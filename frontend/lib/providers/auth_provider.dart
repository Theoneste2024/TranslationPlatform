import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_config.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({
    Dio? dio,
    Future<SharedPreferences> Function()? preferencesFactory,
  })  : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: ApiConfig.baseUrl,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 15),
                headers: const {'Content-Type': 'application/json'},
              ),
            ),
        _preferencesFactory =
            preferencesFactory ?? SharedPreferences.getInstance;

  static const _tokenKey = 'auth_access_token';
  static const _expiryKey = 'auth_token_expiry';
  static const _usernameKey = 'auth_username';
  static const _emailKey = 'auth_email';

  final Dio _dio;
  final Future<SharedPreferences> Function() _preferencesFactory;
  String? _accessToken;
  UserModel? _user;
  bool _isLoading = false;
  bool _isInitializing = true;
  String? _initializationError;

  bool get isAuthenticated => _accessToken != null && _user != null;
  bool get isLoading => _isLoading;
  bool get isInitializing => _isInitializing;
  String? get initializationError => _initializationError;
  String? get accessToken => _accessToken;
  UserModel? get user => _user;

  void continueToLogin() {
    _initializationError = null;
    _accessToken = null;
    _user = null;
    notifyListeners();
  }

  Future<void> restoreSession() async {
    _isInitializing = true;
    _initializationError = null;
    notifyListeners();
    try {
      final preferences = await _preferencesFactory();
      final token = preferences.getString(_tokenKey);
      final expiresAt = preferences.getInt(_expiryKey);
      final username = preferences.getString(_usernameKey);
      final email = preferences.getString(_emailKey);

      if (token != null &&
          expiresAt != null &&
          expiresAt > DateTime.now().millisecondsSinceEpoch &&
          username != null &&
          email != null) {
        _accessToken = token;
        _user = UserModel(name: username, email: email, photoURL: '');
      } else {
        await _clearStoredSession(preferences);
        _accessToken = null;
        _user = null;
      }
    } catch (error) {
      _initializationError =
          'Could not restore your saved login. Retry or log in again.';
      debugPrint('Could not restore the saved authentication session: $error');
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<OtpTiming> register({
    required String username,
    required String email,
    required String phoneNumber,
    required String country,
    required String gender,
    required String password,
    required String confirmPassword,
  }) async {
    final response = await _post('/api/users/signup', {
      'username': username,
      'email': email,
      'phone_number': phoneNumber,
      'country': country,
      'gender': gender,
      'password': password,
      'confirm_password': confirmPassword,
    });
    return _otpTimingFrom(response.data);
  }

  Future<void> verifyEmail({
    required String email,
    required String otp,
  }) async {
    await _post('/api/users/verify-email', {'email': email, 'otp': otp});
  }

  Future<OtpTiming> resendVerification({required String email}) async {
    final response =
        await _post('/api/users/resend-verification', {'email': email});
    return _otpTimingFrom(response.data);
  }

  Future<OtpTiming> requestPasswordReset({required String email}) async {
    final response =
        await _post('/api/users/forgot-password', {'email': email});
    return _otpTimingFrom(response.data);
  }

  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
    required String confirmPassword,
  }) async {
    await _post('/api/users/reset-password', {
      'email': email,
      'otp': otp,
      'new_password': newPassword,
      'confirm_password': confirmPassword,
    });
  }

  Future<void> login({
    required String identifier,
    required String password,
  }) async {
    final response = await _post('/api/users/login', {
      'identifier': identifier,
      'password': password,
    });
    final payload = response.data;
    if (payload is! Map ||
        payload['access_token'] is! String ||
        payload['user'] is! Map) {
      throw const AuthException(
          'The server returned an invalid login response.');
    }

    final userData = Map<String, dynamic>.from(payload['user'] as Map);
    final user = UserModel(
      name: userData['username'] as String? ?? identifier,
      email: userData['email'] as String? ?? '',
      photoURL: '',
    );
    final token = payload['access_token'] as String;
    final expirySeconds =
        payload['expires_in'] is int ? payload['expires_in'] as int : 3600;
    try {
      final preferences = await _preferencesFactory();
      final expiresAt = DateTime.now()
          .add(Duration(seconds: expirySeconds))
          .millisecondsSinceEpoch;
      final saved = await Future.wait([
        preferences.setString(_tokenKey, token),
        preferences.setInt(_expiryKey, expiresAt),
        preferences.setString(_usernameKey, user.name),
        preferences.setString(_emailKey, user.email),
      ]);
      if (saved.any((success) => !success)) {
        await _clearStoredSession(preferences);
        throw const AuthException('Could not save your login session.');
      }
    } on AuthException {
      rethrow;
    } catch (error) {
      debugPrint('Could not save the authentication session: $error');
      throw const AuthException('Could not save your login session.');
    }

    _accessToken = token;
    _user = user;
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      final preferences = await _preferencesFactory();
      await _clearStoredSession(preferences);
    } catch (error) {
      debugPrint('Could not clear the authentication session: $error');
      throw const AuthException('Could not log out. Please try again.');
    }
    _accessToken = null;
    _user = null;
    notifyListeners();
  }

  Future<Response<dynamic>> _post(
    String path,
    Map<String, Object> data,
  ) async {
    _isLoading = true;
    notifyListeners();
    try {
      return await _dio.post<dynamic>(path, data: data);
    } on DioException catch (error) {
      throw AuthException(_messageFor(error));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String _messageFor(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      final message = data['error'];
      if (message is String && message.isNotEmpty) return message;
      final errors = data['errors'];
      if (errors is List && errors.isNotEmpty) {
        return errors.whereType<String>().join(' ');
      }
    }
    if (error.response == null) {
      return 'Could not reach the server at ${ApiConfig.baseUrl}. Check the connection and try again.';
    }
    return 'The request could not be completed. Please try again.';
  }

  OtpTiming _otpTimingFrom(dynamic payload) {
    if (payload is! Map ||
        payload['expires_in'] is! num ||
        payload['resend_in'] is! num) {
      throw const AuthException(
        'The server did not provide OTP expiry information.',
      );
    }
    return OtpTiming(
      expiresInSeconds: (payload['expires_in'] as num).toInt(),
      resendInSeconds: (payload['resend_in'] as num).toInt(),
    );
  }

  Future<void> _clearStoredSession(SharedPreferences preferences) async {
    await Future.wait([
      preferences.remove(_tokenKey),
      preferences.remove(_expiryKey),
      preferences.remove(_usernameKey),
      preferences.remove(_emailKey),
    ]);
  }
}

class OtpTiming {
  const OtpTiming({
    required this.expiresInSeconds,
    required this.resendInSeconds,
  });

  final int expiresInSeconds;
  final int resendInSeconds;
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class UserModel {
  final String name;
  final String email;
  final String photoURL;

  UserModel({
    required this.name,
    required this.email,
    required this.photoURL,
  });
}
