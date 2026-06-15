import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:slowride/core/constants/backend_config.dart';
import 'package:slowride/models/country_vehicle_rules.dart';
import 'package:slowride/models/studded_tire_zones.dart';
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

  /// Which provider actually served the last successful route.
  /// UI can read this to show a subtle indicator when fallback is active.
  String? lastUsedProvider;

  /// Fallback chain: Valhalla → GraphHopper → OSRM public.
  /// Always tries Valhalla first (best quality for slow vehicles).
  /// Falls back automatically only for non-legal-critical routing.
  static const _fallbackChain = [
    _providerValhalla,
    _providerGraphHopper,
    _providerOsrmPublic,
  ];

  // Motorway keywords in all 7 supported app languages + English.
  // Used to hard-reject routes that contain motorway segments for slow vehicles
  // (A-tractor ≤ 30 km/h, moped car ≤ 45 km/h, tractor ≤ 40 km/h).
  static const List<String> _motorwayKeywords = [
    'motorway', 'freeway', 'expressway', // English
    'motorväg', 'motortrafikled', // Swedish
    'motorvei', 'motortrafikkvei', // Norwegian
    'motorvej', 'motortrafikvej', // Danish
    'moottoritie', // Finnish
    'autoroute', 'voie express', // French
    'autopista', 'autovía', 'autovia', // Spanish
  ];

  /// Hard-rejects a route for slow vehicles (legal max ≤ 45 km/h) if any
  /// turn instruction text or street name contains a motorway keyword.
  ///
  /// Valhalla uses [use_highways: 0.0] as a strong *preference*, not a hard
  /// ban — it still routes via motorways when it sees no alternative.
  /// This post-processing guard ensures those routes are never surfaced to
  /// A-tractor, moped-car, or tractor users.
  void _assertNoMotorwayForSlowVehicle({
    required RouteResult route,
    required String vehicleType,
    required String countryCode,
  }) {
    final maxLegalSpeed = CountryVehicleRules.maxLegalSpeedFor(
      countryCode,
      vehicleType,
    );
    if (maxLegalSpeed > 45) return; // Non-slow vehicle — not restricted.

    for (final instruction in route.instructions) {
      final text = instruction.text.toLowerCase();
      final street = instruction.streetName.toLowerCase();
      for (final keyword in _motorwayKeywords) {
        if (text.contains(keyword) || street.contains(keyword)) {
          throw const RoutingException(
            RoutingErrorCode.routeNotAllowedForVehicle,
          );
        }
      }
    }
  }

  String _graphHopperLocale() {
    final code = UserPreferencesService.instance.languageCode.value;
    return switch (code) {
      'sv' => 'sv',
      'en' => 'en',
      'fr' => 'fr',
      'nb' => 'no',
      'da' => 'da',
      'fi' => 'fi',
      'es' => 'es',
      _ => 'en',
    };
  }

  String _valhallaLanguage() {
    final code = UserPreferencesService.instance.languageCode.value;
    return switch (code) {
      'sv' => 'sv-SE',
      'en' => 'en-US',
      'fr' => 'fr-FR',
      'nb' => 'nb-NO',
      'da' => 'da-DK',
      'fi' => 'fi-FI',
      'es' => 'es-ES',
      _ => 'en-US',
    };
  }

  Future<RouteResult> getRoute({
    required LatLng origin,
    required LatLng destination,
    required String vehicleType,
  }) async {
    final userSpeed = UserPreferencesService.instance.maxSpeedKmh.value;
    final country = UserPreferencesService.instance.countryCode.value;
    final profile = CountryVehicleRules.getProfile(country, vehicleType);
    final maxLegalSpeed = CountryVehicleRules.maxLegalSpeedFor(
      country,
      vehicleType,
    );

    final configuredProvider = BackendConfig.routingProvider;

    // Build provider order: configured provider first, then fallback chain.
    final providers = <String>[configuredProvider];
    for (final p in _fallbackChain) {
      if (!providers.contains(p)) providers.add(p);
    }

    // Slow-vehicle legal rules must never be weakened by provider fallback.
    // OSRM/GraphHopper can not enforce all country+vehicle legal constraints
    // as strictly as Valhalla.
    final requiresStrictAvoids =
        profile.useHighways < 0.3 ||
        profile.useFerry < 0.3 ||
        profile.useTolls < 0.3;
    final isSlowVehicle = maxLegalSpeed <= 45;
    final mustUseStrictLegalRouting = requiresStrictAvoids || isSlowVehicle;

    // GraphHopper/OSRM cannot reliably enforce "avoid 70-80 roads" behavior.
    // For slow vehicles, keep routing on providers that support stronger
    // profile constraints and then prefer Valhalla first.
    final eligibleProviders = (() {
      // Legal-critical routing only uses providers that can apply explicit
      // avoid rules. OSRM providers are excluded here.
      if (mustUseStrictLegalRouting) {
        final strictProviders = providers
            .where(
              (p) => p != _providerOsrmPublic && p != _providerOsrmSelfHosted,
            )
            .toList(growable: true);
        strictProviders.remove(_providerValhalla);
        strictProviders.insert(0, _providerValhalla);
        return strictProviders.toList(growable: false);
      }

      final base = providers.toList(growable: true);
      base.remove(_providerValhalla);
      base.insert(0, _providerValhalla);
      return base.toList(growable: false);
    })();

    Object? lastError;
    for (final provider in eligibleProviders) {
      try {
        final route = await _routeWith(
          provider: provider,
          origin: origin,
          destination: destination,
          vehicleType: vehicleType,
          userSpeedKmh: userSpeed,
          countryCode: country,
        );
        lastUsedProvider = provider;
        return route;
      } on RoutingException catch (e) {
        // Retry with next provider on provider outages.
        // Also allow fallback if Valhalla reports no-route for a request,
        // since data freshness can differ between providers.
        final canFallback = mustUseStrictLegalRouting
            ? e.code == RoutingErrorCode.providerUnavailable
            : (e.code == RoutingErrorCode.providerUnavailable ||
                  (provider == _providerValhalla &&
                      e.code == RoutingErrorCode.noRouteFound));
        if (canFallback) {
          lastError = e;
          continue;
        }
        rethrow;
      } catch (e) {
        // Network errors, timeouts, JSON parse failures → try next provider.
        lastError = e;
        continue;
      }
    }

    // All providers failed.
    if (lastError is RoutingException) throw lastError;
    throw const RoutingException(RoutingErrorCode.providerUnavailable);
  }

  Future<RouteResult> _routeWith({
    required String provider,
    required LatLng origin,
    required LatLng destination,
    required String vehicleType,
    required double userSpeedKmh,
    required String countryCode,
  }) async {
    if (provider == _providerValhalla) {
      return _getRouteFromValhalla(
        origin: origin,
        destination: destination,
        vehicleType: vehicleType,
        userSpeedKmh: userSpeedKmh,
        countryCode: countryCode,
      );
    } else if (provider == _providerGraphHopper) {
      final route = await _getRouteFromGraphHopper(
        origin: origin,
        destination: destination,
        vehicleType: vehicleType,
        userSpeedKmh: userSpeedKmh,
        countryCode: countryCode,
      );
      _validateRouteSpeed(
        route: route,
        vehicleType: vehicleType,
        countryCode: countryCode,
      );
      _assertNoMotorwayForSlowVehicle(
        route: route,
        vehicleType: vehicleType,
        countryCode: countryCode,
      );
      return route;
    } else if (provider == _providerOpenRouteService) {
      final route = await _getRouteFromOpenRouteService(
        origin: origin,
        destination: destination,
        vehicleType: vehicleType,
        userSpeedKmh: userSpeedKmh,
        countryCode: countryCode,
      );
      _validateRouteSpeed(
        route: route,
        vehicleType: vehicleType,
        countryCode: countryCode,
      );
      _assertNoMotorwayForSlowVehicle(
        route: route,
        vehicleType: vehicleType,
        countryCode: countryCode,
      );
      return route;
    } else if (provider == _providerOsrmSelfHosted ||
        provider == _providerOsrmPublic) {
      return _getRouteFromOsrm(
        origin: origin,
        destination: destination,
        vehicleType: vehicleType,
        userSpeedKmh: userSpeedKmh,
        countryCode: countryCode,
      );
    }
    throw const RoutingException(RoutingErrorCode.unknownProvider);
  }

  Future<RouteResult> _getRouteFromGraphHopper({
    required LatLng origin,
    required LatLng destination,
    required String vehicleType,
    required double userSpeedKmh,
    required String countryCode,
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
    final avoidFeatures = _graphHopperAvoidFor(vehicleType, countryCode);
    final locale = _graphHopperLocale();

    // Build URI manually to handle repeated `point=` params correctly.
    final buffer = StringBuffer(
      '${BackendConfig.graphhopperBaseUrl}/route?key=$apiKey'
      '&profile=car&points_encoded=false&instructions=true&locale=$locale',
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
    required String countryCode,
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
    required String countryCode,
  }) async {
    final constraints = _routingConstraintsFor(vehicleType, countryCode);
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
    required String countryCode,
  }) async {
    final baseUrl = BackendConfig.valhallaBaseUrl;
    final profile = CountryVehicleRules.getProfile(countryCode, vehicleType);
    final maxLegalSpeedKmh = CountryVehicleRules.maxLegalSpeedFor(
      countryCode,
      vehicleType,
    );
    final isSlowVehicle = maxLegalSpeedKmh <= 45;
    final costing = isSlowVehicle ? 'motor_scooter' : 'auto';
    final costingOptions = <String, dynamic>{
      // Clamp top_speed to the vehicle's legal maximum so Valhalla never
      // optimises for a speed the vehicle cannot legally achieve on any road.
      'top_speed': userSpeedKmh.clamp(1.0, maxLegalSpeedKmh).round(),
      'use_highways': profile.useHighways,
      'use_tolls': profile.useTolls,
      'use_ferry': profile.useFerry,
      // For slow vehicles, shortest tends to avoid long detours over larger
      // fast roads and keeps routing on local road networks.
      'shortest': isSlowVehicle,
    };
    if (isSlowVehicle) {
      costingOptions['use_primary'] = 0.0;
      costingOptions['disable_hierarchy_pruning'] = true;
    }
    final vehicleMaxSpeedKmh = userSpeedKmh;

    final requestPayload = <String, dynamic>{
      'locations': [
        {'lat': origin.latitude, 'lon': origin.longitude},
        {'lat': destination.latitude, 'lon': destination.longitude},
      ],
      'costing': costing,
      'costing_options': {costing: costingOptions},
      'directions_options': {
        'units': 'kilometers',
        'language': _valhallaLanguage(),
      },
      // Request shape as decoded coordinates for easier parsing
      'shape_format': 'polyline6',
    };

    // Avoid studded-tire ban zones when the user has studded tires equipped.
    if (UserPreferencesService.instance.hasStuddedTires.value) {
      final excludePolygons = StuddedTireZones.toValhallaExcludePolygons();
      if (excludePolygons.isNotEmpty) {
        requestPayload['exclude_polygons'] = excludePolygons;
      }
    }

    final requestBody = jsonEncode(requestPayload);

    final url = Uri.parse('$baseUrl/route');
    http.Response? response;
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        response = await http
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: requestBody,
            )
            .timeout(const Duration(seconds: 10));
        break;
      } on TimeoutException {
        if (attempt == 1) {
          throw const RoutingException(RoutingErrorCode.providerUnavailable);
        }
      }
    }

    if (response == null) {
      throw const RoutingException(RoutingErrorCode.providerUnavailable);
    }

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

        // Hard-block: Valhalla tags motorway maneuvers with highway:true.
        // Reject immediately — don't rely on instruction-text keywords which
        // can miss motorways referred to by road number (E4, E18, etc.).
        final isOnHighway = m['highway'] as bool? ?? false;
        if (isOnHighway) {
          final maxLegal = CountryVehicleRules.maxLegalSpeedFor(
            countryCode,
            vehicleType,
          );
          if (maxLegal <= 45) {
            throw const RoutingException(
              RoutingErrorCode.routeNotAllowedForVehicle,
            );
          }
        }

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
            pointIndex: allPoints.isNotEmpty
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
    if (isSlowVehicle && (summary?['has_highway'] as bool? ?? false)) {
      throw const RoutingException(RoutingErrorCode.routeNotAllowedForVehicle);
    }
    final distanceKm = (summary?['length'] as num?)?.toDouble() ?? 0;
    final distanceMeters = distanceKm * 1000;

    // Valhalla calculates time based on our costing_options.top_speed,
    // but we recalculate for consistency at 85% of max speed.
    final avgSpeedMs = (vehicleMaxSpeedKmh * 0.85) / 3.6;
    final calculatedDurationSeconds = avgSpeedMs > 0
        ? distanceMeters / avgSpeedMs
        : 0.0;

    final result = RouteResult(
      points: allPoints,
      distanceMeters: distanceMeters,
      durationSeconds: calculatedDurationSeconds,
      instructions: allInstructions,
    );
    // Hard-reject routes that include motorway segments for slow vehicles.
    _assertNoMotorwayForSlowVehicle(
      route: result,
      vehicleType: vehicleType,
      countryCode: countryCode,
    );
    return result;
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

class _RoutingConstraints {
  const _RoutingConstraints({
    required this.osrmExclude,
    required this.openRouteServiceAvoidFeatures,
  });

  final List<String> osrmExclude;
  final List<String> openRouteServiceAvoidFeatures;
}

_RoutingConstraints _routingConstraintsFor(
  String vehicleType,
  String countryCode,
) {
  final profile = CountryVehicleRules.getProfile(countryCode, vehicleType);
  // Highways are always avoided for slow vehicles in every country.
  // Ferry/toll avoidance depends on the country profile.
  final avoidFeatures = <String>['highways'];
  final osrmExclude = <String>['motorway'];

  if (profile.useFerry < 0.3) {
    avoidFeatures.add('ferries');
    osrmExclude.add('ferry');
  }
  if (profile.useTolls < 0.3) {
    avoidFeatures.add('tollways');
    osrmExclude.add('toll');
  }

  return _RoutingConstraints(
    osrmExclude: osrmExclude,
    openRouteServiceAvoidFeatures: avoidFeatures,
  );
}

/// Returns the `avoid` features to pass to GraphHopper's free-tier GET API.
List<String> _graphHopperAvoidFor(String vehicleType, String countryCode) {
  final profile = CountryVehicleRules.getProfile(countryCode, vehicleType);
  final avoid = <String>['motorway'];
  if (profile.useFerry < 0.3) avoid.add('ferry');
  if (profile.useTolls < 0.3) avoid.add('toll');
  return avoid;
}

double _maxAllowedAverageSpeedKmhFor(String vehicleType, String countryCode) {
  final selected = UserPreferencesService.instance.maxSpeedKmh.value;
  if (selected <= 0) return 1;
  return selected;
}

void _validateRouteSpeed({
  required RouteResult route,
  required String vehicleType,
  required String countryCode,
}) {
  if (route.durationSeconds <= 0 || route.distanceMeters <= 0) {
    throw const RoutingException(RoutingErrorCode.routeNotAllowedForVehicle);
  }

  final averageSpeedKmh = (route.distanceMeters / route.durationSeconds) * 3.6;
  final maxAllowedAverageSpeedKmh = _maxAllowedAverageSpeedKmhFor(
    vehicleType,
    countryCode,
  );

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
