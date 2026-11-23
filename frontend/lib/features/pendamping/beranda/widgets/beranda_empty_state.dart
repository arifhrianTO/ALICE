import 'package:material_ui/material_ui.dart';

import '../../../../core/colors.dart';

// =====================================================================
//  TAMPILAN BERANDA SAAT BELUM ADA TUNANETRA TERHUBUNG
// =====================================================================
//
// Beranda tidak menampilkan peta, baterai, atau suhu yang kosong-kosong.
// Sebagai gantinya: kartu profil kosong, satu area penjelas, dan tombol
// untuk menautkan tunanetra. Bentuknya mengikuti wireframe.

/// Kartu profil saat belum ada tunanetra yang tertaut.
///
/// Bentuk dan warnanya sama dengan kartu profil biasa (ungu tua); hanya
/// saja belum ada nama/email yang bisa ditampilkan.
class EmptyTunanetraDropdown extends StatelessWidget {
  final VoidCallback? onTap;

  const EmptyTunanetraDropdown({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: kDarkPurple,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: kDarkPurple.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.12),
                border: Border.all(color: Colors.white54, width: 1.2),
              ),
              child: const Icon(
                Icons.person_outline,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Belum ada tunanetra',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Pilih tunanetra',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.white,
              size: 30,
            ),
          ],
        ),
      ),
    );
  }
}

/// Area besar pengganti peta saat belum ada tunanetra terhubung.
class EmptyTunanetraPlaceholder extends StatelessWidget {
  const EmptyTunanetraPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 320,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFEDECEF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDDBE3)),
      ),
      child: const Text(
        'Belum ada tunanetra\nyang terhubung',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, color: Colors.black45, height: 1.4),
      ),
    );
  }
}

/// Tombol ajakan menautkan tunanetra, selebar area konten, dengan penanda
/// merah kecil di sudut kanan atas (seperti pada wireframe).
class TautkanTunanetraButton extends StatelessWidget {
  final VoidCallback? onTap;

  const TautkanTunanetraButton({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          width: double.infinity,
          child: Material(
            color: const Color(0xFFEDECEF),
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onTap,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFDDDBE3)),
                ),
                child: const Text(
                  'Tautkan Tunanetra',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 12,
          top: -10,
          child: Container(
            width: 26,
            height: 26,
            decoration: const BoxDecoration(
              color: Color(0xFFE53935),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_add_alt_1,
              color: Colors.white,
              size: 15,
            ),
          ),
        ),
      ],
    );
  }
}
