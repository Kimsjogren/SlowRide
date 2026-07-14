import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:slowride/models/alert_model.dart';
import 'package:slowride/widgets/user_location_marker.dart';

class MapWidget extends StatefulWidget {
  const MapWidget({
    super.key,
    required this.locationNotifier,
    required this.headingNotifier,
    this.destination,
    this.routePoints = const [],
    this.alerts = const [],
    this.studdedTireBanZones = const [],
    this.chargingStations = const [],
    this.onTap,
    this.followUser = false,
    this.onUserPanned,
    this.use3D = true,
    this.darkMode = false,
    this.nextManeuverDistanceMeters,
    this.nextManeuverSign,
  });

  /// Notifiers updated directly by the GPS listener — bypasses setState on
  /// the parent screen so MapWidget doesn't rebuild every GPS tick.
  final ValueNotifier<LatLng?> locationNotifier;
  final ValueNotifier<double> headingNotifier;

  final LatLng? destination;
  final List<LatLng> routePoints;
  final List<AlertModel> alerts;

  /// Polygon zones where studded tires are banned. Rendered as red overlay.
  final List<List<LatLng>> studdedTireBanZones;

  /// EV charging station positions to show as green markers.
  final List<LatLng> chargingStations;
  final ValueChanged<LatLng>? onTap;
  final bool followUser;

  /// Called when the user manually pans the map during navigation.
  final VoidCallback? onUserPanned;

  /// When true and [followUser] is active, renders the Waze-style 3-D
  /// perspective tilt. When false the map stays flat (2-D top-down).
  final bool use3D;

  /// Light/dark map style toggle.
  final bool darkMode;

  /// Distance to next maneuver in meters while navigating.
  /// Used for adaptive turn zoom similar to major navigation apps.
  final double? nextManeuverDistanceMeters;

  /// Sign/type of next maneuver. Used to increase zoom for sharper turns.
  final int? nextManeuverSign;

  static const LatLng _defaultCenter = LatLng(59.3293, 18.0686);

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget>
    with SingleTickerProviderStateMixin {
  static const double _k3DTiltRad = 0.44; // ~25 deg
  static const double _k3DArrowAlignmentY = 0.30;
  static const double _k3DLeadBaseDeg = 0.00042;

  final MapController _mapController = MapController();
  late final http.Client _tileHttpClient;
  late final NetworkTileProvider _tileProvider;

  // ── Marker state (updated via notifiers, isolated from parent setState) ──
  LatLng? _markerLocation;

  // Smooth heading notifier — driven by the ticker at 60fps so the arrow
  // interpolates instead of jumping to raw GPS heading each tick.
  late final ValueNotifier<double> _arrowHdg;

  // ── Smooth camera animation ────────────────────────────────────────────
  late final Ticker _ticker;
  double _curLat = 0, _curLng = 0, _curHdg = 0;
  double _tgtLat = 0, _tgtLng = 0, _tgtHdg = 0;
  double _filteredTgtHdg = 0;
  double _curArrowRelHdg = 0;
  double _rawCompassHdg = 0;
  double _gpsSpeedMps = 0;
  DateTime? _lastGpsAt;
  Duration? _lastTickAt;
  Duration? _lastCameraTickAt;
  bool _navInitialized = false;
  LatLng? _lastLocForBearing;
  int _lastRouteIdx = 0;

  double _curZoom = 16.0;
  double _tgtZoom = 16.0;

  double _computeNavZoom() {
    // Base cruise zoom tuned for readability and tile stability.
    final baseZoom = widget.use3D ? 17.5 : 16.0;
    final maneuverDist = widget.nextManeuverDistanceMeters;
    if (maneuverDist == null || maneuverDist <= 0) return baseZoom;

    // Continuous zoom profile to avoid threshold jitter near bucket edges.
    final nearFactor = ((320.0 - maneuverDist) / 320.0).clamp(0.0, 1.0);
    final distBoost = math.pow(nearFactor, 1.28).toDouble() * 1.05;

    final sign = widget.nextManeuverSign ?? 0;
    final absSign = sign.abs();
    final signBoost = switch (absSign) {
      3 => 0.42,
      2 => 0.28,
      1 => 0.14,
      6 => 0.34,
      _ => 0.0,
    };

    // Apply sign boost mostly when we're reasonably close to the turn.
    final proximityWeight = ((220.0 - maneuverDist) / 220.0).clamp(0.0, 1.0);
    final add = distBoost + signBoost * proximityWeight;

    final maxZoom = widget.use3D ? 18.8 : 17.2;
    return (baseZoom + add).clamp(baseZoom, maxZoom);
  }

  @override
  void initState() {
    super.initState();
    _tileHttpClient = http.Client();
    _tileProvider = NetworkTileProvider(
      httpClient: _tileHttpClient,
      abortObsoleteRequests: true,
      cachingProvider: BuiltInMapCachingProvider.getOrCreateInstance(
        maxCacheSize: 1_000_000_000,
      ),
    );
    _markerLocation = widget.locationNotifier.value;
    _rawCompassHdg = widget.headingNotifier.value;
    _arrowHdg = ValueNotifier<double>(_rawCompassHdg);
    widget.locationNotifier.addListener(_onLocationUpdate);
    widget.headingNotifier.addListener(_onHeadingUpdate);
    _ticker = createTicker(_onTick)..start();
  }

  double _wrap360(double angle) => (angle % 360 + 360) % 360;

  double _angleDiff(double from, double to) {
    return ((to - from + 540) % 360) - 180;
  }

  // Cheap local approximation for short GPS segments.
  double _segmentMeters(LatLng a, LatLng b) {
    const lat2m = 111320.0;
    final lng2m = 111320.0 * math.cos(a.latitude * math.pi / 180.0);
    final dx = (b.latitude - a.latitude) * lat2m;
    final dy = (b.longitude - a.longitude) * lng2m;
    return math.sqrt(dx * dx + dy * dy);
  }

  double _bearingDeg(LatLng from, LatLng to) {
    final dLat = to.latitude - from.latitude;
    final dLng =
        (to.longitude - from.longitude) *
        math.cos(from.latitude * math.pi / 180.0);
    return _wrap360(math.atan2(dLng, dLat) * 180 / math.pi);
  }

  /// Distance-based lookahead: find heading 40m ahead along route.
  /// Much more stable than naive "next 3 points" approach.
  double _routeLookaheadHeading(int startIdx, double lookaheadM) {
    final pts = widget.routePoints;
    if (pts.length < 2) return _rawCompassHdg;
    final i = startIdx.clamp(0, pts.length - 1);

    // Walk along route until we've traveled lookaheadM meters.
    double accum = 0;
    int endIdx = i;
    for (int j = i; j < pts.length - 1 && accum < lookaheadM; j++) {
      accum += _segmentMeters(pts[j], pts[j + 1]);
      endIdx = j + 1;
    }
    // If route is too short, just use last point.
    if (endIdx == i && i < pts.length - 1) endIdx = i + 1;

    return _bearingDeg(pts[i], pts[endIdx]);
  }

  /// Project location onto nearest route segment (not just nearest point).
  /// Returns (closestPoint, segmentIndex, distanceToRoute).
  (LatLng, int, double) _projectOntoRoute(LatLng loc) {
    final pts = widget.routePoints;
    if (pts.length < 2) return (loc, 0, 0);

    // Scan forward from last known index (never go backwards to avoid jumps).
    final searchStart = _lastRouteIdx.clamp(0, pts.length - 2);
    final searchEnd = (searchStart + 50).clamp(0, pts.length - 2);

    int bestSeg = searchStart;
    double bestDistSq = double.infinity;
    LatLng bestProj = pts[searchStart];

    for (int i = searchStart; i <= searchEnd; i++) {
      final a = pts[i];
      final b = pts[i + 1];
      // Project loc onto segment a–b.
      final (proj, distSq) = _projectPointOnSegment(loc, a, b);
      if (distSq < bestDistSq) {
        bestDistSq = distSq;
        bestProj = proj;
        bestSeg = i;
      }
    }

    // Only advance if we've clearly passed current segment start.
    // This prevents "magnetizing" to far-ahead segments at intersections.
    if (bestSeg > _lastRouteIdx) {
      final distToOldStart = _segmentMeters(loc, pts[_lastRouteIdx]);
      if (distToOldStart > 8) {
        _lastRouteIdx = bestSeg;
      }
    }

    return (bestProj, _lastRouteIdx, math.sqrt(bestDistSq));
  }

  /// Project point P onto line segment A–B, return (projectedPoint, distanceSq).
  (LatLng, double) _projectPointOnSegment(LatLng p, LatLng a, LatLng b) {
    const lat2m = 111320.0;
    final lng2m = 111320.0 * math.cos(a.latitude * math.pi / 180.0);

    final ax = a.latitude * lat2m;
    final ay = a.longitude * lng2m;
    final bx = b.latitude * lat2m;
    final by = b.longitude * lng2m;
    final px = p.latitude * lat2m;
    final py = p.longitude * lng2m;

    final abx = bx - ax;
    final aby = by - ay;
    final apx = px - ax;
    final apy = py - ay;

    final abLenSq = abx * abx + aby * aby;
    if (abLenSq < 1e-10) {
      // Degenerate segment.
      final dx = px - ax;
      final dy = py - ay;
      return (a, dx * dx + dy * dy);
    }

    var t = (apx * abx + apy * aby) / abLenSq;
    t = t.clamp(0.0, 1.0);

    final projX = ax + t * abx;
    final projY = ay + t * aby;
    final dx = px - projX;
    final dy = py - projY;

    final projLat = projX / lat2m;
    final projLng = projY / lng2m;
    return (LatLng(projLat, projLng), dx * dx + dy * dy);
  }

  (double heading, double distToRouteM)? _routeHeadingNear(LatLng loc) {
    final pts = widget.routePoints;
    if (pts.length < 2) return null;

    final (_, segIdx, distM) = _projectOntoRoute(loc);

    // 40m lookahead for smooth heading that doesn't flip at turns.
    final heading = _routeLookaheadHeading(segIdx, 40.0);
    return (heading, distM);
  }

  void _onLocationUpdate() {
    final loc = widget.locationNotifier.value;
    if (loc == null || !mounted) return;
    // Update ticker targets (no setState — ticker reads these fields directly).
    if (widget.followUser) {
      if (!_navInitialized) {
        _curLat = _tgtLat = loc.latitude;
        _curLng = _tgtLng = loc.longitude;
        _filteredTgtHdg = _rawCompassHdg;
        _tgtHdg = _rawCompassHdg;
        _curArrowRelHdg = 0;
        _arrowHdg.value = 0;
        _lastLocForBearing = loc;
        _lastGpsAt = DateTime.now();
        _curZoom = _tgtZoom = _computeNavZoom();
        _navInitialized = true;
      } else {
        final prev = _lastLocForBearing;
        final now = DateTime.now();
        double meters = 0;
        final routeInfo = _routeHeadingNear(loc);
        final routeHeading = routeInfo?.$1;
        final distToRouteM = routeInfo?.$2;
        if (prev != null) {
          meters = _segmentMeters(prev, loc);
          final dt = _lastGpsAt == null
              ? 0.0
              : now.difference(_lastGpsAt!).inMilliseconds / 1000.0;
          if (dt > 0.02) {
            _gpsSpeedMps = meters / dt;
          }

          // Ignore tiny GPS drift while almost stationary.
          final distToTarget = _segmentMeters(LatLng(_tgtLat, _tgtLng), loc);
          final shouldMoveCameraTarget =
              _gpsSpeedMps > 2.0 || distToTarget > 2.0;
          if (shouldMoveCameraTarget) {
            // Blend new GPS fix into the (possibly dead-reckoned) target.
            // Lower blend (0.22) = trust dead reckoning more → smoother ride.
            if (_gpsSpeedMps > 3.0 && distToTarget < 25.0) {
              const blend = 0.22;
              _tgtLat = _tgtLat * (1 - blend) + loc.latitude * blend;
              _tgtLng = _tgtLng * (1 - blend) + loc.longitude * blend;
            } else {
              // Low speed, or large jump (lost fix, teleport) → snap.
              _tgtLat = loc.latitude;
              _tgtLng = loc.longitude;
            }
          }

          // Movement bearing is primary target. Compass is only blended in
          // at very low speeds where GPS bearing is unreliable.
          double? motionHeading;
          if (meters > 2.0 && _gpsSpeedMps > 1.2) {
            motionHeading = _wrap360(
              math.atan2(
                    loc.longitude - prev.longitude,
                    loc.latitude - prev.latitude,
                  ) *
                  180 /
                  math.pi,
            );
          }

          // ROUTE-LOCKED HEADING: When navigating on a route, use route
          // direction exclusively. This is how Google Maps/Waze work.
          if (routeHeading != null && (distToRouteM ?? 999) < 45) {
            // Full route lock when on route - no compass, no motion blending.
            _tgtHdg = routeHeading;
          } else if (motionHeading != null) {
            // Off-route or no route: use GPS motion heading
            _tgtHdg = motionHeading;
          } else if (_gpsSpeedMps < 1.0) {
            // At very low speed, keep heading stable instead of chasing noise.
            _tgtHdg = _filteredTgtHdg;
          }

          // POSITION SNAPPING: Progressive blend toward road when nearby.
          // Uses wider zone (45m) to handle typical phone GPS inaccuracy.
          // Gradual blend avoids hard teleports when the projected segment changes.
          final snapDist = distToRouteM ?? 999;
          if (snapDist < 45 && widget.routePoints.length >= 2) {
            final (snappedPos, _, _) = _projectOntoRoute(loc);
            // snapBlend: 1.0 at 0m → 0.0 at 45m (keeps arrow on road firmly)
            final snapBlend = ((45.0 - snapDist) / 45.0).clamp(0.0, 1.0);
            _tgtLat =
                _tgtLat * (1 - snapBlend) + snappedPos.latitude * snapBlend;
            _tgtLng =
                _tgtLng * (1 - snapBlend) + snappedPos.longitude * snapBlend;
          }
        }
        _lastLocForBearing = loc;
        _lastGpsAt = now;

        // Separate low-pass for target heading (decoupled from camera angle).
        final targetAlpha = (_gpsSpeedMps / 16.0).clamp(0.08, 0.32);
        final targetStep = _angleDiff(_filteredTgtHdg, _tgtHdg);
        _filteredTgtHdg = _wrap360(_filteredTgtHdg + targetStep * targetAlpha);
        _tgtZoom = _computeNavZoom();
      }
    }
    // In follow mode we render a fixed overlay marker, so avoid rebuilding
    // the whole map tree on every GPS sample.
    if (widget.followUser) {
      _markerLocation = loc;
      return;
    }

    // Outside follow mode we still need marker updates inside MarkerLayer.
    if (mounted) setState(() => _markerLocation = loc);
  }

  void _onHeadingUpdate() {
    _rawCompassHdg = widget.headingNotifier.value;
    // In follow mode, heading updates are blended in _onLocationUpdate.
    if (widget.followUser) return;

    _tgtHdg = _rawCompassHdg;
    // In non-nav mode the ticker isn't running, so push _arrowHdg directly.
    // ValueListenableBuilder inside _LocationDot handles the repaint —
    // no setState needed here at all.
    _arrowHdg.value = widget.headingNotifier.value;
  }

  void _onTick(Duration elapsed) {
    if (!widget.followUser || !_navInitialized) return;

    final tickNow = elapsed;
    final lastTick = _lastTickAt;
    _lastTickAt = tickNow;
    if (lastTick == null) return;

    final dtSec = (tickNow - lastTick).inMicroseconds / 1000000.0;
    if (dtSec <= 0) return;

    // ── Dead reckoning ────────────────────────────────────────────────────
    // GPS arrives at ~1Hz; without prediction the marker freezes for ~1s
    // between samples and then jumps forward → visible "hackar fram" stutter.
    // Extrapolate the target forward using last known speed + heading so the
    // camera glides continuously. Only kick in when we're clearly moving and
    // have a recent GPS fix (avoid runaway if GPS is lost).
    final lastGps = _lastGpsAt;
    if (_gpsSpeedMps > 0.8 &&
        lastGps != null &&
        DateTime.now().difference(lastGps).inMilliseconds < 2500) {
      final hdgRad = _filteredTgtHdg * math.pi / 180.0;
      final dM = _gpsSpeedMps * dtSec;
      const lat2m = 111320.0;
      final lng2m = 111320.0 * math.cos(_tgtLat * math.pi / 180.0);
      _tgtLat += dM * math.cos(hdgRad) / lat2m;
      _tgtLng += dM * math.sin(hdgRad) / lng2m;
    }

    // Speed-adaptive smoothing: stable at low speed, responsive at higher speed.
    final speedN = (_gpsSpeedMps / 16.0).clamp(0.0, 1.0);
    final posAlpha = (dtSec * (2.0 + speedN * 2.5)).clamp(0.03, 0.30);
    final hdgAlpha = (dtSec * (1.5 + speedN * 2.8)).clamp(0.03, 0.30);
    final maxTurnPerSec = 35.0 + speedN * 75.0;
    final maxTurnThisTick = maxTurnPerSec * dtSec;

    final dLat = _tgtLat - _curLat;
    final dLng = _tgtLng - _curLng;
    final rawDiff = _angleDiff(_curHdg, _filteredTgtHdg);
    final turnN = (rawDiff.abs() / 45.0).clamp(0.0, 1.0);
    // Cap turn rate to avoid map snaps in tight turns.
    final boostedMaxTurn = maxTurnThisTick * (1.0 + turnN * 2.2);
    final diff = rawDiff.clamp(-boostedMaxTurn, boostedMaxTurn);

    // Deadband: skip moveAndRotate (= zero GPU work) when already at target.
    // 1e-7° ≈ 1 cm; 0.05° heading is imperceptible. This eliminates constant
    // 60fps repaints while the user is stationary.
    if (dLat.abs() < 1e-7 && dLng.abs() < 1e-7 && diff.abs() < 0.05) return;

    final turnPosAlpha = (posAlpha * (1.0 + turnN * 0.35)).clamp(0.04, 0.55);
    final turnHdgAlpha = (hdgAlpha * (1.0 + turnN * 2.0)).clamp(0.03, 0.70);
    _curLat += dLat * turnPosAlpha;
    _curLng += dLng * turnPosAlpha;
    _curHdg = _wrap360(_curHdg + diff * turnHdgAlpha);
    // Arrow shows the offset between where the camera faces and where the
    // route actually goes. This way the arrow always points along the road
    // even while the camera is smoothly catching up to turns.
    final desiredArrowRel = _angleDiff(_curHdg, _filteredTgtHdg);
    final arrowDiff = _angleDiff(_curArrowRelHdg, desiredArrowRel);
    final arrowAlpha = (dtSec * 8.0).clamp(0.10, 0.55);
    _curArrowRelHdg = _wrap360(_curArrowRelHdg + arrowDiff * arrowAlpha);
    _arrowHdg.value = _curArrowRelHdg;
    final zoomAlpha = (dtSec * 2.8).clamp(0.04, 0.25);
    _curZoom += (_tgtZoom - _curZoom) * zoomAlpha;
    final zoom = _curZoom;

    // Paint every tick (60fps) while actively moving — the 33ms throttle we
    // had before produced visible 30fps stutter especially in 3D where the
    // perspective magnifies translation. Tile rendering is GPU-cheap; the
    // expensive part is tile fetch, which is independent of paint cadence.
    // Only throttle when nearly stationary to save battery.
    final moveDelta2 = dLat * dLat + dLng * dLng;
    final lastCam = _lastCameraTickAt;
    final isMoving =
        _gpsSpeedMps > 1.0 || moveDelta2 > 1e-12 || diff.abs() > 0.05;
    final shouldPaintCamera =
        isMoving ||
        lastCam == null ||
        (tickNow - lastCam).inMilliseconds >= 100;
    if (!shouldPaintCamera) return;
    _lastCameraTickAt = tickNow;

    _moveCameraForNav(
      lat: _curLat,
      lng: _curLng,
      headingDeg: _curHdg,
      zoom: zoom,
    );
  }

  LatLng _cameraCenterForNav({
    required double lat,
    required double lng,
    required double headingDeg,
    required double zoom,
  }) {
    if (!widget.use3D) return LatLng(lat, lng);

    // Keep the car in the lower part of the screen in 3D by moving camera
    // center ahead along heading. Scale by zoom to keep visual lead stable.
    final offsetDeg = _k3DLeadBaseDeg * math.pow(2.0, 17.2 - zoom).toDouble();
    final rad = headingDeg * math.pi / 180.0;
    final cLat = lat + offsetDeg * math.cos(rad);
    final cLng = lng + offsetDeg * math.sin(rad);
    return LatLng(cLat, cLng);
  }

  void _moveCameraForNav({
    required double lat,
    required double lng,
    required double headingDeg,
    required double zoom,
  }) {
    final center = _cameraCenterForNav(
      lat: lat,
      lng: lng,
      headingDeg: headingDeg,
      zoom: zoom,
    );
    try {
      _mapController.moveAndRotate(center, zoom, -headingDeg);
    } catch (e) {
      debugPrint('MapWidget moveAndRotate skipped: $e');
    }
  }

  @override
  void dispose() {
    widget.locationNotifier.removeListener(_onLocationUpdate);
    widget.headingNotifier.removeListener(_onHeadingUpdate);
    _tileHttpClient.close();
    _arrowHdg.dispose();
    _ticker.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(MapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // A GPS fix can arrive in the same frame that the parent enables follow
    // mode. Synchronize from the notifier here as well so the marker never
    // depends on a later theme/style rebuild to become visible.
    final latestLocation = widget.locationNotifier.value;
    if (latestLocation != null) {
      _markerLocation = latestLocation;
    }

    // Waze-style: zoom in and orient map to heading when navigation starts.
    if (widget.followUser && !oldWidget.followUser) {
      final loc = latestLocation;
      final hdg = widget.headingNotifier.value;
      if (loc != null) {
        _curLat = _tgtLat = loc.latitude;
        _curLng = _tgtLng = loc.longitude;
        _curHdg = _tgtHdg = _filteredTgtHdg = hdg;
        _curArrowRelHdg = 0;
        _arrowHdg.value = 0;
        _navInitialized = true;
        final zoom = _computeNavZoom();
        _curZoom = _tgtZoom = zoom;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _moveCameraForNav(
            lat: _curLat,
            lng: _curLng,
            headingDeg: hdg,
            zoom: zoom,
          );
        });
      }
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
        (widget.use3D != oldWidget.use3D ||
            widget.nextManeuverDistanceMeters !=
                oldWidget.nextManeuverDistanceMeters ||
            widget.nextManeuverSign != oldWidget.nextManeuverSign) &&
        _navInitialized) {
      _tgtZoom = _computeNavZoom();
      _moveCameraForNav(
        lat: _curLat,
        lng: _curLng,
        headingDeg: _curHdg,
        zoom: _tgtZoom,
      );
    }

    // Reset when navigation ends.
    if (!widget.followUser && oldWidget.followUser) {
      _navInitialized = false;
      _lastLocForBearing = null;
      _lastGpsAt = null;
      _gpsSpeedMps = 0;
      _curZoom = 16.0;
      _tgtZoom = 16.0;
      _lastRouteIdx = 0;
      _lastTickAt = null;
      _lastCameraTickAt = null;
    }

    if (widget.routePoints != oldWidget.routePoints) {
      _lastRouteIdx = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    // CRITICAL: the widget tree RUNTIMETYPES must never change.
    // Changing Positioned height or Transform matrix is fine — Flutter just
    // relayouts/repaints. Only a type change would destroy FlutterMap.
    final is3D = widget.followUser && widget.use3D;

    // Waze-style perspective tilt — reduced from 37° to 28° to cut down
    // the amount of horizon visible, which reduces far-tile loading.
    final matrix = is3D
        ? (Matrix4.identity()
            ..setEntry(3, 2, 0.0008) // perspective depth
            ..rotateX(_k3DTiltRad))
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
              initialCenter:
                  widget.locationNotifier.value ?? MapWidget._defaultCenter,
              initialZoom: widget.followUser ? _computeNavZoom() : 12.0,
              onTap: (_, point) => widget.onTap?.call(point),
              onPositionChanged: (camera, hasGesture) {
                if (hasGesture && widget.followUser) {
                  widget.onUserPanned?.call();
                }
              },
            ),
            children: [
              TileLayer(
                // Use POI-richer Voyager in light mode so shops, restaurants
                // and gas stations show up more often on the base map.
                urlTemplate: widget.darkMode
                    ? 'https://{s}.basemaps.cartocdn.com/dark_nolabels/{z}/{x}/{y}{r}.png'
                    : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                fallbackUrl: widget.darkMode
                    ? 'https://{s}.basemaps.cartocdn.com/dark_nolabels/{z}/{x}/{y}{r}.png'
                    : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.cruizx.mobile',
                tileProvider: _tileProvider,
                tileUpdateTransformer: TileUpdateTransformers.throttle(
                  const Duration(milliseconds: 28),
                ),
                retinaMode: RetinaMode.isHighDensity(context),
                maxNativeZoom: 20,
                // Large buffers + instant tile appearance to eliminate
                // white flashes when rotating/panning during navigation.
                keepBuffer: 3,
                panBuffer: 1,
                tileDisplay: const TileDisplay.instantaneous(),
              ),
              // Hillshade overlay — free ESRI terrain shading, subtle 3D depth.
              // Note: ESRI uses {z}/{y}/{x} order (reversed vs OSM).
              if (!widget.darkMode)
                Opacity(
                  opacity: 0.14,
                  child: TileLayer(
                    urlTemplate:
                        'https://server.arcgisonline.com/ArcGIS/rest/services/Elevation/World_Hillshade/MapServer/tile/{z}/{y}/{x}',
                    userAgentPackageName: 'com.cruizx.mobile',
                    keepBuffer: 2,
                    panBuffer: 1,
                    tileDisplay: const TileDisplay.instantaneous(),
                  ),
                ),
              // Always show dark labels in dark mode (self-hosted has no dark raster style).
              if (widget.darkMode)
                TileLayer(
                  urlTemplate:
                      'https://{s}.basemaps.cartocdn.com/dark_only_labels/{z}/{x}/{y}{r}.png',
                  fallbackUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.cruizx.mobile',
                  tileProvider: _tileProvider,
                  tileUpdateTransformer: TileUpdateTransformers.throttle(
                    const Duration(milliseconds: 28),
                  ),
                  retinaMode: RetinaMode.isHighDensity(context),
                  maxNativeZoom: 20,
                  keepBuffer: 2,
                  panBuffer: 1,
                  tileDisplay: const TileDisplay.instantaneous(),
                ),
              if (!widget.darkMode)
                TileLayer(
                  urlTemplate:
                      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager_only_labels/{z}/{x}/{y}{r}.png',
                  fallbackUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.cruizx.mobile',
                  tileProvider: _tileProvider,
                  tileUpdateTransformer: TileUpdateTransformers.throttle(
                    const Duration(milliseconds: 28),
                  ),
                  retinaMode: RetinaMode.isHighDensity(context),
                  maxNativeZoom: 20,
                  keepBuffer: 2,
                  panBuffer: 1,
                  tileDisplay: const TileDisplay.instantaneous(),
                ),
              if (widget.studdedTireBanZones.isNotEmpty)
                PolygonLayer(
                  polygons: [
                    for (final zone in widget.studdedTireBanZones)
                      Polygon(
                        points: zone,
                        color: const Color(0x33FF3B30),
                        borderColor: const Color(0xCCFF3B30),
                        borderStrokeWidth: 2,
                      ),
                  ],
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
                  // EV charging station markers.
                  for (final pos in widget.chargingStations)
                    Marker(
                      point: pos,
                      width: 32,
                      height: 32,
                      child: const _ChargingMarker(),
                    ),
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
                  if (_markerLocation != null && !widget.followUser)
                    Marker(
                      point: _markerLocation!,
                      width: 40,
                      height: 40,
                      child: _LocationDot(
                        headingNotifier: _arrowHdg,
                        lockNorthUp: false,
                        size: 34,
                      ),
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
              if (widget.darkMode)
                IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0x333A4D7A),
                          const Color(0x1A70423B),
                        ],
                      ),
                    ),
                  ),
                ),
              // Keep the navigation arrow fixed on screen in follow mode.
              // This removes micro-jitter from GPS sample cadence while the
              // map animates smoothly beneath the marker.
              if (widget.followUser)
                IgnorePointer(
                  child: Align(
                    alignment: is3D
                        ? const Alignment(0, _k3DArrowAlignmentY)
                        : Alignment.center,
                    child: _LocationDot(
                      headingNotifier: _arrowHdg,
                      lockNorthUp: false,
                      size: 34,
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

// ─── EV charging marker ──────────────────────────────────────────────────────

class _ChargingMarker extends StatelessWidget {
  const _ChargingMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF34C759),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black26)],
      ),
      child: const Icon(Icons.ev_station, color: Colors.white, size: 18),
    );
  }
}

// ─── Alert marker ────────────────────────────────────────────────────────────

class _AlertMarker extends StatelessWidget {
  const _AlertMarker({required this.alert});
  final AlertModel alert;

  Color _bgColor(AlertType t) => switch (t) {
    AlertType.roadClosure => const Color(0xFFB71C1C),
    AlertType.police => const Color(0xFF1565C0),
    AlertType.roadwork => const Color(0xFFE65100),
    AlertType.accident => const Color(0xFFC62828),
    AlertType.trafficJam => const Color(0xFFF57F17),
    AlertType.speedCamera => const Color(0xFF6A1B9A),
    AlertType.narrowRoad => const Color(0xFF00695C),
    AlertType.steepHill => const Color(0xFF37474F),
    AlertType.speedBump => const Color(0xFFFF7A00),
    AlertType.meetup => const Color(0xFF1E88E5),
    AlertType.parking => const Color(0xFF0277BD),
    AlertType.foodStop => const Color(0xFFEF6C00),
    AlertType.charging => const Color(0xFF00A86B),
    AlertType.hangout => const Color(0xFFFFB300),
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
  const _LocationDot({
    required this.headingNotifier,
    required this.lockNorthUp,
    this.size = 34,
  });

  final ValueNotifier<double> headingNotifier;
  final bool lockNorthUp;
  final double size;

  @override
  Widget build(BuildContext context) {
    return UserLocationMarker(
      headingNotifier: headingNotifier,
      lockNorthUp: lockNorthUp,
      size: size,
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
