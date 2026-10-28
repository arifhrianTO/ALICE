import 'package:flutter/material.dart';

import 'email_login_page.dart';
import 'role_page.dart';

/// Halaman pilih metode masuk.
/// Menerima [role] dari halaman pilih peran.
class LoginPage extends StatelessWidget {
  final String role;
  const LoginPage({super.key, this.role = 'pendamping'});

  // Warna sesuai desain
  static const _bg = Color(0xFF46337E);
  static const _ink = Color(0xFF46337E); // teks & ikon tombol
  static const _pink = Color(0xFFFFDADA);
  static const _lavender = Color(0xFFDEDDFF);
  static const _link = Color(0xFFFF9E9E);

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

  void _showOAuthUnavailable(BuildContext context, String provider) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Masuk dengan $provider belum tersedia. Silakan gunakan Masuk dengan Email.',
        ),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const footerStyle = TextStyle(
      color: Colors.white,
      fontSize: 16,
      height: 1.45,
    );
    final linkStyle = footerStyle.copyWith(
      color: _link,
      decoration: TextDecoration.underline,
      decorationColor: _link,
    );

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const SizedBox(height: 38),

              // Tombol Kembali
              Align(
                alignment: Alignment.topLeft,
                child: Transform.translate(
                  offset: const Offset(-21, 0),
                  child: _BackPill(onTap: () => _back(context)),
                ),
              ),

              const SizedBox(height: 40),

              // Logo
              Image.asset(
                'assets/icons/logo_icon.png',
                height: 150,
                fit: BoxFit.contain,
              ),

              const SizedBox(height: 10),

              const Text(
                'Masuk untuk memulai\nperjalanan bersama ALICE!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),

              const SizedBox(height: 56),

              _LoginButton(
                text: 'Masuk dengan Akun Google',
                background: Colors.white,
                icon: Image.asset(
                  'assets/icons/Google.png',
                  width: 40,
                  height: 40,
                  fit: BoxFit.contain,
                ),
                onTap: () => _showOAuthUnavailable(context, 'Google'),
              ),

              const SizedBox(height: 22),
              _LoginButton(
                text: 'Masuk dengan Email',
                background: _pink,
                icon: const Icon(Icons.email,
                    color: Color(0xFFD94545), size: 30),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => EmailLoginPage(role: role)),
                ),
              ),

              const SizedBox(height: 22),
              _LoginButton(
                text: 'Masuk dengan Facebook',
                background: _lavender,
                icon: Image.asset(
                  'assets/icons/Facebook.png',
                  width: 40,
                  height: 40,
                  fit: BoxFit.contain,
                ),
                onTap: () => _showOAuthUnavailable(context, 'Facebook'),
              ),

              const SizedBox(height: 52),

              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: footerStyle,
                  children: [
                    const TextSpan(
                      text:
                          'Dengan melanjutkan, Anda menyatakan bahwa bahwa Anda menyetujui ',
                    ),
                    TextSpan(text: 'Persyaratan Layanan', style: linkStyle),
                    const TextSpan(text: ' dan '),
                    TextSpan(text: 'Kebijakan Privasi', style: linkStyle),
                    const TextSpan(text: ' kami'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tombol "Kembali" berbentuk pil.
class _BackPill extends StatelessWidget {
  final VoidCallback onTap;
  const _BackPill({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: LoginPage._pink,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_back_ios_new,
                  size: 12, color: LoginPage._ink),
              SizedBox(width: 8),
              Text(
                'Kembali',
                style: TextStyle(
                  color: LoginPage._ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tombol login lebar: ikon di kiri, teks rata kiri setelah ikon.
class _LoginButton extends StatelessWidget {
  final String text;
  final Color background;
  final Widget icon;
  final VoidCallback onTap;

  const _LoginButton({
    required this.text,
    required this.background,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: SizedBox(
          height: 55,
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.only(left: 20, right: 12,),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Center(child: icon),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: LoginPage._ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
