import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Icons;
import '../../data/models/activity_log_model.dart';
import '../../data/repositories/activity_log_repository.dart';

/// Centralized, strongly-typed Activity Logger & UI state holder.
///
/// Every user action across the app that should appear in the main
/// activity log calls one of the domain-specific `log*` methods below.
/// Each method:
///   1. Constructs the [ActivityLogModel] with correct icon, polarity, etc.
///   2. Persists it to SQLite via [ActivityLogRepository].
///   3. Prepends it to the in-memory [_activities] list.
///   4. Calls [notifyListeners] so DashboardScreen / ActivityLogScreen
///      update in real time — no manual pull-to-refresh required.
class ActivityLogProvider extends ChangeNotifier {
  final ActivityLogRepository _repository;

  List<ActivityLogModel> _activities = [];
  bool _isLoading = false;
  String? _error;

  ActivityLogProvider({ActivityLogRepository? repository})
      : _repository = repository ?? ActivityLogRepository();

  List<ActivityLogModel> get activities => _activities;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ══════════════════════════════════════════════════════════════════════════
  // Load / Refresh
  // ══════════════════════════════════════════════════════════════════════════

  /// Loads all activity logs for [userId] from SQLite.
  ///
  /// When [silent] is true and the list is already populated, the loading
  /// spinner is suppressed so background refreshes don't flash the UI.
  Future<void> loadActivities(int userId, {bool silent = false}) async {
    if (!silent || _activities.isEmpty) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      _activities = await _repository.getActivities(userId);
    } catch (e) {
      _error = 'Failed to load activities: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Core Internal Logger
  // ══════════════════════════════════════════════════════════════════════════

  /// Persists [activity] to SQLite, prepends it to the in-memory list,
  /// and notifies all listeners for instant UI updates.
  ///
  /// Activity logging failures are non-blocking — they are caught and
  /// printed so primary operations (milk save, payment, etc.) always
  /// succeed cleanly.
  Future<void> _logActivity(ActivityLogModel activity) async {
    try {
      await _repository.logActivity(activity);
      _activities.insert(0, activity);
      notifyListeners();
    } catch (e) {
      debugPrint('[ActivityLogProvider] _logActivity error: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Milk Entry Domain Loggers
  // ══════════════════════════════════════════════════════════════════════════

  /// Logs a new milk entry being recorded for a buyer.
  Future<void> logMilkEntryAdded({
    required int userId,
    required String buyerName,
    required String quantityString,
  }) async {
    await _logActivity(ActivityLogModel(
      userId: userId,
      title: 'Milk Entry Added',
      subtitle: buyerName,
      value: '$quantityString Kg',
      timeUnix: DateTime.now().millisecondsSinceEpoch,
      iconCode: Icons.water_drop_rounded.codePoint,
      isPositive: 1,
      metadata: {'name': buyerName},
    ));
  }

  /// Logs an existing milk entry being updated.
  Future<void> logMilkEntryUpdated({
    required int userId,
    required String buyerName,
    required String quantityString,
  }) async {
    await _logActivity(ActivityLogModel(
      userId: userId,
      title: 'Milk Entry Updated',
      subtitle: buyerName,
      value: '$quantityString Kg',
      timeUnix: DateTime.now().millisecondsSinceEpoch,
      iconCode: Icons.edit_note_rounded.codePoint,
      isPositive: 1,
      metadata: {'name': buyerName},
    ));
  }

  /// Logs a milk entry being deleted from a buyer's ledger.
  Future<void> logMilkEntryDeleted({
    required int userId,
    required String buyerName,
  }) async {
    await _logActivity(ActivityLogModel(
      userId: userId,
      title: 'Milk Entry Deleted',
      subtitle: buyerName,
      value: 'Removed Entry',
      timeUnix: DateTime.now().millisecondsSinceEpoch,
      iconCode: Icons.delete_outline_rounded.codePoint,
      isPositive: 0,
      metadata: {'name': buyerName},
    ));
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Dodi / Buyer Domain Loggers
  // ══════════════════════════════════════════════════════════════════════════

  /// Logs a new milk buyer being registered.
  Future<void> logBuyerAdded({
    required int userId,
    required String name,
    required int ratePaise,
    String? phone,
  }) async {
    await _logActivity(ActivityLogModel(
      userId: userId,
      title: 'Buyer Added',
      subtitle: name,
      value: 'Rate: Rs ${(ratePaise / 100).toStringAsFixed(2)}/Kg',
      timeUnix: DateTime.now().millisecondsSinceEpoch,
      iconCode: Icons.person_add_alt_1_rounded.codePoint,
      isPositive: 1,
      metadata: {'phone': phone},
    ));
  }

  /// Logs a buyer's details being updated.
  Future<void> logBuyerUpdated({
    required int userId,
    required String name,
    String? phone,
  }) async {
    await _logActivity(ActivityLogModel(
      userId: userId,
      title: 'Buyer Updated',
      subtitle: name,
      value: 'Details updated',
      timeUnix: DateTime.now().millisecondsSinceEpoch,
      iconCode: Icons.edit_note_rounded.codePoint,
      isPositive: 1,
      metadata: {'phone': phone},
    ));
  }

  /// Logs a buyer being restored from the Bin.
  Future<void> logBuyerRestored({
    required int userId,
    required String name,
  }) async {
    await _logActivity(ActivityLogModel(
      userId: userId,
      title: 'Buyer Restored',
      subtitle: name,
      value: 'Restored from Bin',
      timeUnix: DateTime.now().millisecondsSinceEpoch,
      iconCode: Icons.restore_from_trash_rounded.codePoint,
      isPositive: 1,
      metadata: {'name': name},
    ));
  }

  /// Logs a buyer being soft-deleted (moved to the Bin).
  Future<void> logBuyerMovedToBin({
    required int userId,
    required String name,
  }) async {
    await _logActivity(ActivityLogModel(
      userId: userId,
      title: 'Buyer Moved to Bin',
      subtitle: name,
      value: 'Moved to Bin',
      timeUnix: DateTime.now().millisecondsSinceEpoch,
      iconCode: Icons.delete_outline_rounded.codePoint,
      isPositive: 0,
      metadata: {'name': name},
    ));
  }

  /// Logs a buyer being permanently erased from SQLite.
  Future<void> logBuyerPermanentlyDeleted({
    required int userId,
    required String name,
  }) async {
    await _logActivity(ActivityLogModel(
      userId: userId,
      title: 'Buyer Permanently Deleted',
      subtitle: name,
      value: 'Permanently Erased',
      timeUnix: DateTime.now().millisecondsSinceEpoch,
      iconCode: Icons.delete_forever_rounded.codePoint,
      isPositive: 0,
      metadata: {'name': name},
    ));
  }

  /// Logs a ledger entry being deleted from a buyer's transaction history.
  Future<void> logLedgerEntryDeleted({
    required int userId,
    required String buyerName,
    required String entryType,
  }) async {
    await _logActivity(ActivityLogModel(
      userId: userId,
      title: 'Ledger Entry Deleted',
      subtitle: '$buyerName - $entryType',
      value: 'Removed',
      timeUnix: DateTime.now().millisecondsSinceEpoch,
      iconCode: Icons.delete_outline_rounded.codePoint,
      isPositive: 0,
      metadata: {'name': buyerName},
    ));
  }

  /// Logs a payment collected from a buyer.
  Future<void> logPaymentReceived({
    required int userId,
    required String buyerName,
    required String amountString,
  }) async {
    await _logActivity(ActivityLogModel(
      userId: userId,
      title: 'Payment Received',
      subtitle: buyerName,
      value: 'Rs $amountString',
      timeUnix: DateTime.now().millisecondsSinceEpoch,
      iconCode: Icons.payments_rounded.codePoint,
      isPositive: 1,
      metadata: {'name': buyerName},
    ));
  }

  /// Logs an advance payment given to a buyer.
  Future<void> logAdvanceGiven({
    required int userId,
    required String buyerName,
    required String amountString,
  }) async {
    await _logActivity(ActivityLogModel(
      userId: userId,
      title: 'Advance Given',
      subtitle: buyerName,
      value: 'Rs $amountString',
      timeUnix: DateTime.now().millisecondsSinceEpoch,
      iconCode: Icons.money_off_rounded.codePoint,
      isPositive: 0,
      metadata: {'name': buyerName},
    ));
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Cow / Herd Management Domain Loggers
  // ══════════════════════════════════════════════════════════════════════════

  /// Logs a new cow being added to the herd.
  Future<void> logCowAdded({
    required int userId,
    required String tagNumber,
    required String status,
    String? name,
  }) async {
    await _logActivity(ActivityLogModel(
      userId: userId,
      title: 'New Cow Added',
      subtitle: 'Tag: $tagNumber',
      value: status,
      timeUnix: DateTime.now().millisecondsSinceEpoch,
      iconCode: Icons.pets.codePoint,
      isPositive: 1,
      metadata: {'name': name, 'tag': tagNumber},
    ));
  }

  /// Logs daily milk yield recorded for a cow.
  Future<void> logCowMilkRecorded({
    required int userId,
    required String tagNumber,
    String? cowName,
    required double totalKg,
    required String sessionStr,
    required String date,
  }) async {
    await _logActivity(ActivityLogModel(
      userId: userId,
      title: 'Milk Recorded',
      subtitle: 'Added entry for Cow: $cowName (Tag: $tagNumber)',
      value: '${totalKg.toStringAsFixed(1)} Kg ($sessionStr)',
      timeUnix: DateTime.now().millisecondsSinceEpoch,
      iconCode: Icons.water_drop.codePoint,
      isPositive: 1,
      metadata: {'tag': tagNumber, 'date': date},
    ));
  }

  /// Logs a cow's milk yield session being deleted.
  Future<void> logCowMilkSessionDeleted({
    required int userId,
    required String cowLabel,
    required String session,
    required String date,
  }) async {
    await _logActivity(ActivityLogModel(
      userId: userId,
      title: 'Milk Yield Session Removed',
      subtitle: 'Cow: $cowLabel',
      value: '$session Session ($date)',
      timeUnix: DateTime.now().millisecondsSinceEpoch,
      iconCode: Icons.remove_circle_outline.codePoint,
      isPositive: 0,
      metadata: {'session': session, 'date': date},
    ));
  }

  /// Logs a cow's general details being updated.
  Future<void> logCowUpdated({
    required int userId,
    required String label,
    required String status,
    String? name,
    String? tagNumber,
  }) async {
    await _logActivity(ActivityLogModel(
      userId: userId,
      title: 'Cow Updated',
      subtitle: label,
      value: status,
      timeUnix: DateTime.now().millisecondsSinceEpoch,
      iconCode: Icons.edit.codePoint,
      isPositive: 1,
      metadata: {'name': name, 'tag': tagNumber},
    ));
  }

  /// Logs a mating event being recorded for a cow.
  Future<void> logMatingRecorded({
    required int userId,
    required String label,
    required String matingDate,
    String? name,
    String? tagNumber,
  }) async {
    await _logActivity(ActivityLogModel(
      userId: userId,
      title: 'Mating Recorded',
      subtitle: '$label — Mating Recorded (Awaiting Confirmation)',
      value: '$matingDate (Pending Confirmation)',
      timeUnix: DateTime.now().millisecondsSinceEpoch,
      iconCode: Icons.favorite.codePoint,
      isPositive: 1,
      metadata: {'name': name, 'tag': tagNumber, 'status': 'PENDING_CONFIRMATION'},
    ));
  }

  /// Logs a cow's status being changed.
  Future<void> logCowStatusUpdated({
    required int userId,
    required String cowName,
    required String newStatus,
  }) async {
    await _logActivity(ActivityLogModel(
      userId: userId,
      title: 'Status Updated',
      subtitle: cowName,
      value: newStatus,
      timeUnix: DateTime.now().millisecondsSinceEpoch,
      iconCode: Icons.update.codePoint,
      isPositive: 1,
      metadata: {'name': cowName},
    ));
  }

  /// Logs a calving event for a cow.
  Future<void> logCalvingRecorded({
    required int userId,
    required String cowName,
  }) async {
    await _logActivity(ActivityLogModel(
      userId: userId,
      title: 'Calving Recorded',
      subtitle: cowName,
      value: 'Now Milking',
      timeUnix: DateTime.now().millisecondsSinceEpoch,
      iconCode: Icons.child_care.codePoint,
      isPositive: 1,
      metadata: {'name': cowName},
    ));
  }

  /// Logs a pregnancy being ended (mid-term loss).
  Future<void> logPregnancyEnded({
    required int userId,
    required String label,
    required String resetStatus,
    String? name,
    String? tagNumber,
  }) async {
    final subtitleStr = (resetStatus == 'MILKING')
        ? '$label — Mid-term loss logged (Reverted to Milking)'
        : '$label — Mid-term loss logged (Reverted to Heifer)';

    await _logActivity(ActivityLogModel(
      userId: userId,
      title: 'Pregnancy Ended',
      subtitle: subtitleStr,
      value: 'Mid-term loss logged (Reverted to $resetStatus)',
      timeUnix: DateTime.now().millisecondsSinceEpoch,
      iconCode: Icons.warning_amber_rounded.codePoint,
      isPositive: 0,
      metadata: {'name': name, 'tag': tagNumber, 'revertedStatus': resetStatus},
    ));
  }

  /// Logs a pregnancy confirmation.
  Future<void> logPregnancyConfirmed({
    required int userId,
    required String label,
    required String targetStatus,
    required String method,
    String? name,
    String? tagNumber,
  }) async {
    await _logActivity(ActivityLogModel(
      userId: userId,
      title: 'Pregnancy Confirmed',
      subtitle: '$label — Confirmed by $method',
      value: '$targetStatus ($method)',
      timeUnix: DateTime.now().millisecondsSinceEpoch,
      iconCode: Icons.favorite.codePoint,
      isPositive: 1,
      metadata: {'name': name, 'tag': tagNumber, 'method': method},
    ));
  }

  /// Logs a confirmation method override (e.g. AUTO → VET).
  Future<void> logConfirmationMethodUpdated({
    required int userId,
    required String label,
    required String oldMethod,
    required String newMethod,
    String? name,
    String? tagNumber,
  }) async {
    await _logActivity(ActivityLogModel(
      userId: userId,
      title: 'Confirmation Method Updated',
      subtitle: '$label — Updated from $oldMethod to $newMethod',
      value: 'Method Override ($oldMethod → $newMethod)',
      timeUnix: DateTime.now().millisecondsSinceEpoch,
      iconCode: Icons.edit_note_rounded.codePoint,
      isPositive: 1,
      metadata: {'name': name, 'tag': tagNumber, 'oldMethod': oldMethod, 'newMethod': newMethod},
    ));
  }

  /// Logs a heat repeat (mating failure) event.
  Future<void> logHeatRepeated({
    required int userId,
    required String label,
    required String resetStatus,
    String? name,
    String? tagNumber,
  }) async {
    await _logActivity(ActivityLogModel(
      userId: userId,
      title: 'Heat Repeated',
      subtitle: label,
      value: 'Reset to $resetStatus (Not Pregnant)',
      timeUnix: DateTime.now().millisecondsSinceEpoch,
      iconCode: Icons.refresh_rounded.codePoint,
      isPositive: 0,
      metadata: {'name': name, 'tag': tagNumber},
    ));
  }

  /// Logs a cow being soft-deleted from the herd.
  Future<void> logCowRemoved({
    required int userId,
    required String cowName,
    required String reason,
  }) async {
    await _logActivity(ActivityLogModel(
      userId: userId,
      title: 'Cow Removed',
      subtitle: cowName,
      value: reason,
      timeUnix: DateTime.now().millisecondsSinceEpoch,
      iconCode: Icons.remove_circle_outline.codePoint,
      isPositive: 0,
      metadata: {'name': cowName},
    ));
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Authentication Domain Loggers
  // ══════════════════════════════════════════════════════════════════════════

  /// Logs a new farm account registration.
  Future<void> logFarmRegistered({
    required int userId,
    required String farmName,
    required String farmerName,
    required String username,
  }) async {
    await _logActivity(ActivityLogModel(
      userId: userId,
      title: 'Farm Account Registered',
      subtitle: farmName,
      value: 'Owner: $farmerName',
      timeUnix: DateTime.now().millisecondsSinceEpoch,
      iconCode: Icons.storefront_rounded.codePoint,
      isPositive: 1,
      metadata: {'username': username, 'farmName': farmName},
    ));
  }

  /// Logs a farmer logging into the app.
  Future<void> logFarmerLoggedIn({
    required int userId,
    required String name,
  }) async {
    await _logActivity(ActivityLogModel(
      userId: userId,
      title: 'Farmer Logged In',
      subtitle: 'Welcome back, $name',
      value: 'Active Session',
      timeUnix: DateTime.now().millisecondsSinceEpoch,
      iconCode: Icons.login_rounded.codePoint,
      isPositive: 1,
      metadata: {},
    ));
  }

  /// Logs a farmer logging out of the app.
  Future<void> logFarmerLoggedOut({
    required int userId,
    required String name,
  }) async {
    await _logActivity(ActivityLogModel(
      userId: userId,
      title: 'Farmer Logged Out',
      subtitle: 'Session ended for $name',
      value: 'Session Ended',
      timeUnix: DateTime.now().millisecondsSinceEpoch,
      iconCode: Icons.logout_rounded.codePoint,
      isPositive: 0,
      metadata: {},
    ));
  }
}
