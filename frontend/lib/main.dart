import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

import 'core/api_config.dart';
import 'core/colors.dart';
import 'features/auth/splash_page.dart';
import 'features/pendamping/beranda/beranda_page.dart';
import 'features/pendamping/jadwal/jadwal_page.dart';
import 'features/pendamping/koneksi/koneksi_page.dart';
import 'features/pendamping/koneksi/tautkan_tunanetra_page.dart';
import 'features/pendamping/profile/profile_page.dart';
import 'features/pendamping/widgets/bottom_bar.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Facebook SDK berbasis JavaScript/WebView perlu diinisialisasi lebih
  // dulu pada web dan desktop. Android/iOS memakai SDK native.
  if (kIsWeb ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS) {
    try {
      await FacebookAuth.i
          .webAndDesktopInitialize(
            appId: ApiConfig.facebookAppId,
            cookie: true,
            xfbml: true,
            version: 'v19.0',
          )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      // Jangan sampai aplikasi gagal start hanya karena SDK Facebook
      // tidak bisa dimuat. Login Facebook akan menampilkan pesan error.
      debugPrint('Inisialisasi Facebook gagal: $e');
    }
  }

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
                MaterialPageRoute(builder: (_) => const TautkanTunanetraPage()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
