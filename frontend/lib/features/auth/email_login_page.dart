import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api_config.dart';
import '../../main.dart';
import '../tunanetra/voice_page.dart';

/// Form login/registrasi dengan email.
/// Menerima [role] dari halaman sebelumnya dan menyimpan sesi lokal.
class EmailLoginPage extends StatefulWidget {
  final String role;
  const EmailLoginPage({super.key, this.role = 'pendamping'});

  @override
  State<EmailLoginPage> createState() => _EmailLoginPageState();
}

class _EmailLoginPageState extends State<EmailLoginPage> {
  static const _bg = Color(0xFF46337E);
  static const _ink = Color(0xFF46337E);
  static const _pink = Color(0xFFFFDADA);
  static const _fieldFill = Colors.white12;

  bool isRegister = false;
  bool obscurePassword = true;

  final nameC = TextEditingController();
  final phoneC = TextEditingController();
  final addressC = TextEditingController();
  final emailC = TextEditingController();
  final passC = TextEditingController();

  bool loading = false;
  String? error;

  @override
  void dispose() {
    nameC.dispose();
    phoneC.dispose();
    addressC.dispose();
    emailC.dispose();
    passC.dispose();
    super.dispose();
  }

  String _roleLabel(String r) =>
      r == 'tunanetra' ? 'Penyandang Tunanetra' : 'Pendamping';

  Future<void> _submit() async {
    final email = emailC.text.trim();
    final pass = passC.text;
    final name = nameC.text.trim();
    final phone = phoneC.text.trim();
    final address = addressC.text.trim();

    if (isRegister) {
      if (name.isEmpty) {
        setState(() => error = 'Mohon masukkan nama lengkap Anda.');
        return;
      }
      if (phone.isEmpty) {
        setState(() => error = 'Mohon masukkan nomor HP / WhatsApp Anda.');
        return;
      }
      if (address.isEmpty) {
        setState(() => error = 'Mohon masukkan alamat tempat tinggal Anda.');
        return;
      }
    }

    if (email.isEmpty) {
      setState(() => error = 'Mohon masukkan alamat email.');
      return;
    }
    if (pass.length < 6) {
      setState(() => error = 'Password minimal 6 karakter.');
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final endpoint = isRegister ? '/api/auth/register' : '/api/auth/login';
      final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      final body = isRegister
          ? {
              'name': name,
              'email': email,
              'password': pass,
              'role': widget.role,
              'phone_number': phone,
              'address': address,
            }
          : {
              'email': email,
              'password': pass,
            };

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200 && response.statusCode != 201) {
        final msg = data['message'] as String? ??
            'Permintaan gagal (${response.statusCode})';
        setState(() => error = msg);
        return;
      }

      final payload = data['data'] as Map<String, dynamic>? ?? {};
      final user = payload['user'] as Map<String, dynamic>? ?? {};
      final token = payload['token'] as String? ?? '';
      final userName = user['name'] as String? ?? name;
      final userEmail = user['email'] as String? ?? email;
      final userRole = user['role'] as String? ?? widget.role;
      final userPhone = user['phone_number'] as String? ?? phone;
      final userAddress = user['address'] as String? ?? address;

      // Simpan sesi login lokal ke SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('session_token', token);
      await prefs.setString('user_role', userRole);
      await prefs.setString('user_name', userName);
      await prefs.setString('user_email', userEmail);
      if (userPhone.isNotEmpty) {
        await prefs.setString('user_phone', userPhone);
      }
      if (userAddress.isNotEmpty) {
        await prefs.setString('user_address', userAddress);
      }

      if (!mounted) return;

      // Navigasi sesuai role
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
            builder: (_) => HomeShell(
              name: userName,
              email: userEmail,
              role: userRole,
            ),
          ),
          (_) => false,
        );
      }
    } catch (e) {
      setState(() =>
          error = 'Gagal menghubungi server. Pastikan backend sedang berjalan.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),

              // Tombol Kembali
              Align(
                alignment: Alignment.topLeft,
                child: Semantics(
                  button: true,
                  label: 'Kembali',
                  hint: 'Ketuk dua kali untuk kembali ke halaman sebelumnya',
                  excludeSemantics: true,
                  child: Material(
                    color: _pink,
                    shape: const StadiumBorder(),
                    child: InkWell(
                      customBorder: const StadiumBorder(),
                      onTap: () => Navigator.pop(context),
                      child: const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.arrow_back_ios_new,
                                size: 12, color: _ink),
                            SizedBox(width: 8),
                            Text(
                              'Kembali',
                              style: TextStyle(
                                color: _ink,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Logo ALICE
              Semantics(
                label: 'Logo ALICE',
                child: Image.asset(
                  'assets/icons/logo_icon.png',
                  height: 90,
                  fit: BoxFit.contain,
                ),
              ),

              const SizedBox(height: 16),

              // Judul & Peran
              Text(
                isRegister ? 'Daftar Akun Baru' : 'Masuk dengan Email',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Sebagai ${_roleLabel(widget.role)}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 28),

              // Form fields
              if (isRegister) ...[
                Semantics(
                  label: 'Kolom input nama lengkap',
                  textField: true,
                  child: TextField(
                    controller: nameC,
                    textInputAction: TextInputAction.next,
                    style: const TextStyle(color: Colors.white),
                    decoration: _dec(
                      hint: 'Nama lengkap',
                      label: 'Nama Lengkap',
                      icon: Icons.person_outline,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Semantics(
                  label: 'Kolom input nomor HP atau WhatsApp',
                  textField: true,
                  child: TextField(
                    controller: phoneC,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    style: const TextStyle(color: Colors.white),
                    decoration: _dec(
                      hint: 'Contoh: 081234567890',
                      label: 'Nomor HP / WhatsApp',
                      icon: Icons.phone_outlined,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Semantics(
                  label: 'Kolom input alamat lengkap',
                  textField: true,
                  child: TextField(
                    controller: addressC,
                    maxLines: 2,
                    textInputAction: TextInputAction.next,
                    style: const TextStyle(color: Colors.white),
                    decoration: _dec(
                      hint: 'Alamat tempat tinggal',
                      label: 'Alamat Lengkap',
                      icon: Icons.location_on_outlined,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Email
              Semantics(
                label: 'Kolom input email',
                textField: true,
                child: TextField(
                  controller: emailC,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(color: Colors.white),
                  decoration: _dec(
                    hint: 'email@contoh.com',
                    label: 'Alamat Email',
                    icon: Icons.email_outlined,
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Password dengan Show/Hide toggle
              Semantics(
                label: 'Kolom input kata sandi',
                textField: true,
                child: TextField(
                  controller: passC,
                  obscureText: obscurePassword,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  style: const TextStyle(color: Colors.white),
                  decoration: _dec(
                    hint: 'Minimal 6 karakter',
                    label: 'Kata Sandi',
                    icon: Icons.lock_outline,
                    suffix: IconButton(
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: Colors.white70,
                        size: 20,
                      ),
                      tooltip: obscurePassword
                          ? 'Tampilkan kata sandi'
                          : 'Sembunyikan kata sandi',
                      onPressed: () => setState(
                          () => obscurePassword = !obscurePassword),
                    ),
                  ),
                ),
              ),

              // Error banner jika ada
              if (error != null) ...[
                const SizedBox(height: 16),
                Semantics(
                  liveRegion: true,
                  label: 'Peringatan: $error',
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade900.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.redAccent.shade100),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.white, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            error!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 28),

              // Tombol Submit
              Semantics(
                button: true,
                label: loading
                    ? 'Sedang memproses data'
                    : (isRegister ? 'Daftar dan Masuk' : 'Masuk'),
                hint: 'Ketuk dua kali untuk mengirim formulir',
                child: ElevatedButton(
                  onPressed: loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _pink,
                    foregroundColor: _ink,
                    disabledBackgroundColor: _pink.withValues(alpha: 0.6),
                    minimumSize: const Size.fromHeight(54),
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: loading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: _ink,
                          ),
                        )
                      : Text(
                          isRegister ? 'Daftar & Masuk' : 'Masuk',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // Tombol Toggle Register / Login
              Semantics(
                button: true,
                label: isRegister
                    ? 'Sudah punya akun? Masuk'
                    : 'Belum punya akun? Daftar',
                hint: 'Ketuk dua kali untuk beralih mode formulir',
                child: TextButton(
                  onPressed: () => setState(() {
                    isRegister = !isRegister;
                    error = null;
                  }),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: Text(
                    isRegister
                        ? 'Sudah punya akun? Masuk di sini'
                        : 'Belum punya akun? Daftar sekarang',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white70,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _dec({
    required String hint,
    required String label,
    required IconData icon,
    Widget? suffix,
  }) =>
      InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70, fontSize: 14),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.white70, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: _fieldFill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _pink, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      );
}
