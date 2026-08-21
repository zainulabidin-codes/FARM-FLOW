import '../../../../core/database/database_helper.dart';
import '../../../../core/utils/money_utils.dart';
import '../../data/datasources/ledger_local_datasource.dart';
import '../models/ledger_entry_model.dart';

/// Business-logic layer for recording milk entries.
///
/// ─── CRITICAL MATH CONTRACT ───────────────────────────────────────────────
/// All arithmetic is performed in integer space.  The only floating-point
/// values are transient parse intermediates — they are converted to integers
/// before being assigned to any variable or passed anywhere.
///
/// Step-by-step for a 30.5 kg entry at ₹5.50/litre:
///   quantityString  = "30.5"
///   quantityDouble  = 30.5          (transient double, never stored)
///   quantityGrams   = 30_500        (integer grams)
///
///   ratePaise       = 550           (integer paise per litre)
///
///   amountPaise     = round(30_500 × 550 / 1_000)
///                   = round(16_775_000 / 1_000)
///                   = round(16_775.0)
///                   = 16_775        (integer paise = ₹167.75)
/// ──────────────────────────────────────────────────────────────────────────
class MilkEntryRepository {
  final LedgerLocalDatasource _ledgerDatasource;

  MilkEntryRepository({LedgerLocalDatasource? ledgerDatasource})
      : _ledgerDatasource = ledgerDatasource ?? LedgerLocalDatasource();

  // ── Record milk entry ──────────────────────────────────────────────────────

  /// Parses UI strings, computes integer amounts, and persists to the ledger.
  ///
  /// Parameters:
  ///   [dodiId]         — FK to the dodis table.
  ///   [quantityString] — milk collected as a string (kg, e.g. "30.5").
  ///   [ratePaise]      — price per litre in paise.
  ///   [session]        — "MORNING" or "EVENING".
  ///   [date]           — ISO-8601 date string from the UI (e.g. "2026-07-09").
  ///
  /// Returns the new ledger row id on success.
  ///
  /// Throws [FormatException] if [quantityString] cannot be
  /// parsed — callers should validate input before calling this method.
  Future<int> recordMilkEntry({
    required int dodiId,
    required String quantityString,
    required int ratePaise,
    required String session,
    required String date,
    String? loadTag,
  }) async {
    final int quantityGrams = MoneyUtils.kgToGrams(quantityString);
    final int amountPaise = MoneyUtils.calculateMilkSalePaise(quantityGrams, ratePaise);

    // ── Step 4: Build the ledger entry ─────────────────────────────────────
    // MILK_SOLD is always POSITIVE paise (money owed TO the farmer).
    final LedgerEntryModel entry = LedgerEntryModel(
      dodiId: dodiId,
      type: LedgerEntryType.milkSold,
      date: date,
      session: session.trim().toUpperCase(),
      loadTag: loadTag?.trim().isEmpty == true ? null : loadTag?.trim(),
      quantityGrams: quantityGrams,
      ratePaise: ratePaise,
      amountPaise: amountPaise, // positive
    );

    return _ledgerDatasource.insertLedgerEntry(entry);
  }

  // ── Update milk entry ──────────────────────────────────────────────────────

  Future<void> updateMilkEntry({
    required int entryId,
    required int dodiId,
    required String quantityString,
    required int ratePaise,
    required String session,
    required String date,
    String? loadTag,
  }) async {
    final int quantityGrams = MoneyUtils.kgToGrams(quantityString);
    final int amountPaise = MoneyUtils.calculateMilkSalePaise(quantityGrams, ratePaise);

    final LedgerEntryModel entry = LedgerEntryModel(
      id: entryId,
      dodiId: dodiId,
      type: LedgerEntryType.milkSold,
      date: date,
      session: session.trim().toUpperCase(),
      loadTag: loadTag?.trim().isEmpty == true ? null : loadTag?.trim(),
      quantityGrams: quantityGrams,
      ratePaise: ratePaise,
      amountPaise: amountPaise, // positive
    );

    await _ledgerDatasource.updateLedgerEntry(entry);
  }

  // ── Today's total milk ─────────────────────────────────────────────────────

  /// Returns the total milk collected across ALL dodis for [date], in GRAMS.
  ///
  /// Uses rawQuery for the SUM aggregation — no Flutter helper equivalent.
  /// Uses COALESCE to guarantee a 0 instead of NULL when no rows match.
  ///
  /// [date] must be ISO-8601 format: "YYYY-MM-DD".
  Future<int> getTodaysTotalMilkGrams(String date) async {
    final db = await DatabaseHelper.instance.database;

    final List<Map<String, dynamic>> rows = await db.rawQuery(
      "SELECT COALESCE(SUM(quantity_grams), 0) AS total FROM ledger "
      "WHERE type = 'MILK_SOLD' AND date = ?",
      [date],
    );

    if (rows.isEmpty) return 0;
    return (rows.first['total'] as num).toInt();
  }

  /// Returns the total milk collected across ALL dodis for [date] and [session], in GRAMS.
  ///
  /// [session] must be "MORNING" or "EVENING".
  Future<int> getTodaysSessionMilkGrams(String date, String session) async {
    final db = await DatabaseHelper.instance.database;

    final List<Map<String, dynamic>> rows = await db.rawQuery(
      "SELECT COALESCE(SUM(quantity_grams), 0) AS total FROM ledger "
      "WHERE type = 'MILK_SOLD' AND date = ? AND session = ?",
      [date, session],
    );

    if (rows.isEmpty) return 0;
    return (rows.first['total'] as num).toInt();
  }

  /// Convenience: returns today's total milk in grams using today's date.
  Future<int> getTodaysTotalMilkGramsForToday() {
    final DateTime now = DateTime.now();
    final String today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return getTodaysTotalMilkGrams(today);
  }

  /// Convenience: returns today's session milk in grams using today's date.
  Future<int> getTodaysSessionMilkGramsForToday(String session) {
    final DateTime now = DateTime.now();
    final String today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return getTodaysSessionMilkGrams(today, session);
  }

  /// Checks if a milk entry already exists for a specific buyer, date, and session.
  Future<LedgerEntryModel?> checkExistingEntry({
    required int dodiId,
    required String session,
    required String date,
  }) async {
    return _ledgerDatasource.getExistingEntryForShift(dodiId, date, session);
  }
}
