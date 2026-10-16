import 'package:sqflite/sqflite.dart';
import '../../../../core/database/database_helper.dart';
import '../models/milk_history_models.dart';

/// SQLite data source for Milk History queries and User Inception detection.
class MilkHistoryLocalDatasource {
  final DatabaseHelper _dbHelper;
  final Database? _customDb;

  MilkHistoryLocalDatasource({DatabaseHelper? dbHelper, Database? db})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance,
        _customDb = db;

  Future<Database> _getDb() async {
    final custom = _customDb;
    if (custom != null) return custom;
    return await _dbHelper.database;
  }

  String _formatDate(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}-'
        '${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')}';
  }

  /// Determines user's earliest activity date dynamically using a 3-tier fallback:
  ///   Tier 1: MIN(time_unix) from activity_log
  ///   Tier 2: MIN(date) from ledger joined with dodis
  ///   Tier 3: current date
  Future<DateTime> getEarliestUserActivityDate(int userId) async {
    final db = await _getDb();

    // Tier 1: Check activity_log table
    try {
      final List<Map<String, dynamic>> actRows = await db.rawQuery(
        'SELECT MIN(time_unix) AS min_time FROM activity_log WHERE user_id = ?',
        [userId],
      );
      if (actRows.isNotEmpty && actRows.first['min_time'] != null) {
        final rawVal = actRows.first['min_time'] as num;
        final int minTime = rawVal.toInt();
        if (minTime > 0) {
          final dt = minTime > 100000000000
              ? DateTime.fromMillisecondsSinceEpoch(minTime)
              : DateTime.fromMillisecondsSinceEpoch(minTime * 1000);
          return DateTime(dt.year, dt.month, dt.day);
        }
      }
    } catch (_) {
      // Fall through to Tier 2
    }

    // Tier 2: Check ledger table via dodis ownership
    try {
      final List<Map<String, dynamic>> ledgerRows = await db.rawQuery(
        'SELECT MIN(SUBSTR(l.date, 1, 10)) AS min_date '
        'FROM ledger l '
        'JOIN dodis d ON l.dodi_id = d.id '
        'WHERE d.user_id = ?',
        [userId],
      );
      if (ledgerRows.isNotEmpty && ledgerRows.first['min_date'] != null) {
        final minDateStr = ledgerRows.first['min_date'] as String;
        final parsed = DateTime.tryParse(minDateStr);
        if (parsed != null) {
          return DateTime(parsed.year, parsed.month, parsed.day);
        }
      }
    } catch (_) {
      // Fall through to Tier 3
    }

    // Tier 3: Current calendar date
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Queries aggregated milk overview and dispatch logs for a specific calendar month.
  Future<MilkHistoryOverview> getMilkHistoryForMonth({
    required int userId,
    required DateTime month,
    int? daysToShow,
  }) async {
    final db = await _getDb();
    final earliestDate = await getEarliestUserActivityDate(userId);

    final inceptionMonth = DateTime(earliestDate.year, earliestDate.month);
    final targetMonth = DateTime(month.year, month.month);
    final isPreAccount = targetMonth.isBefore(inceptionMonth);

    final int daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final int effectiveDaysToShow = (daysToShow != null && daysToShow > 0 && daysToShow <= daysInMonth)
        ? daysToShow
        : daysInMonth;

    final String startDateStr = _formatDate(DateTime(month.year, month.month, 1));
    final String endDateStr = _formatDate(DateTime(month.year, month.month, effectiveDaysToShow));

    // Summary query in exact integer math space
    final List<Map<String, dynamic>> summaryRows = await db.rawQuery(
      'SELECT '
      '  COALESCE(SUM(l.quantity_grams), 0) AS total_quantity_grams, '
      '  COALESCE(SUM(l.amount_paise), 0) AS gross_revenue_paise, '
      '  COUNT(DISTINCT SUBSTR(l.date, 1, 10)) AS active_days_count '
      'FROM ledger l '
      'JOIN dodis d ON l.dodi_id = d.id '
      "WHERE d.user_id = ? AND l.type = 'MILK_SOLD' "
      '  AND SUBSTR(l.date, 1, 10) >= ? AND SUBSTR(l.date, 1, 10) <= ?',
      [userId, startDateStr, endDateStr],
    );

    int totalGrams = 0;
    int grossRevenuePaise = 0;
    if (summaryRows.isNotEmpty) {
      totalGrams = (summaryRows.first['total_quantity_grams'] as num?)?.toInt() ?? 0;
      grossRevenuePaise = (summaryRows.first['gross_revenue_paise'] as num?)?.toInt() ?? 0;
    }

    final double totalQuantity = totalGrams / 1000.0;
    final double grossRevenue = grossRevenuePaise / 100.0;
    final double avgQuantityPerDay = effectiveDaysToShow > 0
        ? totalQuantity / effectiveDaysToShow
        : 0.0;
    final double avgRevenuePerKg = totalGrams > 0
        ? (grossRevenuePaise * 10.0) / totalGrams
        : 0.0;

    // Line items per buyer & date
    final List<Map<String, dynamic>> logRows = await db.rawQuery(
      'SELECT '
      '  SUBSTR(l.date, 1, 10) AS date, '
      '  d.name AS buyer_name, '
      "  COALESCE(SUM(CASE WHEN UPPER(l.session) = 'MORNING' THEN l.quantity_grams ELSE 0 END), 0) AS morning_grams, "
      "  COALESCE(SUM(CASE WHEN UPPER(l.session) = 'EVENING' THEN l.quantity_grams ELSE 0 END), 0) AS evening_grams, "
      '  COALESCE(SUM(l.quantity_grams), 0) AS total_grams, '
      '  COALESCE(SUM(l.amount_paise), 0) AS total_amount_paise '
      'FROM ledger l '
      'JOIN dodis d ON l.dodi_id = d.id '
      "WHERE d.user_id = ? AND l.type = 'MILK_SOLD' "
      '  AND SUBSTR(l.date, 1, 10) >= ? AND SUBSTR(l.date, 1, 10) <= ? '
      'GROUP BY SUBSTR(l.date, 1, 10), d.id, d.name '
      'ORDER BY SUBSTR(l.date, 1, 10) DESC, d.name ASC',
      [userId, startDateStr, endDateStr],
    );

    final List<MilkHistoryLog> logs = logRows.map((row) {
      final int rowTotalGrams = (row['total_grams'] as num?)?.toInt() ?? 0;
      final int rowMorningGrams = (row['morning_grams'] as num?)?.toInt() ?? 0;
      final int rowEveningGrams = (row['evening_grams'] as num?)?.toInt() ?? 0;
      final int rowAmountPaise = (row['total_amount_paise'] as num?)?.toInt() ?? 0;

      final double rate = rowTotalGrams > 0
          ? (rowAmountPaise * 10.0) / rowTotalGrams
          : 0.0;

      final dateStr = (row['date'] as String?) ?? '';
      final parsedDate = DateTime.tryParse(dateStr) ?? DateTime.now();

      return MilkHistoryLog(
        buyerName: (row['buyer_name'] as String?) ?? 'Unknown Buyer',
        date: parsedDate,
        totalCollected: rowTotalGrams / 1000.0,
        rate: rate,
        morningQty: rowMorningGrams / 1000.0,
        eveningQty: rowEveningGrams / 1000.0,
        totalAmount: rowAmountPaise / 100.0,
      );
    }).toList();

    return MilkHistoryOverview(
      totalQuantity: totalQuantity,
      avgQuantityPerDay: avgQuantityPerDay,
      grossRevenue: grossRevenue,
      avgRevenuePerKg: avgRevenuePerKg,
      earliestActivityDate: earliestDate,
      isPreAccount: isPreAccount,
      logs: logs,
    );
  }

  /// Queries aggregated summary and daily breakdown for the export date range.
  Future<({ExportMilkSummary summary, List<ExportMilkLog> logs})> getExportDataForRange({
    required int userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final db = await _getDb();
    final sDate = DateTime(startDate.year, startDate.month, startDate.day);
    final eDate = DateTime(endDate.year, endDate.month, endDate.day);
    final String startDateStr = _formatDate(sDate);
    final String endDateStr = _formatDate(eDate);
    final int daysSpan = eDate.difference(sDate).inDays.abs() + 1;

    // Summary query
    final List<Map<String, dynamic>> summaryRows = await db.rawQuery(
      'SELECT '
      '  COALESCE(SUM(l.quantity_grams), 0) AS total_quantity_grams, '
      "  COALESCE(SUM(CASE WHEN UPPER(l.session) = 'MORNING' THEN l.quantity_grams ELSE 0 END), 0) AS morning_quantity_grams, "
      "  COALESCE(SUM(CASE WHEN UPPER(l.session) = 'EVENING' THEN l.quantity_grams ELSE 0 END), 0) AS evening_quantity_grams "
      'FROM ledger l '
      'JOIN dodis d ON l.dodi_id = d.id '
      "WHERE d.user_id = ? AND l.type = 'MILK_SOLD' "
      '  AND SUBSTR(l.date, 1, 10) >= ? AND SUBSTR(l.date, 1, 10) <= ?',
      [userId, startDateStr, endDateStr],
    );

    int totalGrams = 0;
    int morningGrams = 0;
    int eveningGrams = 0;
    if (summaryRows.isNotEmpty) {
      totalGrams = (summaryRows.first['total_quantity_grams'] as num?)?.toInt() ?? 0;
      morningGrams = (summaryRows.first['morning_quantity_grams'] as num?)?.toInt() ?? 0;
      eveningGrams = (summaryRows.first['evening_quantity_grams'] as num?)?.toInt() ?? 0;
    }

    final double totalQty = totalGrams / 1000.0;
    final double morningQty = morningGrams / 1000.0;
    final double eveningQty = eveningGrams / 1000.0;
    final double dailyAvg = daysSpan > 0 ? totalQty / daysSpan : 0.0;

    final summary = ExportMilkSummary(
      totalQuantity: totalQty,
      morningQuantity: morningQty,
      eveningQuantity: eveningQty,
      dailyAvg: dailyAvg,
    );

    // Daily breakdown query
    final List<Map<String, dynamic>> logRows = await db.rawQuery(
      'SELECT '
      '  SUBSTR(l.date, 1, 10) AS date, '
      "  COALESCE(SUM(CASE WHEN UPPER(l.session) = 'MORNING' THEN l.quantity_grams ELSE 0 END), 0) AS morning_grams, "
      "  COALESCE(SUM(CASE WHEN UPPER(l.session) = 'EVENING' THEN l.quantity_grams ELSE 0 END), 0) AS evening_grams, "
      '  COALESCE(SUM(l.quantity_grams), 0) AS total_grams '
      'FROM ledger l '
      'JOIN dodis d ON l.dodi_id = d.id '
      "WHERE d.user_id = ? AND l.type = 'MILK_SOLD' "
      '  AND SUBSTR(l.date, 1, 10) >= ? AND SUBSTR(l.date, 1, 10) <= ? '
      'GROUP BY SUBSTR(l.date, 1, 10) '
      'ORDER BY SUBSTR(l.date, 1, 10) DESC',
      [userId, startDateStr, endDateStr],
    );

    final List<ExportMilkLog> logs = logRows.map((row) {
      final int rowTotalGrams = (row['total_grams'] as num?)?.toInt() ?? 0;
      final int rowMorningGrams = (row['morning_grams'] as num?)?.toInt() ?? 0;
      final int rowEveningGrams = (row['evening_grams'] as num?)?.toInt() ?? 0;

      final dateStr = (row['date'] as String?) ?? '';
      final parsedDate = DateTime.tryParse(dateStr) ?? DateTime.now();

      return ExportMilkLog(
        date: parsedDate,
        totalQty: rowTotalGrams / 1000.0,
        morningQty: rowMorningGrams / 1000.0,
        eveningQty: rowEveningGrams / 1000.0,
      );
    }).toList();

    return (summary: summary, logs: logs);
  }
}
