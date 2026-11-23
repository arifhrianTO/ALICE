import 'dart:convert';

import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../../core/api_config.dart';

class AssistantReply {
  final String answer;
  final String intent;

  const AssistantReply({required this.answer, required this.intent});
}

class AssistantService {
  static const Duration _locationCacheDuration = Duration(minutes: 2);

  static final geo.Geocoding _geocoder = geo.Geocoding();

  static Position? _cachedPosition;
  static String? _cachedLocationName;
  static DateTime? _cachedAt;

  static Future<AssistantReply> ask(String question) async {
    double? latitude;
    double? longitude;
    String? locationName;
    if (_needsLocation(question)) {
      try {
        final resolved = await _resolveLocation();
        latitude = resolved.position.latitude;
        longitude = resolved.position.longitude;
        locationName = resolved.name;
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
            'locationName': ?locationName,
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

  static bool _needsLocation(String question) =>
      _isWeatherQuestion(question) || _isLocationQuestion(question);

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

  static bool _isLocationQuestion(String question) {
    final normalized = question.toLowerCase();
    return [
      'dimana',
      'di mana',
      'lokasi saya',
      'posisi saya',
    ].any(normalized.contains);
  }

  static Future<({Position position, String? name})> _resolveLocation() async {
    final now = DateTime.now();
    if (_cachedPosition != null &&
        _cachedAt != null &&
        now.difference(_cachedAt!) < _locationCacheDuration) {
      return (position: _cachedPosition!, name: _cachedLocationName);
    }

    final position = await _getPosition();
    String? name;
    try {
      final placemarks = await _geocoder.placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) name = _formatPlacemark(placemarks.first);
    } catch (_) {
      // Nama tempat hanya pelengkap; koordinat tetap dikirim ke backend.
    }

    _cachedPosition = position;
    _cachedLocationName = name;
    _cachedAt = DateTime.now();
    return (position: position, name: name);
  }

  static String? _formatPlacemark(geo.Placemark placemark) {
    final parts = <String>[];
    void add(String? value) {
      final text = value?.trim() ?? '';
      if (text.isNotEmpty && !parts.contains(text)) parts.add(text);
    }

    add(placemark.thoroughfare ?? placemark.street);
    add(placemark.subLocality);
    add(placemark.locality);
    if (parts.isEmpty) add(placemark.subAdministrativeArea);
    if (parts.isEmpty) add(placemark.administrativeArea);
    return parts.isEmpty ? null : parts.take(3).join(', ');
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
