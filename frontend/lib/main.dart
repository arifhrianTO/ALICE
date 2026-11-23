import 'package:flutter/material.dart';

import 'core/colors.dart';
import 'core/notification_service.dart';
import 'features/auth/splash_page.dart';
import 'features/pendamping/beranda/beranda_page.dart';
import 'features/pendamping/jadwal/jadwal_page.dart';
import 'features/pendamping/koneksi/koneksi_page.dart';
import 'features/pendamping/koneksi/tautkan_tunanetra_page.dart';
import 'features/pendamping/profile/profile_page.dart';
import 'features/pendamping/widgets/bottom_bar.dart';

void main() async {
  // Firebase butuh pengikatan Flutter sebelum dipakai.
  WidgetsFlutterBinding.ensureInitialized();

  // Kegagalan di sini tidak menghentikan aplikasi: lihat NotificationService.
  await NotificationService.init();

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

  // Kunci ke state tab "Terhubung" supaya bisa disegarkan setelah
  // pendamping selesai menautkan tunanetra baru.
  final GlobalKey<KoneksiPageState> _koneksiKey = GlobalKey<KoneksiPageState>();

  Future<void> _openTautkan() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const TautkanTunanetraPage()),
    );
    if (added == true) {
      _koneksiKey.currentState?.refresh();
    }
  }

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
                  KoneksiPage(key: _koneksiKey),
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
              onAdd: _openTautkan,
            ),
          ],
        ),
      ),
    );
  }
}