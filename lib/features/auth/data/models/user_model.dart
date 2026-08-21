/// Data model for the `users` table.
///
/// Passwords are NEVER stored in plain text; [passwordHash] holds the
/// SHA-256 hex digest produced by the auth layer before persisting.
class UserModel {
  final int? id;

  /// The unique login handle chosen by the farmer.
  final String username;

  /// SHA-256 hex digest of the user's password.  Never the raw password.
  final String passwordHash;

  /// The name of the farm
  final String? farmName;

  /// The name of the farmer
  final String? farmerName;

  const UserModel({
    this.id,
    required this.username,
    required this.passwordHash,
    this.farmName,
    this.farmerName,
  });

  // ── Persistence helpers ────────────────────────────────────────────────

  /// Deserialises a row returned by sqflite.
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as int?,
      username: map['username'] as String,
      passwordHash: map['password_hash'] as String,
      farmName: map['farm_name'] as String?,
      farmerName: map['farmer_name'] as String?,
    );
  }

  /// Serialises to a map suitable for sqflite insert / update.
  ///
  /// The [id] field is excluded when null so SQLite can auto-generate it.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      if (id != null) 'id': id,
      'username': username,
      'password_hash': passwordHash,
      if (farmName != null) 'farm_name': farmName,
      if (farmerName != null) 'farmer_name': farmerName,
    };
  }

  @override
  String toString() =>
      'UserModel(id: $id, username: $username)';
}
