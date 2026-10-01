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
    const DodiModel(id: 1, userId: 1, name: 'Ramesh Milk', phone: '9876543210', defaultRatePaise: 6000, isDeleted: 0),
    const DodiModel(id: 2, userId: 1, name: 'Suresh Dairy', phone: '9123456789', defaultRatePaise: 6500, isDeleted: 0),
  ];

  List<DodiModel> deletedDodis = [
    const DodiModel(id: 3, userId: 1, name: 'Binned Buyer Corp', phone: '9998887770', defaultRatePaise: 5500, isDeleted: 1),
  ];
}

class FakeDodiProvider extends DodiProvider {
  final FakeDodiRepository repo = FakeDodiRepository();

  @override
  List<DodiModel> get dodis => repo.dodis;

  @override
  List<DodiModel> get deletedDodis => repo.deletedDodis;

  @override
  Future<void> loadDodis(int userId) async {
    notifyListeners();
  }

  @override
  Future<void> loadDeletedDodis(int userId) async {
    notifyListeners();
  }

  @override
  Future<bool> restoreDodi(int dodiId, int userId) async {
    final found = repo.deletedDodis.where((d) => d.id == dodiId).firstOrNull;
    if (found != null) {
      repo.deletedDodis.removeWhere((d) => d.id == dodiId);
      repo.dodis.add(found.copyWith(isDeleted: 0));
      notifyListeners();
      return true;
    }
    return false;
  }
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

void main() {
  testWidgets('Select Milk Buyer renders search bar, chips, and buyers', (WidgetTester tester) async {
    final dodiProvider = FakeDodiProvider();
    final authProvider = FakeAuthProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<DodiProvider>.value(value: dodiProvider),
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: MilkEntryScreen(
            onSaveEntry: (
              int dodiId,
              String buyerName,
              String quantity,
              String session,
              int ratePaise,
              String date,
              String loadTag,
            ) {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify search bar and chips are present
    expect(find.byType(TextField), findsOneWidget);
    expect(find.textContaining('All (3)'), findsOneWidget);
    expect(find.textContaining('Active (2)'), findsOneWidget);
    expect(find.textContaining('Binned (1)'), findsOneWidget);
    expect(find.text('+ Register & Add New Buyer'), findsOneWidget);

    // Verify active buyer names
    expect(find.text('Ramesh Milk'), findsOneWidget);
    expect(find.text('Suresh Dairy'), findsOneWidget);

    // Test Search input filtering
    await tester.enterText(find.byType(TextField), 'Suresh');
    await tester.pumpAndSettle();

    expect(find.text('Suresh Dairy'), findsOneWidget);
    expect(find.text('Ramesh Milk'), findsNothing);

    // Clear search
    await tester.tap(find.byIcon(Icons.close_rounded).first);
    await tester.pumpAndSettle();

    expect(find.text('Ramesh Milk'), findsOneWidget);

    // Filter by Binned tab
    await tester.tap(find.textContaining('Binned (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Binned Buyer Corp'), findsOneWidget);
    expect(find.text('Ramesh Milk'), findsNothing);

    // Tap binned buyer to trigger restore dialog
    await tester.tap(find.text('Binned Buyer Corp'));
    await tester.pumpAndSettle();

    expect(find.text('Restore Buyer?'), findsOneWidget);

    // Tap Restore & Select
    await tester.tap(find.text('Restore & Select'));
    await tester.pumpAndSettle();

    // Verify buyer is now restored and selected
    expect(find.byType(MilkEntryScreen), findsOneWidget);
  });
}
