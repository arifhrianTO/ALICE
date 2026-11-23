import 'package:material_ui/material_ui.dart';

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

  const Schedule({
    required this.id,
    required this.title,
    required this.time,
    required this.repeat,
    required this.date,
    required this.reminderMinutes,
    required this.status,
    required this.createdBy,
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
    );
  }
}

// =====================================================================
// STORE JADWAL
// =====================================================================

class ScheduleStore extends ChangeNotifier {
  ScheduleStore() {
    _seed();
  }

  final List<Schedule> _items = [];
  int _counter = 0;

  String _nextId() => 's${_counter++}';

  /// Kosongkan semua jadwal. Dipakai saat logout / berganti akun agar
  /// jadwal pengguna sebelumnya tidak terlihat oleh pengguna berikutnya.
  void reset() {
    _items.clear();
    _counter = 0;
    notifyListeners();
  }

  // ===============================================================
  // DATA AWAL
  // ===============================================================

  void _seed() {
    final base = initialDate();

    Schedule mk(
      String title,
      int h,
      int m,
      RepeatType r,
      int reminder,
      ScheduleStatus st,
      String by,
    ) {
      return Schedule(
        id: _nextId(),
        title: title,
        time: TimeOfDay(hour: h, minute: m),
        repeat: r,
        date: base,
        reminderMinutes: reminder,
        status: st,
        createdBy: by,
      );
    }

    _items.addAll([
      mk(
        'Zoom call, General Meeting.',
        9,
        0,
        RepeatType.weekly,
        5,
        ScheduleStatus.approved,
        'Budi',
      ),
      mk(
        'Cek Kesehatan',
        12,
        0,
        RepeatType.daily,
        10,
        ScheduleStatus.approved,
        'Budi',
      ),
      mk(
        'Kelas Online',
        15,
        0,
        RepeatType.once,
        10,
        ScheduleStatus.approved,
        'Budi',
      ),
      mk(
        'Kelas Online',
        9,
        0,
        RepeatType.once,
        10,
        ScheduleStatus.pending,
        'Anda',
      ),
      mk(
        'Belanja Bulanan',
        9,
        0,
        RepeatType.once,
        10,
        ScheduleStatus.rejected,
        'Anda',
      ),
    ]);
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
  // TAMBAH JADWAL
  // ===============================================================

  /// Jadwal baru menggunakan tanggal yang dipilih melalui kalender.
  void add(String title, RepeatType repeat, TimeOfDay time, DateTime date) {
    _items.add(
      Schedule(
        id: _nextId(),
        title: title,
        time: time,
        repeat: repeat,
        date: dateOnly(date),
        reminderMinutes: 10,
        status: ScheduleStatus.pending,
        createdBy: 'Anda',
      ),
    );

    notifyListeners();
  }

  // ===============================================================
  // UBAH JADWAL
  // ===============================================================

  /// Memperbarui jadwal beserta tanggal yang dipilih melalui kalender.
  void update(
    String id,
    String title,
    RepeatType repeat,
    TimeOfDay time,
    DateTime date,
  ) {
    final i = _items.indexWhere((s) => s.id == id);

    if (i < 0) return;

    final old = _items[i];

    _items[i] = old.copyWith(
      title: title,
      time: time,
      repeat: repeat,
      date: dateOnly(date),
    );

    notifyListeners();
  }

  // ===============================================================
  // HAPUS JADWAL
  // ===============================================================

  void remove(String id) {
    _items.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  // ===============================================================
  // UBAH STATUS JADWAL
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
