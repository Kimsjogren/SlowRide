import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;
import 'package:latlong2/latlong.dart';
import 'package:slowride/models/alert_model.dart';

/// Vector map widget backed by MapLibre GL — renders crisp tiles at every
/// zoom level. Uses the same interface as [MapWidget] so [MapScreen] can swap
/// between raster and vector with a single flag.
class VectorMapWidget extends StatefulWidget {
  const VectorMapWidget({
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

  final ValueNotifier<LatLng?> locationNotifier;
  final ValueNotifier<double> headingNotifier;
  final LatLng? destination;
  final List<LatLng> routePoints;
  final List<AlertModel> alerts;
  final List<List<LatLng>> studdedTireBanZones;
  final List<LatLng> chargingStations;
  final ValueChanged<LatLng>? onTap;
  final bool followUser;
  final VoidCallback? onUserPanned;
  final bool use3D;
  final bool darkMode;
  final double? nextManeuverDistanceMeters;
  final int? nextManeuverSign;

  static const LatLng _defaultCenter = LatLng(59.3293, 18.0686);

  @override
  State<VectorMapWidget> createState() => _VectorMapWidgetState();
}

class _VectorMapWidgetState extends State<VectorMapWidget> {
  ml.MapLibreMapController? _controller;
  bool _mapReady = false;
  bool _userPanning = false;
  bool _disposed = false;
  Timer? _panCooldownTimer;
  Timer? _layerUpdateDebouncer;
  List<LatLng> _lastRoutePoints = [];
  List<AlertModel> _lastAlerts = [];
  List<LatLng> _lastChargingStations = [];
  List<List<LatLng>> _lastStuddedTireBanZones = [];
  LatLng? _lastDestination;
  LatLng? _lastCameraTarget;
  DateTime _lastCameraUpdateAt = DateTime.fromMillisecondsSinceEpoch(0);
  double _lastCameraBearing = 0.0;
  double _lastCameraZoom = 0.0;
  double _lastAnimatedHeading = 0.0;

  String get _styleUrl {
    if (widget.darkMode) {
      // Using a more stable dark style. The standard dark-matter-gl-style
      // can have label flickering issues due to text collision detection.
      // We'll try the OSM Liberty dark variant or stick with dark-matter
      // but optimize layer management to reduce flicker.
      return 'https://basemaps.cartocdn.com/gl/dark-matter-gl-style/style.json';
    }
    // Light mode: use Voyager GL to surface more everyday POIs like
    // restaurants, shops and gas stations directly on the map.
    return 'https://basemaps.cartocdn.com/gl/voyager-gl-style/style.json';
  }

  @override
  void initState() {
    super.initState();
    widget.locationNotifier.addListener(_onLocationUpdate);
    widget.headingNotifier.addListener(_onHeadingUpdate);
  }

  @override
  void dispose() {
    _disposed = true;
    _panCooldownTimer?.cancel();
    _layerUpdateDebouncer?.cancel();
    widget.locationNotifier.removeListener(_onLocationUpdate);
    widget.headingNotifier.removeListener(_onHeadingUpdate);
    super.dispose();
  }

  void _onLocationUpdate() {
    if (!_mapReady || _userPanning || _disposed) return;
    final loc = widget.locationNotifier.value;
    if (loc != null && widget.followUser) {
      _updateFollowCamera(loc);
    }
  }

  void _onHeadingUpdate() {
    if (!_mapReady || _userPanning || !widget.followUser || !widget.use3D) {
      return;
    }
    final loc = widget.locationNotifier.value;
    if (loc == null) return;

    // In 3D we still allow heading updates, but with a larger deadband and
    // without re-triggering a full animated camera step every small change.
    final currentHeading = widget.headingNotifier.value;
    final headingDiff = (currentHeading - _lastAnimatedHeading).abs();
    final normalizedDiff = headingDiff > 180 ? 360 - headingDiff : headingDiff;

    if (normalizedDiff >= 12.0) {
      _updateFollowCamera(loc, headingOnly: true);
    }
  }

  double _distanceMeters(LatLng a, LatLng b) {
    const lat2m = 111320.0;
    final lng2m = 111320.0 * math.cos(a.latitude * math.pi / 180.0);
    final dx = (b.latitude - a.latitude) * lat2m;
    final dy = (b.longitude - a.longitude) * lng2m;
    return math.sqrt(dx * dx + dy * dy);
  }

  double _normalizedHeadingDiff(double a, double b) {
    final diff = (a - b).abs();
    return diff > 180 ? 360 - diff : diff;
  }

  void _updateFollowCamera(LatLng loc, {bool headingOnly = false}) {
    if (_disposed || _userPanning) return;
    final c = _controller;
    if (c == null) return;
    final heading = widget.use3D ? widget.headingNotifier.value : 0.0;
    final tilt = (widget.followUser && widget.use3D) ? 45.0 : 0.0;
    final zoom = _computeZoom();
    final now = DateTime.now();

    if (_lastCameraTarget != null) {
      final movedMeters = _distanceMeters(_lastCameraTarget!, loc);
      final headingDelta = _normalizedHeadingDiff(heading, _lastCameraBearing);
      final zoomDelta = (zoom - _lastCameraZoom).abs();
      final minIntervalMs = headingOnly ? 220 : 120;
      final updatedRecently =
          now.difference(_lastCameraUpdateAt).inMilliseconds < minIntervalMs;
      final positionStable = movedMeters < 1.5;
      final headingStable = headingDelta < (widget.use3D ? 12.0 : 1.0);
      final zoomStable = zoomDelta < 0.05;

      if (updatedRecently ||
          (positionStable && headingStable && zoomStable) ||
          (headingOnly && positionStable && zoomStable)) {
        return;
      }
    }

    _lastAnimatedHeading = heading;
    _lastCameraTarget = loc;
    _lastCameraBearing = heading;
    _lastCameraZoom = zoom;
    _lastCameraUpdateAt = now;

    final update = ml.CameraUpdate.newCameraPosition(
      ml.CameraPosition(
        target: ml.LatLng(loc.latitude, loc.longitude),
        bearing: heading,
        tilt: tilt,
        zoom: zoom,
      ),
    );

    // Use a hard move during follow updates to avoid the label fade/flicker
    // that MapLibre triggers when a new camera animation starts repeatedly.
    c.moveCamera(update);
  }

  double _computeZoom() {
    final base = widget.use3D ? 17.5 : 16.0;
    final d = widget.nextManeuverDistanceMeters;
    if (d == null || d <= 0) return base;
    final near = ((320.0 - d) / 320.0).clamp(0.0, 1.0);
    final boost = math.pow(near, 1.28).toDouble() * 1.05;
    final max = widget.use3D ? 18.8 : 17.2;
    return (base + boost).clamp(base, max);
  }

  Future<void> _onMapCreated(ml.MapLibreMapController controller) async {
    _controller = controller;
  }

  Future<void> _onStyleLoaded() async {
    if (_disposed) return;
    _mapReady = true;
    _lastRoutePoints = [];
    _lastAlerts = [];
    _lastChargingStations = [];
    _lastStuddedTireBanZones = [];
    _lastDestination = null;
    await _refreshLayers();
    final loc = widget.locationNotifier.value;
    if (loc != null && widget.followUser) {
      _updateFollowCamera(loc);
    } else if (loc != null) {
      _controller?.moveCamera(
        ml.CameraUpdate.newCameraPosition(
          ml.CameraPosition(
            target: ml.LatLng(loc.latitude, loc.longitude),
            zoom: 14.0,
          ),
        ),
      );
    }
  }

  Future<void> _refreshLayers() async {
    final c = _controller;
    if (c == null) return;

    // Skip update if data hasn't actually changed
    final routeChanged = widget.routePoints != _lastRoutePoints;
    final destChanged = widget.destination != _lastDestination;
    final alertsChanged = widget.alerts != _lastAlerts;
    final chargingChanged = widget.chargingStations != _lastChargingStations;
    final studdedZonesChanged =
        widget.studdedTireBanZones != _lastStuddedTireBanZones;
    if (!routeChanged &&
        !destChanged &&
        !alertsChanged &&
        !chargingChanged &&
        !studdedZonesChanged) {
      return;
    }

    _lastRoutePoints = List.from(widget.routePoints);
    _lastAlerts = List.from(widget.alerts);
    _lastChargingStations = List.from(widget.chargingStations);
    _lastStuddedTireBanZones = widget.studdedTireBanZones
        .map((polygon) => List<LatLng>.from(polygon))
        .toList();
    _lastDestination = widget.destination;

    // ── Route ─────────────────────────────────────────────────────────────
    // Instead of removing and re-adding layers/sources, update them in place
    // to avoid triggering label re-rendering which causes flickering.
    final hasRoute = widget.routePoints.length >= 2;

    if (hasRoute) {
      final coords = widget.routePoints
          .map((p) => [p.longitude, p.latitude])
          .toList();
      final geojson = {
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'geometry': {'type': 'LineString', 'coordinates': coords},
          },
        ],
      };

      // Try to update source if it exists, otherwise create it
      try {
        await c.setGeoJsonSource('route-src', geojson);
      } catch (_) {
        // Source doesn't exist yet, create it with layers
        await c.addSource(
          'route-src',
          ml.GeojsonSourceProperties(data: geojson),
        );
        await c.addLineLayer(
          'route-src',
          'route-casing',
          const ml.LineLayerProperties(
            lineColor: '#1448a8',
            lineWidth: 11.0,
            lineCap: 'round',
            lineJoin: 'round',
          ),
        );
        await c.addLineLayer(
          'route-src',
          'route-line',
          const ml.LineLayerProperties(
            lineColor: '#4888ff',
            lineWidth: 7.0,
            lineCap: 'round',
            lineJoin: 'round',
          ),
        );
      }
    } else {
      // No route, remove layers if they exist
      for (final id in ['route-line', 'route-casing']) {
        try {
          await c.removeLayer(id);
        } catch (_) {}
      }
      try {
        await c.removeSource('route-src');
      } catch (_) {}
    }

    // ── Destination ────────────────────────────────────────────────────────
    final hasDest = widget.destination != null;

    if (hasDest) {
      final d = widget.destination!;
      final geojson = {
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [d.longitude, d.latitude],
            },
          },
        ],
      };

      // Try to update source if it exists, otherwise create it
      try {
        await c.setGeoJsonSource('dest-src', geojson);
      } catch (_) {
        // Source doesn't exist yet, create it with layer
        await c.addSource(
          'dest-src',
          ml.GeojsonSourceProperties(data: geojson),
        );
        await c.addCircleLayer(
          'dest-src',
          'dest-layer',
          const ml.CircleLayerProperties(
            circleColor: '#ff4444',
            circleRadius: 10.0,
            circleStrokeColor: '#ffffff',
            circleStrokeWidth: 3.0,
          ),
        );
      }
    } else {
      // No destination, remove layer if it exists
      try {
        await c.removeLayer('dest-layer');
      } catch (_) {}
      try {
        await c.removeSource('dest-src');
      } catch (_) {}
    }

    // ── Studded tire ban zones ────────────────────────────────────────────
    if (widget.studdedTireBanZones.isNotEmpty) {
      final features = widget.studdedTireBanZones
          .where((polygon) => polygon.length >= 3)
          .map((polygon) {
            final ring = polygon
                .map((point) => [point.longitude, point.latitude])
                .toList();
            if (ring.isNotEmpty) {
              final first = ring.first;
              final last = ring.last;
              if (first[0] != last[0] || first[1] != last[1]) {
                ring.add([first[0], first[1]]);
              }
            }
            return {
              'type': 'Feature',
              'geometry': {
                'type': 'Polygon',
                'coordinates': [ring],
              },
            };
          })
          .toList();
      final geojson = {'type': 'FeatureCollection', 'features': features};

      try {
        await c.setGeoJsonSource('studded-zones-src', geojson);
      } catch (_) {
        await c.addSource(
          'studded-zones-src',
          ml.GeojsonSourceProperties(data: geojson),
        );
        await c.addFillLayer(
          'studded-zones-src',
          'studded-zones-fill',
          const ml.FillLayerProperties(
            fillColor: '#ff7a1a',
            fillOpacity: 0.16,
            fillOutlineColor: '#ff9b4a',
          ),
        );
        await c.addLineLayer(
          'studded-zones-src',
          'studded-zones-outline',
          const ml.LineLayerProperties(
            lineColor: '#ff9b4a',
            lineWidth: 2.0,
            lineOpacity: 0.8,
            lineCap: 'round',
            lineJoin: 'round',
          ),
        );
      }
    } else {
      for (final id in ['studded-zones-outline', 'studded-zones-fill']) {
        try {
          await c.removeLayer(id);
        } catch (_) {}
      }
      try {
        await c.removeSource('studded-zones-src');
      } catch (_) {}
    }

    // ── Charging stations ────────────────────────────────────────────────
    if (widget.chargingStations.isNotEmpty) {
      final geojson = {
        'type': 'FeatureCollection',
        'features': widget.chargingStations
            .map(
              (station) => {
                'type': 'Feature',
                'geometry': {
                  'type': 'Point',
                  'coordinates': [station.longitude, station.latitude],
                },
              },
            )
            .toList(),
      };

      try {
        await c.setGeoJsonSource('charging-src', geojson);
      } catch (_) {
        await c.addSource(
          'charging-src',
          ml.GeojsonSourceProperties(data: geojson),
        );
        await c.addCircleLayer(
          'charging-src',
          'charging-halo',
          const ml.CircleLayerProperties(
            circleColor: '#40cfd8',
            circleRadius: 10.0,
            circleOpacity: 0.18,
          ),
        );
        await c.addCircleLayer(
          'charging-src',
          'charging-layer',
          const ml.CircleLayerProperties(
            circleColor: '#11b5c9',
            circleRadius: 5.5,
            circleStrokeColor: '#ffffff',
            circleStrokeWidth: 1.8,
          ),
        );
      }
    } else {
      for (final id in ['charging-layer', 'charging-halo']) {
        try {
          await c.removeLayer(id);
        } catch (_) {}
      }
      try {
        await c.removeSource('charging-src');
      } catch (_) {}
    }

    // ── Alerts ───────────────────────────────────────────────────────────
    if (widget.alerts.isNotEmpty) {
      final geojson = {
        'type': 'FeatureCollection',
        'features': widget.alerts
            .map(
              (alert) => {
                'type': 'Feature',
                'properties': {'color': _alertColor(alert.type)},
                'geometry': {
                  'type': 'Point',
                  'coordinates': [
                    alert.position.longitude,
                    alert.position.latitude,
                  ],
                },
              },
            )
            .toList(),
      };

      try {
        await c.setGeoJsonSource('alerts-src', geojson);
      } catch (_) {
        await c.addSource(
          'alerts-src',
          ml.GeojsonSourceProperties(data: geojson),
        );
        await c.addCircleLayer(
          'alerts-src',
          'alerts-halo',
          ml.CircleLayerProperties(
            circleColor: ['get', 'color'],
            circleRadius: 11.0,
            circleOpacity: 0.16,
          ),
        );
        await c.addCircleLayer(
          'alerts-src',
          'alerts-layer',
          ml.CircleLayerProperties(
            circleColor: ['get', 'color'],
            circleRadius: 5.8,
            circleStrokeColor: '#ffffff',
            circleStrokeWidth: 2.0,
          ),
        );
      }
    } else {
      for (final id in ['alerts-layer', 'alerts-halo']) {
        try {
          await c.removeLayer(id);
        } catch (_) {}
      }
      try {
        await c.removeSource('alerts-src');
      } catch (_) {}
    }
  }

  String _alertColor(AlertType type) {
    return switch (type) {
      AlertType.police => '#2d7ff9',
      AlertType.speedCamera => '#ff5a5f',
      AlertType.roadwork ||
      AlertType.hazard ||
      AlertType.narrowRoad => '#ff9f0a',
      AlertType.accident || AlertType.trafficJam => '#ff375f',
      AlertType.steepHill => '#9b6cff',
      AlertType.meetup || AlertType.hangout => '#7a5cff',
      AlertType.parking => '#3cb371',
      AlertType.foodStop => '#ffb347',
      AlertType.charging => '#11b5c9',
    };
  }

  @override
  void didUpdateWidget(VectorMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_mapReady) return;

    final routeChanged = widget.routePoints != oldWidget.routePoints;
    final destChanged = widget.destination != oldWidget.destination;
    final alertsChanged = widget.alerts != oldWidget.alerts;
    final chargingChanged =
        widget.chargingStations != oldWidget.chargingStations;
    final studdedZonesChanged =
        widget.studdedTireBanZones != oldWidget.studdedTireBanZones;
    if (routeChanged ||
        destChanged ||
        alertsChanged ||
        chargingChanged ||
        studdedZonesChanged) {
      // Debounce layer updates to avoid flickering labels
      _layerUpdateDebouncer?.cancel();
      _layerUpdateDebouncer = Timer(const Duration(milliseconds: 100), () {
        if (mounted) _refreshLayers();
      });
    }

    if (widget.followUser && !oldWidget.followUser) {
      _userPanning = false;
      final loc = widget.locationNotifier.value;
      if (loc != null) {
        _lastCameraTarget = null;
        _updateFollowCamera(loc);
      }
    }

    if (widget.followUser &&
        (widget.use3D != oldWidget.use3D ||
            widget.darkMode != oldWidget.darkMode)) {
      final loc = widget.locationNotifier.value;
      if (loc != null) {
        _lastCameraTarget = null;
        _updateFollowCamera(loc);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial =
        widget.locationNotifier.value ?? VectorMapWidget._defaultCenter;
    return ClipRRect(
      borderRadius: widget.followUser
          ? BorderRadius.zero
          : BorderRadius.circular(12),
      child: Listener(
        onPointerDown: (_) {
          // User touched the map - disable follow mode if active
          if (widget.followUser && !_userPanning) {
            _userPanning = true;
            widget.onUserPanned?.call();
            // Reset after a short delay
            _panCooldownTimer?.cancel();
            _panCooldownTimer = Timer(const Duration(milliseconds: 1000), () {
              if (mounted) {
                _userPanning = false;
              }
            });
          }
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: ml.MapLibreMap(
                styleString: _styleUrl,
                initialCameraPosition: ml.CameraPosition(
                  target: ml.LatLng(initial.latitude, initial.longitude),
                  zoom: 12.0,
                ),
                onMapCreated: _onMapCreated,
                onStyleLoadedCallback: _onStyleLoaded,
                onMapClick: (_, coord) {
                  widget.onTap?.call(LatLng(coord.latitude, coord.longitude));
                },
                myLocationEnabled: true,
                myLocationRenderMode: ml.MyLocationRenderMode.compass,
                myLocationTrackingMode: ml.MyLocationTrackingMode.none,
                compassEnabled: false,
                rotateGesturesEnabled: true,
                tiltGesturesEnabled: true,
                attributionButtonPosition:
                    ml.AttributionButtonPosition.bottomRight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
