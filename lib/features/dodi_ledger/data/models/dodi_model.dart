/// Data model for the `dodis` table.
///
/// A "dodi" is a milk-buyer / regular customer.
///
/// STORAGE RULE — [defaultRatePaise] is always stored as INTEGER paise.
///   e.g. ₹5.50 per litre → 550 paise.  Never store as double.
class DodiModel {
  final int? id;

  /// FK → users.id
  final int userId;

  final String name;
  final String? phone;

  /// Default purchase rate expressed in PAISE (INTEGER).
  /// Divide by 100 to display to the user.
  final int defaultRatePaise;

  /// Soft deletion flag (0 = active, 1 = archived/deleted).
  final int isDeleted;

  const DodiModel({
    this.id,
    required this.userId,
    required this.name,
    this.phone,
    required this.defaultRatePaise,
    this.isDeleted = 0,
  });

  DodiModel copyWith({
    int? id,
    int? userId,
    String? name,
    String? phone,
    int? defaultRatePaise,
    int? isDeleted,
  }) {
    return DodiModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      defaultRatePaise: defaultRatePaise ?? this.defaultRatePaise,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  // ── Persistence helpers ────────────────────────────────────────────────

  factory DodiModel.fromMap(Map<String, dynamic> map) {
    return DodiModel(
      id: map['id'] as int?,
      userId: map['user_id'] as int,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      defaultRatePaise: map['default_rate_paise'] as int,
      isDeleted: (map['is_deleted'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      if (id != null) 'id': id,
      'user_id': userId,
      'name': name,
      'phone': phone,
      'default_rate_paise': defaultRatePaise,
      'is_deleted': isDeleted,
    };
  }

  @override
  String toString() =>
      'DodiModel(id: $id, name: $name, defaultRatePaise: $defaultRatePaise, isDeleted: $isDeleted)';
}
