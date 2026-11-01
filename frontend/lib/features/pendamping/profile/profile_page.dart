import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api_config.dart';
import '../../../core/colors.dart';
import '../../auth/role_page.dart';

const _kPinkButton = Color(0xFFFFDAD6);
const _kRed = Color(0xFFE50000);

class ProfilePage extends StatefulWidget {
  final String? initialName;
  final String? initialEmail;
  final String? initialRole;

  const ProfilePage({
    super.key,
    this.initialName,
    this.initialEmail,
    this.initialRole,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _name = '';
  String _email = '';
  String _phone = '';
  String _address = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  /// Ambil profil dari backend. Kalau server tidak bisa dihubungi (atau
  /// pengguna masuk lewat mock Google/Facebook yang belum punya token),
  /// data lokal di SharedPreferences tetap dipakai sebagai cadangan.
  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();

    var name = prefs.getString('user_name') ?? widget.initialName ?? '';
    var email = prefs.getString('user_email') ?? widget.initialEmail ?? '';
    var phone = prefs.getString('user_phone') ?? '';
    var address = prefs.getString('user_address') ?? '';

    final token = prefs.getString('session_token') ?? '';
    if (token.isNotEmpty) {
      try {
        final response = await http.get(
          Uri.parse('${ApiConfig.baseUrl}/api/profile'),
          headers: {'Authorization': 'Bearer $token'},
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final profile = data['data'] as Map<String, dynamic>? ?? {};

          name = profile['name'] as String? ?? name;
          email = profile['email'] as String? ?? email;
          phone = profile['phone_number'] as String? ?? phone;
          address = profile['address'] as String? ?? address;

          // Simpan salinan lokal supaya halaman tetap terisi saat offline.
          await prefs.setString('user_name', name);
          await prefs.setString('user_email', email);
          await prefs.setString('user_phone', phone);
          await prefs.setString('user_address', address);
        }
      } catch (_) {
        // Server mati / tidak ada jaringan: lanjut dengan data lokal.
      }
    }

    if (!mounted) return;
    setState(() {
      _name = name;
      _email = email;
      _phone = phone;
      _address = address;
      _loading = false;
    });
  }

  /// Simpan perubahan ke backend, lalu ke salinan lokal.
  ///
  /// Mengembalikan false kalau backend menolak, supaya dialog tidak
  /// tertutup dan pengguna bisa memperbaiki isiannya.
  Future<bool> _saveProfile(String name, String phone, String address) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('session_token') ?? '';

    if (token.isNotEmpty) {
      try {
        final response = await http.put(
          Uri.parse('${ApiConfig.baseUrl}/api/profile'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'name': name,
            'phone_number': phone,
            'address': address,
          }),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode != 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          _showMessage(
              data['message'] as String? ?? 'Gagal menyimpan profil.');
          return false;
        }
      } catch (_) {
        _showMessage('Gagal menghubungi server. Silakan coba lagi.');
        return false;
      }
    }

    await prefs.setString('user_name', name);
    await prefs.setString('user_phone', phone);
    await prefs.setString('user_address', address);

    if (!mounted) return true;
    setState(() {
      _name = name;
      _phone = phone;
      _address = address;
    });
    return true;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _filled(String value) =>
      value.trim().isEmpty ? 'Belum diisi' : value;

  /// Sama dengan aturan backend: buang spasi/tanda hubung, lalu terima
  /// nomor yang diawali "+" dan berisi 9–15 digit.
  bool _isValidPhone(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^0-9+]'), '');
    return RegExp(r'^\+?[0-9]{9,15}$').hasMatch(cleaned);
  }

  Future<void> _showEditDialog() async {
    final nameCtrl = TextEditingController(text: _name);
    final phoneCtrl = TextEditingController(text: _phone);
    final addressCtrl = TextEditingController(text: _address);

    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Ubah Profil',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: kDarkPurple)),
              const SizedBox(height: 16),
              _label('Nama Pengguna'),
              _field(nameCtrl),
              const SizedBox(height: 12),
              _label('Nomor Telepon'),
              _field(phoneCtrl, keyboardType: TextInputType.phone),
              const SizedBox(height: 12),
              _label('Alamat'),
              _field(addressCtrl, maxLines: 4),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _button('Batal', kLightPurple, kDarkPurple,
                      () => Navigator.pop(ctx)),
                  const SizedBox(width: 12),
                  _button('Ubah', kPurple, Colors.white, () async {
                    final name = nameCtrl.text.trim();
                    final phone = phoneCtrl.text.trim();
                    final address = addressCtrl.text.trim();

                    if (name.isEmpty) {
                      _showMessage('Nama pengguna wajib diisi.');
                      return;
                    }
                    if (!_isValidPhone(phone)) {
                      _showMessage('Mohon masukkan nomor telepon yang valid.');
                      return;
                    }
                    if (address.length > 255) {
                      _showMessage('Alamat maksimal 255 karakter.');
                      return;
                    }

                    final saved = await _saveProfile(name, phone, address);
                    if (saved && ctx.mounted) Navigator.pop(ctx);
                  }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showLogoutDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Yakin ingin keluar?',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: kDarkPurple)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _button('Batal', kLightPurple, kDarkPurple,
                      () => Navigator.pop(ctx, false),
                      width: 100),
                  const SizedBox(width: 16),
                  _button('Keluar', kPurple, Colors.white, () {
                    Navigator.pop(ctx, true);
                  }, width: 100),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm != true) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const RolePage()),
      (_) => false,
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: kDarkPurple)),
      );

  Widget _field(TextEditingController c,
      {int maxLines = 1, TextInputType? keyboardType}) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade300),
    );
    return TextField(
      controller: c,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(color: kTextPurple, fontSize: 15),
      decoration: InputDecoration(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: border,
        focusedBorder: border.copyWith(
            borderSide: const BorderSide(color: kPurple)),
      ),
    );
  }

  Widget _button(String text, Color bg, Color fg, VoidCallback onTap,
      {double? width}) {
    return SizedBox(
      width: width,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child:
            Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _infoCard(IconData icon, String text,
      {Color? iconColor, Color? textColor, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: kFieldBg,
        elevation: 2,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
            child: Row(
              children: [
                Icon(icon, color: iconColor ?? kPurple, size: 28),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(text,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: textColor ?? kTextPurple)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 6, bottom: 16),
            child: Text('Profil',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: kDarkPurple)),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: kDarkPurple,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.white,
                  backgroundImage: AssetImage('assets/icons/profil.png'),
                ),
                const SizedBox(height: 16),
                Text(
                    _loading
                        ? 'Memuat...'
                        : (_name.trim().isEmpty ? 'Pengguna' : _name),
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _showEditDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPinkButton,
                    foregroundColor: kDarkPurple,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                  child: const Text('Ubah Profil',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _infoCard(Icons.mail, _loading ? '...' : _filled(_email)),
          _infoCard(Icons.phone, _filled(_phone)),
          _infoCard(Icons.location_on, _filled(_address)),
          _infoCard(Icons.logout, 'Keluar',
              iconColor: _kRed,
              textColor: _kRed,
              onTap: _showLogoutDialog),
        ],
      ),
    );
  }
}