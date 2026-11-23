import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

int? _toInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

/// Satu jadwal yang sudah berlaku (tabel `schedule`).
class ScheduleRecord {
  final String id;
  final String tunanetraId;
  final String title;
  final String repeatType; // 'Tidak berulang' | 'Setiap hari' | 'Setiap minggu'
  final String time; // 'HH:MM'
  final String? day; // 'Senin'..'Minggu', boleh null
  final String? startDate; // 'YYYY-MM-DD', null untuk data lama
  final int reminderMinutes; // pengingat sebelum jadwal, default 10

  const ScheduleRecord({
    required this.id,
    required this.tunanetraId,
    required this.title,
    required this.repeatType,
    required this.time,
    this.day,
    this.startDate,
    this.reminderMinutes = 10,
  });

  factory ScheduleRecord.fromJson(Map<String, dynamic> j) => ScheduleRecord(
        id: (j['id'] ?? '').toString(),
        tunanetraId: (j['tunanetra_id'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        repeatType: (j['repeat_type'] ?? '').toString(),
        time: (j['time'] ?? '').toString(),
        day: j['day']?.toString(),
        startDate: j['start_date']?.toString(),
        reminderMinutes: _toInt(j['reminder_minutes']) ?? 10,
      );
}

/// Satu pengajuan dari pendamping (tabel `schedule_request`).
/// Isi title/repeatType/time/day/startDate/reminderMinutes adalah isi
/// jadwal SETELAH perubahan.
class ScheduleRequestRecord {
  final String id;
  final String tunanetraId;
  final String tunanetraName;
  final String companionId;
  final String companionName;
  final String? scheduleId;
  final String action; // 'Tambah' | 'Ubah' | 'Hapus'
  final String status; // 'Menunggu' | 'Disetujui' | 'Ditolak'
  final String? title;
  final String? repeatType;
  final String? time;
  final String? day;
  final String? startDate; // 'YYYY-MM-DD'
  final int? reminderMinutes;

  const ScheduleRequestRecord({
    required this.id,
    required this.tunanetraId,
    required this.tunanetraName,
    required this.companionId,
    required this.companionName,
    required this.action,
    required this.status,
    this.scheduleId,
    this.title,
    this.repeatType,
    this.time,
    this.day,
    this.startDate,
    this.reminderMinutes,
  });

  factory ScheduleRequestRecord.fromJson(Map<String, dynamic> j) =>
      ScheduleRequestRecord(
        id: (j['id'] ?? '').toString(),
        tunanetraId: (j['tunanetra_id'] ?? '').toString(),
        tunanetraName: (j['tunanetra_name'] ?? '').toString(),
        companionId: (j['companion_id'] ?? '').toString(),
        companionName: (j['companion_name'] ?? '').toString(),
        scheduleId: j['schedule_id']?.toString(),
        action: (j['action'] ?? '').toString(),
        status: (j['status'] ?? '').toString(),
        title: j['title']?.toString(),
        repeatType: j['repeat_type']?.toString(),
        time: j['time']?.toString(),
        day: j['day']?.toString(),
        startDate: j['start_date']?.toString(),
        reminderMinutes: _toInt(j['reminder_minutes']),
      );
}

class ScheduleService {
  static const _timeout = Duration(seconds: 8);

  static Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('session_token') ?? '';
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  static Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('${ApiConfig.baseUrl}/api$path')
          .replace(queryParameters: query);

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

  static List<Map<String, dynamic>> _list(Map<String, dynamic> body) {
    final data = body['data'];
    if (data is! List) return const [];
    return data.whereType<Map<String, dynamic>>().toList();
  }

  /// Ubah DateTime menjadi 'YYYY-MM-DD' (tanpa zona waktu, sesuai kolom date).
  static String formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  // -------------------------------------------------------------------
  // Baca
  // -------------------------------------------------------------------

  /// GET /api/schedules
  /// Jadwal yang berlaku. Pendamping mengisi [tunanetraId]; aplikasi
  /// tunanetra boleh mengosongkannya (otomatis jadwal miliknya sendiri).
  static Future<List<ScheduleRecord>> fetchSchedules({
    String? tunanetraId,
  }) async {
    final res = await http
        .get(
          _uri('/schedules',
              tunanetraId == null ? null : {'tunanetra_id': tunanetraId}),
          headers: await _headers(),
        )
        .timeout(_timeout);
    final body = _decode(res);
    _check(res, body);
    return _list(body).map(ScheduleRecord.fromJson).toList();
  }

  /// GET /api/schedule-requests
  /// Riwayat pengajuan milik pendamping (semua status).
  static Future<List<ScheduleRequestRecord>> fetchRequests({
    String? tunanetraId,
  }) async {
    final res = await http
        .get(
          _uri('/schedule-requests',
              tunanetraId == null ? null : {'tunanetra_id': tunanetraId}),
          headers: await _headers(),
        )
        .timeout(_timeout);
    final body = _decode(res);
    _check(res, body);
    return _list(body).map(ScheduleRequestRecord.fromJson).toList();
  }

  /// GET /api/schedule-requests/incoming
  /// Pengajuan yang menunggu jawaban tunanetra yang sedang login.
  static Future<List<ScheduleRequestRecord>> fetchIncoming() async {
    final res = await http
        .get(_uri('/schedule-requests/incoming'), headers: await _headers())
        .timeout(_timeout);
    final body = _decode(res);
    _check(res, body);
    return _list(body).map(ScheduleRequestRecord.fromJson).toList();
  }

  // -------------------------------------------------------------------
  // Tulis
  // -------------------------------------------------------------------

  static Future<void> _submit(Map<String, dynamic> payload) async {
    final res = await http
        .post(
          _uri('/schedule-requests'),
          headers: await _headers(),
          body: jsonEncode(payload),
        )
        .timeout(_timeout);
    _check(res, _decode(res));
  }

  /// Ajukan jadwal baru. Jadwal baru berlaku setelah tunanetra setuju.
  /// [time] berformat 'HH:MM'. [repeatType]: 'Tidak berulang',
  /// 'Setiap hari', atau 'Setiap minggu'.
  /// [startDate] adalah tanggal dari kalender; backend mengisi hari
  /// otomatis dari tanggal ini, jadi [day] tidak perlu dikirim.
  /// Jadwal 'Tidak berulang' wajib punya [startDate].
  static Future<void> submitAdd({
    required String tunanetraId,
    required String title,
    required String time,
    String? repeatType,
    String? day,
    DateTime? startDate,
    int? reminderMinutes,
  }) =>
      _submit({
        'tunanetra_id': tunanetraId,
        'action': 'Tambah',
        'title': title,
        'time': time,
        if (repeatType != null) 'repeat_type': repeatType,
        if (day != null) 'day': day,
        if (startDate != null) 'start_date': formatDate(startDate),
        if (reminderMinutes != null) 'reminder_minutes': reminderMinutes,
      });

  /// Ajukan perubahan jadwal. Isian yang null memakai nilai lama.
  static Future<void> submitEdit({
    required String tunanetraId,
    required String scheduleId,
    String? title,
    String? time,
    String? repeatType,
    String? day,
    DateTime? startDate,
    int? reminderMinutes,
  }) =>
      _submit({
        'tunanetra_id': tunanetraId,
        'action': 'Ubah',
        'schedule_id': scheduleId,
        if (title != null) 'title': title,
        if (time != null) 'time': time,
        if (repeatType != null) 'repeat_type': repeatType,
        if (day != null) 'day': day,
        if (startDate != null) 'start_date': formatDate(startDate),
        if (reminderMinutes != null) 'reminder_minutes': reminderMinutes,
      });

  /// Ajukan penghapusan jadwal.
  static Future<void> submitDelete({
    required String tunanetraId,
    required String scheduleId,
  }) =>
      _submit({
        'tunanetra_id': tunanetraId,
        'action': 'Hapus',
        'schedule_id': scheduleId,
      });

  /// PUT /api/schedule-requests/:id/respond  (dipakai sisi tunanetra)
  static Future<void> respond(String requestId, {required bool accept}) async {
    final res = await http
        .put(
          _uri('/schedule-requests/$requestId/respond'),
          headers: await _headers(),
          body: jsonEncode({'accept': accept}),
        )
        .timeout(_timeout);
    _check(res, _decode(res));
  }

  /// DELETE /api/schedule-requests/:id  (pendamping membatalkan pengajuan
  /// yang masih Menunggu)
  static Future<void> cancelRequest(String requestId) async {
    final res = await http
        .delete(_uri('/schedule-requests/$requestId'),
            headers: await _headers())
        .timeout(_timeout);
    _check(res, _decode(res));
  }
}