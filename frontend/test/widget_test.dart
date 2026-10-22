import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alice_app/auth/login_page.dart';
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

  testWidgets('LoginPage hides email option when role is tunanetra', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginPage(role: 'tunanetra'),
      ),
    );

    expect(find.text('Masuk dengan Akun Google'), findsOneWidget);
    expect(find.text('Masuk dengan Facebook'), findsOneWidget);
    expect(find.text('Masuk dengan Email'), findsNothing);
  });

  testWidgets('LoginPage shows email option when role is pendamping', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginPage(role: 'pendamping'),
      ),
    );

    expect(find.text('Masuk dengan Akun Google'), findsOneWidget);
    expect(find.text('Masuk dengan Facebook'), findsOneWidget);
    expect(find.text('Masuk dengan Email'), findsOneWidget);
  });
}

