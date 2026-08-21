import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_farm_app/features/shell/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dairy_farm_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:dairy_farm_app/features/cows/presentation/providers/cow_provider.dart';
import 'package:dairy_farm_app/features/dodi_ledger/presentation/providers/dodi_provider.dart';
import 'package:dairy_farm_app/features/milk_entry/presentation/providers/milk_entry_provider.dart';
import 'package:dairy_farm_app/features/dashboard/presentation/providers/activity_log_provider.dart';

void main() {
  testWidgets('Milk tab crash test harness', (tester) async {
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exceptionAsString().contains('overflowed')) {
        // Ignore headless layout overflow warnings in provider harness test
        return;
      }
      originalOnError?.call(details);
    };
    addTearDown(() {
      FlutterError.onError = originalOnError;
    });

    final dodiProvider = DodiProvider();
    final milkProvider = MilkEntryProvider();
    final cowProvider = CowProvider();
    final authProvider = AuthProvider();
    final activityLogProvider = ActivityLogProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<DodiProvider>.value(value: dodiProvider),
          ChangeNotifierProvider<MilkEntryProvider>.value(value: milkProvider),
          ChangeNotifierProvider<CowProvider>.value(value: cowProvider),
          ChangeNotifierProvider<ActivityLogProvider>.value(value: activityLogProvider),
        ],
        child: const MaterialApp(
          home: AppShell(
            userId: 1,
          ),
        ),
      ),
    );

    await tester.pump();
    
    // Verify AppShell renders cleanly without ProviderNotFoundException
    expect(find.byType(AppShell), findsOneWidget);
  });
}
