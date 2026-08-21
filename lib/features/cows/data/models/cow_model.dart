/// Data model for the `cows` table.
///
/// Dates ([matingDate], [deliveryDate]) are stored as ISO-8601 strings
/// (e.g. "2026-03-15") so SQLite can sort them lexicographically.
class CowModel {
  final int? id;

  /// FK → users.id
  final int userId;

  /// Physical ear / RFID tag identifier.
  final String tagNumber;

  final String? name;

  /// Life-stage status.  One of: 'MILKING', 'DRY', 'PREGNANT', 'HEIFER'.
  final String status;

  /// ISO-8601 date string of the last confirmed mating, or null.
  final String? matingDate;

  /// ISO-8601 date string of the expected / actual delivery date, or null.
  final String? deliveryDate;
  final String? estimatedBirthDate;
  final int isDeleted;
  final String? deletedReason;
  final String? deletedDate;
  final int hasLactatedBefore;

  // Additional fields for displaying derived yields
  final int? peakMorningYield;
  final int? peakEveningYield;
  final int? lowestMorningYield;
  final int? lowestEveningYield;

  const CowModel({
    this.id,
    required this.userId,
    required this.tagNumber,
    this.name,
    this.status = 'MILKING',
    this.matingDate,
    this.deliveryDate,
    this.estimatedBirthDate,
    this.isDeleted = 0,
    this.deletedReason,
    this.deletedDate,
    this.hasLactatedBefore = 0,
    this.peakMorningYield,
    this.peakEveningYield,
    this.lowestMorningYield,
    this.lowestEveningYield,
  });

  // ── Persistence helpers ────────────────────────────────────────────────

  factory CowModel.fromMap(Map<String, dynamic> map) {
    return CowModel(
      id: map['id'] as int?,
      userId: map['user_id'] as int,
      tagNumber: map['tag_number'] as String,
      name: map['name'] as String?,
      status: map['status'] as String? ?? 'MILKING',
      matingDate: map['mating_date'] as String?,
      deliveryDate: map['delivery_date'] as String?,
      estimatedBirthDate: map['estimated_birth_date'] as String?,
      isDeleted: (map['is_deleted'] as int?) ?? 0,
      deletedReason: map['deleted_reason'] as String?,
      deletedDate: map['deleted_date'] as String?,
      hasLactatedBefore: (map['has_lactated_before'] as int?) ?? 0,
      peakMorningYield: map['peak_morning_yield'] as int?,
      peakEveningYield: map['peak_evening_yield'] as int?,
      lowestMorningYield: map['lowest_morning_yield'] as int?,
      lowestEveningYield: map['lowest_evening_yield'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'tag_number': tagNumber,
      'name': name,
      'status': status,
      'mating_date': matingDate,
      'delivery_date': deliveryDate,
      'estimated_birth_date': estimatedBirthDate,
      'is_deleted': isDeleted,
      'deleted_reason': deletedReason,
      'deleted_date': deletedDate,
      'has_lactated_before': hasLactatedBefore,
    };
  }

  @override
  String toString() =>
      'CowModel(id: $id, tagNumber: $tagNumber, status: $status)';
}
