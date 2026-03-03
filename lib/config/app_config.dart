import 'package:flutter/foundation.dart';

class AppConfig {
  static String get apiBaseUrl {
    if (kIsWeb) {
      return 'http://localhost:8080';
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      // Android emulator maps host localhost to 10.0.2.2.
      return 'http://10.0.2.2:8080';
    }

    return 'http://localhost:8080';
  }

  static const Duration requestTimeout = Duration(seconds: 8);
  static const Duration pollInterval = Duration(seconds: 3);
  static const Duration presenceInterval = Duration(seconds: 10);
  static const Duration usersRefreshInterval = Duration(seconds: 12);
}
