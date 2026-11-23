import 'package:material_ui/material_ui.dart';

import '../../../core/colors.dart';
import 'koneksi_data.dart';

// ---------------------------------------------------------------------------
// Warna & aset lokal (khusus halaman ini)
// ---------------------------------------------------------------------------
const _kCardColor = Color(0xFFFFF8F6);
const _kCardBorder = Color(0xFFE3DFF7);
const _kTextDark = Color(0xFF2B2B3C);
const _kDeepPurple = Color(0xFF2E0A7D);
const _kLightPurple = Color(0xFFE2DFFF);

// Gambar bulat ungu + tautan putus untuk pop-up "Putuskan tautan".
const _kPutuskanImage = 'assets/icons/putuskan.png';
const _kDefaultAvatar = 'assets/icons/profil.png';

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------
// Data & enum status diambil dari `koneksi_data.dart` (ConnectionRequest,
// ConnectionStatus, ConnectionService) supaya halaman ini tidak lagi
// memakai data contoh yang ditulis langsung di kode.

enum ConnectionFilter {
  semua('Semua'),
  tertaut('Tertaut'),
  menunggu('Menunggu'),
  ditolak('Ditolak');

  final String label;
  const ConnectionFilter(this.label);

  bool matches(ConnectionStatus s) {
    switch (this) {
      case ConnectionFilter.semua:
        return true;
      case ConnectionFilter.tertaut:
        return s == ConnectionStatus.terhubung;
      case ConnectionFilter.menunggu:
        return s == ConnectionStatus.menunggu;
      case ConnectionFilter.ditolak:
        return s == ConnectionStatus.ditolak;
    }
  }
}

// ---------------------------------------------------------------------------
// Halaman Koneksi
// (tanpa Scaffold & bottom bar, karena sudah disediakan HomeShell)
// ---------------------------------------------------------------------------
class KoneksiPage extends StatefulWidget {
  const KoneksiPage({super.key});

  @override
  State<KoneksiPage> createState() => KoneksiPageState();
}

/// State dibuat publik supaya HomeShell bisa memanggil [refresh] setelah
/// pendamping selesai menautkan tunanetra baru.
class KoneksiPageState extends State<KoneksiPage> {
  ConnectionFilter _filter = ConnectionFilter.semua;

  /// Status pemuatan daftar pengajuan dari backend.
  bool _loading = true;
  String? _error;

  /// Semua pengajuan tautan milik pendamping yang sedang login.
  List<ConnectionRequest> _items = const [];

  @override
  void initState() {
    super.initState();
    refresh();
  }

  /// Memuat ulang daftar pengajuan dari `GET /api/requests`.
  Future<void> refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ConnectionService.fetchAll();
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } on ConnectionException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal menghubungi server. Coba lagi.';
        _loading = false;
      });
    }
  }

  /// Memuat ulang tanpa indikator loading penuh.
  ///
  /// Dipakai untuk penyegaran berkala selagi tab ini terbuka, supaya status
  /// (misalnya "Menunggu" yang berubah menjadi "Terhubung" setelah tunanetra
  /// menyetujui) ikut tampil tanpa harus menarik layar. Kalau gagal, data
  /// lama dibiarkan tetap tampil.
  Future<void> silentRefresh() async {
    try {
      final list = await ConnectionService.fetchAll();
      if (!mounted) return;
      setState(() {
        _items = list;
        _error = null;
      });
    } catch (_) {
      // Penyegaran latar gagal: cukup diamkan.
    }
  }

  Future<void> _confirmDelete(ConnectionRequest item) async {
    final ok = await showDisconnectDialog(
      context,
      name: item.name,
      // Status "Menunggu" -> teks "Batalkan tautan", selain itu "Putuskan tautan".
      isPending: item.status == ConnectionStatus.menunggu,
    );
    if (ok != true || !mounted) return;

    try {
      await ConnectionService.remove(item.id);
      if (!mounted) return;
      setState(() {
        _items = _items.where((e) => e.id != item.id).toList();
      });
      _showSnack(
        item.status == ConnectionStatus.menunggu
            ? 'Pengajuan tautan dengan ${item.name} dibatalkan'
            : 'Tautan dengan ${item.name} diputus',
      );
    } on ConnectionException catch (e) {
      if (!mounted) return;
      _showSnack(e.message);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: kDarkPurple,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Text(
              'Terhubung',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: kTextPurple,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _FilterTabs(
            selected: _filter,
            onChanged: (f) => setState(() => _filter = f),
          ),
          const SizedBox(height: 14),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: kPurple));
    }
    if (_error != null) {
      return _ErrorState(message: _error!, onRetry: refresh);
    }

    final visible =
        _items.where((e) => _filter.matches(e.status)).toList(growable: false);

    return RefreshIndicator(
      color: kPurple,
      onRefresh: refresh,
      child: visible.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                Center(
                  child: Text(
                    'Belum ada koneksi',
                    style: TextStyle(color: Colors.black45),
                  ),
                ),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: visible.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => ConnectionCard(
                item: visible[i],
                onDelete: () => _confirmDelete(visible[i]),
              ),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tampilan gagal memuat daftar pengajuan + tombol "Coba lagi".
// ---------------------------------------------------------------------------
class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: kPurple, size: 40),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ),
          const SizedBox(height: 16),
          Material(
            color: kPurple,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onRetry,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Text(
                  'Coba lagi',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pop-up "Putuskan tautan"
// Mengembalikan true kalau user menekan "Putuskan", false/null kalau "Batal".
// ---------------------------------------------------------------------------
Future<bool?> showDisconnectDialog(
  BuildContext context, {
  required String name,
  bool isPending = false,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => Dialog(
      backgroundColor: const Color(0xFFFFFCFC),
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Gambar utama pop-up (assets/icons/putuskan.png)
              Image.asset(
                _kPutuskanImage,
                width: 110,
                height: 110,
                fit: BoxFit.contain,
                // Kalau gambar tidak ditemukan, tampilkan ikon bawaan.
                errorBuilder: (_, _, _) => Container(
                  width: 96,
                  height: 96,
                  decoration: const BoxDecoration(
                    color: _kDeepPurple,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.link_off_rounded,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isPending
                    ? 'Batalkan tautan\ndengan $name?'
                    : 'Putuskan tautan\ndengan $name?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isPending
                    ? 'Anda yakin ingin membatalkan permintaan tautan dengan '
                        '$name? Permintaan yang sudah dikirim akan dihapus '
                        'dan $name tidak akan tertaut dengan Anda.'
                    : 'Anda yakin ingin memutus tautan dengan $name? '
                        'Setelah terputus, Anda tidak dapat lagi melihat & '
                        'mengelola lokasi dan jadwalnya.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF555566),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: _DialogButton(
                      label: isPending ? 'Kembali' : 'Batal',
                      background: _kLightPurple,
                      foreground: _kDeepPurple,
                      onTap: () => Navigator.pop(ctx, false),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _DialogButton(
                      label: isPending ? 'Batalkan' : 'Putuskan',
                      background: kPurple,
                      foreground: Colors.white,
                      onTap: () => Navigator.pop(ctx, true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _DialogButton extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  const _DialogButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 46,
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab filter (Semua / Tertaut / Menunggu / Ditolak)
// ---------------------------------------------------------------------------
class _FilterTabs extends StatelessWidget {
  final ConnectionFilter selected;
  final ValueChanged<ConnectionFilter> onChanged;

  const _FilterTabs({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: kPurple,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: ConnectionFilter.values.map((f) {
          final isSelected = f == selected;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(f),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 6),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  f.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? _kTextDark : Colors.white,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Kartu koneksi
// ---------------------------------------------------------------------------
class ConnectionCard extends StatelessWidget {
  final ConnectionRequest item;
  final VoidCallback? onDelete;

  const ConnectionCard({super.key, required this.item, this.onDelete});

  // Tombol hapus tidak muncul untuk status "Ditolak" (sesuai desain).
  bool get _canDelete => item.status != ConnectionStatus.ditolak;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _kCardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kCardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _Avatar(asset: _kDefaultAvatar),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.email,
                  style: const TextStyle(fontSize: 11, color: Colors.black87),
                ),
                const SizedBox(height: 6),
                StatusBadge(status: item.status),
              ],
            ),
          ),
          if (_canDelete)
            Align(
              alignment: Alignment.topCenter,
              child: InkWell(
                onTap: onDelete,
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.delete_outline,
                      size: 20, color: Color(0xFFE53935)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? asset;
  const _Avatar({this.asset});

  @override
  Widget build(BuildContext context) {
    const fallback = Icon(Icons.person, color: kPurple, size: 26);

    return Container(
      width: 52,
      height: 52,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: kPurple, width: 1.5),
      ),
      child: ClipOval(
        child: Container(
          color: const Color(0xFFE6E2FF),
          child: asset == null
              ? fallback
              : Image.asset(
                  asset!,
                  fit: BoxFit.cover,
                  // Kalau gambar tidak ditemukan, tampilkan ikon orang.
                  errorBuilder: (_, _, _) => fallback,
                ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Badge status
// ---------------------------------------------------------------------------
class StatusBadge extends StatelessWidget {
  final ConnectionStatus status;
  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final Color bg;
    late final Color fg;

    switch (status) {
      case ConnectionStatus.terhubung:
        label = 'Terhubung';
        bg = const Color(0xFFDDF7DD);
        fg = const Color(0xFF2E8B3A);
        break;
      case ConnectionStatus.menunggu:
        label = 'Menunggu';
        bg = const Color(0xFFFFF4C7);
        fg = const Color(0xFFB08800);
        break;
      case ConnectionStatus.ditolak:
        label = 'Ditolak';
        bg = const Color(0xFFFFD9D9);
        fg = const Color(0xFFD32F2F);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: fg.withAlpha(128), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}