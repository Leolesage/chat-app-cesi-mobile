import 'package:flutter/foundation.dart';

class AppConfig {
  static const String _apiBaseUrlOverride = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String get apiBaseUrl {
    if (_apiBaseUrlOverride.isNotEmpty) {
      return _apiBaseUrlOverride;
    }

    if (kIsWeb) {
      return 'http://localhost:8080';
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      // Physical devices on the same network must target the host LAN IP.
      // Override at build/run time:
      // flutter run --dart-define=API_BASE_URL=http://<HOST_IP>:8080
      return 'http://10.176.130.138:8080';
    }

    return 'http://localhost:8080';
  }

  static const Duration requestTimeout = Duration(seconds: 8);
  static const Duration pollInterval = Duration(seconds: 3);
  static const Duration presenceInterval = Duration(seconds: 10);
  static const Duration usersRefreshInterval = Duration(seconds: 12);
}
