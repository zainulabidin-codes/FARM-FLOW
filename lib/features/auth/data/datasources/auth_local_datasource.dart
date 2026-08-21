import 'package:sqflite/sqflite.dart';

import '../../../../core/database/database_helper.dart';
import '../models/user_model.dart';

/// Low-level SQLite access for the `users` table.
///
/// This class owns ONLY the raw INSERT / SELECT queries.  All business logic
/// (hashing, validation, error surfacing) lives in [AuthRepository].
class AuthLocalDatasource {
  /// Inserts [user] into the `users` table and returns the generated row id.
  ///
  /// The [user.passwordHash] field must already be a SHA-256 hex digest —
  /// this datasource never sees or processes plain-text passwords.
  ///
  /// Throws a [DatabaseException] if the username already exists
  /// (UNIQUE constraint violation from SQLite).
  Future<int> insertUser(UserModel user) async {
    final Database db = await DatabaseHelper.instance.database;
    return db.insert(
      'users',
      user.toMap(),
      // Reject duplicates at the DB level — do not silently overwrite.
      conflictAlgorithm: ConflictAlgorithm.fail,
    );
  }

  /// Returns the [UserModel] whose username matches [username], or `null`
  /// if no such user exists.
  ///
  /// The query is case-sensitive because SQLite TEXT comparisons are
  /// case-sensitive by default, which matches the login UX expectation.
  Future<UserModel?> getUser(String username) async {
    final Database db = await DatabaseHelper.instance.database;

    final cleanName = username.trim().toLowerCase();
    final List<Map<String, dynamic>> rows = await db.query(
      'users',
      where: 'LOWER(username) = ?',
      whereArgs: [cleanName],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return UserModel.fromMap(rows.first);
  }
}
