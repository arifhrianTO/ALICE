import 'package:flutter/foundation.dart';

class ApiConfig {
  /// Facebook App ID (App Settings > Basic di Meta Developer Console).
  /// Nilai ini BUKAN rahasia, jadi aman disimpan di kode.
  static const String facebookAppId = '1615961146947500';

  /// Base URL API backend.
  ///
  /// Urutan prioritas:
  /// 1. `--dart-define=API_BASE_URL=http://...` (menimpa semuanya)
  /// 2. Web/desktop: localhost
  /// 3. Emulator Android: 10.0.2.2 (alamat host dari dalam emulator)
  ///
  /// Untuk HP fisik Android, jalankan `adb reverse tcp:8080 tcp:8080`
  /// lalu pakai `--dart-define=API_BASE_URL=http://localhost:8080`, atau
  /// arahkan ke IP laptop di jaringan yang sama.
  static String get baseUrl {
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) return override;

    if (kIsWeb) return 'http://localhost:8080';

    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }

    return 'http://localhost:8080';
  }
}
