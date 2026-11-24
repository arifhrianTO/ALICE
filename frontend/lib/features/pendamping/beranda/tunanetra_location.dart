import '../../../core/connection_service.dart';
import '../../../core/monitoring_service.dart';

/// Satu tunanetra yang dipantau di Beranda.
///
/// Identitas (id, nama, email) berasal dari data koneksi yang NYATA.
/// Lokasi, alamat, baterai, dan suhu berasal dari data perangkat di server.
/// Kalau perangkat belum mengirim data, isiannya kosong dan Beranda
/// menampilkan "belum tersedia", bukan data contoh.
class TunanetraLocation {
  final String id;
  final String name;
  final String email;

  /// Koordinat terakhir. Hanya berarti kalau [hasLocation] true.
  final double latitude;
  final double longitude;
  final bool hasLocation;

  final String? address;
  final String? battery; // contoh: '89%'
  final String? temperature; // contoh: '35°C'

  const TunanetraLocation({
    required this.id,
    required this.name,
    required this.email,
    this.latitude = 0,
    this.longitude = 0,
    this.hasLocation = false,
    this.address,
    this.battery,
    this.temperature,
  });

  /// Dari tunanetra yang berstatus Terhubung, dilengkapi data perangkat
  /// ([status]) kalau sudah dimuat.
  factory TunanetraLocation.fromConnection(
    ConnectionRecord c, {
    MonitoringRecord? status,
  }) {
    final hasLocation = status?.hasLocation ?? false;

    return TunanetraLocation(
      id: c.tunanetraId,
      // Kalau nama kosong, pakai email supaya kartu tidak kosong.
      name: c.name.trim().isEmpty ? c.email : c.name,
      email: c.email,
      latitude: hasLocation ? status!.latitude! : 0,
      longitude: hasLocation ? status!.longitude! : 0,
      hasLocation: hasLocation,
      address: status?.address,
      battery:
          status?.batteryLevel == null ? null : '${status!.batteryLevel}%',
      temperature: _formatTemperature(status?.temperature),
    );
  }
}

String? _formatTemperature(double? t) {
  if (t == null) return null;
  final text = t == t.roundToDouble() ? t.toInt().toString() : t.toStringAsFixed(1);
  return '$text°C';
}