import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../../core/colors.dart';
import '../../../core/monitoring_service.dart';
import '../jadwal/jadwal_data.dart';
import 'tunanetra_location.dart';
import 'widgets/beranda_empty_state.dart';
import 'widgets/beranda_info_cards.dart';
import 'widgets/beranda_map_card.dart';
import 'widgets/profile_dropdown.dart';

// =====================================================================
//  HALAMAN BERANDA
// =====================================================================
//
// Daftar tunanetra, pilihan tunanetra, dan jadwal mendatang diambil dari
// `scheduleStore` yang sama dengan halaman Jadwal. Jadi tunanetra yang
// dipilih di Beranda ikut terpilih di Jadwal, dan sebaliknya.
class BerandaPage extends StatefulWidget {
  /// Aksi saat pengguna ingin menautkan tunanetra dari keadaan kosong.
  /// Disediakan oleh HomeShell supaya alurnya sama dengan tombol "+".
  final VoidCallback? onTautkan;

  const BerandaPage({super.key, this.onTautkan});

  @override
  State<BerandaPage> createState() => BerandaPageState();
}

class BerandaPageState extends State<BerandaPage> {
  /// Seberapa sering data perangkat (lokasi, baterai, suhu) diperbarui.
  static const _pollEvery = Duration(seconds: 30);

  Timer? _timer;

  /// Tunanetra yang datanya sedang dimuat/ditampilkan, dan datanya.
  String? _statusFor;
  MonitoringRecord? _status;

  @override
  void initState() {
    super.initState();
    scheduleStore.addListener(_onStoreChanged);
    scheduleStore.load();
    _timer = Timer.periodic(_pollEvery, (_) => _fetchStatus());
  }

  @override
  void dispose() {
    _timer?.cancel();
    scheduleStore.removeListener(_onStoreChanged);
    super.dispose();
  }

  /// Tunanetra terpilih berganti (di sini atau di halaman Jadwal):
  /// buang data lama dan muat data tunanetra yang baru.
  void _onStoreChanged() {
    final id = scheduleStore.selectedTunanetra?.tunanetraId;
    if (id == _statusFor) return;

    _statusFor = id;
    _status = null;
    _fetchStatus();
  }

  Future<void> _fetchStatus() async {
    final id = _statusFor;
    if (id == null) return;

    try {
      final s = await MonitoringService.fetchStatus(id);
      // Pilihan sudah berganti selama menunggu: abaikan hasil ini.
      if (!mounted || id != _statusFor) return;
      setState(() => _status = s);
    } catch (e) {
      // Data lama dipertahankan; percobaan berikutnya menyusul otomatis.
      debugPrint('Gagal memuat data perangkat tunanetra ($e)');
    }
  }

  /// Memuat ulang daftar tunanetra terhubung dan jadwalnya.
  ///
  /// Dipanggil saat tab beranda dibuka lagi, supaya tautan yang baru
  /// diterima (status "Terhubung") langsung ikut muncul di dropdown.
  void refresh() {
    scheduleStore.load();
    _fetchStatus();
  }

  /// Jadwal berikutnya yang belum lewat (hari ini sampai 7 hari ke depan).
  /// `forDay` sudah terurut berdasarkan jam.
  ({Schedule schedule, DateTime date})? _findUpcoming() {
    final now = DateTime.now();
    final today = dateOnly(now);
    final nowMin = now.hour * 60 + now.minute;

    for (var i = 0; i < 8; i++) {
      final day = DateTime(today.year, today.month, today.day + i);
      for (final s in scheduleStore.forDay(day)) {
        if (i == 0 && s.minutes < nowMin) continue;
        return (schedule: s, date: day);
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: const _NoStretchScrollBehavior(),
      child: ListenableBuilder(
        listenable: scheduleStore,
        builder: (context, _) {
          // Pertama kali memuat.
          if (!scheduleStore.loaded && scheduleStore.error == null) {
            return _page(const [
              DropdownLoadingPlaceholder(),
              SizedBox(height: 14),
              AddressRow(address: 'Memuat alamat lokasi...'),
              SizedBox(height: 10),
              MapLoadingFallback(),
              SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: BerandaInfoCard(
                      imagePath: 'assets/icons/baterai.png',
                      value: '--',
                      label: 'Baterai saat ini',
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: BerandaInfoCard(
                      imagePath: 'assets/icons/suhu.png',
                      value: '--',
                      label: 'Suhu saat ini',
                    ),
                  ),
                ],
              ),
              SizedBox(height: 14),
              BerandaUpcomingCard(),
            ]);
          }

          // Gagal memuat dan belum ada data sama sekali.
          if (!scheduleStore.loaded && scheduleStore.error != null) {
            return _page([
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: Text(
                    'Gagal memuat data tunanetra',
                    style: TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                ),
              ),
              Center(
                child: TextButton(
                  onPressed: scheduleStore.load,
                  child: const Text('Coba lagi'),
                ),
              ),
            ]);
          }

          final list = [
            for (final c in scheduleStore.connectedTunanetra)
              TunanetraLocation.fromConnection(
                c,
                status: c.tunanetraId == _statusFor ? _status : null,
              ),
          ];

          // Keadaan kosong: belum ada tunanetra berstatus "Terhubung".
          // Tampilkan ajakan menautkan, bukan peta dan kartu data kosong.
          if (list.isEmpty) {
            return _page([
              EmptyTunanetraDropdown(onTap: widget.onTautkan),
              const SizedBox(height: 14),
              const EmptyTunanetraPlaceholder(),
              const SizedBox(height: 28),
              TautkanTunanetraButton(onTap: widget.onTautkan),
            ]);
          }

          final selectedId = scheduleStore.selectedTunanetra?.tunanetraId;
          final index = list.indexWhere((t) => t.id == selectedId);
          final safeIndex = index < 0 ? 0 : index;
          final current = list[safeIndex];
          final upcoming = _findUpcoming();

          return _page([
            ProfileDropdown(
              accounts: list,
              currentIndex: safeIndex,
              onSelected: (i) => scheduleStore.selectTunanetra(list[i].id),
            ),
            const SizedBox(height: 14),
            AddressRow(
              address: current.address ??
                  (current.hasLocation
                      ? '${current.latitude.toStringAsFixed(5)}, '
                          '${current.longitude.toStringAsFixed(5)}'
                      : 'Lokasi belum tersedia'),
            ),
            const SizedBox(height: 10),
            if (current.hasLocation)
              BerandaMapCard(location: current)
            else
              const _LocationUnavailableCard(),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: BerandaInfoCard(
                    imagePath: 'assets/icons/baterai.png',
                    value: current.battery ?? '--',
                    label: 'Baterai saat ini',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: BerandaInfoCard(
                    imagePath: 'assets/icons/suhu.png',
                    value: current.temperature ?? '--',
                    label: 'Suhu saat ini',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            BerandaUpcomingCard(
              schedule: upcoming?.schedule,
              date: upcoming?.date,
            ),
          ]);
        },
      ),
    );
  }

  /// Kerangka halaman: judul "Beranda" lalu isinya.
  Widget _page(List<Widget> children) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 14),
            child: Text(
              'Beranda',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: kTextPurple,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

/// Pengganti peta saat perangkat tunanetra belum mengirim lokasi.
class _LocationUnavailableCard extends StatelessWidget {
  const _LocationUnavailableCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 300,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFEDECEF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDDDBE3)),
      ),
      child: const Text(
        'Lokasi tunanetra\nbelum tersedia',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, color: Colors.black45, height: 1.4),
      ),
    );
  }
}

class _NoStretchScrollBehavior extends MaterialScrollBehavior {
  const _NoStretchScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}