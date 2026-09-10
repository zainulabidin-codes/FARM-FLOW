import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:dairy_farm_app/core/database/database_helper.dart';
import 'package:dairy_farm_app/features/cows/presentation/utils/pregnancy_display_utils.dart';
import 'package:dairy_farm_app/features/cows/data/datasources/cow_local_datasource.dart';
import 'package:dairy_farm_app/features/cows/data/models/cow_model.dart';
import 'package:dairy_farm_app/features/cows/data/repositories/cow_repository.dart';
import 'package:dairy_farm_app/features/cows/presentation/providers/cow_provider.dart';
import 'package:dairy_farm_app/features/dashboard/data/repositories/activity_log_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('Cow Lifecycle Invariant Tests', () async {
    DatabaseHelper.initForPlatform();
    final dbHelper = DatabaseHelper.instance;
    final db = await dbHelper.database;
    final repo = CowRepository();
    final datasource = CowLocalDatasource();

    // 1. Add a test cow with DRY status
    final cow = await repo.addCow(
      userId: 999,
      tagNumber: 'LIFECYCLE01',
      name: 'Bessie Lifecycle',
      status: 'DRY',
      hasLactatedBefore: 1,
    );
    expect(cow.id, isNotNull);

    // Verify DRY status has 0 active seasons
    var activeSeasons = await db.query(
      'milking_seasons',
      where: 'cow_id = ? AND season_end_date IS NULL',
      whereArgs: [cow.id],
    );
    expect(activeSeasons.length, equals(0));

    // 2. Transition DRY -> MILKING (Path B / Manual Edit)
    await repo.updateCowStatus(cow.id!, 'MILKING');

    // Invariant Check 1: MILKING => exactly 1 active season
    activeSeasons = await db.query(
      'milking_seasons',
      where: 'cow_id = ? AND season_end_date IS NULL',
      whereArgs: [cow.id],
    );
    expect(activeSeasons.length, equals(1));

    // 3. Repeat MILKING status update -> Prevent Duplicate Active Seasons
    await repo.updateCowStatus(cow.id!, 'MILKING');

    // Invariant Check 2: Max 1 active season (no duplicate)
    activeSeasons = await db.query(
      'milking_seasons',
      where: 'cow_id = ? AND season_end_date IS NULL',
      whereArgs: [cow.id],
    );
    expect(activeSeasons.length, equals(1));

    // 4. Transition MILKING -> DRY
    await repo.updateCowStatus(cow.id!, 'DRY');

    // Invariant Check 3: DRY => 0 active seasons (season closed)
    activeSeasons = await db.query(
      'milking_seasons',
      where: 'cow_id = ? AND season_end_date IS NULL',
      whereArgs: [cow.id],
    );
    expect(activeSeasons.length, equals(0));

    // 5. Calving Event: recordCalving (Path A)
    await datasource.recordCalving(cow.id!, '2026-07-31');

    // Invariant Check 4: Calving opens a new active season
    activeSeasons = await db.query(
      'milking_seasons',
      where: 'cow_id = ? AND season_end_date IS NULL',
      whereArgs: [cow.id],
    );
    expect(activeSeasons.length, equals(1));

    // 6. Soft Delete
    await datasource.softDeleteCow(cow.id!, 'SOLD', '2026-07-31');

    // Invariant Check 5: Soft delete closes active season
    activeSeasons = await db.query(
      'milking_seasons',
      where: 'cow_id = ? AND season_end_date IS NULL',
      whereArgs: [cow.id],
    );
    expect(activeSeasons.length, equals(0));
  });

  // ---------------------------------------------------------------------------
  // Regression tests for pregnancy progress display math (Bug: ordinal vs cardinal)
  // These tests exercise the pure function computePregnancyDisplay extracted
  // from _PregnancyDetailsState.build. No Flutter or DB infrastructure needed.
  // ---------------------------------------------------------------------------
  group('computePregnancyDisplay — display text regression', () {
    test('day 6: completedMonths=0, remainingDays=6 (was wrongly showing "1 months and 6 days")', () {
      final result = computePregnancyDisplay(daysSinceMating: 6);
      expect(result.completedMonths, equals(0),
          reason: 'A cow mated 6 days ago has 0 completed months elapsed');
      expect(result.remainingDays, equals(6),
          reason: 'Remaining days within the current month should be 6');
      // The ordinal month badge (used elsewhere for the progress bar) should still be 1
      expect(result.pregnancyMonth, equals(1),
          reason: 'Ordinal month is 1 (first month in progress), used by badge/bar, NOT the display text');
    });

    test('day 35: completedMonths=1, remainingDays≈5 (first full month crossed)', () {
      final result = computePregnancyDisplay(daysSinceMating: 35);
      expect(result.completedMonths, equals(1),
          reason: '35 days > 30.44, so one full month has elapsed');
      // remainingDays = 35 - (1 * 30.44) = 4.56 → rounds to 5
      expect(result.remainingDays, equals(5),
          reason: '35 - 30.44 ≈ 4.56, rounds to 5 remaining days');
      expect(result.pregnancyMonth, equals(2),
          reason: 'Ordinal month badge should show Month 2');
    });

    test('day 0: all zeros — no negative or NaN values', () {
      final result = computePregnancyDisplay(daysSinceMating: 0);
      expect(result.completedMonths, equals(0));
      expect(result.remainingDays, equals(0));
      expect(result.pregnancyMonth, equals(0));
    });
  });

  group('getDaysSinceMating — midnight normalization tests', () {
    final repo = CowRepository();
    const matingDate = '2026-09-07'; // Mating date recorded on Sept 7

    test('11:58 PM on mating day (Sept 7 23:58) returns 0 days elapsed', () {
      final sameDayLate = DateTime(2026, 9, 7, 23, 58);
      final days = repo.getDaysSinceMating(matingDate, now: sameDayLate);
      expect(days, equals(0), reason: 'Mating logged near midnight on Sept 7 must evaluate to 0 days on Sept 7 23:58');
    });

    test('12:02 AM on next day (Sept 8 00:02) returns 1 day elapsed', () {
      final nextDayEarly = DateTime(2026, 9, 8, 0, 2);
      final days = repo.getDaysSinceMating(matingDate, now: nextDayEarly);
      expect(days, equals(1), reason: 'Crossing midnight into Sept 8 00:02 must evaluate to 1 day elapsed');
    });
  });

  // ---------------------------------------------------------------------------
  // Phase 1 — v13 Schema & endPregnancy Bug 3 Fix Tests
  // ---------------------------------------------------------------------------
  group('Phase 1 — v13 Schema & endPregnancy Bug 3 Fix Tests', () {
    test('v13 schema migration adds pregnancy confirmation columns', () async {
      DatabaseHelper.initForPlatform();
      final db = await DatabaseHelper.instance.database;

      final columns = await db.rawQuery("PRAGMA table_info(cows)");
      final columnNames = columns.map((c) => c['name'] as String).toSet();

      expect(columnNames.contains('is_pregnancy_confirmed'), isTrue);
      expect(columnNames.contains('confirmation_date'), isTrue);
      expect(columnNames.contains('confirmation_method'), isTrue);
    });

    test('CowModel fromMap/toMap roundtrips confirmation fields correctly', () {
      final map = {
        'id': 101,
        'user_id': 1,
        'tag_number': 'TAG101',
        'name': 'Model Cow',
        'status': 'PREGNANT',
        'mating_date': '2026-08-01',
        'delivery_date': '2027-05-11',
        'is_deleted': 0,
        'has_lactated_before': 1,
        'is_pregnancy_confirmed': 1,
        'confirmation_date': '2026-08-25',
        'confirmation_method': 'VET',
      };

      final model = CowModel.fromMap(map);
      expect(model.isPregnancyConfirmed, equals(1));
      expect(model.confirmationDate, equals('2026-08-25'));
      expect(model.confirmationMethod, equals('VET'));

      final reserialized = model.toMap();
      expect(reserialized['is_pregnancy_confirmed'], equals(1));
      expect(reserialized['confirmation_date'], equals('2026-08-25'));
      expect(reserialized['confirmation_method'], equals('VET'));
    });

    test('endPregnancy on lactated cow reverts status to MILKING and clears pregnancy & confirmation fields', () async {
      DatabaseHelper.initForPlatform();
      final repo = CowRepository();
      final provider = CowProvider(repository: repo);

      final tag = 'P1_LAC_${DateTime.now().microsecondsSinceEpoch}';
      final cow = await repo.addCow(
        userId: 1,
        tagNumber: tag,
        name: 'Milking Loss Test',
        status: 'PREGNANT',
        matingDate: '2026-08-01',
        hasLactatedBefore: 1,
      );

      await repo.updateCowGeneral(
        cowId: cow.id!,
        name: cow.name!,
        tagNumber: cow.tagNumber,
        status: 'PREGNANT',
        matingDate: '2026-08-01',
        hasLactatedBefore: 1,
        isPregnancyConfirmed: 1,
        confirmationDate: '2026-08-25',
        confirmationMethod: 'SELF',
      );

      await provider.fetchCows(1);
      final success = await provider.endPregnancy(cow.id!, 1);
      expect(success, isTrue);

      final updatedCow = provider.cows.firstWhere((c) => c.id == cow.id);
      expect(updatedCow.status, equals('MILKING'));
      expect(updatedCow.hasLactatedBefore, equals(1));
      expect(updatedCow.matingDate, isNull);
      expect(updatedCow.deliveryDate, isNull);
      expect(updatedCow.isPregnancyConfirmed, equals(0));
      expect(updatedCow.confirmationDate, isNull);
      expect(updatedCow.confirmationMethod, isNull);
    });

    test('endPregnancy on non-lactated heifer reverts status to HEIFER and clears pregnancy & confirmation fields', () async {
      DatabaseHelper.initForPlatform();
      final repo = CowRepository();
      final provider = CowProvider(repository: repo);

      final tag = 'P1_HEIF_${DateTime.now().microsecondsSinceEpoch}';
      final cow = await repo.addCow(
        userId: 1,
        tagNumber: tag,
        name: 'Heifer Loss Test',
        status: 'PREGNANT',
        matingDate: '2026-08-01',
        hasLactatedBefore: 0,
      );

      await repo.updateCowGeneral(
        cowId: cow.id!,
        name: cow.name!,
        tagNumber: cow.tagNumber,
        status: 'PREGNANT',
        matingDate: '2026-08-01',
        hasLactatedBefore: 0,
        isPregnancyConfirmed: 1,
        confirmationDate: '2026-08-25',
        confirmationMethod: 'VET',
      );

      await provider.fetchCows(1);
      final success = await provider.endPregnancy(cow.id!, 1);
      expect(success, isTrue);

      final updatedCow = provider.cows.firstWhere((c) => c.id == cow.id);
      expect(updatedCow.status, equals('HEIFER'));
      expect(updatedCow.hasLactatedBefore, equals(0));
      expect(updatedCow.matingDate, isNull);
      expect(updatedCow.deliveryDate, isNull);
      expect(updatedCow.isPregnancyConfirmed, equals(0));
      expect(updatedCow.confirmationDate, isNull);
      expect(updatedCow.confirmationMethod, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Phase 2 — Core State Machine Tests
  // ---------------------------------------------------------------------------
  group('Phase 2 — Core State Machine Tests', () {
    test('recordMating sets status to PENDING_CONFIRMATION and clears confirmation fields', () async {
      DatabaseHelper.initForPlatform();
      final repo = CowRepository();
      final provider = CowProvider(repository: repo);

      final tag = 'P2_PEND_${DateTime.now().microsecondsSinceEpoch}';
      final cow = await repo.addCow(
        userId: 1,
        tagNumber: tag,
        name: 'Pending Mating Cow',
        status: 'MILKING',
        hasLactatedBefore: 1,
      );

      final recentMatingDate = DateTime.now().subtract(const Duration(days: 10));
      final recentMatingStr = "${recentMatingDate.year.toString().padLeft(4, '0')}-${recentMatingDate.month.toString().padLeft(2, '0')}-${recentMatingDate.day.toString().padLeft(2, '0')}";

      await provider.fetchCows(1);
      final success = await provider.recordMating(
        cowId: cow.id!,
        cowName: cow.name!,
        matingDate: recentMatingStr,
        userId: 1,
      );
      expect(success, isTrue);

      final updatedCow = provider.cows.firstWhere((c) => c.id == cow.id);
      expect(updatedCow.status, equals('PENDING_CONFIRMATION'));
      expect(updatedCow.matingDate, equals(recentMatingStr));
      expect(updatedCow.deliveryDate, isNotNull);
      expect(updatedCow.isPregnancyConfirmed, equals(0));
      expect(updatedCow.confirmationDate, isNull);
      expect(updatedCow.confirmationMethod, isNull);
    });

    test('confirmPregnancy derives BRED_HEIFER for non-lactated heifer (hasLactatedBefore = 0)', () async {
      DatabaseHelper.initForPlatform();
      final repo = CowRepository();
      final provider = CowProvider(repository: repo);

      final tag = 'P2_HCONF_${DateTime.now().microsecondsSinceEpoch}';
      final heifer = await repo.addCow(
        userId: 1,
        tagNumber: tag,
        name: 'Heifer Confirm Test',
        status: 'HEIFER',
        hasLactatedBefore: 0,
      );

      await provider.fetchCows(1);
      await provider.recordMating(
        cowId: heifer.id!,
        cowName: heifer.name!,
        matingDate: '2026-08-10',
        userId: 1,
      );

      final success = await provider.confirmPregnancy(
        heifer.id!,
        1,
        confirmationDate: '2026-08-30',
        method: 'SELF',
      );
      expect(success, isTrue);

      final confirmedCow = provider.cows.firstWhere((c) => c.id == heifer.id);
      expect(confirmedCow.status, equals('BRED_HEIFER'));
      expect(confirmedCow.isPregnancyConfirmed, equals(1));
      expect(confirmedCow.confirmationDate, equals('2026-08-30'));
      expect(confirmedCow.confirmationMethod, equals('SELF'));
    });

    test('confirmPregnancy derives PREGNANT for adult lactated cow (hasLactatedBefore = 1)', () async {
      DatabaseHelper.initForPlatform();
      final repo = CowRepository();
      final provider = CowProvider(repository: repo);

      final tag = 'P2_MCONF_${DateTime.now().microsecondsSinceEpoch}';
      final cow = await repo.addCow(
        userId: 1,
        tagNumber: tag,
        name: 'Adult Confirm Test',
        status: 'MILKING',
        hasLactatedBefore: 1,
      );

      await provider.fetchCows(1);
      await provider.recordMating(
        cowId: cow.id!,
        cowName: cow.name!,
        matingDate: '2026-08-10',
        userId: 1,
      );

      final success = await provider.confirmPregnancy(
        cow.id!,
        1,
        confirmationDate: '2026-08-30',
        method: 'SELF',
      );
      expect(success, isTrue);

      final confirmedCow = provider.cows.firstWhere((c) => c.id == cow.id);
      expect(confirmedCow.status, equals('PREGNANT'));
      expect(confirmedCow.isPregnancyConfirmed, equals(1));
      expect(confirmedCow.confirmationDate, equals('2026-08-30'));
      expect(confirmedCow.confirmationMethod, equals('SELF'));
    });

    test('confirmPregnancy method override (AUTO -> VET) updates method and allows re-confirmation', () async {
      DatabaseHelper.initForPlatform();
      final repo = CowRepository();
      final provider = CowProvider(repository: repo);

      final tag = 'P2_OVR_${DateTime.now().microsecondsSinceEpoch}';
      final cow = await repo.addCow(
        userId: 1,
        tagNumber: tag,
        name: 'Override Test Cow',
        status: 'MILKING',
        hasLactatedBefore: 1,
      );

      await provider.fetchCows(1);
      await provider.recordMating(
        cowId: cow.id!,
        cowName: cow.name!,
        matingDate: '2026-08-01',
        userId: 1,
      );

      // First confirmation: AUTO
      await provider.confirmPregnancy(
        cow.id!,
        1,
        confirmationDate: '2026-08-29',
        method: 'AUTO',
      );

      var current = provider.cows.firstWhere((c) => c.id == cow.id);
      expect(current.confirmationMethod, equals('AUTO'));

      // No-Op re-confirmation with identical method: AUTO -> AUTO
      final noOpSuccess = await provider.confirmPregnancy(
        cow.id!,
        1,
        confirmationDate: '2026-08-29',
        method: 'AUTO',
      );
      expect(noOpSuccess, isTrue);

      // Method Override: AUTO -> VET
      final overrideSuccess = await provider.confirmPregnancy(
        cow.id!,
        1,
        confirmationDate: '2026-09-05',
        method: 'VET',
      );
      expect(overrideSuccess, isTrue);

      final updated = provider.cows.firstWhere((c) => c.id == cow.id);
      expect(updated.isPregnancyConfirmed, equals(1));
      expect(updated.confirmationDate, equals('2026-09-05'));
      expect(updated.confirmationMethod, equals('VET'));
    });
  });

  // ---------------------------------------------------------------------------
  // Phase 3 — Provider KPI, Auto-Confirm & Milk Eligibility Tests
  // ---------------------------------------------------------------------------
  group('Phase 3 — Provider KPI, Auto-Confirm & Milk Eligibility Tests', () {
    test('pendingConfirmationCount and pendingConfirmationCows capture PENDING_CONFIRMATION cows', () async {
      DatabaseHelper.initForPlatform();
      final repo = CowRepository();
      final provider = CowProvider(repository: repo);
      final userId = DateTime.now().microsecondsSinceEpoch % 100000;

      final cow = await repo.addCow(
        userId: userId,
        tagNumber: 'P3_PEND_${DateTime.now().microsecondsSinceEpoch}',
        name: 'Pending Count Cow',
        status: 'MILKING',
        hasLactatedBefore: 1,
      );

      await provider.fetchCows(userId);
      final initialPending = provider.pendingConfirmationCount;

      await provider.recordMating(
        cowId: cow.id!,
        cowName: cow.name!,
        matingDate: '2026-08-20',
        userId: userId,
      );

      expect(provider.pendingConfirmationCount, equals(initialPending + 1));
      expect(provider.pendingConfirmationCows.firstWhere((c) => c.id == cow.id).id, equals(cow.id));
    });

    test('pregnantCount and pregnantCows exclude PENDING_CONFIRMATION cows', () async {
      DatabaseHelper.initForPlatform();
      final repo = CowRepository();
      final provider = CowProvider(repository: repo);
      final userId = (DateTime.now().microsecondsSinceEpoch + 1) % 100000;

      final cow = await repo.addCow(
        userId: userId,
        tagNumber: 'P3_EXCL_${DateTime.now().microsecondsSinceEpoch}',
        name: 'Exclude Pending Cow',
        status: 'MILKING',
        hasLactatedBefore: 1,
      );

      await provider.fetchCows(userId);
      final initialPregnant = provider.pregnantCount;

      await provider.recordMating(
        cowId: cow.id!,
        cowName: cow.name!,
        matingDate: '2026-08-20',
        userId: userId,
      );

      expect(provider.pregnantCount, equals(initialPregnant));
      expect(provider.pregnantCows.any((c) => c.id == cow.id), isFalse);

      await provider.confirmPregnancy(cow.id!, userId, method: 'SELF');
      expect(provider.pregnantCount, equals(initialPregnant + 1));
      expect(provider.pregnantCows.any((c) => c.id == cow.id), isTrue);
    });

    test('milkingCows includes PENDING_CONFIRMATION lactated cows and excludes PENDING_CONFIRMATION heifers', () async {
      DatabaseHelper.initForPlatform();
      final repo = CowRepository();
      final provider = CowProvider(repository: repo);
      final userId = 303;

      final lactatedCow = await repo.addCow(
        userId: userId,
        tagNumber: 'P3_MILK_${DateTime.now().microsecondsSinceEpoch}',
        name: 'Lactated Pending',
        status: 'MILKING',
        hasLactatedBefore: 1,
      );

      final heiferCow = await repo.addCow(
        userId: userId,
        tagNumber: 'P3_HEIF_${DateTime.now().microsecondsSinceEpoch}',
        name: 'Heifer Pending',
        status: 'HEIFER',
        hasLactatedBefore: 0,
      );

      await provider.fetchCows(userId);
      await provider.recordMating(cowId: lactatedCow.id!, cowName: lactatedCow.name!, matingDate: '2026-08-20', userId: userId);
      await provider.recordMating(cowId: heiferCow.id!, cowName: heiferCow.name!, matingDate: '2026-08-20', userId: userId);

      expect(provider.milkingCows.any((c) => c.id == lactatedCow.id), isTrue, reason: 'Lactating cow in PENDING_CONFIRMATION must be in milkingCows');
      expect(provider.milkingCows.any((c) => c.id == heiferCow.id), isFalse, reason: 'Non-lactated heifer in PENDING_CONFIRMATION must NOT be in milkingCows');
    });

    test('fetchCows auto-confirms Day 29+ pending cows and skips <29 days pending cows (Idempotent)', () async {
      DatabaseHelper.initForPlatform();
      final repo = CowRepository();
      final provider = CowProvider(repository: repo);
      final userId = 304;

      final now = DateTime.now();
      final day30Ago = now.subtract(const Duration(days: 30));
      final day20Ago = now.subtract(const Duration(days: 20));
      final day30Str = "${day30Ago.year.toString().padLeft(4, '0')}-${day30Ago.month.toString().padLeft(2, '0')}-${day30Ago.day.toString().padLeft(2, '0')}";
      final day20Str = "${day20Ago.year.toString().padLeft(4, '0')}-${day20Ago.month.toString().padLeft(2, '0')}-${day20Ago.day.toString().padLeft(2, '0')}";

      final oldCow = await repo.addCow(
        userId: userId,
        tagNumber: 'P3_AUTO30_${DateTime.now().microsecondsSinceEpoch}',
        name: 'Day 30 Cow',
        status: 'MILKING',
        hasLactatedBefore: 1,
      );

      final recentCow = await repo.addCow(
        userId: userId,
        tagNumber: 'P3_RECENT20_${DateTime.now().microsecondsSinceEpoch}',
        name: 'Day 20 Cow',
        status: 'MILKING',
        hasLactatedBefore: 1,
      );

      await provider.fetchCows(userId);
      await provider.recordMating(cowId: oldCow.id!, cowName: oldCow.name!, matingDate: day30Str, userId: userId);
      await provider.recordMating(cowId: recentCow.id!, cowName: recentCow.name!, matingDate: day20Str, userId: userId);

      // Trigger fetchCows which runs auto-confirm sweep
      await provider.fetchCows(userId);

      final updatedOld = provider.cows.firstWhere((c) => c.id == oldCow.id);
      final updatedRecent = provider.cows.firstWhere((c) => c.id == recentCow.id);

      expect(updatedOld.status, equals('PREGNANT'), reason: 'Day 30 pending cow should be auto-confirmed as PREGNANT');
      expect(updatedOld.isPregnancyConfirmed, equals(1));
      expect(updatedOld.confirmationMethod, equals('AUTO'));

      expect(updatedRecent.status, equals('PENDING_CONFIRMATION'), reason: 'Day 20 pending cow should remain PENDING_CONFIRMATION');
      expect(updatedRecent.isPregnancyConfirmed, equals(0));

      // Idempotency check: re-running fetchCows does not re-auto-confirm or throw
      final activityRepo = ActivityLogRepository();
      final logsBefore = await activityRepo.getActivities(userId);

      await provider.fetchCows(userId);

      final logsAfter = await activityRepo.getActivities(userId);
      expect(logsAfter.length, equals(logsBefore.length), reason: 'Re-running fetchCows should not duplicate activity logs');
    });

    test('identical method re-confirmation (SELF -> SELF) triggers No-Op Guard (no duplicate activity log)', () async {
      DatabaseHelper.initForPlatform();
      final repo = CowRepository();
      final provider = CowProvider(repository: repo);
      final activityRepo = ActivityLogRepository();
      final userId = 305;

      final cow = await repo.addCow(
        userId: userId,
        tagNumber: 'P3_NOOP_${DateTime.now().microsecondsSinceEpoch}',
        name: 'NoOp Guard Cow',
        status: 'MILKING',
        hasLactatedBefore: 1,
      );

      await provider.fetchCows(userId);
      await provider.recordMating(cowId: cow.id!, cowName: cow.name!, matingDate: '2026-08-01', userId: userId);

      // First confirmation: SELF
      await provider.confirmPregnancy(cow.id!, userId, confirmationDate: '2026-08-25', method: 'SELF');
      final logsFirst = await activityRepo.getActivities(userId);
      final countAfterFirst = logsFirst.length;

      // Re-confirmation: SELF -> SELF (Identical method)
      await provider.confirmPregnancy(cow.id!, userId, confirmationDate: '2026-08-26', method: 'SELF');
      final logsSecond = await activityRepo.getActivities(userId);

      expect(logsSecond.length, equals(countAfterFirst), reason: 'Identical method re-confirmation (SELF -> SELF) must skip logging duplicate override event');

      final updatedCow = provider.cows.firstWhere((c) => c.id == cow.id);
      expect(updatedCow.confirmationDate, equals('2026-08-26'), reason: 'Confirmation date should be updated');
      expect(updatedCow.confirmationMethod, equals('SELF'));
    });
  });

  // ---------------------------------------------------------------------------
  // Phase 4 — Add Cow Direct Confirmation Tests
  // ---------------------------------------------------------------------------
  group('Phase 4 — Add Cow Direct Confirmation Tests', () {
    test('addCow as PREGNANT with mating date immediately sets is_pregnancy_confirmed = 1 and method = SELF', () async {
      DatabaseHelper.initForPlatform();
      final repo = CowRepository();
      final provider = CowProvider(repository: repo);
      final userId = 401;

      final todayStr = '2026-09-09';
      final cow = await repo.addCow(
        userId: userId,
        tagNumber: 'P4_PREG_${DateTime.now().microsecondsSinceEpoch}',
        name: 'Direct Pregnant Cow',
        status: 'PREGNANT',
        matingDate: '2026-06-01',
        hasLactatedBefore: 1,
        isPregnancyConfirmed: 1,
        confirmationDate: todayStr,
        confirmationMethod: 'SELF',
      );

      await provider.fetchCows(userId);
      final savedCow = provider.cows.firstWhere((c) => c.id == cow.id);

      expect(savedCow.status, equals('PREGNANT'));
      expect(savedCow.hasLactatedBefore, equals(1));
      expect(savedCow.matingDate, equals('2026-06-01'));
      expect(savedCow.isPregnancyConfirmed, equals(1), reason: 'Must be confirmed immediately upon insertion, not deferred to Day 29 sweep');
      expect(savedCow.confirmationMethod, equals('SELF'));
      expect(savedCow.confirmationDate, equals(todayStr));
    });

    test('addCow as BRED_HEIFER with mating date immediately sets is_pregnancy_confirmed = 1, method = SELF, and has_lactated_before = 0', () async {
      DatabaseHelper.initForPlatform();
      final repo = CowRepository();
      final provider = CowProvider(repository: repo);
      final userId = 402;

      final todayStr = '2026-09-09';
      final cow = await repo.addCow(
        userId: userId,
        tagNumber: 'P4_HEIF_${DateTime.now().microsecondsSinceEpoch}',
        name: 'Direct Bred Heifer',
        status: 'BRED_HEIFER',
        matingDate: '2026-07-01',
        hasLactatedBefore: 0,
        isPregnancyConfirmed: 1,
        confirmationDate: todayStr,
        confirmationMethod: 'SELF',
      );

      await provider.fetchCows(userId);
      final savedCow = provider.cows.firstWhere((c) => c.id == cow.id);

      expect(savedCow.status, equals('BRED_HEIFER'));
      expect(savedCow.hasLactatedBefore, equals(0), reason: 'BRED_HEIFER must have hasLactatedBefore = 0');
      expect(savedCow.matingDate, equals('2026-07-01'));
      expect(savedCow.isPregnancyConfirmed, equals(1), reason: 'Must be confirmed immediately upon insertion');
      expect(savedCow.confirmationMethod, equals('SELF'));
    });

    test('addCow as DRY without mating date leaves is_pregnancy_confirmed = 0, method = null, and mating_date = null', () async {
      DatabaseHelper.initForPlatform();
      final repo = CowRepository();
      final provider = CowProvider(repository: repo);
      final userId = 403;

      final cow = await repo.addCow(
        userId: userId,
        tagNumber: 'P4_DRY_${DateTime.now().microsecondsSinceEpoch}',
        name: 'Plain Resting Dry Cow',
        status: 'DRY',
        matingDate: null,
        hasLactatedBefore: 1,
        isPregnancyConfirmed: 0,
        confirmationDate: null,
        confirmationMethod: null,
      );

      await provider.fetchCows(userId);
      final savedCow = provider.cows.firstWhere((c) => c.id == cow.id);

      expect(savedCow.status, equals('DRY'));
      expect(savedCow.hasLactatedBefore, equals(1));
      expect(savedCow.matingDate, isNull);
      expect(savedCow.deliveryDate, isNull);
      expect(savedCow.isPregnancyConfirmed, equals(0), reason: 'Plain dry cow without mating date must be unconfirmed');
      expect(savedCow.confirmationMethod, isNull);
    });
  });
}
