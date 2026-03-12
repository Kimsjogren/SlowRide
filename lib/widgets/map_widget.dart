import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:slowride/models/alert_model.dart';

class MapWidget extends StatefulWidget {
  const MapWidget({
    super.key,
    this.currentLocation,
    this.destination,
    this.routePoints = const [],
    this.alerts = const [],
    this.onTap,
    this.followUser = false,
    this.onUserPanned,
    this.heading = 0,
    this.use3D = true,
    this.distToManeuver = double.infinity,
  });

  final LatLng? currentLocation;
  final LatLng? destination;
  final List<LatLng> routePoints;
  final List<AlertModel> alerts;
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

  /// Distance in metres to the next maneuver. Used for Waze-style dynamic
  /// zoom: the camera zooms in smoothly as the turn approaches.
  /// Defaults to [double.infinity] (= no dynamic zoom).
  final double distToManeuver;

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

  // ── Waze-style dynamic zoom ───────────────────────────────────────────────
  /// Returns the target zoom level based on distance to the next maneuver.
  double _targetZoom() {
    final base = widget.use3D ? 18.5 : 16.0;
    final d = widget.distToManeuver;
    if (d <= 0 || d > 300) return base;
    if (d < 50) return base + 2.0; // very close: +2
    if (d < 100) return base + 1.5; // close:      +1.5
    if (d < 200) return base + 0.8; // approaching: +0.8
    return base + 0.4; // 200–300 m:  +0.4
  }

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration _) {
    if (!widget.followUser || !_navInitialized) return;
    // kPos: position catches up in ~180ms at 60fps (was 0.18 = ~280ms).
    // kHdg: heading responds faster so turns feel immediate.
    const kPos = 0.25;
    const kHdg = 0.32;
    final dLat = _tgtLat - _curLat;
    final dLng = _tgtLng - _curLng;
    final diff = ((_tgtHdg - _curHdg + 540) % 360) - 180;

    // Deadband: skip moveAndRotate (= zero GPU work) when already at target.
    // 1e-7° ≈ 1 cm; 0.05° heading is imperceptible. This eliminates constant
    // 60fps repaints while the user is stationary.
    if (dLat.abs() < 1e-7 && dLng.abs() < 1e-7 && diff.abs() < 0.05) return;

    _curLat += dLat * kPos;
    _curLng += dLng * kPos;
    _curHdg = (_curHdg + diff * kHdg + 360) % 360;
    final zoom = _targetZoom();

    if (widget.use3D) {
      // In 3D mode shift the camera centre toward the heading so the user
      // dot sits in the lower third of the screen rather than the middle.
      // At zoom 18.5 one degree latitude ≈ 10 000 map units; we shift by
      // a fraction of a degree "behind" the heading direction.
      const offsetDeg = 0.00045; // ~50 m in lat/lng degrees
      final rad = _curHdg * 3.141592653589793 / 180.0;
      final cLat = _curLat + offsetDeg * math.cos(rad);
      final cLng = _curLng + offsetDeg * math.sin(rad);
      _mapController.moveAndRotate(LatLng(cLat, cLng), zoom, -_curHdg);
    } else {
      _mapController.moveAndRotate(LatLng(_curLat, _curLng), zoom, -_curHdg);
    }
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
      final zoom = _targetZoom();
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
    // CRITICAL: the widget tree RUNTIMETYPES must never change.
    // Changing Positioned height or Transform matrix is fine — Flutter just
    // relayouts/repaints. Only a type change would destroy FlutterMap.
    final is3D = widget.followUser && widget.use3D;

    // Strong Waze-style perspective: ~37° tilt anchored at bottom-centre.
    final matrix = is3D
        ? (Matrix4.identity()
            ..setEntry(3, 2, 0.001) // perspective depth
            ..rotateX(0.65)) // ≈ 37° forward tilt
        : Matrix4.identity();

    return ClipRRect(
      borderRadius: widget.followUser
          ? BorderRadius.zero
          : BorderRadius.circular(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.maxHeight;
          final w = constraints.maxWidth;

          // Normal height always — camera offset handles the 3D perspective
          // positioning. No oversized box that would push tiles off-screen.
          final mapHeight = h;

          final mapWidget = FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.currentLocation ?? MapWidget._defaultCenter,
              initialZoom: widget.followUser ? (is3D ? 18.5 : 16.0) : 12.0,
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
                // Pre-cache tiles outside the viewport to avoid
                // blank tile flashes when panning or rotating.
                keepBuffer: 4,
                panBuffer: 1,
              ),
              if (widget.routePoints.isNotEmpty) ...[
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
                  // Alert markers — community reports.
                  for (final alert in widget.alerts)
                    Marker(
                      point: alert.position,
                      width: 44,
                      height: 52,
                      alignment: const Alignment(0, -1),
                      child: _AlertMarker(alert: alert),
                    ),
                  if (widget.destination != null)
                    Marker(
                      point: widget.destination!,
                      width: 44,
                      height: 54,
                      alignment: const Alignment(0, -1),
                      child: const _DestinationPin(),
                    ),
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
          );

          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // ── Map — Positioned height changes, but type never changes ──
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: mapHeight,
                child: Transform(
                  alignment: Alignment.bottomCenter,
                  transform: matrix,
                  child: SizedBox(
                    width: w,
                    height: mapHeight,
                    child: mapWidget,
                  ),
                ),
              ),
              // ── Horizon fade — covers top ~40% in 3D to hide tilted sky ──
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: h * 0.45,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: is3D ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            const Color(0xFF0A1628).withValues(alpha: 0.98),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Alert marker ────────────────────────────────────────────────────────────

class _AlertMarker extends StatelessWidget {
  const _AlertMarker({required this.alert});
  final AlertModel alert;

  Color _bgColor(AlertType t) => switch (t) {
    AlertType.police => const Color(0xFF1565C0),
    AlertType.roadwork => const Color(0xFFE65100),
    AlertType.accident => const Color(0xFFC62828),
    AlertType.trafficJam => const Color(0xFFF57F17),
    AlertType.speedCamera => const Color(0xFF6A1B9A),
    AlertType.narrowRoad => const Color(0xFF00695C),
    AlertType.steepHill => const Color(0xFF37474F),
    _ => const Color(0xFF4A148C),
  };

  @override
  Widget build(BuildContext context) {
    final color = _bgColor(alert.type);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.6),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Center(
            child: Text(alert.type.emoji, style: const TextStyle(fontSize: 20)),
          ),
        ),
        // Small triangle tail.
        CustomPaint(
          size: const Size(10, 8),
          painter: _AlertTailPainter(color: color),
        ),
      ],
    );
  }
}

class _AlertTailPainter extends CustomPainter {
  const _AlertTailPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_AlertTailPainter old) => old.color != color;
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
