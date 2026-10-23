import 'package:flutter/material.dart';

import '../../../../core/colors.dart';
import '../jadwal_data.dart';
import '../kelola_jadwal_page.dart';
import 'schedule_common_widgets.dart';

// =====================================================================
//  TIMELINE
// =====================================================================
class ScheduleTimeline extends StatelessWidget {
  final List<Schedule> items;
  final int highlight;

  const ScheduleTimeline({super.key, required this.items, required this.highlight});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Text(
              'Belum ada jadwal pada tanggal ini',
              style: TextStyle(fontSize: 14, color: Colors.black45),
            ),
          ),
        for (int i = 0; i < items.length; i++)
          _TimelineRow(
            index: i,
            isFirst: i == 0,
            isLast: false,
            filled: i == highlight,
            child: i == highlight
                ? UpcomingScheduleCard(schedule: items[i])
                : ScheduleCard(schedule: items[i]),
          ),
        _TimelineRow(
          index: items.length,
          isFirst: items.isEmpty,
          isLast: true,
          filled: false,
          child: const ManageButton(),
        ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final int index;
  final bool isFirst;
  final bool isLast;
  final bool filled;
  final Widget child;

  const _TimelineRow({
    required this.index,
    required this.isFirst,
    required this.isLast,
    required this.filled,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Appear(
      index: index,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 28,
              child: CustomPaint(
                painter: _TimelinePainter(
                  isFirst: isFirst,
                  isLast: isLast,
                  filled: filled,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelinePainter extends CustomPainter {
  final bool isFirst;
  final bool isLast;
  final bool filled;

  _TimelinePainter({
    required this.isFirst,
    required this.isLast,
    required this.filled,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gap = isLast ? 0.0 : 10.0;
    final dotY = (size.height - gap) / 2;
    const cx = 10.0;

    final line = Paint()
      ..color = kPurple
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(cx, isFirst ? dotY : 0),
      Offset(cx, isLast ? dotY : size.height),
      line,
    );

    canvas.drawCircle(
      Offset(cx, dotY),
      7,
      Paint()..color = filled ? kPurple : kBg,
    );
    canvas.drawCircle(
      Offset(cx, dotY),
      7,
      Paint()
        ..color = kPurple
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter old) =>
      old.isFirst != isFirst || old.isLast != isLast || old.filled != filled;
}

// =====================================================================
//  KARTU JADWAL
// =====================================================================
class UpcomingScheduleCard extends StatelessWidget {
  final Schedule schedule;
  const UpcomingScheduleCard({super.key, required this.schedule});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 18, 12, 18),
      decoration: BoxDecoration(
        color: kPurple,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: kPurple.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Mendatang!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        schedule.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  RepeatChip(schedule: schedule, onDark: true),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD9DF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.notifications,
                          size: 11, color: Color(0xFF8A2A3C)),
                      const SizedBox(width: 4),
                      Text(
                        'Ingatkan di ${schedule.reminderTime}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF8A2A3C),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  formatTime(schedule.time),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ScheduleCard extends StatelessWidget {
  final Schedule schedule;
  const ScheduleCard({super.key, required this.schedule});

  @override
  Widget build(BuildContext context) {
    return AccentCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      schedule.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: kTextPurple,
                      ),
                    ),
                    const SizedBox(height: 8),
                    RepeatChip(schedule: schedule),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ReminderInline(minutes: schedule.reminderMinutes),
                  const SizedBox(height: 6),
                  Text(
                    formatTime(schedule.time),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================================
//  TOMBOL KELOLA JADWAL
// =====================================================================
class ManageButton extends StatelessWidget {
  const ManageButton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      width: double.infinity,
      child: Material(
        color: kDarkPurple,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: () => Navigator.of(context).push(slideRoute(
            const KelolaJadwalPage(),
          )),
          child: const Center(
            child: Text(
              'Kelola Jadwal',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
