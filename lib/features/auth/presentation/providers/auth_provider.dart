import 'package:flutter/foundation.dart';

import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';

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
      case AuthFailure(:final message):
        _setError(message);
    }
  }

  /// Logs out the current user and resets all state.
  void logout() {
    _currentUser = null;
    _status = AuthStatus.idle;
    _errorMessage = null;
    notifyListeners();
  }
}
