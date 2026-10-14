import 'package:flutter/material.dart';

import '../core/colors.dart';
import '../widgets/avatar.dart';
import 'tambah_tunanetra_data.dart';
import 'tambah_tunanetra_dialogs.dart';

// =====================================================================
//  HALAMAN TAUTKAN TUNANETRA
// =====================================================================

/// Jumlah kartu per halaman pada pagination.
const int _kPerPage = 5;

/// Warna kotak nomor halaman yang sedang aktif (senada desain).
const Color _kActivePage = Color(0xFFFBDCC4);

class TautkanTunanetraPage extends StatefulWidget {
  const TautkanTunanetraPage({super.key});

  @override
  State<TautkanTunanetraPage> createState() => _TautkanTunanetraPageState();
}

class _TautkanTunanetraPageState extends State<TautkanTunanetraPage> {
  final TextEditingController _search = TextEditingController();
  String _query = '';
  int _page = 0;

  /// Arah animasi pindah halaman: true = maju (ke kanan), false = mundur.
  bool _forward = true;

  void _goTo(int p) {
    if (p == _page) return;
    setState(() {
      _forward = p > _page;
      _page = p;
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Daftar yang sudah difilter sesuai kata kunci pencarian.
  List<Tunanetra> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return dummyTunanetra;
    return dummyTunanetra
        .where((t) =>
            t.name.toLowerCase().contains(q) ||
            t.email.toLowerCase().contains(q))
        .toList();
  }

  int get _totalPages {
    final n = _filtered.length;
    return n == 0 ? 1 : (n / _kPerPage).ceil();
  }

  Future<void> _onTautkan(Tunanetra person) async {
    final ok = await showTautkanDialog(context, person);
    if (!ok || !mounted) return;
    showTautkanSnack(context, '${person.name} berhasil ditautkan');
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    final totalPages = _totalPages;
    final page = _page.clamp(0, totalPages - 1);
    final pageItems = items.skip(page * _kPerPage).take(_kPerPage).toList();

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          children: [
            _Header(onBack: () => Navigator.of(context).maybePop()),
            _SearchBar(
              controller: _search,
              onChanged: (v) => setState(() {
                _query = v;
                _page = 0;
                _forward = true;
              }),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 340),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                // Halaman baru meluncur masuk searah (kiri/kanan) sambil
                // halaman lama meluncur keluar, plus fade halus.
                transitionBuilder: (child, anim) {
                  final begin = Offset(_forward ? 1.0 : -1.0, 0);
                  final slide = Tween<Offset>(begin: begin, end: Offset.zero)
                      .animate(anim);
                  return ClipRect(
                    child: FadeTransition(
                      opacity: anim,
                      child: SlideTransition(position: slide, child: child),
                    ),
                  );
                },
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.topCenter,
                  children: [...previous, ?current],
                ),
                child: pageItems.isEmpty
                    ? const _EmptyState(key: ValueKey('empty'))
                    : ListView.separated(
                        key: ValueKey('page-$page-$_query'),
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        itemCount: pageItems.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _TunanetraCard(
                          person: pageItems[i],
                          onTautkan: () => _onTautkan(pageItems[i]),
                        ),
                      ),
              ),
            ),
            _PaginationBar(
              page: page,
              totalPages: totalPages,
              onSelect: _goTo,
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
//  HEADER
// =====================================================================
class _Header extends StatelessWidget {
  final VoidCallback onBack;

  const _Header({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 20, 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: kPurple,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Tautkan Tunanetra',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: kTextPurple,
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
//  SEARCH BAR
// =====================================================================
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 48,
        padding: const EdgeInsets.fromLTRB(16, 0, 4, 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: kLightPurple),
          boxShadow: [
            BoxShadow(
              color: kPurple.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                textInputAction: TextInputAction.search,
                style: const TextStyle(fontSize: 14),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Cari Tunanetra',
                  hintStyle: TextStyle(fontSize: 14, color: Colors.black38),
                ),
              ),
            ),
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: kPurple,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_rounded,
                  color: Colors.white, size: 22),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
//  KARTU TUNANETRA
// =====================================================================
class _TunanetraCard extends StatelessWidget {
  final Tunanetra person;
  final VoidCallback onTautkan;

  const _TunanetraCard({required this.person, required this.onTautkan});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: kPurple.withValues(alpha: 0.10),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: kLightPurple, width: 2),
            ),
            child: const Avatar(radius: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  person.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  person.email,
                  style: const TextStyle(fontSize: 11, color: Colors.black45),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _LinkButton(onTap: onTautkan),
        ],
      ),
    );
  }
}

class _LinkButton extends StatelessWidget {
  final VoidCallback onTap;

  const _LinkButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kDarkPurple,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.link_rounded, color: Colors.white, size: 13),
              SizedBox(width: 4),
              Text(
                'Tautkan',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Tunanetra tidak ditemukan',
        style: TextStyle(fontSize: 13, color: Colors.black45),
      ),
    );
  }
}

// =====================================================================
//  PAGINATION
// =====================================================================
class _PaginationBar extends StatelessWidget {
  final int page;
  final int totalPages;
  final ValueChanged<int> onSelect;

  const _PaginationBar({
    required this.page,
    required this.totalPages,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: kLightPurple),
          boxShadow: [
            BoxShadow(
              color: kPurple.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            _PageNav(
              label: 'Prev',
              leading: Icons.chevron_left_rounded,
              enabled: page > 0,
              onTap: () => onSelect(page - 1),
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (int p = 0; p < totalPages; p++)
                      _PageNumber(
                        number: p + 1,
                        active: p == page,
                        onTap: () => onSelect(p),
                      ),
                  ],
                ),
              ),
            ),
            _PageNav(
              label: 'Next',
              trailing: Icons.chevron_right_rounded,
              enabled: page < totalPages - 1,
              onTap: () => onSelect(page + 1),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageNumber extends StatelessWidget {
  final int number;
  final bool active;
  final VoidCallback onTap;

  const _PageNumber({
    required this.number,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: active ? 1.15 : 1,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: 28,
          height: 28,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? _kActivePage : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: _kActivePage.withValues(alpha: 0.55),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 220),
            style: TextStyle(
              fontSize: 13,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? Colors.black87 : Colors.black54,
            ),
            child: Text('$number'),
          ),
        ),
      ),
    );
  }
}

class _PageNav extends StatelessWidget {
  final String label;
  final IconData? leading;
  final IconData? trailing;
  final bool enabled;
  final VoidCallback onTap;

  const _PageNav({
    required this.label,
    required this.enabled,
    required this.onTap,
    this.leading,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: kBtnLight,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading != null)
                  Icon(leading, size: 16, color: kDarkPurple),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: kDarkPurple,
                  ),
                ),
                if (trailing != null)
                  Icon(trailing, size: 16, color: kDarkPurple),
              ],
            ),
          ),
        ),
      ),
    );
  }
}