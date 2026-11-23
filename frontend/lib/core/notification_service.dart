import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_config.dart';

/// Pengurus push notification (Firebase Cloud Messaging).
///
/// Tugasnya empat:
///  1. minta izin notifikasi ke sistem operasi
///  2. ambil token perangkat dari Firebase
///  3. kirim token itu ke backend supaya server bisa mengirim pesan
///  4. teruskan pesan yang masuk ke bagian aplikasi yang peduli
///
/// Semua kegagalan ditangkap dan dicatat, TIDAK dilempar ke atas. Fitur
/// notifikasi adalah tambahan: kalau gagal (misalnya HP tanpa Google Play
/// Services), login dan halaman lain tetap harus jalan.
class NotificationService {
  NotificationService._();

  static bool _ready = false;

  /// Aliran data notifikasi yang datang selagi aplikasi hidup.
  ///
  /// Isinya hanya bagian `data` (bukan judul/isi tampilan), karena data
  /// inilah yang membawa penanda jenis pesan dan id terkait. Halaman yang
  /// peduli — misalnya halaman suara tunanetra — mendengarkan aliran ini
  /// supaya bisa langsung bereaksi begitu pesan tiba.
  static final StreamController<Map<String, String>> _messagesController =
      StreamController<Map<String, String>>.broadcast();

  static Stream<Map<String, String>> get messages => _messagesController.stream;

  /// Data notifikasi yang MEMBUKA aplikasi dari kondisi benar-benar tertutup.
  ///
  /// Disimpan sementara karena saat itu halaman tujuan belum dibangun, jadi
  /// belum ada yang mendengarkan aliran [messages]. Halaman yang siap
  /// memanggil [consumePendingMessage] untuk mengambilnya.
  static Map<String, String>? _pendingMessage;

  /// Mengambil (sekali) data notifikasi yang menunggu, lalu mengosongkannya
  /// supaya tidak diproses dua kali. Mengembalikan null kalau tidak ada.
  static Map<String, String>? consumePendingMessage() {
    final pending = _pendingMessage;
    _pendingMessage = null;
    return pending;
  }

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

      // (a) Pesan yang tiba selagi aplikasi di depan.
      //
      // FCM TIDAK menampilkan apa pun sendiri di mode ini; kalau tidak
      // didengarkan, pesannya hilang tanpa jejak. Di sini pesannya
      // diteruskan ke halaman suara tunanetra.
      FirebaseMessaging.onMessage.listen(_handleIncoming);

      // (b) Pesan yang diketuk dari bilah notifikasi saat aplikasi masih
      // hidup di latar belakang. Aplikasi dilanjutkan, lalu pesannya
      // diteruskan seperti di atas.
      FirebaseMessaging.onMessageOpenedApp.listen(_handleIncoming);

      // (c) Pesan yang MEMBUKA aplikasi dari kondisi tertutup total.
      // getInitialMessage() mengembalikan pesan itu satu kali saja.
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        _pendingMessage = Map<String, String>.from(initial.data);
        _handleIncoming(initial);
      }
    } catch (e) {
      debugPrint('[notifikasi] inisialisasi gagal: $e');
    }
  }

  /// Meneruskan data satu pesan yang masuk ke para pendengar.
  ///
  /// Nilai data FCM selalu berupa teks, jadi konversinya aman.
  static void _handleIncoming(RemoteMessage message) {
    final data = Map<String, String>.from(message.data);
    debugPrint('[notifikasi] pesan masuk: $data');
    _messagesController.add(data);
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