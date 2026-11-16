import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';

class ApiClient {
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';

  final FlutterSecureStorage _storage;
  final Dio dio;
  final Dio _refreshDio;
  Future<String?>? _refreshInProgress;
  void Function()? onSessionExpired;

  ApiClient({FlutterSecureStorage? storage, Dio? dio})
      : _storage = storage ?? const FlutterSecureStorage(),
        dio = dio ?? Dio(BaseOptions(baseUrl: ApiConfig.dioBaseUrl)),
        _refreshDio = Dio(BaseOptions(baseUrl: ApiConfig.dioBaseUrl)) {
    this.dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) async {
              try {
                if (_requiresAuthentication(options.path)) {
                  final token = await _accessToken();
                  if (token != null) {
                    options.headers['Authorization'] = 'Bearer $token';
                  }
                }
                handler.next(options);
              } catch (error) {
                handler.reject(
                  DioException(requestOptions: options, error: error),
                );
              }
            },
            onError: (error, handler) async {
              final options = error.requestOptions;
              if (error.response?.statusCode != 401 ||
                  !_requiresAuthentication(options.path)) {
                handler.next(error);
                return;
              }
              if (options.extra['authRetry'] == true) {
                await clearTokens();
                onSessionExpired?.call();
                handler.next(error);
                return;
              }

              try {
                final token = await _refreshAccessToken();
                if (token == null) {
                  await clearTokens();
                  onSessionExpired?.call();
                  handler.next(error);
                  return;
                }
                options
                  ..extra['authRetry'] = true
                  ..headers['Authorization'] = 'Bearer $token';
                handler.resolve(await this.dio.fetch<dynamic>(options));
              } on DioException catch (_) {
                handler.next(error);
              } catch (_) {
                handler.next(error);
              }
            },
          ),
        );
  }

  static bool _requiresAuthentication(String path) {
    final normalizedPath = path.replaceFirst(RegExp(r'^/+'), '');
    if (!normalizedPath.startsWith('auth/')) return true;
    return normalizedPath == 'auth/me/';
  }

  Future<bool> hasStoredSession() async =>
      await _storage.read(key: _accessTokenKey) != null ||
      await _storage.read(key: _refreshTokenKey) != null;

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    try {
      await _storage.write(key: _accessTokenKey, value: accessToken);
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
    } catch (_) {
      await clearTokens();
      rethrow;
    }
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }

  Future<http.StreamedResponse> sendAuthorizedMultipart(
    Future<http.MultipartRequest> Function() requestFactory,
  ) async {
    final response = await _sendAuthorizedMultipart(requestFactory);
    if (response.statusCode != 401) return response;

    await response.stream.drain<void>();
    final token = await _refreshAccessToken();
    if (token == null) {
      await clearTokens();
      onSessionExpired?.call();
      throw StateError('Your session expired. Please sign in again.');
    }
    final retriedResponse = await _sendAuthorizedMultipart(requestFactory);
    if (retriedResponse.statusCode == 401) {
      await clearTokens();
      onSessionExpired?.call();
    }
    return retriedResponse;
  }

  Future<http.StreamedResponse> _sendAuthorizedMultipart(
    Future<http.MultipartRequest> Function() requestFactory,
  ) async {
    final token = await _accessToken();
    if (token == null) {
      throw StateError('Sign in is required to use this feature.');
    }
    final request = await requestFactory();
    request.headers['Authorization'] = 'Bearer $token';
    return request.send();
  }

  Future<String?> _accessToken() async {
    final accessToken = await _storage.read(key: _accessTokenKey);
    if (accessToken != null && !_expiresSoon(accessToken)) {
      return accessToken;
    }

    final refreshToken = await _storage.read(key: _refreshTokenKey);
    if (refreshToken == null) return accessToken;
    return _refreshAccessToken();
  }

  bool _expiresSoon(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      final expiry = (payload as Map<String, dynamic>)['exp'] as num?;
      if (expiry == null) return true;
      return DateTime.fromMillisecondsSinceEpoch(expiry.toInt() * 1000)
          .isBefore(DateTime.now().add(const Duration(seconds: 30)));
    } on Object {
      return true;
    }
  }

  Future<String?> _refreshAccessToken() {
    final inProgress = _refreshInProgress;
    if (inProgress != null) return inProgress;

    final refresh = _performRefresh();
    _refreshInProgress = refresh;
    return refresh.whenComplete(() {
      if (identical(_refreshInProgress, refresh)) {
        _refreshInProgress = null;
      }
    });
  }

  Future<String?> _performRefresh() async {
    final refreshToken = await _storage.read(key: _refreshTokenKey);
    if (refreshToken == null) return null;

    try {
      final response = await _refreshDio.post<Map<String, dynamic>>(
        'auth/token/refresh/',
        data: {'refresh': refreshToken},
      );
      final accessToken = response.data?['access']?.toString();
      if (accessToken == null || accessToken.isEmpty) {
        await clearTokens();
        onSessionExpired?.call();
        throw const FormatException('The token refresh response was invalid.');
      }
      final rotatedRefreshToken =
          response.data?['refresh']?.toString() ?? refreshToken;
      await saveTokens(
        accessToken: accessToken,
        refreshToken: rotatedRefreshToken,
      );
      return accessToken;
    } on DioException catch (error) {
      if (error.response?.statusCode == 400 ||
          error.response?.statusCode == 401) {
        await clearTokens();
        onSessionExpired?.call();
      }
      rethrow;
    }
  }

  void dispose() {
    dio.close();
    _refreshDio.close();
  }
}
