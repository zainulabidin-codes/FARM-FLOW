import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:dairy_farm_app/features/cows/presentation/models/cow_ui_model.dart';
import 'package:dairy_farm_app/features/cows/data/models/cow_model.dart';
import 'package:dairy_farm_app/features/cows/presentation/pages/cows_screen.dart';
import 'package:dairy_farm_app/features/cows/presentation/providers/cow_provider.dart' hide CowStatus;
import 'package:dairy_farm_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:dairy_farm_app/features/dodi_ledger/presentation/providers/dodi_provider.dart';
import 'package:dairy_farm_app/features/milk_entry/presentation/providers/milk_entry_provider.dart';
import 'package:dairy_farm_app/features/dashboard/presentation/providers/activity_log_provider.dart';
import 'package:dairy_farm_app/features/shell/presentation/pages/app_shell.dart';

class FakeCowProvider extends CowProvider {
  final List<CowModel> mockCows;
  FakeCowProvider(this.mockCows);

  @override
  List<CowModel> get cows => mockCows;

  @override
  int? getDaysSinceMating(CowModel cow) {
    if (cow.matingDate == null || cow.matingDate!.isEmpty) return null;
    return 24;
  }
}

void main() {
  Widget createHarness(Widget child, {CowProvider? cowProvider}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: AuthProvider()),
        ChangeNotifierProvider<DodiProvider>.value(value: DodiProvider()),
        ChangeNotifierProvider<MilkEntryProvider>.value(value: MilkEntryProvider()),
        ChangeNotifierProvider<CowProvider>.value(value: cowProvider ?? CowProvider()),
        ChangeNotifierProvider<ActivityLogProvider>.value(value: ActivityLogProvider()),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  Widget createCowsScreenHarness(CowUiModel cow) {
    return createHarness(
      CowsScreen(
        cows: [cow],
        selectedFilter: 'All',
        currentNavIndex: 3,
        onFilterChanged: (_) {},
        onAddCowTap: () {},
        onCowCardTap: (_) {},
        onCowCardLongPress: (_) {},
        onNavTap: (_) {},
      ),
    );
  }

  group('Phase 4 Widget Tests — Tier-1 Quick Button Boundary Conditions', () {
    testWidgets('Day 20: Confirm Pregnancy button is NOT rendered', (tester) async {
      const cow = CowUiModel(
        id: '1',
        tagNumber: 'TAG20',
        name: 'Day 20 Cow',
        status: CowStatus.pendingConfirmation,
        daysSinceMating: 19,
      );

      await tester.pumpWidget(createCowsScreenHarness(cow));
      await tester.pump();

      expect(find.text('Mating Recorded • Day 20 of 28 (Observation Window)'), findsOneWidget);
      expect(find.text('Confirm Pregnancy'), findsNothing);
    });

    testWidgets('Day 21: Confirm Pregnancy button IS rendered (exact boundary start)', (tester) async {
      const cow = CowUiModel(
        id: '2',
        tagNumber: 'TAG21',
        name: 'Day 21 Cow',
        status: CowStatus.pendingConfirmation,
        daysSinceMating: 20,
      );

      await tester.pumpWidget(createCowsScreenHarness(cow));
      await tester.pump();

      expect(find.text('Mating Recorded • Day 21 of 28 (Observation Window)'), findsOneWidget);
      expect(find.text('Confirm Pregnancy'), findsOneWidget);
    });

    testWidgets('Day 28: Confirm Pregnancy button IS rendered (exact boundary end)', (tester) async {
      const cow = CowUiModel(
        id: '3',
        tagNumber: 'TAG28',
        name: 'Day 28 Cow',
        status: CowStatus.pendingConfirmation,
        daysSinceMating: 27,
      );

      await tester.pumpWidget(createCowsScreenHarness(cow));
      await tester.pump();

      expect(find.text('Mating Recorded • Day 28 of 28 (Observation Window)'), findsOneWidget);
      expect(find.text('Confirm Pregnancy'), findsOneWidget);
    });

    testWidgets('Day 29: Confirm Pregnancy button is NOT rendered', (tester) async {
      const cow = CowUiModel(
        id: '4',
        tagNumber: 'TAG29',
        name: 'Day 29 Cow',
        status: CowStatus.pendingConfirmation,
        daysSinceMating: 28,
      );

      await tester.pumpWidget(createCowsScreenHarness(cow));
      await tester.pump();

      expect(find.text('Mating Recorded • Day 29 of 28 (Observation Window)'), findsOneWidget);
      expect(find.text('Confirm Pregnancy'), findsNothing);
    });
  });

  group('Phase 4 Widget Tests — Long-Press Dialog Action Set Verification', () {
    testWidgets('Bucket 1 (PENDING_CONFIRMATION): Dialog displays Confirm Pregnancy, Heat Repeated, and Delete Cow', (tester) async {
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('overflowed')) return;
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      final cow = CowModel(
        id: 10,
        userId: 1,
        tagNumber: 'TAG10',
        name: 'Pending Cow 10',
        status: 'PENDING_CONFIRMATION',
        matingDate: '2026-08-15',
        hasLactatedBefore: 1,
      );
      final fakeProvider = FakeCowProvider([cow]);
      final shellKey = GlobalKey<AppShellState>();

      await tester.pumpWidget(createHarness(AppShell(key: shellKey, userId: 1), cowProvider: fakeProvider));
      await tester.pumpAndSettle();

      shellKey.currentState!.onCowCardLongPress('10');
      await tester.pumpAndSettle();

      // Verify exact 3-option set for PENDING_CONFIRMATION
      expect(find.text('Confirm Pregnancy'), findsOneWidget);
      expect(find.text('Heat Repeated / Cancel Mating'), findsOneWidget);
      expect(find.text('Remove / Delete Cow'), findsOneWidget);

      // Verify confirmed pregnancy options are NOT present
      expect(find.text('End Pregnancy (Mid-Term Loss)'), findsNothing);
      expect(find.text('Override Confirmation Method'), findsNothing);
    });

    testWidgets('Bucket 2 (PREGNANT/BRED_HEIFER/DRY): Dialog displays End Pregnancy, Override Method, and Delete Cow', (tester) async {
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('overflowed')) return;
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      final cow = CowModel(
        id: 20,
        userId: 1,
        tagNumber: 'TAG20',
        name: 'Confirmed Pregnant Cow 20',
        status: 'PREGNANT',
        matingDate: '2026-07-01',
        hasLactatedBefore: 1,
        isPregnancyConfirmed: 1,
        confirmationMethod: 'VET',
      );
      final fakeProvider = FakeCowProvider([cow]);
      final shellKey = GlobalKey<AppShellState>();

      await tester.pumpWidget(createHarness(AppShell(key: shellKey, userId: 1), cowProvider: fakeProvider));
      await tester.pumpAndSettle();

      shellKey.currentState!.onCowCardLongPress('20');
      await tester.pumpAndSettle();

      // Verify exact 3-option set for PREGNANT
      expect(find.text('End Pregnancy (Mid-Term Loss)'), findsOneWidget);
      expect(find.text('Override Confirmation Method'), findsOneWidget);
      expect(find.text('Remove / Delete Cow'), findsOneWidget);

      // Verify unconfirmed mating options are NOT present
      expect(find.text('Confirm Pregnancy'), findsNothing);
      expect(find.text('Heat Repeated / Cancel Mating'), findsNothing);
    });

    testWidgets('Bucket 3 (Unconfirmed MILKING/DRY/HEIFER): Directly opens Delete Cow Dialog', (tester) async {
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('overflowed')) return;
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      final cow = CowModel(
        id: 30,
        userId: 1,
        tagNumber: 'TAG30',
        name: 'Unconfirmed Milking Cow 30',
        status: 'MILKING',
        hasLactatedBefore: 1,
      );
      final fakeProvider = FakeCowProvider([cow]);
      final shellKey = GlobalKey<AppShellState>();

      await tester.pumpWidget(createHarness(AppShell(key: shellKey, userId: 1), cowProvider: fakeProvider));
      await tester.pumpAndSettle();

      shellKey.currentState!.onCowCardLongPress('30');
      await tester.pumpAndSettle();

      // Verify directly opens _DeleteCowDialog
      expect(find.text('Remove "Unconfirmed Milking Cow 30"?'), findsOneWidget);
      expect(find.text('Reason for removal *'), findsOneWidget);

      // Verify pregnancy management options are NOT present
      expect(find.text('Confirm Pregnancy'), findsNothing);
      expect(find.text('End Pregnancy (Mid-Term Loss)'), findsNothing);
      expect(find.text('Override Confirmation Method'), findsNothing);
      expect(find.text('Heat Repeated / Cancel Mating'), findsNothing);
    });

    testWidgets('Standing Rule Test: AppShell maps raw DB status PENDING_CONFIRMATION correctly', (tester) async {
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('overflowed')) return;
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      final cow = CowModel(
        id: 99,
        userId: 1,
        tagNumber: 'TAG99',
        name: 'Pending Cow 99',
        status: 'PENDING_CONFIRMATION',
        matingDate: '2026-08-15',
        hasLactatedBefore: 0,
      );
      final fakeProvider = FakeCowProvider([cow]);

      await tester.pumpWidget(createHarness(const AppShell(userId: 1, initialIndex: 3), cowProvider: fakeProvider));
      await tester.pumpAndSettle();

      // Verify that PENDING_CONFIRMATION is mapped to CowStatus.pendingConfirmation
      // and renders the green "Confirm Pregnancy" button for Day 24 (within Day 21-28)
      expect(find.text('Confirm Pregnancy'), findsOneWidget);
    });
  });
}
