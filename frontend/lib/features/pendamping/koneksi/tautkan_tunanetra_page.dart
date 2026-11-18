import 'package:material_ui/material_ui.dart';

import '../../../core/colors.dart';
import 'tautkan_tunanetra_data.dart';
import 'widgets/tautkan_tunanetra_dialogs.dart';

// =====================================================================
//  HALAMAN TAUTKAN TUNANETRA
// =====================================================================

/// Jumlah kartu per halaman pada pagination.
const int _kPerPage = 5;

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
        child: SingleChildScrollView(
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
              const SizedBox(height: 16),
              AnimatedSwitcher(
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
                    : Padding(
                        key: ValueKey('page-$page-$_query'),
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (int i = 0; i < pageItems.length; i++) ...[
                              if (i > 0) const SizedBox(height: 10),
                              _TunanetraCard(
                                person: pageItems[i],
                                onTautkan: () => _onTautkan(pageItems[i]),
                              ),
                            ],
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 16),
              _PaginationBar(
                page: page,
                totalPages: totalPages,
                onSelect: _goTo,
              ),
            ],
          ),
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
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: kPurple,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chevron_left_rounded,
                  color: Colors.white, size: 24),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Tautkan Tunanetra',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
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
        padding: const EdgeInsets.fromLTRB(22, 0, 4, 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: kLightPurple),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
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
                cursorColor: kPurple,
                style: const TextStyle(fontSize: 14, color: kTextPurple),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Cari Tunanetra',
                  hintStyle: TextStyle(fontSize: 14, color: kTextPurple),
                ),
              ),
            ),
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: kPurple,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_rounded,
                  color: Colors.white, size: 24),
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
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kLightPurple),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(1),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: kPurple, width: 1),
            ),
            child: const _Avatar(radius: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  person.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  person.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
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
      color: kTitleIndigo,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
               Image(
                image: AssetImage('assets/icons/link.png'),
                width: 16,
                height: 16,
                color: Colors.white,
              ),
              SizedBox(width: 5),
              Text(
                'Tautkan',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
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
    return const SizedBox(
      height: 200,
      width: double.infinity,
      child: Center(
        child: Text(
          'Tunanetra tidak ditemukan',
          style: TextStyle(fontSize: 13, color: Colors.black45),
        ),
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
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
          decoration: BoxDecoration(
            color: kPurple,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kLightPurple, width: 1),
            boxShadow: [
              BoxShadow(
                color: kPurple.withValues(alpha: 0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PageNav(
                label: 'Prev',
                leading: Icons.chevron_left_rounded,
                enabled: page > 0,
                onTap: () => onSelect(page - 1),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
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
              const SizedBox(width: 6),
              _PageNav(
                label: 'Next',
                trailing: Icons.chevron_right_rounded,
                enabled: page < totalPages - 1,
                onTap: () => onSelect(page + 1),
              ),
            ],
          ),
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
        scale: active ? 1.1 : 1,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: 24,
          height: 26,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AliceColors.pinkMid : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 220),
            style: TextStyle(
              fontSize: 13,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? kPurple : Colors.white,
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
      opacity: enabled ? 1 : 0.6,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              leading != null ? 6 : 12,
              5,
              trailing != null ? 6 : 12,
              5,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading != null) Icon(leading, size: 18, color: kPurple),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: kPurple,
                  ),
                ),
                if (trailing != null) Icon(trailing, size: 18, color: kPurple),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final double radius;
  const _Avatar({required this.radius});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: kLightPurple,
      child: Icon(Icons.person, size: radius * 1.3, color: kDarkPurple),
    );
  }
}