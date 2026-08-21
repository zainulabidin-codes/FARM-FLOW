import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'dart:io';

void main() {
  test('print db path', () async {
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
  });
}
