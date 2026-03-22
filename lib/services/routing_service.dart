import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:slowride/core/constants/backend_config.dart';
import 'package:slowride/services/user_preferences_service.dart';

enum RoutingErrorCode {
  unknownProvider,
  providerUnavailable,
  noRouteFound,
  invalidGeometry,
  missingApiKey,
  routeTooFastForVehicle,
  routeNotAllowedForVehicle,
}

/// A single turn-by-turn instruction returned from the routing provider.
/// [sign] uses GraphHopper sign conventions:
///  -3=sharp left, -2=left, -1=slight left, 0=straight,
///   1=slight right, 2=right, 3=sharp right, 4=finish, 6=roundabout.
class RouteInstruction {
  const RouteInstruction({
    required this.sign,
    required this.text,
    required this.distanceMeters,
    required this.pointIndex,
    this.streetName = '',
  });

  final int sign;
  final String text;
  final double distanceMeters;

  /// Index into [RouteResult.points] where this instruction begins.
  final int pointIndex;

  /// Name of the street the user is traveling on during this instruction.
  final String streetName;
}

class RouteResult {
  const RouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    this.instructions = const [],
  });

  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;
  final List<RouteInstruction> instructions;
}

class RoutingService {
  static const String _providerOsrmPublic = 'osrm_public';
  static const String _providerOsrmSelfHosted = 'osrm_self_hosted';
  static const String _providerOpenRouteService = 'openrouteservice';
  static const String _providerGraphHopper = 'graphhopper';
  static const String _providerValhalla = 'valhalla';

  Future<RouteResult> getRoute({
    required LatLng origin,
    required LatLng destination,
    required String vehicleType,
  }) async {
    final provider = BackendConfig.routingProvider;
    // Use the user's chosen speed (they may have adjusted it from the default).
    final userSpeed = UserPreferencesService.instance.maxSpeedKmh.value;
    late final RouteResult route;

    if (provider == _providerGraphHopper) {
      route = await _getRouteFromGraphHopper(
        origin: origin,
        destination: destination,
        vehicleType: vehicleType,
        userSpeedKmh: userSpeed,
      );
    } else if (provider == _providerOpenRouteService) {
      route = await _getRouteFromOpenRouteService(
        origin: origin,
        destination: destination,
        vehicleType: vehicleType,
        userSpeedKmh: userSpeed,
      );
      // Only validate speed for ORS — it returns actual vehicle travel times.
      _validateRouteSpeed(route: route, vehicleType: vehicleType);
    } else if (provider == _providerOsrmSelfHosted ||
        provider == _providerOsrmPublic) {
      route = await _getRouteFromOsrm(
        origin: origin,
        destination: destination,
        vehicleType: vehicleType,
        userSpeedKmh: userSpeed,
      );
      // OSRM calculates car travel times, not slow-vehicle times —
      // skip speed validation to avoid false positives.
    } else if (provider == _providerValhalla) {
      route = await _getRouteFromValhalla(
        origin: origin,
        destination: destination,
        vehicleType: vehicleType,
        userSpeedKmh: userSpeed,
      );
      // Valhalla uses our custom costing options with correct max speeds,
      // so duration is already accurate for slow vehicles.
    } else {
      throw const RoutingException(RoutingErrorCode.unknownProvider);
    }

    return route;
  }

  Future<RouteResult> _getRouteFromGraphHopper({
    required LatLng origin,
    required LatLng destination,
    required String vehicleType,
    required double userSpeedKmh,
  }) async {
    final apiKey = BackendConfig.graphhopperApiKey;
    if (apiKey.isEmpty) {
      throw const RoutingException(RoutingErrorCode.missingApiKey);
    }

    final vehicleMaxSpeedKmh = userSpeedKmh;

    // GraphHopper free-tier GET API.
    // The `avoid` parameter IS supported on free plans (unlike custom_model
    // which requires the paid Platinum tier).
    // Slow vehicles must avoid motorways and ferries by law.
    final avoidFeatures = _graphHopperAvoidFor(vehicleType);

    // Build URI manually to handle repeated `point=` params correctly.
    final buffer = StringBuffer(
      '${BackendConfig.graphhopperBaseUrl}/route?key=$apiKey'
      '&profile=car&points_encoded=false&instructions=true&locale=sv',
    );
    buffer.write(
      '&point=${origin.latitude},${origin.longitude}'
      '&point=${destination.latitude},${destination.longitude}',
    );
    if (avoidFeatures.isNotEmpty) {
      buffer.write('&avoid=${avoidFeatures.join(',')}');
    }

    final response = await http.get(
      Uri.parse(buffer.toString()),
      headers: const {'Accept': 'application/json'},
    );

    if (response.statusCode != 200) {
      throw const RoutingException(RoutingErrorCode.providerUnavailable);
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final paths = body['paths'] as List<dynamic>?;
    if (paths == null || paths.isEmpty) {
      throw const RoutingException(RoutingErrorCode.noRouteFound);
    }

    final firstPath = paths.first as Map<String, dynamic>;
    final pointsObj = firstPath['points'] as Map<String, dynamic>?;
    final coordinates = pointsObj?['coordinates'] as List<dynamic>?;

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

    final distanceMeters = (firstPath['distance'] as num?)?.toDouble() ?? 0;

    // Recalculate duration using 85% of the vehicle's legal max speed
    // (accounts for traffic lights, bends, junctions etc.).
    final avgSpeedMs = (vehicleMaxSpeedKmh * 0.85) / 3.6;
    final calculatedDurationSeconds = avgSpeedMs > 0
        ? distanceMeters / avgSpeedMs
        : 0.0;

    // Parse turn-by-turn instructions.
    final rawInstructions =
        firstPath['instructions'] as List<dynamic>? ?? const [];
    final instructions = rawInstructions
        .whereType<Map<String, dynamic>>()
        .map((inst) {
          final interval = inst['interval'] as List<dynamic>?;
          final startIdx = (interval?.first as num?)?.toInt() ?? 0;
          return RouteInstruction(
            sign: (inst['sign'] as num?)?.toInt() ?? 0,
            text: (inst['text'] as String?) ?? '',
            distanceMeters: (inst['distance'] as num?)?.toDouble() ?? 0,
            pointIndex: startIdx,
          );
        })
        .toList(growable: false);

    return RouteResult(
      points: points,
      distanceMeters: distanceMeters,
      durationSeconds: calculatedDurationSeconds,
      instructions: instructions,
    );
  }

  Future<RouteResult> _getRouteFromOsrm({
    required LatLng origin,
    required LatLng destination,
    required String vehicleType,
    required double userSpeedKmh,
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
    final vehicleMaxSpeedKmh = userSpeedKmh;
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
    required double userSpeedKmh,
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

  /// Valhalla self-hosted routing with custom vehicle profiles for slow vehicles.
  /// Supports A-tractor (30 km/h), Moped car (45 km/h), and Tractor (30 km/h)
  /// with proper road restrictions (no motorways, no ferries for most).
  Future<RouteResult> _getRouteFromValhalla({
    required LatLng origin,
    required LatLng destination,
    required String vehicleType,
    required double userSpeedKmh,
  }) async {
    final baseUrl = BackendConfig.valhallaBaseUrl;
    final costingOptions = _valhallaCostingOptionsFor(vehicleType);
    // Override top_speed with the user's chosen speed
    costingOptions['top_speed'] = userSpeedKmh.round();
    final vehicleMaxSpeedKmh = userSpeedKmh;

    final requestBody = jsonEncode({
      'locations': [
        {'lat': origin.latitude, 'lon': origin.longitude},
        {'lat': destination.latitude, 'lon': destination.longitude},
      ],
      'costing': 'auto',
      'costing_options': {'auto': costingOptions},
      'directions_options': {'units': 'kilometers', 'language': 'sv-SE'},
      // Request shape as decoded coordinates for easier parsing
      'shape_format': 'polyline6',
    });

    final url = Uri.parse('$baseUrl/route');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: requestBody,
    );

    if (response.statusCode != 200) {
      throw const RoutingException(RoutingErrorCode.providerUnavailable);
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final trip = body['trip'] as Map<String, dynamic>?;
    if (trip == null) {
      throw const RoutingException(RoutingErrorCode.noRouteFound);
    }

    final legs = trip['legs'] as List<dynamic>?;
    if (legs == null || legs.isEmpty) {
      throw const RoutingException(RoutingErrorCode.noRouteFound);
    }

    // Decode all leg shapes and combine into single route
    final allPoints = <LatLng>[];
    final allInstructions = <RouteInstruction>[];

    for (final leg in legs) {
      final legMap = leg as Map<String, dynamic>;
      final shape = legMap['shape'] as String?;
      if (shape != null) {
        final legPoints = _decodePolyline6(shape);
        allPoints.addAll(legPoints);
      }

      // Parse maneuvers (turn-by-turn instructions)
      final maneuvers = legMap['maneuvers'] as List<dynamic>? ?? [];
      for (final maneuver in maneuvers) {
        final m = maneuver as Map<String, dynamic>;
        // Valhalla provides street_names for the road after this maneuver
        final streetNames = m['street_names'] as List<dynamic>?;
        final streetName = (streetNames != null && streetNames.isNotEmpty)
            ? streetNames.first as String
            : '';
        allInstructions.add(
          RouteInstruction(
            sign: _valhallaTypeToGraphHopperSign(m['type'] as int? ?? 0),
            text: m['instruction'] as String? ?? '',
            distanceMeters: ((m['length'] as num?)?.toDouble() ?? 0) * 1000,
            pointIndex: allPoints.length > 0
                ? (m['begin_shape_index'] as int? ?? 0)
                : 0,
            streetName: streetName,
          ),
        );
      }
    }

    if (allPoints.isEmpty) {
      throw const RoutingException(RoutingErrorCode.invalidGeometry);
    }

    // Valhalla returns summary with length in km and time in seconds
    final summary = trip['summary'] as Map<String, dynamic>?;
    final distanceKm = (summary?['length'] as num?)?.toDouble() ?? 0;
    final distanceMeters = distanceKm * 1000;

    // Valhalla calculates time based on our costing_options.top_speed,
    // but we recalculate for consistency at 85% of max speed.
    final avgSpeedMs = (vehicleMaxSpeedKmh * 0.85) / 3.6;
    final calculatedDurationSeconds = avgSpeedMs > 0
        ? distanceMeters / avgSpeedMs
        : 0.0;

    return RouteResult(
      points: allPoints,
      distanceMeters: distanceMeters,
      durationSeconds: calculatedDurationSeconds,
      instructions: allInstructions,
    );
  }

  /// Decode Valhalla's polyline6 format (precision 1e-6) to LatLng list.
  List<LatLng> _decodePolyline6(String encoded) {
    final points = <LatLng>[];
    var index = 0;
    var lat = 0;
    var lng = 0;

    while (index < encoded.length) {
      // Decode latitude
      var shift = 0;
      var result = 0;
      int byte;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1F) << shift;
        shift += 5;
      } while (byte >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      // Decode longitude
      shift = 0;
      result = 0;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1F) << shift;
        shift += 5;
      } while (byte >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      // Polyline6 uses 1e-6 precision
      points.add(LatLng(lat / 1e6, lng / 1e6));
    }

    return points;
  }

  /// Convert Valhalla maneuver type to GraphHopper sign convention.
  /// This allows consistent instruction handling across all providers.
  int _valhallaTypeToGraphHopperSign(int valhallaType) {
    // Valhalla maneuver types:
    // 0=none, 1=start, 2=start right, 3=start left, 4=destination,
    // 5=destination right, 6=destination left, 7=becomes, 8=continue,
    // 9=slight right, 10=right, 11=sharp right, 12=u-turn right,
    // 13=u-turn left, 14=sharp left, 15=left, 16=slight left,
    // 17-20=ramp variations, 21-24=exit variations, 25=roundabout, etc.
    switch (valhallaType) {
      case 0:
      case 1:
      case 7:
      case 8:
        return 0; // Straight / continue
      case 4:
      case 5:
      case 6:
        return 4; // Finish / destination
      case 9:
        return 1; // Slight right
      case 10:
        return 2; // Right
      case 11:
      case 12:
        return 3; // Sharp right / U-turn right
      case 13:
      case 14:
        return -3; // Sharp left / U-turn left
      case 15:
        return -2; // Left
      case 16:
        return -1; // Slight left
      case 25:
      case 26:
      case 27:
        return 6; // Roundabout
      default:
        return 0; // Default to straight
    }
  }
}

/// Valhalla costing options for slow vehicles.
/// These settings ensure Valhalla routes correctly for Swedish EPA/A-traktor,
/// Mopedbil, and Tractor vehicles.
Map<String, dynamic> _valhallaCostingOptionsFor(String vehicleType) {
  switch (vehicleType) {
    case 'A-tractor':
      // A-traktor: Max 30 km/h, no motorways, no ferries, no tolls
      return {
        'top_speed': 30,
        'use_highways': 0.0, // Avoid motorways completely
        'use_tolls': 0.0, // Avoid toll roads
        'use_ferry': 0.0, // Avoid ferries (not allowed for EPA)
        'shortest': false, // Optimize for time, not distance
      };
    case 'Moped car':
      // Mopedbil: Max 45 km/h, no motorways, no ferries
      return {
        'top_speed': 45,
        'use_highways': 0.0,
        'use_tolls': 0.0,
        'use_ferry': 0.0,
        'shortest': false,
      };
    case 'Tractor':
      // Tractor: Max 30 km/h, no motorways, ferries allowed
      return {
        'top_speed': 30,
        'use_highways': 0.0,
        'use_tolls': 0.5, // Some tolerance for toll roads
        'use_ferry': 0.5, // Ferries allowed for tractors
        'shortest': false,
      };
    default:
      // Default to most restrictive (A-traktor settings)
      return {
        'top_speed': 30,
        'use_highways': 0.0,
        'use_tolls': 0.0,
        'use_ferry': 0.0,
        'shortest': false,
      };
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

/// Returns the `avoid` features to pass to GraphHopper's free-tier GET API.
/// Supported values: motorway, ferry, tunnel, ford, track, toll.
List<String> _graphHopperAvoidFor(String vehicleType) {
  switch (vehicleType) {
    case 'Tractor':
      // Tractors can use ferries but not motorways.
      return ['motorway'];
    default:
      // A-tractor, Moped car — motorway, ferry and toll are illegal/unusable.
      return ['motorway', 'ferry', 'toll'];
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
