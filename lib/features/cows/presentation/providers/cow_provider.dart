import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Icons;

import '../../data/models/cow_model.dart';
import '../../data/repositories/cow_repository.dart';
import '../../../../features/dashboard/data/repositories/activity_log_repository.dart';
import '../../../../features/dashboard/data/models/activity_log_model.dart';

/// Loading state for async cow operations.
enum CowStatus { idle, loading, success, error }

/// ChangeNotifier provider for all Cow-related UI state.
class CowProvider extends ChangeNotifier {
  final CowRepository _repository;
  final ActivityLogRepository _activityRepo = ActivityLogRepository();

  CowProvider({CowRepository? repository})
      : _repository = repository ?? CowRepository();

  CowStatus _status = CowStatus.idle;
  CowStatus get status => _status;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<CowModel> _cows = [];

  List<CowModel> get cows => List.unmodifiable(_cows);
  int get totalHerdCount => _cows.where((c) => c.isDeleted == 0).length;

  /// Centralized Case-Insensitive Tag Validator
  bool isTagTaken(String tagNumber, {int? excludeCowId}) {
    final cleanTag = tagNumber.trim().toLowerCase();
    if (cleanTag.isEmpty) return false;
    return _cows.any((c) => 
      c.isDeleted == 0 && 
      c.tagNumber.trim().toLowerCase() == cleanTag && 
      c.id != excludeCowId
    );
  }

  // ── 5 Category Herd Breakdown Getters (Strict Primary Status counts) ───────
  int get milkingCount => _cows.where((c) => c.isDeleted == 0 && c.status == 'MILKING').length;
  int get pregnantCount => _cows.where((c) => c.isDeleted == 0 && c.status == 'PREGNANT').length;
  int get dryCount => _cows.where((c) => c.isDeleted == 0 && c.status == 'DRY').length;
  int get bredHeiferCount => _cows.where((c) => c.isDeleted == 0 && c.status == 'BRED_HEIFER').length;
  int get heiferCount => _cows.where((c) => c.isDeleted == 0 && c.status == 'HEIFER').length;
  int get pendingConfirmationCount => _cows.where((c) => c.isDeleted == 0 && c.status == 'PENDING_CONFIRMATION').length;
  List<CowModel> get pendingConfirmationCows => _cows.where((c) => c.isDeleted == 0 && c.status == 'PENDING_CONFIRMATION').toList();

  List<CowModel> get pregnantCows => _cows.where((c) => c.status == 'PREGNANT' || c.status == 'BRED_HEIFER').toList();
  List<CowModel> get dryCows =>
      _cows.where((c) {
        if (c.status == 'DRY') return true;
        if (c.status == 'PREGNANT' || c.status == 'BRED_HEIFER') {
          final days = getDaysSinceMating(c);
          if (days != null && days >= 211) return true;
        }
        return false;
      }).toList();
  List<CowModel> get heifers => _cows.where((c) => c.status == 'HEIFER').toList();

  bool hasLactated(int cowId) {
    final cow = _cows.where((c) => c.id == cowId).firstOrNull;
    if (cow == null) return false;
    return cow.hasLactatedBefore == 1;
  }

  List<CowModel> get milkingCows =>
      _cows.where((c) {
        if (c.isDeleted == 1) return false;
        // STRICT FIREWALL: Must have lactated at least once in her lifetime!
        if (c.hasLactatedBefore != 1) return false;

        if (c.status == 'MILKING' || c.status == 'PENDING_CONFIRMATION') return true;
        if (c.status == 'PREGNANT') {
          final days = getDaysSinceMating(c);
          if (days != null && days < 211) return true;
        }
        return false;
      }).toList();

  bool _isRollupRunning = false;
  bool get isRollupRunning => _isRollupRunning;

  int? getDaysSinceMating(CowModel cow) {
    return _repository.getDaysSinceMating(cow.matingDate);
  }

  int getPregnancyMonth(CowModel cow) {
    final days = getDaysSinceMating(cow);
    if (days == null) return 0;
    final month = (days / 30.44).floor() + 1;
    return month.clamp(1, 9);
  }

  String? calculateAgeString(CowModel cow) {
    if (cow.estimatedBirthDate == null || cow.estimatedBirthDate!.isEmpty) {
      return null;
    }
    try {
      final birthDate = DateTime.parse(cow.estimatedBirthDate!);
      final now = DateTime.now();
      if (birthDate.isAfter(now)) return null;

      int years = now.year - birthDate.year;
      int months = now.month - birthDate.month;
      int days = now.day - birthDate.day;

      if (months < 0 || (months == 0 && days < 0)) {
        years--;
        months += 12;
      }

      if (days < 0) {
        final previousMonthDate = DateTime(now.year, now.month, 0);
        days += previousMonthDate.day;
        months--;
        
        if (days < 0) {
          days = 0;
        }
      }

      final parts = <String>[];
      if (years > 0) parts.add('$years yrs');
      if (months > 0) parts.add('$months mos');
      if (days > 0 || parts.isEmpty) parts.add('$days days');

      return parts.join(', ');
    } catch (_) {
      return null;
    }
  }

  Future<void> runStartupRollups() async {
    _isRollupRunning = true;
    notifyListeners();
    try {
      await _repository.runStartupRollups();
      await _repository.purgeExpiredDeletedCows(retentionDays: 365);
    } catch (e) {
      _errorMessage = "Rollup failed: $e";
    } finally {
      _isRollupRunning = false;
      notifyListeners();
    }
  }

  Future<bool> logDailyYield({
    required int cowId,
    required String date,
    int? morningGrams,
    int? eveningGrams,
  }) async {
    _status = CowStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.logDailyYield(cowId, date, morningGrams, eveningGrams);
      
      final cow = _cows.where((c) => c.id == cowId).firstOrNull;
      
      if (cow != null && cow.userId != 0) {
        String sessionStr = '';
        double totalKg = 0.0;
        if (morningGrams != null) {
          sessionStr += 'MORNING';
          totalKg += morningGrams / 1000;
        }
        if (eveningGrams != null) {
          if (sessionStr.isNotEmpty) sessionStr += ' & ';
          sessionStr += 'EVENING';
          totalKg += eveningGrams / 1000;
        }
        
        await _activityRepo.logActivity(
          ActivityLogModel(
            userId: cow.userId,
            title: 'Milk Recorded',
            subtitle: 'Added entry for Cow: ${cow.name} (Tag: ${cow.tagNumber})',
            value: '${totalKg.toStringAsFixed(1)} Kg ($sessionStr)',
            timeUnix: DateTime.now().millisecondsSinceEpoch,
            iconCode: Icons.water_drop.codePoint,
            isPositive: 1,
            metadata: {'tag': cow.tagNumber, 'date': date},
          ),
        );
      }

      if (_cows.isNotEmpty) {
        await fetchCows(_cows.first.userId);
      }
      _status = CowStatus.success;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _status = CowStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> _runAutoConfirmSweep(int userId, List<CowModel> baseCows) async {
    bool didConfirmAny = false;
    final now = DateTime.now();
    final todayStr =
        "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    for (final cow in baseCows) {
      if (cow.isDeleted == 0 && cow.status == 'PENDING_CONFIRMATION') {
        final days = getDaysSinceMating(cow);
        if (days != null && days >= 29) {
          final result = await _repository.confirmPregnancy(
            cowId: cow.id!,
            confirmationDate: todayStr,
            method: 'AUTO',
          );

          final label = (cow.name?.isNotEmpty == true) ? cow.name! : cow.tagNumber;
          final targetStatus = result['targetStatus']!;

          await _activityRepo.logActivity(
            ActivityLogModel(
              userId: userId,
              title: 'Pregnancy Confirmed',
              subtitle: '$label — Confirmed by AUTO',
              value: '$targetStatus (AUTO)',
              timeUnix: now.millisecondsSinceEpoch,
              iconCode: Icons.favorite.codePoint,
              isPositive: 1,
              metadata: {
                'name': cow.name,
                'tag': cow.tagNumber,
                'method': 'AUTO',
              },
            ),
          );
          didConfirmAny = true;
        }
      }
    }
    return didConfirmAny;
  }

  Future<void> loadCows(int userId) async {
    await fetchCows(userId);
  }

  Future<void> fetchCows(int userId) async {
    _status = CowStatus.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      var baseCows = await _repository.getAllCows(userId);

      final didAutoConfirm = await _runAutoConfirmSweep(userId, baseCows);
      if (didAutoConfirm) {
        baseCows = await _repository.getAllCows(userId);
      }

      final List<CowModel> updatedCows = [];
      for (final cow in baseCows) {
        if (cow.status == 'MILKING' ||
            (cow.status == 'PREGNANT' && getDaysSinceMating(cow) != null && getDaysSinceMating(cow)! < 211) ||
            (cow.status == 'PENDING_CONFIRMATION' && cow.hasLactatedBefore == 1)) {
          final yields = await _repository.getSeasonSessionYields(cow.id!);
          
          updatedCows.add(CowModel(
            id: cow.id,
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
            isDeleted: cow.isDeleted,
            deletedReason: cow.deletedReason,
            deletedDate: cow.deletedDate,
            peakMorningYield: yields['peakMorning'],
            peakEveningYield: yields['peakEvening'],
            lowestMorningYield: yields['lowestMorning'],
            lowestEveningYield: yields['lowestEvening'],
            estimatedBirthDate: cow.estimatedBirthDate,
          ));
        } else {
          updatedCows.add(cow);
        }
      }

      _cows = updatedCows;
      _status = CowStatus.success;
    } catch (e, stacktrace) {
      _errorMessage = e.toString();
      _status = CowStatus.error;
      debugPrint('CowProvider.fetchCows error: $e\n$stacktrace');
    }
    notifyListeners();
  }

  Future<bool> addCow({
    required int userId,
    required String tagNumber,
    String? name,
    String status = 'MILKING',
    String? matingDate,
    int hasLactatedBefore = 0,
    String? estimatedBirthDate,
  }) async {
    _status = CowStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.addCow(
        userId: userId,
        tagNumber: tagNumber,
        name: name,
        status: status,
        matingDate: matingDate,
        hasLactatedBefore: hasLactatedBefore,
        estimatedBirthDate: estimatedBirthDate,
      );
      
      await _activityRepo.logActivity(
        ActivityLogModel(
          userId: userId,
          title: 'New Cow Added',
          subtitle: 'Tag: $tagNumber',
          value: status,
          timeUnix: DateTime.now().millisecondsSinceEpoch,
          iconCode: Icons.pets.codePoint,
          isPositive: 1,
          metadata: {
            'name': name,
            'tag': tagNumber,
          },
        ),
      );

      await fetchCows(userId);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _status = CowStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> recordMating({
    required int cowId,
    required String cowName,
    required String matingDate,
    required int userId,
  }) async {
    _status = CowStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final currentCow = _cows.where((c) => c.id == cowId).firstOrNull;
      if (currentCow == null) {
        _errorMessage = 'Cow not found.';
        _status = CowStatus.error;
        notifyListeners();
        return false;
      }
      await _repository.recordMating(
        cowId: cowId, 
        matingDateString: matingDate,
        newStatus: 'PENDING_CONFIRMATION',
      );
      
      final label = (currentCow.name?.isNotEmpty == true) ? currentCow.name! : currentCow.tagNumber;
      await _activityRepo.logActivity(
        ActivityLogModel(
          userId: userId,
          title: 'Mating Recorded',
          subtitle: '$label — Mating Recorded (Awaiting Confirmation)',
          value: '$matingDate (Pending Confirmation)',
          timeUnix: DateTime.now().millisecondsSinceEpoch,
          iconCode: Icons.favorite.codePoint,
          isPositive: 1,
          metadata: {
            'name': currentCow.name,
            'tag': currentCow.tagNumber,
            'status': 'PENDING_CONFIRMATION',
          },
        ),
      );

      await fetchCows(userId);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _status = CowStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateCowStatus({
    required int cowId,
    required String cowName,
    required String newStatus,
    required int userId,
  }) async {
    _status = CowStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.updateCowStatus(cowId, newStatus);
      
      await _activityRepo.logActivity(
        ActivityLogModel(
          userId: userId,
          title: 'Status Updated',
          subtitle: cowName,
          value: newStatus,
          timeUnix: DateTime.now().millisecondsSinceEpoch,
          iconCode: Icons.update.codePoint,
          isPositive: 1,
          metadata: {
            'name': cowName,
          },
        ),
      );

      await fetchCows(userId);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _status = CowStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateCowGeneral({
    required int cowId,
    required String name,
    required String tagNumber,
    required String status,
    String? matingDate,
    required int hasLactatedBefore,
    String? estimatedBirthDate,
    required int userId,
  }) async {
    _status = CowStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.updateCowGeneral(
        cowId: cowId,
        name: name,
        tagNumber: tagNumber,
        status: status,
        matingDate: matingDate,
        hasLactatedBefore: hasLactatedBefore,
        estimatedBirthDate: estimatedBirthDate,
      );
      
      final label = name.isNotEmpty ? name : tagNumber;
      await _activityRepo.logActivity(
        ActivityLogModel(
          userId: userId,
          title: 'Cow Updated',
          subtitle: label,
          value: status,
          timeUnix: DateTime.now().millisecondsSinceEpoch,
          iconCode: Icons.edit.codePoint,
          isPositive: 1,
          metadata: {
            'name': name,
            'tag': tagNumber,
          },
        ),
      );

      await fetchCows(userId);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _status = CowStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> recordCalving({
    required int cowId,
    required String cowName,
    required int userId,
  }) async {
    _status = CowStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.recordCalving(cowId);
      
      await _activityRepo.logActivity(
        ActivityLogModel(
          userId: userId,
          title: 'Calving Recorded',
          subtitle: cowName,
          value: 'Now Milking',
          timeUnix: DateTime.now().millisecondsSinceEpoch,
          iconCode: Icons.child_care.codePoint,
          isPositive: 1,
          metadata: {
            'name': cowName,
          },
        ),
      );

      await fetchCows(userId);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _status = CowStatus.error;
      notifyListeners();
      return false;
    }
  }

  /// Ends pregnancy due to mid-term loss / abortion and reverts animal status.
  Future<bool> endPregnancy(int cowId, int userId) async {
    _status = CowStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final cow = _cows.where((c) => c.id == cowId).firstOrNull;
      final label = (cow?.name?.isNotEmpty == true) ? cow!.name! : (cow?.tagNumber ?? 'Cow');
      final resetStatus = (cow?.hasLactatedBefore == 1) ? 'MILKING' : 'HEIFER';
      final lactatedFlag = (cow?.hasLactatedBefore == 1) ? 1 : 0;

      await _repository.updateCowGeneral(
        cowId: cowId,
        name: cow?.name ?? '',
        tagNumber: cow?.tagNumber ?? '',
        status: resetStatus,
        matingDate: null,
        deliveryDate: null,
        hasLactatedBefore: lactatedFlag,
        estimatedBirthDate: cow?.estimatedBirthDate,
        isPregnancyConfirmed: 0,
        confirmationDate: null,
        confirmationMethod: null,
      );

      final subtitleStr = (resetStatus == 'MILKING')
          ? '$label — Mid-term loss logged (Reverted to Milking)'
          : '$label — Mid-term loss logged (Reverted to Heifer)';

      await _activityRepo.logActivity(
        ActivityLogModel(
          userId: userId,
          title: 'Pregnancy Ended',
          subtitle: subtitleStr,
          value: 'Mid-term loss logged (Reverted to $resetStatus)',
          timeUnix: DateTime.now().millisecondsSinceEpoch,
          iconCode: Icons.warning_amber_rounded.codePoint,
          isPositive: 0,
          metadata: {
            'name': cow?.name,
            'tag': cow?.tagNumber,
            'revertedStatus': resetStatus,
          },
        ),
      );

      await fetchCows(userId);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _status = CowStatus.error;
      notifyListeners();
      return false;
    }
  }

  /// Confirms pregnancy post-mating via repository transactional operation.
  /// Accepts optional [confirmationDate] (defaults to today) and [method] (defaults to 'SELF').
  Future<bool> confirmPregnancy(
    int cowId,
    int userId, {
    String? confirmationDate,
    String method = 'SELF',
  }) async {
    _status = CowStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final now = DateTime.now();
      final dateStr = confirmationDate ??
          "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      final result = await _repository.confirmPregnancy(
        cowId: cowId,
        confirmationDate: dateStr,
        method: method,
      );

      final cow = _cows.where((c) => c.id == cowId).firstOrNull;
      final label = (cow?.name?.isNotEmpty == true) ? cow!.name! : (cow?.tagNumber ?? 'Cow');
      final isFirst = result['isFirstConfirmation'] == 'true';
      final oldMethod = result['oldMethod']!;
      final targetStatus = result['targetStatus']!;

      // Gap 3 & Gap 4: Activity logging with No-Op Guard
      if (isFirst) {
        await _activityRepo.logActivity(
          ActivityLogModel(
            userId: userId,
            title: 'Pregnancy Confirmed',
            subtitle: '$label — Confirmed by $method',
            value: '$targetStatus ($method)',
            timeUnix: DateTime.now().millisecondsSinceEpoch,
            iconCode: Icons.favorite.codePoint,
            isPositive: 1,
            metadata: {
              'name': cow?.name,
              'tag': cow?.tagNumber,
              'method': method,
            },
          ),
        );
      } else if (oldMethod != method) {
        // Real method override (e.g. AUTO -> VET)
        await _activityRepo.logActivity(
          ActivityLogModel(
            userId: userId,
            title: 'Confirmation Method Updated',
            subtitle: '$label — Updated from $oldMethod to $method',
            value: 'Method Override ($oldMethod → $method)',
            timeUnix: DateTime.now().millisecondsSinceEpoch,
            iconCode: Icons.edit_note_rounded.codePoint,
            isPositive: 1,
            metadata: {
              'name': cow?.name,
              'tag': cow?.tagNumber,
              'oldMethod': oldMethod,
              'newMethod': method,
            },
          ),
        );
      }
      // Gap 4 No-Op Guard: If oldMethod == method on re-call, skip duplicate log.

      await fetchCows(userId);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _status = CowStatus.error;
      notifyListeners();
      return false;
    }
  }

  /// Reports a heat repeat (mating failed) -> resets status and clears mating date.
  Future<bool> reportHeatRepeated(int cowId, int userId) async {
    _status = CowStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final cow = _cows.where((c) => c.id == cowId).firstOrNull;
      final label = (cow?.name?.isNotEmpty == true) ? cow!.name! : (cow?.tagNumber ?? 'Cow');
      final resetStatus = (cow?.hasLactatedBefore == 1) ? 'MILKING' : 'HEIFER';

      await _repository.updateCowGeneral(
        cowId: cowId,
        name: cow?.name ?? '',
        tagNumber: cow?.tagNumber ?? '',
        status: resetStatus,
        matingDate: null,
        hasLactatedBefore: cow?.hasLactatedBefore ?? 0,
        estimatedBirthDate: cow?.estimatedBirthDate,
      );

      await _activityRepo.logActivity(
        ActivityLogModel(
          userId: userId,
          title: 'Heat Repeated',
          subtitle: label,
          value: 'Reset to $resetStatus (Not Pregnant)',
          timeUnix: DateTime.now().millisecondsSinceEpoch,
          iconCode: Icons.refresh_rounded.codePoint,
          isPositive: 0,
          metadata: {
            'name': cow?.name,
            'tag': cow?.tagNumber,
          },
        ),
      );

      await fetchCows(userId);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _status = CowStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteCow({
    required int cowId,
    required String cowName,
    required String reason,
    required int userId,
  }) async {
    _status = CowStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.softDeleteCow(cowId, reason);
      
      await _activityRepo.logActivity(
        ActivityLogModel(
          userId: userId,
          title: 'Cow Removed',
          subtitle: cowName,
          value: reason,
          timeUnix: DateTime.now().millisecondsSinceEpoch,
          iconCode: Icons.remove_circle_outline.codePoint,
          isPositive: 0,
          metadata: {
            'name': cowName,
          },
        ),
      );

      await fetchCows(userId);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _status = CowStatus.error;
      notifyListeners();
      return false;
    }
  }



  Future<Map<String, int?>> getSeasonSessionYields(int cowId) async {
    return _repository.getSeasonSessionYields(cowId);
  }

  Future<Map<String, dynamic>?> getLatestSeason(int cowId) async {
    return _repository.getLatestSeason(cowId);
  }

  Future<List<Map<String, dynamic>>> getSessionsForSeason(int seasonId) async {
    return _repository.getSessionsForSeason(seasonId);
  }

  Future<List<Map<String, dynamic>>> getMonthlySummariesForSeason(int seasonId) async {
    return _repository.getMonthlySummariesForSeason(seasonId);
  }

  Future<bool> deleteMilkSession(int cowId, String date, String session) async {
    _status = CowStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.deleteMilkSession(cowId, date, session);
      if (_cows.isNotEmpty) {
        await fetchCows(_cows.first.userId);
      }
      _status = CowStatus.success;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _status = CowStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateMilkSession(int cowId, String date, String session, int newGrams) async {
    _status = CowStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.updateMilkSession(cowId, date, session, newGrams);
      if (_cows.isNotEmpty) {
        await fetchCows(_cows.first.userId);
      }
      _status = CowStatus.success;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _status = CowStatus.error;
      notifyListeners();
      return false;
    }
  }
}


