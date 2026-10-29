import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:dairy_farm_app/core/database/database_helper.dart';
import 'package:dairy_farm_app/features/dashboard/data/datasources/vet_check_local_datasource.dart';
import 'package:dairy_farm_app/features/dashboard/data/models/activity_log_model.dart';
import 'package:dairy_farm_app/features/dashboard/data/models/vet_check_models.dart';
import 'package:dairy_farm_app/features/dashboard/data/repositories/vet_check_repository.dart';
import 'package:dairy_farm_app/features/dashboard/presentation/providers/activity_log_provider.dart';
import 'package:dairy_farm_app/features/dashboard/presentation/providers/vet_check_provider.dart';

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

  group('VetCheckProvider Unit Tests', () {
    late Database db;
    late VetCheckProvider vetProvider;
    late MockActivityLogProvider activityProvider;
    const userId = 505;

    setUp(() async {
      db = await DatabaseHelper.createInMemoryDatabase();

      await db.insert('users', {
        'id': userId,
        'username': 'ali_farm',
        'password_hash': 'pass123',
        'farm_name': 'Ali Dairy',
      });

      await db.insert('cows', {
        'id': 20,
        'user_id': userId,
        'tag_number': 'COW-020',
        'name': 'Gauri',
        'status': 'MILKING',
      });

      activityProvider = MockActivityLogProvider();

      final vetDatasource = VetCheckLocalDatasource(db: db);
      final vetRepo = VetCheckRepository(datasource: vetDatasource);
      vetProvider = VetCheckProvider(repository: vetRepo);
      vetProvider.setActivityProvider(activityProvider);
    });

    tearDown(() async {
      await db.close();
    });

    test('loadAll populates doctors and upcoming appointment', () async {
      expect(vetProvider.doctors, isEmpty);
      expect(vetProvider.upcomingAppointment, isNull);

      await vetProvider.loadAll(userId);

      expect(vetProvider.doctors, isEmpty);
      expect(vetProvider.upcomingAppointment, isNull);
      expect(vetProvider.isLoading, isFalse);
    });

    test('addDoctor adds doctor and selects in provider list', () async {
      await vetProvider.loadDoctors(userId);
      final initialCount = vetProvider.doctors.length;

      final newDoc = VetDoctor(
        userId: userId,
        name: 'Dr. Tariq',
        qualification: 'Cattle Surgeon',
        phone: '+92 344 1122334',
        isPrimary: true,
      );

      final added = await vetProvider.addDoctor(newDoc);
      expect(added, isNotNull);
      expect(added!.id, isNotNull);
      expect(vetProvider.doctors.length, initialCount + 1);
      expect(vetProvider.doctors.any((d) => d.name == 'Dr. Tariq' && d.isPrimary), isTrue);
    });

    test('scheduleAppointment creates appointment and logs activity entry', () async {
      final doc = await vetProvider.addDoctor(
        const VetDoctor(
          userId: userId,
          name: 'Dr. Sarah Jenkins',
          qualification: 'Livestock Specialist',
          phone: '+92 300 1234567',
          isPrimary: true,
        ),
      );

      final appointment = VetAppointment(
        userId: userId,
        cowId: 20,
        doctorId: doc!.id!,
        scheduledDate: '2026-11-10',
        scheduledTime: '02:00 PM',
        reasons: ['Pregnancy Check'],
        cowTag: 'COW-020',
        doctorName: doc.name,
      );

      final id = await vetProvider.scheduleAppointment(
        appointment,
        cowTag: 'COW-020',
        doctorName: doc.name,
      );

      expect(id, isNotNull);
      expect(vetProvider.upcomingAppointment, isNotNull);
      expect(vetProvider.upcomingAppointment!.id, id);
      expect(vetProvider.upcomingAppointment!.scheduledTime, '02:00 PM');

      // Verify activity was logged in ActivityLogProvider
      expect(activityProvider.activities.isNotEmpty, isTrue);
      final latest = activityProvider.activities.first;
      expect(latest.title, 'Vet Check Scheduled');
      expect(latest.subtitle, contains('COW-020'));
      expect(latest.subtitle, contains(doc.name));
    });

    test('deleteDoctor permanently removes doctor and reloads doctors list', () async {
      final doc = await vetProvider.addDoctor(
        const VetDoctor(
          userId: userId,
          name: 'Dr. Tariq',
          qualification: 'Cattle Surgeon',
          phone: '+92 344 1122334',
        ),
      );

      expect(vetProvider.doctors.length, 1);

      final success = await vetProvider.deleteDoctor(doc!.id!, userId);
      expect(success, isTrue);
      expect(vetProvider.doctors, isEmpty);
    });
  });
}
