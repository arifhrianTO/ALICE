import 'package:flutter/material.dart';
import '../core/colors.dart';

class PillButton extends StatelessWidget {
  final String text;
  final Widget? icon;
  final Color background;
  final bool enabled;
  final VoidCallback? onTap;

  /// Jika false, tombol menyusut mengikuti konten (misal tombol "Kembali").
  final bool wide;

  /// Jika true, ikon + teks rata kiri seperti tombol metode masuk di desain.
  final bool alignLeft;
  const PillButton({
    super.key,
    required this.text,
    this.icon,
    this.background = Colors.white,
    this.enabled = true,
    this.onTap,
    this.wide = true,
    this.alignLeft = false,
  });

  @override
  Widget build(BuildContext context) {
    final btn = Opacity(
      opacity: enabled ? 1 : 0.5,
      child: ElevatedButton(
        onPressed: enabled ? onTap : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: AliceColors.textPurple,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
          elevation: 0,
          minimumSize: wide ? const Size(double.infinity, 52) : const Size(0, 38),
          padding: wide
              ? (alignLeft ? const EdgeInsets.symmetric(horizontal: 24) : null)
              : const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Row(
          mainAxisSize: alignLeft ? MainAxisSize.max : MainAxisSize.min,
          children: [
            if (icon != null) ...[
              SizedBox(width: 24, child: Center(child: icon!)),
              SizedBox(width: wide ? 10 : 6),
            ],
            Flexible(
              child: Text(
                text,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: wide ? 15 : 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!enabled) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AliceColors.textPurple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Segera', style: TextStyle(fontSize: 10)),
              ),
            ],
          ],
        ),
      ),
    );
    if (!enabled) {
      return Tooltip(message: 'Segera hadir, gunakan email dulu', child: btn);
    }
    return btn;
  }
}
