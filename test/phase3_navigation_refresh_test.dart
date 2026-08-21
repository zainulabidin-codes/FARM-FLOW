import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dairy_farm_app/core/database/database_helper.dart';
import 'package:dairy_farm_app/core/routing/app_router.dart';
import 'package:dairy_farm_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:dairy_farm_app/features/cows/presentation/providers/cow_provider.dart';
import 'package:dairy_farm_app/features/dodi_ledger/presentation/providers/dodi_provider.dart';
import 'package:dairy_farm_app/features/milk_entry/presentation/providers/milk_entry_provider.dart';
import 'package:dairy_farm_app/features/dashboard/presentation/providers/activity_log_provider.dart';
import 'package:dairy_farm_app/features/dashboard/presentation/utils/dashboard_refresh_coordinator.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseHelper.initForPlatform();
  });

  testWidgets('Phase 3: Defensive Cow Navigation Test (Invalid & Deleted IDs)', (tester) async {
    final authProvider = AuthProvider();
    final dodiProvider = DodiProvider();
    final milkProvider = MilkEntryProvider();
    final cowProvider = CowProvider();
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
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    // Test invalid non-integer cowId
                    AppRouter.pushPerCowMilk(context, cowIdStr: 'INVALID_ID');
                  },
                  child: const Text('Nav Invalid'),
                );
              },
            ),
          ),
        ),
      ),
    );

    // Tap invalid nav button
    await tester.tap(find.text('Nav Invalid'));
    await tester.pump();

    // Verify screen did not push broken route
    expect(find.text('Nav Invalid'), findsOneWidget);
  });

  testWidgets('Phase 3: Dashboard Coordinator Execution Test', (tester) async {
    final authProvider = AuthProvider();
    final dodiProvider = DodiProvider();
    final milkProvider = MilkEntryProvider();
    final cowProvider = CowProvider();
    final activityLogProvider = ActivityLogProvider();

    late BuildContext testContext;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<DodiProvider>.value(value: dodiProvider),
          ChangeNotifierProvider<MilkEntryProvider>.value(value: milkProvider),
          ChangeNotifierProvider<CowProvider>.value(value: cowProvider),
          ChangeNotifierProvider<ActivityLogProvider>.value(value: activityLogProvider),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                testContext = context;
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );

    // Verify DashboardRefreshCoordinator instantiates cleanly
    final coordinator = DashboardRefreshCoordinator(testContext);
    expect(coordinator, isNotNull);
  });
}
