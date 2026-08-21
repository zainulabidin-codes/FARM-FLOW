import 'package:sqflite/sqflite.dart';

import '../../../../core/database/database_helper.dart';
import '../../../milk_entry/data/models/ledger_entry_model.dart';

/// Low-level SQLite access for the `ledger` table.
///
/// Intentionally kept to a single write method here.  Read queries
/// (including the complex aggregation) live in [DodiRepository] which
/// calls [rawQuery] directly for full SQL control.
class LedgerLocalDatasource {
  /// Persists [entry] into the `ledger` table.
  ///
  /// Returns the auto-generated row id.
  ///
  /// CALLER RESPONSIBILITY: [entry.amountPaise] must already carry the correct
  /// sign before this method is called:
  ///   • MILK_SOLD        → positive  (+paise)
  ///   • PAYMENT_RECEIVED → negative  (-paise)
  ///   • ADVANCE_TAKEN    → negative  (-paise)
  Future<int> insertLedgerEntry(LedgerEntryModel entry) async {
    final Database db = await DatabaseHelper.instance.database;
    return db.insert(
      'ledger',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.fail,
    );
  }

  /// Returns all ledger rows for [dodiId], newest-first.
  ///
  /// Used by the dodi-detail screen to show a full transaction history.
  Future<List<LedgerEntryModel>> getEntriesForDodi(int dodiId) async {
    final Database db = await DatabaseHelper.instance.database;

    final List<Map<String, dynamic>> rows = await db.query(
      'ledger',
      where: 'dodi_id = ?',
      whereArgs: [dodiId],
      orderBy: 'date DESC, id DESC',
    );

    return rows.map(LedgerEntryModel.fromMap).toList();
  }

  /// Deletes a ledger entry.
  Future<void> deleteLedgerEntry(int entryId) async {
    final Database db = await DatabaseHelper.instance.database;
    await db.delete(
      'ledger',
      where: 'id = ?',
      whereArgs: [entryId],
    );
  }

  /// Updates a ledger entry.
  Future<void> updateLedgerEntry(LedgerEntryModel entry) async {
    if (entry.id == null) throw ArgumentError('Entry ID cannot be null for update');
    final Database db = await DatabaseHelper.instance.database;
    await db.update(
      'ledger',
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  /// Checks if a milk entry already exists for a specific buyer, date, and session.
  Future<LedgerEntryModel?> getExistingEntryForShift(int dodiId, String date, String session) async {
    final Database db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> rows = await db.query(
      'ledger',
      where: "dodi_id = ? AND type = 'MILK_SOLD' AND date = ? AND session = ?",
      whereArgs: [dodiId, date, session.trim().toUpperCase()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return LedgerEntryModel.fromMap(rows.first);
  }
}
