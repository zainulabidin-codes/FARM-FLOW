import 'package:sqflite/sqflite.dart';

import '../../../../core/database/database_helper.dart';
import '../models/cow_model.dart';

/// Low-level SQLite access for the cows table.
///
/// Keeps raw INSERT / SELECT / UPDATE queries isolated from business logic.
class CowLocalDatasource {
  /// Inserts [cow] into the cows table and returns the generated row id.
  Future<int> insertCow(CowModel cow) async {
    final Database db = await DatabaseHelper.instance.database;
    return db.insert(
      'cows',
      cow.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  /// Returns all active (not deleted) cows for the given [userId],
  /// sorted by creation date descending.
  Future<List<CowModel>> getAllCows(int userId) async {
    final Database db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'cows',
      where: 'user_id = ? AND is_deleted = 0',
      whereArgs: [userId],
      orderBy: 'id DESC',
    );

    return List.generate(maps.length, (i) {
      return CowModel.fromMap(maps[i]);
    });
  }

  /// Returns a set of cow IDs owned by the user that have at least one milking season.
  Future<Set<int>> getCowsWithMilkingSeasons(int userId) async {
    final Database db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> rows = await db.rawQuery('''
      SELECT DISTINCT m.cow_id 
      FROM milking_seasons m
      INNER JOIN cows c ON m.cow_id = c.id
      WHERE c.user_id = ? AND c.is_deleted = 0
    ''', [userId]);

    return rows.map((row) => row['cow_id'] as int).toSet();
  }

  /// Transactional lifecycle manager enforcing database invariants:
  ///   1. MILKING => exactly one active season (auto-created if none exists).
  ///   2. DRY / DELETED => zero active seasons (closes open seasons).
  ///   3. Max one active season per cow.
  ///   4. Historical seasons remain immutable except for closure.
  Future<void> transitionCowLifecycle(
    Transaction txn, {
    required int cowId,
    required String newStatus,
    String? transitionDate,
  }) async {
    final now = DateTime.now();
    final dateStr = transitionDate ??
        "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    if (newStatus == 'DRY') {
      // Invariant: DRY => zero active seasons
      await txn.update(
        'milking_seasons',
        {'season_end_date': dateStr},
        where: 'cow_id = ? AND season_end_date IS NULL',
        whereArgs: [cowId],
      );
    } else if (newStatus == 'MILKING') {
      // Invariant: MILKING => exactly one active season
      final activeSeasons = await txn.query(
        'milking_seasons',
        where: 'cow_id = ? AND season_end_date IS NULL',
        whereArgs: [cowId],
      );
      if (activeSeasons.isEmpty) {
        await txn.insert('milking_seasons', {
          'cow_id': cowId,
          'season_start_date': dateStr,
        });
      } else if (activeSeasons.length > 1) {
        // Enforce max 1 active season invariant: close duplicate extra active seasons
        for (int i = 1; i < activeSeasons.length; i++) {
          await txn.update(
            'milking_seasons',
            {'season_end_date': dateStr},
            where: 'id = ?',
            whereArgs: [activeSeasons[i]['id']],
          );
        }
      }
    }
  }

  /// Updates just the status field for the cow with [cowId].
  Future<void> updateCowStatus(int cowId, String newStatus) async {
    final Database db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      await txn.update(
        'cows',
        {'status': newStatus},
        where: 'id = ?',
        whereArgs: [cowId],
      );
      await transitionCowLifecycle(txn, cowId: cowId, newStatus: newStatus);
    });
  }

  /// General manual update of cow details from the Edit form.
  Future<void> updateCowGeneral({
    required int cowId,
    required String name,
    required String tagNumber,
    required String status,
    String? matingDate,
    String? deliveryDate,
    required int hasLactatedBefore,
    String? estimatedBirthDate,
  }) async {
    final Database db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      await txn.update(
        'cows',
        {
          'name': name,
          'tag_number': tagNumber,
          'status': status,
          'mating_date': matingDate,
          'delivery_date': deliveryDate,
          'has_lactated_before': hasLactatedBefore,
          'estimated_birth_date': estimatedBirthDate,
        },
        where: 'id = ?',
        whereArgs: [cowId],
      );
      await transitionCowLifecycle(txn, cowId: cowId, newStatus: status);
    });
  }

  /// Updates mating date, expected delivery date, and status.
  Future<void> updateMatingAndDeliveryDate({
    required int cowId,
    required String matingDate,
    required String deliveryDate,
    required String newStatus,
  }) async {
    final Database db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      await txn.update(
        'cows',
        {
          'mating_date': matingDate,
          'delivery_date': deliveryDate,
          'status': newStatus,
        },
        where: 'id = ?',
        whereArgs: [cowId],
      );
      await transitionCowLifecycle(txn, cowId: cowId, newStatus: newStatus);
    });
  }

  /// Clears mating/delivery dates, sets status to MILKING, locks has_lactated_before to 1, and opens a new milking season.
  Future<void> recordCalving(int cowId, String deliveryDateString) async {
    final Database db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      await txn.update(
        'cows',
        {
          'mating_date': null,
          'delivery_date': null,
          'status': 'MILKING',
          'has_lactated_before': 1,
        },
        where: 'id = ?',
        whereArgs: [cowId],
      );

      final activeSeasons = await txn.query(
        'milking_seasons',
        where: 'cow_id = ? AND season_end_date IS NULL',
        whereArgs: [cowId],
      );
      if (activeSeasons.isNotEmpty) {
        await txn.update(
          'milking_seasons',
          {'season_end_date': deliveryDateString},
          where: 'id = ?',
          whereArgs: [activeSeasons.first['id']],
        );
      }

      await txn.insert('milking_seasons', {
        'cow_id': cowId,
        'season_start_date': deliveryDateString,
      });
    });
  }

  /// Marks the cow as deleted (soft delete).
  Future<void> softDeleteCow(int cowId, String reason, String deletedAt) async {
    final Database db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      await txn.update(
        'cows',
        {
          'is_deleted': 1,
          'deleted_reason': reason,
          'deleted_date': deletedAt,
        },
        where: 'id = ?',
        whereArgs: [cowId],
      );
      await txn.update(
        'milking_seasons',
        {'season_end_date': deletedAt},
        where: 'cow_id = ? AND season_end_date IS NULL',
        whereArgs: [cowId],
      );
    });
  }

  /// Permanently removes cows soft-deleted more than [retentionDays] (default 365) ago.
  Future<int> purgeExpiredDeletedCows({int retentionDays = 365}) async {
    final Database db = await DatabaseHelper.instance.database;
    final cutoffDate = DateTime.now()
        .subtract(Duration(days: retentionDays))
        .toIso8601String();

    return await db.transaction((txn) async {
      return await txn.rawDelete('''
        DELETE FROM cows 
        WHERE is_deleted = 1 
          AND deleted_date IS NOT NULL 
          AND deleted_date < ?
      ''', [cutoffDate]);
    });
  }

  // --- Milking Season & Yield Logic ---

  Future<void> runStartupRollups() async {
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      final now = DateTime.now();
      final currentYearMonth = "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}";

      final activeSeasons = await txn.query('milking_seasons', where: 'season_end_date IS NULL');
      
      for (var season in activeSeasons) {
        final seasonId = season['id'] as int;
        final cowId = season['cow_id'] as int;

        final pastSessions = await txn.query(
          'cow_milk_sessions',
          where: 'season_id = ? AND date < ?',
          whereArgs: [seasonId, "$currentYearMonth-01"],
          orderBy: 'date ASC',
        );

        if (pastSessions.isEmpty) continue;

        final Map<String, List<Map<String, dynamic>>> byMonth = {};
        for (var row in pastSessions) {
          final date = row['date'] as String;
          final ym = date.substring(0, 7);
          byMonth.putIfAbsent(ym, () => []).add(row);
        }

        for (var entry in byMonth.entries) {
          final ym = entry.key;
          final rows = entry.value;
          await _rollupMonth(txn, cowId, seasonId, ym, rows);
        }
      }
    });
  }

  Future<void> _rollupMonth(Transaction txn, int cowId, int seasonId, String yearMonth, List<Map<String, dynamic>> rawRows) async {
    if (rawRows.isEmpty) return;
    
    int highestGrams = -1;
    String highestDate = '';
    String highestSession = '';
    
    int lowestGrams = 99999999;
    String lowestDate = '';
    String lowestSession = '';

    for (var row in rawRows) {
      final grams = row['quantity_grams'] as int;
      final date = row['date'] as String;
      final session = row['session'] as String;

      if (grams > highestGrams) {
        highestGrams = grams;
        highestDate = date;
        highestSession = session;
      }
      if (grams < lowestGrams) {
        lowestGrams = grams;
        lowestDate = date;
        lowestSession = session;
      }
    }

    await txn.insert('cow_milk_monthly_summary', {
      'cow_id': cowId,
      'season_id': seasonId,
      'year_month': yearMonth,
      'highest_grams': highestGrams,
      'highest_date': highestDate,
      'highest_session': highestSession,
      'lowest_grams': lowestGrams,
      'lowest_date': lowestDate,
      'lowest_session': lowestSession,
      'rolled_up_at': DateTime.now().toIso8601String(),
    });

    await txn.delete(
      'cow_milk_sessions',
      where: 'season_id = ? AND date LIKE ?',
      whereArgs: [seasonId, "$yearMonth-%"],
    );
  }

  Future<void> closeActiveSeason(int cowId, String endDate) async {
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      final rows = await txn.query('milking_seasons', where: 'cow_id = ? AND season_end_date IS NULL', whereArgs: [cowId], limit: 1);
      if (rows.isEmpty) return;
      final seasonId = rows.first['id'] as int;

      final remainingRaw = await txn.query('cow_milk_sessions', where: 'season_id = ?', whereArgs: [seasonId]);
      final summaryRows = await txn.query('cow_milk_monthly_summary', where: 'season_id = ?', whereArgs: [seasonId]);
      
      int? highestGrams;
      String? highestDate;
      String? highestSession;
      int? lowestGrams;
      String? lowestDate;
      String? lowestSession;

      void checkBeat(int grams, String date, String session) {
        if (highestGrams == null || grams > highestGrams!) {
          highestGrams = grams;
          highestDate = date;
          highestSession = session;
        }
        if (lowestGrams == null || grams < lowestGrams!) {
          lowestGrams = grams;
          lowestDate = date;
          lowestSession = session;
        }
      }

      for (var row in summaryRows) {
        checkBeat(row['highest_grams'] as int, row['highest_date'] as String, row['highest_session'] as String);
        checkBeat(row['lowest_grams'] as int, row['lowest_date'] as String, row['lowest_session'] as String);
      }

      for (var row in remainingRaw) {
        checkBeat(row['quantity_grams'] as int, row['date'] as String, row['session'] as String);
      }

      await txn.update(
        'milking_seasons',
        {
          'season_end_date': endDate,
          'season_highest_grams': highestGrams,
          'season_highest_date': highestDate,
          'season_highest_session': highestSession,
          'season_lowest_grams': lowestGrams,
          'season_lowest_date': lowestDate,
          'season_lowest_session': lowestSession,
        },
        where: 'id = ?',
        whereArgs: [seasonId],
      );
    });
  }

  Future<void> logDailyYield(int cowId, String date, int? morningGrams, int? eveningGrams) async {
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      int seasonId;
      final seasonRows = await txn.query('milking_seasons', where: 'cow_id = ? AND season_end_date IS NULL', whereArgs: [cowId], limit: 1);
      if (seasonRows.isEmpty) {
        seasonId = await txn.insert('milking_seasons', {'cow_id': cowId, 'season_start_date': date});
      } else {
        seasonId = seasonRows.first['id'] as int;
      }

      final yearMonth = date.substring(0, 7);

      Future<void> upsertSession(String sessionType, int grams) async {
        await txn.insert(
          'cow_milk_sessions', 
          {
            'cow_id': cowId,
            'season_id': seasonId,
            'date': date,
            'session': sessionType,
            'quantity_grams': grams,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      
      // Step A: Unconditional Raw Session Upsert
      if (morningGrams != null) {
        await upsertSession('MORNING', morningGrams);
      }
      if (eveningGrams != null) {
        await upsertSession('EVENING', eveningGrams);
      }

      // Step B: Recalculate Summary
      await _recalculateCurrentMonthSummary(txn, cowId, seasonId, yearMonth);
    });
  }

  Future<Map<String, int?>> getSeasonSessionYields(int cowId) async {
    final db = await DatabaseHelper.instance.database;
    int? peakMorning;
    int? peakEvening;
    int? lowestMorning;
    int? lowestEvening;

    final seasonRows = await db.query(
      'milking_seasons',
      where: 'cow_id = ? AND season_end_date IS NULL',
      whereArgs: [cowId],
      limit: 1,
    );

    if (seasonRows.isEmpty) {
      return {
        'peakMorning': null,
        'peakEvening': null,
        'lowestMorning': null,
        'lowestEvening': null,
      };
    }
    final seasonId = seasonRows.first['id'] as int;

    // 1. Current month's raw data
    final rawRows = await db.rawQuery(
      '''
      SELECT session, MAX(quantity_grams) as max_grams, MIN(quantity_grams) as min_grams
      FROM cow_milk_sessions
      WHERE cow_id = ? AND season_id = ?
      GROUP BY session
      ''',
      [cowId, seasonId],
    );

    for (final row in rawRows) {
      final session = row['session'] as String;
      final maxGrams = row['max_grams'] as int;
      final minGrams = row['min_grams'] as int;
      if (session == 'MORNING') {
        peakMorning = maxGrams;
        lowestMorning = minGrams;
      } else if (session == 'EVENING') {
        peakEvening = maxGrams;
        lowestEvening = minGrams;
      }
    }

    // 2. Prior months' summary data
    final summaryRows = await db.query(
      'cow_milk_monthly_summary',
      where: 'cow_id = ? AND season_id = ?',
      whereArgs: [cowId, seasonId],
    );

    for (final row in summaryRows) {
      final hSession = row['highest_session'] as String;
      final hGrams = row['highest_grams'] as int;
      final lSession = row['lowest_session'] as String;
      final lGrams = row['lowest_grams'] as int;

      if (hSession == 'MORNING') {
        if (peakMorning == null || hGrams > peakMorning) peakMorning = hGrams;
      } else if (hSession == 'EVENING') {
        if (peakEvening == null || hGrams > peakEvening) peakEvening = hGrams;
      }

      if (lSession == 'MORNING') {
        if (lowestMorning == null || lGrams < lowestMorning) lowestMorning = lGrams;
      } else if (lSession == 'EVENING') {
        if (lowestEvening == null || lGrams < lowestEvening) lowestEvening = lGrams;
      }
    }

    return {
      'peakMorning': peakMorning,
      'peakEvening': peakEvening,
      'lowestMorning': lowestMorning,
      'lowestEvening': lowestEvening,
    };
  }

  Future<Map<String, dynamic>?> getLatestSeason(int cowId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'milking_seasons',
      where: 'cow_id = ?',
      whereArgs: [cowId],
      orderBy: 'season_start_date DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<List<Map<String, dynamic>>> getSessionsForSeason(int seasonId) async {
    final db = await DatabaseHelper.instance.database;
    return await db.query(
      'cow_milk_sessions',
      where: 'season_id = ?',
      whereArgs: [seasonId],
      orderBy: 'date DESC, session DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getMonthlySummariesForSeason(int seasonId) async {
    final db = await DatabaseHelper.instance.database;
    return await db.query(
      'cow_milk_monthly_summary',
      where: 'season_id = ?',
      whereArgs: [seasonId],
      orderBy: 'year_month DESC',
    );
  }

  Future<void> deleteMilkSession(int cowId, String date, String session) async {
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      final seasonRows = await txn.query('milking_seasons', where: 'cow_id = ? AND season_end_date IS NULL', whereArgs: [cowId], limit: 1);
      if (seasonRows.isEmpty) return;
      final seasonId = seasonRows.first['id'] as int;

      await txn.delete(
        'cow_milk_sessions',
        where: 'season_id = ? AND date = ? AND session = ?',
        whereArgs: [seasonId, date, session],
      );

      await _recalculateCurrentMonthSummary(txn, cowId, seasonId, date.substring(0, 7));
    });
  }

  Future<void> updateMilkSession(int cowId, String date, String session, int newGrams) async {
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      final seasonRows = await txn.query('milking_seasons', where: 'cow_id = ? AND season_end_date IS NULL', whereArgs: [cowId], limit: 1);
      if (seasonRows.isEmpty) return;
      final seasonId = seasonRows.first['id'] as int;

      await txn.update(
        'cow_milk_sessions',
        {'quantity_grams': newGrams},
        where: 'season_id = ? AND date = ? AND session = ?',
        whereArgs: [seasonId, date, session],
      );

      await _recalculateCurrentMonthSummary(txn, cowId, seasonId, date.substring(0, 7));
    });
  }

  Future<void> _recalculateCurrentMonthSummary(Transaction txn, int cowId, int seasonId, String yearMonth) async {
    final remainingRaw = await txn.query(
      'cow_milk_sessions',
      where: 'season_id = ? AND date LIKE ?',
      whereArgs: [seasonId, '$yearMonth-%'],
    );
    
    if (remainingRaw.isEmpty) {
      await txn.delete('cow_milk_monthly_summary', where: 'season_id = ? AND year_month = ?', whereArgs: [seasonId, yearMonth]);
      return;
    }

    int hGrams = -1;
    String hDate = '';
    String hSession = '';
    int lGrams = 99999999;
    String lDate = '';
    String lSession = '';

    for (var row in remainingRaw) {
      final grams = row['quantity_grams'] as int;
      final d = row['date'] as String;
      final s = row['session'] as String;
      if (grams > hGrams) { hGrams = grams; hDate = d; hSession = s; }
      if (grams < lGrams) { lGrams = grams; lDate = d; lSession = s; }
    }

    final summaryExists = await txn.query('cow_milk_monthly_summary', where: 'season_id = ? AND year_month = ?', whereArgs: [seasonId, yearMonth], limit: 1);
    if (summaryExists.isNotEmpty) {
      await txn.update(
        'cow_milk_monthly_summary',
        {
          'highest_grams': hGrams, 'highest_date': hDate, 'highest_session': hSession,
          'lowest_grams': lGrams, 'lowest_date': lDate, 'lowest_session': lSession,
        },
        where: 'id = ?',
        whereArgs: [summaryExists.first['id']],
      );
    } else {
      await txn.insert('cow_milk_monthly_summary', {
        'cow_id': cowId, 'season_id': seasonId, 'year_month': yearMonth,
        'highest_grams': hGrams, 'highest_date': hDate, 'highest_session': hSession,
        'lowest_grams': lGrams, 'lowest_date': lDate, 'lowest_session': lSession,
        'rolled_up_at': DateTime.now().toIso8601String(),
      });
    }
  }
}
