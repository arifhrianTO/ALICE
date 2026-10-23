import 'package:flutter/material.dart';

import '../../../core/colors.dart';
import 'jadwal_data.dart';
import 'jadwal_dialogs.dart';


// =====================================================================
//  HALAMAN JADWAL
// =====================================================================

// =====================================================================
//  HALAMAN JADWAL
// =====================================================================
class JadwalPage extends StatefulWidget {
  const JadwalPage({super.key});

  @override
  State<JadwalPage> createState() => _JadwalPageState();
}

class _JadwalPageState extends State<JadwalPage> {
  DateTime _selected = initialDate();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: scheduleStore,
      builder: (context, _) {
        final items = [...scheduleStore.forDay(_selected)];
        final now = DateTime.now();
        final isToday = sameDay(_selected, now);

        // Urutkan jadwal berdasarkan jam
        if (isToday) {
          final nowMin = now.hour * 60 + now.minute;

          items.sort((a, b) {
            final aUpcoming = a.minutes >= nowMin;
            final bUpcoming = b.minutes >= nowMin;

    // Jadwal mendatang selalu di atas jadwal yang sudah lewat
        if (aUpcoming != bUpcoming) {
          return aUpcoming ? -1 : 1;
        }

    // Urutkan berdasarkan jam paling dekat
          return a.minutes.compareTo(b.minutes);
        });
      } else {
  // Untuk tanggal lain, urutkan dari jam paling awal
        items.sort((a, b) => a.minutes.compareTo(b.minutes));
      }
        // Kartu "Mendatang!" = jadwal pertama yang belum lewat
        int highlight = -1;
        if (isToday) {
          final nowMin = now.hour * 60 + now.minute;
          highlight = items.indexWhere((s) => s.minutes >= nowMin);
        } else if (items.isNotEmpty) {
          highlight = 0;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 12),
                child: Text(
                  'Jadwal',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: kTextPurple,
                  ),
                ),
              ),
              const MiniProfileCard(),
              const SizedBox(height: 12),
              WeekStrip(
                selected: _selected,
                onSelect: (d) => setState(() => _selected = d),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isToday
                          ? 'Jadwal hari ini'
                          : 'Jadwal ${_selected.day} ${monthAbbr[_selected.month - 1]}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: kTextPurple,
                      ),
                    ),
                    Text(
                      '${items.length} Jadwal',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.topCenter,
                  children: [...previous, ?current],
                ),
                child: ScheduleTimeline(
                  key: ValueKey(_selected.toString()),
                  items: items,
                  highlight: highlight,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}


// =====================================================================
//  KARTU PROFIL KECIL
// =====================================================================

// ---------- Kartu profil kecil (tanpa dropdown) ----------

class MiniProfileCard extends StatelessWidget {
  const MiniProfileCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 20,
      ),
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
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 26,
            backgroundImage: AssetImage('assets/icons/profil.png'),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Budi Santoso',
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
                  'BudiSantoso@gmail.com',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}



// =====================================================================
//  STRIP TANGGAL
// =====================================================================

// ---------- Strip tanggal (jumlah hari diatur kStripDays) ----------
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


// =====================================================================
//  TIMELINE
// =====================================================================

// ---------- Timeline ----------
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

// ---------- Kartu "Mendatang!" ----------
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

// ---------- Kartu jadwal biasa ----------
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

// ---------- Tombol "Kelola Jadwal" ----------
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


// =====================================================================
//  HALAMAN KELOLA JADWAL
// =====================================================================

// =====================================================================
//  HALAMAN KELOLA JADWAL
// =====================================================================
class KelolaJadwalPage extends StatefulWidget {
  const KelolaJadwalPage({super.key});

  @override
  State<KelolaJadwalPage> createState() => _KelolaJadwalPageState();
}

class _KelolaJadwalPageState extends State<KelolaJadwalPage> {
  static const List<ScheduleStatus?> _filters = [
    null,
    ScheduleStatus.approved,
    ScheduleStatus.pending,
    ScheduleStatus.rejected,
  ];

  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      floatingActionButton: RoundFab(
        onTap: () => showAddScheduleDialog(context),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            children: [
              Row(
                children: [
                  Material(
                    color: kPurple,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.of(context).pop(),
                      child: const SizedBox(
                        width: 30,
                        height: 30,
                        child: Icon(Icons.chevron_left_rounded,
                            color: Colors.white, size: 22),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Kelola Jadwal',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: kTextPurple,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              StatusTabs(
                index: _tab,
                onChanged: (i) => setState(() => _tab = i),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListenableBuilder(
                  listenable: scheduleStore,
                  builder: (context, _) {
                    final items = scheduleStore.byStatus(_filters[_tab]);
                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: items.isEmpty
                          ? const Center(
                              key: ValueKey('empty'),
                              child: Text(
                                'Belum ada jadwal',
                                style: TextStyle(
                                    fontSize: 13, color: Colors.black45),
                              ),
                            )
                          : ListView.separated(
                              key: ValueKey(_tab),
                              padding: const EdgeInsets.only(bottom: 100),
                              itemCount: items.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 14),
                              itemBuilder: (context, i) => Appear(
                                key: ValueKey(items[i].id),
                                index: i,
                                child: ManageCard(schedule: items[i]),
                              ),
                            ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// =====================================================================
//  TAB STATUS
// =====================================================================

// ---------- Tab status dengan indikator yang bergeser ----------
class StatusTabs extends StatelessWidget {
  static const labels = ['Semua', 'Disetujui', 'Menunggu', 'Ditolak'];

  final int index;
  final ValueChanged<int> onChanged;

  const StatusTabs({super.key, required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: kPurple,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: kPurple.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, cons) {
          final w = cons.maxWidth / labels.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                left: index * w + 3,
                top: 2,
                bottom: 2,
                width: w - 6,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              Row(
                children: [
                  for (int i = 0; i < labels.length; i++)
                    SizedBox(
                      width: w,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onChanged(i),
                        child: Container(
                          alignment: Alignment.center,
                          padding: EdgeInsets.zero,
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: i == index ? kTextPurple : Colors.white,
                            ),
                            child: Text(labels[i]),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}


// =====================================================================
//  KARTU KELOLA
// =====================================================================

// ---------- Kartu kelola (dengan tombol ubah & hapus) ----------

class ManageCard extends StatelessWidget {
  final Schedule schedule;
  const ManageCard({super.key, required this.schedule});

  @override
  Widget build(BuildContext context) {
    return AccentCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      schedule.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                OutlineBadge(
                  text: 'Dibuat oleh ${schedule.createdBy}',
                ),
                const SizedBox(width: 4),
                StatusBadge(status: schedule.status),
              ],
            ),
            Row(
              children: [
                const Icon(
                  Icons.access_time_rounded,
                  size: 26,
                  color: kTextPurple,
                ),
                const SizedBox(width: 6),
                Text(
                  formatTime(schedule.time),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: kTextPurple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                RepeatChip(schedule: schedule),
                const SizedBox(width: 10),
                ReminderInline(
                  minutes: schedule.reminderMinutes,
                ),

                // Tombol hanya muncul jika status bukan Menunggu
                if (schedule.status != ScheduleStatus.pending) ...[
                  const Spacer(),
                  _SmallIconButton(
                    icon: Icons.edit_rounded,
                    color: kPurple,
                    background: const Color(0xFFEDE9FF),
                    onTap: () =>
                        showEditScheduleDialog(context, schedule),
                  ),
                  const SizedBox(width: 6),
                  _SmallIconButton(
                    icon: Icons.delete_outline_rounded,
                    color: const Color(0xFFC62828),
                    background: const Color(0xFFFFE9E9),
                    onTap: () =>
                        showDeleteScheduleDialog(context, schedule),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}


class _SmallIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color background;
  final VoidCallback onTap;

  const _SmallIconButton({
    required this.icon,
    required this.color,
    required this.background,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: color, width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(icon, size: 19, color: color),
        ),
      ),
    );
  }
}


// =====================================================================
//  TOMBOL +
// =====================================================================

// ---------- Tombol + bulat ----------
class RoundFab extends StatefulWidget {
  final VoidCallback onTap;
  const RoundFab({super.key, required this.onTap});

  @override
  State<RoundFab> createState() => _RoundFabState();
}

class _RoundFabState extends State<RoundFab> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: kPurple,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: kPurple.withValues(alpha: 0.4),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 38),
        ),
      ),
    );
  }
}


// =====================================================================
//  CHIP & BADGE
// =====================================================================

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
            const Icon(Icons.repeat_rounded, size: 10, color: kTitleIndigo),
            const SizedBox(width: 3),
          ],
          Text(
            schedule.repeatLabel,
            style: const TextStyle(
              fontSize: 12,
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
        const Icon(Icons.notifications, size: 11, color: kDarkPurple),
        const SizedBox(width: 3),
        Text(
          '$minutes mnt',
          style: const TextStyle(
            fontSize: 13,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kPurple.withValues(alpha: 0.6)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
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
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}


// =====================================================================
//  KARTU ACCENT
// =====================================================================

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


// =====================================================================
//  ANIMASI MUNCUL
// =====================================================================

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
