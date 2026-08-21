import 'package:crypto/crypto.dart';
import 'dart:convert';

import '../datasources/auth_local_datasource.dart';
import '../models/user_model.dart';

/// Result type for auth operations — avoids throwing exceptions for
/// expected failure modes (wrong password, duplicate username).
sealed class AuthResult {}

class AuthSuccess extends AuthResult {
  final UserModel user;
  AuthSuccess(this.user);
}

class AuthFailure extends AuthResult {
  /// Human-readable reason, safe to show in the UI.
  final String message;
  AuthFailure(this.message);
}

/// Business-logic layer for all authentication operations.
///
/// Responsibilities:
///   1. Hash passwords with SHA-256 before they touch the database.
///   2. Coordinate with [AuthLocalDatasource] for persistence.
///   3. Return typed [AuthResult] so callers never catch raw exceptions
///      for expected failure paths.
class AuthRepository {
  final AuthLocalDatasource _datasource;

  AuthRepository({AuthLocalDatasource? datasource})
      : _datasource = datasource ?? AuthLocalDatasource();

  // ── Hashing ───────────────────────────────────────────────────────────────

  /// Returns the SHA-256 hex digest of [plainText].
  ///
  /// This is a pure function — no I/O, always deterministic.
  String _hashPassword(String plainText) {
    final bytes = utf8.encode(plainText);
    final digest = sha256.convert(bytes);
    return digest.toString(); // 64-char lowercase hex string
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Creates a new user account.
  ///
  /// Returns [AuthSuccess] with the created [UserModel] on success, or
  /// [AuthFailure] with a descriptive message if the username is taken or
  /// any other persistence error occurs.
  Future<AuthResult> signUp(String username, String password, String farmName, String farmerName) async {
    final cleanUsername = username.trim().toLowerCase();
    if (cleanUsername.isEmpty) {
      return AuthFailure('Username cannot be empty.');
    }
    if (password.length < 4) {
      return AuthFailure('Password must be at least 4 characters.');
    }

    final hash = _hashPassword(password);
    final newUser = UserModel(
      username: cleanUsername,
      passwordHash: hash,
      farmName: farmName.trim().isNotEmpty ? farmName.trim() : null,
      farmerName: farmerName.trim().isNotEmpty ? farmerName.trim() : null,
    );

    try {
      final id = await _datasource.insertUser(newUser);
      // Return the complete model with the DB-generated id and farm details attached.
      return AuthSuccess(UserModel(
        id: id,
        username: newUser.username,
        passwordHash: newUser.passwordHash,
        farmName: newUser.farmName,
        farmerName: newUser.farmerName,
      ));
    } catch (e) {
      // SQLite UNIQUE constraint violation → username already taken.
      return AuthFailure('Username "$cleanUsername" is already taken.');
    }
  }

  /// Validates credentials against the stored hash.
  ///
  /// Returns [AuthSuccess] with the matching [UserModel] on success, or
  /// [AuthFailure] if the user does not exist or the password is wrong.
  Future<AuthResult> login(String username, String password) async {
    final cleanUsername = username.trim().toLowerCase();
    if (cleanUsername.isEmpty || password.isEmpty) {
      return AuthFailure('Please enter your username and password.');
    }

    final existingUser = await _datasource.getUser(cleanUsername);
    if (existingUser == null) {
      return AuthFailure('Invalid username or password.');
    }

    final inputHash = _hashPassword(password);
    if (inputHash != existingUser.passwordHash) {
      return AuthFailure('Invalid username or password.');
    }

    return AuthSuccess(existingUser);
  }
}
