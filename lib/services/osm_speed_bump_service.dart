import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:slowride/core/constants/backend_config.dart';
import 'package:slowride/models/alert_model.dart';

/// Loads traffic-calming points extracted from OpenStreetMap by the CruizX
/// backend. The backend quantizes and caches requests so mobile clients never
/// put direct load on the public Overpass API.
class OsmSpeedBumpService {
  OsmSpeedBumpService._();

  static final OsmSpeedBumpService instance = OsmSpeedBumpService._();

  final Map<String, _CachedBumps> _cache = {};
  static const Duration _memoryCacheTtl = Duration(hours: 6);

  Future<List<AlertModel>> fetchNearby(
    LatLng center, {
    double radiusKm = 15,
  }) async {
    final key = _cacheKey(center, radiusKm);
    final cached = _cache[key];
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt) < _memoryCacheTtl) {
      return cached.bumps;
    }

    final uri = Uri.parse('${BackendConfig.mapDataBaseUrl}/api/map/speed-bumps')
        .replace(
          queryParameters: {
            'lat': center.latitude.toStringAsFixed(6),
            'lng': center.longitude.toStringAsFixed(6),
            'radius_km': radiusKm.clamp(1, 25).toStringAsFixed(0),
          },
        );

    final response = await http
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw StateError('CruizX map data returned HTTP ${response.statusCode}');
    }

    final bumps = parseResponse(response.body);
    _cache[key] = _CachedBumps(bumps: bumps, fetchedAt: DateTime.now());
    return bumps;
  }

  /// Combines already loaded community alerts with OSM data near the start,
  /// midpoint and destination, then selects the points most relevant to the
  /// requested route. Valhalla defaults to at most 50 exclude locations; 40
  /// leaves room for the points used to generate alternative routes.
  Future<List<LatLng>> avoidLocationsForRoute({
    required LatLng origin,
    required LatLng destination,
    LatLng? waypoint,
    List<AlertModel> knownAlerts = const [],
    int maxLocations = 40,
  }) async {
    final centers = <LatLng>{
      origin,
      ?waypoint,
      LatLng(
        (origin.latitude + destination.latitude) / 2,
        (origin.longitude + destination.longitude) / 2,
      ),
      destination,
    };
    final fetched = await Future.wait(
      centers.map((center) async {
        try {
          return await fetchNearby(center);
        } catch (_) {
          return const <AlertModel>[];
        }
      }),
    );
    return selectForRoute(
      alerts: [...knownAlerts, ...fetched.expand((items) => items)],
      origin: origin,
      destination: destination,
      waypoint: waypoint,
      maxLocations: maxLocations,
    );
  }

  @visibleForTesting
  static List<LatLng> selectForRoute({
    required List<AlertModel> alerts,
    required LatLng origin,
    required LatLng destination,
    LatLng? waypoint,
    int maxLocations = 40,
  }) {
    const distance = Distance();
    final routeSegments = <(LatLng, LatLng)>[
      if (waypoint == null)
        (origin, destination)
      else ...[
        (origin, waypoint),
        (waypoint, destination),
      ],
    ];
    final unique = <String, AlertModel>{};
    for (final alert in alerts) {
      if (alert.type == AlertType.speedBump) unique[alert.id] = alert;
    }
    final ranked = unique.values.map((alert) {
      final score = routeSegments
          .map(
            (segment) =>
                distance(segment.$1, alert.position) +
                distance(alert.position, segment.$2) -
                distance(segment.$1, segment.$2),
          )
          .reduce((a, b) => a < b ? a : b);
      return (alert: alert, score: score);
    }).toList()..sort((a, b) => a.score.compareTo(b.score));

    return ranked
        .take(maxLocations.clamp(0, 40))
        .map((entry) => entry.alert.position)
        .toList(growable: false);
  }

  @visibleForTesting
  static List<AlertModel> parseResponse(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) return const [];
    final rows = decoded['bumps'];
    if (rows is! List) return const [];

    final fetchedAt =
        DateTime.tryParse(decoded['fetched_at']?.toString() ?? '') ??
        DateTime.now();
    final result = <AlertModel>[];
    final seen = <String>{};
    for (final row in rows) {
      if (row is! Map) continue;
      final data = Map<String, dynamic>.from(row);
      final id = data['id']?.toString() ?? '';
      final lat = (data['lat'] as num?)?.toDouble();
      final lng = (data['lng'] as num?)?.toDouble();
      if (id.isEmpty || lat == null || lng == null || !seen.add(id)) continue;
      if (lat < -90 || lat > 90 || lng < -180 || lng > 180) continue;

      result.add(
        AlertModel(
          id: id,
          type: AlertType.speedBump,
          position: LatLng(lat, lng),
          description: 'OpenStreetMap · ${data['kind'] ?? 'traffic_calming'}',
          upvotes: 0,
          createdAt: fetchedAt,
        ),
      );
    }
    return List.unmodifiable(result);
  }

  String _cacheKey(LatLng center, double radiusKm) {
    final latCell = (center.latitude / 0.05).round();
    final lngCell = (center.longitude / 0.05).round();
    final radiusCell = (radiusKm.clamp(1, 25) / 5).ceil();
    return '$latCell:$lngCell:$radiusCell';
  }
}

class _CachedBumps {
  const _CachedBumps({required this.bumps, required this.fetchedAt});

  final List<AlertModel> bumps;
  final DateTime fetchedAt;
}
