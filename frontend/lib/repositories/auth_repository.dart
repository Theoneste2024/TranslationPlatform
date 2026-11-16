import 'package:dio/dio.dart';

import '../core/network/api_client.dart';
import '../models/user_model.dart';

class AuthException implements Exception {
  final String message;

  const AuthException(this.message);

  @override
  String toString() => message;
}

class AuthRepository {
  final ApiClient _apiClient;

  AuthRepository(this._apiClient);

  void setSessionExpiredHandler(void Function()? handler) {
    _apiClient.onSessionExpired = handler;
  }

  Future<bool> hasStoredSession() => _apiClient.hasStoredSession();

  Future<UserModel> login({
    required String identifier,
    required String password,
  }) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        'auth/token/',
        data: {'identifier': identifier, 'password': password},
      );
      final data = response.data;
      final user = data?['user'];
      final accessToken = data?['access']?.toString();
      final refreshToken = data?['refresh']?.toString();
      if (user is! Map ||
          accessToken == null ||
          refreshToken == null ||
          accessToken.isEmpty ||
          refreshToken.isEmpty) {
        throw const AuthException('The sign-in response was invalid.');
      }

      await _apiClient.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );
      return UserModel.fromJson(Map<String, dynamic>.from(user));
    } on DioException catch (error) {
      throw AuthException(_messageFrom(error));
    }
  }

  Future<String> register({
    required String email,
    required String username,
    required String phoneNumber,
    required String gender,
    required String password,
    required String confirmPassword,
  }) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        'auth/register/',
        data: {
          'email': email,
          'username': username,
          'phone_number': phoneNumber,
          'gender': gender,
          'password': password,
          'confirm_password': confirmPassword,
        },
      );
      return response.data?['detail']?.toString() ??
          'Account created. Verify your email before signing in.';
    } on DioException catch (error) {
      throw AuthException(_messageFrom(error));
    }
  }

  Future<UserModel> getCurrentUser() async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        'auth/me/',
      );
      if (response.data == null) {
        throw const AuthException('The account response was empty.');
      }
      return UserModel.fromJson(response.data!);
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        await _apiClient.clearTokens();
      }
      throw AuthException(_messageFrom(error));
    }
  }

  Future<String> resendVerification(String email) =>
      _postDetail('auth/verify-email/resend/', {'email': email});

  Future<String> requestPasswordReset(String email) =>
      _postDetail('auth/password-reset/', {'email': email});

  Future<String> _postDetail(String path, Map<String, String> data) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        path,
        data: data,
      );
      return response.data?['detail']?.toString() ?? 'Request completed.';
    } on DioException catch (error) {
      throw AuthException(_messageFrom(error));
    }
  }

  Future<void> logout() => _apiClient.clearTokens();

  String _messageFrom(DioException error) {
    final message = _flattenErrors(error.response?.data);
    if (message.isNotEmpty) return message;
    if (error.response == null) {
      return 'Could not reach the server. Check your connection and API URL.';
    }
    return 'Request failed (${error.response?.statusCode}). Please try again.';
  }

  String _flattenErrors(dynamic value) {
    if (value is Map) {
      for (final key in const ['detail', 'error', 'non_field_errors']) {
        if (value.containsKey(key)) {
          final message = _flattenErrors(value[key]);
          if (message.isNotEmpty) return message;
        }
      }
      return value.entries
          .map((entry) {
            final message = _flattenErrors(entry.value);
            return message.isEmpty ? '' : '${entry.key}: $message';
          })
          .where((message) => message.isNotEmpty)
          .join('\n');
    }
    if (value is List) {
      return value.map(_flattenErrors).where((e) => e.isNotEmpty).join('\n');
    }
    if (value is String) return value;
    return '';
  }
}
