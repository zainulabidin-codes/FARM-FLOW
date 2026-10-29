import 'package:flutter/foundation.dart';
import '../../data/models/vet_check_models.dart';
import '../../data/repositories/vet_check_repository.dart';
import 'activity_log_provider.dart';

class VetCheckProvider extends ChangeNotifier {
  final VetCheckRepository _repository;
  ActivityLogProvider? _activityProvider;

  List<VetDoctor> _doctors = [];
  VetAppointment? _upcomingAppointment;
  bool _isLoading = false;
  String? _error;

  VetCheckProvider({VetCheckRepository? repository})
      : _repository = repository ?? VetCheckRepository();

  List<VetDoctor> get doctors => _doctors;
  VetAppointment? get upcomingAppointment => _upcomingAppointment;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void setActivityProvider(ActivityLogProvider? provider) {
    _activityProvider = provider;
  }

  Future<void> loadAll(int userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _repository.getDoctors(userId),
        _repository.getUpcomingAppointment(userId),
      ]);
      _doctors = results[0] as List<VetDoctor>;
      _upcomingAppointment = results[1] as VetAppointment?;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadDoctors(int userId) async {
    try {
      _doctors = await _repository.getDoctors(userId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> loadUpcomingAppointment(int userId) async {
    try {
      _upcomingAppointment = await _repository.getUpcomingAppointment(userId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<VetDoctor?> addDoctor(VetDoctor doctor) async {
    try {
      final id = await _repository.addDoctor(doctor);
      await loadDoctors(doctor.userId);
      return _doctors.firstWhere(
        (d) => d.id == id,
        orElse: () => VetDoctor(
          id: id,
          userId: doctor.userId,
          name: doctor.name,
          qualification: doctor.qualification,
          phone: doctor.phone,
          isPrimary: doctor.isPrimary,
        ),
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> deleteDoctor(int doctorId, int userId) async {
    try {
      await _repository.deleteDoctor(doctorId, userId);
      await loadDoctors(userId);
      await loadUpcomingAppointment(userId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<int?> scheduleAppointment(
    VetAppointment appointment, {
    String? cowTag,
    String? doctorName,
  }) async {
    try {
      final id = await _repository.scheduleAppointment(appointment);
      await loadUpcomingAppointment(appointment.userId);

      if (_activityProvider != null) {
        final tag = cowTag ?? (appointment.cowTag ?? '${appointment.cowId}');
        final doc = doctorName ?? (appointment.doctorName ?? 'Doctor');
        await _activityProvider!.logVetAppointmentScheduled(
          userId: appointment.userId,
          cowTag: tag,
          doctorName: doc,
          scheduledDate: appointment.scheduledDate,
          scheduledTime: appointment.scheduledTime,
        );
      }

      notifyListeners();
      return id;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<void> updateAppointmentStatus(
    int appointmentId,
    String status,
    int userId,
  ) async {
    try {
      await _repository.updateAppointmentStatus(appointmentId, status);
      await loadUpcomingAppointment(userId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
}

