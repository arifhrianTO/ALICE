import 'package:material_ui/material_ui.dart';

/// Logo teks ALICE full (assets/icons/logo_full.png) — dipakai di splash.
class AliceFullLogo extends StatelessWidget {
  final double width;
  const AliceFullLogo({super.key, this.width = 200});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/icons/logo_full.png',
      width: width,
      fit: BoxFit.contain,
      semanticLabel: 'ALICE',
    );
  }
}

/// Ikon "A" saja (assets/icons/logo_icon.png) — dipakai di login & pilih peran.
class AliceIconLogo extends StatelessWidget {
  final double height;
  const AliceIconLogo({super.key, this.height = 90});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/icons/logo_icon.png',
      height: height,
      fit: BoxFit.contain,
      semanticLabel: 'Logo ALICE',
    );
  }
}
