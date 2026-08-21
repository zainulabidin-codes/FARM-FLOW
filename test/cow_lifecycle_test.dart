import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:dairy_farm_app/core/database/database_helper.dart';
import 'package:dairy_farm_app/core/utils/pregnancy_display_utils.dart';
import 'package:dairy_farm_app/features/cows/data/datasources/cow_local_datasource.dart';
import 'package:dairy_farm_app/features/cows/data/repositories/cow_repository.dart';

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
}
