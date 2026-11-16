import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:translation_platform/core/network/api_client.dart';

void main() {
  test('uses the signed-in AuthProvider token for API requests', () async {
    SharedPreferences.setMockInitialValues({
      'auth_access_token': 'signed-in-token',
      'auth_token_expiry':
          DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch,
    });

    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000/api/v1/'));
    final apiClient = ApiClient(dio: dio);
    String? authorizationHeader;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          authorizationHeader = options.headers['Authorization'] as String?;
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: <String, dynamic>{},
            ),
          );
        },
      ),
    );

    try {
      await apiClient.dio.post<dynamic>(
        'translate_text/',
        data: <String, dynamic>{},
      );
      expect(authorizationHeader, 'Bearer signed-in-token');
    } finally {
      apiClient.dispose();
    }
  });
}
