import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/colors.dart';
import '../main.dart';
import '../tunanetra/voice_page.dart';
import '../widgets/alice_logo.dart';
import 'role_page.dart';

/// Alur awal aplikasi:
/// Splash screen -> Cek sesi lokal:
///   - Jika sudah login -> langsung ke Beranda sesuai peran (VoicePage atau HomeShell)
///   - Jika belum login -> ke RolePage (pilih peran)
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      final role = prefs.getString('user_role') ?? 'pendamping';

      if (!mounted) return;

      if (isLoggedIn) {
        if (role == 'tunanetra') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const VoicePage()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeShell()),
          );
        }
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const RolePage()),
        );
      }
    } catch (_) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const RolePage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AliceColors.primaryDark,
      body: Center(
        child: AliceFullLogo(width: 220),
      ),
    );
  }
}
