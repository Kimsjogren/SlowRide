import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slowride/core/constants/backend_config.dart';

enum TrafficCongestionLevel { moderate, heavy, severe }

class TrafficRouteSection {
  const TrafficRouteSection({required this.level, required this.points});

  final TrafficCongestionLevel level;
  final List<LatLng> points;

  Map<String, Object> toMap() => <String, Object>{
    'level': level.name,
    'points': points
        .map(
          (point) => <String, double>{
            'latitude': point.latitude,
            'longitude': point.longitude,
          },
        )
        .toList(growable: false),
  };
}

class TrafficEtaEstimate {
  const TrafficEtaEstimate({
    required this.liveDurationSeconds,
    required this.typicalDurationSeconds,
    required this.routeDistanceMeters,
    required this.fetchedAt,
    this.trafficSections = const [],
  });

  final double liveDurationSeconds;
  final double typicalDurationSeconds;
  final double routeDistanceMeters;
  final DateTime fetchedAt;
  final List<TrafficRouteSection> trafficSections;

  double get delaySeconds =>
      (liveDurationSeconds - typicalDurationSeconds).clamp(0, double.infinity);
}

/// Adds live traffic delay to CruizX's existing vehicle-specific route.
///
/// Mapbox is deliberately not allowed to replace the route geometry. Up to 25
/// points sampled from the active CruizX route force the traffic lookup to
/// follow the same corridor, including routes created for slow vehicles.
class MapboxTrafficService {
  MapboxTrafficService({http.Client? client})
    : _client = client ?? http.Client();

  static const Duration refreshInterval = Duration(minutes: 5);
  static const int _maximumCoordinates = 25;
  static const String _usageMonthKey = 'mapbox_traffic_usage_month';
  static const String _usageCountKey = 'mapbox_traffic_usage_count';
  static const int _maximumCachedRoutes = 12;

  final http.Client _client;
  final Map<String, TrafficEtaEstimate> _cache = {};
  final Map<String, Future<TrafficEtaEstimate?>> _inFlight = {};

  Future<TrafficEtaEstimate?> estimate({
    required String routeId,
    required List<LatLng> remainingRoutePoints,
    bool force = false,
  }) {
    if (!BackendConfig.mapboxTrafficEnabled ||
        BackendConfig.mapboxAccessToken.trim().isEmpty ||
        remainingRoutePoints.length < 2) {
      return Future.value(null);
    }

    final now = DateTime.now();
    final cached = _cache[routeId];
    if (!force &&
        cached != null &&
        now.difference(cached.fetchedAt) < refreshInterval) {
      return Future.value(cached);
    }

    final existing = _inFlight[routeId];
    if (existing != null) return existing;

    final request = _fetch(
      routeId: routeId,
      remainingRoutePoints: remainingRoutePoints,
      requestedAt: now,
    );
    _inFlight[routeId] = request;
    return request.whenComplete(() => _inFlight.remove(routeId));
  }

  Future<TrafficEtaEstimate?> _fetch({
    required String routeId,
    required List<LatLng> remainingRoutePoints,
    required DateTime requestedAt,
  }) async {
    if (!await _reserveMonthlyRequest()) return _cache[routeId];
    final sampled = sampleRoutePoints(remainingRoutePoints);
    final coordinates = sampled
        .map(
          (point) =>
              '${point.longitude.toStringAsFixed(6)},${point.latitude.toStringAsFixed(6)}',
        )
        .join(';');
    final uri =
        Uri.parse(
          'https://api.mapbox.com/directions/v5/mapbox/driving-traffic/$coordinates',
        ).replace(
          queryParameters: <String, String>{
            'alternatives': 'false',
            'overview': 'full',
            'geometries': 'geojson',
            'annotations': 'congestion',
            'steps': 'false',
            'access_token': BackendConfig.mapboxAccessToken.trim(),
          },
        );

    try {
      final response = await _client
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return _cache[routeId];

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = decoded['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) return _cache[routeId];
      final route = routes.first as Map<String, dynamic>;
      final liveDuration = (route['duration'] as num?)?.toDouble();
      final typicalDuration = (route['duration_typical'] as num?)?.toDouble();
      final distance = (route['distance'] as num?)?.toDouble();
      if (liveDuration == null ||
          typicalDuration == null ||
          distance == null ||
          liveDuration <= 0 ||
          typicalDuration <= 0 ||
          distance <= 0) {
        return _cache[routeId];
      }

      final estimate = TrafficEtaEstimate(
        liveDurationSeconds: liveDuration,
        typicalDurationSeconds: typicalDuration,
        routeDistanceMeters: distance,
        fetchedAt: requestedAt,
        trafficSections: _trafficSections(route),
      );
      _cache[routeId] = estimate;
      if (_cache.length > _maximumCachedRoutes) {
        final oldest = _cache.entries.reduce(
          (a, b) => a.value.fetchedAt.isBefore(b.value.fetchedAt) ? a : b,
        );
        _cache.remove(oldest.key);
      }
      return estimate;
    } catch (error) {
      debugPrint('Mapbox traffic ETA failed: $error');
      return _cache[routeId];
    }
  }

  static List<TrafficRouteSection> _trafficSections(
    Map<String, dynamic> route,
  ) {
    final geometry = route['geometry'] as Map<String, dynamic>?;
    final rawCoordinates = geometry?['coordinates'] as List<dynamic>?;
    if (rawCoordinates == null || rawCoordinates.length < 2) return const [];
    final points = rawCoordinates
        .whereType<List<dynamic>>()
        .where((pair) => pair.length >= 2)
        .map(
          (pair) => LatLng(
            (pair[1] as num).toDouble(),
            (pair[0] as num).toDouble(),
          ),
        )
        .toList(growable: false);
    if (points.length < 2) return const [];

    final congestion = <String?>[];
    for (final rawLeg in route['legs'] as List<dynamic>? ?? const []) {
      final leg = rawLeg as Map<String, dynamic>?;
      final annotation = leg?['annotation'] as Map<String, dynamic>?;
      for (final value
          in annotation?['congestion'] as List<dynamic>? ?? const []) {
        congestion.add(value?.toString());
      }
    }
    if (congestion.isEmpty) return const [];

    final sections = <TrafficRouteSection>[];
    TrafficCongestionLevel? activeLevel;
    var activePoints = <LatLng>[];
    void flush() {
      if (activeLevel != null && activePoints.length >= 2) {
        sections.add(
          TrafficRouteSection(
            level: activeLevel!,
            points: List.unmodifiable(activePoints),
          ),
        );
      }
      activeLevel = null;
      activePoints = <LatLng>[];
    }

    final segmentCount = (points.length - 1).clamp(0, congestion.length);
    for (var index = 0; index < segmentCount; index++) {
      final level = _levelFor(congestion[index]);
      if (level == null) {
        flush();
        continue;
      }
      if (level != activeLevel) {
        flush();
        activeLevel = level;
        activePoints = <LatLng>[points[index], points[index + 1]];
      } else {
        activePoints.add(points[index + 1]);
      }
    }
    flush();
    return List.unmodifiable(sections);
  }

  static TrafficCongestionLevel? _levelFor(String? congestion) {
    return switch (congestion) {
      'moderate' => TrafficCongestionLevel.moderate,
      'heavy' => TrafficCongestionLevel.heavy,
      'severe' => TrafficCongestionLevel.severe,
      _ => null,
    };
  }

  Future<bool> _reserveMonthlyRequest() async {
    final preferences = await SharedPreferences.getInstance();
    final now = DateTime.now().toUtc();
    final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final storedMonth = preferences.getString(_usageMonthKey);
    var count = preferences.getInt(_usageCountKey) ?? 0;
    if (storedMonth != month) {
      count = 0;
      await preferences.setString(_usageMonthKey, month);
    }
    if (count >= BackendConfig.mapboxTrafficMonthlyRequestLimit) return false;
    await preferences.setInt(_usageCountKey, count + 1);
    return true;
  }

  @visibleForTesting
  static List<LatLng> sampleRoutePoints(List<LatLng> points) {
    if (points.length <= _maximumCoordinates) return List.unmodifiable(points);
    const distance = Distance();
    final cumulative = List<double>.filled(points.length, 0);
    for (var index = 1; index < points.length; index++) {
      cumulative[index] =
          cumulative[index - 1] + distance(points[index - 1], points[index]);
    }
    final totalDistance = cumulative.last;
    if (totalDistance <= 0) {
      return List.unmodifiable(<LatLng>[points.first, points.last]);
    }

    final sampled = <LatLng>[];
    var cursor = 0;
    for (var i = 0; i < _maximumCoordinates; i++) {
      final target = totalDistance * i / (_maximumCoordinates - 1);
      while (cursor < cumulative.length - 1 && cumulative[cursor] < target) {
        cursor++;
      }
      var selected = cursor;
      if (cursor > 0 &&
          (target - cumulative[cursor - 1]).abs() <
              (cumulative[cursor] - target).abs()) {
        selected = cursor - 1;
      }
      final point = points[selected];
      if (sampled.isEmpty || sampled.last != point) sampled.add(point);
    }
    if (sampled.last != points.last) sampled.add(points.last);
    return List.unmodifiable(sampled);
  }
}
