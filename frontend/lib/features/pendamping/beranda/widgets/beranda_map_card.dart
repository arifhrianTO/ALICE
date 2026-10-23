import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../../../../core/colors.dart';
import '../tunanetra_location.dart';

// =====================================================================
//  PETA OPENSTREETMAP (INTERAKTIF - 1 MAP UNTUK 1 TUNANETRA)
// =====================================================================
class BerandaMapCard extends StatefulWidget {
  final TunanetraLocation location;

  const BerandaMapCard({
    super.key,
    required this.location,
  });

  @override
  State<BerandaMapCard> createState() => _BerandaMapCardState();
}

class _BerandaMapCardState extends State<BerandaMapCard> {
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void didUpdateWidget(covariant BerandaMapCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location.id != widget.location.id ||
        oldWidget.location.latitude != widget.location.latitude ||
        oldWidget.location.longitude != widget.location.longitude) {
      _mapController.move(
        LatLng(widget.location.latitude, widget.location.longitude),
        16.0,
      );
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _recenter() {
    _mapController.move(
      LatLng(widget.location.latitude, widget.location.longitude),
      16.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = widget.location;

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
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(loc.latitude, loc.longitude),
                initialZoom: 16.0,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  fallbackUrl:
                      'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.alice_app',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(
                        loc.latitude,
                        loc.longitude,
                      ),
                      width: 100,
                      height: 60,
                      alignment: Alignment.topCenter,
                      child: _TunanetraMarker(
                        name: loc.name,
                      ),
                    ),
                  ],
                ),
                const SimpleAttributionWidget(
                  source: Text('© OpenStreetMap'),
                ),
              ],
            ),
            // Tombol Re-center ke lokasi tunanetra aktif
            Positioned(
              right: 12,
              bottom: 12,
              child: Material(
                color: Colors.white,
                shape: const CircleBorder(),
                elevation: 4,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _recenter,
                  child: const Padding(
                    padding: EdgeInsets.all(9),
                    child: Icon(
                      Icons.my_location_rounded,
                      size: 22,
                      color: kDarkPurple,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TunanetraMarker extends StatelessWidget {
  final String name;

  const _TunanetraMarker({
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: kDarkPurple,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const Icon(
          Icons.location_on,
          size: 36,
          color: kPurple,
        ),
      ],
    );
  }
}

// =====================================================================
//  PETA LOADING FALLBACK (memakai ilustrasi saat memuat)
// =====================================================================
class MapLoadingFallback extends StatelessWidget {
  const MapLoadingFallback({super.key});

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
            Container(
              color: Colors.black.withValues(alpha: 0.08),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        color: kPurple,
                        strokeWidth: 3,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Memuat peta...',
                      style: TextStyle(
                        color: kDarkPurple,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
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
