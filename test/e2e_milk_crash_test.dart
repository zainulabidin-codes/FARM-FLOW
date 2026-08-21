import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_farm_app/main.dart';
import 'package:dairy_farm_app/core/database/database_helper.dart';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseHelper.initForPlatform();
    final dbPath = await getDatabasesPath();
    await databaseFactory.deleteDatabase(join(dbPath, 'dairy_farm.db'));
  });

  testWidgets('Full app milk tab crash test', (tester) async {
    await tester.pumpWidget(const DairyFarmApp());
    await tester.pumpAndSettle();
    
    // AuthScreen: tap Create Farm Profile button
    final createBtn = find.byIcon(Icons.person_add_alt_1_rounded);
    expect(createBtn, findsOneWidget);
    await tester.tap(createBtn);
    await tester.pumpAndSettle();
    
    // RegisterScreen: fill 4 text fields by index
    final textFields = find.byType(TextField);
    expect(textFields, findsNWidgets(4));
    
    await tester.enterText(textFields.at(0), 'Test Farm');
    await tester.enterText(textFields.at(1), 'Test Farmer');
    await tester.enterText(textFields.at(2), 'testuser');
    await tester.enterText(textFields.at(3), 'password123');
    await tester.pumpAndSettle();
    
    // Submit registration button
    await tester.tap(find.byType(ElevatedButton).first);
    await tester.pumpAndSettle();
    
    // Tap the Milk tab in the bottom nav bar
    try {
      final milkIcon = find.byIcon(Icons.water_drop_outlined);
      if (milkIcon.evaluate().isNotEmpty) {
        await tester.tap(milkIcon.first);
        await tester.pumpAndSettle();
        debugPrint('TAP SUCCEEDED, NO CRASH');
      }
    } catch (e, st) {
      debugPrint('CAUGHT EXCEPTION DURING TAP: $e');
      debugPrint('STACK TRACE:\n$st');
    }
  });
}
