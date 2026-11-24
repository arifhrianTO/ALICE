import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

int? _toInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

/// Data pantauan terakhir seorang tunanetra. Semua isian boleh null
/// kalau perangkat belum pernah mengirim datanya.
class MonitoringRecord {
  final String tunanetraId;
  final double? latitude;
  final double? longitude;
  final String? address;
  final int? batteryLevel; // 0..100
  final double? temperature; // derajat Celsius
  final String? lastSeenAt; // 'YYYY-MM-DDTHH:MM:SS'

  const MonitoringRecord({
    required this.tunanetraId,
    this.latitude,
    this.longitude,
    this.address,
    this.batteryLevel,
    this.temperature,
    this.lastSeenAt,
  });

  bool get hasLocation => latitude != null && longitude != null;

  factory MonitoringRecord.fromJson(Map<String, dynamic> j) {
    final address = j['address']?.toString().trim();
    return MonitoringRecord(
      tunanetraId: (j['tunanetra_id'] ?? '').toString(),
      latitude: _toDouble(j['latitude']),
      longitude: _toDouble(j['longitude']),
      address: (address == null || address.isEmpty) ? null : address,
      batteryLevel: _toInt(j['battery_level']),
      temperature: _toDouble(j['temperature']),
      lastSeenAt: j['last_seen_at']?.toString(),
    );
  }
}

class MonitoringService {
  static const _timeout = Duration(seconds: 8);

  static Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('session_token') ?? '';
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  /// GET /api/monitoring/:tunanetra_id
  /// Null kalau datanya tidak ada (404). Error lain dilempar.
  static Future<MonitoringRecord?> fetchStatus(String tunanetraId) async {
    final res = await http
        .get(
          Uri.parse('${ApiConfig.baseUrl}/api/monitoring/$tunanetraId'),
          headers: await _headers(),
        )
        .timeout(_timeout);

    if (res.statusCode == 404) return null;

    Map<String, dynamic> body;
    try {
      final b = jsonDecode(res.body);
      body = b is Map<String, dynamic> ? b : <String, dynamic>{};
    } catch (_) {
      body = <String, dynamic>{};
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(body['message'] ?? 'Gagal (HTTP ${res.statusCode})');
    }

    final data = body['data'];
    if (data is! Map<String, dynamic>) return null;
    return MonitoringRecord.fromJson(data);
  }

  /// PUT /api/monitoring/me  (dipakai aplikasi tunanetra)
  /// Mengirim lokasi dan/atau baterai/suhu milik akun yang sedang login.
  /// Isian null tidak dikirim. Latitude dan longitude harus berpasangan.
  static Future<void> updateMyStatus({
    double? latitude,
    double? longitude,
    String? address,
    int? batteryLevel,
    double? temperature,
  }) async {
    final res = await http
        .put(
          Uri.parse('${ApiConfig.baseUrl}/api/monitoring/me'),
          headers: await _headers(),
          body: jsonEncode({
            if (latitude != null) 'latitude': latitude,
            if (longitude != null) 'longitude': longitude,
            if (address != null) 'address': address,
            if (batteryLevel != null) 'battery_level': batteryLevel,
            if (temperature != null) 'temperature': temperature,
          }),
        )
        .timeout(_timeout);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      String message = 'Gagal (HTTP ${res.statusCode})';
      try {
        final b = jsonDecode(res.body);
        if (b is Map<String, dynamic> && b['message'] != null) {
          message = b['message'].toString();
        }
      } catch (_) {}
      throw Exception(message);
    }
  }
}