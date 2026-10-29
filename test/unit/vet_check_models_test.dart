import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_farm_app/features/dashboard/data/models/vet_check_models.dart';

void main() {
  group('VetDoctor Model Tests', () {
    test('toMap and fromMap should be consistent', () {
      final doc = VetDoctor(
        id: 1,
        userId: 42,
        name: 'Dr. Sarah Jenkins',
        qualification: 'B.V.Sc & A.H',
        phone: '+92 300 1234567',
        isPrimary: true,
      );

      final map = doc.toMap();
      expect(map['id'], 1);
      expect(map['user_id'], 42);
      expect(map['name'], 'Dr. Sarah Jenkins');
      expect(map['is_primary'], 1);

      final restored = VetDoctor.fromMap(map);
      expect(restored.id, 1);
      expect(restored.userId, 42);
      expect(restored.name, 'Dr. Sarah Jenkins');
      expect(restored.qualification, 'B.V.Sc & A.H');
      expect(restored.phone, '+92 300 1234567');
      expect(restored.isPrimary, true);
    });

    test('fromMap should handle missing optional values gracefully', () {
      final map = <String, dynamic>{
        'id': 2,
        'user_id': 99,
        'name': 'Dr. Vance',
      };

      final doc = VetDoctor.fromMap(map);
      expect(doc.id, 2);
      expect(doc.userId, 99);
      expect(doc.name, 'Dr. Vance');
      expect(doc.qualification, '');
      expect(doc.phone, '');
      expect(doc.isPrimary, false);
    });
  });

  group('VetAppointment Model Tests', () {
    test('toMap and fromMap should serialize reasons with delimiter', () {
      final appointment = VetAppointment(
        id: 10,
        userId: 42,
        cowId: 5,
        doctorId: 3,
        scheduledDate: '2026-10-30',
        scheduledTime: '10:30 AM',
        reasons: ['Vaccination', 'Mastitis Screen'],
        customNotes: 'Routine bi-annual check',
        feedbackNotes: 'All clear',
        hasFollowUp: true,
        followUpDate: '2026-11-06',
        status: 'SCHEDULED',
        cowTag: 'COW-005',
        cowName: 'Daisy',
        doctorName: 'Dr. Sarah Jenkins',
        doctorPhone: '+92 300 1234567',
      );

      final map = appointment.toMap();
      expect(map['reasons'], 'Vaccination||Mastitis Screen');
      expect(map['has_follow_up'], 1);
      expect(map['status'], 'SCHEDULED');

      // Add extra join columns as SQLite query would
      map['cow_tag'] = 'COW-005';
      map['cow_name'] = 'Daisy';
      map['doctor_name'] = 'Dr. Sarah Jenkins';
      map['doctor_phone'] = '+92 300 1234567';

      final restored = VetAppointment.fromMap(map);
      expect(restored.id, 10);
      expect(restored.userId, 42);
      expect(restored.cowId, 5);
      expect(restored.doctorId, 3);
      expect(restored.scheduledDate, '2026-10-30');
      expect(restored.scheduledTime, '10:30 AM');
      expect(restored.reasons, ['Vaccination', 'Mastitis Screen']);
      expect(restored.customNotes, 'Routine bi-annual check');
      expect(restored.feedbackNotes, 'All clear');
      expect(restored.hasFollowUp, true);
      expect(restored.followUpDate, '2026-11-06');
      expect(restored.status, 'SCHEDULED');
      expect(restored.cowTag, 'COW-005');
      expect(restored.cowName, 'Daisy');
      expect(restored.doctorName, 'Dr. Sarah Jenkins');
    });

    test('fromMap should handle empty reasons', () {
      final map = <String, dynamic>{
        'id': 1,
        'user_id': 1,
        'cow_id': 2,
        'doctor_id': 3,
        'scheduled_date': '2026-10-30',
        'scheduled_time': '14:00',
        'reasons': '',
      };

      final restored = VetAppointment.fromMap(map);
      expect(restored.reasons, isEmpty);
      expect(restored.hasFollowUp, false);
      expect(restored.status, 'SCHEDULED');
    });
  });
}

