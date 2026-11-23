import 'package:material_ui/material_ui.dart';

import '../../../core/colors.dart';
import 'tunanetra_location.dart';
import 'widgets/beranda_empty_state.dart';
import 'widgets/beranda_info_cards.dart';
import 'widgets/beranda_map_card.dart';
import 'widgets/profile_dropdown.dart';

// =====================================================================
//  HALAMAN BERANDA
// =====================================================================
class BerandaPage extends StatefulWidget {
  /// Aksi saat pengguna ingin menautkan tunanetra dari keadaan kosong.
  /// Disediakan oleh HomeShell supaya alurnya sama dengan tombol "+".
  final VoidCallback? onTautkan;

  const BerandaPage({super.key, this.onTautkan});

  @override
  State<BerandaPage> createState() => BerandaPageState();
}

class BerandaPageState extends State<BerandaPage> {
  late Future<List<TunanetraLocation>> _tunanetraFuture;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Memuat ulang daftar tunanetra terhubung.
  ///
  /// Dipanggil saat tab beranda dibuka lagi, supaya tautan yang baru
  /// diterima (status "Terhubung") langsung ikut muncul di dropdown.
  void refresh() {
    setState(_loadData);
  }

  void _loadData() {
    _tunanetraFuture = TunanetraLocationService.fetchLinkedTunanetra()
        .catchError((error) {
      debugPrint(
        'Gagal memuat tunanetra terhubung dari backend ($error). '
        'Menampilkan daftar kosong.',
      );
      return <TunanetraLocation>[];
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: const _NoStretchScrollBehavior(),
      child: FutureBuilder<List<TunanetraLocation>>(
        future: _tunanetraFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SingleChildScrollView(
              physics: ClampingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
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
                ],
              ),
            );
          }

          final list = snapshot.data ?? const <TunanetraLocation>[];

          // Keadaan kosong: belum ada tunanetra berstatus "Terhubung".
          // Tampilkan ajakan menautkan, bukan peta dan kartu data kosong.
          if (list.isEmpty) {
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
                  EmptyTunanetraDropdown(onTap: widget.onTautkan),
                  const SizedBox(height: 14),
                  const EmptyTunanetraPlaceholder(),
                  const SizedBox(height: 28),
                  TautkanTunanetraButton(onTap: widget.onTautkan),
                ],
              ),
            );
          }

          final safeIndex = _selectedIndex.clamp(0, list.length - 1);
          final currentTunanetra = list[safeIndex];

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
                ProfileDropdown(
                  accounts: list,
                  currentIndex: safeIndex,
                  onSelected: (i) {
                    setState(() {
                      _selectedIndex = i;
                    });
                  },
                ),
                const SizedBox(height: 14),
                AddressRow(address: currentTunanetra.address),
                const SizedBox(height: 10),
                BerandaMapCard(
                  location: currentTunanetra,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: BerandaInfoCard(
                        imagePath: 'assets/icons/baterai.png',
                        value: currentTunanetra.battery,
                        label: 'Baterai saat ini',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: BerandaInfoCard(
                        imagePath: 'assets/icons/suhu.png',
                        value: currentTunanetra.temperature,
                        label: 'Suhu saat ini',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const BerandaUpcomingCard(),
              ],
            ),
          );
        },
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
