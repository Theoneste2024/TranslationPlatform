import 'package:flutter/foundation.dart';

import '../models/user_model.dart';
import '../repositories/auth_repository.dart';

enum AuthStatus { loading, signedOut, signedIn }

class AuthProvider extends ChangeNotifier {
  final AuthRepository _repository;

  AuthStatus _status = AuthStatus.loading;
  UserModel? _user;
  bool _isBusy = false;
  String? _errorMessage;
  String? _noticeMessage;

  AuthProvider(this._repository) {
    _repository.setSessionExpiredHandler(_handleExpiredSession);
    _restoreSession();
  }

  AuthStatus get status => _status;
  bool get isAuthenticated => _status == AuthStatus.signedIn;
  UserModel? get user => _user;
  bool get isBusy => _isBusy;
  String? get errorMessage => _errorMessage;
  String? get noticeMessage => _noticeMessage;

  Future<void> _restoreSession() async {
    try {
      if (await _repository.hasStoredSession()) {
        _user = await _repository.getCurrentUser();
        _status = AuthStatus.signedIn;
      } else {
        _status = AuthStatus.signedOut;
      }
    } on Object catch (error) {
      if (_status != AuthStatus.signedOut || _errorMessage == null) {
        _errorMessage = _displayError(error);
      }
      _status = AuthStatus.signedOut;
    } finally {
      notifyListeners();
    }
  }

  Future<void> login({
    required String identifier,
    required String password,
  }) async {
    await _run(() async {
      _user = await _repository.login(
        identifier: identifier,
        password: password,
      );
      _status = AuthStatus.signedIn;
      return null;
    });
  }

  Future<void> register({
    required String email,
    required String username,
    required String phoneNumber,
    required String gender,
    required String password,
    required String confirmPassword,
  }) async {
    await _run(
      () => _repository.register(
        email: email,
        username: username,
        phoneNumber: phoneNumber,
        gender: gender,
        password: password,
        confirmPassword: confirmPassword,
      ),
    );
  }

  Future<void> resendVerification(String email) async {
    await _run(() => _repository.resendVerification(email));
  }

  Future<void> requestPasswordReset(String email) async {
    await _run(() => _repository.requestPasswordReset(email));
  }

  Future<void> logout() async {
    _isBusy = true;
    _errorMessage = null;
    _noticeMessage = null;
    notifyListeners();
    try {
      await _repository.logout();
    } on Object catch (error) {
      _errorMessage = _displayError(error);
    } finally {
      _user = null;
      _status = AuthStatus.signedOut;
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> _run(Future<String?> Function() action) async {
    _isBusy = true;
    _errorMessage = null;
    _noticeMessage = null;
    notifyListeners();
    try {
      _noticeMessage = await action();
    } on Object catch (error) {
      _errorMessage = _displayError(error);
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  String _displayError(Object error) {
    if (error is AuthException) return error.message;
    return error.toString().replaceFirst('Exception: ', '');
  }

  void _handleExpiredSession() {
    _user = null;
    _status = AuthStatus.signedOut;
    _errorMessage = 'Your session expired. Please sign in again.';
    notifyListeners();
  }

  @override
  void dispose() {
    _repository.setSessionExpiredHandler(null);
    super.dispose();
  }
}
