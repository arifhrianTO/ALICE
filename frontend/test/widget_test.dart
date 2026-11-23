import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alice_app/features/auth/login_page.dart';
import 'package:alice_app/features/pendamping/koneksi/koneksi_data.dart';
import 'package:alice_app/features/pendamping/beranda/tunanetra_location.dart';

void main() {
  test('TunanetraLocation carries identity and telemetry', () {
    const loc = TunanetraLocation(
      id: 'tn-test',
      name: 'Test User',
      email: 'test@example.com',
      latitude: 1.1301,
      longitude: 104.0529,
      address: 'Batam Center',
      battery: '85%',
      temperature: '36°C',
    );

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

  group('linkedTunanetraFrom', () {
    ConnectionRequest req(String id, String vi, String name, String email,
        ConnectionStatus status) {
      return ConnectionRequest(
        id: id,
        visuallyImpairedId: vi,
        name: name,
        email: email,
        status: status,
      );
    }

    test('hanya menyertakan pengajuan berstatus Terhubung', () {
      final list = linkedTunanetraFrom([
        req('r1', 'tn-1', 'Agak Laen', 'a@x.com', ConnectionStatus.terhubung),
        req('r2', 'tn-2', 'Masih Menunggu', 'b@x.com',
            ConnectionStatus.menunggu),
        req('r3', 'tn-3', 'Sudah Ditolak', 'c@x.com', ConnectionStatus.ditolak),
      ]);

      expect(list.length, 1);
      expect(list.first.id, 'tn-1');
      expect(list.first.name, 'Agak Laen');
      expect(list.first.email, 'a@x.com');
    });

    test('kosong kalau tidak ada yang terhubung', () {
      expect(linkedTunanetraFrom(const []), isEmpty);
      expect(
        linkedTunanetraFrom([
          req('r1', 'tn-1', 'X', 'x@x.com', ConnectionStatus.menunggu),
        ]),
        isEmpty,
      );
    });

    test('hasilnya tetap punya koordinat untuk peta', () {
      final list = linkedTunanetraFrom([
        req('r1', 'tn-1', 'X', 'x@x.com', ConnectionStatus.terhubung),
        req('r2', 'tn-2', 'Y', 'y@x.com', ConnectionStatus.terhubung),
      ]);

      expect(list.length, 2);
      for (final item in list) {
        expect(item.latitude, isNotNull);
        expect(item.longitude, isNotNull);
      }
    });
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
