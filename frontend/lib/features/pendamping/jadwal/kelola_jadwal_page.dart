import 'package:material_ui/material_ui.dart';

import '../../../core/colors.dart';
import 'jadwal_data.dart';
import 'widgets/jadwal_dialogs.dart';
import 'widgets/schedule_common_widgets.dart';

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
  void initState() {
    super.initState();
    scheduleStore.load();
  }

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
                        child: Icon(
                          Icons.chevron_left_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
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
                    // Pertama kali memuat.
                    if (!scheduleStore.loaded && scheduleStore.loading) {
                      return const Center(
                        child: CircularProgressIndicator(color: kPurple),
                      );
                    }

                    // Gagal memuat dan belum ada data sama sekali.
                    if (!scheduleStore.loaded && scheduleStore.error != null) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              scheduleStore.error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: scheduleStore.load,
                              child: const Text('Coba lagi'),
                            ),
                          ],
                        ),
                      );
                    }

                    // Sudah dimuat tapi belum terhubung dengan tunanetra.
                    if (scheduleStore.loaded && !scheduleStore.hasConnection) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            'Belum terhubung dengan tunanetra. '
                            'Hubungkan dulu lewat tab Terhubung.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      );
                    }

                    final items = scheduleStore.byStatus(_filters[_tab]);
                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: items.isEmpty
                          ? const Center(
                              key: ValueKey('empty'),
                              child: Text(
                                'Belum ada jadwal',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.black45,
                                ),
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
class StatusTabs extends StatelessWidget {
  static const labels = [
    'Semua',
    'Disetujui',
    'Menunggu',
    'Ditolak'
  ];

  final int index;
  final ValueChanged<int> onChanged;

  const StatusTabs({
    super.key,
    required this.index,
    required this.onChanged,
  });

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
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: i == index
                                  ? kTextPurple
                                  : Colors.white,
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
                      softWrap: true,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
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
                  size: 24,
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

                // Tombol hanya muncul jika status Disetujui
                if (schedule.status == ScheduleStatus.approved) ...[
                  const Spacer(),
                  _SmallIconButton(
                    icon: Icons.edit_rounded,
                    color: kPurple,
                    background: const Color(0xFFEDE9FF),
                    onTap: () => showEditScheduleDialog(context, schedule),
                  ),
                  const SizedBox(width: 6),
                  _SmallIconButton(
                    icon: Icons.delete_outline_rounded,
                    color: const Color(0xFFC62828),
                    background: const Color(0xFFFFE9E9),
                    onTap: () => showDeleteScheduleDialog(context, schedule),
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
          child: const Icon(
            Icons.add_rounded,
            color: Colors.white,
            size: 38,
          ),
        ),
      ),
    );
  }
}