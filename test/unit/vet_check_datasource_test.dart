import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:dairy_farm_app/core/database/database_helper.dart';
import 'package:dairy_farm_app/features/dashboard/data/datasources/vet_check_local_datasource.dart';
import 'package:dairy_farm_app/features/dashboard/data/models/vet_check_models.dart';
import 'package:dairy_farm_app/features/dashboard/data/repositories/vet_check_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('VetCheckLocalDatasource & Repository Integration Tests', () {
    late Database db;
    late VetCheckLocalDatasource datasource;
    late VetCheckRepository repository;
    const userId = 101;

    setUp(() async {
      db = await DatabaseHelper.createInMemoryDatabase();
      datasource = VetCheckLocalDatasource(db: db);
      repository = VetCheckRepository(datasource: datasource);

      // Seed a user and a cow
      await db.insert('users', {
        'id': userId,
        'username': 'farmer_dan',
        'password_hash': 'hashed_pw',
        'farm_name': 'Green Pastures',
      });

      await db.insert('cows', {
        'id': 1,
        'user_id': userId,
        'tag_number': 'COW-101',
        'name': 'Bella',
        'status': 'MILKING',
      });
    });

    tearDown(() async {
      await db.close();
    });

    test('getDoctors returns empty list when no doctors have been added', () async {
      final doctors = await repository.getDoctors(userId);
      expect(doctors, isEmpty);
    });

    test('addDoctor inserts new doctor and updates primary flag properly', () async {
      final doc1 = VetDoctor(
        userId: userId,
        name: 'Dr. John Watson',
        qualification: 'DVM',
        phone: '+92 311 0000000',
        isPrimary: false,
      );

      final doc1Id = await repository.addDoctor(doc1);
      expect(doc1Id, isPositive);

      final doc2 = VetDoctor(
        userId: userId,
        name: 'Dr. Sherlock',
        qualification: 'Surgeon',
        phone: '+92 322 0000000',
        isPrimary: true,
      );

      final doc2Id = await repository.addDoctor(doc2);
      expect(doc2Id, isPositive);

      final allDocs = await repository.getDoctors(userId);
      final primaryDocs = allDocs.where((d) => d.isPrimary).toList();
      expect(primaryDocs.length, 1);
      expect(primaryDocs.first.id, doc2Id);
      expect(primaryDocs.first.name, 'Dr. Sherlock');
    });

    test('scheduleAppointment stores and retrieves upcoming appointment with joins', () async {
      final docId = await repository.addDoctor(
        VetDoctor(
          userId: userId,
          name: 'Dr. Sarah Jenkins',
          qualification: 'Livestock Specialist',
          phone: '+92 300 1234567',
          isPrimary: true,
        ),
      );
      final doctor = (await repository.getDoctors(userId)).first;

      final appointment = VetAppointment(
        userId: userId,
        cowId: 1,
        doctorId: docId,
        scheduledDate: '2026-11-05',
        scheduledTime: '11:00 AM',
        reasons: ['Routine Health Check', 'Deworming'],
        customNotes: 'Check left hind hoof',
        feedbackNotes: 'Mild inflammation observed',
        hasFollowUp: true,
        followUpDate: '2026-11-12',
        status: 'SCHEDULED',
      );

      final appointmentId = await repository.scheduleAppointment(appointment);
      expect(appointmentId, isPositive);

      final upcoming = await repository.getUpcomingAppointment(userId);
      expect(upcoming, isNotNull);
      expect(upcoming!.id, appointmentId);
      expect(upcoming.cowTag, 'COW-101');
      expect(upcoming.cowName, 'Bella');
      expect(upcoming.doctorName, doctor.name);
      expect(upcoming.doctorPhone, doctor.phone);
      expect(upcoming.scheduledDate, '2026-11-05');
      expect(upcoming.reasons, contains('Routine Health Check'));
      expect(upcoming.hasFollowUp, isTrue);
    });

    test('updateAppointmentStatus changes appointment status and excludes from upcoming if completed', () async {
      final docId = await repository.addDoctor(
        VetDoctor(
          userId: userId,
          name: 'Dr. Sarah Jenkins',
          qualification: 'Livestock Specialist',
          phone: '+92 300 1234567',
          isPrimary: true,
        ),
      );

      final appointmentId = await repository.scheduleAppointment(
        VetAppointment(
          userId: userId,
          cowId: 1,
          doctorId: docId,
          scheduledDate: '2026-11-01',
          scheduledTime: '10:00 AM',
          reasons: ['Mastitis Screen'],
        ),
      );

      var upcoming = await repository.getUpcomingAppointment(userId);
      expect(upcoming, isNotNull);
      expect(upcoming!.id, appointmentId);

      await repository.updateAppointmentStatus(appointmentId, 'COMPLETED');

      upcoming = await repository.getUpcomingAppointment(userId);
      expect(upcoming, isNull);

      final history = await repository.getAppointments(userId);
      expect(history.length, 1);
      expect(history.first.status, 'COMPLETED');
    });

    test('deleteDoctor permanently removes doctor from SQLite database', () async {
      final docId = await repository.addDoctor(
        VetDoctor(
          userId: userId,
          name: 'Dr. John Watson',
          qualification: 'DVM',
          phone: '+92 311 0000000',
        ),
      );

      var doctors = await repository.getDoctors(userId);
      expect(doctors.length, 1);

      final deletedRows = await repository.deleteDoctor(docId, userId);
      expect(deletedRows, 1);

      doctors = await repository.getDoctors(userId);
      expect(doctors, isEmpty);
    });
  });
}

