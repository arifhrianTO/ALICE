import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/colors.dart';
import '../jadwal/jadwal_dialogs.dart';
import 'tambah_tunanetra_data.dart';

// =====================================================================
//  POP UP KONFIRMASI TAUTKAN
// =====================================================================

/// Pop up "Apakah ada ingin bertaut dengan [nama]?"
/// Mengembalikan true kalau tombol "Tautkan" ditekan.
Future<bool> showTautkanDialog(BuildContext context, Tunanetra person) async {
  final ok = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Tutup',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (_, _, _) => TautkanDialog(person: person),
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
  return ok ?? false;
}

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

/// Isi pop up konfirmasi.
class TautkanDialog extends StatelessWidget {
  final Tunanetra person;

  const TautkanDialog({super.key, required this.person});

  @override
  Widget build(BuildContext context) {
    return DialogShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: const BoxDecoration(
              color: kDarkPurple,
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: const EdgeInsets.all(26),
              child: SvgPicture.asset(
                'assets/icons/link.svg',
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Apakah ada ingin bertaut dengan',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          Text(
            '${person.name}?',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: DialogButton(
                  label: 'Batal',
                  onTap: () => Navigator.of(context).pop(false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DialogButton(
                  label: 'Tautkan',
                  primary: true,
                  onTap: () => Navigator.of(context).pop(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}