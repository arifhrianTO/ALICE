import 'package:flutter_test/flutter_test.dart';
import 'package:alice_app/beranda/tunanetra_location.dart';

void main() {
  test('TunanetraLocation fromJson parses correctly', () {
    final json = {
      'id': 'tn-test',
      'name': 'Test User',
      'email': 'test@example.com',
      'latitude': 1.1301,
      'longitude': 104.0529,
      'address': 'Batam Center',
      'battery': '85%',
      'temperature': '36°C',
    };

    final loc = TunanetraLocation.fromJson(json);
    expect(loc.id, 'tn-test');
    expect(loc.name, 'Test User');
    expect(loc.latitude, 1.1301);
    expect(loc.longitude, 104.0529);
    expect(loc.battery, '85%');
    expect(loc.temperature, '36°C');
  });

  test('TunanetraLocation defaultList has valid coordinates', () {
    expect(TunanetraLocation.defaultList.isNotEmpty, isTrue);
    for (final item in TunanetraLocation.defaultList) {
      expect(item.latitude, isNotNull);
      expect(item.longitude, isNotNull);
    }
  });
}
