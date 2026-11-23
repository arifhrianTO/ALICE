import 'package:material_ui/material_ui.dart';

import '../../../../core/colors.dart';
import '../tunanetra_location.dart';

// =====================================================================
//  PLACEHOLDER SAAT LOADING DROPDOWN
// =====================================================================
class DropdownLoadingPlaceholder extends StatelessWidget {
  const DropdownLoadingPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: kDarkPurple,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundImage: AssetImage('assets/icons/profil.png'),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Memuat data...',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Silakan tunggu',
                  style: TextStyle(
                    color: Colors.white70,
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
//  PROFIL + DROPDOWN AKUN (dengan animasi)
// =====================================================================
class ProfileDropdown extends StatefulWidget {
  final List<TunanetraLocation> accounts;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  const ProfileDropdown({
    super.key,
    required this.accounts,
    required this.currentIndex,
    required this.onSelected,
  });

  @override
  State<ProfileDropdown> createState() => _ProfileDropdownState();
}

class _ProfileDropdownState extends State<ProfileDropdown>
    with SingleTickerProviderStateMixin {
  final LayerLink _link = LayerLink();
  final OverlayPortalController _portal = OverlayPortalController();
  late final AnimationController _ctrl;
  late final Animation<double> _curve;

  double _width = 300;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      reverseDuration: const Duration(milliseconds: 250),
    )..addStatusListener((status) {
        if (status == AnimationStatus.dismissed) _portal.hide();
      });

    _curve = CurvedAnimation(
      parent: _ctrl,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    final closing =
        _ctrl.status == AnimationStatus.forward ||
        _ctrl.status == AnimationStatus.completed;

    if (closing) {
      _ctrl.reverse();
    } else {
      _portal.show();
      _ctrl.forward();
    }
  }

  void _select(int i) {
    widget.onSelected(i);
    _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _portal,
        overlayChildBuilder: _buildOverlay,
        child: LayoutBuilder(
          builder: (context, constraints) {
            _width = constraints.maxWidth;
            return _buildHeader();
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    if (widget.accounts.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: kDarkPurple,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: Text(
            'Belum ada akun tunanetra tertaut',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final safeIndex =
        widget.currentIndex.clamp(0, widget.accounts.length - 1);
    final acc = widget.accounts[safeIndex];

    return GestureDetector(
      onTap: _toggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const CircleAvatar(
              radius: 26,
              backgroundImage: AssetImage('assets/icons/profil.png'),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  layoutBuilder: (currentChild, previousChildren) {
                    return Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        ...previousChildren,
                        ?currentChild,
                      ],
                    );
                  },
                  child: Column(
                    key: ValueKey(acc.id),
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        acc.name,
                        textAlign: TextAlign.left,
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
                        acc.email,
                        textAlign: TextAlign.left,
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
              ),
            ),
            RotationTransition(
              turns: Tween<double>(
                begin: 0,
                end: 0.5,
              ).animate(_curve),
              child: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlay(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => _ctrl.reverse(),
          ),
        ),
        CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 6),
          child: SizedBox(
            width: _width,
            child: Material(
              type: MaterialType.transparency,
              child: FadeTransition(
                opacity: _curve,
                child: SizeTransition(
                  sizeFactor: _curve,
                  alignment: Alignment.topCenter,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: kDarkPurple,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (int i = 0; i < widget.accounts.length; i++)
                          _staggered(
                            i,
                            Padding(
                              padding: EdgeInsets.only(
                                bottom:
                                    i == widget.accounts.length - 1 ? 0 : 12,
                              ),
                              child: _AccountTile(
                                account: widget.accounts[i],
                                selected: i == widget.currentIndex,
                                onTap: () => _select(i),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _staggered(int index, Widget child) {
    final anim = CurvedAnimation(
      parent: _ctrl,
      curve: Interval(
        0.2 + index * 0.15,
        0.8 + index * 0.15,
        curve: Curves.easeOutCubic,
      ),
    );

    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -0.3),
          end: Offset.zero,
        ).animate(anim),
        child: child,
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  final TunanetraLocation account;
  final bool selected;
  final VoidCallback onTap;

  const _AccountTile({
    required this.account,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: kPurple, width: 1.5),
                ),
                child: const CircleAvatar(
                  radius: 20,
                  backgroundImage: AssetImage('assets/icons/profil.png'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      account.email,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedScale(
                scale: selected ? 1 : 0,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutBack,
                child: const Icon(
                  Icons.check_circle,
                  color: kPurple,
                  size: 20,
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
//  BARIS ALAMAT
// =====================================================================
class AddressRow extends StatelessWidget {
  final String address;

  const AddressRow({super.key, required this.address});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(Icons.location_on, color: kPurple, size: 26),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            address,
            textAlign: TextAlign.left,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
