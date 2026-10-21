import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/colors.dart';
import '../main.dart';
import '../tunanetra/voice_page.dart';
import '../widgets/alice_logo.dart';
import '../widgets/brand_icons.dart';
import '../widgets/pill_button.dart';
import 'email_login_page.dart';
import 'role_page.dart';

/// Halaman pilih metode masuk.
/// Menerima [role] dari halaman pilih peran.
class LoginPage extends StatelessWidget {
  final String role;
  const LoginPage({super.key, this.role = 'pendamping'});

  void _back(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const RolePage()),
      );
    }
  }

  /// Login simulasi untuk metode Google/Facebook (tanpa OAuth asli).
  Future<void> _mockLogin(BuildContext context, String provider) async {
    final isTunanetra = role == 'tunanetra';
    final name = isTunanetra ? 'Ahmad Pratama' : 'Budi Santoso';
    final email = isTunanetra
        ? 'ahmad@$provider.com'
        : 'budisantoso@$provider.com';

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('user_role', role);
    await prefs.setString('user_name', name);
    await prefs.setString('user_email', email);

    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => isTunanetra ? const VoicePage() : const HomeShell(),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AliceColors.primaryDark,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.topLeft,
                      child: PillButton(
                        text: 'Kembali',
                        wide: false,
                        icon: const Icon(Icons.arrow_back_ios, size: 13),
                        background: AliceColors.pinkMid,
                        onTap: () => _back(context),
                      ),
                    ),
                    const SizedBox(height: 36),
                    const AliceIconLogo(height: 100),
                    const SizedBox(height: 20),
                    const Text(
                      'Masuk untuk memulai\nperjalanan bersama ALICE!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 36),
                    PillButton(
                      text: 'Masuk dengan Akun Google',
                      background: Colors.white,
                      icon: const GoogleGIcon(),
                      alignLeft: true,
                      onTap: () => _mockLogin(context, 'google'),
                    ),
                    const SizedBox(height: 14),
                    PillButton(
                      text: 'Masuk dengan Email',
                      background: AliceColors.pinkMid,
                      icon: const EmailBadge(),
                      alignLeft: true,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EmailLoginPage(role: role),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    PillButton(
                      text: 'Masuk dengan Facebook',
                      background: AliceColors.blueLight,
                      icon: const FacebookBadge(),
                      alignLeft: true,
                      onTap: () => _mockLogin(context, 'facebook'),
                    ),
                    const Spacer(),
                    const SizedBox(height: 28),
                    RichText(
                      textAlign: TextAlign.center,
                      text: const TextSpan(
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          height: 1.5,
                        ),
                        children: [
                          TextSpan(
                            text:
                                'Dengan melanjutkan, Anda menyatakan bahwa Anda menyetujui ',
                          ),
                          TextSpan(
                            text: 'Persyaratan Layanan',
                            style: TextStyle(
                              color: Color(0xFFFF9EBB),
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          TextSpan(text: ' dan '),
                          TextSpan(
                            text: 'Kebijakan Privasi',
                            style: TextStyle(
                              color: Color(0xFFFF9EBB),
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          TextSpan(text: ' kami'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
