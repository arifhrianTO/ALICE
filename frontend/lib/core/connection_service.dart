import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_config.dart';

/// Satu baris koneksi (tabel `request`) milik pendamping yang login.
///
/// Dipakai lintas fitur — misalnya halaman Jadwal memakainya untuk memilih
/// tunanetra yang sudah "Terhubung". Halaman "Terhubung" sendiri memakai
/// `features/pendamping/koneksi/koneksi_data.dart`.
class ConnectionRecord {
  final String id; // request_id
  final String tunanetraId;
  final String name;
  final String email;
  final String status; // 'Menunggu' | 'Terhubung' | 'Ditolak'

  const ConnectionRecord({
    required this.id,
    required this.tunanetraId,
    required this.name,
    required this.email,
    required this.status,
  });

  // Parsing dibuat toleran terhadap beberapa kemungkinan nama field,
  // supaya tidak crash kalau nama di backend sedikit berbeda.
  factory ConnectionRecord.fromJson(Map<String, dynamic> j) {
    String pick(List<String> keys) {
      for (final k in keys) {
        final v = j[k];
        if (v != null) return v.toString();
      }
      return '';
    }

    return ConnectionRecord(
      id: pick(['request_id', 'id']),
      tunanetraId: pick(['visually_impaired_id', 'tunanetra_id', 'user_id']),
      name: pick(['name', 'tunanetra_name', 'visually_impaired_name']),
      email: pick(['email', 'tunanetra_email']),
      status: pick(['status']),
    );
  }
}

/// Pembacaan daftar pengajuan tautan milik pendamping yang login.
class ConnectionService {
  static Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('session_token') ?? '';
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  static Map<String, dynamic> _decode(http.Response res) {
    try {
      final b = jsonDecode(res.body);
      return b is Map<String, dynamic> ? b : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static void _check(http.Response res, Map<String, dynamic> body) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(body['message'] ?? 'Gagal (HTTP ${res.statusCode})');
    }
  }

  /// GET /api/requests
  ///
  /// Endpoint lama `/api/connections` sudah tidak dipakai; backend kini
  /// memakai `/api/requests`.
  static Future<List<ConnectionRecord>> fetchConnections() async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/requests');
    final res = await http
        .get(uri, headers: await _headers())
        .timeout(const Duration(seconds: 8));
    final body = _decode(res);
    _check(res, body);
    final data = (body['data'] as List<dynamic>?) ?? const [];
    return data
        .map((e) => ConnectionRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
