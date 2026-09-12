import 'package:flutter/foundation.dart';

import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../../dashboard/data/repositories/activity_log_repository.dart';
import '../../../dashboard/data/models/activity_log_model.dart';
import 'package:flutter/material.dart' show Icons;

/// UI state for an in-flight auth operation.
enum AuthStatus {
  /// Nothing happening — initial or post-result state.
  idle,

  /// An async DB operation is running.
  loading,

  /// Last operation succeeded.
  success,

  /// Last operation failed — check [errorMessage].
  error,
}

/// ChangeNotifier provider for all authentication state.
///
/// Owned by the root [MultiProvider] so it is available throughout the app.
/// The UI watches [status], [currentUser], and [errorMessage].
class AuthProvider extends ChangeNotifier {
  final AuthRepository _repository;
  final ActivityLogRepository _activityRepo = ActivityLogRepository();

  AuthProvider({AuthRepository? repository})
      : _repository = repository ?? AuthRepository();

  // ── State ─────────────────────────────────────────────────────────────────

  AuthStatus _status = AuthStatus.idle;
  AuthStatus get status => _status;

  /// The logged-in user, or null when not authenticated.
  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  /// Non-null only when [status] is [AuthStatus.error].
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// Convenience getter — true when a user has been authenticated this session.
  bool get isLoggedIn => _currentUser != null;

  // ── Private helpers ───────────────────────────────────────────────────────

  void _setLoading() {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();
  }

  void _setSuccess(UserModel user) {
    _currentUser = user;
    _status = AuthStatus.success;
    _errorMessage = null;
    notifyListeners();
  }

  void _setError(String message) {
    _status = AuthStatus.error;
    _errorMessage = message;
    notifyListeners();
  }

  // ── Public actions ────────────────────────────────────────────────────────

  /// Attempts to sign up a new farmer account.
  ///
  /// On success, [currentUser] is populated and [status] becomes
  /// [AuthStatus.success].  The caller can then navigate to the dashboard.
  Future<void> signup(String username, String password, String farmName, String farmerName) async {
    _setLoading();
    final result = await _repository.signUp(username, password, farmName, farmerName);
    switch (result) {
      case AuthSuccess(:final user):
        _setSuccess(user);
        // Log farm registration activity (non-blocking).
        try {
          await _activityRepo.logActivity(ActivityLogModel(
            userId: user.id!,
            title: 'Farm Account Registered',
            subtitle: farmName,
            value: 'Owner: $farmerName',
            timeUnix: DateTime.now().millisecondsSinceEpoch,
            iconCode: Icons.storefront_rounded.codePoint,
            isPositive: 1,
            metadata: {'username': username, 'farmName': farmName},
          ));
        } catch (_) {}
      case AuthFailure(:final message):
        _setError(message);
    }
  }

  /// Attempts to log in with [username] and [password].
  ///
  /// On success, [currentUser] is populated.  The caller navigates away.
  Future<void> login(String username, String password) async {
    _setLoading();
    final result = await _repository.login(username, password);
    switch (result) {
      case AuthSuccess(:final user):
        _setSuccess(user);
        // Log login activity (non-blocking).
        try {
          final displayName = user.farmerName ?? user.username;
          await _activityRepo.logActivity(ActivityLogModel(
            userId: user.id!,
            title: 'Farmer Logged In',
            subtitle: 'Welcome back, $displayName',
            value: 'Active Session',
            timeUnix: DateTime.now().millisecondsSinceEpoch,
            iconCode: Icons.login_rounded.codePoint,
            isPositive: 1,
            metadata: {'username': user.username},
          ));
        } catch (_) {}
      case AuthFailure(:final message):
        _setError(message);
    }
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }

  /// Logs out the current user and resets all state.
  Future<void> logout() async {
    // Capture user info before clearing state.
    final user = _currentUser;

    _currentUser = null;
    _status = AuthStatus.idle;
    _errorMessage = null;
    notifyListeners();

    // Log logout activity (non-blocking).
    if (user != null && user.id != null) {
      try {
        final displayName = user.farmerName ?? user.username;
        await _activityRepo.logActivity(ActivityLogModel(
          userId: user.id!,
          title: 'Farmer Logged Out',
          subtitle: 'Session ended for $displayName',
          value: 'Session Ended',
          timeUnix: DateTime.now().millisecondsSinceEpoch,
          iconCode: Icons.logout_rounded.codePoint,
          isPositive: 0,
          metadata: {'username': user.username},
        ));
      } catch (_) {}
    }
  }
}
