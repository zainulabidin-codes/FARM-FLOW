import '../datasources/activity_log_local_datasource.dart';
import '../models/activity_log_model.dart';

class ActivityLogRepository {
  final ActivityLogLocalDatasource _datasource;

  ActivityLogRepository({ActivityLogLocalDatasource? datasource})
      : _datasource = datasource ?? ActivityLogLocalDatasource();

  Future<void> logActivity(ActivityLogModel activity) {
    return _datasource.logActivity(activity);
  }

  Future<List<ActivityLogModel>> getActivities(int userId) {
    return _datasource.getActivities(userId);
  }
}
