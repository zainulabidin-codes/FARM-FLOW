import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Icons;

import '../../data/repositories/milk_entry_repository.dart';
import '../../../dashboard/data/models/activity_log_model.dart';
import '../../../dashboard/data/repositories/activity_log_repository.dart';
import '../../data/models/ledger_entry_model.dart';

/// Loading state for milk entry operations.
enum MilkEntryStatus { idle, loading, success, error }

/// ChangeNotifier provider for all milk-entry UI state.
///
/// Responsibilities:
///   • Exposes [recordMilkEntry] for the milk-entry form to call on save.
///   • Fetches and caches today's total milk in grams for the dashboard.
///   • Notifies dependent widgets after each successful save so live totals
///     update without a manual refresh.
class MilkEntryProvider extends ChangeNotifier {
  final MilkEntryRepository _repository;
  final ActivityLogRepository _activityRepo = ActivityLogRepository();

  MilkEntryProvider({MilkEntryRepository? repository})
      : _repository = repository ?? MilkEntryRepository();

  // ── State ─────────────────────────────────────────────────────────────────

  MilkEntryStatus _status = MilkEntryStatus.idle;
  MilkEntryStatus get status => _status;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// Today's total milk collected (all dodis combined), in INTEGER GRAMS.
  ///
  /// Divide by 1000.0 ONLY in the UI layer for display as kg.
  int _todaysTotalMilkGrams = 0;
  int get todaysTotalMilkGrams => _todaysTotalMilkGrams;

  int _todaysMorningMilkGrams = 0;
  int get todaysMorningMilkGrams => _todaysMorningMilkGrams;

  int _todaysEveningMilkGrams = 0;
  int get todaysEveningMilkGrams => _todaysEveningMilkGrams;

  /// UI-only display getter: converts grams → kg for rendering.
  /// Never use this value in calculations or persistence.
  double get todaysTotalMilkKg => _todaysTotalMilkGrams / 1000.0;
  double get todaysMorningMilkKg => _todaysMorningMilkGrams / 1000.0;
  double get todaysEveningMilkKg => _todaysEveningMilkGrams / 1000.0;

  // ── Private helpers ───────────────────────────────────────────────────────

  void _setLoading() {
    _status = MilkEntryStatus.loading;
    _errorMessage = null;
    notifyListeners();
  }

  void _setError(String message) {
    _status = MilkEntryStatus.error;
    _errorMessage = message;
    notifyListeners();
  }

  // ── Public actions ────────────────────────────────────────────────────────

  /// Records a new milk entry from the form screen.
  ///
  /// On success:
  ///   1. Persists the entry to the ledger table.
  ///   2. Refreshes [todaysTotalMilkGrams] so the dashboard updates
  ///      without requiring a full reload.
  ///   3. Returns true — the caller should show a Snackbar and pop.
  ///
  /// On failure:
  ///   Returns false — [errorMessage] is set for the UI to display.
  ///
  ///   [quantityString] — e.g. "30.5"
  ///   [ratePaise]      — e.g. 550
  ///   [session]        — e.g. "Morning"
  ///   [date]           — e.g. "2026-07-09"
  Future<bool> recordMilkEntry({
    required int userId,
    required String buyerName, // Needed for subtitle
    required int dodiId,
    required String quantityString,
    required int ratePaise,
    required String session,
    required String date,
    String? loadTag,
  }) async {
    _setLoading();
    try {
      await _repository.recordMilkEntry(
        dodiId: dodiId,
        quantityString: quantityString,
        ratePaise: ratePaise,
        session: session,
        date: date,
        loadTag: loadTag,
      );

      await _activityRepo.logActivity(ActivityLogModel(
        userId: userId,
        title: 'Milk Entry Added',
        subtitle: buyerName,
        value: '$quantityString Kg',
        timeUnix: DateTime.now().millisecondsSinceEpoch,
        iconCode: Icons.water_drop_rounded.codePoint,
        isPositive: 1,
        metadata: {
          'name': buyerName,
        },
      ));

      // Refresh today's total immediately after a successful save.
      // This implicitly calls notifyListeners().
      await _refreshTodaysTotal();

      _status = MilkEntryStatus.success;
      notifyListeners();
      return true;
    } on FormatException catch (e) {
      _setError('Invalid number format: ${e.message}');
      return false;
    } catch (e) {
      _setError('Failed to save milk entry: $e');
      return false;
    }
  }

  /// Updates an existing milk entry.
  Future<bool> updateMilkEntry({
    required int entryId,
    required int userId,
    required String buyerName,
    required int dodiId,
    required String quantityString,
    required int ratePaise,
    required String session,
    required String date,
    String? loadTag,
  }) async {
    _setLoading();
    try {
      await _repository.updateMilkEntry(
        entryId: entryId,
        dodiId: dodiId,
        quantityString: quantityString,
        ratePaise: ratePaise,
        session: session,
        date: date,
        loadTag: loadTag,
      );

      await _activityRepo.logActivity(ActivityLogModel(
        userId: userId,
        title: 'Milk Entry Updated',
        subtitle: buyerName,
        value: '$quantityString Kg',
        timeUnix: DateTime.now().millisecondsSinceEpoch,
        iconCode: Icons.edit_note_rounded.codePoint,
        isPositive: 1,
        metadata: {
          'name': buyerName,
        },
      ));

      await _refreshTodaysTotal();

      _status = MilkEntryStatus.success;
      notifyListeners();
      return true;
    } on FormatException catch (e) {
      _setError('Invalid number format: ${e.message}');
      return false;
    } catch (e) {
      _setError('Failed to update milk entry: $e');
      return false;
    }
  }

  /// Checks if an entry already exists for a specific buyer, date, and session.
  Future<LedgerEntryModel?> checkExistingEntry({
    required int dodiId,
    required String session,
    required String date,
  }) async {
    return await _repository.checkExistingEntry(dodiId: dodiId, session: session, date: date);
  }

  /// Fetches today's total milk and updates [todaysTotalMilkGrams].
  ///
  /// Call this when the dashboard first loads (or resumes from background)
  /// to populate the live total display.
  Future<void> fetchTodaysTotalMilk() async {
    try {
      await _refreshTodaysTotal();
    } catch (e) {
      // Non-critical — don't disrupt the UI for a display refresh failure.
      debugPrint('[MilkEntryProvider] fetchTodaysTotalMilk error: $e');
    }
  }

  /// Fetches today's total for a specific [date] string.
  ///
  /// Useful when the dashboard shows a date-picker to view historical totals.
  Future<int> getTotalMilkForDate(String date) async {
    try {
      return await _repository.getTodaysTotalMilkGrams(date);
    } catch (e) {
      debugPrint('[MilkEntryProvider] getTotalMilkForDate error: $e');
      return 0;
    }
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  Future<void> _refreshTodaysTotal() async {
    _todaysTotalMilkGrams = await _repository.getTodaysTotalMilkGramsForToday();
    _todaysMorningMilkGrams = await _repository.getTodaysSessionMilkGramsForToday('MORNING');
    _todaysEveningMilkGrams = await _repository.getTodaysSessionMilkGramsForToday('EVENING');
    notifyListeners();
  }
}
