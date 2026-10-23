import 'package:flutter/material.dart';

import '../../core/colors.dart';
import '../../core/text.dart';
import '../../widgets/alice_logo.dart';
import 'login_page.dart';

/// Pilih peran, lalu ke halaman metode masuk.
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
              _RoleCard(
                title: 'Penyandang Tunanetra',
                desc: 'Dapatkan informasi harian, kelola jadwal, dan berinteraksi melalui suara bersama ALICE.',
                iconPath: 'assets/icons/user_role_page.png',
                circleColor: AliceColors.pinkMid,
                onTap: () => _go(context, 'tunanetra'),
              ),
              const SizedBox(height: 34),
              _RoleCard(
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

class _RoleCard extends StatelessWidget {
  final String title;
  final String desc;
  final String iconPath;
  final Color circleColor;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.desc,
    required this.iconPath,
    required this.circleColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 157,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              // Lingkaran warna di sebelah kiri card
              Positioned(
                left: -73,
                top: -18,
                bottom: -18,
                width: 175,
                child: Container(
                  decoration: BoxDecoration(
                    color: circleColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),

              // Icon PNG
              Positioned(
                left: -10,
                top: 0,
                bottom: 0,
                width: 100,
                child: Center(
                  child: Image.asset(
                    iconPath,
                    width: 100,
                    height: 100,
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              // Judul dan deskripsi di sebelah kanan icon
              Positioned(
                left: 115,
                right: 14,
                top: 0,
                bottom: 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AliceText.cardTitle.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        desc,
                        style: AliceText.cardDesc.copyWith(
                          fontSize: 13,
                          color: Colors.black87,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
