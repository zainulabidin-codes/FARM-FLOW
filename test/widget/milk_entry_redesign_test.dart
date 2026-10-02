import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:dairy_farm_app/core/theme/app_theme.dart';
import 'package:dairy_farm_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:dairy_farm_app/features/auth/data/models/user_model.dart';
import 'package:dairy_farm_app/features/dodi_ledger/presentation/providers/dodi_provider.dart';
import 'package:dairy_farm_app/features/dodi_ledger/data/models/dodi_model.dart';
import 'package:dairy_farm_app/features/milk_entry/presentation/pages/milk_entry_screen.dart';

class FakeDodiRepository {
  List<DodiModel> dodis = [
    const DodiModel(
      id: 1,
      userId: 1,
      name: 'Chaudhary Raghvendra Pratap Singh Dairy Farm',
      phone: '9876543210',
      defaultRatePaise: 6000,
      isDeleted: 0,
    ),
  ];

  List<DodiModel> deletedDodis = [];
}

class FakeDodiProvider extends DodiProvider {
  final FakeDodiRepository repo = FakeDodiRepository();

  @override
  List<DodiModel> get dodis => repo.dodis;

  @override
  List<DodiModel> get deletedDodis => repo.deletedDodis;

  @override
  Future<void> loadDodis(int userId) async {}

  @override
  Future<void> loadDeletedDodis(int userId) async {}
}

class FakeAuthProvider extends AuthProvider {
  @override
  UserModel? get currentUser => const UserModel(
        id: 1,
        username: 'testuser',
        passwordHash: 'dummyhash',
        farmerName: 'Test Farmer',
      );
}

Widget buildTestWidget({
  required DodiProvider dodiProvider,
  required AuthProvider authProvider,
  int? initialDodiId = 1,
  double textScale = 1.0,
  Size screenSize = const Size(390, 844),
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<DodiProvider>.value(value: dodiProvider),
      ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(
          size: screenSize,
          textScaler: TextScaler.linear(textScale),
        ),
        child: MilkEntryScreen(
          initialDodiId: initialDodiId,
          onSaveEntry: (p1, p2, p3, p4, p5, p6, p7) {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('Milk Entry Redesign — Render, Keypad input, State preservation across session toggle & date pick', (WidgetTester tester) async {
    final dodiProvider = FakeDodiProvider();
    final authProvider = FakeAuthProvider();

    await tester.pumpWidget(
      buildTestWidget(
        dodiProvider: dodiProvider,
        authProvider: authProvider,
      ),
    );
    await tester.pumpAndSettle();

    // Verify visual components render
    expect(find.text('WEIGHT METRIC'), findsOneWidget);
    expect(find.text('KG'), findsOneWidget);
    expect(find.text('Touchpad entry ready'), findsOneWidget);
    expect(find.text('RATE (RS/KG) *'), findsOneWidget);
    expect(find.text('LOAD TAG *'), findsOneWidget);
    expect(find.text('Morning'), findsOneWidget);
    expect(find.text('Evening'), findsOneWidget);
    expect(find.text('Save Entry'), findsOneWidget);

    // Enter digits 2 and 5 on numpad
    await tester.tap(find.text('2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5'));
    await tester.pumpAndSettle();

    expect(find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().contains('25')), findsOneWidget);

    // Toggle shift from Morning to Evening
    await tester.tap(find.text('Evening'));
    await tester.pumpAndSettle();

    // Verify entered weight value (25) is preserved after session toggle!
    expect(find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().contains('25')), findsOneWidget);

    // Tap Date Badge Pill to trigger date picker
    await tester.tap(find.byIcon(Icons.calendar_today_rounded));
    await tester.pumpAndSettle();

    // Tap OK on date picker if visible
    final okFinder = find.text('OK');
    if (okFinder.evaluate().isNotEmpty) {
      await tester.tap(okFinder);
      await tester.pumpAndSettle();
    }

    // Verify entered weight value (25) is preserved after date pick!
    expect(find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().contains('25')), findsOneWidget);
  });

  testWidgets('Milk Entry Redesign — Long buyer name truncation test', (WidgetTester tester) async {
    final dodiProvider = FakeDodiProvider();
    final authProvider = FakeAuthProvider();

    await tester.pumpWidget(
      buildTestWidget(
        dodiProvider: dodiProvider,
        authProvider: authProvider,
      ),
    );
    await tester.pumpAndSettle();

    // Verify long buyer name is rendered inside app bar without overflow
    expect(find.text('Chaudhary Raghvendra Pratap Singh Dairy Farm'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Milk Entry Redesign — 320px narrow screen at 2.0x text scale layout test', (WidgetTester tester) async {
    final dodiProvider = FakeDodiProvider();
    final authProvider = FakeAuthProvider();

    await tester.pumpWidget(
      buildTestWidget(
        dodiProvider: dodiProvider,
        authProvider: authProvider,
        textScale: 2.0,
        screenSize: const Size(320, 568),
      ),
    );
    await tester.pumpAndSettle();

    // Verify zero render overflow errors under extreme scale on 320px
    expect(tester.takeException(), isNull);
  });

  testWidgets('Milk Entry Redesign — Max digits (99999.9) FittedBox scale test', (WidgetTester tester) async {
    final dodiProvider = FakeDodiProvider();
    final authProvider = FakeAuthProvider();

    await tester.pumpWidget(
      buildTestWidget(
        dodiProvider: dodiProvider,
        authProvider: authProvider,
      ),
    );
    await tester.pumpAndSettle();

    // Enter 99999.9
    for (int i = 0; i < 5; i++) {
      await tester.tap(find.text('9'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('·'), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('9'));
    await tester.pumpAndSettle();

    expect(find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().contains('99999')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
