import 'package:flutter/material.dart';

/// Ikon Google dari aset (assets/icons/Google.png).
class GoogleGIcon extends StatelessWidget {
  final double size;
  const GoogleGIcon({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/icons/Google.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}

/// Ikon Facebook dari aset (assets/icons/Facebook.png).
class FacebookBadge extends StatelessWidget {
  final double size;
  const FacebookBadge({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/icons/Facebook.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}

/// Ikon amplop dari aset (assets/icons/Email.png).
class EmailBadge extends StatelessWidget {
  final double size;
  const EmailBadge({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/icons/Email.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}
