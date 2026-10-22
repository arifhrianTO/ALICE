import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/role_page.dart';
import '../core/colors.dart';

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
  String _name = 'Budi Santoso';
  String _email = 'BudiSantoso@gmail.com';
  String _phone = '08123456789';
  String _address =
      'Jl. Ahmad Yani, Tlk. Tering, Kec. Batam Kota, Kota Batam, Kepulauan Riau 29461';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _name = prefs.getString('user_name') ?? widget.initialName ?? _name;
      _email = prefs.getString('user_email') ?? widget.initialEmail ?? _email;
      _phone = prefs.getString('user_phone') ?? _phone;
      _address = prefs.getString('user_address') ?? _address;
      _loading = false;
    });
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
              _field(
                phoneCtrl,
                keyboardType: TextInputType.phone,
                suffix: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD6F5D6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_outlined,
                          size: 10, color: Color(0xFF2E7D32)),
                      SizedBox(width: 2),
                      Text('Disetujui',
                          style: TextStyle(
                              fontSize: 9, color: Color(0xFF2E7D32))),
                    ],
                  ),
                ),
              ),
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
                    final prefs = await SharedPreferences.getInstance();
                    final name = nameCtrl.text.trim();
                    final phone = phoneCtrl.text.trim();
                    final address = addressCtrl.text.trim();
                    await prefs.setString('user_name', name);
                    await prefs.setString('user_phone', phone);
                    await prefs.setString('user_address', address);
                    if (mounted) {
                      setState(() {
                        _name = name.isEmpty ? _name : name;
                        _phone = phone;
                        _address = address;
                      });
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
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
      {int maxLines = 1, Widget? suffix, TextInputType? keyboardType}) {
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
        suffixIcon: suffix == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(right: 10),
                child: suffix,
              ),
        suffixIconConstraints: const BoxConstraints(minHeight: 0, minWidth: 0),
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
                Text(_loading ? 'Memuat...' : _name,
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
          _infoCard(Icons.mail, _loading ? '...' : _email),
          _infoCard(Icons.phone, _phone),
          _infoCard(Icons.location_on, _address),
          _infoCard(Icons.logout, 'Keluar',
              iconColor: _kRed,
              textColor: _kRed,
              onTap: _showLogoutDialog),
        ],
      ),
    );
  }
}