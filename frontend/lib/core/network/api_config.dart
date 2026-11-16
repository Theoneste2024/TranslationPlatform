import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String _configuredBaseUrl =
      String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_configuredBaseUrl.isNotEmpty) {
      return _configuredBaseUrl;
    }

    if (kIsWeb) {
      final host = Uri.base.host;
      if (host.isNotEmpty && host != 'localhost' && host != '127.0.0.1') {
        return '${Uri.base.scheme}://$host:8000/api/v1';
      }
      return 'http://127.0.0.1:8000/api/v1';
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000/api/v1';
    }

    return 'http://127.0.0.1:8000/api/v1';
  }

  static String get dioBaseUrl =>
      '${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/';

  static Uri endpoint(String path) {
    final base = baseUrl.replaceFirst(RegExp(r'/+$'), '');
    final endpointPath = path.replaceFirst(RegExp(r'^/+'), '');
    return Uri.parse('$base/$endpointPath');
  }
}
