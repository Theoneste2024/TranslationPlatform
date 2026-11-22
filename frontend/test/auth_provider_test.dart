import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:translation_platform/providers/auth_provider.dart';
import 'package:translation_platform/services/api_config.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('login URL does not append auth routes to the versioned API path',
      () async {
    final dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));
    String? requestPath;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requestPath = options.uri.toString();
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: <String, dynamic>{
                'access_token': 'test-token',
                'user': <String, dynamic>{'username': 'tester'},
              },
            ),
          );
        },
      ),
    );
    final provider = AuthProvider(dio: dio);

    await provider.login(identifier: 'tester', password: 'safe-test-password');

    expect(
      Uri.parse(requestPath!).path,
      '/api/users/login',
      reason: requestPath,
    );
    dio.close();
  });

  test('persists a supported system language through the authenticated API',
      () async {
    final requests = <RequestOptions>[];
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          if (options.path == '/api/users/login') {
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: <String, dynamic>{
                  'access_token': 'test-token',
                  'expires_in': 3600,
                  'user': <String, dynamic>{
                    'username': 'tester',
                    'email': 'tester@example.com',
                    'system_language': 'en',
                  },
                },
              ),
            );
            return;
          }
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: options.data,
            ),
          );
        },
      ),
    );
    final provider = AuthProvider(dio: dio);

    await provider.login(identifier: 'tester', password: 'safe-test-password');
    await provider.updateSystemLanguage('rw');

    expect(requests.last.path, '/api/users/me/system-language');
    expect(requests.last.data, {'system_language': 'rw'});
    expect(requests.last.headers['Authorization'], 'Bearer test-token');
    expect(provider.systemLanguage, 'rw');
    expect(provider.user?.systemLanguage, 'rw');

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('system_language'), 'rw');
    final restored = AuthProvider();
    await restored.restoreSession();
    expect(restored.systemLanguage, 'rw');
    dio.close();
  });

  test('sends auth payloads and restores an unexpired login session', () async {
    final requests = <RequestOptions>[];
    final provider = AuthProvider(dio: _successfulAuthDio(requests));

    final otpTiming = await provider.register(
      username: 'jean_claude',
      email: 'jean@example.com',
      phoneNumber: '+250781234567',
      country: 'Rwanda',
      gender: 'male',
      password: 'Mpuza@2026',
      confirmPassword: 'Mpuza@2026',
    );
    expect(otpTiming.expiresInSeconds, 937);
    expect(otpTiming.resendInSeconds, 83);
    expect(requests.last.path, '/api/users/signup');
    expect(requests.last.data, {
      'username': 'jean_claude',
      'email': 'jean@example.com',
      'phone_number': '+250781234567',
      'country': 'Rwanda',
      'gender': 'male',
      'password': 'Mpuza@2026',
      'confirm_password': 'Mpuza@2026',
    });

    await provider.login(
      identifier: 'jean_claude',
      password: 'Mpuza@2026',
    );
    expect(requests.last.path, '/api/users/login');
    expect(requests.last.data, {
      'identifier': 'jean_claude',
      'password': 'Mpuza@2026',
    });
    expect(provider.isAuthenticated, isTrue);
    expect(provider.user?.name, 'jean_claude');

    final restored = AuthProvider(dio: _successfulAuthDio([]));
    await restored.restoreSession();
    expect(restored.isInitializing, isFalse);
    expect(restored.isAuthenticated, isTrue);
    expect(restored.accessToken, 'test-token');
    expect(restored.user?.email, 'jean@example.com');
  });

  test('surfaces backend validation errors and clears loading state', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(
            DioException(
              requestOptions: options,
              response: Response<dynamic>(
                requestOptions: options,
                statusCode: 409,
                data: {
                  'error': 'An account with this username already exists.',
                },
              ),
            ),
          );
        },
      ),
    );
    final provider = AuthProvider(dio: dio);

    await expectLater(
      provider.register(
        username: 'taken',
        email: 'jean@example.com',
        phoneNumber: '+250781234567',
        country: 'Rwanda',
        gender: 'male',
        password: 'Mpuza@2026',
        confirmPassword: 'Mpuza@2026',
      ),
      throwsA(
        isA<AuthException>().having(
          (error) => error.message,
          'message',
          'An account with this username already exists.',
        ),
      ),
    );
    expect(provider.isLoading, isFalse);
  });
}

Dio _successfulAuthDio(List<RequestOptions> requests) {
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        requests.add(options);
        handler.resolve(
          Response<dynamic>(
            requestOptions: options,
            statusCode: options.path == '/api/users/signup' ? 201 : 200,
            data: options.path == '/api/users/login'
                ? {
                    'access_token': 'test-token',
                    'token_type': 'Bearer',
                    'expires_in': 3600,
                    'user': {
                      'username': 'jean_claude',
                      'email': 'jean@example.com',
                    },
                  }
                : {
                    'message': 'ok',
                    'expires_in': 937,
                    'resend_in': 83,
                  },
          ),
        );
      },
    ),
  );
  return dio;
}
