import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'auth/splash_page.dart';
import 'beranda/beranda_page.dart';
import 'core/colors.dart';
import 'jadwal/jadwal_pages.dart';
import 'profile/profile_page.dart';
import 'tambah_tunanetra/tambah_tunanetra_page.dart';
import 'widgets/bottom_bar.dart';

void main() {
  runApp(const AliceApp());
}

class AliceApp extends StatelessWidget {
  const AliceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ALICE',
      theme: ThemeData(
        colorSchemeSeed: kPurple,
        useMaterial3: true,
        scaffoldBackgroundColor: kBg,
      ),
      home: const SplashPage(),
    );
  }
}

// =====================================================================
//  SHELL APLIKASI (Beranda + Terhubung + Jadwal + Profile)
// =====================================================================
class HomeShell extends StatefulWidget {
  final String? name;
  final String? email;
  final String? role;

  const HomeShell({super.key, this.name, this.email, this.role});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              // IndexedStack menjaga state tiap tab saat berpindah.
              child: IndexedStack(
                index: _index,
                children: [
                  const BerandaPage(),
                  const _TerhubungPage(),
                  const SizedBox.shrink(),
                  const JadwalPage(),
                  ProfilePage(
                    initialName: widget.name,
                    initialEmail: widget.email,
                    initialRole: widget.role,
                  ),
                ],
              ),
            ),
            AppBottomBar(
              selectedIndex: _index,
              onTap: (i) => setState(() => _index = i),
              onAdd: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const TautkanTunanetraPage(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
//  HALAMAN TERHUBUNG (uji koneksi ke backend)
// =====================================================================
class _TerhubungPage extends StatefulWidget {
  const _TerhubungPage();

  @override
  State<_TerhubungPage> createState() => _TerhubungPageState();
}

class _TerhubungPageState extends State<_TerhubungPage> {
  String message = 'Tekan tombol untuk menghubungkan server';

  Future<void> connectBackend() async {
    setState(() {
      message = 'Menghubungkan...';
    });

    // Untuk Web (Chrome) -> localhost.
    // Untuk Android Emulator -> 10.0.2.2.
    // Untuk HP fisik, ganti dengan IP komputer di jaringan lokal (mis. http://192.168.x.x:8080).
    const baseUrl = kIsWeb ? 'http://localhost:8080' : 'http://10.0.2.2:8080';

    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/hello'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          message = '${data['app']}: ${data['message']}';
        });
      } else {
        setState(() {
          message = 'Server error: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        message = 'Gagal terhubung ke backend';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 14),
            child: Text(
              'Terhubung',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: kTextPurple,
              ),
            ),
          ),
          Center(
            child: Column(
              children: [
                Text(
                  message,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: connectBackend,
                  child: const Text('Hubungkan ke Backend'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}