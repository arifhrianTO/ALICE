import 'package:flutter/material.dart';

import '../core/colors.dart';

class Avatar extends StatelessWidget {
  final double radius;
  const Avatar({super.key, required this.radius});

  @override
  Widget build(BuildContext context) {
    // Ganti dengan backgroundImage: AssetImage('assets/profile.jpg') jika ada fotonya
    return CircleAvatar(
      radius: radius,
      backgroundColor: kLightPurple,
      child: Icon(Icons.person, size: radius * 1.3, color: kDarkPurple),
    );
  }
}
