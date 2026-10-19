import 'package:flutter/material.dart';
import '../core/colors.dart';
import '../core/text.dart';

class RoleCard extends StatelessWidget {
  final String title;
  final String desc;
  final IconData icon;
  final Color circleColor;
  final VoidCallback onTap;
  const RoleCard({
    super.key,
    required this.title,
    required this.desc,
    required this.icon,
    required this.circleColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: circleColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: AliceColors.textPurple),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AliceText.cardTitle),
                  const SizedBox(height: 4),
                  Text(desc, style: AliceText.cardDesc),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
