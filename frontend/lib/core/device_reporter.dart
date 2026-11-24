import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import 'monitoring_service.dart';

/// Mengirim lokasi, alamat, dan baterai perangkat tunanetra ke server secara
/// berkala, supaya pendamping bisa memantaunya di Beranda.
///
/// Pemakaian (di aplikasi tunanetra, setelah login):
///   DeviceReporter.start();
/// dan saat logout:
///   DeviceReporter.stop();
///
/// Izin lokasi diminta satu kali per sesi aplikasi kalau belum diberikan.
/// Kalau ditolak, pengiriman lokasi dilewati (baterai tetap dikirim) dan
/// izin tidak diminta berulang-ulang.
class DeviceReporter {
  static const _interval = Duration(seconds: 30);

  /// Alamat dicari ulang hanya kalau perangkat sudah berpindah sejauh ini.
  /// Menghindari panggilan geocoder tiap 30 detik saat perangkat diam.
  static const _regeocodeMeters = 50.0;

  /// Saluran ke kode Android (MainActivity.kt) untuk membaca suhu baterai.
  static const _channel = MethodChannel('alice/device');

  static Timer? _timer;
  static bool _sending = false;

  /// Izin sudah pernah diminta pada sesi ini.
  static bool _askedPermission = false;

  /// Titik dan alamat terakhir yang berhasil dicari.
  static Position? _addressPoint;
  static String? _addressText;

  /// geocoding 5.x: semua fungsi ada di kelas Geocoding. Bahasa hasil
  /// mengikuti bahasa perangkat.
  static final Geocoding _geocoding = Geocoding();

  /// Mulai mengirim: sekali sekarang, lalu tiap [_interval].
  static void start() {
    if (_timer != null) return;
    debugPrint('DeviceReporter: mulai');
    _send();
    _timer = Timer.periodic(_interval, (_) => _send());
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
    _addressPoint = null;
    _addressText = null;
  }

  static Future<void> _send() async {
    // Jangan menumpuk kalau pengiriman sebelumnya belum selesai.
    if (_sending) return;
    _sending = true;

    try {
      final position = await _position();
      final battery = await _battery();
      final temperature = await _temperature();
      final address = position == null ? null : await _addressFor(position);

      debugPrint(
        'DeviceReporter: lokasi=${position?.latitude},${position?.longitude} '
        'baterai=$battery suhu=$temperature alamat=$address',
      );

      // Tidak ada yang bisa dikirim.
      if (position == null && battery == null && temperature == null) {
        debugPrint('DeviceReporter: tidak ada data, pengiriman dilewati');
        return;
      }

      await MonitoringService.updateMyStatus(
        latitude: position?.latitude,
        longitude: position?.longitude,
        address: address,
        batteryLevel: battery,
        temperature: temperature,
      );
      debugPrint('DeviceReporter: terkirim');
    } catch (e) {
      // Dicoba lagi pada giliran berikutnya.
      debugPrint('Gagal mengirim data perangkat ($e)');
    } finally {
      _sending = false;
    }
  }

  /// Lokasi saat ini, atau null kalau layanan mati / izin belum diberikan.
  static Future<Position?> _position() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        debugPrint('DeviceReporter: layanan lokasi perangkat mati');
        return null;
      }

      var permission = await Geolocator.checkPermission();

      // Minta izin satu kali. Kalau sedang ada permintaan izin lain
      // (misalnya dari asisten suara), Geolocator melempar error dan
      // pengiriman lokasi dicoba lagi pada giliran berikutnya.
      if (permission == LocationPermission.denied && !_askedPermission) {
        _askedPermission = true;
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('DeviceReporter: izin lokasi belum diberikan ($permission)');
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      debugPrint('DeviceReporter: gagal membaca lokasi ($e)');
      return null;
    }
  }

  /// Alamat teks untuk [p]. Memakai hasil sebelumnya kalau perangkat belum
  /// berpindah jauh. Null kalau alamat tidak bisa dicari; server lalu
  /// menyimpan alamat kosong dan Beranda menampilkan koordinatnya.
  static Future<String?> _addressFor(Position p) async {
    final last = _addressPoint;
    if (last != null &&
        Geolocator.distanceBetween(
              last.latitude,
              last.longitude,
              p.latitude,
              p.longitude,
            ) <
            _regeocodeMeters) {
      return _addressText;
    }

    try {
      final marks = await _geocoding
          .placemarkFromCoordinates(p.latitude, p.longitude)
          .timeout(const Duration(seconds: 8));
      final text = _formatAddress(marks);
      if (text != null) {
        _addressPoint = p;
        _addressText = text;
        return text;
      }
    } catch (e) {
      debugPrint('DeviceReporter: gagal mencari alamat ($e)');
    }

    // Sudah berpindah dan alamat baru belum didapat: jangan kirim alamat
    // lama yang sudah tidak cocok dengan lokasi sekarang.
    _addressPoint = null;
    _addressText = null;
    return null;
  }

  /// Plus Code Google, contoh "2XV2+HX9". Bukan nama jalan.
  static final RegExp _plusCode = RegExp(r'^[0-9A-Z]{4,8}\+[0-9A-Z]{2,}');

  /// Kunci pembanding supaya "Kec. Sagulung" dan "Kecamatan Sagulung"
  /// dianggap sama.
  static String _key(String v) => v
      .toLowerCase()
      .replaceFirst(RegExp(r'^(kecamatan|kec\.?)\s+'), '')
      .trim();

  /// Menyusun alamat pendek dari bagian-bagian placemark: jalan (kalau ada),
  /// kelurahan, kecamatan, kota, provinsi, kode pos. Bagian kosong, ganda,
  /// dan Plus Code dibuang.
  ///
  /// Kolom `street` di Android sering berisi seluruh alamat (lengkap dengan
  /// Plus Code dan negara), jadi hanya dipakai kalau berupa satu nama jalan
  /// sederhana dan `thoroughfare` kosong.
  static String? _formatAddress(List<Placemark> marks) {
    if (marks.isEmpty) return null;
    final m = marks.first;

    String clean(String? v) => v?.trim() ?? '';

    var road = clean(m.thoroughfare);
    final number = clean(m.subThoroughfare);
    if (road.isNotEmpty && number.isNotEmpty) road = '$road No. $number';

    if (road.isEmpty) {
      final street = clean(m.street);
      if (street.isNotEmpty && !street.contains(',')) road = street;
    }
    if (_plusCode.hasMatch(road)) road = '';

    final parts = <String>[];
    final seen = <String>{};
    for (final raw in [
      road,
      clean(m.subLocality),
      clean(m.locality),
      clean(m.subAdministrativeArea),
      clean(m.administrativeArea),
      clean(m.postalCode),
    ]) {
      if (raw.isEmpty || _plusCode.hasMatch(raw)) continue;
      if (seen.add(_key(raw))) parts.add(raw);
    }

    return parts.isEmpty ? null : parts.join(', ');
  }

  /// Level baterai 0..100, atau null kalau tidak bisa dibaca
  /// (misalnya di desktop).
  static Future<int?> _battery() async {
    try {
      return await Battery().batteryLevel;
    } catch (e) {
      debugPrint('DeviceReporter: gagal membaca baterai ($e)');
      return null;
    }
  }

  /// Suhu perangkat dalam derajat Celsius: suhu baterai HP, satu-satunya
  /// suhu yang tersedia di hampir semua HP Android. Null kalau tidak bisa
  /// dibaca (misalnya bukan Android).
  static Future<double?> _temperature() async {
    try {
      return await _channel.invokeMethod<double>('batteryTemperature');
    } catch (e) {
      debugPrint('DeviceReporter: gagal membaca suhu ($e)');
      return null;
    }
  }
}