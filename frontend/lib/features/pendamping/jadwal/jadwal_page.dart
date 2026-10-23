import 'package:flutter/material.dart';

import '../../../core/colors.dart';
import 'jadwal_data.dart';
import 'widgets/mini_profile_card.dart';
import 'widgets/schedule_timeline.dart';
import 'widgets/week_strip.dart';

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
