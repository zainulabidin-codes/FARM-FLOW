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
    final cow = _cows.firstWhere(
      (c) => c.id == cowId,
      orElse: () => const CowModel(userId: 0, tagNumber: ''),
    );
    return cow.hasLactatedBefore == 1;
  }

  List<CowModel> get milkingCows =>
      _cows.where((c) {
        if (c.isDeleted == 1) return false;
        // STRICT FIREWALL: Must have lactated at least once in her lifetime!
        if (c.hasLactatedBefore != 1) return false;

        if (c.status == 'MILKING') return true;
        if (c.status == 'PREGNANT') {
          final days = getDaysSinceMating(c);
          if (days != null && days < 211) return true;
        }
        return false;
      }).toList();

  bool _isRollupRunning = false;
  bool get isRollupRunning => _isRollupRunning;

  int? getDaysSinceMating(CowModel cow) {
    if (cow.matingDate == null || cow.matingDate!.isEmpty) return null;
    try {
      final date = DateTime.parse(cow.matingDate!);
      final days = DateTime.now().difference(date).inDays;
      return days < 0 ? 0 : days;
    } catch (_) {
      return null;
    }
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
      
      final cow = _cows.firstWhere(
        (c) => c.id == cowId,
        orElse: () => const CowModel(userId: 0, tagNumber: 'Unknown'),
      );
      
      if (cow.userId != 0) {
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

  Future<void> loadCows(int userId) async {
    await fetchCows(userId);
  }

  Future<void> fetchCows(int userId) async {
    _status = CowStatus.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      final baseCows = await _repository.getAllCows(userId);

      final List<CowModel> updatedCows = [];
      for (final cow in baseCows) {
        if (cow.status == 'MILKING' || (cow.status == 'PREGNANT' && getDaysSinceMating(cow) != null && getDaysSinceMating(cow)! < 211)) {
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
      final currentCow = _cows.firstWhere((c) => c.id == cowId);
      final newStatus = currentCow.status == 'HEIFER' ? 'BRED_HEIFER' : 'PREGNANT';

      await _repository.recordMating(
        cowId: cowId, 
        matingDateString: matingDate,
        newStatus: newStatus,
      );
      
      await _activityRepo.logActivity(
        ActivityLogModel(
          userId: userId,
          title: 'Mating Recorded',
          subtitle: cowName,
          value: matingDate,
          timeUnix: DateTime.now().millisecondsSinceEpoch,
          iconCode: Icons.favorite.codePoint,
          isPositive: 1,
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

  /// Ends pregnancy due to mid-term loss / abortion and reverts animal to MILKING status.
  Future<bool> endPregnancy(int cowId, int userId) async {
    _status = CowStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final cow = _cows.where((c) => c.id == cowId).firstOrNull;
      final label = (cow?.name?.isNotEmpty == true) ? cow!.name! : (cow?.tagNumber ?? 'Cow');

      await _repository.updateCowGeneral(
        cowId: cowId,
        name: cow?.name ?? '',
        tagNumber: cow?.tagNumber ?? '',
        status: 'MILKING',
        matingDate: null,
        hasLactatedBefore: 1, // Mid-term loss triggers lactation -> automatically MILKING
        estimatedBirthDate: cow?.estimatedBirthDate,
      );

      await _activityRepo.logActivity(
        ActivityLogModel(
          userId: userId,
          title: 'Pregnancy Ended',
          subtitle: label,
          value: 'Mid-term loss logged (Reverted to Milking)',
          timeUnix: DateTime.now().millisecondsSinceEpoch,
          iconCode: Icons.warning_amber_rounded.codePoint,
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

  /// Confirms pregnancy post-mating.
  Future<bool> confirmPregnancy(int cowId, int userId) async {
    _status = CowStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final cow = _cows.where((c) => c.id == cowId).firstOrNull;
      final label = (cow?.name?.isNotEmpty == true) ? cow!.name! : (cow?.tagNumber ?? 'Cow');
      final newStatus = (cow?.status == 'HEIFER' || cow?.status == 'BRED_HEIFER') ? 'BRED_HEIFER' : 'PREGNANT';

      await _repository.updateCowGeneral(
        cowId: cowId,
        name: cow?.name ?? '',
        tagNumber: cow?.tagNumber ?? '',
        status: newStatus,
        matingDate: cow?.matingDate,
        hasLactatedBefore: cow?.hasLactatedBefore ?? 0,
        estimatedBirthDate: cow?.estimatedBirthDate,
      );

      await _activityRepo.logActivity(
        ActivityLogModel(
          userId: userId,
          title: 'Pregnancy Confirmed',
          subtitle: label,
          value: newStatus == 'BRED_HEIFER' ? 'Bred Heifer' : 'Confirmed Pregnant',
          timeUnix: DateTime.now().millisecondsSinceEpoch,
          iconCode: Icons.favorite.codePoint,
          isPositive: 1,
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


