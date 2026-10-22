import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/api_config.dart';

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

  factory TunanetraLocation.fromJson(Map<String, dynamic> json) {
    return TunanetraLocation(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 1.1301,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 104.0529,
      address: json['address'] as String? ?? '',
      battery: json['battery'] as String? ?? '0%',
      temperature: json['temperature'] as String? ?? '0°C',
    );
  }

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

class TunanetraLocationService {
  static Future<List<TunanetraLocation>> fetchLinkedTunanetra() async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/tunanetra');
    final response = await http.get(url).timeout(
      const Duration(seconds: 4),
    );

    if (response.statusCode == 200) {
      final List<dynamic> list = jsonDecode(response.body) as List<dynamic>;
      return list
          .map((item) => TunanetraLocation.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Gagal memuat data tunanetra: HTTP ${response.statusCode}');
    }
  }
}
