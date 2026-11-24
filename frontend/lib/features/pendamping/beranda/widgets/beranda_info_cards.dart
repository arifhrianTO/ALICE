import 'package:material_ui/material_ui.dart';

import '../../../../core/colors.dart';
import '../../jadwal/jadwal_data.dart';

// =====================================================================
//  KARTU BATERAI / SUHU
// =====================================================================
class BerandaInfoCard extends StatelessWidget {
  final String imagePath;
  final String value;
  final String label;

  const BerandaInfoCard({
    super.key,
    required this.imagePath,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 17,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: kPurple.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Image.asset(
            imagePath,
            width: 48,
            height: 48,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: kDarkPurple,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: kPurple,
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
//  KARTU AGENDA MENDATANG
// =====================================================================
//
// Menampilkan jadwal disetujui berikutnya milik tunanetra yang dipilih.
// Kalau [schedule] null, kartu menampilkan keadaan kosong.
class BerandaUpcomingCard extends StatelessWidget {
  final Schedule? schedule;

  /// Tanggal jadwal ini akan berlangsung (hari ini sampai 7 hari ke depan).
  final DateTime? date;

  const BerandaUpcomingCard({super.key, this.schedule, this.date});

  String _dateLabel(DateTime d) {
    final today = dateOnly(DateTime.now());
    final diff = dateOnly(d).difference(today).inDays;
    if (diff == 0) return 'Hari ini';
    if (diff == 1) return 'Besok';
    return '${dayFull[d.weekday - 1]}, ${d.day} ${monthAbbr[d.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final s = schedule;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
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
      child: s == null ? _empty() : _filled(s),
    );
  }

  Widget _empty() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mendatang!',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Belum ada jadwal mendatang.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8),
      ],
    );
  }

  Widget _filled(Schedule s) {
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mendatang!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              // Sisakan ruang di kanan agar tidak menabrak chip pengingat.
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                s.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  height: 1.25,
                ),
              ),
            ),
            if (date != null) ...[
              const SizedBox(height: 2),
              Text(
                _dateLabel(date!),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
        Positioned(
          right: 0,
          top: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD9DF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.notifications,
                  size: 13,
                  color: Color(0xFF8A2A3C),
                ),
                const SizedBox(width: 4),
                Text(
                  'Ingatkan di ${s.reminderTime}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8A2A3C),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Chip pengulangan (kiri bawah)
        Positioned(
          left: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.repeat_rounded,
                  size: 14,
                  color: Colors.black,
                ),
                const SizedBox(width: 5),
                Text(
                  s.repeatLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Text(
            formatTime(s.time),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 38,
              fontWeight: FontWeight.bold,
              height: 1.0,
            ),
          ),
        ),
      ],
    );
  }
}