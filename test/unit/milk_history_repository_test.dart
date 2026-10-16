import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:dairy_farm_app/core/database/database_helper.dart';
import 'package:dairy_farm_app/features/milk_entry/data/datasources/milk_history_local_datasource.dart';
import 'package:dairy_farm_app/features/milk_entry/data/repositories/milk_history_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('MilkHistoryRepository & 3-Tier Fallback Tests', () {
    late Database db;
    late MilkHistoryRepository repo;

    setUp(() async {
      db = await DatabaseHelper.createInMemoryDatabase();
      repo = MilkHistoryRepository(
        datasource: MilkHistoryLocalDatasource(db: db),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('Tier 1: Accurately determines earliest user activity date from activity_log', () async {
      final userId = 1001;
      final expectedDate = DateTime(2025, 4, 15);
      final timeUnix = expectedDate.millisecondsSinceEpoch;

      await db.insert('activity_log', {
        'user_id': userId,
        'title': 'Registered',
        'subtitle': 'User joined',
        'value': 'Welcome',
        'time_unix': timeUnix,
        'icon_code': 1,
        'is_positive': 1,
      });

      // Add a later activity
      await db.insert('activity_log', {
        'user_id': userId,
        'title': 'Milk Added',
        'subtitle': 'Recorded',
        'value': '10L',
        'time_unix': timeUnix + 86400000 * 10,
        'icon_code': 1,
        'is_positive': 1,
      });

      final earliest = await repo.getEarliestUserActivityDate(userId);
      expect(earliest.year, equals(2025));
      expect(earliest.month, equals(4));
      expect(earliest.day, equals(15));
    });

    test('Tier 2: Falls back to MIN(date) from ledger when activity_log has no records', () async {
      final userId = 1002;

      // Create a dodi for userId
      final dodiId = await db.insert('dodis', {
        'user_id': userId,
        'name': 'Dodi Ali',
        'default_rate_paise': 5000,
        'is_deleted': 0,
      });

      // Insert ledger entries
      await db.insert('ledger', {
        'dodi_id': dodiId,
        'type': 'MILK_SOLD',
        'date': '2025-06-20',
        'session': 'MORNING',
        'quantity_grams': 25000,
        'rate_paise': 5000,
        'amount_paise': 125000,
      });

      await db.insert('ledger', {
        'dodi_id': dodiId,
        'type': 'MILK_SOLD',
        'date': '2025-08-10',
        'session': 'EVENING',
        'quantity_grams': 30000,
        'rate_paise': 5000,
        'amount_paise': 150000,
      });

      final earliest = await repo.getEarliestUserActivityDate(userId);
      expect(earliest.year, equals(2025));
      expect(earliest.month, equals(6));
      expect(earliest.day, equals(20));
    });

    test('Tier 3: Falls back to current date when neither activity_log nor ledger exist', () async {
      final userId = 999999;
      final now = DateTime.now();

      final earliest = await repo.getEarliestUserActivityDate(userId);
      expect(earliest.year, equals(now.year));
      expect(earliest.month, equals(now.month));
      expect(earliest.day, equals(now.day));
    });
  });

  group('Milk History Aggregation & Precision Tests (R1)', () {
    late Database db;
    late MilkHistoryRepository repo;

    setUp(() async {
      db = await DatabaseHelper.createInMemoryDatabase();
      repo = MilkHistoryRepository(
        datasource: MilkHistoryLocalDatasource(db: db),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('Aggregates daily morning & evening sessions without floating point inaccuracies', () async {
      final userId = 2001;

      final dodiA = await db.insert('dodis', {
        'user_id': userId,
        'name': 'Buyer Alpha',
        'default_rate_paise': 6000,
        'is_deleted': 0,
      });

      final dodiB = await db.insert('dodis', {
        'user_id': userId,
        'name': 'Buyer Beta',
        'default_rate_paise': 5500,
        'is_deleted': 0,
      });

      // Day 1: 2026-05-10
      // Buyer Alpha: Morning 20.5 Kg (20500g) @ Rs 60 (6000 paise) = Rs 1230.00 (123000 paise)
      await db.insert('ledger', {
        'dodi_id': dodiA,
        'type': 'MILK_SOLD',
        'date': '2026-05-10',
        'session': 'MORNING',
        'quantity_grams': 20500,
        'rate_paise': 6000,
        'amount_paise': 123000,
      });
      // Buyer Alpha: Evening 15.2 Kg (15200g) @ Rs 60 (6000 paise) = Rs 912.00 (91200 paise)
      await db.insert('ledger', {
        'dodi_id': dodiA,
        'type': 'MILK_SOLD',
        'date': '2026-05-10',
        'session': 'EVENING',
        'quantity_grams': 15200,
        'rate_paise': 6000,
        'amount_paise': 91200,
      });

      // Day 2: 2026-05-11
      // Buyer Beta: Morning 30.0 Kg (30000g) @ Rs 55 (5500 paise) = Rs 1650.00 (165000 paise)
      await db.insert('ledger', {
        'dodi_id': dodiB,
        'type': 'MILK_SOLD',
        'date': '2026-05-11',
        'session': 'MORNING',
        'quantity_grams': 30000,
        'rate_paise': 5500,
        'amount_paise': 165000,
      });

      final month = DateTime(2026, 5);
      final overview = await repo.getMilkHistoryForMonth(
        userId: userId,
        month: month,
      );

      // Total quantity: 20.5 + 15.2 + 30.0 = 65.7 Kg
      expect(overview.totalQuantity, closeTo(65.7, 0.0001));
      // Total revenue: 1230 + 912 + 1650 = 3792 PKR
      expect(overview.grossRevenue, closeTo(3792.0, 0.01));
      // Average rate: 3792 / 65.7 ≈ 57.71689 PKR/Kg
      expect(overview.avgRevenuePerKg, closeTo(3792.0 / 65.7, 0.05));
      // Days in May = 31, avg per day = 65.7 / 31
      expect(overview.avgQuantityPerDay, closeTo(65.7 / 31, 0.001));

      expect(overview.logs.length, equals(2));
      // Log for Day 10 (Buyer Alpha)
      final alphaLog = overview.logs.firstWhere((l) => l.buyerName == 'Buyer Alpha');
      expect(alphaLog.morningQty, closeTo(20.5, 0.0001));
      expect(alphaLog.eveningQty, closeTo(15.2, 0.0001));
      expect(alphaLog.totalCollected, closeTo(35.7, 0.0001));
      expect(alphaLog.rate, closeTo(60.0, 0.01));

      // Log for Day 11 (Buyer Beta)
      final betaLog = overview.logs.firstWhere((l) => l.buyerName == 'Buyer Beta');
      expect(betaLog.morningQty, closeTo(30.0, 0.0001));
      expect(betaLog.eveningQty, closeTo(0.0, 0.0001));
      expect(betaLog.totalCollected, closeTo(30.0, 0.0001));
      expect(betaLog.rate, closeTo(55.0, 0.01));
    });

    test('Pre-Account detection flags months before inception as isPreAccount = true', () async {
      final userId = 2002;
      // Register activity in June 2026
      await db.insert('activity_log', {
        'user_id': userId,
        'title': 'User Registered',
        'subtitle': 'Joined',
        'value': 'Registration',
        'time_unix': DateTime(2026, 6, 1).millisecondsSinceEpoch,
        'icon_code': 1,
        'is_positive': 1,
      });

      // Query May 2026 (prior to account inception)
      final preOverview = await repo.getMilkHistoryForMonth(
        userId: userId,
        month: DateTime(2026, 5),
      );
      expect(preOverview.isPreAccount, isTrue);
      expect(preOverview.logs.isEmpty, isTrue);

      // Query July 2026 (after account inception with zero yield)
      final postOverview = await repo.getMilkHistoryForMonth(
        userId: userId,
        month: DateTime(2026, 7),
      );
      expect(postOverview.isPreAccount, isFalse);
      expect(postOverview.logs.isEmpty, isTrue);
    });

    test('getExportDataForRange accurately aggregates date range', () async {
      final userId = 2003;
      final dodi = await db.insert('dodis', {
        'user_id': userId,
        'name': 'Export Buyer',
        'default_rate_paise': 5000,
        'is_deleted': 0,
      });

      await db.insert('ledger', {
        'dodi_id': dodi,
        'type': 'MILK_SOLD',
        'date': '2026-07-01',
        'session': 'MORNING',
        'quantity_grams': 10000,
        'rate_paise': 5000,
        'amount_paise': 50000,
      });

      await db.insert('ledger', {
        'dodi_id': dodi,
        'type': 'MILK_SOLD',
        'date': '2026-07-01',
        'session': 'EVENING',
        'quantity_grams': 8000,
        'rate_paise': 5000,
        'amount_paise': 40000,
      });

      await db.insert('ledger', {
        'dodi_id': dodi,
        'type': 'MILK_SOLD',
        'date': '2026-07-05',
        'session': 'MORNING',
        'quantity_grams': 12000,
        'rate_paise': 5000,
        'amount_paise': 60000,
      });

      final result = await repo.getExportDataForRange(
        userId: userId,
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2026, 7, 5),
      );

      // Total quantity = 10 + 8 + 12 = 30.0 Kg
      expect(result.summary.totalQuantity, closeTo(30.0, 0.0001));
      expect(result.summary.morningQuantity, closeTo(22.0, 0.0001));
      expect(result.summary.eveningQuantity, closeTo(8.0, 0.0001));
      // Days span from July 1 to July 5 = 5 days
      expect(result.summary.dailyAvg, closeTo(30.0 / 5, 0.0001));

      expect(result.logs.length, equals(2));
      final day1 = result.logs.firstWhere((l) => l.date == DateTime(2026, 7, 1));
      expect(day1.morningQty, closeTo(10.0, 0.0001));
      expect(day1.eveningQty, closeTo(8.0, 0.0001));
      expect(day1.totalQty, closeTo(18.0, 0.0001));
    });

    test('Aggregates lowercase session names and preserves records for soft-deleted dodis', () async {
      final userId = 2003;

      // Soft-deleted dodi
      final dodiId = await db.insert('dodis', {
        'user_id': userId,
        'name': 'Former Buyer',
        'default_rate_paise': 5000,
        'is_deleted': 1,
      });

      // Lowercase session entries
      await db.insert('ledger', {
        'dodi_id': dodiId,
        'type': 'MILK_SOLD',
        'date': '2026-06-15',
        'session': 'morning',
        'quantity_grams': 15000,
        'rate_paise': 5000,
        'amount_paise': 75000,
      });

      await db.insert('ledger', {
        'dodi_id': dodiId,
        'type': 'MILK_SOLD',
        'date': '2026-06-15',
        'session': 'evening',
        'quantity_grams': 10000,
        'rate_paise': 5000,
        'amount_paise': 50000,
      });

      final overview = await repo.getMilkHistoryForMonth(
        userId: userId,
        month: DateTime(2026, 6),
      );

      expect(overview.totalQuantity, closeTo(25.0, 0.0001));
      expect(overview.grossRevenue, closeTo(1250.0, 0.0001));
      expect(overview.logs.length, equals(1));
      expect(overview.logs.first.morningQty, closeTo(15.0, 0.0001));
      expect(overview.logs.first.eveningQty, closeTo(10.0, 0.0001));
      expect(overview.logs.first.buyerName, equals('Former Buyer'));
      expect(overview.logs.first.totalAmount, equals(1250.0));
    });

    test('Robustly matches dates with ISO timestamps on boundary dates', () async {
      final userId = 2004;
      final dodiId = await db.insert('dodis', {
        'user_id': userId,
        'name': 'Timestamp Buyer',
        'default_rate_paise': 5000,
        'is_deleted': 0,
      });

      // Entry on end-of-month date with time component
      await db.insert('ledger', {
        'dodi_id': dodiId,
        'type': 'MILK_SOLD',
        'date': '2026-06-30 20:45:00',
        'session': 'EVENING',
        'quantity_grams': 18000,
        'rate_paise': 5000,
        'amount_paise': 90000,
      });

      final overview = await repo.getMilkHistoryForMonth(
        userId: userId,
        month: DateTime(2026, 6),
      );

      expect(overview.totalQuantity, closeTo(18.0, 0.0001));
      expect(overview.grossRevenue, closeTo(900.0, 0.0001));
      expect(overview.logs.length, equals(1));
      expect(overview.logs.first.totalAmount, equals(900.0));

      final exportData = await repo.getExportDataForRange(
        userId: userId,
        startDate: DateTime(2026, 6, 1),
        endDate: DateTime(2026, 6, 30),
      );

      expect(exportData.summary.totalQuantity, closeTo(18.0, 0.0001));
      expect(exportData.logs.length, equals(1));
    });
  });
}
