import 'package:sqflite/sqflite.dart';
import '../../../../core/database/database_helper.dart';
import '../models/activity_log_model.dart';

class ActivityLogLocalDatasource {
  Future<void> logActivity(ActivityLogModel activity) async {
    final Database db = await DatabaseHelper.instance.database;
    await db.insert('activity_log', activity.toMap());
  }

  Future<List<ActivityLogModel>> getActivities(int userId) async {
    final Database db = await DatabaseHelper.instance.database;
    
    // Delete logs older than 10 days
    final tenDaysAgo = DateTime.now().subtract(const Duration(days: 10)).millisecondsSinceEpoch;
    await db.delete(
      'activity_log',
      where: 'user_id = ? AND time_unix < ?',
      whereArgs: [userId, tenDaysAgo],
    );

    // Fetch remaining logs
    final List<Map<String, dynamic>> rows = await db.query(
      'activity_log',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'time_unix DESC',
    );

    return rows.map(ActivityLogModel.fromMap).toList();
  }
}
