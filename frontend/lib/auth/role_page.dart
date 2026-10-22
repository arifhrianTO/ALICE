import 'package:flutter/material.dart';
import '../core/colors.dart';
import '../widgets/alice_logo.dart';
import '../widgets/role_card.dart';
import 'login_page.dart';

/// pilih peran, lalu ke halaman metode masuk.
class RolePage extends StatelessWidget {
  const RolePage({super.key});

  void _go(BuildContext context, String role) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LoginPage(role: role)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AliceColors.primaryDark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            children: [
              const SizedBox(height: 16),
              const AliceIconLogo(height: 90),
              const SizedBox(height: 20),
              const Text(
                'Selamat datang!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ayo mulai perjalananmu bersama ALICE!\nKamu mau masuk sebagai apa?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
              RoleCard(
                title: 'Penyandang Tunanetra',
                desc: 'Dapatkan informasi harian, kelola jadwal, dan berinteraksi melalui suara bersama ALICE.',
                iconPath: 'assets/icons/user_role_page.png',
                circleColor: AliceColors.pinkMid,
                onTap: () => _go(context, 'tunanetra'),
              ),
              const SizedBox(height: 34),
              RoleCard(
                title: 'Pendamping',
                desc: 'Terhubung dengan penyandang tunanetra dan bantu memantau serta mengatur jadwal.',
                iconPath: 'assets/icons/handshake.png',
                circleColor: AliceColors.blueLight,
                onTap: () => _go(context, 'pendamping'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
