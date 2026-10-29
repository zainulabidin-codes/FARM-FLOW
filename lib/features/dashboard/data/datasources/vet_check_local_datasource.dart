import 'package:sqflite/sqflite.dart';
import '../../../../core/database/database_helper.dart';
import '../models/vet_check_models.dart';

class VetCheckLocalDatasource {
  final Database? db;

  VetCheckLocalDatasource({this.db});

  Future<Database> get _database async => db ?? await DatabaseHelper.instance.database;

  Future<List<VetDoctor>> getDoctors(int userId) async {
    final database = await _database;
    final maps = await database.query(
      'vet_doctors',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'is_primary DESC, name ASC',
    );

    return maps.map((m) => VetDoctor.fromMap(m)).toList();
  }

  Future<int> addDoctor(VetDoctor doctor) async {
    final database = await _database;
    if (doctor.isPrimary) {
      await database.update(
        'vet_doctors',
        {'is_primary': 0},
        where: 'user_id = ?',
        whereArgs: [doctor.userId],
      );
    }
    return await database.insert('vet_doctors', doctor.toMap());
  }

  Future<int> deleteDoctor(int doctorId, int userId) async {
    final database = await _database;
    return await database.delete(
      'vet_doctors',
      where: 'id = ? AND user_id = ?',
      whereArgs: [doctorId, userId],
    );
  }

  Future<int> scheduleAppointment(VetAppointment appointment) async {
    final database = await _database;
    return await database.insert('vet_appointments', appointment.toMap());
  }

  Future<VetAppointment?> getUpcomingAppointment(int userId) async {
    final database = await _database;
    final results = await database.rawQuery('''
      SELECT a.*, c.tag_number AS cow_tag, c.name AS cow_name, d.name AS doctor_name, d.phone AS doctor_phone
      FROM vet_appointments a
      LEFT JOIN cows c ON a.cow_id = c.id
      LEFT JOIN vet_doctors d ON a.doctor_id = d.id
      WHERE a.user_id = ? AND a.status = 'SCHEDULED'
      ORDER BY a.scheduled_date ASC, a.scheduled_time ASC, a.id ASC
      LIMIT 1
    ''', [userId]);

    if (results.isEmpty) return null;
    return VetAppointment.fromMap(results.first);
  }

  Future<List<VetAppointment>> getAppointments(int userId) async {
    final database = await _database;
    final results = await database.rawQuery('''
      SELECT a.*, c.tag_number AS cow_tag, c.name AS cow_name, d.name AS doctor_name, d.phone AS doctor_phone
      FROM vet_appointments a
      LEFT JOIN cows c ON a.cow_id = c.id
      LEFT JOIN vet_doctors d ON a.doctor_id = d.id
      WHERE a.user_id = ?
      ORDER BY a.scheduled_date DESC, a.scheduled_time DESC, a.id DESC
    ''', [userId]);

    return results.map((m) => VetAppointment.fromMap(m)).toList();
  }

  Future<int> updateAppointmentStatus(int appointmentId, String status) async {
    final database = await _database;
    return await database.update(
      'vet_appointments',
      {'status': status},
      where: 'id = ?',
      whereArgs: [appointmentId],
    );
  }
}
