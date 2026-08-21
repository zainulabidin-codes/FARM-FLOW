import '../../../../core/database/database_helper.dart';
import '../../../milk_entry/data/datasources/ledger_local_datasource.dart';
import '../../../milk_entry/data/models/ledger_entry_model.dart';
import '../datasources/dodi_local_datasource.dart';
import '../models/dodi_dashboard_summary.dart';
import '../models/dodi_model.dart';

/// Business-logic layer for all Dodi and Ledger operations.
///
/// This repository is the single source of truth for:
///   • Creating and listing Dodis.
///   • The critical dashboard aggregation query.
///   • Recording financial transactions (payments, advances).
class DodiRepository {
  final DodiLocalDatasource _dodiDatasource;
  final LedgerLocalDatasource _ledgerDatasource;

  DodiRepository({
    DodiLocalDatasource? dodiDatasource,
    LedgerLocalDatasource? ledgerDatasource,
  })  : _dodiDatasource = dodiDatasource ?? DodiLocalDatasource(),
        _ledgerDatasource = ledgerDatasource ?? LedgerLocalDatasource();

  // ── Dodi CRUD ─────────────────────────────────────────────────────────────

  /// Pre-flight duplicate firewall check.
  Future<Map<String, bool>?> checkBuyerExists({
    required int userId,
    required String name,
    String? phone,
    int? excludeDodiId,
  }) {
    return _dodiDatasource.checkBuyerExists(
      userId: userId,
      name: name,
      phone: phone,
      excludeDodiId: excludeDodiId,
    );
  }

  /// Creates a new dodi and returns the saved [DodiModel] with its DB id.
  ///
  /// [ratePaise] is the UI-provided rate in paise.
  Future<DodiModel> addDodi({
    required int userId,
    required String name,
    String? phone,
    required int ratePaise,
  }) async {

    final dodi = DodiModel(
      userId: userId,
      name: name.trim(),
      phone: phone?.trim().isEmpty == true ? null : phone?.trim(),
      defaultRatePaise: ratePaise,
    );

    final id = await _dodiDatasource.insertDodi(dodi);
    return DodiModel(
      id: id,
      userId: dodi.userId,
      name: dodi.name,
      phone: dodi.phone,
      defaultRatePaise: dodi.defaultRatePaise,
    );
  }

  /// Returns all dodis for [userId].
  Future<List<DodiModel>> getAllDodis(int userId) {
    return _dodiDatasource.getAllDodis(userId);
  }

  /// Returns transaction record count for [dodiId].
  Future<int> getLedgerCount(int dodiId) {
    return _dodiDatasource.getLedgerCount(dodiId);
  }

  /// Returns all soft-deleted / archived dodis in the Bin.
  Future<List<DodiModel>> getDeletedDodis(int userId) {
    return _dodiDatasource.getDeletedDodis(userId);
  }

  /// Restores a dodi from the Bin back to active status.
  Future<void> restoreDodi(int dodiId) {
    return _dodiDatasource.restoreDodi(dodiId);
  }

  /// Moves a dodi to the Bin.
  Future<void> softDeleteDodi(int dodiId) {
    return _dodiDatasource.softDeleteDodi(dodiId);
  }

  /// Permanently deletes a dodi and their associated ledger entries.
  Future<void> hardDeleteDodi(int dodiId) {
    return _dodiDatasource.hardDeleteDodi(dodiId);
  }

  /// Legacy helper for deleting a dodi safely.
  Future<void> deleteDodi(int dodiId) {
    return _dodiDatasource.deleteDodi(dodiId);
  }

  /// Updates an existing dodi.
  Future<void> updateDodi(DodiModel dodi) {
    return _dodiDatasource.updateDodi(dodi);
  }

  // ── Dashboard aggregation ─────────────────────────────────────────────────

  /// Computes the financial summary for a single dodi using a raw SQL
  /// aggregation query.
  ///
  /// WHY RAW SQL:
  ///   The query uses CASE WHEN expressions that cannot be expressed with
  ///   sqflite's helper methods. rawQuery gives us full SQLite control.
  ///
  /// SIGN CONVENTION enforced by the DB schema:
  ///   MILK_SOLD        amount_paise → positive  (money owed to farmer)
  ///   PAYMENT_RECEIVED amount_paise → negative  (cash received, reduces debt)
  ///   ADVANCE_TAKEN    amount_paise → negative  (advance given, reduces debt)
  ///
  /// Therefore SUM(amount_paise) naturally yields the net amount still due.
  Future<DodiDashboardSummary> getDodiSummary(int dodiId) async {
    final db = await DatabaseHelper.instance.database;

    // ── THE CRITICAL RAW QUERY ─────────────────────────────────────────────
    // Do NOT simplify or convert to Flutter helpers — this query is specified
    // by the system architect and must be preserved exactly.
    final List<Map<String, dynamic>> rows = await db.rawQuery('''
      SELECT
        SUM(CASE WHEN type = 'MILK_SOLD' THEN quantity_grams ELSE 0 END) AS total_milk_grams,
        SUM(CASE WHEN type = 'MILK_SOLD' THEN amount_paise   ELSE 0 END) AS grand_total_paise,
        SUM(CASE WHEN type = 'PAYMENT_RECEIVED' THEN ABS(amount_paise) ELSE 0 END) AS amount_taken_paise,
        SUM(amount_paise) AS amount_due_paise
      FROM ledger
      WHERE dodi_id = ?
    ''', [dodiId]);

    // ── Parse integers from the result map ────────────────────────────────
    // SQLite returns NULL for SUM() on an empty set — guard with ?? 0.
    // All values stay as integers; division by 100.0 happens only in the UI
    // via DodiDashboardSummary's display getters.
    if (rows.isEmpty) return DodiDashboardSummary.empty;

    final Map<String, dynamic> row = rows.first;
    return DodiDashboardSummary(
      totalMilkGrams: (row['total_milk_grams'] as num?)?.toInt() ?? 0,
      grandTotalPaise: (row['grand_total_paise'] as num?)?.toInt() ?? 0,
      amountTakenPaise: (row['amount_taken_paise'] as num?)?.toInt() ?? 0,
      amountDuePaise: (row['amount_due_paise'] as num?)?.toInt() ?? 0,
    );
  }

  // ── Financial transactions ────────────────────────────────────────────────

  /// Records a payment received from a dodi.
  ///
  /// [amountString] is the UI string (e.g. "500.00" → rupees).
  /// Stored as NEGATIVE paise to reduce the outstanding balance.
  Future<void> recordPayment({
    required int dodiId,
    required String amountString,
    required String date,
  }) async {
    final double amountDouble = double.parse(amountString.trim());
    // Negative because PAYMENT_RECEIVED reduces the dodi's debt.
    final int amountPaise = -((amountDouble * 100).round());

    final entry = LedgerEntryModel(
      dodiId: dodiId,
      type: LedgerEntryType.paymentReceived,
      date: date,
      amountPaise: amountPaise,
    );

    await _ledgerDatasource.insertLedgerEntry(entry);
  }

  /// Records an advance taken by a dodi.
  ///
  /// [amountString] is the UI string (e.g. "200.00" → rupees).
  /// Stored as NEGATIVE paise.
  Future<void> recordAdvance({
    required int dodiId,
    required String amountString,
    required String date,
  }) async {
    final double amountDouble = double.parse(amountString.trim());
    final int amountPaise = -((amountDouble * 100).round());

    final entry = LedgerEntryModel(
      dodiId: dodiId,
      type: LedgerEntryType.advanceTaken,
      date: date,
      amountPaise: amountPaise,
    );

    await _ledgerDatasource.insertLedgerEntry(entry);
  }

  /// Returns all ledger rows for a given dodi, newest-first.
  Future<List<LedgerEntryModel>> getLedgerEntries(int dodiId) {
    return _ledgerDatasource.getEntriesForDodi(dodiId);
  }

  /// Deletes a ledger entry by id.
  Future<void> deleteLedgerEntry(int entryId) {
    return _ledgerDatasource.deleteLedgerEntry(entryId);
  }
}
