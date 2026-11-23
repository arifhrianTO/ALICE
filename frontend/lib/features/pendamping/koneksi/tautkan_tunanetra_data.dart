import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api_config.dart';

// =====================================================================
//  DATA TUNANETRA
// =====================================================================

/// Calon tunanetra yang bisa ditautkan ke pendamping.
class Tunanetra {
  final String id;
  final String name;
  final String email;

  const Tunanetra({
    required this.id,
    required this.name,
    required this.email,
  });

  factory Tunanetra.fromJson(Map<String, dynamic> json) {
    return Tunanetra(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
    );
  }
}

/// Kesalahan saat memuat daftar tunanetra. Pesannya sudah siap ditampilkan.
///
/// [unauthorized] bernilai true kalau sesi tidak ada / sudah kedaluwarsa,
/// supaya halaman bisa menampilkan pesan khusus "login ulang".
class TunanetraException implements Exception {
  final String message;
  final bool unauthorized;

  TunanetraException(this.message, {this.unauthorized = false});

  @override
  String toString() => message;
}

/// Service pengambilan daftar tunanetra dari backend.
class TunanetraService {
  /// Mengambil semua akun tunanetra asli dari `GET /api/tunanetra/accounts`.
  ///
  /// Endpoint ini WAJIB menyertakan token sesi (`session_token`), karena
  /// backend hanya mengizinkan pengguna yang sudah login. Token itu sudah
  /// tersimpan otomatis saat pendamping login lewat email atau Google.
  static Future<List<Tunanetra>> fetchAll() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('session_token') ?? '';

    final url = Uri.parse('${ApiConfig.baseUrl}/api/tunanetra/accounts');
    final response = await http.get(
      url,
      headers: {
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 401) {
      throw TunanetraException(
        'Sesi Anda berakhir. Silakan login ulang.',
        unauthorized: true,
      );
    }
    if (response.statusCode != 200) {
      throw TunanetraException(
        'Gagal memuat daftar tunanetra (${response.statusCode}).',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>? ?? const [];
    return data
        .map((item) => Tunanetra.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
