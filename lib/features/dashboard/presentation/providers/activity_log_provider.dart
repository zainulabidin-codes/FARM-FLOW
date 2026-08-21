import 'package:flutter/foundation.dart';
import '../../data/models/activity_log_model.dart';
import '../../data/repositories/activity_log_repository.dart';

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

  Future<void> loadActivities(int userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _activities = await _repository.getActivities(userId);
    } catch (e) {
      _error = 'Failed to load activities: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
