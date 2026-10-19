import 'package:flutter/material.dart';

/// Huruf "G" tegas warna gelap seperti di desain halaman masuk.
class GoogleGIcon extends StatelessWidget {
  final double size;
  const GoogleGIcon({super.key, this.size = 22});

  @override
  Widget build(BuildContext context) {
    return Text(
      'G',
      style: TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w900,
        color: const Color(0xFF1F1F39),
        height: 1,
      ),
    );
  }
}

/// Logo Facebook: huruf "f" putih di atas kotak biru rounded.
class FacebookBadge extends StatelessWidget {
  final double size;
  const FacebookBadge({super.key, this.size = 22});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF1877F2),
        borderRadius: BorderRadius.circular(size * 0.22),
      ),
      alignment: Alignment.center,
      child: Text(
        'f',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: size * 0.72,
          height: 1,
        ),
      ),
    );
  }
}

/// Ikon amplop merah seperti di desain tombol Email.
class EmailBadge extends StatelessWidget {
  final double size;
  const EmailBadge({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.email, color: const Color(0xFFE05252), size: size);
  }
}
