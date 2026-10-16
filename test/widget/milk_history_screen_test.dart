import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_farm_app/features/milk_entry/data/models/milk_history_models.dart';
import 'package:dairy_farm_app/features/milk_entry/data/repositories/milk_history_repository.dart';
import 'package:dairy_farm_app/features/milk_entry/presentation/pages/milk_history_screen.dart';

class FakeMilkHistoryRepository implements MilkHistoryRepository {
  final DateTime earliestActivityDate;
  final MilkHistoryOverview overviewToReturn;

  FakeMilkHistoryRepository({
    required this.earliestActivityDate,
    required this.overviewToReturn,
  });

  @override
  Future<DateTime> getEarliestUserActivityDate(int userId) async {
    return earliestActivityDate;
  }

  @override
  Future<MilkHistoryOverview> getMilkHistoryForMonth({
    required int userId,
    required DateTime month,
    int? daysToShow,
  }) async {
    return overviewToReturn;
  }

  @override
  Future<({ExportMilkSummary summary, List<ExportMilkLog> logs})> getExportDataForRange({
    required int userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    return (summary: ExportMilkSummary.empty, logs: const <ExportMilkLog>[]);
  }
}

void main() {
  group('MilkHistoryScreen Widget Tests (R1 & R2)', () {
    testWidgets('Renders "Pre-Account Period" empty state when selected month is before inception', (tester) async {
      final inceptionDate = DateTime(2026, 8, 1);
      final fakeRepo = FakeMilkHistoryRepository(
        earliestActivityDate: inceptionDate,
        overviewToReturn: MilkHistoryOverview(
          totalQuantity: 0,
          avgQuantityPerDay: 0,
          grossRevenue: 0,
          avgRevenuePerKg: 0,
          earliestActivityDate: inceptionDate,
          isPreAccount: true,
          logs: const [],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MilkHistoryScreen(
            farmName: 'Test Farm',
            userId: 101,
            initialMonth: DateTime(2026, 5),
            repository: fakeRepo,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Pre-Account Period'), findsOneWidget);
      expect(find.byIcon(Icons.history_toggle_off), findsOneWidget);
      expect(find.text('No Milk Recorded'), findsNothing);
    });

    testWidgets('Renders "No Milk Recorded" empty state when selected month is after inception with zero yield', (tester) async {
      final inceptionDate = DateTime(2025, 1, 1);
      final fakeRepo = FakeMilkHistoryRepository(
        earliestActivityDate: inceptionDate,
        overviewToReturn: MilkHistoryOverview(
          totalQuantity: 0,
          avgQuantityPerDay: 0,
          grossRevenue: 0,
          avgRevenuePerKg: 0,
          earliestActivityDate: inceptionDate,
          isPreAccount: false,
          logs: const [],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MilkHistoryScreen(
            farmName: 'Test Farm',
            userId: 101,
            repository: fakeRepo,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No Milk Recorded'), findsOneWidget);
      expect(find.byIcon(Icons.water_drop_outlined), findsOneWidget);
      expect(find.text('Pre-Account Period'), findsNothing);
    });

    testWidgets('Month picker bottom sheet is clamped to exactly 12 calendar months (R1)', (tester) async {
      final fakeRepo = FakeMilkHistoryRepository(
        earliestActivityDate: DateTime(2025, 1, 1),
        overviewToReturn: MilkHistoryOverview.empty(earliestActivityDate: DateTime(2025, 1, 1)),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MilkHistoryScreen(
            farmName: 'Test Farm',
            userId: 101,
            repository: fakeRepo,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap calendar month picker icon in header
      final calendarButton = find.byIcon(Icons.calendar_today_outlined);
      expect(calendarButton, findsOneWidget);
      await tester.tap(calendarButton);
      await tester.pumpAndSettle();

      // Find the ListView in the bottom sheet
      final listView = find.byType(ListView);
      expect(listView, findsOneWidget);

      // Verify there are 12 items (clamped to last 12 calendar months)
      final listWidget = tester.widget<ListView>(listView);
      final delegate = listWidget.childrenDelegate as SliverChildBuilderDelegate;
      expect(delegate.childCount, equals(12));
    });

    testWidgets('Renders dispatch logs and session filter chips correctly', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final logs = [
        MilkHistoryLog(
          buyerName: 'Buyer Alpha',
          date: DateTime(2026, 10, 5),
          totalCollected: 25.0,
          rate: 60.0,
          morningQty: 25.0,
          eveningQty: 0.0,
        ),
        MilkHistoryLog(
          buyerName: 'Buyer Beta',
          date: DateTime(2026, 10, 5),
          totalCollected: 15.0,
          rate: 55.0,
          morningQty: 0.0,
          eveningQty: 15.0,
        ),
      ];

      final fakeRepo = FakeMilkHistoryRepository(
        earliestActivityDate: DateTime(2026, 1, 1),
        overviewToReturn: MilkHistoryOverview(
          totalQuantity: 40.0,
          avgQuantityPerDay: 1.3,
          grossRevenue: 2325.0,
          avgRevenuePerKg: 58.1,
          earliestActivityDate: DateTime(2026, 1, 1),
          isPreAccount: false,
          logs: logs,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MilkHistoryScreen(
            farmName: 'Alpine Meadows',
            userId: 101,
            repository: fakeRepo,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Both logs visible initially under 'All Loads'
      expect(find.text('Buyer Alpha'), findsOneWidget);
      expect(find.text('Buyer Beta'), findsOneWidget);

      // Filter by 'Morning Only'
      await tester.tap(find.text('Morning Only'));
      await tester.pumpAndSettle();
      expect(find.text('Buyer Alpha'), findsOneWidget);
      expect(find.text('Buyer Beta'), findsNothing);

      // Filter by 'Evening Only'
      await tester.tap(find.text('Evening Only'));
      await tester.pumpAndSettle();
      expect(find.text('Buyer Alpha'), findsNothing);
      expect(find.text('Buyer Beta'), findsOneWidget);
    });
  });
}
