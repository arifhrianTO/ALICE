import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api_config.dart';

// =====================================================================
//  DATA PERMINTAAN MASUK (sisi tunanetra)
// =====================================================================
//
// Berbeda dari halaman pendamping, di sini "pihak lain" adalah PENDAMPING
// yang mengajukan tautan. Satu tunanetra bisa punya beberapa permintaan
// "Menunggu" sekaligus, karena itu layanannya mengembalikan daftar.

/// Satu permintaan tautan yang masuk ke tunanetra yang sedang login.
class IncomingRequest {
  final String id; // request_id, dipakai untuk menjawab (respond)
  final String companionId;
  final String companionName;
  final String companionEmail;
  final String status;

  const IncomingRequest({
    required this.id,
    required this.companionId,
    required this.companionName,
    required this.companionEmail,
    required this.status,
  });

  factory IncomingRequest.fromJson(Map<String, dynamic> json) {
    return IncomingRequest(
      id: json['id'] as String? ?? '',
      companionId: json['companion_id'] as String? ?? '',
      companionName: json['companion_name'] as String? ?? '',
      companionEmail: json['companion_email'] as String? ?? '',
      status: json['status'] as String? ?? '',
    );
  }
}

// =====================================================================
//  MENAFSIRKAN JAWABAN SUARA (setuju / tolak)
// =====================================================================
//
// Dipakai halaman suara tunanetra untuk memahami ucapan saat menjawab
// dialog permintaan tautan. Dibuat sebagai fungsi murni agar mudah diuji.

/// Kata yang dibaca sebagai "menerima".
const List<String> requestAcceptWords = [
  'setuju',
  'terima',
  'ya',
  'iya',
  'boleh',
  'mau',
  'siap',
  'oke',
  'ok',
  'benar',
  'betul',
  'yakin',
];

/// Kata yang dibaca sebagai "menolak".
const List<String> requestRejectWords = [
  'tolak',
  'tidak',
  'tak',
  'nggak',
  'gak',
  'enggak',
  'ngga',
  'bukan',
  'batal',
  'jangan',
];

/// Normalisasi ucapan: huruf kecil, tanda baca jadi spasi, spasi dirapatkan.
String _normalizeSpeech(String text) {
  return text
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Apakah [word] muncul sebagai kata utuh di dalam [normalized]?
///
/// Pencocokan per kata mencegah salah tafsir yang berbahaya, misalnya
/// "saya" atau "banyak" ikut dianggap mengandung kata "ya".
bool _hasWholeWord(String normalized, String word) {
  final pattern = RegExp('(^| )${RegExp.escape(word)}( |\$)');
  return pattern.hasMatch(normalized);
}

/// Menerjemahkan ucapan menjadi pilihan.
///
/// Mengembalikan `true` kalau menerima, `false` kalau menolak, dan `null`
/// kalau tidak dikenali. Kata penolakan diperiksa lebih dahulu supaya
/// ucapan seperti "tidak setuju" dibaca sebagai penolakan.
///
/// Pencocokan dilakukan per kata utuh, bukan sekadar "terkandung", supaya
/// gema suara aplikasi sendiri (misalnya "...saya belum paham...") tidak
/// ikut dibaca sebagai jawaban.
bool? parseRequestDecision(String text) {
  final normalized = _normalizeSpeech(text);
  if (normalized.isEmpty) return null;
  if (requestRejectWords.any((word) => _hasWholeWord(normalized, word))) {
    return false;
  }
  if (requestAcceptWords.any((word) => _hasWholeWord(normalized, word))) {
    return true;
  }
  return null;
}

/// Mengambil id pengajuan dari data sebuah notifikasi push.
///
/// Backend mengirim notifikasi dengan bagian data seperti:
///   `{ "type": "connection_request", "request_id": "<id>" }`
///
/// Mengembalikan id-nya, atau null kalau notifikasi ini bukan pengajuan
/// tautan (misalnya jenis pesan lain) atau id-nya kosong. Dipisah sebagai
/// fungsi murni supaya bisa diuji tanpa perlu Firebase.
String? requestIdFromNotification(Map<String, dynamic> data) {
  if (data['type'] != 'connection_request') return null;
  final id = data['request_id'];
  if (id is! String || id.isEmpty) return null;
  return id;
}

/// Kesalahan saat mengirim jawaban permintaan tautan.
///
/// [gone] bernilai true kalau pengajuan sudah tidak berlaku (HTTP 404) —
/// misalnya sudah dijawab atau dibatalkan pendamping. Dalam kasus itu
/// dialog sebaiknya ditutup, bukan dicoba ulang.
class RequestRespondException implements Exception {
  final String message;
  final bool gone;

  const RequestRespondException(this.message, {this.gone = false});

  @override
  String toString() => message;
}

/// Layanan permintaan masuk dari backend (sisi tunanetra).
class IncomingRequestService {
  /// Mengambil permintaan "Menunggu" milik tunanetra yang sedang login dari
  /// `GET /api/requests/incoming`.
  ///
  /// Melempar [Exception] kalau gagal, supaya pemanggil bisa memutuskan
  /// untuk mencatat/diamkan tanpa membuat aplikasi berhenti.
  static Future<List<IncomingRequest>> fetchIncoming({
    http.Client? client,
  }) async {
    final token = await _token();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/requests/incoming');
    final response = await (client ?? http.Client())
        .get(
          url,
          headers: {if (token.isNotEmpty) 'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 401) {
      throw Exception('Sesi berakhir');
    }
    if (response.statusCode != 200) {
      throw Exception('Gagal memuat permintaan (HTTP ${response.statusCode})');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>? ?? const [];
    return data
        .map((item) => IncomingRequest.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Mengirim jawaban tunanetra untuk satu pengajuan lewat
  /// `PUT /api/requests/:id/respond`.
  ///
  /// [accept] true = menerima (status menjadi "Terhubung"), false = menolak
  /// (status menjadi "Ditolak"). Melempar [RequestRespondException] kalau
  /// gagal, dengan [RequestRespondException.gone] true bila pengajuan sudah
  /// tidak berlaku lagi (HTTP 404).
  static Future<void> respond(
    String requestId, {
    required bool accept,
    http.Client? client,
  }) async {
    final token = await _token();
    final url = Uri.parse(
      '${ApiConfig.baseUrl}/api/requests/$requestId/respond',
    );
    final response = await (client ?? http.Client())
        .put(
          url,
          headers: {
            'Content-Type': 'application/json',
            if (token.isNotEmpty) 'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'accept': accept}),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) return;
    if (response.statusCode == 404) {
      throw const RequestRespondException(
        'Pengajuan ini sudah tidak berlaku.',
        gone: true,
      );
    }
    if (response.statusCode == 401) {
      throw const RequestRespondException(
        'Sesi Anda berakhir. Silakan masuk lagi.',
      );
    }
    throw const RequestRespondException('Gagal mengirim jawaban.');
  }

  /// Mengambil token sesi yang tersimpan di perangkat.
  static Future<String> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('session_token') ?? '';
  }
}
