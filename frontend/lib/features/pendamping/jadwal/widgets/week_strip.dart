import 'package:material_ui/material_ui.dart';

import '../../../../core/colors.dart';
import '../jadwal_data.dart';

class WeekStrip extends StatelessWidget {
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  const WeekStrip({super.key, required this.selected, required this.onSelect});

  DateTime _shift(int days) =>
      DateTime(selected.year, selected.month, selected.day + days);

  @override
  Widget build(BuildContext context) {
    final startOffset = selected.weekday - 1; // jarak ke hari Senin
    final days = List.generate(
      kStripDays,
      (i) => DateTime(
          selected.year, selected.month, selected.day - startOffset + i),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: kPurple.withValues(alpha: 0.10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _ArrowButton(
            icon: Icons.chevron_left_rounded,
            onTap: () => onSelect(_shift(-7)),
          ),
          for (final d in days) _buildDay(d),
          _ArrowButton(
            icon: Icons.chevron_right_rounded,
            onTap: () => onSelect(_shift(7)),
          ),
        ],
      ),
    );
  }

  Widget _buildDay(DateTime d) {
    final isSel = sameDay(d, selected);
    final hasEvent =
        scheduleStore.forDay(d).any((s) => s.repeat != RepeatType.daily);
    final style = TextStyle(
      fontSize: 15,
      fontWeight: isSel ? FontWeight.w800 : FontWeight.w500,
      color: kTextPurple,
    );

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onSelect(d),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: isSel ? const Color(0xFFCBE7FB) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(dayAbbr[d.weekday - 1], style: style),
              Text('${d.day}', style: style),
              const SizedBox(height: 3),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasEvent ? const Color(0xFFE53935) : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ArrowButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 22, color: kDarkPurple),
      ),
    );
  }
}
