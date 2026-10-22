import 'package:flutter/foundation.dart';

class ApiConfig {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8080';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      // 10.0.2.2 merujuk ke localhost komputer host pada emulator Android
      return 'http://10.0.2.2:8080';
    }
    return 'http://localhost:8080';
  }
}
