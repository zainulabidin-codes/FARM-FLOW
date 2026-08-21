import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_farm_app/core/database/database_helper.dart';

void main() {
  test('clear all tables', () async {
    DatabaseHelper.initForPlatform();
    final db = await DatabaseHelper.instance.database;
    await db.execute('DELETE FROM users');
    await db.execute('DELETE FROM dodis');
    await db.execute('DELETE FROM cows');
    await db.execute('DELETE FROM ledger');
    debugPrint('ALL TABLES CLEARED');
  });
}
