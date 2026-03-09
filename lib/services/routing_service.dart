import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:slowride/core/constants/backend_config.dart';

enum RoutingErrorCode {
  unknownProvider,
  providerUnavailable,
  noRouteFound,
  invalidGeometry,
  missingApiKey,
  routeTooFastForVehicle,
  routeNotAllowedForVehicle,
}

class RouteResult {
  const RouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;
}

class RoutingService {
  static const String _providerOsrmPublic = 'osrm_public';
  static const String _providerOsrmSelfHosted = 'osrm_self_hosted';
  static const String _providerOpenRouteService = 'openrouteservice';

  Future<RouteResult> getRoute({
    required LatLng origin,
    required LatLng destination,
    required String vehicleType,
  }) async {
    final provider = BackendConfig.routingProvider;
    late final RouteResult route;

    if (provider == _providerOpenRouteService) {
      route = await _getRouteFromOpenRouteService(
        origin: origin,
        destination: destination,
        vehicleType: vehicleType,
      );
      // Only validate speed for ORS — it returns actual vehicle travel times.
      _validateRouteSpeed(route: route, vehicleType: vehicleType);
    } else if (provider == _providerOsrmSelfHosted ||
        provider == _providerOsrmPublic) {
      route = await _getRouteFromOsrm(
        origin: origin,
        destination: destination,
        vehicleType: vehicleType,
      );
      // OSRM calculates car travel times, not slow-vehicle times —
      // skip speed validation to avoid false positives.
    } else {
      throw const RoutingException(RoutingErrorCode.unknownProvider);
    }

    return route;
  }

  Future<RouteResult> _getRouteFromOsrm({
    required LatLng origin,
    required LatLng destination,
    required String vehicleType,
  }) async {
    // OSRM public API does not support exclude parameters —
    // use bare routing without exclude flags.
    final url = Uri.parse(
      '${BackendConfig.osrmBaseUrl}/route/v1/driving/'
      '${origin.longitude},${origin.latitude};'
      '${destination.longitude},${destination.latitude}'
      '?overview=full&geometries=geojson',
    );

    final response = await http.get(url);
    if (response.statusCode != 200) {
      throw const RoutingException(RoutingErrorCode.providerUnavailable);
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final routes = body['routes'] as List<dynamic>?;
    if (routes == null || routes.isEmpty) {
      throw const RoutingException(RoutingErrorCode.noRouteFound);
    }

    final firstRoute = routes.first as Map<String, dynamic>;
    final geometry = firstRoute['geometry'] as Map<String, dynamic>?;
    final coordinates = geometry?['coordinates'] as List<dynamic>?;

    if (coordinates == null || coordinates.isEmpty) {
      throw const RoutingException(RoutingErrorCode.invalidGeometry);
    }

    final points = coordinates
        .whereType<List<dynamic>>()
        .where((pair) => pair.length >= 2)
        .map(
          (pair) =>
              LatLng((pair[1] as num).toDouble(), (pair[0] as num).toDouble()),
        )
        .toList(growable: false);

    final distanceMeters = (firstRoute['distance'] as num?)?.toDouble() ?? 0;
    // OSRM returns car travel times. Recalculate using the vehicle's actual
    // max speed so A-tractor (30 km/h) and Moped car (45 km/h) show
    // realistic times.
    final vehicleMaxSpeedKmh = _maxAllowedAverageSpeedKmhFor(vehicleType);
    // Use 85% of max speed as realistic average (traffic lights, bends, etc.)
    final avgSpeedMs = (vehicleMaxSpeedKmh * 0.85) / 3.6;
    final calculatedDurationSeconds = avgSpeedMs > 0
        ? distanceMeters / avgSpeedMs
        : 0.0;

    return RouteResult(
      points: points,
      distanceMeters: distanceMeters,
      durationSeconds: calculatedDurationSeconds,
    );
  }

  Future<RouteResult> _getRouteFromOpenRouteService({
    required LatLng origin,
    required LatLng destination,
    required String vehicleType,
  }) async {
    final constraints = _routingConstraintsFor(vehicleType);
    final apiKey = BackendConfig.openRouteServiceApiKey;
    if (apiKey.isEmpty) {
      throw const RoutingException(RoutingErrorCode.missingApiKey);
    }

    final url = Uri.parse(
      '${BackendConfig.openRouteServiceBaseUrl}/v2/directions/driving-car/geojson',
    );

    final response = await http.post(
      url,
      headers: {'Authorization': apiKey, 'Content-Type': 'application/json'},
      body: jsonEncode({
        'coordinates': [
          [origin.longitude, origin.latitude],
          [destination.longitude, destination.latitude],
        ],
        'options': {
          'avoid_features': constraints.openRouteServiceAvoidFeatures,
        },
      }),
    );

    if (response.statusCode != 200) {
      throw const RoutingException(RoutingErrorCode.providerUnavailable);
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final features = body['features'] as List<dynamic>?;
    if (features == null || features.isEmpty) {
      throw const RoutingException(RoutingErrorCode.noRouteFound);
    }

    final firstFeature = features.first as Map<String, dynamic>;
    final geometry = firstFeature['geometry'] as Map<String, dynamic>?;
    final coordinates = geometry?['coordinates'] as List<dynamic>?;
    final properties = firstFeature['properties'] as Map<String, dynamic>?;
    final summary = properties?['summary'] as Map<String, dynamic>?;

    if (coordinates == null || coordinates.isEmpty) {
      throw const RoutingException(RoutingErrorCode.invalidGeometry);
    }

    final points = coordinates
        .whereType<List<dynamic>>()
        .where((pair) => pair.length >= 2)
        .map(
          (pair) =>
              LatLng((pair[1] as num).toDouble(), (pair[0] as num).toDouble()),
        )
        .toList(growable: false);

    return RouteResult(
      points: points,
      distanceMeters: (summary?['distance'] as num?)?.toDouble() ?? 0,
      durationSeconds: (summary?['duration'] as num?)?.toDouble() ?? 0,
    );
  }
}

class _RoutingConstraints {
  const _RoutingConstraints({
    required this.osrmExclude,
    required this.openRouteServiceAvoidFeatures,
  });

  final List<String> osrmExclude;
  final List<String> openRouteServiceAvoidFeatures;
}

_RoutingConstraints _routingConstraintsFor(String vehicleType) {
  switch (vehicleType) {
    case 'A-tractor':
      return const _RoutingConstraints(
        osrmExclude: ['motorway', 'toll', 'ferry'],
        openRouteServiceAvoidFeatures: ['highways', 'tollways', 'ferries'],
      );
    case 'Moped car':
      return const _RoutingConstraints(
        osrmExclude: ['motorway', 'toll', 'ferry'],
        openRouteServiceAvoidFeatures: ['highways', 'tollways', 'ferries'],
      );
    case 'Tractor':
      return const _RoutingConstraints(
        osrmExclude: ['motorway', 'toll'],
        openRouteServiceAvoidFeatures: ['highways', 'tollways'],
      );
    default:
      return const _RoutingConstraints(
        osrmExclude: ['motorway', 'toll', 'ferry'],
        openRouteServiceAvoidFeatures: ['highways', 'tollways', 'ferries'],
      );
  }
}

double _maxAllowedAverageSpeedKmhFor(String vehicleType) {
  // Swedish legal top speeds for slow vehicles.
  switch (vehicleType) {
    case 'A-tractor':
      return 30; // max 30 km/h by law
    case 'Moped car':
      return 45; // max 45 km/h by law
    case 'Tractor':
      return 30; // typical road tractor max
    default:
      return 30;
  }
}

void _validateRouteSpeed({
  required RouteResult route,
  required String vehicleType,
}) {
  if (route.durationSeconds <= 0 || route.distanceMeters <= 0) {
    throw const RoutingException(RoutingErrorCode.routeNotAllowedForVehicle);
  }

  final averageSpeedKmh = (route.distanceMeters / route.durationSeconds) * 3.6;
  final maxAllowedAverageSpeedKmh = _maxAllowedAverageSpeedKmhFor(vehicleType);

  if (averageSpeedKmh > maxAllowedAverageSpeedKmh) {
    throw const RoutingException(RoutingErrorCode.routeTooFastForVehicle);
  }
}

class RoutingException implements Exception {
  const RoutingException(this.code);

  final RoutingErrorCode code;

  @override
  String toString() => code.name;
}
