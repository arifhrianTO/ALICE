import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/colors.dart';
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
  bool isRegister = false;
  final nameC = TextEditingController();
  final emailC = TextEditingController();
  final passC = TextEditingController();
  bool loading = false;
  String? error;

  @override
  void dispose() {
    nameC.dispose();
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

    if (isRegister && name.isEmpty) {
      setState(() => error = 'Mohon masukkan nama lengkap Anda.');
      return;
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
      // Simpan sesi login lokal ke SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('user_role', widget.role);
      await prefs.setString(
        'user_name',
        name.isNotEmpty
            ? name
            : (widget.role == 'tunanetra' ? 'Ahmad Pratama' : 'Budi Santoso'),
      );
      await prefs.setString(
        'user_email',
        email.isNotEmpty
            ? email
            : (widget.role == 'tunanetra'
                ? 'ahmad@example.com'
                : 'BudiSantoso@gmail.com'),
      );

      if (!mounted) return;

      // Navigasi sesuai role
      if (widget.role == 'tunanetra') {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const VoicePage()),
          (_) => false,
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeShell()),
          (_) => false,
        );
      }
    } catch (e) {
      setState(() => error = 'Terjadi kesalahan saat menyimpan sesi.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AliceColors.primaryDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isRegister ? 'Daftar Akun Baru' : 'Masuk dengan Email',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Sebagai ${_roleLabel(widget.role)}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 24),
              if (isRegister) ...[
                TextField(
                  controller: nameC,
                  style: const TextStyle(color: Colors.white),
                  decoration: _dec('Nama lengkap', Icons.person_outline),
                ),
                const SizedBox(height: 14),
              ],
              TextField(
                controller: emailC,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white),
                decoration: _dec('Email', Icons.email_outlined),
              ),
              TextField(
                controller: passC,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: _dec('Password (min 6 karakter)', Icons.lock_outline),
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(
                  error!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AliceColors.pinkMid,
                  foregroundColor: AliceColors.textPurple,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(40),
                  ),
                ),
                child: loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        isRegister ? 'Daftar & Masuk' : 'Masuk',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => setState(() {
                  isRegister = !isRegister;
                  error = null;
                }),
                child: Text(
                  isRegister
                      ? 'Sudah punya akun? Masuk'
                      : 'Belum punya akun? Daftar',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _dec(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white54, fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.white70, size: 20),
        filled: true,
        fillColor: Colors.white12,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      );
}
