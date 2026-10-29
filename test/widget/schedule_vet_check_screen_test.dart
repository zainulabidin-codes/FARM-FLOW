import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:dairy_farm_app/core/database/database_helper.dart';
import 'package:dairy_farm_app/features/auth/data/models/user_model.dart';
import 'package:dairy_farm_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:dairy_farm_app/features/cows/data/models/cow_model.dart';
import 'package:dairy_farm_app/features/cows/presentation/providers/cow_provider.dart';
import 'package:dairy_farm_app/features/dashboard/data/datasources/vet_check_local_datasource.dart';
import 'package:dairy_farm_app/features/dashboard/data/models/activity_log_model.dart';
import 'package:dairy_farm_app/features/dashboard/data/models/vet_check_models.dart';
import 'package:dairy_farm_app/features/dashboard/data/repositories/vet_check_repository.dart';
import 'package:dairy_farm_app/features/dashboard/presentation/pages/schedule_vet_check_screen.dart';
import 'package:dairy_farm_app/features/dashboard/presentation/providers/activity_log_provider.dart';
import 'package:dairy_farm_app/features/dashboard/presentation/providers/vet_check_provider.dart';

class MockAuthProvider extends ChangeNotifier implements AuthProvider {
  final UserModel? _user;
  MockAuthProvider(this._user);

  @override
  UserModel? get currentUser => _user;

  @override
  AuthStatus get status => AuthStatus.success;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockCowProvider extends ChangeNotifier implements CowProvider {
  final List<CowModel> _cows;
  MockCowProvider(this._cows);

  @override
  List<CowModel> get cows => _cows;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockActivityLogProvider extends ChangeNotifier implements ActivityLogProvider {
  final List<ActivityLogModel> _activities = [];

  @override
  List<ActivityLogModel> get activities => _activities;

  @override
  Future<void> logVetAppointmentScheduled({
    required int userId,
    required String cowTag,
    required String doctorName,
    required String scheduledDate,
    required String scheduledTime,
  }) async {
    _activities.insert(
      0,
      ActivityLogModel(
        userId: userId,
        title: 'Vet Check Scheduled',
        subtitle: 'Cow #$cowTag with $doctorName',
        value: '$scheduledDate at $scheduledTime',
        timeUnix: DateTime.now().millisecondsSinceEpoch,
        iconCode: 0,
        isPositive: 1,
      ),
    );
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('ScheduleVetCheckScreen Widget Tests', () {
    late Database db;
    late AuthProvider authProvider;
    late CowProvider cowProvider;
    late MockActivityLogProvider activityProvider;
    late VetCheckProvider vetProvider;
    const userId = 777;

    setUp(() async {
      db = await DatabaseHelper.createInMemoryDatabase();

      await db.insert('users', {
        'id': userId,
        'username': 'john_doe',
        'password_hash': 'pw',
        'farm_name': 'Sunny Farm',
      });

      await db.insert('cows', {
        'id': 10,
        'user_id': userId,
        'tag_number': 'COW-010',
        'name': 'Bella',
        'status': 'MILKING',
        'is_deleted': 0,
      });

      await db.insert('cows', {
        'id': 11,
        'user_id': userId,
        'tag_number': 'COW-011',
        'name': 'Luna',
        'status': 'PREGNANT',
        'is_deleted': 0,
      });

      authProvider = MockAuthProvider(
        const UserModel(
          id: userId,
          username: 'john_doe',
          farmName: 'Sunny Farm',
          passwordHash: 'dummy',
        ),
      );

      cowProvider = MockCowProvider([
        const CowModel(id: 10, userId: userId, tagNumber: 'COW-010', name: 'Bella', status: 'MILKING'),
        const CowModel(id: 11, userId: userId, tagNumber: 'COW-011', name: 'Luna', status: 'PREGNANT'),
      ]);

      activityProvider = MockActivityLogProvider();

      final vetDatasource = VetCheckLocalDatasource(db: db);
      final vetRepo = VetCheckRepository(datasource: vetDatasource);
      vetProvider = VetCheckProvider(repository: vetRepo);
      vetProvider.setActivityProvider(activityProvider);
      await vetProvider.loadAll(userId);
    });

    tearDown(() async {
      await db.close();
    });

    Widget createWidgetUnderTest({String? cowName, String? cowTag}) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<CowProvider>.value(value: cowProvider),
          ChangeNotifierProvider<ActivityLogProvider>.value(value: activityProvider),
          ChangeNotifierProvider<VetCheckProvider>.value(value: vetProvider),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const Key('open_vet_screen_btn'),
                  onPressed: () {
                    Navigator.of(ctx).push(
                      MaterialPageRoute(
                        builder: (_) => ScheduleVetCheckScreen(
                          userId: userId,
                          cowId: 10,
                          cowName: cowName ?? 'Bella',
                          cowTag: cowTag ?? 'COW-010',
                          shed: 'A',
                        ),
                      ),
                    );
                  },
                  child: const Text('Open Vet Screen'),
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('Renders all primary UI components properly', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_vet_screen_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Schedule Vet Check'), findsOneWidget);
      expect(find.byKey(const Key('vet_patient_card')), findsOneWidget);
      expect(find.text('Bella'), findsOneWidget);
      expect(find.text('Milking Tag #COW-010 • Shed A'), findsOneWidget);

      expect(find.text('Select Vet Doctor'), findsOneWidget);
      expect(find.text('No Vet Doctors Added'), findsOneWidget);
      expect(find.byKey(const Key('vet_empty_add_doctor_button')), findsOneWidget);
      expect(find.text('Reason for Appointment'), findsOneWidget);
      expect(find.text('Routine Health Check'), findsOneWidget);
      expect(find.byKey(const Key('vet_confirm_schedule_button')), findsOneWidget);
    });

    testWidgets('Tapping reason tag toggles selection', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_vet_screen_btn')));
      await tester.pumpAndSettle();

      final reasonTagFinder = find.byKey(const Key('vet_reason_tag_Vaccination'));
      expect(reasonTagFinder, findsOneWidget);

      await tester.tap(reasonTagFinder);
      await tester.pumpAndSettle();

      // Tap again to toggle off
      await tester.tap(reasonTagFinder);
      await tester.pumpAndSettle();
    });

    testWidgets('Tapping Change button opens bottom sheet and changes selected cow', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_vet_screen_btn')));
      await tester.pumpAndSettle();

      final changeBtn = find.byKey(const Key('vet_change_cow_button'));
      expect(changeBtn, findsOneWidget);

      await tester.tap(changeBtn);
      await tester.pumpAndSettle();

      expect(find.text('Select Cow for Vet Check'), findsOneWidget);
      expect(find.text('Luna'), findsOneWidget);

      // Select Luna
      await tester.tap(find.text('Luna'));
      await tester.pumpAndSettle();

      // Bottom sheet should be closed and Luna should be active patient
      expect(find.text('Luna'), findsOneWidget);
      expect(find.text('Milking Tag #COW-011 • Shed A'), findsOneWidget);
    });

    testWidgets('Tapping Add New doctor opens dialog and adds doctor', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_vet_screen_btn')));
      await tester.pumpAndSettle();

      final addDocBtn = find.byKey(const Key('vet_empty_add_doctor_button'));
      await tester.tap(addDocBtn);
      await tester.pumpAndSettle();

      expect(find.text('Add Vet Doctor'), findsOneWidget);
      expect(find.byKey(const Key('pick_doctor_from_contacts_button')), findsOneWidget);

      // Enter details
      await tester.enterText(find.widgetWithText(TextField, 'Doctor Name *'), 'Dr. Robert King');
      await tester.enterText(find.widgetWithText(TextField, 'Phone Number *'), '+92 333 9988776');

      await tester.tap(find.text('Add Doctor'));
      await tester.pumpAndSettle();

      expect(find.text('Dr. Robert King'), findsOneWidget);
    });

    testWidgets('Confirm & Schedule successfully saves appointment and logs activity', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Add a doctor to provider first
      await tester.runAsync(() async {
        await vetProvider.addDoctor(
          VetDoctor(
            userId: userId,
            name: 'Dr. Sarah Jenkins',
            qualification: 'Livestock Specialist',
            phone: '+92 300 1234567',
            isPrimary: true,
          ),
        );
      });

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_vet_screen_btn')));
      await tester.pumpAndSettle();

      // Select doctor
      final doctorId = vetProvider.doctors.first.id!;
      await tester.tap(find.byKey(Key('vet_doctor_card_$doctorId')));
      await tester.pumpAndSettle();

      // Select Vaccination reason
      await tester.tap(find.byKey(const Key('vet_reason_tag_Vaccination')));
      await tester.pumpAndSettle();

      // Enter notes
      await tester.enterText(find.byKey(const Key('vet_manual_reason_input')), 'Annual booster dose');
      await tester.pumpAndSettle();

      // Tap confirm button
      final confirmBtn = find.byKey(const Key('vet_confirm_schedule_button'));
      await tester.ensureVisible(confirmBtn);
      await tester.tap(confirmBtn);
      await tester.pump();

      // Yield event loop between root isolate and SQLite background isolate
      int retries = 0;
      while (vetProvider.upcomingAppointment == null && retries < 20) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
        await tester.pump();
        retries++;
      }

      // Provider should now have an upcoming appointment
      expect(vetProvider.upcomingAppointment, isNotNull);
      expect(vetProvider.upcomingAppointment!.reasons, contains('Vaccination'));

      // Activity log should have recorded it
      expect(activityProvider.activities.any((a) => a.title == 'Vet Check Scheduled'), isTrue);
    });

    testWidgets('Long-pressing doctor card shows Delete Doctor dialog and permanently deletes doctor on confirmation', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Add a doctor
      late VetDoctor addedDoctor;
      await tester.runAsync(() async {
        final doc = await vetProvider.addDoctor(
          const VetDoctor(
            userId: userId,
            name: 'Dr. Emily Torres',
            qualification: 'Animal Health',
            phone: '+92 300 9876543',
            isPrimary: true,
          ),
        );
        addedDoctor = doc!;
      });

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_vet_screen_btn')));
      await tester.pumpAndSettle();

      final doctorCardFinder = find.byKey(Key('vet_doctor_card_${addedDoctor.id}'));
      expect(doctorCardFinder, findsOneWidget);

      // Long press doctor card
      await tester.longPress(doctorCardFinder);
      await tester.pumpAndSettle();

      // Verify dialog appears
      expect(find.text('Delete Doctor?'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining('Dr. Emily Torres'),
        ),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.byKey(const Key('confirm_delete_doctor_btn')), findsOneWidget);

      // Tap Delete in dialog
      await tester.tap(find.byKey(const Key('confirm_delete_doctor_btn')));
      await tester.pump();

      // Yield event loop
      int retries = 0;
      while (vetProvider.doctors.isNotEmpty && retries < 20) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
        await tester.pump();
        retries++;
      }

      await tester.pumpAndSettle();

      // Doctor should be permanently deleted, empty state shown
      expect(find.text('Dr. Emily Torres'), findsNothing);
      expect(find.text('No Vet Doctors Added'), findsOneWidget);
      expect(find.byKey(const Key('vet_empty_add_doctor_button')), findsOneWidget);
    });
  });
}
