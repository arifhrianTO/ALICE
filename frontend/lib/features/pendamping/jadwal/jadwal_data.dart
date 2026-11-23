import 'package:material_ui/material_ui.dart';

import '../../../core/connection_service.dart';
import '../../../core/schedule_service.dart';

// =====================================================================
// HELPER TANGGAL & WAKTU
// =====================================================================

/// Jumlah hari pada strip tanggal di halaman Jadwal.
const int kStripDays = 7;

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String formatTime(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

const dayAbbr = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

const dayFull = [
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  'Jumat',
  'Sabtu',
  'Minggu',
];

const monthAbbr = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

/// Tanggal awal yang dipilih di halaman Jadwal.
DateTime initialDate() {
  final now = DateTime.now();

  return dateOnly(
    now.weekday > kStripDays ? now.add(Duration(days: 8 - now.weekday)) : now,
  );
}

/// Tanggal terdekat yang jatuh pada hari tertentu.
DateTime nextWeekday(int weekday) {
  final today = dateOnly(DateTime.now());
  final diff = (weekday - today.weekday + 7) % 7;

  return DateTime(today.year, today.month, today.day + diff);
}

// =====================================================================
// MODEL JADWAL
// =====================================================================

enum RepeatType { once, weekday, daily, weekly }

enum ScheduleStatus { approved, pending, rejected }

extension RepeatTypeX on RepeatType {
  String dropdownLabel(int weekday) {
    switch (this) {
      case RepeatType.once:
        return 'Sekali saja';

      case RepeatType.weekday:
        return 'Tiap hari ${dayFull[weekday - 1]}';

      case RepeatType.daily:
        return 'Setiap hari';

      case RepeatType.weekly:
        return 'Tiap minggu';
    }
  }

  bool get isRepeating => this != RepeatType.once;

  /// Label yang dipakai di database (enum repeat_type).
  /// weekday dan weekly sama-sama "Setiap minggu".
  String get dbLabel {
    switch (this) {
      case RepeatType.once:
        return 'Tidak berulang';

      case RepeatType.daily:
        return 'Setiap hari';

      case RepeatType.weekday:
      case RepeatType.weekly:
        return 'Setiap minggu';
    }
  }

  static RepeatType fromDb(String? label) {
    switch (label) {
      case 'Setiap hari':
        return RepeatType.daily;

      case 'Setiap minggu':
        return RepeatType.weekday;

      default:
        return RepeatType.once;
    }
  }
}

extension ScheduleStatusX on ScheduleStatus {
  String get label {
    switch (this) {
      case ScheduleStatus.approved:
        return 'Disetujui';

      case ScheduleStatus.pending:
        return 'Menunggu';

      case ScheduleStatus.rejected:
        return 'Ditolak';
    }
  }
}

// =====================================================================
// CLASS SCHEDULE
// =====================================================================

class Schedule {
  /// Jadwal Disetujui: schedule_id.
  /// Menunggu / Ditolak: schedule_request_id.
  final String id;
  final String title;
  final TimeOfDay time;
  final RepeatType repeat;

  /// Tanggal mulai jadwal.
  /// Sekali saja = tanggal tertentu.
  /// Pengulangan = tanggal acuan pengulangan.
  final DateTime date;

  final int reminderMinutes;
  final ScheduleStatus status;
  final String createdBy;

  /// Hanya untuk pengajuan (Menunggu / Ditolak):
  /// jadwal yang diubah atau dihapus, dan jenis aksinya.
  final String? scheduleId;
  final String? action; // 'Tambah' | 'Ubah' | 'Hapus'

  const Schedule({
    required this.id,
    required this.title,
    required this.time,
    required this.repeat,
    required this.date,
    required this.reminderMinutes,
    required this.status,
    required this.createdBy,
    this.scheduleId,
    this.action,
  });

  int get minutes => time.hour * 60 + time.minute;

  /// Jam pengingat.
  String get reminderTime {
    final m = (minutes - reminderMinutes) % 1440;

    return formatTime(TimeOfDay(hour: m ~/ 60, minute: m % 60));
  }

  /// Label pengulangan pada kartu jadwal.
  String get repeatLabel {
    switch (repeat) {
      case RepeatType.once:
        return 'Sekali Saja';

      case RepeatType.weekday:
        return 'Tiap ${dayFull[date.weekday - 1]}';

      case RepeatType.daily:
        return 'Tiap Hari';

      case RepeatType.weekly:
        return 'Tiap Minggu';
    }
  }

  /// Memeriksa apakah jadwal berlangsung pada tanggal tertentu.
  bool occursOn(DateTime day) {
    final d = dateOnly(day);
    final start = dateOnly(date);

    if (d.isBefore(start)) return false;

    switch (repeat) {
      case RepeatType.once:
        return d == start;

      case RepeatType.daily:
        return true;

      case RepeatType.weekday:
      case RepeatType.weekly:
        return d.weekday == start.weekday;
    }
  }

  Schedule copyWith({
    String? title,
    TimeOfDay? time,
    RepeatType? repeat,
    DateTime? date,
    ScheduleStatus? status,
  }) {
    return Schedule(
      id: id,
      title: title ?? this.title,
      time: time ?? this.time,
      repeat: repeat ?? this.repeat,
      date: date ?? this.date,
      reminderMinutes: reminderMinutes,
      status: status ?? this.status,
      createdBy: createdBy,
      scheduleId: scheduleId,
      action: action,
    );
  }
}

// =====================================================================
// KONVERSI DATA API -> MODEL APLIKASI
// =====================================================================

TimeOfDay _parseTime(String? s) {
  final p = (s ?? '').split(':');
  if (p.length < 2) return const TimeOfDay(hour: 0, minute: 0);

  return TimeOfDay(
    hour: int.tryParse(p[0]) ?? 0,
    minute: int.tryParse(p[1]) ?? 0,
  );
}

/// Tanggal mulai dari server. Data lama bisa kosong; kalau begitu dipakai
/// tanggal di masa lalu yang hari mingguannya cocok, supaya jadwal tetap
/// muncul di hari yang benar.
DateTime _parseStartDate(String? iso, String? day) {
  final parsed = iso == null ? null : DateTime.tryParse(iso);
  if (parsed != null) return dateOnly(parsed);

  final idx = day == null ? -1 : dayFull.indexOf(day);
  final today = dateOnly(DateTime.now());
  if (idx < 0) return today;

  final next = nextWeekday(idx + 1);
  return DateTime(next.year, next.month, next.day - 7);
}

Schedule _fromSchedule(ScheduleRecord r) => Schedule(
  id: r.id,
  title: r.title,
  time: _parseTime(r.time),
  repeat: RepeatTypeX.fromDb(r.repeatType),
  date: _parseStartDate(r.startDate, r.day),
  reminderMinutes: r.reminderMinutes,
  status: ScheduleStatus.approved,
  createdBy: 'Pendamping',
);

Schedule _fromRequest(ScheduleRequestRecord r) => Schedule(
  id: r.id,
  title: r.title ?? '',
  time: _parseTime(r.time),
  repeat: RepeatTypeX.fromDb(r.repeatType),
  date: _parseStartDate(r.startDate, r.day),
  reminderMinutes: r.reminderMinutes ?? 10,
  status: r.status == 'Ditolak'
      ? ScheduleStatus.rejected
      : ScheduleStatus.pending,
  createdBy: 'Anda',
  scheduleId: r.scheduleId,
  action: r.action,
);

String _msg(Object e) {
  final text = e.toString();
  const prefix = 'Exception: ';
  final msg = text.startsWith(prefix) ? text.substring(prefix.length) : text;

  if (msg.contains('SocketException') ||
      msg.contains('TimeoutException') ||
      msg.contains('ClientException')) {
    return 'Gagal menghubungi server';
  }
  return msg;
}

// =====================================================================
// STORE JADWAL
// =====================================================================

class ScheduleStore extends ChangeNotifier {
  final List<Schedule> _items = [];

  /// Semua tunanetra yang berstatus Terhubung dengan pendamping yang login.
  final List<ConnectionRecord> _connected = [];

  /// Tunanetra yang jadwalnya sedang ditampilkan (salah satu dari
  /// [_connected]). Default: yang pertama.
  String? _tunanetraId;

  bool _loading = false;
  bool _loaded = false;
  String? _error;

  /// Sedang memuat dari server.
  bool get loading => _loading;

  /// Sudah pernah berhasil dimuat.
  bool get loaded => _loaded;

  /// Pesan error pemuatan terakhir, null kalau berhasil.
  String? get error => _error;

  /// Ada tunanetra yang terhubung (setelah load).
  bool get hasConnection => _tunanetraId != null;

  /// Daftar tunanetra yang terhubung, untuk dropdown pilihan.
  List<ConnectionRecord> get connectedTunanetra =>
      List.unmodifiable(_connected);

  /// Tunanetra yang sedang dipilih, null kalau belum ada yang terhubung.
  ConnectionRecord? get selectedTunanetra {
    for (final c in _connected) {
      if (c.tunanetraId == _tunanetraId) return c;
    }
    return null;
  }

  /// Ganti tunanetra yang ditampilkan, lalu muat ulang jadwalnya.
  Future<void> selectTunanetra(String tunanetraId) async {
    if (tunanetraId == _tunanetraId) return;
    if (!_connected.any((c) => c.tunanetraId == tunanetraId)) return;

    _tunanetraId = tunanetraId;
    _items.clear();
    await load(refreshConnections: false);
  }

  /// Kosongkan semua jadwal. Dipakai saat logout / berganti akun agar
  /// jadwal pengguna sebelumnya tidak terlihat oleh pengguna berikutnya.
  void reset() {
    _items.clear();
    _connected.clear();
    _tunanetraId = null;
    _loading = false;
    _loaded = false;
    _error = null;
    notifyListeners();
  }

  // ===============================================================
  // MUAT DARI SERVER
  // ===============================================================

  /// Muat ulang jadwal dan pengajuan. Tidak melempar error; kegagalan
  /// disimpan di [error].
  Future<void> load({bool refreshConnections = true}) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      if (refreshConnections) await _resolveTunanetra();

      final id = _tunanetraId;
      if (id == null) {
        _items.clear();
      } else {
        final results = await Future.wait([
          ScheduleService.fetchSchedules(tunanetraId: id),
          ScheduleService.fetchRequests(tunanetraId: id),
        ]);

        final schedules = results[0] as List<ScheduleRecord>;
        final requests = results[1] as List<ScheduleRequestRecord>;

        _items
          ..clear()
          ..addAll(schedules.map(_fromSchedule))
          // Pengajuan Disetujui sudah muncul sebagai jadwal berlaku.
          ..addAll(
            requests.where((r) => r.status != 'Disetujui').map(_fromRequest),
          );
      }
      _loaded = true;
    } catch (e) {
      _error = _msg(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _resolveTunanetra() async {
    final connections = await ConnectionService.fetchConnections();
    final connected = connections.where((c) => c.status == 'Terhubung');

    _connected
      ..clear()
      ..addAll(connected);

    // Pilihan sebelumnya dipertahankan kalau masih terhubung,
    // kalau tidak dipakai tunanetra pertama.
    final stillThere = _connected.any((c) => c.tunanetraId == _tunanetraId);
    if (!stillThere) {
      _tunanetraId = _connected.isEmpty ? null : _connected.first.tunanetraId;
    }
  }

  Future<String> _requireTunanetra() async {
    if (_tunanetraId == null) await _resolveTunanetra();

    final id = _tunanetraId;
    if (id == null) {
      throw Exception('Anda belum terhubung dengan tunanetra');
    }
    return id;
  }

  // ===============================================================
  // JADWAL BERDASARKAN TANGGAL
  // ===============================================================

  /// Mengambil jadwal yang disetujui dan berlangsung pada tanggal tertentu.
  List<Schedule> forDay(DateTime day) {
    final r =
        _items
            .where(
              (s) => s.status == ScheduleStatus.approved && s.occursOn(day),
            )
            .toList()
          ..sort((a, b) => a.minutes.compareTo(b.minutes));

    return r;
  }

  // ===============================================================
  // FILTER JADWAL BERDASARKAN STATUS
  // ===============================================================

  List<Schedule> byStatus(ScheduleStatus? status) {
    final r = _items.where((s) => status == null || s.status == status).toList()
      ..sort((a, b) => a.minutes.compareTo(b.minutes));

    return r;
  }

  // ===============================================================
  // TAMBAH JADWAL (mengirim pengajuan)
  // ===============================================================

  /// Mengirim pengajuan jadwal baru. Jadwal berlaku setelah tunanetra
  /// menyetujui. Melempar Exception kalau gagal.
  Future<void> add(
    String title,
    RepeatType repeat,
    TimeOfDay time,
    DateTime date,
  ) async {
    final tunanetraId = await _requireTunanetra();

    await ScheduleService.submitAdd(
      tunanetraId: tunanetraId,
      title: title,
      time: formatTime(time),
      repeatType: repeat.dbLabel,
      startDate: dateOnly(date),
    );

    await load();
  }

  // ===============================================================
  // UBAH JADWAL (mengirim pengajuan)
  // ===============================================================

  /// Jadwal Disetujui: mengajukan perubahan.
  /// Pengajuan Menunggu / Ditolak: pengajuan lama dibatalkan lalu dikirim
  /// ulang dengan isi baru.
  Future<void> update(
    String id,
    String title,
    RepeatType repeat,
    TimeOfDay time,
    DateTime date,
  ) async {
    final i = _items.indexWhere((s) => s.id == id);
    if (i < 0) return;

    final old = _items[i];
    final tunanetraId = await _requireTunanetra();

    if (old.status == ScheduleStatus.pending) {
      await ScheduleService.cancelRequest(old.id);
    }

    // Jadwal berlaku, atau pengajuan Ubah / Hapus -> ajukan Ubah.
    // Pengajuan Tambah -> ajukan Tambah baru.
    final editTarget = old.status == ScheduleStatus.approved
        ? old.id
        : (old.action == 'Tambah' ? null : old.scheduleId);

    if (editTarget != null) {
      await ScheduleService.submitEdit(
        tunanetraId: tunanetraId,
        scheduleId: editTarget,
        title: title,
        time: formatTime(time),
        repeatType: repeat.dbLabel,
        startDate: dateOnly(date),
      );
    } else {
      await ScheduleService.submitAdd(
        tunanetraId: tunanetraId,
        title: title,
        time: formatTime(time),
        repeatType: repeat.dbLabel,
        startDate: dateOnly(date),
      );
    }

    await load();
  }

  // ===============================================================
  // HAPUS JADWAL
  // ===============================================================

  /// Jadwal Disetujui: mengajukan penghapusan.
  /// Pengajuan Menunggu: dibatalkan.
  /// Pengajuan Ditolak: hanya disembunyikan dari layar ini
  /// (server tidak menghapus riwayat yang sudah dijawab).
  Future<void> remove(String id) async {
    final i = _items.indexWhere((s) => s.id == id);
    if (i < 0) return;

    final old = _items[i];

    switch (old.status) {
      case ScheduleStatus.approved:
        final tunanetraId = await _requireTunanetra();
        await ScheduleService.submitDelete(
          tunanetraId: tunanetraId,
          scheduleId: old.id,
        );
        await load();

      case ScheduleStatus.pending:
        await ScheduleService.cancelRequest(old.id);
        await load();

      case ScheduleStatus.rejected:
        _items.removeAt(i);
        notifyListeners();
    }
  }

  // ===============================================================
  // UBAH STATUS JADWAL (lokal)
  // ===============================================================

  void setStatus(String id, ScheduleStatus status) {
    final i = _items.indexWhere((s) => s.id == id);

    if (i < 0) return;

    _items[i] = _items[i].copyWith(status: status);

    notifyListeners();
  }
}

// =====================================================================
// INSTANCE STORE JADWAL
// =====================================================================

final ScheduleStore scheduleStore = ScheduleStore();