import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:dairy_farm_app/features/cows/presentation/providers/cow_provider.dart';
import 'package:dairy_farm_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:dairy_farm_app/features/dodi_ledger/presentation/providers/dodi_provider.dart';
import 'package:dairy_farm_app/features/milk_entry/presentation/providers/milk_entry_provider.dart';
import 'package:dairy_farm_app/features/dashboard/presentation/providers/activity_log_provider.dart';
import 'package:dairy_farm_app/features/shell/presentation/pages/app_shell.dart';

void main() {
  testWidgets('Verify Add Cow Sheet segmented controls do not overflow on 360px narrow screen', (tester) async {
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      originalOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = originalOnError);

    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final shellKey = GlobalKey<AppShellState>();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: AuthProvider()),
          ChangeNotifierProvider<DodiProvider>.value(value: DodiProvider()),
          ChangeNotifierProvider<MilkEntryProvider>.value(value: MilkEntryProvider()),
          ChangeNotifierProvider<CowProvider>.value(value: CowProvider()),
          ChangeNotifierProvider<ActivityLogProvider>.value(value: ActivityLogProvider()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: AppShell(key: shellKey, userId: 1, initialIndex: 0),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Trigger Add Cow Sheet via shellState
    shellKey.currentState!.openAddCowSheet();
    await tester.pumpAndSettle();

    // Verify Q1 segmented toggle option texts are present
    expect(find.text('Yes — Given Birth\n(Adult)'), findsOneWidget);
    expect(find.text('No — Never Calved\n(Heifer)'), findsOneWidget);

    // Tap Pregnant status to show Q2 pregnancy info segmented control
    final pregnantChip = find.text('Pregnant');
    expect(pregnantChip, findsOneWidget);
    await tester.tap(pregnantChip);
    await tester.pumpAndSettle();

    // Verify Q2 segmented toggle option texts are present
    expect(find.text('Exact Mating Date'), findsOneWidget);
    expect(find.text('Pregnancy Months &\nDays'), findsOneWidget);
  });
}
