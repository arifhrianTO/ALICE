import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_config.dart';

/// Pengurus push notification (Firebase Cloud Messaging).
///
/// Tugasnya cuma tiga:
///  1. minta izin notifikasi ke sistem operasi
///  2. ambil token perangkat dari Firebase
///  3. kirim token itu ke backend supaya server bisa mengirim pesan
///
/// Semua kegagalan ditangkap dan dicatat, TIDAK dilempar ke atas. Fitur
/// notifikasi adalah tambahan: kalau gagal (misalnya HP tanpa Google Play
/// Services), login dan halaman lain tetap harus jalan.
class NotificationService {
  NotificationService._();

  static bool _ready = false;

  /// Dipanggil sekali saat aplikasi mulai.
  static Future<void> init() async {
    // Web & desktop belum didukung. Firebase di web juga menuntut
    // konfigurasi tambahan yang belum disiapkan.
    if (kIsWeb ||
        !(defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      return;
    }

    try {
      await Firebase.initializeApp();

      // Di Android 13+ dan iOS, izin notifikasi harus diminta eksplisit.
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      _ready = true;

      // Token bisa berubah kapan saja (reinstall, pembersihan data,
      // Firebase memperbarui sendiri). Setiap perubahan dikirim ulang.
      //
      // getToken/onTokenRefresh ditandai deprecated oleh paket ini dan
      // digantikan register/onRegistered. Pengganti itu memberi Firebase
      // Installation ID, sedangkan backend Go memakai FCM registration
      // token. Jadi untuk saat ini API lama tetap dipakai.
      // ignore: deprecated_member_use
      FirebaseMessaging.instance.onTokenRefresh.listen(_sendToBackend);
    } catch (e) {
      debugPrint('[notifikasi] inisialisasi gagal: $e');
    }
  }

  /// Mendaftarkan perangkat yang sedang dipakai ke akun yang sedang login.
  ///
  /// Dipanggil SETELAH login berhasil, karena backend butuh token sesi
  /// untuk tahu token perangkat ini milik siapa.
  static Future<void> registerCurrentDevice() async {
    if (!_ready) return;
    try {
      // ignore: deprecated_member_use
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _sendToBackend(token);
    } catch (e) {
      debugPrint('[notifikasi] ambil token gagal: $e');
    }
  }

  /// Menghapus token perangkat saat logout.
  ///
  /// Tanpa langkah ini, HP yang sudah keluar akun tetap menerima
  /// notifikasi atas nama akun lama.
  static Future<void> unregisterCurrentDevice() async {
    if (!_ready) return;
    try {
      // ignore: deprecated_member_use
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;

      final prefs = await SharedPreferences.getInstance();
      final sessionToken = prefs.getString('session_token') ?? '';
      if (sessionToken.isEmpty) return;

      await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/api/device-tokens'),
        headers: {
          'Authorization': 'Bearer $sessionToken',
          'Content-Type': 'application/json',
        },
        body: '{"token":"$token"}',
      );
    } catch (e) {
      debugPrint('[notifikasi] hapus token gagal: $e');
    }
  }

  static Future<void> _sendToBackend(String token) async {
    final prefs = await SharedPreferences.getInstance();
    final sessionToken = prefs.getString('session_token') ?? '';

    // Belum login: tidak ada pemilik token. Nanti didaftarkan lagi lewat
    // registerCurrentDevice() setelah login.
    if (sessionToken.isEmpty) return;

    final platform =
        defaultTargetPlatform == TargetPlatform.android ? 'android' : 'ios';

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/device-tokens'),
      headers: {
        'Authorization': 'Bearer $sessionToken',
        'Content-Type': 'application/json',
      },
      body: '{"token":"$token","platform":"$platform"}',
    );

    if (response.statusCode != 200) {
      debugPrint(
        '[notifikasi] simpan token gagal (${response.statusCode}): ${response.body}',
      );
    }
  }
}