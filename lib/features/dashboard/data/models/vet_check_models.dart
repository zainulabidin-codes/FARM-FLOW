class VetDoctor {
  final int? id;
  final int userId;
  final String name;
  final String qualification;
  final String phone;
  final bool isPrimary;

  const VetDoctor({
    this.id,
    required this.userId,
    required this.name,
    required this.qualification,
    required this.phone,
    this.isPrimary = false,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'name': name,
      'qualification': qualification,
      'phone': phone,
      'is_primary': isPrimary ? 1 : 0,
      'created_at': DateTime.now().toIso8601String(),
    };
  }

  factory VetDoctor.fromMap(Map<String, dynamic> map) {
    return VetDoctor(
      id: map['id'] as int?,
      userId: map['user_id'] as int,
      name: map['name'] as String,
      qualification: map['qualification'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      isPrimary: (map['is_primary'] as int? ?? 0) == 1,
    );
  }
}

class VetAppointment {
  final int? id;
  final int userId;
  final int cowId;
  final int doctorId;
  final String scheduledDate;
  final String scheduledTime;
  final List<String> reasons;
  final String? customNotes;
  final String? feedbackNotes;
  final bool hasFollowUp;
  final String? followUpDate;
  final String status;
  final String? cowTag;
  final String? cowName;
  final String? doctorName;
  final String? doctorPhone;

  const VetAppointment({
    this.id,
    required this.userId,
    required this.cowId,
    required this.doctorId,
    required this.scheduledDate,
    required this.scheduledTime,
    required this.reasons,
    this.customNotes,
    this.feedbackNotes,
    this.hasFollowUp = false,
    this.followUpDate,
    this.status = 'SCHEDULED',
    this.cowTag,
    this.cowName,
    this.doctorName,
    this.doctorPhone,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'cow_id': cowId,
      'doctor_id': doctorId,
      'scheduled_date': scheduledDate,
      'scheduled_time': scheduledTime,
      'reasons': reasons.join('||'),
      'custom_notes': customNotes,
      'feedback_notes': feedbackNotes,
      'has_follow_up': hasFollowUp ? 1 : 0,
      'follow_up_date': followUpDate,
      'status': status,
      'created_at': DateTime.now().toIso8601String(),
    };
  }

  factory VetAppointment.fromMap(Map<String, dynamic> map) {
    final reasonsRaw = map['reasons'] as String? ?? '';
    final reasons = reasonsRaw.isEmpty
        ? <String>[]
        : reasonsRaw.contains('||')
            ? reasonsRaw.split('||')
            : reasonsRaw.split(',');

    return VetAppointment(
      id: map['id'] as int?,
      userId: map['user_id'] as int,
      cowId: map['cow_id'] as int,
      doctorId: map['doctor_id'] as int,
      scheduledDate: map['scheduled_date'] as String,
      scheduledTime: map['scheduled_time'] as String,
      reasons: reasons,
      customNotes: map['custom_notes'] as String?,
      feedbackNotes: map['feedback_notes'] as String?,
      hasFollowUp: (map['has_follow_up'] as int? ?? 0) == 1,
      followUpDate: map['follow_up_date'] as String?,
      status: map['status'] as String? ?? 'SCHEDULED',
      cowTag: map['cow_tag'] as String?,
      cowName: map['cow_name'] as String?,
      doctorName: map['doctor_name'] as String?,
      doctorPhone: map['doctor_phone'] as String?,
    );
  }
}

