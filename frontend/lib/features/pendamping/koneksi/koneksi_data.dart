import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api_config.dart';

// =====================================================================
//  DATA PENGAJUAN TAUTAN (halaman "Terhubung")
// =====================================================================

/// Status pengajuan tautan.
///
/// Nilai di sini adalah padanan dari enum `request_status` di backend
/// ('Menunggu', 'Terhubung', 'Ditolak'), tapi sudah diubah menjadi bentuk
/// Dart-friendly supaya mudah dipakai di UI.
enum ConnectionStatus { terhubung, menunggu, ditolak }

/// Mengubah teks status dari backend menjadi [ConnectionStatus].
///
/// Nilai yang tidak dikenal dianggap "menunggu" supaya kartu tetap
/// tampil, tidak hilang.
ConnectionStatus connectionStatusFrom(String raw) {
  switch (raw.toLowerCase()) {
    case 'terhubung':
      return ConnectionStatus.terhubung;
    case 'ditolak':
      return ConnectionStatus.ditolak;
    case 'menunggu':
    default:
      return ConnectionStatus.menunggu;
  }
}

/// Satu pengajuan tautan antara pendamping (yang login) dan seorang
/// tunanetra, lengkap dengan statusnya.
class ConnectionRequest {
  final String id;
  final String visuallyImpairedId;
  final String name;
  final String email;
  final ConnectionStatus status;

  const ConnectionRequest({
    required this.id,
    required this.visuallyImpairedId,
    required this.name,
    required this.email,
    required this.status,
  });

  factory ConnectionRequest.fromJson(Map<String, dynamic> json) {
    return ConnectionRequest(
      id: json['id'] as String? ?? '',
      visuallyImpairedId: json['visually_impaired_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      status: connectionStatusFrom(json['status'] as String? ?? ''),
    );
  }
}

/// Kesalahan saat memuat/mengubah pengajuan tautan. Pesannya sudah siap
/// ditampilkan ke pengguna.
///
/// [unauthorized] bernilai true kalau sesi tidak ada / sudah kedaluwarsa,
/// supaya halaman bisa menampilkan pesan khusus "login ulang".
class ConnectionException implements Exception {
  final String message;
  final bool unauthorized;

  ConnectionException(this.message, {this.unauthorized = false});

  @override
  String toString() => message;
}

/// Service pengajuan tautan ke backend.
class ConnectionService {
  /// Mengambil semua pengajuan milik pendamping yang sedang login dari
  /// `GET /api/requests`.
  static Future<List<ConnectionRequest>> fetchAll() async {
    final response = await _send('GET', '/api/requests');

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>? ?? const [];
    return data
        .map((item) => ConnectionRequest.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Mengirim pengajuan tautan baru ke seorang tunanetra.
  ///
  /// `POST /api/requests` dengan badan `{ "visually_impaired_id": "..." }`.
  static Future<ConnectionRequest> create(String visuallyImpairedId) async {
    final response = await _send(
      'POST',
      '/api/requests',
      body: {'visually_impaired_id': visuallyImpairedId},
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>? ?? const {};
    return ConnectionRequest.fromJson(data);
  }

  /// Menghapus satu pengajuan: membatalkan yang "Menunggu" atau memutus
  /// yang "Terhubung".
  ///
  /// `DELETE /api/requests/{id}`.
  static Future<void> remove(String id) async {
    await _send('DELETE', '/api/requests/$id');
  }

  /// Mengirim permintaan HTTP dengan token sesi, lalu menerjemahkan kode
  /// status yang gagal menjadi [ConnectionException] yang ramah-pengguna.
  static Future<http.Response> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('session_token') ?? '';

    final url = Uri.parse('${ApiConfig.baseUrl}$path');
    final headers = <String, String>{
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      if (body != null) 'Content-Type': 'application/json',
    };

    late final http.Response response;
    switch (method) {
      case 'POST':
        response = await http
            .post(url, headers: headers, body: jsonEncode(body))
            .timeout(const Duration(seconds: 10));
        break;
      case 'DELETE':
        response = await http
            .delete(url, headers: headers)
            .timeout(const Duration(seconds: 10));
        break;
      default:
        response = await http
            .get(url, headers: headers)
            .timeout(const Duration(seconds: 10));
    }

    if (response.statusCode == 401) {
      throw ConnectionException(
        'Sesi Anda berakhir. Silakan login ulang.',
        unauthorized: true,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ConnectionException(_errorMessage(response));
    }

    return response;
  }

  /// Mengambil pesan `message` dari balasan JSON kalau ada.
  static String _errorMessage(http.Response response) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final message = body['message'] as String?;
      if (message != null && message.isNotEmpty) return message;
    } catch (_) {
      // Balasan bukan JSON; pakai pesan umum di bawah.
    }
    return 'Gagal menghubungi server (${response.statusCode}).';
  }
}
