import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
    this.use3D = true,
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

  /// When true and [followUser] is active, renders the Waze-style 3-D
  /// perspective tilt. When false the map stays flat (2-D top-down).
  final bool use3D;

  static const LatLng _defaultCenter = LatLng(59.3293, 18.0686);

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();

  // ── Smooth camera animation ────────────────────────────────────────────
  late final Ticker _ticker;
  double _curLat = 0, _curLng = 0, _curHdg = 0;
  double _tgtLat = 0, _tgtLng = 0, _tgtHdg = 0;
  bool _navInitialized = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration _) {
    if (!widget.followUser || !_navInitialized) return;
    const k = 0.18;
    _curLat += (_tgtLat - _curLat) * k;
    _curLng += (_tgtLng - _curLng) * k;
    final diff = ((_tgtHdg - _curHdg + 540) % 360) - 180;
    _curHdg = (_curHdg + diff * k + 360) % 360;
    // 3D = zoom 18.5 (close-up street level), 2D = zoom 16 (wider view).
    final zoom = widget.use3D ? 18.5 : 16.0;
    _mapController.moveAndRotate(LatLng(_curLat, _curLng), zoom, -_curHdg);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(MapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Waze-style: zoom in and orient map to heading when navigation starts.
    if (widget.followUser &&
        !oldWidget.followUser &&
        widget.currentLocation != null) {
      _curLat = _tgtLat = widget.currentLocation!.latitude;
      _curLng = _tgtLng = widget.currentLocation!.longitude;
      _curHdg = _tgtHdg = widget.heading;
      _navInitialized = true;
      final zoom = widget.use3D ? 18.5 : 16.0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _mapController.moveAndRotate(
          widget.currentLocation!,
          zoom,
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

    // 3D↔2D toggle during nav: snap zoom immediately.
    if (widget.followUser &&
        widget.use3D != oldWidget.use3D &&
        _navInitialized) {
      final zoom = widget.use3D ? 18.5 : 16.0;
      _mapController.moveAndRotate(LatLng(_curLat, _curLng), zoom, -_curHdg);
    }

    // During active navigation: update animation TARGET.
    if (widget.followUser &&
        widget.currentLocation != null &&
        (widget.currentLocation != oldWidget.currentLocation ||
            widget.heading != oldWidget.heading)) {
      if (!_navInitialized) {
        _curLat = widget.currentLocation!.latitude;
        _curLng = widget.currentLocation!.longitude;
        _curHdg = widget.heading;
        _navInitialized = true;
      }
      _tgtLat = widget.currentLocation!.latitude;
      _tgtLng = widget.currentLocation!.longitude;
      _tgtHdg = widget.heading;
    }

    // Reset when navigation ends.
    if (!widget.followUser && oldWidget.followUser) {
      _navInitialized = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Single stable widget tree — never changes structure so Flutter never
    // destroys/recreates FlutterMap (which would cause a white flash).
    final borderRadius = widget.followUser
        ? BorderRadius.zero
        : BorderRadius.circular(12);

    return ClipRRect(
      borderRadius: borderRadius,
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: widget.currentLocation ?? MapWidget._defaultCenter,
          initialZoom: widget.followUser ? (widget.use3D ? 18.5 : 16.0) : 12.0,
          onTap: (_, point) => widget.onTap?.call(point),
          onPositionChanged: (camera, hasGesture) {
            if (hasGesture && widget.followUser) {
              widget.onUserPanned?.call();
            }
          },
        ),
        children: [
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
