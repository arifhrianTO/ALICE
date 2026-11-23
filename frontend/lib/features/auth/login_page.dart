import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api_config.dart';
import '../../core/notification_service.dart';
import '../../main.dart';
import '../tunanetra/voice_page.dart';
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

  // Web Application client ID — dipakai sebagai serverClientId supaya
  // idToken di-generate dengan aud yang cocok untuk backend.
  static const _serverClientId =
      '562542839875-2le8jkh5cglu0n5fggfhv7njc6polhs7.apps.googleusercontent.com';

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

  /// Login Google OAuth asli.
  Future<void> _googleLogin(BuildContext context) async {
    final googleSignIn = GoogleSignIn(
      // Di web, google_sign_in memakai `clientId` (Web OAuth client).
      // Di Android, `serverClientId` yang menentukan aud idToken.
      clientId: kIsWeb ? _serverClientId : null,
      serverClientId: _serverClientId,
      scopes: ['email', 'profile'],
    );

    try {
      final account = await googleSignIn.signIn();
      if (account == null) return; // user batal

      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal mendapatkan token Google.')),
          );
        }
        return;
      }

      final url = Uri.parse('${ApiConfig.baseUrl}/api/auth/google');
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'id_token': idToken, 'role': role}),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200) {
        final msg =
            data['message'] as String? ??
            'Login gagal (${response.statusCode})';
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(msg)));
        }
        return;
      }

      final payload = data['data'] as Map<String, dynamic>? ?? {};
      final user = payload['user'] as Map<String, dynamic>? ?? {};
      final token = payload['token'] as String? ?? '';
      final userID = user['user_id'] as String? ?? '';
      final userName = user['name'] as String? ?? account.displayName ?? '';
      final userEmail = user['email'] as String? ?? account.email;
      final userRole = user['role'] as String? ?? role;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('session_token', token);
      await prefs.setString('user_id', userID);
      await prefs.setString('user_role', userRole);
      await prefs.setString('user_name', userName);
      await prefs.setString('user_email', userEmail);

      // Daftarkan HP ini supaya bisa menerima notifikasi atas nama akun
      // yang baru saja masuk.
      await NotificationService.registerCurrentDevice();

      if (!context.mounted) return;

      if (userRole == 'tunanetra') {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const VoicePage()),
          (_) => false,
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) =>
                HomeShell(name: userName, email: userEmail, role: userRole),
          ),
          (_) => false,
        );
      }
    } catch (e) {
      debugPrint('Google login gagal: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menghubungi server. Coba lagi.')),
        );
      }
    }
  }

  /// Login Facebook memakai SDK resmi, lalu menukar access token ke backend.
  Future<void> _loginWithFacebook(BuildContext context) async {
    LoginResult result;
    try {
      result = await FacebookAuth.instance.login(
        permissions: const ['email', 'public_profile'],
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Facebook tidak bisa dibuka: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (result.status == LoginStatus.cancelled) return;

    if (result.status != LoginStatus.success || result.accessToken == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? 'Login Facebook gagal.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final accessToken = result.accessToken!;
    final accessTokenValue = accessToken.tokenString;
    // iOS memakai Limited Login (JWT OIDC) bila ATT tidak diberikan.
    final tokenType = accessToken is LimitedToken ? 'limited' : 'classic';

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator(color: Colors.white)),
    );

    var loadingVisible = true;
    void closeLoading() {
      if (!loadingVisible || !context.mounted) return;
      loadingVisible = false;
      Navigator.of(context, rootNavigator: true).pop();
    }

    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/api/auth/facebook');
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'access_token': accessTokenValue,
              'token_type': tokenType,
              'role': role,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (!context.mounted) return;
      closeLoading();

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200 && response.statusCode != 201) {
        final msg =
            data['message'] as String? ??
            'Login Facebook gagal (${response.statusCode})';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
        );
        return;
      }

      final payload = data['data'] as Map<String, dynamic>? ?? {};
      final user = payload['user'] as Map<String, dynamic>? ?? {};
      final sessionToken = payload['token'] as String? ?? '';
      final userID = user['user_id'] as String? ?? '';
      final userName = user['name'] as String? ?? 'Pengguna Facebook';
      final userEmail = user['email'] as String? ?? '';
      final userRole = user['role'] as String? ?? role;
      final userPhone = user['phone_number'] as String? ?? '';
      final userAddress = user['address'] as String? ?? '';

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('session_token', sessionToken);
      await prefs.setString('user_id', userID);
      await prefs.setString('user_role', userRole);
      await prefs.setString('user_name', userName);
      await prefs.setString('user_email', userEmail);
      if (userPhone.isNotEmpty) {
        await prefs.setString('user_phone', userPhone);
      }
      if (userAddress.isNotEmpty) {
        await prefs.setString('user_address', userAddress);
      }

      if (!context.mounted) return;

      final isTunanetra = userRole == 'tunanetra';
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => isTunanetra ? const VoicePage() : const HomeShell(),
        ),
        (_) => false,
      );
    } catch (e) {
      closeLoading();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Koneksi ke backend gagal: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
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
              Semantics(
                label: 'Logo aplikasi ALICE',
                image: true,
                child: Image.asset(
                  'assets/icons/logo_icon.png',
                  height: 150,
                  fit: BoxFit.contain,
                ),
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
                onTap: () => _googleLogin(context),
              ),

              if (role != 'tunanetra') ...[
                const SizedBox(height: 22),
                _LoginButton(
                  text: 'Masuk dengan Email',
                  background: _pink,
                  icon: const Icon(
                    Icons.email,
                    color: Color(0xFFD94545),
                    size: 30,
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EmailLoginPage(role: role),
                    ),
                  ),
                ),
              ],

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
                onTap: () => _loginWithFacebook(context),
              ),

              const SizedBox(height: 52),

              Semantics(
                label: 'Dengan melanjutkan, Anda menyatakan bahwa Anda menyetujui Persyaratan Layanan dan Kebijakan Privasi kami',
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: footerStyle,
                    children: [
                      const TextSpan(
                        text: 'Dengan melanjutkan, Anda menyatakan bahwa bahwa Anda menyetujui ',
                      ),
                      TextSpan(text: 'Persyaratan Layanan', style: linkStyle),
                      const TextSpan(text: ' dan '),
                      TextSpan(text: 'Kebijakan Privasi', style: linkStyle),
                      const TextSpan(text: ' kami'),
                    ],
                  ),
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
    return Semantics(
      button: true,
      label: 'Kembali',
      hint: 'Ketuk dua kali untuk kembali ke pemilihan peran',
      excludeSemantics: true,
      child: Material(
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
                Icon(Icons.arrow_back_ios_new, size: 12, color: LoginPage._ink),
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
    return Semantics(
      button: true,
      label: text,
      hint: 'Ketuk dua kali untuk $text',
      excludeSemantics: true,
      child: Material(
        color: background,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: SizedBox(
            height: 55,
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.only(left: 20, right: 12),
              child: Row(
                children: [
                  SizedBox(width: 28, child: Center(child: icon)),
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
      ),
    );
  }
}
