import 'package:material_ui/material_ui.dart';

import '../../../core/colors.dart';

// =====================================================================
//  BOTTOM NAVBAR (dengan animasi)
// =====================================================================
class AppBottomBar extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final VoidCallback? onAdd;

  const AppBottomBar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
    this.onAdd,
  });

  @override
  State<AppBottomBar> createState() => _BottomBarState();
}

class _BottomBarState extends State<AppBottomBar> {
  double _fabTurns = 0;
  bool _fabPressed = false;

  @override
  Widget build(BuildContext context) {
    // Animasi masuk: navbar naik dari bawah saat halaman dibuka
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, (1 - v) * 90),
          child: child,
        ),
      ),
      child: SizedBox(
        height: 88,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              height: 66,
              decoration: BoxDecoration(
              color: kBg,
              boxShadow: [
                BoxShadow(
                  color: kDarkPurple.withValues(alpha: 0.12),
                  blurRadius: 16,
                  spreadRadius: 0,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  _NavItem(
                    icon: Icons.home_outlined,
                    label: 'Beranda',
                    selected: widget.selectedIndex == 0,
                    onTap: () => widget.onTap(0),
                  ),
                  _NavItem(
                    icon: Icons.people_alt_rounded,
                    label: 'Terhubung',
                    selected: widget.selectedIndex == 1,
                    onTap: () => widget.onTap(1),
                  ),
                  const SizedBox(width: 80), // ruang untuk tombol tengah
                  _NavItem(
                    icon: Icons.calendar_month_rounded,
                    label: 'Jadwal',
                    selected: widget.selectedIndex == 3,
                    onTap: () => widget.onTap(3),
                  ),
                  _NavItem(
                    icon: Icons.person_rounded,
                    label: 'Profile',
                    selected: widget.selectedIndex == 4,
                    onTap: () => widget.onTap(4),
                  ),
                ],
              ),
            ),
            // Tombol tambah: mengecil saat ditekan, ikon + berputar saat diklik
            Positioned(
              top: 0,
              child: GestureDetector(
                onTapDown: (_) => setState(() => _fabPressed = true),
                onTapCancel: () => setState(() => _fabPressed = false),
                onTapUp: (_) => setState(() => _fabPressed = false),
                onTap: () {
                  setState(() => _fabTurns += 0.25);
                  widget.onAdd?.call();
                },
                child: AnimatedScale(
                  scale: _fabPressed ? 0.88 : 1,
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  child: Transform.rotate(
                    angle: 0.785398, // 45°
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: kPurple,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: kPurple.withValues(alpha: 0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Transform.rotate(
                        angle: -0.785398,
                        child: AnimatedRotation(
                          turns: _fabTurns,
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOutBack,
                          child: const Icon(
                            Icons.add,
                            color: kBg,
                            size: 34,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          // Latar pil berubah halus + ukuran menyesuaikan
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(
              horizontal: selected ? 10 : 8,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: selected ? kLightPurple : kLightPurple.withValues(alpha: 0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ikon membesar & naik sedikit saat aktif (efek memantul)
                AnimatedSlide(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutBack,
                  offset: selected ? const Offset(0, -0.08) : Offset.zero,
                  child: AnimatedScale(
                    scale: selected ? 1.18 : 1,
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutBack,
                    child: Icon(icon, color: kPurple, size: 24),
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? kDarkPurple : kPurple,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
