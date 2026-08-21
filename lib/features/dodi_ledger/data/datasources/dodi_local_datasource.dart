import 'package:sqflite/sqflite.dart';

import '../../../../core/database/database_helper.dart';
import '../models/dodi_model.dart';

/// Low-level SQLite access for the `dodis` table.
///
/// Only raw INSERT / SELECT lives here.  Business logic belongs in
/// [DodiRepository].
class DodiLocalDatasource {
  /// Inserts [dodi] into the `dodis` table and returns the generated row id.
  Future<int> insertDodi(DodiModel dodi) async {
    final Database db = await DatabaseHelper.instance.database;
    return db.insert(
      'dodis',
      dodi.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  /// Checks if a dodi with the same name (case-insensitive) or phone number already exists for [userId].
  /// If [excludeDodiId] is passed, it ignores that ID (used when editing an existing buyer).
  /// Returns a map with conflict flags `{'nameConflict': bool, 'phoneConflict': bool}` or `null` if unique.
  Future<Map<String, bool>?> checkBuyerExists({
    required int userId,
    required String name,
    String? phone,
    int? excludeDodiId,
  }) async {
    final Database db = await DatabaseHelper.instance.database;

    final cleanName = name.trim();
    final cleanPhone = phone?.replaceAll(RegExp(r'\D'), '').trim();

    String query = 'SELECT id, LOWER(TRIM(name)) as low_name, phone FROM dodis WHERE user_id = ? AND (is_deleted = 0 OR is_deleted IS NULL)';
    List<dynamic> args = [userId];

    if (excludeDodiId != null) {
      query += ' AND id != ?';
      args.add(excludeDodiId);
    }

    final rows = await db.rawQuery(query, args);

    bool nameConflict = false;
    bool phoneConflict = false;

    for (final row in rows) {
      final existingLowName = row['low_name'] as String?;
      final rawPhone = row['phone'] as String?;
      final existingPhone = rawPhone?.replaceAll(RegExp(r'\D'), '').trim();

      if (existingLowName != null && existingLowName == cleanName.toLowerCase()) {
        nameConflict = true;
      }

      if (cleanPhone != null && cleanPhone.isNotEmpty && existingPhone != null && existingPhone.isNotEmpty && existingPhone == cleanPhone) {
        phoneConflict = true;
      }
    }

    if (nameConflict || phoneConflict) {
      return {
        'nameConflict': nameConflict,
        'phoneConflict': phoneConflict,
      };
    }

    return null;
  }

  /// Returns every active dodi belonging to [userId], ordered by name ascending.
  Future<List<DodiModel>> getAllDodis(int userId) async {
    final Database db = await DatabaseHelper.instance.database;

    final List<Map<String, dynamic>> rows = await db.query(
      'dodis',
      where: 'user_id = ? AND (is_deleted = 0 OR is_deleted IS NULL)',
      whereArgs: [userId],
      orderBy: 'name ASC',
    );

    return rows.map(DodiModel.fromMap).toList();
  }

  /// Returns the number of ledger transaction entries for a given [dodiId].
  Future<int> getLedgerCount(int dodiId) async {
    final Database db = await DatabaseHelper.instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM ledger WHERE dodi_id = ?', [dodiId]);
    if (result.isEmpty) return 0;
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Returns all soft-deleted / archived dodis in the Bin for [userId].
  Future<List<DodiModel>> getDeletedDodis(int userId) async {
    final Database db = await DatabaseHelper.instance.database;

    final List<Map<String, dynamic>> rows = await db.query(
      'dodis',
      where: 'user_id = ? AND is_deleted = 1',
      whereArgs: [userId],
      orderBy: 'name ASC',
    );

    return rows.map(DodiModel.fromMap).toList();
  }

  /// Restores a soft-deleted dodi from the Bin back to active status.
  Future<void> restoreDodi(int dodiId) async {
    final Database db = await DatabaseHelper.instance.database;
    await db.update(
      'dodis',
      {'is_deleted': 0},
      where: 'id = ?',
      whereArgs: [dodiId],
    );
  }

  /// Moves a dodi to the Bin (sets `is_deleted = 1`).
  Future<void> softDeleteDodi(int dodiId) async {
    final Database db = await DatabaseHelper.instance.database;
    await db.update(
      'dodis',
      {'is_deleted': 1},
      where: 'id = ?',
      whereArgs: [dodiId],
    );
  }

  /// Permanently erases a dodi and their associated ledger records from SQLite.
  Future<void> hardDeleteDodi(int dodiId) async {
    final Database db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      await txn.delete('ledger', where: 'dodi_id = ?', whereArgs: [dodiId]);
      await txn.delete('dodis', where: 'id = ?', whereArgs: [dodiId]);
    });
  }

  /// Legacy helper for deleting a dodi safely.
  Future<void> deleteDodi(int dodiId) async {
    await softDeleteDodi(dodiId);
  }

  /// Updates an existing dodi.
  Future<int> updateDodi(DodiModel dodi) async {
    final Database db = await DatabaseHelper.instance.database;
    return db.update(
      'dodis',
      dodi.toMap(),
      where: 'id = ?',
      whereArgs: [dodi.id],
    );
  }
}
