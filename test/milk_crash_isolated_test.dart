import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dairy_farm_app/core/routing/app_router.dart';
import 'package:dairy_farm_app/features/dodi_ledger/presentation/providers/dodi_provider.dart';
import 'package:dairy_farm_app/features/milk_entry/presentation/providers/milk_entry_provider.dart';
import 'package:dairy_farm_app/features/auth/presentation/providers/auth_provider.dart';

void main() {
  testWidgets('Trigger Milk Crash', (tester) async {
    final authProvider = AuthProvider();
    final dodiProvider = DodiProvider();
    final milkProvider = MilkEntryProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<DodiProvider>.value(value: dodiProvider),
          ChangeNotifierProvider<MilkEntryProvider>.value(value: milkProvider),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  AppRouter.pushMilkEntry(context, dodiId: null);
                },
                child: const Text('Tap'),
              );
            },
          ),
        ),
      ),
    );

    try {
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      debugPrint('TAP SUCCEEDED');
    } catch (e, st) {
      debugPrint('CAUGHT EXCEPTION: $e');
      debugPrint('STACK TRACE:\n$st');
    }
  });
}
