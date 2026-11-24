import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alice_app/features/auth/login_page.dart';
import 'package:alice_app/features/pendamping/beranda/tunanetra_location.dart';

void main() {
  test('TunanetraLocation carries identity and telemetry', () {
    const loc = TunanetraLocation(
      id: 'tn-test',
      name: 'Test User',
      email: 'test@example.com',
      latitude: 1.1301,
      longitude: 104.0529,
      hasLocation: true,
      address: 'Batam Center',
      battery: '85%',
      temperature: '36°C',
    );

    expect(loc.id, 'tn-test');
    expect(loc.name, 'Test User');
    expect(loc.latitude, 1.1301);
    expect(loc.longitude, 104.0529);
    expect(loc.hasLocation, isTrue);
    expect(loc.address, 'Batam Center');
    expect(loc.battery, '85%');
    expect(loc.temperature, '36°C');
  });

  test('TunanetraLocation tanpa data perangkat tidak punya lokasi', () {
    const loc = TunanetraLocation(
      id: 'tn-test',
      name: 'Test User',
      email: 'test@example.com',
    );

    // Belum ada data dari perangkat: Beranda menampilkan "belum tersedia",
    // bukan koordinat palsu.
    expect(loc.hasLocation, isFalse);
    expect(loc.address, isNull);
    expect(loc.battery, isNull);
    expect(loc.temperature, isNull);
  });

  testWidgets('LoginPage hides email option when role is tunanetra', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: LoginPage(role: 'tunanetra')),
    );

    expect(find.text('Masuk dengan Akun Google'), findsOneWidget);
    expect(find.text('Masuk dengan Facebook'), findsOneWidget);
    expect(find.text('Masuk dengan Email'), findsNothing);
  });

  testWidgets('LoginPage shows email option when role is pendamping', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: LoginPage(role: 'pendamping')),
    );

    expect(find.text('Masuk dengan Akun Google'), findsOneWidget);
    expect(find.text('Masuk dengan Facebook'), findsOneWidget);
    expect(find.text('Masuk dengan Email'), findsOneWidget);
  });
}