import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

class TunanetraItem {
  final String userId;
  final String name;
  final String email;

  TunanetraItem({
    required this.userId,
    required this.name,
    required this.email,
  });

  factory TunanetraItem.fromJson(Map<String, dynamic> j) => TunanetraItem(
        userId: j['user_id'] as String,
        name: j['name'] as String,
        email: j['email'] as String,
      );
}

Future<List<TunanetraItem>> searchTunanetra(String keyword) async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('session_token') ?? '';

  final uri = Uri.parse('${ApiConfig.baseUrl}/api/tunanetra/search')
      .replace(queryParameters: {'q': keyword});

  final res = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
  final body = jsonDecode(res.body) as Map<String, dynamic>;

  if (res.statusCode != 200) {
    throw Exception(body['message'] ?? 'Gagal memuat data');
  }

  final data = body['data'] as List<dynamic>;
  return data
      .map((e) => TunanetraItem.fromJson(e as Map<String, dynamic>))
      .toList();
}