import 'package:material_ui/material_ui.dart';

import '../../../../core/colors.dart';
import '../jadwal_data.dart';

/// Helper navigasi slide transisi halaman
Route<T> slideRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 350),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (_, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.12, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Chip pengulangan: "Sekali Saja" / "Tiap Senin" / "Tiap Hari" / "Tiap Minggu"
class RepeatChip extends StatelessWidget {
  final Schedule schedule;
  final bool onDark;
  const RepeatChip({super.key, required this.schedule, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: onDark ? Colors.white : const Color(0xFFE2DDF8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (schedule.repeat.isRepeating) ...[
            const Icon(Icons.repeat_rounded, size: 15, color: kTitleIndigo),
            const SizedBox(width: 6),
          ],
          Text(
            schedule.repeatLabel,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: kTitleIndigo,
            ),
          ),
        ],
      ),
    );
  }
}

/// Lonceng + "10 mnt"
class ReminderInline extends StatelessWidget {
  final int minutes;
  const ReminderInline({super.key, required this.minutes});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.notifications, size: 14, color: kDarkPurple),
        const SizedBox(width: 3),
        Text(
          '$minutes mnt',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: kTextPurple,
          ),
        ),
      ],
    );
  }
}

class OutlineBadge extends StatelessWidget {
  final String text;
  const OutlineBadge({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kPurple.withValues(alpha: 0.6)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: kDarkPurple,
        ),
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final ScheduleStatus status;
  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    late final Color bg;
    late final Color fg;
    late final IconData icon;
    switch (status) {
      case ScheduleStatus.approved:
        bg = const Color(0xFFD6F5D6);
        fg = const Color(0xFF2E7D32);
        icon = Icons.check_rounded;
        break;
      case ScheduleStatus.pending:
        bg = const Color(0xFFFFF3B8);
        fg = const Color(0xFF8A6D00);
        icon = Icons.hourglass_bottom_rounded;
        break;
      case ScheduleStatus.rejected:
        bg = const Color(0xFFFFD9D9);
        fg = const Color(0xFFC62828);
        icon = Icons.close_rounded;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 2),
          Text(
            status.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu putih krem dengan aksen ungu di sisi kiri
class AccentCard extends StatelessWidget {
  final Widget child;
  const AccentCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kFieldBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: kPurple.withValues(alpha: 0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: kPurple),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// Animasi muncul: fade + naik sedikit, bergantian berdasarkan urutan
class Appear extends StatelessWidget {
  final int index;
  final Widget child;
  const Appear({super.key, required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    final i = index > 8 ? 8 : index;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 350 + i * 90),
      curve: Curves.easeOutCubic,
      builder: (context, v, ch) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, (1 - v) * 18), child: ch),
      ),
      child: child,
    );
  }
}
