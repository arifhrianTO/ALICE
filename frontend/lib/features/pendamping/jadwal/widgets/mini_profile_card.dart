import 'package:material_ui/material_ui.dart';

import '../../../../core/colors.dart';
import '../../../../core/connection_service.dart';
import '../jadwal_data.dart';

/// Kartu tunanetra di halaman Jadwal. Bentuknya sama dengan dropdown di
/// halaman Beranda, tetapi isinya data tunanetra yang terhubung.
///
/// - Memuat                   : "Memuat..."
/// - Belum ada yang terhubung : "Belum ada tunanetra yang terhubung"
/// - Satu tunanetra           : nama + email
/// - Lebih dari satu          : kartu bisa diketuk, panel pilihan melayang
///                              di bawahnya
class MiniProfileCard extends StatefulWidget {
  const MiniProfileCard({super.key});

  @override
  State<MiniProfileCard> createState() => _MiniProfileCardState();
}

class _MiniProfileCardState extends State<MiniProfileCard> {
  final OverlayPortalController _portal = OverlayPortalController();
  final LayerLink _link = LayerLink();
  double _width = 0;

  void _toggle() {
    if (_portal.isShowing) {
      _portal.hide();
    } else {
      _portal.show();
    }
    setState(() {});
  }

  void _close() {
    if (!_portal.isShowing) return;
    _portal.hide();
    setState(() {});
  }

  void _pick(String tunanetraId) {
    _close();
    scheduleStore.selectTunanetra(tunanetraId);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: scheduleStore,
      builder: (context, _) {
        final selected = scheduleStore.selectedTunanetra;
        final list = scheduleStore.connectedTunanetra;

        // Belum selesai dimuat.
        if (!scheduleStore.loaded) {
          return _shell(
            child: _messageRow(
              scheduleStore.error != null
                  ? 'Gagal memuat tunanetra'
                  : 'Memuat...',
            ),
          );
        }

        // Belum ada tunanetra yang terhubung.
        if (selected == null) {
          return _shell(
            child: _messageRow('Belum ada tunanetra yang terhubung'),
          );
        }

        final canPick = list.length > 1;

        // Daftar menyusut jadi satu: tutup panel yang masih terbuka.
        if (!canPick && _portal.isShowing) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _portal.isShowing) {
              _portal.hide();
              setState(() {});
            }
          });
        }

        final open = canPick && _portal.isShowing;

        final header = _shell(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const CircleAvatar(
                radius: 26,
                backgroundImage: AssetImage('assets/icons/profil.png'),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _displayName(selected),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      selected.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              if (canPick)
                Icon(
                  open
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: Colors.white,
                  size: 30,
                ),
            ],
          ),
        );

        // Satu tunanetra saja: tidak ada dropdown.
        if (!canPick) return header;

        return OverlayPortal(
          controller: _portal,
          overlayChildBuilder: (_) => _buildPanel(list, selected),
          child: LayoutBuilder(
            builder: (context, constraints) {
              _width = constraints.maxWidth;
              return CompositedTransformTarget(
                link: _link,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _toggle,
                  child: header,
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ===============================================================
  // PANEL PILIHAN (melayang di bawah kartu)
  // ===============================================================

  Widget _buildPanel(List<ConnectionRecord> list, ConnectionRecord selected) {
    return Stack(
      children: [
        // Ketuk di luar panel = tutup.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _close,
          ),
        ),
        Positioned(
          left: 0,
          top: 0,
          width: _width,
          child: CompositedTransformFollower(
            link: _link,
            targetAnchor: Alignment.bottomLeft,
            followerAnchor: Alignment.topLeft,
            offset: const Offset(0, 8),
            child: Material(
              color: kDarkPurple,
              elevation: 6,
              shadowColor: Colors.black38,
              borderRadius: BorderRadius.circular(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 340),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int i = 0; i < list.length; i++) ...[
                        if (i > 0) const SizedBox(height: 12),
                        _item(list[i], list[i].tunanetraId == selected.tunanetraId),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _item(ConnectionRecord c, bool isSelected) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _pick(c.tunanetraId),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: kPurple, width: 2),
                ),
                child: const CircleAvatar(
                  radius: 22,
                  backgroundImage: AssetImage('assets/icons/profil.png'),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _displayName(c),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      c.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: kPurple,
                  size: 28,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ===============================================================
  // BAGIAN BERSAMA
  // ===============================================================

  /// Nama tunanetra; kalau kosong dipakai emailnya.
  String _displayName(ConnectionRecord c) =>
      c.name.trim().isEmpty ? c.email : c.name;

  Widget _messageRow(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const CircleAvatar(
          radius: 26,
          backgroundImage: AssetImage('assets/icons/profil.png'),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _shell({required Widget child}) {
    return Container(
      width: double.infinity,
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
      child: child,
    );
  }
}