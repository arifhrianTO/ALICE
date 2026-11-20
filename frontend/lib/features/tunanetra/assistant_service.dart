import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../../core/api_config.dart';

class AssistantReply {
  final String answer;
  final String intent;

  const AssistantReply({required this.answer, required this.intent});
}

class AssistantService {
  static Future<AssistantReply> ask(String question) async {
    double? latitude;
    double? longitude;
    if (_isWeatherQuestion(question)) {
      try {
        final position = await _getPosition();
        latitude = position.latitude;
        longitude = position.longitude;
      } catch (_) {
        // The backend returns an accessible explanation when no location is available.
      }
    }

    final now = DateTime.now();
    final response = await http
        .post(
          Uri.parse('${ApiConfig.baseUrl}/api/assistant/ask'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'question': question,
            'latitude': ?latitude,
            'longitude': ?longitude,
            'timezoneOffsetMinutes': now.timeZoneOffset.inMinutes,
          }),
        )
        .timeout(const Duration(seconds: 15));

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        body['message'] as String? ?? 'Pertanyaan gagal diproses.',
      );
    }
    final data = body['data'] as Map<String, dynamic>;
    return AssistantReply(
      answer: data['answer'] as String? ?? 'Maaf, saya belum memiliki jawaban.',
      intent: data['intent'] as String? ?? 'unknown',
    );
  }

  static bool _isWeatherQuestion(String question) {
    final normalized = question.toLowerCase();
    return [
      'cuaca',
      'hujan',
      'suhu',
      'prakiraan',
      'cerah',
      'berawan',
    ].any(normalized.contains);
  }

  static Future<Position> _getPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('Layanan lokasi tidak aktif.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Izin lokasi tidak diberikan.');
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
    ).timeout(const Duration(seconds: 8));
  }
}
