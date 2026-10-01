import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:dairy_farm_app/features/dashboard/domain/connectors/milk_card_actions_connector.dart';
import 'package:dairy_farm_app/features/dashboard/presentation/pages/dashboard_screen.dart';

// Fake connector implementation for Success state
class FakeSuccessMilkCardActionsConnector implements MilkCardActionsConnector {
  @override
  Future<MilkActionConnectorResult> executeAction(
    MilkCardActionType action, {
    Map<String, dynamic>? params,
  }) async {
    return const MilkActionSuccess(message: 'Action completed successfully');
  }
}

// Fake connector implementation for Failure state
class FakeFailureMilkCardActionsConnector implements MilkCardActionsConnector {
  @override
  Future<MilkActionConnectorResult> executeAction(
    MilkCardActionType action, {
    Map<String, dynamic>? params,
  }) async {
    return const MilkActionFailure('Failed to execute connector action');
  }
}

// Fake connector implementation for NotConnected state
class FakeNotConnectedMilkCardActionsConnector implements MilkCardActionsConnector {
  @override
  Future<MilkActionConnectorResult> executeAction(
    MilkCardActionType action, {
    Map<String, dynamic>? params,
  }) async {
    return const MilkActionNotConnected();
  }
}

void main() {
  Widget buildHarness(MilkCardActionsConnector connector, ValueChanged<MilkCardActionType> onAction) {
    return MaterialApp(
      home: Provider<MilkCardActionsConnector>.value(
        value: connector,
        child: Scaffold(
          body: DashboardScreen(
            farmName: 'Test Farm',
            totalMilk: '100.0',
            morningMilk: '50.0',
            eveningMilk: '50.0',
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
            onMilkCardAction: onAction,
          ),
        ),
      ),
    );
  }

  group('Phase 2 — MilkCardActionsConnector Widget Tests', () {
    testWidgets('Connector handles MilkActionNotConnected result', (tester) async {
      MilkActionConnectorResult? capturedResult;
      final connector = FakeNotConnectedMilkCardActionsConnector();

      await tester.pumpWidget(
        buildHarness(connector, (action) async {
          capturedResult = await connector.executeAction(action);
        }),
      );

      // Tap 3-dots menu icon
      final iconFinder = find.byIcon(Icons.more_vert_rounded);
      expect(iconFinder, findsOneWidget);
      await tester.tap(iconFinder);
      await tester.pumpAndSettle();

      // Tap 'View Milk History'
      final menuItemFinder = find.text('View Milk History');
      expect(menuItemFinder, findsOneWidget);
      await tester.tap(menuItemFinder);
      await tester.pumpAndSettle();

      expect(capturedResult, isA<MilkActionNotConnected>());
    });

    testWidgets('Connector handles MilkActionSuccess result', (tester) async {
      MilkActionConnectorResult? capturedResult;
      final connector = FakeSuccessMilkCardActionsConnector();

      await tester.pumpWidget(
        buildHarness(connector, (action) async {
          capturedResult = await connector.executeAction(action);
        }),
      );

      final iconFinder = find.byIcon(Icons.more_vert_rounded);
      await tester.tap(iconFinder);
      await tester.pumpAndSettle();

      final menuItemFinder = find.text('Export Daily Summary');
      expect(menuItemFinder, findsOneWidget);
      await tester.tap(menuItemFinder);
      await tester.pumpAndSettle();

      expect(capturedResult, isA<MilkActionSuccess>());
      expect((capturedResult as MilkActionSuccess).message, equals('Action completed successfully'));
    });

    testWidgets('Connector handles MilkActionFailure result', (tester) async {
      MilkActionConnectorResult? capturedResult;
      final connector = FakeFailureMilkCardActionsConnector();

      await tester.pumpWidget(
        buildHarness(connector, (action) async {
          capturedResult = await connector.executeAction(action);
        }),
      );

      final iconFinder = find.byIcon(Icons.more_vert_rounded);
      await tester.tap(iconFinder);
      await tester.pumpAndSettle();

      final menuItemFinder = find.text('View Milk History');
      await tester.tap(menuItemFinder);
      await tester.pumpAndSettle();

      expect(capturedResult, isA<MilkActionFailure>());
      expect((capturedResult as MilkActionFailure).errorMessage, equals('Failed to execute connector action'));
    });
  });
}
