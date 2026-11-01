import 'package:flutter/material.dart';

import 'core/colors.dart';
import 'features/auth/onboarding_page.dart';
import 'features/auth/splash_page.dart';
import 'features/pendamping/beranda/beranda_page.dart';
import 'features/pendamping/jadwal/jadwal_page.dart';
import 'features/pendamping/koneksi/koneksi_page.dart';
import 'features/pendamping/koneksi/tautkan_tunanetra_page.dart';
import 'features/pendamping/profile/profile_page.dart';
import 'features/pendamping/widgets/bottom_bar.dart';

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
      // Halaman 1 onboarding berisi logo ALICE, jadi tidak perlu SplashPage.
      // Setelah halaman 3 selesai, otomatis pindah ke HomeShell.
      home: const OnboardingPage(),
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
                  const KoneksiPage(),
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