import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'dart:io';

/// Helper function to reset/delete the local SQLite database for development or explicit testing.
/// Note: This is NOT a unit test and will not execute automatically during `flutter test`.
Future<void> clearDatabaseForTesting() async {
  sqfliteFfiInit();
  var databaseFactory = databaseFactoryFfi;
  var path = await databaseFactory.getDatabasesPath();
  var dbPath = join(path, 'dairy_farm.db');
  debugPrint('DB PATH: $dbPath');
  if (File(dbPath).existsSync()) {
    debugPrint('FILE EXISTS, DELETING...');
    await databaseFactory.deleteDatabase(dbPath);
    debugPrint('DELETED');
  } else {
    debugPrint('FILE DOES NOT EXIST');
  }
}
