import '../datasources/vet_check_local_datasource.dart';
import '../models/vet_check_models.dart';

class VetCheckRepository {
  final VetCheckLocalDatasource _datasource;

  VetCheckRepository({VetCheckLocalDatasource? datasource})
      : _datasource = datasource ?? VetCheckLocalDatasource();

  Future<List<VetDoctor>> getDoctors(int userId) => _datasource.getDoctors(userId);

  Future<int> addDoctor(VetDoctor doctor) => _datasource.addDoctor(doctor);

  Future<int> deleteDoctor(int doctorId, int userId) =>
      _datasource.deleteDoctor(doctorId, userId);

  Future<int> scheduleAppointment(VetAppointment appointment) =>
      _datasource.scheduleAppointment(appointment);

  Future<VetAppointment?> getUpcomingAppointment(int userId) =>
      _datasource.getUpcomingAppointment(userId);

  Future<List<VetAppointment>> getAppointments(int userId) =>
      _datasource.getAppointments(userId);

  Future<int> updateAppointmentStatus(int appointmentId, String status) =>
      _datasource.updateAppointmentStatus(appointmentId, status);
}

