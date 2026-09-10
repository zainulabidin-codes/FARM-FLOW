import '../datasources/cow_local_datasource.dart';
import '../models/cow_model.dart';

/// Encapsulates all business logic for cow and breeding management.
///
/// Key responsibilities:
///   1. CRUD operations on cows.
///   2. Gestation calculation - delivery_date = mating_date + 283 days.
///   3. Pregnancy month computation for the UI progress indicator.
class CowRepository {
  static const int _gestationDays = 283;

  final CowLocalDatasource _datasource;

  CowRepository({CowLocalDatasource? datasource})
      : _datasource = datasource ?? CowLocalDatasource();

  // --- CRUD ------------------------------------------------------------------

  /// Adds a new cow and returns the saved [CowModel] with its DB id.
  Future<CowModel> addCow({
    required int userId,
    required String tagNumber,
    String? name,
    String status = 'MILKING',
    String? matingDate,
    int hasLactatedBefore = 0,
    String? estimatedBirthDate,
    int isPregnancyConfirmed = 0,
    String? confirmationDate,
    String? confirmationMethod,
  }) async {
    String? deliveryDate;
    if (matingDate != null && matingDate.isNotEmpty) {
      try {
        final parsed = DateTime.parse(matingDate);
        final delivery = parsed.add(const Duration(days: _gestationDays));
        deliveryDate = "${delivery.year.toString().padLeft(4, '0')}-${delivery.month.toString().padLeft(2, '0')}-${delivery.day.toString().padLeft(2, '0')}";
      } catch (e) {
        // ignore parsing errors
      }
    }

    final cow = CowModel(
      userId: userId,
      tagNumber: tagNumber,
      name: name,
      status: status,
      matingDate: matingDate,
      deliveryDate: deliveryDate,
      hasLactatedBefore: hasLactatedBefore,
      estimatedBirthDate: estimatedBirthDate,
      isPregnancyConfirmed: isPregnancyConfirmed,
      confirmationDate: confirmationDate,
      confirmationMethod: confirmationMethod,
    );

    final id = await _datasource.insertCow(cow);
    return CowModel(
      id: id,
      userId: cow.userId,
      tagNumber: cow.tagNumber,
      name: cow.name,
      status: cow.status,
      matingDate: cow.matingDate,
      deliveryDate: cow.deliveryDate,
      hasLactatedBefore: cow.hasLactatedBefore,
      isPregnancyConfirmed: cow.isPregnancyConfirmed,
      confirmationDate: cow.confirmationDate,
      confirmationMethod: cow.confirmationMethod,
      estimatedBirthDate: cow.estimatedBirthDate,
      isDeleted: cow.isDeleted,
      deletedReason: cow.deletedReason,
      deletedDate: cow.deletedDate,
    );
  }

  /// Returns all cows for [userId].
  Future<List<CowModel>> getAllCows(int userId) {
    return _datasource.getAllCows(userId);
  }

  /// Returns a set of cow IDs owned by the user that have at least one milking season.
  Future<Set<int>> getCowsWithMilkingSeasons(int userId) {
    return _datasource.getCowsWithMilkingSeasons(userId);
  }

  /// Updates just the status of [cowId].
  Future<void> updateCowStatus(int cowId, String newStatus) {
    return _datasource.updateCowStatus(cowId, newStatus);
  }

  /// General update of a cow from the Edit form.
  Future<void> updateCowGeneral({
    required int cowId,
    required String name,
    required String tagNumber,
    required String status,
    String? matingDate,
    String? deliveryDate,
    required int hasLactatedBefore,
    String? estimatedBirthDate,
    int isPregnancyConfirmed = 0,
    String? confirmationDate,
    String? confirmationMethod,
  }) async {
    String? computedDeliveryDate = deliveryDate;
    if (deliveryDate == null && matingDate != null && matingDate.isNotEmpty) {
      try {
        final parsed = DateTime.parse(matingDate);
        final delivery = parsed.add(const Duration(days: _gestationDays));
        computedDeliveryDate = "${delivery.year.toString().padLeft(4, '0')}-${delivery.month.toString().padLeft(2, '0')}-${delivery.day.toString().padLeft(2, '0')}";
      } catch (e) {
        // ignore parsing errors
      }
    }

    await _datasource.updateCowGeneral(
      cowId: cowId,
      name: name,
      tagNumber: tagNumber,
      status: status,
      matingDate: matingDate,
      deliveryDate: computedDeliveryDate,
      hasLactatedBefore: hasLactatedBefore,
      estimatedBirthDate: estimatedBirthDate,
      isPregnancyConfirmed: isPregnancyConfirmed,
      confirmationDate: confirmationDate,
      confirmationMethod: confirmationMethod,
    );
  }

  // --- Breeding logic --------------------------------------------------------

  /// Records a confirmed mating event for [cowId].
  ///
  /// BREEDING RULE:
  ///   delivery_date = mating_date + [_gestationDays] (283 days) days.
  ///   Cow status is set to 'PREGNANT' automatically.
  ///
  /// Records a mating event for [cowId].
  /// Sets initial status to 'PENDING_CONFIRMATION'.
  Future<void> recordMating({
    required int cowId,
    required String matingDateString,
    String newStatus = 'PENDING_CONFIRMATION',
  }) async {
    final DateTime matingDate = DateTime.parse(matingDateString);
    final DateTime deliveryDate = matingDate.add(
      const Duration(days: _gestationDays),
    );

    // Format delivery date back to ISO-8601 string for storage.
    final String deliveryDateString =
        '${deliveryDate.year}-${deliveryDate.month.toString().padLeft(2, '0')}-${deliveryDate.day.toString().padLeft(2, '0')}';

    await _datasource.updateMatingAndDeliveryDate(
      cowId: cowId,
      matingDate: matingDateString,
      deliveryDate: deliveryDateString,
      newStatus: newStatus,
    );
  }

  /// Confirms pregnancy post-mating via datasource transactional method.
  Future<Map<String, String>> confirmPregnancy({
    required int cowId,
    required String confirmationDate,
    required String method,
  }) async {
    return _datasource.confirmPregnancy(
      cowId: cowId,
      confirmationDate: confirmationDate,
      method: method,
    );
  }

  /// Records calving by marking the cow as MILKING and setting delivery date to today.
  Future<void> recordCalving(int cowId) async {
    final DateTime today = DateTime.now();
    final String deliveryDateString =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    await _datasource.recordCalving(cowId, deliveryDateString);
  }

  /// Soft deletes the cow with [cowId] by flagging it as deleted.
  Future<void> softDeleteCow(int cowId, String reason) async {
    final now = DateTime.now().toIso8601String();
    await _datasource.softDeleteCow(cowId, reason, now);
  }

  /// Permanently removes cows soft-deleted more than [retentionDays] ago.
  Future<int> purgeExpiredDeletedCows({int retentionDays = 365}) {
    return _datasource.purgeExpiredDeletedCows(retentionDays: retentionDays);
  }

  // --- Pregnancy month calculation -------------------------------------------

  /// Returns the number of days since mating, or null if no valid date.
  /// Normalizes both dates to local midnight (00:00:00) to eliminate time-of-day drift.
  /// Optional [now] allows deterministic testing across midnight boundaries.
  int? getDaysSinceMating(String? matingDateString, {DateTime? now}) {
    if (matingDateString == null || matingDateString.isEmpty) return null;
    try {
      final DateTime matingDate = DateTime.parse(matingDateString);
      final DateTime currentTime = now ?? DateTime.now();
      final DateTime todayMidnight = DateTime(currentTime.year, currentTime.month, currentTime.day);
      final DateTime matingMidnight = DateTime(matingDate.year, matingDate.month, matingDate.day);

      final int daysSinceMating = todayMidnight.difference(matingMidnight).inDays;
      return daysSinceMating < 0 ? 0 : daysSinceMating;
    } catch (_) {
      return null;
    }
  }

  /// Calculates the current month of pregnancy (1-9) based on matingDate.
  /// Returns null if not pregnant or no mating date is recorded.
  ///
  /// Can return a lower month (or even 9+ clamped to 9)
  /// if data is stale (cow delivered but status not yet updated).
  ///
  /// NOTE: No floats are stored - this is a pure in-memory computation
  /// for display purposes only.
  int? getCurrentPregnancyMonth(String? matingDateString) {
    final daysSinceMating = getDaysSinceMating(matingDateString);
    if (daysSinceMating == null) return null;

    // Average days per month ~ 30.44 gives a more accurate month boundary
    // than a flat 30. Still integer output - no floats stored anywhere.
    final int month = (daysSinceMating / 30.44).floor() + 1;
    return month.clamp(1, 9);
  }

  /// Returns the number of days remaining until the expected delivery date.
  ///
  /// Returns null if [deliveryDateString] is null.
  /// Returns 0 if the delivery date has already passed.
  int? getDaysUntilDelivery(String? deliveryDateString) {
    if (deliveryDateString == null || deliveryDateString.isEmpty) return null;
    try {
      final DateTime deliveryDate = DateTime.parse(deliveryDateString);
      final DateTime now = DateTime.now();
      final DateTime todayMidnight = DateTime(now.year, now.month, now.day);
      final DateTime deliveryMidnight = DateTime(deliveryDate.year, deliveryDate.month, deliveryDate.day);

      final int days = deliveryMidnight.difference(todayMidnight).inDays;
      return days < 0 ? 0 : days;
    } catch (_) {
      return null;
    }
  }

  // --- Yield Logging ---
  Future<void> logDailyYield(int cowId, String date, int? morningGrams, int? eveningGrams) async {
    await _datasource.logDailyYield(cowId, date, morningGrams, eveningGrams);
  }

  Future<Map<String, int?>> getSeasonSessionYields(int cowId) async {
    return _datasource.getSeasonSessionYields(cowId);
  }

  Future<Map<String, dynamic>?> getLatestSeason(int cowId) async {
    return _datasource.getLatestSeason(cowId);
  }

  Future<List<Map<String, dynamic>>> getSessionsForSeason(int seasonId) async {
    return _datasource.getSessionsForSeason(seasonId);
  }

  Future<List<Map<String, dynamic>>> getMonthlySummariesForSeason(int seasonId) async {
    return _datasource.getMonthlySummariesForSeason(seasonId);
  }

  Future<void> runStartupRollups() async {
    await _datasource.runStartupRollups();
  }

  Future<void> deleteMilkSession(int cowId, String date, String session) async {
    await _datasource.deleteMilkSession(cowId, date, session);
  }

  Future<void> updateMilkSession(int cowId, String date, String session, int newGrams) async {
    await _datasource.updateMilkSession(cowId, date, session, newGrams);
  }
}
