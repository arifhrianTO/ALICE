import 'package:flutter/material.dart';


// =====================================================================
//  HELPER TANGGAL & WAKTU
// =====================================================================

/// Jumlah hari pada strip tanggal di halaman Jadwal.
/// 6 = Senin–Sabtu, 7 = Senin–Minggu.
const int kStripDays = 7;

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String formatTime(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

const dayAbbr = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
const dayFull = [
  'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu',
];
const monthAbbr = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

/// Tanggal awal yang dipilih di halaman Jadwal.
/// Kalau hari ini tidak ada di strip (mis. Minggu saat strip Senin–Sabtu),
/// dipilih Senin berikutnya.
DateTime initialDate() {
  final now = DateTime.now();
  return dateOnly(
    now.weekday > kStripDays ? now.add(Duration(days: 8 - now.weekday)) : now,
  );
}

/// Tanggal terdekat (hari ini atau setelahnya) yang jatuh pada hari [weekday]
/// (1 = Senin ... 7 = Minggu).
DateTime nextWeekday(int weekday) {
  final today = dateOnly(DateTime.now());
  final diff = (weekday - today.weekday + 7) % 7;
  return DateTime(today.year, today.month, today.day + diff);
}


// =====================================================================
//  MODEL JADWAL
// =====================================================================

/// Jenis pengulangan jadwal
enum RepeatType {
  once, // sekali saja
  weekday, // tiap hari tertentu, mis. "Tiap hari Senin"
  daily, // setiap hari
  weekly, // tiap minggu
}

enum ScheduleStatus { approved, pending, rejected }

extension RepeatTypeX on RepeatType {
  /// Label pada dropdown pengulangan di pop up.
  /// [weekday]: 1 = Senin ... 7 = Minggu
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

class Schedule {
  final String id;
  final String title;
  final TimeOfDay time;
  final RepeatType repeat;

  /// Tanggal mulai. 'Sekali saja' = tanggalnya; pengulangan = tanggal acuan
  /// (hari dalam seminggu diambil dari sini).
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

  /// Jam pengingat, mis. 09:00 dengan 5 mnt -> 08:55
  String get reminderTime {
    final m = (minutes - reminderMinutes) % 1440;
    return formatTime(TimeOfDay(hour: m ~/ 60, minute: m % 60));
  }

  /// Label chip pada kartu, mis. "Tiap Senin"
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
//  STORE JADWAL
// =====================================================================

// ---------- Store ----------
class ScheduleStore extends ChangeNotifier {
  ScheduleStore() {
    _seed();
  }

  final List<Schedule> _items = [];
  int _counter = 0;

  String _nextId() => 's${_counter++}';

  void _seed() {
    final base = initialDate();
    Schedule mk(String title, int h, int m, RepeatType r, int reminder,
        ScheduleStatus st, String by) {
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
      mk('Zoom call, General Meeting.', 9, 0, RepeatType.weekly, 5,
          ScheduleStatus.approved, 'Budi'),
      mk('Cek Kesehatan', 12, 0, RepeatType.daily, 10,
          ScheduleStatus.approved, 'Budi'),
      mk('Kelas Online', 15, 0, RepeatType.once, 10,
          ScheduleStatus.approved, 'Budi'),
      mk('Kelas Online', 9, 0, RepeatType.once, 10,
          ScheduleStatus.pending, 'Anda'),
      mk('Belanja Bulanan', 9, 0, RepeatType.once, 10,
          ScheduleStatus.rejected, 'Anda'),
    ]);
  }

  /// Jadwal yang disetujui dan terjadi pada [day], urut berdasarkan jam.
  List<Schedule> forDay(DateTime day) {
    final r = _items
        .where((s) => s.status == ScheduleStatus.approved && s.occursOn(day))
        .toList()
      ..sort((a, b) => a.minutes.compareTo(b.minutes));
    return r;
  }

  /// Semua jadwal, bisa difilter berdasarkan status (null = semua).
  List<Schedule> byStatus(ScheduleStatus? status) {
    final r = _items.where((s) => status == null || s.status == status).toList()
      ..sort((a, b) => a.minutes.compareTo(b.minutes));
    return r;
  }

  /// Jadwal baru dibuat oleh 'Anda' dan menunggu persetujuan.
  /// [weekday]: 1 = Senin ... 7 = Minggu
  void add(String title, RepeatType repeat, TimeOfDay time, int weekday) {
    _items.add(Schedule(
      id: _nextId(),
      title: title,
      time: time,
      repeat: repeat,
      date: repeat == RepeatType.daily
          ? dateOnly(DateTime.now())
          : nextWeekday(weekday),
      reminderMinutes: 10,
      status: ScheduleStatus.pending,
      createdBy: 'Anda',
    ));
    notifyListeners();
  }

  void update(
    String id,
    String title,
    RepeatType repeat,
    TimeOfDay time,
    int weekday,
  ) {
    final i = _items.indexWhere((s) => s.id == id);
    if (i < 0) return;
    final old = _items[i];
    final today = dateOnly(DateTime.now());

    final DateTime newDate;
    if (repeat == RepeatType.daily) {
      newDate = old.repeat == RepeatType.daily ? old.date : today;
    } else if (old.date.weekday == weekday &&
        (repeat != RepeatType.once || !old.date.isBefore(today))) {
      // hari tidak berubah -> tanggal acuan lama dipertahankan
      newDate = old.date;
    } else {
      newDate = nextWeekday(weekday);
    }

    _items[i] = old.copyWith(
      title: title,
      time: time,
      repeat: repeat,
      date: newDate,
    );
    notifyListeners();
  }

  void remove(String id) {
    _items.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  /// Dipakai saat jadwal disetujui / ditolak dari sisi lain (mis. menu Terhubung / backend).
  void setStatus(String id, ScheduleStatus status) {
    final i = _items.indexWhere((s) => s.id == id);
    if (i < 0) return;
    _items[i] = _items[i].copyWith(status: status);
    notifyListeners();
  }
}

/// Instance tunggal yang dipakai seluruh aplikasi.
final ScheduleStore scheduleStore = ScheduleStore();
