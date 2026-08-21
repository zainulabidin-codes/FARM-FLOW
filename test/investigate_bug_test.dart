import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test('investigate bug harness', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    expect(databaseFactory, isNotNull);
  });
}
