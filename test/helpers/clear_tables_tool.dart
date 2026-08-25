import 'package:flutter/foundation.dart';
import 'package:dairy_farm_app/core/database/database_helper.dart';

/// Helper function to truncate all database tables for testing setup.
/// Note: This is NOT a unit test and will not execute automatically during `flutter test`.
Future<void> clearAllTablesForTesting() async {
  DatabaseHelper.initForPlatform();
  final db = await DatabaseHelper.instance.database;
  await db.execute('DELETE FROM users');
  await db.execute('DELETE FROM dodis');
  await db.execute('DELETE FROM cows');
  await db.execute('DELETE FROM ledger');
  debugPrint('ALL TABLES CLEARED');
}
