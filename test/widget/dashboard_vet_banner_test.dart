import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_farm_app/features/dashboard/presentation/pages/dashboard_screen.dart';

void main() {
  group('DashboardScreen Vet Banner Tests', () {
    testWidgets('DashboardScreen renders vet banner with upcoming appointment subtitle', (tester) async {
      bool bannerTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardScreen(
              farmName: 'Test Dairy Farm',
              totalMilk: '120.0',
              morningMilk: '70.0',
              eveningMilk: '50.0',
              totalCows: '15',
              activeCows: '10',
              pregnantCount: '3',
              dryCount: '2',
              recentActivities: const [],
              onMilkEntryTap: () {},
              onDodiTap: () {},
              onNavTap: (_) {},
              onAddCowTap: () {},
              onViewAllTap: () {},
              vetCheckSubtitle: 'Cow #COW-010 visit on 2026-11-10 at 10:30 AM',
              onVetCheckBannerTap: () {
                bannerTapped = true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Scheduled Vet Check'), findsOneWidget);
      expect(find.text('Cow #COW-010 visit on 2026-11-10 at 10:30 AM'), findsOneWidget);

      await tester.tap(find.text('Scheduled Vet Check'));
      await tester.pumpAndSettle();

      expect(bannerTapped, isTrue);
    });

    testWidgets('DashboardScreen renders fallback empty state when vetCheckSubtitle is null', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardScreen(
              farmName: 'Test Dairy Farm',
              totalMilk: '0.0',
              morningMilk: '0.0',
              eveningMilk: '0.0',
              totalCows: '0',
              activeCows: '0',
              pregnantCount: '0',
              dryCount: '0',
              recentActivities: const [],
              onMilkEntryTap: () {},
              onDodiTap: () {},
              onNavTap: (_) {},
              onAddCowTap: () {},
              onViewAllTap: () {},
              vetCheckSubtitle: null,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Scheduled Vet Check'), findsOneWidget);
      expect(find.text('No upcoming visits • Tap to schedule'), findsOneWidget);
    });
  });
}

