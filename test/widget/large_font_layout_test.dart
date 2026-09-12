import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:dairy_farm_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:dairy_farm_app/features/dodi_ledger/data/models/dodi_model.dart';
import 'package:dairy_farm_app/features/dodi_ledger/presentation/providers/dodi_provider.dart';
import 'package:dairy_farm_app/features/milk_entry/presentation/providers/milk_entry_provider.dart';
import 'package:dairy_farm_app/features/cows/data/models/cow_model.dart';
import 'package:dairy_farm_app/features/cows/presentation/models/cow_ui_model.dart';
import 'package:dairy_farm_app/features/cows/presentation/providers/cow_provider.dart' hide CowStatus;
import 'package:dairy_farm_app/features/dashboard/presentation/providers/activity_log_provider.dart';

import 'package:dairy_farm_app/features/dashboard/presentation/pages/dashboard_screen.dart';
import 'package:dairy_farm_app/features/cows/presentation/pages/cows_screen.dart';
import 'package:dairy_farm_app/features/cows/presentation/pages/edit_cow_sheet.dart';
import 'package:dairy_farm_app/features/milk_entry/presentation/pages/milk_entry_screen.dart';
import 'package:dairy_farm_app/features/shell/presentation/pages/app_shell.dart';

// Fake Dodi Provider to simulate having buyers
class FakeDodiProvider extends DodiProvider {
  final List<DodiModel> mockDodis;
  FakeDodiProvider(this.mockDodis);
  
  @override
  List<DodiModel> get dodis => mockDodis;
}

// Fake Cow Provider
class FakeCowProvider extends CowProvider {
  final List<CowModel> mockCows;
  FakeCowProvider(this.mockCows);

  @override
  List<CowModel> get cows => mockCows;
}

void main() {
  Widget createHarness(Widget child, {DodiProvider? dodiProvider, CowProvider? cowProvider}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: AuthProvider()),
        ChangeNotifierProvider<DodiProvider>.value(value: dodiProvider ?? DodiProvider()),
        ChangeNotifierProvider<MilkEntryProvider>.value(value: MilkEntryProvider()),
        ChangeNotifierProvider<CowProvider>.value(value: cowProvider ?? CowProvider()),
        ChangeNotifierProvider<ActivityLogProvider>.value(value: ActivityLogProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        // Override MediaQuery to force 2.0x text scaling
        builder: (context, childWidget) {
          final data = MediaQuery.of(context);
          return MediaQuery(
            data: data.copyWith(
              textScaler: const TextScaler.linear(2.0),
              // Force standard mobile viewport size
              size: const Size(360, 640),
            ),
            child: childWidget!,
          );
        },
        home: child,
      ),
    );
  }

  group('Large Font Layout Tests (2.0x Scale)', () {
    // 1. DashboardScreen
    testWidgets('DashboardScreen renders without overflow at 2.0x scale', (tester) async {
      await tester.pumpWidget(
        createHarness(
          DashboardScreen(
            farmName: 'Test Farm',
            totalMilk: '150.0',
            morningMilk: '70.0',
            eveningMilk: '80.0',
            totalCows: '10',
            activeCows: '5',
            pregnantCount: '2',
            dryCount: '1',
            bredHeiferCount: '1',
            heiferCount: '1',
            recentActivities: const [],
            onMilkEntryTap: () {},
            onDodiTap: () {},
            onNavTap: (_) {},
            onAddCowTap: () {},
            onViewAllTap: () {},
          ),
        ),
      );
      
      // Allow animations and images to settle
      await tester.pumpAndSettle();
      
      // Implicitly asserts that no RenderFlex overflow exceptions occurred during layout
      expect(tester.takeException(), isNull);
    });

    // 2. MilkEntryScreen
    testWidgets('MilkEntryScreen renders without overflow at 2.0x scale', (tester) async {
      final fakeDodis = [
        const DodiModel(id: 1, userId: 1, name: 'Buyer A', defaultRatePaise: 5000, isDeleted: 0),
      ];
      final provider = FakeDodiProvider(fakeDodis);
      
      await tester.pumpWidget(
        createHarness(
          MilkEntryScreen(
            initialDodiId: 1, // Start in Numpad state
            onSaveEntry: (id, name, qty, sess, rate, date, tag) {},
          ),
          dodiProvider: provider,
        ),
      );
      
      await tester.pumpAndSettle();
      
      // Tap some numpad keys to fill the quantity display
      final key9 = find.text('9');
      final key0 = find.text('0');
      if (key9.evaluate().isNotEmpty && key0.evaluate().isNotEmpty) {
        await tester.tap(key9);
        await tester.pump();
        await tester.tap(key0);
        await tester.pump();
        await tester.tap(key0);
        await tester.pumpAndSettle();
      }
      
      expect(tester.takeException(), isNull);
    });

    // 3. CowsScreen
    testWidgets('CowsScreen card details render without overflow at 2.0x scale', (tester) async {
      const cow = CowUiModel(
        id: '1',
        tagNumber: 'TAG-123',
        name: 'Test Cow',
        status: CowStatus.pendingConfirmation, // Will render _PendingConfirmationDetails
        daysSinceMating: 24, // Will render Confirm Pregnancy button
      );
      
      await tester.pumpWidget(
        createHarness(
          CowsScreen(
            cows: const [cow],
            selectedFilter: 'All',
            currentNavIndex: 0,
            onFilterChanged: (_) {},
            onAddCowTap: () {},
            onCowCardTap: (_) {},
            onCowCardLongPress: (_) {},
            onNavTap: (_) {},
          ),
        ),
      );
      
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    // 4. EditCowSheet (and CowAgePicker implicitly)
    testWidgets('EditCowSheet and AgePicker render without overflow at 2.0x scale', (tester) async {
      final cowModel = CowModel(
        id: 1,
        userId: 1,
        tagNumber: 'TAG-123',
        status: 'BRED_HEIFER',
        hasLactatedBefore: 0,
      );
      final fakeCowProvider = FakeCowProvider([cowModel]);
      
      await tester.pumpWidget(
        createHarness(
          Scaffold(
            body: EditCowSheet(cow: cowModel),
          ),
          cowProvider: fakeCowProvider,
        ),
      );
      
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
