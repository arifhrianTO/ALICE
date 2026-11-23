import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api_config.dart';
import '../../core/colors.dart';
import '../../main.dart';
import '../../widgets/alice_logo.dart';
import '../pendamping/jadwal/jadwal_data.dart';
import '../tunanetra/voice_page.dart';
import 'onboarding_page.dart';
import 'role_page.dart';

/// Alur awal aplikasi:
/// Splash screen -> Cek sesi lokal:
///   - Jika sudah login -> langsung ke Beranda sesuai peran (VoicePage atau HomeShell)
///   - Jika belum login & belum pernah onboarding -> ke OnboardingPage (hanya sekali)
///   - Jika belum login & sudah pernah onboarding -> langsung ke RolePage (pilih peran)
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
      var isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      final role = prefs.getString('user_role') ?? 'pendamping';
      final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
      final token = prefs.getString('session_token') ?? '';

      if (isLoggedIn) {
        if (token.isEmpty) {
          await _clearSession(prefs);
          isLoggedIn = false;
        } else {
          // false = token ditolak server; null = tidak bisa dicek (offline).
          final valid = await _isSessionValid(token);
          if (valid == false) {
            await _clearSession(prefs);
            isLoggedIn = false;
          }
        }
      }

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
        if (!hasSeenOnboarding) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const OnboardingPage()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const RolePage()),
          );
        }
      }
    } catch (_) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const RolePage()),
      );
    }
  }

  /// true = sesi sah, false = ditolak (401), null = tidak bisa dipastikan
  /// karena jaringan/server bermasalah (pakai data lokal sebagai cadangan).
  Future<bool?> _isSessionValid(String token) async {
    try {
      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/api/profile'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 401) return false;
      if (response.statusCode == 200) return true;
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _clearSession(SharedPreferences prefs) async {
    for (final key in const [
      'isLoggedIn',
      'session_token',
      'user_id',
      'user_role',
      'user_name',
      'user_email',
      'user_phone',
      'user_address',
    ]) {
      await prefs.remove(key);
    }
    scheduleStore.reset();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AliceColors.primaryDark,
      body: Center(
        child: Semantics(
          label: 'Logo ALICE',
          child: const AliceFullLogo(width: 220),
        ),
      ),
    );
  }
}
