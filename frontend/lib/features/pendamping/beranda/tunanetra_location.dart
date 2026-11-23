import '../koneksi/koneksi_data.dart';

class TunanetraLocation {
  final String id;
  final String name;
  final String email;
  final double latitude;
  final double longitude;
  final String address;
  final String battery;
  final String temperature;

  const TunanetraLocation({
    required this.id,
    required this.name,
    required this.email,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.battery,
    required this.temperature,
  });

  /// Data lokasi/baterai/suhu CONTOH, bergiliran.
  ///
  /// Aplikasi tunanetra belum mengirim data perangkat ke server, jadi bagian
  /// lokasi, baterai, dan suhu masih contoh. Daftar ini dipakai sebagai
  /// pasokan contoh saat beranda menampilkan tunanetra yang benar-benar
  /// terhubung. Diganti begitu ada endpoint data perangkat.
  static const List<TunanetraLocation> defaultList = [
    TunanetraLocation(
      id: 'tn-1',
      name: 'Budi Santoso',
      email: 'BudiSantoso@gmail.com',
      latitude: 1.1301,
      longitude: 104.0529,
      address:
          'Jl. Ahmad Yani, Tlk. Tering, Kec. Batam Kota, Kota Batam, Kepulauan Riau 29461',
      battery: '89%',
      temperature: '35°C',
    ),
    TunanetraLocation(
      id: 'tn-2',
      name: 'Siti Rahma',
      email: 'SitiRahma@gmail.com',
      latitude: 1.1278,
      longitude: 104.0535,
      address:
          'Engku Putri, Tlk. Tering, Kec. Batam Kota, Kota Batam, Kepulauan Riau 29464',
      battery: '94%',
      temperature: '36°C',
    ),
  ];
}

/// Layanan data tunanetra untuk halaman beranda pendamping.
class TunanetraLocationService {
  /// Mengambil tunanetra yang sudah TERHUBUNG dengan pendamping yang sedang
  /// login, yaitu pengajuan berstatus "Terhubung" pada `GET /api/requests`.
  ///
  /// Ini menggantikan daftar contoh yang dulu selalu ditampilkan. Kalau
  /// gagal, halaman beranda menampilkan keadaan kosong, bukan data palsu.
  static Future<List<TunanetraLocation>> fetchLinkedTunanetra() async {
    final requests = await ConnectionService.fetchAll();
    return linkedTunanetraFrom(requests);
  }
}

/// Menyaring pengajuan berstatus "Terhubung" lalu mengubahnya menjadi daftar
/// tunanetra untuk beranda.
///
/// Dibuat sebagai fungsi murni supaya bisa diuji tanpa jaringan.
List<TunanetraLocation> linkedTunanetraFrom(List<ConnectionRequest> requests) {
  final connected = requests
      .where((request) => request.status == ConnectionStatus.terhubung)
      .toList();

  return [
    for (var i = 0; i < connected.length; i++) _withDemoTelemetry(i, connected[i]),
  ];
}

/// Menggabungkan identitas asli tunanetra dengan contoh data lokasi/baterai/
/// suhu. Bergiliran supaya tiap tunanetra terhubung punya penanda sendiri di
/// peta, walau datanya belum nyata.
TunanetraLocation _withDemoTelemetry(int index, ConnectionRequest request) {
  final demo = TunanetraLocation.defaultList[
      index % TunanetraLocation.defaultList.length];

  return TunanetraLocation(
    id: request.visuallyImpairedId,
    name: request.name,
    email: request.email,
    latitude: demo.latitude,
    longitude: demo.longitude,
    address: demo.address,
    battery: demo.battery,
    temperature: demo.temperature,
  );
}
