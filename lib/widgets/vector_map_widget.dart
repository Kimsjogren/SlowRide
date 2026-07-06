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
  bool _isAnimatingCamera = false;

  String get _styleUrl {
    // Always use Carto GL for reliable vector rendering.
    return widget.darkMode
        ? 'https://basemaps.cartocdn.com/gl/dark-matter-gl-style/style.json'
        : 'https://basemaps.cartocdn.com/gl/voyager-gl-style/style.json';
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
    widget.locationNotifier.removeListener(_onLocationUpdate);
    widget.headingNotifier.removeListener(_onHeadingUpdate);
    super.dispose();
  }

  void _onLocationUpdate() {
    if (!_mapReady || _userPanning || _disposed) return;
    final loc = widget.locationNotifier.value;
    if (loc != null && widget.followUser) {
      _animateCameraToUser(loc);
    }
  }

  void _onHeadingUpdate() {
    if (!_mapReady || _userPanning || !widget.followUser) return;
    final loc = widget.locationNotifier.value;
    if (loc != null) _animateCameraToUser(loc);
  }

  void _animateCameraToUser(LatLng loc) {
    if (_disposed) return;
    final c = _controller;
    if (c == null) return;
    final heading = widget.headingNotifier.value;
    final tilt = (widget.followUser && widget.use3D) ? 45.0 : 0.0;
    _isAnimatingCamera = true;
    c.animateCamera(
      ml.CameraUpdate.newCameraPosition(
        ml.CameraPosition(
          target: ml.LatLng(loc.latitude, loc.longitude),
          bearing: heading,
          tilt: tilt,
          zoom: _computeZoom(),
        ),
      ),
      duration: const Duration(milliseconds: 300),
    );
    // Clear programmatic flag after animation duration
    Future.delayed(const Duration(milliseconds: 400), () {
      _isAnimatingCamera = false;
    });
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
    await _refreshLayers();
    final loc = widget.locationNotifier.value;
    if (loc != null && widget.followUser) {
      _animateCameraToUser(loc);
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

    // ── Route ─────────────────────────────────────────────────────────────
    for (final id in ['route-line', 'route-casing']) {
      try {
        await c.removeLayer(id);
      } catch (_) {}
    }
    try {
      await c.removeSource('route-src');
    } catch (_) {}

    if (widget.routePoints.length >= 2) {
      final coords = widget.routePoints
          .map((p) => [p.longitude, p.latitude])
          .toList();
      await c.addSource(
        'route-src',
        ml.GeojsonSourceProperties(
          data: {
            'type': 'FeatureCollection',
            'features': [
              {
                'type': 'Feature',
                'geometry': {'type': 'LineString', 'coordinates': coords},
              },
            ],
          },
        ),
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

    // ── Destination ────────────────────────────────────────────────────────
    try {
      await c.removeLayer('dest-layer');
    } catch (_) {}
    try {
      await c.removeSource('dest-src');
    } catch (_) {}

    if (widget.destination != null) {
      final d = widget.destination!;
      await c.addSource(
        'dest-src',
        ml.GeojsonSourceProperties(
          data: {
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
          },
        ),
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
  }

  @override
  void didUpdateWidget(VectorMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_mapReady) return;

    final routeChanged = widget.routePoints != oldWidget.routePoints;
    final destChanged = widget.destination != oldWidget.destination;
    if (routeChanged || destChanged) _refreshLayers();

    if (widget.followUser && !oldWidget.followUser) {
      _userPanning = false;
      final loc = widget.locationNotifier.value;
      if (loc != null) _animateCameraToUser(loc);
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
        onCameraMove: (_) {
          // If camera moves without a programmatic animation, it's a user pan.
          if (!_isAnimatingCamera && _mapReady) {
            _userPanning = true;
          }
        },
        onCameraIdle: () {
          if (_userPanning) {
            _userPanning = false;
            widget.onUserPanned?.call();
          }
        },
        myLocationEnabled: true,
        myLocationRenderMode: ml.MyLocationRenderMode.compass,
        myLocationTrackingMode: ml.MyLocationTrackingMode.none,
        compassEnabled: false,
        rotateGesturesEnabled: true,
        tiltGesturesEnabled: true,
        attributionButtonPosition: ml.AttributionButtonPosition.bottomRight,
      ),
    );
  }
}
