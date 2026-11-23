import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alice_app/features/tunanetra/incoming_request_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('IncomingRequest.fromJson memetakan data pendamping', () {
    final req = IncomingRequest.fromJson({
      'id': 'req-1',
      'companion_id': 'usr-9',
      'companion_name': 'Firgi',
      'companion_email': 'firgi@example.com',
      'status': 'Menunggu',
      'request_at': '2026-11-23T10:00:00Z',
    });

    expect(req.id, 'req-1');
    expect(req.companionId, 'usr-9');
    expect(req.companionName, 'Firgi');
    expect(req.companionEmail, 'firgi@example.com');
    expect(req.status, 'Menunggu');
  });

  test('IncomingRequest.fromJson toleran terhadap field yang hilang', () {
    final req = IncomingRequest.fromJson({});

    expect(req.id, '');
    expect(req.companionName, '');
    expect(req.companionEmail, '');
  });

  group('parseRequestDecision', () {
    test('mengenali ucapan menerima', () {
      expect(parseRequestDecision('setuju'), isTrue);
      expect(parseRequestDecision('Saya setuju'), isTrue);
      expect(parseRequestDecision('ya'), isTrue);
      expect(parseRequestDecision('iya, terima'), isTrue);
      expect(parseRequestDecision('boleh'), isTrue);
    });

    test('mengenali ucapan menolak', () {
      expect(parseRequestDecision('tolak'), isFalse);
      expect(parseRequestDecision('tidak'), isFalse);
      expect(parseRequestDecision('tidak mau'), isFalse);
      expect(parseRequestDecision('nggak'), isFalse);
      expect(parseRequestDecision('jangan'), isFalse);
    });

    test('"tidak setuju" dibaca sebagai menolak', () {
      expect(parseRequestDecision('tidak setuju'), isFalse);
      expect(parseRequestDecision('saya tidak setuju'), isFalse);
    });

    test('ucapan tak dikenali mengembalikan null', () {
      expect(parseRequestDecision('apa itu'), isNull);
      expect(parseRequestDecision(''), isNull);
    });

    test('kata yang hanya mengandung "ya" tidak dianggap menerima', () {
      // Regresi: gema "saya belum paham" dulu salah dibaca "ya" (dari
      // "saya"), sehingga dialog menjawab sendiri pembicaraannya.
      expect(parseRequestDecision('saya belum paham'), isNull);
      expect(parseRequestDecision('banyak orang'), isNull);
      expect(parseRequestDecision('kaya'), isNull);
      expect(parseRequestDecision('melanjutkan'), isNull);
    });

    test('mengenali kata utuh tambahan', () {
      expect(parseRequestDecision('ya tolong'), isTrue);
      expect(parseRequestDecision('oke'), isTrue);
      expect(parseRequestDecision('siap'), isTrue);
      expect(parseRequestDecision('yakin'), isTrue);
      expect(parseRequestDecision('bukan'), isFalse);
      expect(parseRequestDecision('tak mau'), isFalse);
    });
  });

  group('requestIdFromNotification', () {
    test('mengambil id dari notifikasi pengajuan tautan', () {
      expect(
        requestIdFromNotification({
          'type': 'connection_request',
          'request_id': 'req-9',
        }),
        'req-9',
      );
    });

    test('null untuk jenis pesan lain', () {
      expect(
        requestIdFromNotification({'type': 'pengingat', 'request_id': 'req-9'}),
        isNull,
      );
    });

    test('null kalau id hilang atau kosong', () {
      expect(requestIdFromNotification({'type': 'connection_request'}), isNull);
      expect(
        requestIdFromNotification({
          'type': 'connection_request',
          'request_id': '',
        }),
        isNull,
      );
    });

    test('toleran terhadap data kosong', () {
      expect(requestIdFromNotification({}), isNull);
    });
  });

  group('IncomingRequestService.respond', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({'session_token': 'tok-uji'});
    });

    test('sukses saat server membalas 200', () async {
      final client = MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.path, endsWith('/api/requests/req-1/respond'));
        expect(request.body, contains('"accept":true'));
        expect(request.headers['Authorization'], 'Bearer tok-uji');
        return http.Response('{"status":"success"}', 200);
      });

      await IncomingRequestService.respond(
        'req-1',
        accept: true,
        client: client,
      );
    });

    test('404 dibaca sebagai "sudah tidak berlaku"', () async {
      final client = MockClient((_) async => http.Response('{}', 404));

      await expectLater(
        IncomingRequestService.respond('req-1', accept: false, client: client),
        throwsA(
          isA<RequestRespondException>().having((e) => e.gone, 'gone', isTrue),
        ),
      );
    });

    test('500 dibaca sebagai gagal (boleh dicoba ulang)', () async {
      final client = MockClient((_) async => http.Response('{}', 500));

      await expectLater(
        IncomingRequestService.respond('req-1', accept: true, client: client),
        throwsA(
          isA<RequestRespondException>().having((e) => e.gone, 'gone', isFalse),
        ),
      );
    });
  });
}
