import 'package:material_ui/material_ui.dart';

import '../../../../core/colors.dart';
import '../tautkan_tunanetra_data.dart';

// =====================================================================
//  POP UP TAUTKAN TUNANETRA
// =====================================================================

/// Menampilkan pop up konfirmasi tautkan.
/// Mengembalikan `true` jika user menekan "Tautkan".
Future<bool> showTautkanDialog(BuildContext context, Tunanetra person) async {
  final ok = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Tutup',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (_, _, _) => _TautkanDialog(person: person),
    transitionBuilder: (context, anim, _, child) {
      final curved = CurvedAnimation(
        parent: anim,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeIn,
      );
      return FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
  return ok == true;
}

/// Snackbar notifikasi berhasil.
void showTautkanSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: kDarkPurple,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
}

class _TautkanDialog extends StatelessWidget {
  final Tunanetra person;

  const _TautkanDialog({required this.person});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Material(
            color: kFieldBg,
            elevation: 6,
            shadowColor: Colors.black38,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ---- Ikon link dalam lingkaran ungu tua ----
                  Container(
                    width: 120,
                    height: 120,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: kTitleIndigo,
                      shape: BoxShape.circle,
                    ),
                    child: Image.asset(
                      'assets/icons/link.png',
                      width: 70,
                      height: 70,
                      color: Colors.white,
                      // Cadangan bila aset gagal dimuat
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.link_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ---- Teks konfirmasi ----
                  const Text(
                    'Apakah ada ingin bertaut dengan',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${person.name}?',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ---- Tombol ----
                  Row(
                    children: [
                      Expanded(
                        child: _DialogBtn(
                          label: 'Batal',
                          background: kBtnLight,
                          foreground: kTitleIndigo,
                          onTap: () => Navigator.of(context).pop(false),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _DialogBtn(
                          label: 'Tautkan',
                          background: kPurple,
                          foreground: Colors.white,
                          onTap: () => Navigator.of(context).pop(true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogBtn extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  const _DialogBtn({
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            height: 44,
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}