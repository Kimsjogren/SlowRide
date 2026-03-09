import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapWidget extends StatefulWidget {
  const MapWidget({
    super.key,
    this.currentLocation,
    this.destination,
    this.routePoints = const [],
    this.onTap,
    this.followUser = false,
    this.onUserPanned,
    this.heading = 0,
  });

  final LatLng? currentLocation;
  final LatLng? destination;
  final List<LatLng> routePoints;
  final ValueChanged<LatLng>? onTap;
  final bool followUser;

  /// Called when the user manually pans the map during navigation.
  final VoidCallback? onUserPanned;

  /// Compass heading in degrees (0 = north, clockwise). Used to rotate
  /// the map so the direction of travel is always "up" (Waze-style).
  final double heading;

  static const LatLng _defaultCenter = LatLng(59.3293, 18.0686);

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  final MapController _mapController = MapController();

  @override
  void didUpdateWidget(MapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Waze-style: zoom in and orient map to heading when navigation starts.
    if (widget.followUser &&
        !oldWidget.followUser &&
        widget.currentLocation != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _mapController.moveAndRotate(
          widget.currentLocation!,
          17.0,
          -widget.heading,
        );
      });
      return;
    }

    // Waze-style: when a new route arrives (not navigating), fit route in view.
    if (!widget.followUser &&
        widget.routePoints.isNotEmpty &&
        widget.routePoints != oldWidget.routePoints) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final bounds = LatLngBounds.fromPoints(widget.routePoints);
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.fromLTRB(40, 100, 40, 160),
          ),
        );
      });
      return;
    }

    // During active navigation: move AND rotate so heading is always "up".
    if (widget.followUser &&
        widget.currentLocation != null &&
        (widget.currentLocation != oldWidget.currentLocation ||
            widget.heading != oldWidget.heading)) {
      _mapController.moveAndRotate(
        widget.currentLocation!,
        17.0,
        -widget.heading,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface),
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: widget.currentLocation ?? MapWidget._defaultCenter,
            initialZoom: widget.followUser ? 17.0 : 12.0,
            onTap: (_, point) => widget.onTap?.call(point),
            onPositionChanged: (camera, hasGesture) {
              // If user drags the map during navigation, notify parent.
              if (hasGesture && widget.followUser) {
                widget.onUserPanned?.call();
              }
            },
          ),
          children: [
            // Mapbox Navigation Night — dark Waze-style map perfect for driving.
            TileLayer(
              urlTemplate:
                  'https://api.mapbox.com/styles/v1/mapbox/navigation-night-v1/tiles/{z}/{x}/{y}@2x?access_token={mapbox_token}',
              additionalOptions: const {
                'mapbox_token':
                    'pk.eyJ1Ijoia2ltc2pvZ3JlbjE5ODciLCJhIjoiY21taXQ0dDB3MWJlMzJxczUzc2tvZDN2NyJ9.-eZcy-sIG46WBe_y05rUeQ',
              },
              userAgentPackageName: 'com.kimtechtool.slowride',
              tileDimension: 512,
              zoomOffset: -1,
            ),
            if (widget.routePoints.isNotEmpty) ...[
              // Outer glow (Waze-style).
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: widget.routePoints,
                    strokeWidth: 11,
                    color: const Color(0xFF1E90FF).withValues(alpha: 0.25),
                    strokeCap: StrokeCap.round,
                    strokeJoin: StrokeJoin.round,
                  ),
                ],
              ),
              // Inner route line.
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: widget.routePoints,
                    strokeWidth: 6,
                    color: const Color(0xFF1E90FF),
                    strokeCap: StrokeCap.round,
                    strokeJoin: StrokeJoin.round,
                  ),
                ],
              ),
            ],
            MarkerLayer(
              markers: [
                // Destination pin.
                if (widget.destination != null)
                  Marker(
                    point: widget.destination!,
                    width: 44,
                    height: 54,
                    alignment: const Alignment(0, -1),
                    child: const _DestinationPin(),
                  ),
                // Current location — glowing arrow rotated to heading.
                if (widget.currentLocation != null)
                  Marker(
                    point: widget.currentLocation!,
                    width: 48,
                    height: 48,
                    child: _LocationDot(heading: widget.heading),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Premium marker widgets ──────────────────────────────────────────────────

class _LocationDot extends StatelessWidget {
  const _LocationDot({this.heading = 0});

  final double heading;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Transform.rotate(
        // heading 0 = north; Icons.navigation_rounded already points up (north)
        // so we just rotate by heading degrees converted to radians.
        angle: heading * 3.141592653589793 / 180.0,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF1E90FF),
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E90FF).withValues(alpha: 0.75),
                blurRadius: 10,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: const Color(0xFF1E90FF).withValues(alpha: 0.30),
                blurRadius: 22,
                spreadRadius: 8,
              ),
            ],
          ),
          child: const Icon(
            Icons.navigation_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _DestinationPin extends StatelessWidget {
  const _DestinationPin();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFFF3B30),
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF3B30).withValues(alpha: 0.5),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(Icons.flag_rounded, color: Colors.white, size: 18),
        ),
        // Pin tail.
        CustomPaint(size: const Size(12, 10), painter: _PinTailPainter()),
      ],
    );
  }
}

class _PinTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFF3B30)
      ..style = PaintingStyle.fill;
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_PinTailPainter oldDelegate) => false;
}
