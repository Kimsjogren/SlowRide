import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
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

  // Motorway keywords in all supported app languages + English.
  // Used to hard-reject routes that contain motorway segments for slow vehicles
  // (A-tractor ≤ 30 km/h, moped car ≤ 45 km/h, tractor ≤ 40 km/h).
  static const List<String> _motorwayKeywords = [
    'motorway', 'freeway', 'expressway', // English
    'motorväg', 'motortrafikled', // Swedish
    'motorvei', 'motortrafikkvei', // Norwegian
    'motorvej', 'motortrafikvej', // Danish
    'moottoritie', 'moottoriliikennetie', // Finnish
    'autoroute', 'voie express', // French
    'autopista', 'autovía', 'autovia', // Spanish
    'autostrada', 'strada extraurbana principale', 'superstrada', // Italian
  ];

  List<String> _forbiddenRoadKeywordsFor(
    String countryCode,
    String vehicleType,
  ) {
    if (vehicleType != 'Moped class I' &&
        vehicleType != 'Moped class II' &&
        vehicleType != 'Electric scooter') {
      return _motorwayKeywords;
    }

    // A British category AM moped is prohibited on motorways, but an ordinary
    // dual carriageway is not automatically prohibited. Other supported
    // countries also prohibit their motorway-like motor-road category.
    return switch (countryCode) {
      'SE' => const ['motorway', 'freeway', 'motorväg', 'motortrafikled'],
      'NO' => const ['motorway', 'freeway', 'motorvei', 'motortrafikkvei'],
      'DK' => const ['motorway', 'freeway', 'motorvej', 'motortrafikvej'],
      'FI' => const [
        'motorway',
        'freeway',
        'moottoritie',
        'moottoriliikennetie',
      ],
      'FR' => const ['motorway', 'freeway', 'autoroute', 'voie express'],
      'ES' => const ['motorway', 'freeway', 'autopista', 'autovía', 'autovia'],
      'IT' => const [
        'motorway',
        'freeway',
        'autostrada',
        'strada extraurbana principale',
        'superstrada',
      ],
      'GB' => const ['motorway', 'freeway'],
      _ => _motorwayKeywords,
    };
  }

  @visibleForTesting
  List<String> debugForbiddenRoadKeywords({
    required String countryCode,
    required String vehicleType,
  }) => _forbiddenRoadKeywordsFor(countryCode, vehicleType);

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
      for (final keyword in _forbiddenRoadKeywordsFor(
        countryCode,
        vehicleType,
      )) {
        if (text.contains(keyword) || street.contains(keyword)) {
          throw const RoutingException(
            RoutingErrorCode.routeNotAllowedForVehicle,
          );
        }
      }
    }
  }

  /// Provider-agnostic guard for fallback providers (GraphHopper/ORS) that lack
  /// Valhalla's own road-class loop: hard-rejects a slow-vehicle route that
  /// uses a motorway. Trunk/motor-roads are treated softly elsewhere, so they
  /// are not rejected here.
  Future<void> _assertNoForbiddenRoadClassForSlowVehicle({
    required RouteResult route,
    required String vehicleType,
    required String countryCode,
  }) async {
    final forbidden = await _forbiddenRoadClassPoints(
      routePoints: route.points,
      vehicleType: vehicleType,
      countryCode: countryCode,
    );
    if (forbidden.motorway.isNotEmpty) {
      throw const RoutingException(RoutingErrorCode.routeNotAllowedForVehicle);
    }
  }

  String _graphHopperLocale() {
    final code = _effectiveLanguageCode();
    return switch (code) {
      'sv' => 'sv',
      'en' => 'en',
      'fr' => 'fr',
      'nb' => 'no',
      'da' => 'da',
      'fi' => 'fi',
      'es' => 'es',
      'it' => 'it',
      _ => 'en',
    };
  }

  String _valhallaLanguage() {
    final code = _effectiveLanguageCode();
    return switch (code) {
      'sv' => 'sv-SE',
      'en' => 'en-US',
      'fr' => 'fr-FR',
      'nb' => 'nb-NO',
      'da' => 'da-DK',
      'fi' => 'fi-FI',
      'es' => 'es-ES',
      'it' => 'it-IT',
      _ => 'en-US',
    };
  }

  String _effectiveLanguageCode() {
    return UserPreferencesService.instance.languageCode.value ??
        PlatformDispatcher.instance.locale.languageCode;
  }

  @visibleForTesting
  Map<String, dynamic> debugBuildValhallaRequestPayload({
    required LatLng origin,
    required LatLng destination,
    LatLng? waypoint,
    required String vehicleType,
    required double userSpeedKmh,
    required String countryCode,
    String language = 'sv-SE',
    List<LatLng> avoidLocations = const [],
  }) {
    return _buildValhallaRequestPayload(
      origin: origin,
      destination: destination,
      waypoint: waypoint,
      vehicleType: vehicleType,
      userSpeedKmh: userSpeedKmh,
      countryCode: countryCode,
      language: language,
      avoidLocations: avoidLocations,
    );
  }

  Map<String, dynamic> _buildValhallaRequestPayload({
    required LatLng origin,
    required LatLng destination,
    LatLng? waypoint,
    required String vehicleType,
    required double userSpeedKmh,
    required String countryCode,
    required String language,
    List<LatLng> avoidLocations = const [],
  }) {
    final profile = CountryVehicleRules.getProfile(countryCode, vehicleType);
    final maxLegalSpeedKmh = CountryVehicleRules.maxLegalSpeedFor(
      countryCode,
      vehicleType,
    );
    final isSlowVehicle = maxLegalSpeedKmh <= 45;
    final useCyclewayRouting =
        (vehicleType == 'Moped class II' ||
            vehicleType == 'Electric scooter') &&
        profile.prefersCycleways;
    final costing = useCyclewayRouting
        ? 'bicycle'
        : (isSlowVehicle ? 'motor_scooter' : 'auto');
    final hasVehicleSpeedLimit = CountryVehicleRules.hasVehicleSpeedLimit(
      vehicleType,
    );
    final costingOptions = useCyclewayRouting
        ? <String, dynamic>{
            // Sweden and Denmark require a two-wheel low-speed moped to use
            // cycleways by default. Bicycle costing is the Valhalla profile
            // that can traverse that network; local signs still take priority.
            'bicycle_type': 'Hybrid',
            'cycling_speed': userSpeedKmh.clamp(5.0, maxLegalSpeedKmh).round(),
            'use_roads': profile.useRoads,
            'use_hills': 0.5,
            'use_ferry': profile.useFerry,
            'avoid_bad_surfaces': 1.0,
            'shortest': true,
            'ignore_access': false,
          }
        : <String, dynamic>{
            // Clamp top_speed to the vehicle's legal maximum so Valhalla never
            // optimises for a speed the vehicle cannot legally achieve on any road.
            if (hasVehicleSpeedLimit)
              'top_speed': userSpeedKmh.clamp(1.0, maxLegalSpeedKmh).round(),
            'use_highways': profile.useHighways,
            'use_tolls': profile.useTolls,
            'use_ferry': profile.useFerry,
            // For slow vehicles, shortest tends to avoid long detours over larger
            // fast roads and keeps routing on local road networks.
            'shortest': isSlowVehicle,
          };
    if (isSlowVehicle && !useCyclewayRouting) {
      costingOptions['use_primary'] = profile.usePrimary;
      costingOptions['disable_hierarchy_pruning'] = true;
      // Respect OSM access tags for moped/mofa/motor_scooter. This is
      // especially important for cycleways and locally restricted roads.
      costingOptions['ignore_access'] = false;
    }
    if (!useCyclewayRouting &&
        (vehicleType == 'Low vehicle' || profile.excludeUnpaved)) {
      // A low vehicle follows the A-tractor speed profile, but must also stay
      // away from tracks and roads tagged as unpaved whenever the map data
      // makes that possible.
      costingOptions['use_tracks'] = vehicleType == 'Low vehicle'
          ? 0.0
          : profile.useTracks;
      costingOptions['exclude_unpaved'] = true;
    }

    // Never exclude the road the driver starts on or the road containing the
    // destination/waypoint. A reported bump at either end must not make the
    // whole route impossible to calculate.
    const distance = Distance();
    const endpointSafetyRadiusMeters = 120.0;
    final safeAvoidLocations = avoidLocations
        .where((location) {
          if (distance(origin, location) < endpointSafetyRadiusMeters ||
              distance(destination, location) < endpointSafetyRadiusMeters) {
            return false;
          }
          return waypoint == null ||
              distance(waypoint, location) >= endpointSafetyRadiusMeters;
        })
        .toList(growable: false);

    return <String, dynamic>{
      'locations': [
        {'lat': origin.latitude, 'lon': origin.longitude},
        if (waypoint != null)
          {'lat': waypoint.latitude, 'lon': waypoint.longitude},
        {'lat': destination.latitude, 'lon': destination.longitude},
      ],
      'costing': costing,
      'costing_options': {costing: costingOptions},
      'directions_options': {'units': 'kilometers', 'language': language},
      // Request shape as decoded coordinates for easier parsing
      'shape_format': 'polyline6',
      if (safeAvoidLocations.isNotEmpty)
        'exclude_locations': [
          for (final location in safeAvoidLocations)
            {'lat': location.latitude, 'lon': location.longitude},
        ],
    };
  }

  @visibleForTesting
  List<String> debugEligibleProviders({
    required String configuredProvider,
    required String vehicleType,
    required String countryCode,
  }) {
    return _eligibleProvidersFor(
      configuredProvider: configuredProvider,
      vehicleType: vehicleType,
      countryCode: countryCode,
    );
  }

  List<String> _eligibleProvidersFor({
    required String configuredProvider,
    required String vehicleType,
    required String countryCode,
  }) {
    // The other configured providers use car profiles and cannot correctly
    // represent mandatory cycleway routing for class-II mopeds or electric
    // scooters. Valhalla can switch costing per vehicle and country.
    if (vehicleType == 'Moped class II' || vehicleType == 'Electric scooter') {
      return const [_providerValhalla];
    }
    final profile = CountryVehicleRules.getProfile(countryCode, vehicleType);
    final maxLegalSpeed = CountryVehicleRules.maxLegalSpeedFor(
      countryCode,
      vehicleType,
    );

    final providers = <String>[configuredProvider];
    for (final provider in _fallbackChain) {
      if (!providers.contains(provider)) providers.add(provider);
    }

    final requiresStrictAvoids =
        profile.useHighways < 0.3 ||
        profile.useFerry < 0.3 ||
        profile.useTolls < 0.3;
    final isSlowVehicle = maxLegalSpeed <= 45;
    final mustUseStrictLegalRouting = requiresStrictAvoids || isSlowVehicle;

    if (mustUseStrictLegalRouting) {
      final strictProviders = providers
          .where(
            (provider) =>
                provider != _providerOsrmPublic &&
                provider != _providerOsrmSelfHosted,
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
  }

  @visibleForTesting
  Uri debugBuildGraphHopperUri({
    required LatLng origin,
    required LatLng destination,
    LatLng? waypoint,
    required String vehicleType,
    required String countryCode,
    String apiKey = 'test-key',
    String locale = 'sv',
  }) {
    return _buildGraphHopperUri(
      origin: origin,
      destination: destination,
      waypoint: waypoint,
      vehicleType: vehicleType,
      countryCode: countryCode,
      apiKey: apiKey,
      locale: locale,
    );
  }

  Uri _buildGraphHopperUri({
    required LatLng origin,
    required LatLng destination,
    LatLng? waypoint,
    required String vehicleType,
    required String countryCode,
    required String apiKey,
    required String locale,
  }) {
    final avoidFeatures = _graphHopperAvoidFor(vehicleType, countryCode);
    final buffer = StringBuffer(
      '${BackendConfig.graphhopperBaseUrl}/route?key=$apiKey'
      '&profile=car&points_encoded=false&instructions=true&locale=$locale',
    );
    buffer.write(
      '&point=${origin.latitude},${origin.longitude}'
      '${waypoint == null ? '' : '&point=${waypoint.latitude},${waypoint.longitude}'}'
      '&point=${destination.latitude},${destination.longitude}',
    );
    if (avoidFeatures.isNotEmpty) {
      buffer.write('&avoid=${avoidFeatures.join(',')}');
    }
    return Uri.parse(buffer.toString());
  }

  @visibleForTesting
  Map<String, dynamic> debugBuildOpenRouteServiceRequestPayload({
    required LatLng origin,
    required LatLng destination,
    required String vehicleType,
    required String countryCode,
  }) {
    return _buildOpenRouteServiceRequestPayload(
      origin: origin,
      destination: destination,
      vehicleType: vehicleType,
      countryCode: countryCode,
    );
  }

  Map<String, dynamic> _buildOpenRouteServiceRequestPayload({
    required LatLng origin,
    required LatLng destination,
    LatLng? waypoint,
    required String vehicleType,
    required String countryCode,
  }) {
    final constraints = _routingConstraintsFor(vehicleType, countryCode);
    return <String, dynamic>{
      'coordinates': [
        [origin.longitude, origin.latitude],
        if (waypoint != null) [waypoint.longitude, waypoint.latitude],
        [destination.longitude, destination.latitude],
      ],
      'options': {'avoid_features': constraints.openRouteServiceAvoidFeatures},
    };
  }

  Future<RouteResult> getRoute({
    required LatLng origin,
    required LatLng destination,
    LatLng? waypoint,
    required String vehicleType,
    bool relaxedLegalChecks = false,
    List<LatLng> avoidLocations = const [],
  }) async {
    final userSpeed = UserPreferencesService.instance.maxSpeedKmh.value;
    final country = UserPreferencesService.instance.countryCode.value;
    // The UI can request a last-resort relaxed route for legacy slow vehicle
    // profiles. A class I moped must never bypass its country-specific road
    // restrictions, even when no legal route can be found.
    final effectiveRelaxedLegalChecks =
        relaxedLegalChecks &&
        vehicleType != 'Moped class I' &&
        vehicleType != 'Moped class II' &&
        vehicleType != 'Electric scooter';
    final eligibleProviders = _eligibleProvidersFor(
      configuredProvider: BackendConfig.routingProvider,
      vehicleType: vehicleType,
      countryCode: country,
    );
    final mustUseStrictLegalRouting =
        !eligibleProviders.contains(_providerOsrmPublic) &&
        !eligibleProviders.contains(_providerOsrmSelfHosted);

    Object? lastError;
    for (final provider in eligibleProviders) {
      try {
        final route = await _routeWith(
          provider: provider,
          origin: origin,
          destination: destination,
          waypoint: waypoint,
          vehicleType: vehicleType,
          userSpeedKmh: userSpeed,
          countryCode: country,
          relaxedLegalChecks: effectiveRelaxedLegalChecks,
          avoidLocations: avoidLocations,
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
    LatLng? waypoint,
    required String vehicleType,
    required double userSpeedKmh,
    required String countryCode,
    required bool relaxedLegalChecks,
    required List<LatLng> avoidLocations,
  }) async {
    if (provider == _providerValhalla) {
      return _getRouteFromValhalla(
        origin: origin,
        destination: destination,
        waypoint: waypoint,
        vehicleType: vehicleType,
        userSpeedKmh: userSpeedKmh,
        countryCode: countryCode,
        relaxedLegalChecks: relaxedLegalChecks,
        avoidLocations: avoidLocations,
      );
    } else if (provider == _providerGraphHopper) {
      final route = await _getRouteFromGraphHopper(
        origin: origin,
        destination: destination,
        waypoint: waypoint,
        vehicleType: vehicleType,
        userSpeedKmh: userSpeedKmh,
        countryCode: countryCode,
      );
      if (!relaxedLegalChecks) {
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
        await _assertNoForbiddenRoadClassForSlowVehicle(
          route: route,
          vehicleType: vehicleType,
          countryCode: countryCode,
        );
      }
      return route;
    } else if (provider == _providerOpenRouteService) {
      final route = await _getRouteFromOpenRouteService(
        origin: origin,
        destination: destination,
        waypoint: waypoint,
        vehicleType: vehicleType,
        userSpeedKmh: userSpeedKmh,
        countryCode: countryCode,
      );
      if (!relaxedLegalChecks) {
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
        await _assertNoForbiddenRoadClassForSlowVehicle(
          route: route,
          vehicleType: vehicleType,
          countryCode: countryCode,
        );
      }
      return route;
    } else if (provider == _providerOsrmSelfHosted ||
        provider == _providerOsrmPublic) {
      return _getRouteFromOsrm(
        origin: origin,
        destination: destination,
        waypoint: waypoint,
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
    LatLng? waypoint,
    required String vehicleType,
    required double userSpeedKmh,
    required String countryCode,
  }) async {
    final apiKey = BackendConfig.graphhopperApiKey;
    if (apiKey.isEmpty) {
      throw const RoutingException(RoutingErrorCode.missingApiKey);
    }

    final vehicleMaxSpeedKmh = userSpeedKmh;

    final locale = _graphHopperLocale();
    final url = _buildGraphHopperUri(
      origin: origin,
      destination: destination,
      waypoint: waypoint,
      vehicleType: vehicleType,
      countryCode: countryCode,
      apiKey: apiKey,
      locale: locale,
    );

    final response = await http.get(
      url,
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
    final providerDurationSeconds =
        ((firstPath['time'] as num?)?.toDouble() ?? 0) / 1000;
    final calculatedDurationSeconds =
        !CountryVehicleRules.hasVehicleSpeedLimit(vehicleType) &&
            providerDurationSeconds > 0
        ? providerDurationSeconds
        : (avgSpeedMs > 0 ? distanceMeters / avgSpeedMs : 0.0);

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
    LatLng? waypoint,
    required String vehicleType,
    required double userSpeedKmh,
    required String countryCode,
  }) async {
    // OSRM public API does not support exclude parameters —
    // use bare routing without exclude flags.
    final url = Uri.parse(
      '${BackendConfig.osrmBaseUrl}/route/v1/driving/'
      '${origin.longitude},${origin.latitude};'
      '${waypoint == null ? '' : '${waypoint.longitude},${waypoint.latitude};'}'
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
    final maxLegalSpeedKmh = CountryVehicleRules.maxLegalSpeedFor(
      countryCode,
      vehicleType,
    );
    final vehicleMaxSpeedKmh = userSpeedKmh.clamp(1.0, maxLegalSpeedKmh);
    // Use 85% of max speed as realistic average (traffic lights, bends, etc.)
    final avgSpeedMs = (vehicleMaxSpeedKmh * 0.85) / 3.6;
    final providerDurationSeconds =
        (firstRoute['duration'] as num?)?.toDouble() ?? 0;
    final calculatedDurationSeconds =
        !CountryVehicleRules.hasVehicleSpeedLimit(vehicleType) &&
            providerDurationSeconds > 0
        ? providerDurationSeconds
        : (avgSpeedMs > 0 ? distanceMeters / avgSpeedMs : 0.0);

    return RouteResult(
      points: points,
      distanceMeters: distanceMeters,
      durationSeconds: calculatedDurationSeconds,
    );
  }

  Future<RouteResult> _getRouteFromOpenRouteService({
    required LatLng origin,
    required LatLng destination,
    LatLng? waypoint,
    required String vehicleType,
    required double userSpeedKmh,
    required String countryCode,
  }) async {
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
      body: jsonEncode(
        _buildOpenRouteServiceRequestPayload(
          origin: origin,
          destination: destination,
          waypoint: waypoint,
          vehicleType: vehicleType,
          countryCode: countryCode,
        ),
      ),
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

    final distanceMeters = (summary?['distance'] as num?)?.toDouble() ?? 0;
    final avgSpeedMs = (userSpeedKmh * 0.85) / 3.6;
    final providerDurationSeconds =
        (summary?['duration'] as num?)?.toDouble() ?? 0;
    final calculatedDurationSeconds =
        !CountryVehicleRules.hasVehicleSpeedLimit(vehicleType) &&
            providerDurationSeconds > 0
        ? providerDurationSeconds
        : (avgSpeedMs > 0 ? distanceMeters / avgSpeedMs : 0.0);

    return RouteResult(
      points: points,
      distanceMeters: distanceMeters,
      durationSeconds: calculatedDurationSeconds,
    );
  }

  /// Valhalla self-hosted routing with custom vehicle profiles for slow vehicles.
  /// Supports A-tractor (30 km/h), Moped car (45 km/h), and Tractor (30 km/h)
  /// with proper road restrictions (no motorways, no ferries for most).
  Future<RouteResult> _getRouteFromValhalla({
    required LatLng origin,
    required LatLng destination,
    LatLng? waypoint,
    required String vehicleType,
    required double userSpeedKmh,
    required String countryCode,
    required bool relaxedLegalChecks,
    required List<LatLng> avoidLocations,
  }) async {
    final maxLegalSpeedKmh = CountryVehicleRules.maxLegalSpeedFor(
      countryCode,
      vehicleType,
    );
    final isSlowVehicle = maxLegalSpeedKmh <= 45;
    final vehicleMaxSpeedKmh = userSpeedKmh.clamp(1.0, maxLegalSpeedKmh);

    // For slow vehicles we hard-enforce road class: motorway everywhere and
    // trunk/motortrafikled in the Nordics are illegal. Valhalla's use_highways
    // penalty is only a preference, so it can still route via a trunk road
    // (e.g. väg 73/Nynäsvägen). When that happens we exclude the offending
    // segments and re-route until the path is legal.
    final enforceRoadClass = isSlowVehicle && !relaxedLegalChecks;
    final studdedPolygons =
        UserPreferencesService.instance.hasStuddedTires.value
        ? StuddedTireZones.toValhallaExcludePolygons()
        : const <dynamic>[];

    var exclusions = List<LatLng>.from(avoidLocations);
    final maxAttempts = enforceRoadClass ? 3 : 1;
    // A route that only touches a (soft) motor road — OSM `trunk`, which may be
    // an ordinary legal national road — kept as a graceful fallback when no
    // fully motor-road-free route can be found. Motorways stay a hard ban.
    RouteResult? motorRoadOnlyFallback;

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      RouteResult route;
      try {
        final requestPayload = _buildValhallaRequestPayload(
          origin: origin,
          destination: destination,
          waypoint: waypoint,
          vehicleType: vehicleType,
          userSpeedKmh: userSpeedKmh,
          countryCode: countryCode,
          language: _valhallaLanguage(),
          avoidLocations: exclusions,
        );
        if (studdedPolygons.isNotEmpty) {
          requestPayload['exclude_polygons'] = studdedPolygons;
        }

        final body = await _postValhallaRoute(requestPayload);
        final trip = body['trip'] as Map<String, dynamic>?;
        if (trip == null) {
          throw const RoutingException(RoutingErrorCode.noRouteFound);
        }
        route = _parseValhallaTrip(
          trip,
          vehicleType: vehicleType,
          countryCode: countryCode,
          relaxedLegalChecks: relaxedLegalChecks,
          vehicleMaxSpeedKmh: vehicleMaxSpeedKmh,
          isSlowVehicle: isSlowVehicle,
        );
      } catch (_) {
        // The first attempt's failure is a real provider/legality error —
        // surface it. Later attempts only fail because our exclusions made
        // routing impossible; fall back to the best route found so far.
        if (attempt == 0) rethrow;
        break;
      }

      if (!enforceRoadClass) return route;

      final forbidden = await _forbiddenRoadClassPoints(
        routePoints: route.points,
        vehicleType: vehicleType,
        countryCode: countryCode,
      );
      // Fully legal — no motorway and no forbidden motor road.
      if (forbidden.motorway.isEmpty && forbidden.motorRoad.isEmpty) {
        return route;
      }
      // No motorway, only a (soft) motor road: remember it in case we can't do
      // better, then keep trying to route around the motor road.
      if (forbidden.motorway.isEmpty) {
        motorRoadOnlyFallback ??= route;
      }
      exclusions = [
        ...exclusions,
        ...forbidden.motorway,
        ...forbidden.motorRoad,
      ];
    }

    // Couldn't find a fully motor-road-free route. Prefer a route that at least
    // avoids motorways (the trunk it uses may well be a legal ordinary road we
    // can't distinguish) over failing outright.
    if (motorRoadOnlyFallback != null) return motorRoadOnlyFallback;

    // Only a motorway route remained — that is unambiguously illegal.
    throw const RoutingException(RoutingErrorCode.routeNotAllowedForVehicle);
  }

  /// POSTs a Valhalla route request and returns the decoded JSON body.
  /// Retries once on timeout before surfacing a provider-unavailable error.
  Future<Map<String, dynamic>> _postValhallaRoute(
    Map<String, dynamic> requestPayload,
  ) => _postValhalla('/route', requestPayload);

  /// POSTs to a Valhalla endpoint (`/route`, `/trace_attributes`, …) and
  /// returns the decoded JSON body. Retries once on timeout.
  Future<Map<String, dynamic>> _postValhalla(
    String path,
    Map<String, dynamic> requestPayload,
  ) async {
    final baseUrl = BackendConfig.valhallaBaseUrl;
    final requestBody = jsonEncode(requestPayload);
    final url = Uri.parse('$baseUrl$path');
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

    if (response == null || response.statusCode != 200) {
      throw const RoutingException(RoutingErrorCode.providerUnavailable);
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Returns the posted speed limit for every point in an already calculated
  /// route. Valhalla supplies the value per matched road edge, avoiding a
  /// separate public map lookup every few seconds while driving.
  Future<List<double?>> getRouteSpeedLimits({
    required List<LatLng> routePoints,
    required String vehicleType,
    required String countryCode,
  }) async {
    if (routePoints.length < 2) return const [];
    final profile = CountryVehicleRules.getProfile(countryCode, vehicleType);
    final costing = profile.prefersCycleways
        ? 'bicycle'
        : CountryVehicleRules.maxLegalSpeedFor(countryCode, vehicleType) <= 45
        ? 'motor_scooter'
        : 'auto';
    final payload = <String, dynamic>{
      'shape': [
        for (final point in routePoints)
          {'lat': point.latitude, 'lon': point.longitude},
      ],
      'shape_match': 'edge_walk',
      'costing': costing,
      'directions_options': {'units': 'kilometers'},
      'filters': {
        'attributes': [
          'edge.speed_limit',
          'edge.begin_shape_index',
          'edge.end_shape_index',
        ],
        'action': 'include',
      },
    };

    try {
      final body = await _postValhalla('/trace_attributes', payload);
      return _parseRouteSpeedLimits(
        body['edges'] as List<dynamic>? ?? const [],
        routePoints.length,
      );
    } catch (_) {
      // Live OSM lookup remains available to the map as a fallback.
      return List<double?>.filled(routePoints.length, null);
    }
  }

  List<double?> _parseRouteSpeedLimits(List<dynamic> edges, int pointCount) {
    final limits = List<double?>.filled(pointCount, null);
    if (pointCount == 0) return limits;
    for (final raw in edges.whereType<Map<String, dynamic>>()) {
      final rawLimit = raw['speed_limit'];
      final limit = rawLimit is num
          ? rawLimit.toDouble()
          : double.tryParse(rawLimit?.toString() ?? '');
      // Valhalla uses 0/255 for absent or unlimited data. Neither is a road
      // sign that should be shown to the driver.
      if (limit == null || limit < 5 || limit > 200) continue;
      final begin = (raw['begin_shape_index'] as num?)?.toInt();
      final end = (raw['end_shape_index'] as num?)?.toInt();
      if (begin == null || end == null) continue;
      final safeBegin = begin.clamp(0, pointCount - 1);
      final safeEnd = end.clamp(safeBegin, pointCount - 1);
      for (var index = safeBegin; index <= safeEnd; index++) {
        limits[index] = limit;
      }
    }
    return limits;
  }

  @visibleForTesting
  List<double?> debugParseRouteSpeedLimits(
    List<Map<String, dynamic>> edges,
    int pointCount,
  ) => _parseRouteSpeedLimits(edges, pointCount);

  /// Whether the country/vehicle profile forbids the local motorway-like motor
  /// road class (OSM `trunk`: motortrafikled/voie express/superstrada/…).
  /// Driven by the per-country profile so the rule follows each country's law
  /// (e.g. Spanish N-roads and UK A-roads are legal `trunk` and return false).
  /// Treated as a soft preference by callers because OSM `trunk` also covers
  /// ordinary legal national roads.
  bool _trunkForbiddenForSlowVehicle(String vehicleType, String countryCode) {
    return CountryVehicleRules.getProfile(
      countryCode,
      vehicleType,
    ).forbidsMotorRoads;
  }

  /// Reads the road class of every edge on [routePoints] via Valhalla
  /// `trace_attributes` and splits the forbidden ones into two groups:
  ///  - `motorway`: illegal for every slow vehicle in every country (hard ban).
  ///  - `motorRoad`: the local motorway-like class (OSM `trunk`) where the
  ///    country/vehicle profile forbids motor roads. This is a *soft* signal:
  ///    OSM `trunk` covers both genuine motor roads (motortrafikled/voie
  ///    express) AND ordinary legal national roads (e.g. Swedish väg 45, most
  ///    Norwegian E-roads), and the accurate `motorroad` tag is frequently
  ///    missing — so callers should only *prefer* to avoid these, not fail.
  /// Valhalla only tags maneuvers with `highway:true` for motorway class, so
  /// trunk motor-roads (e.g. väg 73/Nynäsvägen) are invisible to the maneuver
  /// and keyword guards — this closes that gap. Returns empty lists when the
  /// route is legal or the trace can't be performed.
  Future<({List<LatLng> motorway, List<LatLng> motorRoad})>
  _forbiddenRoadClassPoints({
    required List<LatLng> routePoints,
    required String vehicleType,
    required String countryCode,
  }) async {
    const empty = (motorway: <LatLng>[], motorRoad: <LatLng>[]);
    final maxLegalSpeed = CountryVehicleRules.maxLegalSpeedFor(
      countryCode,
      vehicleType,
    );
    if (maxLegalSpeed > 45) return empty;
    // Cycleway vehicles route on the bicycle network via access tags; the
    // motor-road class ban does not apply to them.
    if (vehicleType == 'Moped class II' || vehicleType == 'Electric scooter') {
      return empty;
    }
    if (routePoints.length < 2) return empty;

    final forbidMotorRoad = _trunkForbiddenForSlowVehicle(
      vehicleType,
      countryCode,
    );
    final payload = <String, dynamic>{
      'shape': [
        for (final p in routePoints) {'lat': p.latitude, 'lon': p.longitude},
      ],
      'shape_match': 'edge_walk',
      'costing': 'motor_scooter',
      'directions_options': {'units': 'kilometers'},
      'filters': {
        'attributes': [
          'edge.road_class',
          'edge.begin_shape_index',
          'edge.end_shape_index',
        ],
        'action': 'include',
      },
    };

    Map<String, dynamic> body;
    try {
      body = await _postValhalla('/trace_attributes', payload);
    } catch (_) {
      return empty; // Trace unavailable — don't block routing on it.
    }

    final edges = body['edges'] as List<dynamic>? ?? const [];
    final motorway = <LatLng>[];
    final motorRoad = <LatLng>[];
    for (final raw in edges) {
      final edge = raw as Map<String, dynamic>;
      final roadClass = edge['road_class'] as String?;
      final isMotorway = roadClass == 'motorway';
      final isMotorRoad = forbidMotorRoad && roadClass == 'trunk';
      if (!isMotorway && !isMotorRoad) continue;
      final begin = (edge['begin_shape_index'] as num?)?.toInt();
      final end = (edge['end_shape_index'] as num?)?.toInt();
      if (begin == null || end == null) continue;
      final mid = ((begin + end) ~/ 2).clamp(0, routePoints.length - 1);
      (isMotorway ? motorway : motorRoad).add(routePoints[mid]);
    }
    return (motorway: motorway, motorRoad: motorRoad);
  }

  /// Parses a single Valhalla `trip` object into a [RouteResult].
  /// Applies the same slow-vehicle legal checks as the primary route: throws
  /// [RoutingException] when the trip uses a motorway and checks aren't relaxed.
  RouteResult _parseValhallaTrip(
    Map<String, dynamic> trip, {
    required String vehicleType,
    required String countryCode,
    required bool relaxedLegalChecks,
    required double vehicleMaxSpeedKmh,
    required bool isSlowVehicle,
  }) {
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
        if (isOnHighway && !relaxedLegalChecks) {
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
    if (isSlowVehicle &&
        !relaxedLegalChecks &&
        (summary?['has_highway'] as bool? ?? false)) {
      throw const RoutingException(RoutingErrorCode.routeNotAllowedForVehicle);
    }
    final distanceKm = (summary?['length'] as num?)?.toDouble() ?? 0;
    final distanceMeters = distanceKm * 1000;

    // Speed-limited vehicles use a consistent estimate based on their selected
    // maximum. Ordinary cars keep Valhalla's road-aware travel time.
    final avgSpeedMs = (vehicleMaxSpeedKmh * 0.85) / 3.6;
    final providerDurationSeconds = (summary?['time'] as num?)?.toDouble() ?? 0;
    final calculatedDurationSeconds =
        !CountryVehicleRules.hasVehicleSpeedLimit(vehicleType) &&
            providerDurationSeconds > 0
        ? providerDurationSeconds
        : (avgSpeedMs > 0 ? distanceMeters / avgSpeedMs : 0.0);

    final result = RouteResult(
      points: allPoints,
      distanceMeters: distanceMeters,
      durationSeconds: calculatedDurationSeconds,
      instructions: allInstructions,
    );
    if (!relaxedLegalChecks) {
      _assertNoMotorwayForSlowVehicle(
        route: result,
        vehicleType: vehicleType,
        countryCode: countryCode,
      );
    }
    return result;
  }

  /// Generates Waze-style alternative routes by re-routing while excluding a
  /// point on the [primaryRoute], which forces Valhalla onto a structurally
  /// different path. Valhalla's built-in `alternates` returns nothing on most
  /// servers, so we derive distinct alternatives ourselves. Each candidate is
  /// re-validated by [_parseValhallaTrip], so routes that violate slow-vehicle
  /// legal checks (e.g. use a motorway) are dropped. Returns an empty list when
  /// Valhalla isn't the active provider — callers fall back to the single
  /// route from [getRoute].
  Future<List<RouteResult>> getValhallaAlternatives({
    required LatLng origin,
    required LatLng destination,
    LatLng? waypoint,
    required String vehicleType,
    required RouteResult primaryRoute,
    int maxAlternatives = 2,
    List<LatLng> avoidLocations = const [],
  }) async {
    if (BackendConfig.routingProvider != _providerValhalla) {
      return const [];
    }
    final userSpeed = UserPreferencesService.instance.maxSpeedKmh.value;
    final country = UserPreferencesService.instance.countryCode.value;
    final maxLegalSpeedKmh = CountryVehicleRules.maxLegalSpeedFor(
      country,
      vehicleType,
    );
    final isSlowVehicle = maxLegalSpeedKmh <= 45;

    final basePayload = _buildValhallaRequestPayload(
      origin: origin,
      destination: destination,
      waypoint: waypoint,
      vehicleType: vehicleType,
      userSpeedKmh: userSpeed,
      countryCode: country,
      language: _valhallaLanguage(),
      avoidLocations: avoidLocations,
    );
    if (UserPreferencesService.instance.hasStuddedTires.value) {
      final excludePolygons = StuddedTireZones.toValhallaExcludePolygons();
      if (excludePolygons.isNotEmpty) {
        basePayload['exclude_polygons'] = excludePolygons;
      }
    }

    // Always derive exclusion points from a fresh Valhalla route for the same
    // origin/destination. If the displayed primary route came from a fallback
    // provider, reusing its geometry here can place exclude_locations on the
    // wrong edges and collapse alternatives back to a single option.
    var primaryPoints = primaryRoute.points;
    try {
      final primaryBody = await _postValhallaRoute(basePayload);
      final primaryTrip = primaryBody['trip'] as Map<String, dynamic>?;
      final primaryLegs = primaryTrip?['legs'] as List<dynamic>?;
      final primaryShape = primaryLegs != null && primaryLegs.isNotEmpty
          ? (primaryLegs.first as Map<String, dynamic>)['shape'] as String?
          : null;
      if (primaryShape != null && primaryShape.isNotEmpty) {
        primaryPoints = _decodePolyline6(primaryShape);
      }
    } catch (_) {
      // Fall back to the provided primary route geometry if the direct
      // Valhalla probe fails for any reason.
    }
    if (primaryPoints.length < 4) return const [];

    // Spread the excluded points along the primary route. Excluding a
    // mid-route point forces Valhalla to find a different path around it.
    final fractions = maxAlternatives <= 1
        ? const <double>[0.5]
        : const <double>[0.3, 0.5, 0.7];

    final results = <RouteResult>[];
    for (final fraction in fractions) {
      final idx = (primaryPoints.length * fraction).round().clamp(
        1,
        primaryPoints.length - 2,
      );
      // Exclude a short window of points (not just one) so Valhalla can't skirt
      // a single edge and rejoin the same road — forces a real detour.
      final excludeIdx = <int>{
        (idx - 2).clamp(1, primaryPoints.length - 2),
        idx,
        (idx + 2).clamp(1, primaryPoints.length - 2),
      };
      basePayload['exclude_locations'] = [
        for (final location in avoidLocations)
          {'lat': location.latitude, 'lon': location.longitude},
        for (final i in excludeIdx)
          {'lat': primaryPoints[i].latitude, 'lon': primaryPoints[i].longitude},
      ];

      Map<String, dynamic> body;
      try {
        body = await _postValhallaRoute(basePayload);
      } catch (_) {
        continue;
      }
      final trip = body['trip'] as Map<String, dynamic>?;
      if (trip == null) continue;
      try {
        final alt = _parseValhallaTrip(
          trip,
          vehicleType: vehicleType,
          countryCode: country,
          // An alternative must pass the same legal checks as the primary
          // route. Never trade legality for an extra route choice.
          relaxedLegalChecks: false,
          vehicleMaxSpeedKmh: userSpeed,
          isSlowVehicle: isSlowVehicle,
        );
        if (isSlowVehicle) {
          final forbidden = await _forbiddenRoadClassPoints(
            routePoints: alt.points,
            vehicleType: vehicleType,
            countryCode: country,
          );
          // Alternatives are extra choices — keep them strictly clean and drop
          // any that use a motorway or a forbidden motor road.
          if (forbidden.motorway.isNotEmpty || forbidden.motorRoad.isNotEmpty) {
            continue;
          }
        }
        results.add(alt);
      } on RoutingException {
        // Skip illegal/invalid alternate — never surface restricted roads.
      }
    }
    return results;
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
  if (!CountryVehicleRules.hasVehicleSpeedLimit(vehicleType)) {
    return double.infinity;
  }
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
