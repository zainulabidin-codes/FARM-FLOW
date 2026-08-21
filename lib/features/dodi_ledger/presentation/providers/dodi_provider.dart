import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Icons;

import '../../data/models/dodi_dashboard_summary.dart';
import '../../data/models/dodi_model.dart';
import '../../data/repositories/dodi_repository.dart';
import '../../../milk_entry/data/models/ledger_entry_model.dart';
import '../../../dashboard/data/models/activity_log_model.dart';
import '../../../dashboard/data/repositories/activity_log_repository.dart';

/// Loading state for async dodi operations.
enum DodiStatus { idle, loading, success, error }

/// ChangeNotifier provider for all Dodi-related UI state.
///
/// Responsibilities:
///   • Holds the list of [DodiModel] for the current logged-in farmer.
///   • Holds per-dodi [DodiDashboardSummary] in a cache map (keyed by dodiId)
///     so navigating back to a dodi detail screen doesn't re-query the DB.
///   • Exposes add-dodi and fetch-summary actions.
class DodiProvider extends ChangeNotifier {
  final DodiRepository _repository;
  final ActivityLogRepository _activityRepo = ActivityLogRepository();

  DodiProvider({DodiRepository? repository})
      : _repository = repository ?? DodiRepository();

  // ── State ─────────────────────────────────────────────────────────────────

  DodiStatus _status = DodiStatus.idle;
  DodiStatus get status => _status;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<DodiModel> _dodis = [];
  List<DodiModel> get dodis => List.unmodifiable(_dodis);

  List<DodiModel> _deletedDodis = [];
  List<DodiModel> get deletedDodis => List.unmodifiable(_deletedDodis);

  /// Cache: dodiId → summary.  Cleared whenever dodis are reloaded.
  final Map<int, DodiDashboardSummary> _summaryCache = {};

  /// Cache: dodiId → ledger entries.
  final Map<int, List<LedgerEntryModel>> _ledgerCache = {};

  /// Returns the cached summary for [dodiId], or null if not yet fetched.
  DodiDashboardSummary? getCachedSummary(int dodiId) => _summaryCache[dodiId];

  /// Returns the cached ledger entries for [dodiId], or null if not yet fetched.
  List<LedgerEntryModel>? getCachedLedgerEntries(int dodiId) => _ledgerCache[dodiId];

  // ── Private helpers ───────────────────────────────────────────────────────

  void _setLoading() {
    _status = DodiStatus.loading;
    _errorMessage = null;
    notifyListeners();
  }

  void _setError(String message) {
    _status = DodiStatus.error;
    _errorMessage = message;
    notifyListeners();
  }

  // ── Public actions ────────────────────────────────────────────────────────

  /// Loads all dodis for [userId] from the database.
  ///
  /// Call this once after login and after adding a new dodi.
  Future<void> loadDodis(int userId) async {
    _setLoading();
    try {
      _dodis = await _repository.getAllDodis(userId);
      // Invalidate stale caches ONLY if we explicitly want to, otherwise leave them 
      // intact so returning to the Dodi detail screen doesn't show an endless loading state.

      _status = DodiStatus.success;
      notifyListeners();
    } catch (e) {
      _setError('Failed to load dodis: $e');
    }
  }

  /// Creates a new dodi and refreshes the dodi list.
  ///
  /// [userId] — the currently logged-in farmer's id.
  /// [ratePaise] — rate in paise.
  Future<bool> addDodi({
    required int userId,
    required String name,
    String? phone,
    required int ratePaise,
  }) async {
    _setLoading();
    try {
      final conflicts = await _repository.checkBuyerExists(
        userId: userId,
        name: name,
        phone: phone,
      );

      if (conflicts != null) {
        if (conflicts['nameConflict'] == true) {
          _setError('A buyer named "${name.trim()}" already exists.');
          return false;
        }
        if (conflicts['phoneConflict'] == true) {
          final cleanPh = phone?.replaceAll(RegExp(r'\D'), '');
          _setError('Phone number "$cleanPh" is already registered to another buyer.');
          return false;
        }
      }

      await _repository.addDodi(
        userId: userId,
        name: name,
        phone: phone,
        ratePaise: ratePaise,
      );

      await _activityRepo.logActivity(ActivityLogModel(
        userId: userId,
        title: 'Buyer Added',
        subtitle: name,
        value: 'Rate: Rs ${(ratePaise / 100).toStringAsFixed(2)}/Kg',
        timeUnix: DateTime.now().millisecondsSinceEpoch,
        iconCode: Icons.person_add_alt_1_rounded.codePoint,
        isPositive: 1,
        metadata: {
          'phone': phone,
        },
      ));

      // Reload the full list so the UI reflects the new entry.
      await loadDodis(userId);
      return true;
    } catch (e) {
      _setError('Failed to add dodi: $e');
      return false;
    }
  }

  /// Updates an existing dodi and refreshes the list.
  Future<bool> updateDodi({
    required int dodiId,
    required int userId,
    required String name,
    String? phone,
    required int ratePaise,
  }) async {
    _setLoading();
    try {
      final conflicts = await _repository.checkBuyerExists(
        userId: userId,
        name: name,
        phone: phone,
        excludeDodiId: dodiId,
      );

      if (conflicts != null) {
        if (conflicts['nameConflict'] == true) {
          _setError('A buyer named "${name.trim()}" already exists.');
          return false;
        }
        if (conflicts['phoneConflict'] == true) {
          final cleanPh = phone?.replaceAll(RegExp(r'\D'), '');
          _setError('Phone number "$cleanPh" is already registered to another buyer.');
          return false;
        }
      }

      final updatedDodi = DodiModel(
        id: dodiId,
        userId: userId,
        name: name,
        phone: phone,
        defaultRatePaise: ratePaise,
      );
      await _repository.updateDodi(updatedDodi);

      await _activityRepo.logActivity(ActivityLogModel(
        userId: userId,
        title: 'Buyer Updated',
        subtitle: name,
        value: 'Details updated',
        timeUnix: DateTime.now().millisecondsSinceEpoch,
        iconCode: Icons.edit_note_rounded.codePoint,
        isPositive: 1,
        metadata: {
          'phone': phone,
        },
      ));

      // Reload the full list so the UI reflects the updated entry.
      await loadDodis(userId);
      return true;
    } catch (e) {
      _setError('Failed to update dodi: $e');
      return false;
    }
  }

  /// Checks transaction count for a dodi.
  Future<int> getLedgerCount(int dodiId) {
    return _repository.getLedgerCount(dodiId);
  }

  /// Loads archived buyers currently in the Bin.
  Future<void> loadDeletedDodis(int userId) async {
    try {
      _deletedDodis = await _repository.getDeletedDodis(userId);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load deleted dodis: $e');
    }
  }

  /// Restores a soft-deleted buyer from the Bin back to active list.
  Future<bool> restoreDodi(int dodiId, int userId) async {
    _setLoading();
    try {
      final dodi = _deletedDodis.where((d) => d.id == dodiId).firstOrNull;
      final dodiName = dodi?.name ?? 'Buyer';

      // Check name conflict with active buyers
      final conflict = await _repository.checkBuyerExists(
        userId: userId,
        name: dodiName,
      );

      if (conflict != null && conflict['nameConflict'] == true) {
        // Automatically handle duplicate name on restore by appending (Restored)
        if (dodi != null) {
          final renamed = dodi.copyWith(name: '${dodi.name} (Restored)');
          await _repository.updateDodi(renamed);
        }
      }

      await _repository.restoreDodi(dodiId);

      await _activityRepo.logActivity(ActivityLogModel(
        userId: userId,
        title: 'Buyer Restored',
        subtitle: dodiName,
        value: 'Restored from Bin',
        timeUnix: DateTime.now().millisecondsSinceEpoch,
        iconCode: Icons.restore_from_trash_rounded.codePoint,
        isPositive: 1,
        metadata: {'name': dodiName},
      ));

      await loadDodis(userId);
      await loadDeletedDodis(userId);
      return true;
    } catch (e) {
      _setError('Failed to restore buyer: $e');
      return false;
    }
  }

  /// Moves a buyer to the Bin ("Move to Bin").
  Future<bool> softDeleteDodi(int dodiId, int userId) async {
    _setLoading();
    try {
      final dodi = _dodis.where((d) => d.id == dodiId).firstOrNull;

      await _repository.softDeleteDodi(dodiId);

      if (dodi != null) {
        await _activityRepo.logActivity(ActivityLogModel(
          userId: userId,
          title: 'Buyer Moved to Bin',
          subtitle: dodi.name,
          value: 'Moved to Bin',
          timeUnix: DateTime.now().millisecondsSinceEpoch,
          iconCode: Icons.delete_outline_rounded.codePoint,
          isPositive: 0,
          metadata: {'name': dodi.name},
        ));
      }

      _summaryCache.remove(dodiId);
      _ledgerCache.remove(dodiId);
      await loadDodis(userId);
      await loadDeletedDodis(userId);
      return true;
    } catch (e) {
      _setError('Failed to move buyer to bin: $e');
      return false;
    }
  }

  /// Permanently erases a buyer from SQLite (allowed only if account balance is settled).
  Future<bool> hardDeleteDodi(int dodiId, int userId) async {
    _setLoading();
    try {
      final dodi = _dodis.where((d) => d.id == dodiId).firstOrNull;

      await _repository.hardDeleteDodi(dodiId);

      if (dodi != null) {
        await _activityRepo.logActivity(ActivityLogModel(
          userId: userId,
          title: 'Buyer Permanently Deleted',
          subtitle: dodi.name,
          value: 'Permanently Erased',
          timeUnix: DateTime.now().millisecondsSinceEpoch,
          iconCode: Icons.delete_forever_rounded.codePoint,
          isPositive: 0,
          metadata: {'name': dodi.name},
        ));
      }

      _summaryCache.remove(dodiId);
      _ledgerCache.remove(dodiId);
      await loadDodis(userId);
      await loadDeletedDodis(userId);
      return true;
    } catch (e) {
      _setError('Failed to permanently delete buyer: $e');
      return false;
    }
  }

  /// Legacy helper for deleting a dodi (moves to Bin).
  Future<bool> deleteDodi(int dodiId, int userId) async {
    return softDeleteDodi(dodiId, userId);
  }

  /// Fetches (or retrieves from cache) the [DodiDashboardSummary] for [dodiId].
  ///
  /// Returns the summary directly so the dodi-detail screen can use a
  /// FutureBuilder or await this call without depending on provider state.
  Future<DodiDashboardSummary> fetchSummary(int dodiId) async {
    // Return cached result if available — avoids redundant DB round-trips.
    if (_summaryCache.containsKey(dodiId)) {
      return _summaryCache[dodiId]!;
    }

    try {
      final summary = await _repository.getDodiSummary(dodiId);
      _summaryCache[dodiId] = summary;
      notifyListeners(); // Let any listening widget know the cache was updated.
      return summary;
    } catch (e) {
      // Propagate so the UI FutureBuilder can show an error state.
      rethrow;
    }
  }

  /// Triggers a fetch if the data for [dodiId] is not fully cached.
  void loadDodiIfNotCached(int dodiId) {
    if (!_summaryCache.containsKey(dodiId) || !_ledgerCache.containsKey(dodiId)) {
      refreshDodi(dodiId);
    }
  }

  /// Refreshes both the summary and ledger entries for [dodiId] and notifies listeners.
  Future<void> refreshDodi(int dodiId) async {
    try {
      final summary = await _repository.getDodiSummary(dodiId);
      final entries = await _repository.getLedgerEntries(dodiId);
      _summaryCache[dodiId] = summary;
      _ledgerCache[dodiId] = entries;
      notifyListeners();
    } catch (e) {
      _setError('Failed to refresh dodi details: $e');
    }
  }

  /// Fetches ledger entries for [dodiId].
  Future<List<LedgerEntryModel>> fetchLedgerEntries(int dodiId) async {
    if (_ledgerCache.containsKey(dodiId)) {
      return _ledgerCache[dodiId]!;
    }
    final entries = await _repository.getLedgerEntries(dodiId);
    _ledgerCache[dodiId] = entries;
    notifyListeners();
    return entries;
  }

  /// Deletes a ledger entry and updates the summary.
  Future<void> deleteLedgerEntry({required int entryId, required int dodiId, required int userId}) async {
    _setLoading();
    try {
      final entry = _ledgerCache[dodiId]?.where((e) => e.id == entryId).firstOrNull;
      final dodi = _dodis.where((d) => d.id == dodiId).firstOrNull;

      await _repository.deleteLedgerEntry(entryId);
      
      if (entry != null && dodi != null) {
        await _activityRepo.logActivity(ActivityLogModel(
          userId: userId,
          title: 'Ledger Entry Deleted',
          subtitle: '${dodi.name} - ${entry.type}',
          value: 'Removed',
          timeUnix: DateTime.now().millisecondsSinceEpoch,
          iconCode: Icons.delete_outline_rounded.codePoint,
          isPositive: 0,
          metadata: {
            'name': dodi.name,
          },
        ));
      }

      await refreshDodi(dodiId);
      await loadDodis(userId);
    } catch (e) {
      _setError('Failed to delete entry: $e');
    }
  }

  /// Records a payment received.
  Future<bool> recordPayment({required int dodiId, required String amountString, required String date, required int userId}) async {
    _setLoading();
    try {
      await _repository.recordPayment(dodiId: dodiId, amountString: amountString, date: date);
      
      final dodi = _dodis.where((d) => d.id == dodiId).firstOrNull;
      if (dodi != null) {
        await _activityRepo.logActivity(ActivityLogModel(
          userId: userId,
          title: 'Payment Received',
          subtitle: dodi.name,
          value: 'Rs $amountString',
          timeUnix: DateTime.now().millisecondsSinceEpoch,
          iconCode: Icons.payments_rounded.codePoint,
          isPositive: 1,
          metadata: {
            'name': dodi.name,
          },
        ));
      }

      await refreshDodi(dodiId);
      await loadDodis(userId);
      return true;
    } catch (e) {
      _setError('Failed to record payment: $e');
      return false;
    }
  }

  /// Records an advance taken.
  Future<bool> recordAdvance({required int dodiId, required String amountString, required String date, required int userId}) async {
    _setLoading();
    try {
      await _repository.recordAdvance(dodiId: dodiId, amountString: amountString, date: date);

      final dodi = _dodis.where((d) => d.id == dodiId).firstOrNull;
      if (dodi != null) {
        await _activityRepo.logActivity(ActivityLogModel(
          userId: userId,
          title: 'Advance Given',
          subtitle: dodi.name,
          value: 'Rs $amountString',
          timeUnix: DateTime.now().millisecondsSinceEpoch,
          iconCode: Icons.money_off_rounded.codePoint,
          isPositive: 0,
          metadata: {
            'name': dodi.name,
          },
        ));
      }

      await refreshDodi(dodiId);
      await loadDodis(userId);
      return true;
    } catch (e) {
      _setError('Failed to record advance: $e');
      return false;
    }
  }
}
