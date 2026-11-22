import 'package:flutter/foundation.dart';

class ApiConfig {
  static const _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_configuredBaseUrl.isNotEmpty) {
      final uri = Uri.parse(_configuredBaseUrl);
      return Uri(
        scheme: uri.scheme,
        userInfo: uri.userInfo,
        host: uri.host,
        port: uri.hasPort ? uri.port : null,
      ).toString();
    }

    final host = kIsWeb
        ? (Uri.base.host.isEmpty ? '127.0.0.1' : Uri.base.host)
        : defaultTargetPlatform == TargetPlatform.android
            ? '10.0.2.2'
            : '127.0.0.1';
    return 'http://$host:8000';
  }
}
