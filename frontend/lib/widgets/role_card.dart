
import 'package:flutter/material.dart';
import '../core/text.dart';

class RoleCard extends StatelessWidget {
  final String title;
  final String desc;
  final String iconPath;
  final Color circleColor;
  final VoidCallback onTap;

  const RoleCard({
    super.key,
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
