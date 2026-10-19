import 'package:flutter/material.dart';

import '../core/colors.dart';

// =====================================================================
//  HALAMAN BERANDA
// =====================================================================
class BerandaPage extends StatelessWidget {
  const BerandaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: const _NoStretchScrollBehavior(),
      child: SingleChildScrollView(
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
            const ProfileDropdown(),
            const SizedBox(height: 14),
            const _AddressRow(),
            const SizedBox(height: 10),
            const _MapCard(),
            const SizedBox(height: 14),
            const Row(
              children: [
                Expanded(
                  child: _InfoCard(
                    imagePath: 'assets/icons/baterai.png',
                    value: '89%',
                    label: 'Baterai saat ini',
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _InfoCard(
                    imagePath: 'assets/icons/suhu.png',
                    value: '35°C',
                    label: 'Suhu saat ini',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const _UpcomingCard(),
          ],
        ),
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

// =====================================================================
//  PROFIL + DROPDOWN AKUN (dengan animasi)
// =====================================================================
class Account {
  final String name;
  final String email;

  const Account(this.name, this.email);
}

class ProfileDropdown extends StatefulWidget {
  const ProfileDropdown({super.key});

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
  int _current = 0;

  final List<Account> _accounts = const [
    Account('Budi Santoso', 'BudiSantoso@gmail.com'),
    Account('Budi Santoso', 'BudiSantoso@gmail.com'),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      reverseDuration: const Duration(milliseconds: 250),
    )..addStatusListener((status) {
        // sembunyikan overlay setelah animasi tutup selesai
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
    setState(() => _current = i);
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
    final acc = _accounts[_current];

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
                    key: ValueKey(_current),
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

  // ---- Panel dropdown (overlay di atas peta) ----
  Widget _buildOverlay(BuildContext context) {
    return Stack(
      children: [
        // Area transparan: tap di luar untuk menutup
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
                        for (int i = 0; i < _accounts.length; i++)
                          _staggered(
                            i,
                            Padding(
                              padding: EdgeInsets.only(
                                bottom:
                                    i == _accounts.length - 1 ? 0 : 12,
                              ),
                              child: _AccountTile(
                                account: _accounts[i],
                                selected: i == _current,
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

  // Item muncul berurutan (fade + slide dari atas)
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
  final Account account;
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
//  ALAMAT
// =====================================================================
class _AddressRow extends StatelessWidget {
  const _AddressRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(Icons.location_on, color: kPurple, size: 26),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Jl. Ahmad Yani, Tlk. Tering, Kec. Batam Kota, Kota Batam, Kepulauan Riau 29461',
            textAlign: TextAlign.left,
            style: TextStyle(
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

// =====================================================================
//  PETA (ilustrasi CustomPaint)
// =====================================================================
class _MapCard extends StatelessWidget {
  const _MapCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _MapPainter()),
            const Align(
              alignment: Alignment(0, -0.05),
              child: Icon(
                Icons.location_on,
                size: 48,
                color: kTextPurple,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFDCE3EA),
    );

    final green = Paint()..color = const Color(0xFFB9DB94);
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(w * 0.45, 0)
        ..quadraticBezierTo(w * 0.3, h * 0.2, w * 0.12, h * 0.28)
        ..lineTo(0, h * 0.3)
        ..close(),
      green,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.65, h * 0.68)
        ..quadraticBezierTo(w * 0.8, h * 0.6, w * 0.95, h * 0.75)
        ..lineTo(w * 0.85, h * 0.85)
        ..quadraticBezierTo(w * 0.7, h * 0.85, w * 0.65, h * 0.68)
        ..close(),
      green,
    );

    final water = Paint()..color = const Color(0xFF9CC8EE);
    canvas.drawOval(
      Rect.fromLTWH(w * 0.38, h * 0.3, w * 0.07, h * 0.16),
      water,
    );
    canvas.drawOval(
      Rect.fromLTWH(w * 0.25, h * 0.7, w * 0.07, h * 0.1),
      water,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.6, h)
        ..quadraticBezierTo(w * 0.8, h * 0.9, w, h * 0.88)
        ..lineTo(w, h)
        ..close(),
      water,
    );

    final road = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    void line(
      double x1,
      double y1,
      double x2,
      double y2,
      double width,
    ) {
      road.strokeWidth = width;
      canvas.drawLine(
        Offset(w * x1, h * y1),
        Offset(w * x2, h * y2),
        road,
      );
    }

    line(0, 0.55, 1, 0.5, 8);
    line(0.1, 0.1, 0.6, 1, 6);
    line(0.55, 0, 0.45, 1, 10);
    line(0, 0.75, 0.5, 0.65, 5);
    line(0.7, 0, 0.95, 1, 5);
    line(0.2, 0.35, 0.9, 0.28, 4);
    line(0.3, 0.9, 1, 0.65, 4);
    line(0.05, 0.25, 0.4, 0.15, 3);
    line(0.65, 0.5, 0.65, 1, 3);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// =====================================================================
//  KARTU BATERAI / SUHU
// =====================================================================
class _InfoCard extends StatelessWidget {
  final String imagePath;
  final String value;
  final String label;

  const _InfoCard({
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
//  KARTU AGENDA
// =====================================================================
class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard();

  @override
  Widget build(BuildContext context) {
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
      child: Stack(
        children: [
          const Column(
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
                'Zoom call, General\nMeeting.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  height: 1.25,
                ),
              ),
              SizedBox(height: 32),
            ],
          ),
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD9DF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.notifications,
                    size: 13,
                    color: Color(0xFF8A2A3C),
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Ingatkan di 08:55',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF8A2A3C),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Chip "Tiap Minggu" (kiri bawah)
          Positioned(
            left: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.repeat_rounded,
                    size: 14,
                    color: Colors.black,
                  ),
                  SizedBox(width: 5),
                  Text(
                    'Tiap Minggu',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Positioned(
            right: 0,
            bottom: 0,
            child: Text(
              '09:00',
              style: TextStyle(
                color: Colors.white,
                fontSize: 38,
                fontWeight: FontWeight.bold,
                height: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
