import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:slowride/l10n/app_localizations.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:slowride/core/constants/backend_config.dart';
import 'package:slowride/services/navigation_request_service.dart';
import 'package:slowride/services/routing_service.dart';
import 'package:slowride/services/slow_road_service.dart';
import 'package:slowride/services/speed_calibration_service.dart';
import 'package:slowride/services/user_preferences_service.dart';
import 'package:slowride/services/favorite_places_service.dart';
import 'package:slowride/models/country_vehicle_rules.dart';
import 'package:slowride/features/alerts/alerts_controller.dart';
import 'package:slowride/models/alert_model.dart';
import 'package:slowride/models/studded_tire_zones.dart';
import 'package:slowride/services/charging_station_service.dart';
import 'package:slowride/widgets/map_widget.dart';
import 'package:slowride/features/paywall/paywall_screen.dart';
import 'package:slowride/services/subscription_service.dart';
import 'package:slowride/services/tts_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final RoutingService _routingService = RoutingService();
  final TextEditingController _addressController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  Timer? _debounce;
  List<Map<String, dynamic>> _suggestions = [];
  bool _showSuggestions = false;

  StreamSubscription<Position>? _positionSubscription;
  double _speedKmh = 0;
  LatLng? _currentLocation;

  // Notifiers that feed MapWidget directly — updating them does NOT cause
  // the whole screen to rebuild (unlike setState).
  final ValueNotifier<LatLng?> _locationNotifier = ValueNotifier(null);
  final ValueNotifier<double> _headingNotifier = ValueNotifier(0);

  // Tracks progress along route so nearest-point scan is O(1) not O(n).
  int _lastNearestIdx = 0;
  int _displayNearestIdx = 0;
  String _routingStatus = '';
  bool _isRouting = false;
  bool _isNavigating = false;
  // true = camera locked on user (like Waze follow mode)
  bool _isFollowing = false;
  bool _use3DMap = true;
  bool _useDarkMap = true;
  LatLng? _destination;
  String _destinationLabel = '';
  LatLng? _routeStop;
  String _routeStopLabel = '';
  List<LatLng> _routePoints = const [];
  bool _isSearchingRouteStops = false;

  // ── Turn-by-turn instructions ─────────────────────────────────────
  List<RouteInstruction> _instructions = const [];
  int _nextManeuverSign = 0;
  String _nextManeuverText = '';
  double _distToNextManeuver = 0;
  String _lastSpokenManeuver = '';
  bool _spokenEarlyWarning = false;
  String _currentStreetName = '';

  // ── Speed calibration + live ETA ──────────────────────────────────
  // Cumulative distance from route start to each point (metres).
  List<double> _cumulativeDist = const [];
  double _totalRouteDistM = 0;
  // Per-trip tracking: accumulated while _isNavigating is true.
  DateTime? _tripStartTime;
  LatLng? _lastNavPos;
  double _tripDistanceM = 0;
  double _etaSmoothedSpeedKmh = 0;
  DateTime? _etaLastMovementAt;
  static const Duration _etaPauseGrace = Duration(seconds: 25);

  // ── Community alerts ──────────────────────────────────────────
  final AlertsController _alertsController = AlertsController();
  List<AlertModel> _alerts = const [];
  Timer? _alertsTimer;
  // EV charging stations (fetched when isElectric is on).
  List<LatLng> _chargingStations = const [];
  // Nearest alert within 400 m while navigating (for proximity warning).
  AlertModel? _nearbyAlert;
  double? _roadSpeedLimitKmh;
  LatLng? _lastRoadLimitLookupPos;
  DateTime _lastRoadLimitLookupAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _roadLimitLookupInFlight = false;
  static const Duration _roadLimitLookupInterval = Duration(seconds: 10);
  static const double _roadLimitLookupMinMoveMeters = 55;

  // ── GPS simulation (test-only, visible in debug builds) ──────────────
  bool _isSimulating = false;
  Timer? _simTimer;
  int _simPtIdx = 0;
  double _simSegOffsetM = 0;
  static const double _simSpeedKmh = 50.0;
  static const Duration _simInterval = Duration(milliseconds: 200);

  bool _countryAutoDetected = false;
  bool _localizedDefaultsSet = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_localizedDefaultsSet) {
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    _routingStatus = l10n.mapTapToSelectDestination;
    _localizedDefaultsSet = true;
  }

  @override
  void initState() {
    super.initState();
    // Delay until after first frame so AppLocalizations/context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startLocationTracking();
    });
    NavigationRequestService.instance.pendingDestination.addListener(
      _onExternalNavigationRequest,
    );
    _use3DMap = UserPreferencesService.instance.use3DMap.value;
    // Lazy-load prefs for speed calibration (fire-and-forget).
    SpeedCalibrationService.instance.initialize();
    FavoritePlacesService.instance.initialize();
    // Start community alerts polling (immediate + every 30 s).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadAlerts();
    });
    _alertsTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _loadAlerts();
      if (mounted) _loadChargingStations();
    });
  }

  void _onExternalNavigationRequest() {
    final dest = NavigationRequestService.instance.pendingDestination.value;
    if (dest != null) {
      NavigationRequestService.instance.consume();
      _handleMapTap(dest);
    }
  }

  Future<void> _loadAlerts() async {
    final center = _currentLocation ?? const LatLng(59.3293, 18.0686);
    try {
      final result = await _alertsController.fetchNearby(center);
      if (!mounted) return;
      setState(() => _alerts = result);
    } catch (_) {}
  }

  Future<void> _loadChargingStations() async {
    if (!UserPreferencesService.instance.isElectric.value) {
      if (_chargingStations.isNotEmpty) {
        setState(() => _chargingStations = const []);
      }
      return;
    }
    final center = _currentLocation ?? const LatLng(59.3293, 18.0686);
    try {
      final stations = await ChargingStationService.instance.fetchNearby(
        center,
      );
      if (!mounted) return;
      setState(() {
        _chargingStations = stations.map((s) => s.position).toList();
      });
    } catch (_) {}
  }

  Future<void> _maybeRefreshRoadSpeedLimit(LatLng pos) async {
    if (_roadLimitLookupInFlight) return;

    final now = DateTime.now();
    if (now.difference(_lastRoadLimitLookupAt) < _roadLimitLookupInterval) {
      return;
    }

    final lastPos = _lastRoadLimitLookupPos;
    if (lastPos != null &&
        _segDist(lastPos, pos) < _roadLimitLookupMinMoveMeters) {
      return;
    }

    _roadLimitLookupInFlight = true;
    _lastRoadLimitLookupAt = now;
    final fetched = await _fetchRoadSpeedLimitKmh(pos);
    _roadLimitLookupInFlight = false;
    _lastRoadLimitLookupPos = pos;

    if (!mounted || fetched == null) return;
    if (_roadSpeedLimitKmh != null &&
        (fetched - _roadSpeedLimitKmh!).abs() < 1.0) {
      return;
    }

    setState(() {
      _roadSpeedLimitKmh = fetched;
    });
  }

  Future<double?> _fetchRoadSpeedLimitKmh(LatLng pos) async {
    final countryCode = UserPreferencesService.instance.countryCode.value
        .trim()
        .toUpperCase();
    final query =
        '[out:json][timeout:8];way(around:35,${pos.latitude},${pos.longitude})["highway"]["maxspeed"];out tags;';

    try {
      final response = await http
          .post(
            Uri.https('overpass-api.de', '/api/interpreter'),
            headers: {
              'Content-Type':
                  'application/x-www-form-urlencoded; charset=UTF-8',
            },
            body: {'data': query},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final elements =
          (decoded['elements'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          const <Map<String, dynamic>>[];

      final counts = <int, int>{};
      for (final element in elements) {
        final tags = element['tags'] as Map<String, dynamic>?;
        final raw = tags?['maxspeed']?.toString();
        if (raw == null || raw.trim().isEmpty) continue;

        final parsed = _parseRoadSpeedLimitKmh(raw, countryCode: countryCode);
        if (parsed == null) continue;

        final rounded = parsed.round();
        counts[rounded] = (counts[rounded] ?? 0) + 1;
      }

      if (counts.isEmpty) return null;

      final sorted = counts.entries.toList()
        ..sort((a, b) {
          final byCount = b.value.compareTo(a.value);
          if (byCount != 0) return byCount;
          return a.key.compareTo(b.key);
        });

      return sorted.first.key.toDouble();
    } catch (_) {
      return null;
    }
  }

  double? _parseRoadSpeedLimitKmh(String raw, {required String countryCode}) {
    final value = raw.trim().toLowerCase();
    if (value.isEmpty ||
        value == 'none' ||
        value == 'signals' ||
        value == 'variable') {
      return null;
    }

    if (value.contains(':')) {
      final symbolic = _symbolicRoadLimitKmh(value, countryCode: countryCode);
      if (symbolic != null) return symbolic;
    }

    final match = RegExp(r'(\d+(?:[\.,]\d+)?)').firstMatch(value);
    if (match == null) return null;

    final numberRaw = match.group(1)!.replaceAll(',', '.');
    final number = double.tryParse(numberRaw);
    if (number == null) return null;

    final kmh = value.contains('mph') ? number * 1.60934 : number;
    if (kmh < 5 || kmh > 200) return null;
    return kmh;
  }

  double? _symbolicRoadLimitKmh(String value, {required String countryCode}) {
    final cc = countryCode.toUpperCase();
    if (value.endsWith('urban')) {
      return 50;
    }
    if (value.endsWith('rural')) {
      switch (cc) {
        case 'SE':
          return 70;
        default:
          return 80;
      }
    }
    if (value.endsWith('motorway')) {
      switch (cc) {
        case 'DK':
        case 'FR':
          return 130;
        case 'FI':
          return 120;
        default:
          return 110;
      }
    }
    if (value.contains('living_street') || value.contains('walk')) {
      return 7;
    }
    return null;
  }

  Future<void> _showReportAlertSheet() async {
    final pos = _currentLocation;
    if (pos == null) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _InlineReportSheet(
        position: pos,
        controller: _alertsController,
        onSubmitted: _loadAlerts,
      ),
    );
  }

  Future<void> _startLocationTracking() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) {
          return;
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) {
          return;
        }
        return;
      }

      // distanceFilter:0 fires on every OS GPS sample (~1Hz).
      // bestForNavigation squeezes extra accuracy from the GPS chip.
      // automotiveNavigation tells iOS to keep GPS hot and never pause.
      final settings = AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        activityType: ActivityType.automotiveNavigation,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );

      _positionSubscription?.cancel();
      _positionSubscription =
          Geolocator.getPositionStream(locationSettings: settings).listen((
            position,
          ) {
            if (!mounted || _isSimulating) return;

            final hadLocation = _currentLocation != null;
            final currentPos = LatLng(position.latitude, position.longitude);
            final newSpeed = (position.speed < 0 ? 0 : position.speed) * 3.6;
            final heading = (position.speed > 0.5 && position.heading >= 0)
                ? position.heading
                : _headingNotifier.value;

            _processLocationUpdate(currentPos, newSpeed, heading);

            // First GPS fix: auto-detect country from coordinates.
            if (!_countryAutoDetected) {
              _countryAutoDetected = true;
              final detected = CountryVehicleRules.countryFromCoordinates(
                currentPos.latitude,
                currentPos.longitude,
              );
              if (detected != null) {
                UserPreferencesService.instance.countryCode.value = detected;
              }
            }

            // First GPS fix: auto-start routing if destination was set early.
            if (!hadLocation &&
                _destination != null &&
                _routePoints.isEmpty &&
                !_isRouting) {
              _handleMapTap(_destination!);
            }
          });
    } catch (_) {
      if (!mounted) {
        return;
      }
      // GPS unavailable
    }
  }

  @override
  void dispose() {
    NavigationRequestService.instance.pendingDestination.removeListener(
      _onExternalNavigationRequest,
    );
    _locationNotifier.dispose();
    _headingNotifier.dispose();
    _addressController.dispose();
    _searchFocus.dispose();
    _debounce?.cancel();
    _simTimer?.cancel();
    _alertsTimer?.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _fetchSuggestions(query.trim());
    });
  }

  String _normalizeSearchText(String input) {
    return input
        .toLowerCase()
        .replaceAll('å', 'a')
        .replaceAll('ä', 'a')
        .replaceAll('ö', 'o')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _normalizeHouseNumber(String input) {
    return input.toUpperCase().replaceAll(RegExp(r'\s+'), '');
  }

  String _mapboxLanguageCode() {
    final appLang = UserPreferencesService.instance.languageCode.value;
    const map = {
      'sv': 'sv',
      'en': 'en',
      'fr': 'fr',
      'nb': 'no',
      'da': 'da',
      'fi': 'fi',
    };
    return map[appLang] ?? 'sv';
  }

  String _mapboxContextValue(List<dynamic> context, List<String> prefixes) {
    for (final c in context) {
      if (c is! Map) continue;
      final id = (c['id'] ?? '').toString();
      if (prefixes.any((p) => id.startsWith(p))) {
        final text = (c['text'] ?? c['name'] ?? '').toString().trim();
        if (text.isNotEmpty) return text;
      }
    }
    return '';
  }

  Map<String, dynamic>? _mapboxFeatureToResult(Map<String, dynamic> feature) {
    final center = feature['center'];
    if (center is! List || center.length < 2) return null;
    final lon = (center[0]).toString();
    final lat = (center[1]).toString();

    final context = (feature['context'] is List)
        ? (feature['context'] as List)
        : const [];
    final placeTypes = (feature['place_type'] is List)
        ? (feature['place_type'] as List)
        : const [];
    final placeType = placeTypes.isNotEmpty ? placeTypes.first.toString() : '';
    final properties = (feature['properties'] is Map)
        ? (feature['properties'] as Map)
        : const {};

    final featureText = (feature['text'] ?? '').toString().trim();
    final road = placeType == 'poi'
        ? _mapboxContextValue(context, ['address.'])
        : (feature['text'] ?? feature['place_name'] ?? '').toString().trim();
    final houseNumber = (properties['address'] ?? '').toString().trim();
    final city = _mapboxContextValue(context, ['place.', 'locality.']);
    final suburb = _mapboxContextValue(context, ['neighborhood.', 'district.']);
    final municipality = _mapboxContextValue(context, ['region.']);
    final country = _mapboxContextValue(context, ['country.']);

    final address = <String, String>{
      if (road.isNotEmpty) 'road': road,
      if (houseNumber.isNotEmpty) 'house_number': houseNumber,
      if (suburb.isNotEmpty) 'suburb': suburb,
      if (city.isNotEmpty) 'city': city,
      if (municipality.isNotEmpty) 'municipality': municipality,
      if (country.isNotEmpty) 'country': country,
    };

    final title = placeType == 'poi' && featureText.isNotEmpty
        ? featureText
        : road.isNotEmpty
        ? (houseNumber.isNotEmpty ? '$road $houseNumber' : road)
        : featureText;

    return {
      'lat': lat,
      'lon': lon,
      'place_id': feature['id']?.toString() ?? '$lat,$lon',
      'importance': feature['relevance'] ?? 0.0,
      'name': title,
      'display_name': (feature['place_name'] ?? feature['text'] ?? title)
          .toString(),
      'address': address,
      '_mapbox_place_type': placeType,
    };
  }

  Future<List<Map<String, dynamic>>> _fetchMapboxResults(
    String query, {
    int limit = 10,
    LatLng? proximity,
  }) async {
    final token = BackendConfig.mapboxAccessToken.trim();
    if (token.isEmpty) return const [];

    final countries = CountryVehicleRules.supportedCountries
        .map((c) => c.toLowerCase())
        .join(',');
    final path =
        '/geocoding/v5/mapbox.places/${Uri.encodeComponent(query)}.json';
    final params = <String, String>{
      'access_token': token,
      'autocomplete': 'true',
      'limit': '$limit',
      'country': countries,
      'language': _mapboxLanguageCode(),
      'types': 'poi,address,street,place,locality,neighborhood',
    };

    final prox = proximity ?? _currentLocation;
    if (prox != null) {
      params['proximity'] =
          '${prox.longitude},${prox.latitude}';
    }

    final uri = Uri.https('api.mapbox.com', path, params);
    final response = await http.get(
      uri,
      headers: const {
        'User-Agent': 'CruizX/1.0 (mapbox-search)',
        'Accept': 'application/json',
      },
    );
    if (response.statusCode != 200) return const [];

    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['features'] is! List) return const [];
    final features = (decoded['features'] as List)
        .whereType<Map<String, dynamic>>()
        .toList();
    final converted = <Map<String, dynamic>>[];
    for (final f in features) {
      final mapped = _mapboxFeatureToResult(f);
      if (mapped != null) converted.add(mapped);
    }
    return converted;
  }

  Future<List<Map<String, dynamic>>> _fetchPrimaryGeocodingResults(
    String query, {
    int limit = 15,
    LatLng? proximity,
  }) async {
    var raw = await _fetchMapboxResults(
      query,
      limit: limit,
      proximity: proximity,
    );
    if (raw.isEmpty) {
      raw = await _fetchNominatimResults(
        query,
        limit: math.max(limit, 25),
        proximity: proximity,
      );
    }
    return raw;
  }

  Future<List<Map<String, dynamic>>> _fetchNominatimResults(
    String query, {
    int limit = 25,
    LatLng? proximity,
  }) async {
    final codes = CountryVehicleRules.supportedCountries
        .join(',')
        .toLowerCase();
    final baseParams = <String, String>{
      'format': 'jsonv2',
      'addressdetails': '1',
      'limit': '$limit',
      'dedupe': '1',
      'countrycodes': codes,
      'q': query,
    };

    final hnMatch = RegExp(
      r'^\s*(.+?)\s+(\d+\s*[A-Za-z]?)\s*$',
    ).firstMatch(query);
    final structuredParams = <String, String>{...baseParams};
    if (hnMatch != null) {
      structuredParams['street'] = '${hnMatch.group(1)} ${hnMatch.group(2)}';
      structuredParams.remove('q');
    }

    final prox = proximity ?? _currentLocation;
    if (prox != null) {
      final lat = prox.latitude;
      final lon = prox.longitude;
      baseParams['viewbox'] =
          '${lon - 0.5},${lat + 0.5},${lon + 0.5},${lat - 0.5}';
      structuredParams['viewbox'] = baseParams['viewbox']!;
    }

    final response = await http.get(
      Uri.https('nominatim.openstreetmap.org', '/search', baseParams),
      headers: const {
        'User-Agent': 'CruizX/1.0 (address-search)',
        'Accept': 'application/json',
      },
    );
    if (response.statusCode != 200) return const [];

    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];
    var raw = decoded.whereType<Map<String, dynamic>>().toList();

    if (hnMatch != null) {
      final structuredResponse = await http.get(
        Uri.https('nominatim.openstreetmap.org', '/search', structuredParams),
        headers: const {
          'User-Agent': 'CruizX/1.0 (address-search)',
          'Accept': 'application/json',
        },
      );
      if (structuredResponse.statusCode == 200) {
        final structuredDecoded = jsonDecode(structuredResponse.body);
        if (structuredDecoded is List) {
          raw = [
            ...raw,
            ...structuredDecoded.whereType<Map<String, dynamic>>(),
          ];
        }
      }
    }

    return raw;
  }

  String _roadFromResult(Map<String, dynamic> result) {
    final address = result['address'];
    if (address is Map) {
      String getPart(String key) => (address[key] ?? '').toString().trim();
      return [
        getPart('road'),
        getPart('pedestrian'),
        getPart('residential'),
        getPart('street'),
        getPart('footway'),
      ].firstWhere((v) => v.isNotEmpty, orElse: () => '');
    }
    return '';
  }

  String _houseNumberFromResult(Map<String, dynamic> result) {
    final address = result['address'];
    if (address is Map) {
      final hn = (address['house_number'] ?? '').toString().trim();
      if (hn.isNotEmpty) return hn;
    }
    final display = (result['display_name']?.toString() ?? '').trim();
    if (display.isNotEmpty) {
      final first = display.split(',').first.trim();
      if (RegExp(r'^\d+[A-Za-z]?$').hasMatch(first)) return first;
    }
    return '';
  }

  double _scoreSuggestion(
    Map<String, dynamic> result,
    String query,
    RegExpMatch? hnMatch,
  ) {
    final queryNorm = _normalizeSearchText(query);
    final titleNorm = _normalizeSearchText(_addressTitleFromResult(result));
    final subtitleNorm = _normalizeSearchText(
      _addressSubtitleFromResult(result),
    );
    final roadNorm = _normalizeSearchText(_roadFromResult(result));
    final houseNorm = _normalizeHouseNumber(_houseNumberFromResult(result));
    final importance =
        double.tryParse(result['importance']?.toString() ?? '') ?? 0.0;

    double score = importance * 50;

    if (titleNorm == queryNorm) score += 400;
    if (titleNorm.startsWith(queryNorm)) score += 240;
    if (titleNorm.contains(queryNorm)) score += 120;
    if ('$titleNorm $subtitleNorm'.contains(queryNorm)) score += 80;

    if (hnMatch != null) {
      final queryRoad = _normalizeSearchText(hnMatch.group(1) ?? '');
      final queryHouse = _normalizeHouseNumber(hnMatch.group(2) ?? '');
      final roadHit =
          roadNorm == queryRoad ||
          roadNorm.startsWith(queryRoad) ||
          queryRoad.startsWith(roadNorm);
      final houseHit = houseNorm == queryHouse;

      if (roadHit) score += 250;
      if (houseHit) score += 400;
      if (roadHit && houseHit) score += 450;
      if (roadHit && !houseHit && houseNorm.isNotEmpty) score -= 220;
      if (roadHit && houseNorm.isEmpty) score -= 300;
    }

    final lat = double.tryParse(result['lat']?.toString() ?? '');
    final lon = double.tryParse(result['lon']?.toString() ?? '');
    if (_currentLocation != null && lat != null && lon != null) {
      final m = Geolocator.distanceBetween(
        _currentLocation!.latitude,
        _currentLocation!.longitude,
        lat,
        lon,
      );
      // Favor nearby candidates heavily for autocomplete.
      score += math.max(0, 180 - (m / 1000) * 20);
    }

    return score;
  }

  List<Map<String, dynamic>> _rankAndDedupeSuggestions(
    List<Map<String, dynamic>> raw,
    String query,
  ) {
    final hnMatch = RegExp(
      r'^\s*(.+?)\s+(\d+\s*[A-Za-z]?)\s*$',
    ).firstMatch(query);
    var candidates = raw;

    if (hnMatch != null) {
      final qRoad = _normalizeSearchText(hnMatch.group(1) ?? '');
      final qHouse = _normalizeHouseNumber(hnMatch.group(2) ?? '');

      final strict = raw.where((r) {
        final road = _normalizeSearchText(_roadFromResult(r));
        final house = _normalizeHouseNumber(_houseNumberFromResult(r));
        final roadHit =
            road == qRoad || road.startsWith(qRoad) || qRoad.startsWith(road);
        return roadHit && house == qHouse;
      }).toList();

      if (strict.isNotEmpty) {
        candidates = strict;
      }
    }

    final scored =
        candidates
            .map((r) => (item: r, score: _scoreSuggestion(r, query, hnMatch)))
            .toList()
          ..sort((a, b) => b.score.compareTo(a.score));

    final seen = <String>{};
    final deduped = <Map<String, dynamic>>[];
    for (final s in scored) {
      final title = _normalizeSearchText(_addressTitleFromResult(s.item));
      final subtitle = _normalizeSearchText(_addressSubtitleFromResult(s.item));
      // Collapse repeated road-segment hits into one visible suggestion.
      final key = '$title|$subtitle';
      if (seen.add(key)) deduped.add(s.item);
      if (deduped.length >= 5) break;
    }
    return deduped;
  }

  Future<void> _fetchSuggestions(String query) async {
    try {
      final raw = await _fetchPrimaryGeocodingResults(query, limit: 15);
      if (!mounted) return;
      final ranked = _rankAndDedupeSuggestions(raw, query);
      setState(() {
        _suggestions = ranked;
        _showSuggestions = _suggestions.isNotEmpty;
      });
    } catch (_) {}
  }

  void _selectSuggestion(Map<String, dynamic> suggestion) {
    final lat = double.tryParse(suggestion['lat']?.toString() ?? '');
    final lon = double.tryParse(suggestion['lon']?.toString() ?? '');
    if (lat == null || lon == null) return;
    setState(() {
      _suggestions = [];
      _showSuggestions = false;
    });
    final label = _addressTitleFromResult(suggestion);
    _addressController.text = label;
    _destinationLabel = label;
    _searchFocus.unfocus();
    _handleMapTap(LatLng(lat, lon));
  }

  Future<void> _searchAddress(String rawQuery) async {
    final l10n = AppLocalizations.of(context)!;
    final query = rawQuery.trim();
    if (query.isEmpty) {
      return;
    }

    setState(() {
      _isRouting = true;
      _routingStatus = l10n.mapSearchingAddress;
      _showSuggestions = false;
    });

    try {
      final raw = await _fetchPrimaryGeocodingResults(query, limit: 15);
      if (raw.isEmpty) {
        if (!mounted) {
          return;
        }
        setState(() {
          _isRouting = false;
          _routingStatus = l10n.mapAddressNotFound;
        });
        return;
      }
      final ranked = _rankAndDedupeSuggestions(raw, query);
      if (ranked.isEmpty) {
        throw StateError('address_lookup_failed');
      }
      final first = ranked.first;

      final lat = double.tryParse(first['lat']?.toString() ?? '');
      final lon = double.tryParse(first['lon']?.toString() ?? '');

      if (lat == null || lon == null) {
        throw StateError('address_lookup_failed');
      }

      if (!mounted) {
        return;
      }

      _destinationLabel = _addressTitleFromResult(first, fallback: rawQuery);
      await _handleMapTap(LatLng(lat, lon));
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isRouting = false;
        _routingStatus = l10n.mapAddressLookupFailed;
      });
    }
  }

  List<LatLng> _routeSearchAnchors() {
    if (_routePoints.isEmpty) return const [];
    final start = _displayNearestIdx.clamp(0, _routePoints.length - 1);
    final end = _routePoints.length - 1;
    final currentLocation = _currentLocation;
    final anchors = <LatLng>[];
    if (currentLocation != null) {
      anchors.add(currentLocation);
    }
    anchors.add(_routePoints[start]);
    for (final fraction in const [0.18, 0.35, 0.55, 0.75]) {
      final idx = start + ((end - start) * fraction).round();
      if (idx > start && idx <= end) anchors.add(_routePoints[idx]);
    }
    return anchors;
  }

  int _nearestRouteIndexFull(LatLng point) {
    if (_routePoints.isEmpty) return 0;
    var bestIndex = 0;
    var bestDist = double.infinity;
    for (var i = 0; i < _routePoints.length; i++) {
      final dist = _segDist(point, _routePoints[i]);
      if (dist < bestDist) {
        bestDist = dist;
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  Future<List<_RouteStopCandidate>> _findStopsAlongRoute({
    required String query,
    int limit = 8,
  }) async {
    final anchors = _routeSearchAnchors();
    if (anchors.isEmpty || _routePoints.isEmpty || _currentLocation == null) {
      return const [];
    }

    final seen = <String>{};
    final candidates = <_RouteStopCandidate>[];
    for (final anchor in anchors) {
      final raw = await _fetchPrimaryGeocodingResults(
        query,
        limit: 8,
        proximity: anchor,
      );
      for (final result in raw) {
        final lat = double.tryParse(result['lat']?.toString() ?? '');
        final lon = double.tryParse(result['lon']?.toString() ?? '');
        if (lat == null || lon == null) continue;

        final point = LatLng(lat, lon);
        final title = _addressTitleFromResult(result, fallback: query);
        final subtitle = _addressSubtitleFromResult(result);
        final key =
            '${title.toLowerCase()}|${lat.toStringAsFixed(4)},${lon.toStringAsFixed(4)}';
        if (!seen.add(key)) continue;

        final routeDistance = _distanceToRouteMeters(point, _routePoints);
        if (routeDistance > 3500) continue;
        final routeIndex = _nearestRouteIndexFull(point);
        final isAhead = routeIndex >= (_displayNearestIdx - 5);
        final distanceFromMe = _segDist(_currentLocation!, point);
        candidates.add(
          _RouteStopCandidate(
            title: title,
            subtitle: subtitle,
            position: point,
            routeDistanceMeters: routeDistance,
            distanceFromMeMeters: distanceFromMe,
            routeIndex: routeIndex,
            isAhead: isAhead,
          ),
        );
      }
    }

    candidates.sort((a, b) {
      if (a.isAhead != b.isAhead) return a.isAhead ? -1 : 1;
      final routeCompare = a.routeDistanceMeters.compareTo(
        b.routeDistanceMeters,
      );
      if (routeCompare != 0) return routeCompare;
      final progressCompare = a.routeIndex.compareTo(b.routeIndex);
      if (progressCompare != 0) return progressCompare;
      return a.distanceFromMeMeters.compareTo(b.distanceFromMeMeters);
    });
    return candidates.take(limit).toList(growable: false);
  }

  String _formatStopDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  Future<void> _showRouteStopSheet({
    required String title,
    required String query,
    required IconData icon,
  }) async {
    if (_currentLocation == null || _destination == null || _routePoints.isEmpty) {
      return;
    }
    setState(() => _isSearchingRouteStops = true);
    final candidates = await _findStopsAlongRoute(query: query);
    if (!mounted) return;
    setState(() => _isSearchingRouteStops = false);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return SafeArea(
          top: false,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.72,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF1C1C1E),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: Icon(icon, color: const Color(0xFF3AA8FF)),
                  title: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    l10n.routeStopSheetSubtitle,
                    style: const TextStyle(color: Colors.white54),
                  ),
                ),
                if (candidates.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
                    child: Text(
                      l10n.routeStopEmpty,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: candidates.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, color: Colors.white12),
                      itemBuilder: (context, index) {
                        final candidate = candidates[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF303438),
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(
                            candidate.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            [
                              if (candidate.subtitle.isNotEmpty)
                                candidate.subtitle,
                              l10n.routeStopFromRoute(
                                _formatStopDistance(
                                  candidate.routeDistanceMeters,
                                ),
                              ),
                              l10n.routeStopAway(
                                _formatStopDistance(
                                  candidate.distanceFromMeMeters,
                                ),
                              ),
                            ].join(' · '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white54),
                          ),
                          trailing: const Icon(
                            Icons.add_circle,
                            color: Color(0xFF3AA8FF),
                          ),
                          onTap: () {
                            Navigator.of(context).pop();
                            _selectRouteStop(candidate);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _selectRouteStop(_RouteStopCandidate candidate) async {
    final destination = _destination;
    final current = _currentLocation;
    if (destination == null || current == null) return;
    final l10n = AppLocalizations.of(context)!;
    final preferences = UserPreferencesService.instance;

    setState(() {
      _isRouting = true;
      _routeStop = candidate.position;
      _routeStopLabel = candidate.title;
      _routingStatus = l10n.mapCalculatingRoute;
    });

    try {
      final route = await _routingService.getRoute(
        origin: current,
        waypoint: candidate.position,
        destination: destination,
        vehicleType: preferences.vehicleType.value,
      );
      if (!mounted) return;
      _applyRouteResult(route, l10n);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _routeStop = null;
        _routeStopLabel = '';
        _routingStatus = l10n.mapRouteFailed;
      });
    } finally {
      if (mounted) setState(() => _isRouting = false);
    }
  }

  Future<void> _removeRouteStop() async {
    final destination = _destination;
    final current = _currentLocation;
    if (destination == null || current == null) return;
    final l10n = AppLocalizations.of(context)!;
    final preferences = UserPreferencesService.instance;
    setState(() {
      _routeStop = null;
      _routeStopLabel = '';
      _isRouting = true;
      _routingStatus = l10n.mapCalculatingRoute;
    });
    try {
      final route = await _routingService.getRoute(
        origin: current,
        destination: destination,
        vehicleType: preferences.vehicleType.value,
      );
      if (!mounted) return;
      _applyRouteResult(route, l10n);
    } catch (_) {
      if (!mounted) return;
      setState(() => _routingStatus = l10n.mapRouteFailed);
    } finally {
      if (mounted) setState(() => _isRouting = false);
    }
  }

  // Scans a small window forward from last known index — O(window) not O(n).
  // Saves hundreds of iterations per GPS tick on long routes.
  int _nearestRoutePointIndex(LatLng pos) {
    if (_routePoints.isEmpty) return 0;
    // Allow a few points backward (GPS jitter) but scan mostly forward.
    final start = (_lastNearestIdx - 3).clamp(0, _routePoints.length - 1);
    final end = (_lastNearestIdx + 60).clamp(0, _routePoints.length - 1);
    double best = double.infinity;
    int idx = _lastNearestIdx;
    for (int i = start; i <= end; i++) {
      final p = _routePoints[i];
      final dx = p.latitude - pos.latitude;
      final dy = p.longitude - pos.longitude;
      final d = dx * dx + dy * dy;
      if (d < best) {
        best = d;
        idx = i;
      }
    }

    // Never move backward because that makes the passed-route segment
    // re-appear and causes visual "flicker" of the blue line behind us.
    if (idx > _lastNearestIdx) {
      final oldDist = _segDist(pos, _routePoints[_lastNearestIdx]);
      if (oldDist > 6 || (idx - _lastNearestIdx) > 2) {
        _lastNearestIdx = idx;
      }
    }

    // Smooth the visible trim point so the line removal looks stable even
    // when nearest-point index jumps several points on sparse geometries.
    if (_displayNearestIdx < _lastNearestIdx) {
      final step = (_lastNearestIdx - _displayNearestIdx).clamp(0, 6);
      _displayNearestIdx += step;
    }
    return _lastNearestIdx;
  }

  double _segDist(LatLng a, LatLng b) {
    const lat2m = 111320.0;
    final lng2m = 111320.0 * math.cos(a.latitude * math.pi / 180.0);
    final dx = (b.latitude - a.latitude) * lat2m;
    final dy = (b.longitude - a.longitude) * lng2m;
    return math.sqrt(dx * dx + dy * dy);
  }

  double _distanceToRouteMeters(LatLng point, List<LatLng> route) {
    if (route.isEmpty) return double.infinity;
    if (route.length == 1) return _segDist(point, route.first);

    var best = double.infinity;
    for (var i = 0; i < route.length - 1; i++) {
      final a = route[i];
      final b = route[i + 1];
      final dist = _distanceToSegmentMeters(point, a, b);
      if (dist < best) best = dist;
    }
    return best;
  }

  double _distanceToSegmentMeters(LatLng p, LatLng a, LatLng b) {
    const lat2m = 111320.0;
    final lng2m = 111320.0 * math.cos(a.latitude * math.pi / 180.0);
    final ax = a.longitude * lng2m;
    final ay = a.latitude * lat2m;
    final bx = b.longitude * lng2m;
    final by = b.latitude * lat2m;
    final px = p.longitude * lng2m;
    final py = p.latitude * lat2m;
    final dx = bx - ax;
    final dy = by - ay;
    if (dx == 0 && dy == 0) return _segDist(p, a);
    final t = (((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)).clamp(
      0.0,
      1.0,
    );
    final cx = ax + dx * t;
    final cy = ay + dy * t;
    return math.sqrt(math.pow(px - cx, 2) + math.pow(py - cy, 2));
  }

  double _normalizeDeg(double angle) => (angle % 360 + 360) % 360;

  double _bearingDeg(LatLng a, LatLng b) {
    final dLat = b.latitude - a.latitude;
    final dLng =
        (b.longitude - a.longitude) * math.cos(a.latitude * math.pi / 180.0);
    return _normalizeDeg(math.atan2(dLng, dLat) * 180 / math.pi);
  }

  /// Distance-based lookahead: find heading 40m ahead along route.
  /// Much more stable than naive "next segment" approach.
  double _routeLookaheadHeading(int startIdx, double lookaheadM) {
    if (_routePoints.length < 2) return _headingNotifier.value;
    final i = startIdx.clamp(0, _routePoints.length - 1);

    // Walk along route until we've traveled lookaheadM meters.
    double accum = 0;
    int endIdx = i;
    for (int j = i; j < _routePoints.length - 1 && accum < lookaheadM; j++) {
      accum += _segDist(_routePoints[j], _routePoints[j + 1]);
      endIdx = j + 1;
    }
    // If route is too short, just use last point.
    if (endIdx == i && i < _routePoints.length - 1) endIdx = i + 1;

    return _bearingDeg(_routePoints[i], _routePoints[endIdx]);
  }

  double _routeHeadingAt(int nearestIdx) {
    // Use 40m lookahead for smooth heading that doesn't flip at turns.
    return _routeLookaheadHeading(nearestIdx, 40.0);
  }

  String _addressTitleFromResult(
    Map<String, dynamic> result, {
    String fallback = '',
  }) {
    final name = (result['name']?.toString() ?? '').trim();
    final category = (result['category']?.toString() ?? '').trim();
    final mapboxPlaceType = (result['_mapbox_place_type']?.toString() ?? '')
        .trim();
    final isPoi =
        mapboxPlaceType == 'poi' ||
        (category.isNotEmpty && category != 'highway');

    if (isPoi && name.isNotEmpty) {
      return name;
    }

    final address = result['address'];
    // Always prefer road + house_number when we have both.
    if (address is Map) {
      String getPart(String key) => (address[key] ?? '').toString().trim();
      final road = [
        getPart('road'),
        getPart('pedestrian'),
        getPart('residential'),
        getPart('street'),
        getPart('footway'),
      ].firstWhere((v) => v.isNotEmpty, orElse: () => '');
      final houseNumber = getPart('house_number');
      if (road.isNotEmpty && houseNumber.isNotEmpty) {
        return '$road $houseNumber';
      }
      if (road.isNotEmpty) {
        // house_number may be absent from address object — try display_name
        final display = (result['display_name']?.toString() ?? '').trim();
        if (display.isNotEmpty) {
          final firstPart = display.split(',').first.trim();
          if (RegExp(r'^\d+[A-Za-z]?$').hasMatch(firstPart)) {
            return '$road $firstPart';
          }
        }
        return road;
      }
    }

    // Fall back to POI / place name
    if (name.isNotEmpty) return name;

    final display = (result['display_name']?.toString() ?? fallback).trim();
    if (display.isEmpty) return fallback.trim();
    final parts = display
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return fallback.trim();

    final first = parts[0];
    final second = parts.length > 1 ? parts[1] : '';
    final firstIsHouseNumber = RegExp(r'^\d+[A-Za-z]?$').hasMatch(first);
    if (firstIsHouseNumber && second.isNotEmpty) {
      return '$second $first';
    }
    return first;
  }

  String _addressSubtitleFromResult(Map<String, dynamic> result) {
    final address = result['address'];
    if (address is Map) {
      String getPart(String key) => (address[key] ?? '').toString().trim();
      final road = [
        getPart('road'),
        getPart('pedestrian'),
        getPart('residential'),
        getPart('street'),
        getPart('footway'),
      ].firstWhere((v) => v.isNotEmpty, orElse: () => '');
      final houseNumber = getPart('house_number');
      final city = [
        getPart('city'),
        getPart('town'),
        getPart('village'),
        getPart('municipality'),
      ].firstWhere((v) => v.isNotEmpty, orElse: () => '');
      final suburb = getPart('suburb');
      final parts = <String>[
        if (road.isNotEmpty)
          houseNumber.isNotEmpty ? '$road $houseNumber' : road,
        if (suburb.isNotEmpty) suburb,
        if (city.isNotEmpty) city,
      ];
      if (parts.isNotEmpty) return parts.join(', ');
    }
    final display = (result['display_name']?.toString() ?? '').trim();
    if (display.isEmpty) return '';
    final parts = display
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.length <= 1) return '';
    return parts.skip(1).take(3).join(', ');
  }

  /// Precompute cumulative distances so remaining-dist lookups are O(1).
  List<double> _buildCumulativeDist(List<LatLng> pts) {
    if (pts.isEmpty) return const [];
    final result = List<double>.filled(pts.length, 0);
    for (int i = 1; i < pts.length; i++) {
      result[i] = result[i - 1] + _segDist(pts[i - 1], pts[i]);
    }
    return result;
  }

  /// Smart ETA speed: GPS-driven, smoothed, and resilient to short stops.
  double _smartEtaSpeedKmh(double liveSpeedKmh) {
    final selectedVehicleSpeedKmh =
        UserPreferencesService.instance.maxSpeedKmh.value;
    if (selectedVehicleSpeedKmh <= 0) return 0;

    final cappedLive = liveSpeedKmh.clamp(0.0, selectedVehicleSpeedKmh);
    if (cappedLive >= 3.0) {
      _etaLastMovementAt = DateTime.now();
      if (_etaSmoothedSpeedKmh <= 0) {
        _etaSmoothedSpeedKmh = cappedLive;
      } else {
        _etaSmoothedSpeedKmh = _etaSmoothedSpeedKmh * 0.75 + cappedLive * 0.25;
      }
      return _etaSmoothedSpeedKmh.clamp(1.0, selectedVehicleSpeedKmh);
    }

    if (_etaSmoothedSpeedKmh > 0 && _etaLastMovementAt != null) {
      final pause = DateTime.now().difference(_etaLastMovementAt!);
      if (pause <= _etaPauseGrace) {
        _etaSmoothedSpeedKmh = (_etaSmoothedSpeedKmh * 0.96).clamp(
          3.0,
          selectedVehicleSpeedKmh,
        );
        return _etaSmoothedSpeedKmh;
      }
    }

    return 0;
  }

  (int turns, int complexTurns) _remainingManeuversFrom(int currentInstrIdx) {
    if (_instructions.isEmpty) return (0, 0);
    final start = (currentInstrIdx + 1).clamp(0, _instructions.length);
    var turns = 0;
    var complexTurns = 0;
    for (int i = start; i < _instructions.length; i++) {
      final sign = _instructions[i].sign;
      if (sign == 0 || sign == 4) continue;
      turns++;
      if (sign.abs() >= 2 || sign.abs() == 6) {
        complexTurns++;
      }
    }
    return (turns, complexTurns);
  }

  double _etaManeuverDelaySeconds({
    required int turns,
    required int complexTurns,
    required double remainingMeters,
  }) {
    if (turns <= 0 || remainingMeters <= 120) return 0;
    final vehicleMax = UserPreferencesService.instance.maxSpeedKmh.value;
    final slowFactor = ((45.0 - vehicleMax).clamp(0.0, 15.0)) / 15.0;
    final basePerTurn = 6.0 + 4.0 * slowFactor;
    final complexExtra = 5.0 + 3.0 * slowFactor;
    final rawDelay = turns * basePerTurn + complexTurns * complexExtra;
    final cap = (remainingMeters / 45.0).clamp(20.0, 180.0);
    return rawDelay.clamp(0.0, cap);
  }

  Widget _mapCircleButton({
    required VoidCallback onTap,
    required Widget child,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xEE0A1F63),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0x883AA8FF), width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Center(child: child),
      ),
    );
  }

  // ── Favorite places helpers ───────────────────────────────────────
  Widget _favChip({
    required IconData icon,
    required String label,
    required bool hasValue,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
    bool compact = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: hasValue ? const Color(0xEE0A1F63) : const Color(0x880A1F63),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasValue ? const Color(0xFF3AA8FF) : const Color(0x553AA8FF),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white70),
            if (!compact) ...[
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: hasValue ? Colors.white : Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _navigateToFavorite(FavoritePlace fav) {
    _addressController.text = fav.label;
    _destinationLabel = fav.label;
    _searchFocus.unfocus();
    _handleMapTap(LatLng(fav.lat, fav.lon));
  }

  void _promptSetFavorite(String iconKey, String defaultLabel) {
    if (_destination == null) {
      // No destination set — ask user to first search for an address
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.mapAddressFieldHint),
          duration: const Duration(seconds: 2),
        ),
      );
      _searchFocus.requestFocus();
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final dest = _destination!;
    final label = _destinationLabel.isNotEmpty
        ? _destinationLabel
        : defaultLabel;
    FavoritePlacesService.instance.add(
      FavoritePlace(
        id: '${iconKey}_${DateTime.now().millisecondsSinceEpoch}',
        label: label,
        icon: iconKey,
        lat: dest.latitude,
        lon: dest.longitude,
        address: _destinationLabel,
      ),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.favSaved),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _promptAddCustomFavorite() {
    if (_destination == null) {
      _searchFocus.requestFocus();
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final dest = _destination!;
    final nameCtrl = TextEditingController(text: _destinationLabel);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0A1F63),
        title: Text(
          l10n.favAddTitle,
          style: const TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: l10n.favLabelHint,
            hintStyle: const TextStyle(color: Colors.white38),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              MaterialLocalizations.of(ctx).cancelButtonLabel,
              style: const TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              FavoritePlacesService.instance.add(
                FavoritePlace(
                  id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                  label: name,
                  lat: dest.latitude,
                  lon: dest.longitude,
                  address: _destinationLabel,
                ),
              );
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.favSaved),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: Text(
              l10n.favAddTitle,
              style: const TextStyle(color: Color(0xFF3AA8FF)),
            ),
          ),
        ],
      ),
    );
  }

  void _showFavoriteOptions(FavoritePlace fav) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0A1F63),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.navigation, color: Colors.white70),
              title: Text(
                fav.label,
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                fav.address,
                style: const TextStyle(color: Colors.white54),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _navigateToFavorite(fav);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.redAccent),
              title: Text(
                l10n.favDeleteConfirm(fav.label),
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                FavoritePlacesService.instance.remove(fav.id);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.favDeleted),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSaveFavoriteSheet() {
    if (_destination == null) return;
    final l10n = AppLocalizations.of(context)!;
    final dest = _destination!;
    final address = _destinationLabel;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0A1F63),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (FavoritePlacesService.instance.findByIcon('home') == null)
              ListTile(
                leading: const Icon(Icons.home, color: Colors.white70),
                title: Text(
                  l10n.favSetAs(l10n.favHome),
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  _saveFav(ctx, 'home', l10n.favHome, dest, address);
                },
              ),
            if (FavoritePlacesService.instance.findByIcon('school') == null)
              ListTile(
                leading: const Icon(Icons.school, color: Colors.white70),
                title: Text(
                  l10n.favSetAs(l10n.favSchool),
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  _saveFav(ctx, 'school', l10n.favSchool, dest, address);
                },
              ),
            if (FavoritePlacesService.instance.findByIcon('work') == null)
              ListTile(
                leading: const Icon(Icons.work, color: Colors.white70),
                title: Text(
                  l10n.favSetAs(l10n.favWork),
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  _saveFav(ctx, 'work', l10n.favWork, dest, address);
                },
              ),
            ListTile(
              leading: const Icon(Icons.star, color: Color(0xFFFFB800)),
              title: Text(
                l10n.favCustom,
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _promptAddCustomFavorite();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _saveFav(
    BuildContext ctx,
    String iconKey,
    String label,
    LatLng dest,
    String address,
  ) {
    FavoritePlacesService.instance.add(
      FavoritePlace(
        id: '${iconKey}_${DateTime.now().millisecondsSinceEpoch}',
        label: label,
        icon: iconKey,
        lat: dest.latitude,
        lon: dest.longitude,
        address: address,
      ),
    );
    Navigator.pop(ctx);
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.favSaved),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  IconData _turnIcon(int sign) {
    return switch (sign) {
      -3 => Icons.turn_sharp_left,
      -2 => Icons.turn_left,
      -1 => Icons.turn_slight_left,
      0 => Icons.straight,
      1 => Icons.turn_slight_right,
      2 => Icons.turn_right,
      3 => Icons.turn_sharp_right,
      4 => Icons.flag_rounded,
      -6 || 6 => Icons.rotate_right,
      _ => Icons.straight,
    };
  }

  void _announceManeuver(String text, double distMeters) {
    if (text.isEmpty) return;
    final l10n = AppLocalizations.of(context)!;
    // Announce at ~200m (early warning) and ~50m (final reminder)
    if (distMeters <= 200 && distMeters > 50 && !_spokenEarlyWarning) {
      _spokenEarlyWarning = true;
      final distText = distMeters >= 1000
          ? l10n.voiceInKm((distMeters / 1000).toStringAsFixed(1))
          : l10n.voiceInMeters(((distMeters / 10).round() * 10).toString());
      TtsService.instance.speak('$distText, $text');
    } else if (distMeters <= 50 && _lastSpokenManeuver != text) {
      _lastSpokenManeuver = text;
      _spokenEarlyWarning = false;
      TtsService.instance.speak(text);
    }
    // Reset when new maneuver comes (distance increases)
    if (distMeters > 250) {
      _spokenEarlyWarning = false;
    }
  }

  String _formatManeuverDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.round()} m';
  }

  String? _maneuverTargetFromText(String text) {
    final t = text.trim();
    if (t.isEmpty) return null;

    final patterns = <RegExp>[
      RegExp(
        r'\b(?:in pa|in p\u00e5|mot|towards|onto)\s+(.+)$',
        caseSensitive: false,
      ),
      RegExp(r'\b(?:vid)\s+(.+)$', caseSensitive: false),
    ];

    for (final re in patterns) {
      final m = re.firstMatch(t);
      if (m != null && m.groupCount >= 1) {
        final road = (m.group(1) ?? '')
            .replaceAll(RegExp(r'[.!]+$'), '')
            .trim();
        if (road.isNotEmpty) return road;
      }
    }

    return null;
  }

  String _maneuverPrimaryText(String text) {
    final t = text.trim();
    if (t.isEmpty) return t;

    final cleaned = t
        .replaceAll(
          RegExp(
            r'\s+(?:in pa|in p\u00e5|mot|towards|onto|vid)\s+.+$',
            caseSensitive: false,
          ),
          '',
        )
        .trim();

    return cleaned.isNotEmpty ? cleaned : t;
  }

  String _localizedManeuverPrimaryText(
    AppLocalizations l10n,
    int sign,
    String fallback,
  ) {
    return switch (sign) {
      -3 => l10n.voiceTurnSharpLeft,
      -2 => l10n.voiceTurnLeft,
      -1 => l10n.voiceTurnSlightLeft,
      0 => l10n.voiceContinue,
      1 => l10n.voiceTurnSlightRight,
      2 => l10n.voiceTurnRight,
      3 => l10n.voiceTurnSharpRight,
      -6 || 6 => l10n.voiceRoundabout,
      4 => l10n.voiceDestination,
      _ => _maneuverPrimaryText(fallback),
    };
  }

  Color _maneuverAccentColor(double distanceMeters, int sign) {
    final absSign = sign.abs();
    if (distanceMeters <= 30) return const Color(0xFFD84315);
    if (distanceMeters <= 65 && (absSign >= 2 || absSign == 6)) {
      return const Color(0xFFEF6C00);
    }
    if (distanceMeters <= 140 && absSign >= 2) {
      return const Color(0xFFFB8C00);
    }
    return const Color(0xFF274D94);
  }

  void _applyRouteResult(RouteResult route, AppLocalizations l10n) {
    final km = route.distanceMeters / 1000;
    final minutes = route.durationSeconds / 60;
    final cumDist = _buildCumulativeDist(route.points);
    final totalDist = cumDist.isNotEmpty ? cumDist.last : 0.0;

    setState(() {
      _routePoints = route.points;
      _cumulativeDist = cumDist;
      _totalRouteDistM = totalDist;
      _instructions = route.instructions;
      _lastNearestIdx = 0;
      _displayNearestIdx = 0;
      _nextManeuverText = '';
      _nextManeuverSign = 0;
      _distToNextManeuver = 0;
      _routingStatus = l10n.mapRouteReady(
        km.toStringAsFixed(1),
        minutes.toStringAsFixed(0),
      );
    });
  }

  Future<void> _handleMapTap(LatLng destination) async {
    final l10n = AppLocalizations.of(context)!;
    final preferences = UserPreferencesService.instance;

    if (_currentLocation == null) {
      // Save destination so auto-retry fires when first GPS fix arrives.
      setState(() {
        _destination = destination;
        _routingStatus = l10n.mapWaitingForGps;
      });
      return;
    }

    // ── Free tier route limit ─────────────────────────────────────────
    if (!SubscriptionService.instance.canStartRoute()) {
      await Navigator.of(context).push(
        MaterialPageRoute<bool>(
          builder: (_) => const PaywallScreen(reason: PaywallReason.routeLimit),
        ),
      );
      return;
    }

    setState(() {
      _isRouting = true;
      _destination = destination;
      _routeStop = null;
      _routeStopLabel = '';
      _routingStatus = l10n.mapCalculatingRoute;
    });

    try {
      final route = await _routingService.getRoute(
        origin: _currentLocation!,
        destination: destination,
        vehicleType: preferences.vehicleType.value,
      );

      if (!mounted) {
        return;
      }

      _applyRouteResult(route, l10n);
      SubscriptionService.instance.recordRoute();
    } on RoutingException catch (error) {
      if (!mounted) {
        return;
      }

      final isRouteBlocked =
          error.code == RoutingErrorCode.noRouteFound ||
          error.code == RoutingErrorCode.routeTooFastForVehicle ||
          error.code == RoutingErrorCode.routeNotAllowedForVehicle;

      setState(() {
        _routePoints = const [];
        _lastNearestIdx = 0;
        _displayNearestIdx = 0;
        _routingStatus = switch (error.code) {
          RoutingErrorCode.noRouteFound => l10n.mapRouteNoRouteFound,
          RoutingErrorCode.providerUnavailable =>
            l10n.mapRouteProviderUnavailable,
          RoutingErrorCode.missingApiKey => l10n.mapRouteMissingApiKey,
          RoutingErrorCode.invalidGeometry => l10n.mapRouteInvalidGeometry,
          RoutingErrorCode.unknownProvider => l10n.mapRouteUnknownProvider,
          RoutingErrorCode.routeTooFastForVehicle =>
            l10n.mapRouteTooFastForVehicle,
          RoutingErrorCode.routeNotAllowedForVehicle =>
            l10n.mapRouteNotAllowedForVehicle,
        };
      });

      if (isRouteBlocked) {
        final vehicleName = switch (preferences.vehicleType.value) {
          'A-tractor' => l10n.settingsVehicleAtractor,
          'Moped car' => l10n.settingsVehicleMopedCar,
          'Tractor' => l10n.settingsVehicleTractor,
          _ => preferences.vehicleType.value,
        };

        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF0A1F63),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                const Icon(Icons.block, color: Colors.redAccent, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.routeBlockedTitle,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
              ],
            ),
            content: Text(
              l10n.routeBlockedBody(vehicleName),
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(
                  l10n.routeBlockedOk,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _routePoints = const [];
        _routingStatus = l10n.mapRouteFailed;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isRouting = false;
        });
      }
    }
  }

  void _clearRoute() {
    _simTimer?.cancel();
    _simTimer = null;
    // Calibrate speed with this trip's data, then end the SlowRoad session.
    if (_isNavigating) {
      final start = _tripStartTime;
      if (start != null) {
        final durationSec = DateTime.now()
            .difference(start)
            .inSeconds
            .toDouble();
        SpeedCalibrationService.instance.recordTrip(
          vehicleType: UserPreferencesService.instance.vehicleType.value,
          distanceM: _tripDistanceM,
          durationSec: durationSec,
        );
      }
      SlowRoadService.instance.endSession();
    } else {
      SlowRoadService.instance.cancelSession();
    }
    setState(() {
      _routePoints = const [];
      _lastNearestIdx = 0;
      _displayNearestIdx = 0;
      _destination = null;
      _destinationLabel = '';
      _routeStop = null;
      _routeStopLabel = '';
      _isNavigating = false;
      _isFollowing = false;
      _instructions = const [];
      _nextManeuverText = '';
      _nextManeuverSign = 0;
      _distToNextManeuver = 0;
      _currentStreetName = '';
      _cumulativeDist = const [];
      _totalRouteDistM = 0;
      _tripStartTime = null;
      _tripDistanceM = 0;
      _lastNavPos = null;
      _etaSmoothedSpeedKmh = 0;
      _etaLastMovementAt = null;
      _nearbyAlert = null;
      _isSimulating = false;
      _routingStatus = AppLocalizations.of(context)!.mapTapToSelectDestination;
    });
  }

  // ── Shared location-update processor (used by GPS stream + sim) ──────────
  void _processLocationUpdate(
    LatLng currentPos,
    double newSpeed,
    double heading,
  ) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;

    if (_isNavigating) {
      SlowRoadService.instance.addPoint(currentPos, newSpeed);
    }

    double newTripDist = _tripDistanceM;
    if (_isNavigating && _lastNavPos != null) {
      newTripDist += _segDist(_lastNavPos!, currentPos);
    }

    int? newSign;
    String? newText;
    double? newDist;
    double? newRemaining;
    String? newStreetName;
    int? nearestIdxForHeading;
    double? nearestPointDistM;
    int remainingTurns = 0;
    int remainingComplexTurns = 0;
    if (_isNavigating && _routePoints.isNotEmpty) {
      final nearestIdx = _nearestRoutePointIndex(currentPos);
      nearestIdxForHeading = nearestIdx;
      nearestPointDistM = _segDist(currentPos, _routePoints[nearestIdx]);
      if (_cumulativeDist.length == _routePoints.length) {
        newRemaining = (_totalRouteDistM - _cumulativeDist[nearestIdx]).clamp(
          0.0,
          _totalRouteDistM,
        );
      }
      if (_instructions.isNotEmpty) {
        int instrIdx = 0;
        for (int i = 0; i < _instructions.length - 1; i++) {
          if (_instructions[i + 1].pointIndex > nearestIdx) {
            instrIdx = i;
            break;
          }
          instrIdx = i + 1;
        }
        final remaining = _remainingManeuversFrom(instrIdx);
        remainingTurns = remaining.$1;
        remainingComplexTurns = remaining.$2;
        // Track current street name from the active instruction
        final currentInstr = _instructions[instrIdx];
        if (currentInstr.streetName.isNotEmpty) {
          newStreetName = currentInstr.streetName;
        }
        final nextIdx = instrIdx + 1;
        if (nextIdx < _instructions.length) {
          final next = _instructions[nextIdx];
          double dist = 0;
          for (
            int i = nearestIdx;
            i < next.pointIndex && i < _routePoints.length - 1;
            i++
          ) {
            dist += _segDist(_routePoints[i], _routePoints[i + 1]);
          }
          newSign = next.sign;
          newText = next.text;
          newDist = dist;
        } else {
          newText = '';
        }
      }
    }

    _locationNotifier.value = currentPos;
    if (newSpeed > 0.5) {
      var headingForArrow = heading;
      if (_isNavigating &&
          nearestIdxForHeading != null &&
          nearestPointDistM != null) {
        // ROUTE-LOCKED: When on route, use route direction exclusively.
        // This is how Google Maps/Waze work — no GPS/compass blending.
        if (nearestPointDistM < 20) {
          // Full route lock when within 20m of route.
          headingForArrow = _routeHeadingAt(nearestIdxForHeading);
        }
        // Otherwise keep GPS heading (off-route).
      }
      _headingNotifier.value = headingForArrow;
    }

    setState(() {
      _speedKmh = newSpeed;
      _currentLocation = currentPos;
      if (_isNavigating) {
        _tripDistanceM = newTripDist;
        _lastNavPos = currentPos;
      }
      if (newSign != null) _nextManeuverSign = newSign;
      if (newText != null) _nextManeuverText = newText;
      if (newDist != null) _distToNextManeuver = newDist;
      if (newStreetName != null) _currentStreetName = newStreetName;

      // Voice navigation announcements
      if (_isNavigating && newText != null && newDist != null) {
        _announceManeuver(newText, newDist);
      }
      if (newRemaining != null) {
        final remKm = newRemaining / 1000;
        final distStr = remKm >= 1.0
            ? '${remKm.toStringAsFixed(1)} km ${l10n.mapRemaining}'
            : '${newRemaining.round()} m ${l10n.mapRemaining}';
        final etaSpeedKmh = _smartEtaSpeedKmh(newSpeed);
        if (etaSpeedKmh > 0 && newRemaining > 50) {
          final baseSec = newRemaining / (etaSpeedKmh / 3.6);
          final maneuverDelaySec = _etaManeuverDelaySeconds(
            turns: remainingTurns,
            complexTurns: remainingComplexTurns,
            remainingMeters: newRemaining,
          );
          final sec = baseSec + maneuverDelaySec;
          final arrival = DateTime.now().add(Duration(seconds: sec.round()));
          final hh = arrival.hour.toString().padLeft(2, '0');
          final mm = arrival.minute.toString().padLeft(2, '0');
          _routingStatus = '$distStr  •  $hh:$mm';
        } else {
          _routingStatus = distStr;
        }
      }
      _nearbyAlert = _alerts
          .where((a) => a.distanceTo(currentPos) <= 400)
          .fold<AlertModel?>(
            null,
            (best, a) =>
                best == null ||
                    a.distanceTo(currentPos) < best.distanceTo(currentPos)
                ? a
                : best,
          );
    });

    unawaited(_maybeRefreshRoadSpeedLimit(currentPos));
  }

  // ── GPS simulation ────────────────────────────────────────────────────────
  void _startSimulation() {
    if (_routePoints.isEmpty) return;
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _simPtIdx = 0;
    _simSegOffsetM = 0;
    final vt = UserPreferencesService.instance.vehicleType.value;
    SlowRoadService.instance.startSession(vt);
    setState(() {
      _isSimulating = true;
      _isNavigating = true;
      _isFollowing = true;
      _tripStartTime = DateTime.now();
      _tripDistanceM = 0;
      _lastNavPos = _routePoints[0];
      _currentLocation = _routePoints[0];
    });
    _locationNotifier.value = _routePoints[0];
    _simTimer = Timer.periodic(_simInterval, (_) => _simStep());
  }

  void _simStep() {
    if (!mounted || _routePoints.isEmpty) {
      _clearRoute();
      return;
    }
    const metersPerSec = _simSpeedKmh / 3.6;
    final intervalSec = _simInterval.inMilliseconds / 1000.0;
    double toAdvance = metersPerSec * intervalSec;

    int idx = _simPtIdx;
    double offset = _simSegOffsetM;

    while (toAdvance > 0 && idx < _routePoints.length - 1) {
      final segLen = _segDist(_routePoints[idx], _routePoints[idx + 1]);
      final remaining = segLen - offset;
      if (toAdvance >= remaining) {
        toAdvance -= remaining;
        idx++;
        offset = 0;
      } else {
        offset += toAdvance;
        toAdvance = 0;
      }
    }

    _simPtIdx = idx;
    _simSegOffsetM = offset;

    if (idx >= _routePoints.length - 1) {
      _clearRoute();
      return;
    }

    final ptA = _routePoints[idx];
    final ptB = _routePoints[idx + 1];
    final segLen = _segDist(ptA, ptB);
    final t = segLen > 0 ? (offset / segLen).clamp(0.0, 1.0) : 0.0;
    final simPos = LatLng(
      ptA.latitude + (ptB.latitude - ptA.latitude) * t,
      ptA.longitude + (ptB.longitude - ptA.longitude) * t,
    );
    final dLat = ptB.latitude - ptA.latitude;
    final dLng = ptB.longitude - ptA.longitude;
    final heading = (math.atan2(dLng, dLat) * 180 / math.pi + 360) % 360;

    _processLocationUpdate(simPos, _simSpeedKmh, heading);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final preferences = UserPreferencesService.instance;

    // In navigation mode the map is fullscreen (edge-to-edge, behind
    // status bar). Outside navigation mode it sits in a padded card.
    final mapPadding = _isNavigating
        ? EdgeInsets.zero
        : const EdgeInsets.fromLTRB(12, 12, 12, 18);
    final mapRadius = _isNavigating ? 0.0 : 12.0;

    return SafeArea(
      // During navigation we want the map to extend behind the safe area.
      top: !_isNavigating,
      bottom: !_isNavigating,
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: mapPadding,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(mapRadius),
                child: RepaintBoundary(
                  child: MapWidget(
                    locationNotifier: _locationNotifier,
                    headingNotifier: _headingNotifier,
                    destination: _destination,
                    routePoints: _isNavigating && _displayNearestIdx > 0
                        ? _routePoints.sublist(
                            _displayNearestIdx.clamp(0, _routePoints.length),
                          )
                        : _routePoints,
                    studdedTireBanZones:
                        UserPreferencesService.instance.hasStuddedTires.value
                        ? StuddedTireZones.all.map((z) => z.polygon).toList()
                        : const [],
                    chargingStations: _chargingStations,
                    nextManeuverDistanceMeters: _isNavigating
                        ? _distToNextManeuver
                        : null,
                    nextManeuverSign: _isNavigating ? _nextManeuverSign : null,
                    alerts: _alerts,
                    onTap: _isNavigating ? null : _handleMapTap,
                    followUser: _isNavigating && _isFollowing,
                    use3D: _use3DMap,
                    darkMode: _useDarkMap,
                    onUserPanned: _isNavigating
                        ? () => setState(() => _isFollowing = false)
                        : null,
                  ),
                ),
              ),
            ),
          ),
          // ── Logo (top-left) ─────────────────────────────────────────────
          if (!_isNavigating)
            Positioned(
              top: 12,
              left: 16,
              child: Image.asset(
                'assets/logga_nobg.png',
                height: 120,
                fit: BoxFit.contain,
              ),
            ),
          // ── Compact speed bubble (aligned with right-side buttons) ─────────
          if (!_isNavigating)
            Positioned(
              left: 14,
              bottom: 155,
              child: ValueListenableBuilder<SpeedUnit>(
                valueListenable: preferences.speedUnit,
                builder: (context, speedUnit, _) {
                  return ValueListenableBuilder<double>(
                    valueListenable: preferences.maxSpeedKmh,
                    builder: (context, maxSpeedKmh, _) {
                      final roadLimitKmh = _roadSpeedLimitKmh;
                      final effectiveLimitKmh = roadLimitKmh;
                      final over =
                          effectiveLimitKmh != null &&
                          _speedKmh > effectiveLimitKmh;
                      final speedDisplay = preferences.toDisplaySpeed(
                        speedKmh: _speedKmh,
                        unit: speedUnit,
                      );
                      final effectiveLimitDisplay = effectiveLimitKmh == null
                          ? 0.0
                          : preferences.toDisplaySpeed(
                              speedKmh: effectiveLimitKmh,
                              unit: speedUnit,
                            );
                      final roadLimitDisplay = roadLimitKmh == null
                          ? null
                          : preferences.toDisplaySpeed(
                              speedKmh: roadLimitKmh,
                              unit: speedUnit,
                            );
                      final speedRatio = effectiveLimitDisplay > 0
                          ? (speedDisplay / effectiveLimitDisplay).clamp(
                              0.0,
                              1.25,
                            )
                          : 0.0;
                      final unitLabel = speedUnit == SpeedUnit.kmh
                          ? l10n.settingsSpeedUnitKmh
                          : l10n.settingsSpeedUnitMph;
                      final hasRoadLimit = roadLimitDisplay != null;
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Current speed circle
                          SizedBox(
                            width: 64,
                            height: 64,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CustomPaint(
                                  size: const Size(64, 64),
                                  painter: _SpeedBarsPainter(
                                    ratio: speedRatio,
                                    activeColor: over
                                        ? const Color(0xFFFF5A5F)
                                        : const Color(0xFFFF9A2F),
                                    inactiveColor: const Color(0x40FFFFFF),
                                    strokeWidth: 4.0,
                                    segments: 30,
                                  ),
                                ),
                                Container(
                                  width: 58,
                                  height: 58,
                                  decoration: BoxDecoration(
                                    color: over
                                        ? const Color(0xFFD32F2F)
                                        : const Color(0xEE0A1F63),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: over
                                          ? Colors.red.shade300
                                          : const Color(0x883AA8FF),
                                      width: 1.5,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black45,
                                        blurRadius: 8,
                                        offset: Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        speedDisplay.toStringAsFixed(0),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          height: 1.0,
                                        ),
                                      ),
                                      Text(
                                        unitLabel,
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 9,
                                          height: 1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          // EU speed limit sign
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: hasRoadLimit
                                    ? Colors.red.shade700
                                    : Colors.grey.shade500,
                                width: 3,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black38,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                hasRoadLimit
                                    ? roadLimitDisplay.toStringAsFixed(0)
                                    : '--',
                                style: TextStyle(
                                  color: hasRoadLimit
                                      ? Colors.black
                                      : Colors.black45,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  height: 1.0,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),

          // ── Bottom search bar (hidden while navigating) ──────────────────
          if (!_isNavigating)
            Positioned(
              left: 16,
              right: 16,
              bottom:
                  (_destination != null ||
                      _routePoints.isNotEmpty ||
                      _isRouting)
                  ? 110
                  : 24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_showSuggestions && _suggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xF0071739),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0x553AA8FF)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: _suggestions.map((s) {
                            final title = _addressTitleFromResult(s);
                            final subtitle = _addressSubtitleFromResult(s);
                            return InkWell(
                              onTap: () => _selectSuggestion(s),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on,
                                      size: 18,
                                      color: Colors.white54,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            title,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w500,
                                              fontSize: 14,
                                            ),
                                          ),
                                          if (subtitle.isNotEmpty)
                                            Text(
                                              subtitle,
                                              style: TextStyle(
                                                color: Colors.white.withValues(
                                                  alpha: 0.5,
                                                ),
                                                fontSize: 12,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  // ── Favorite places chips ─────────────────────────────
                  ValueListenableBuilder<List<FavoritePlace>>(
                    valueListenable: FavoritePlacesService.instance.places,
                    builder: (context, favs, _) {
                      if (_showSuggestions && _suggestions.isNotEmpty) {
                        return const SizedBox.shrink();
                      }
                      final presets = <_FavPreset>[
                        _FavPreset('home', Icons.home, l10n.favHome),
                        _FavPreset('school', Icons.school, l10n.favSchool),
                        _FavPreset('work', Icons.work, l10n.favWork),
                      ];
                      final custom = favs
                          .where(
                            (f) =>
                                f.icon != 'home' &&
                                f.icon != 'school' &&
                                f.icon != 'work',
                          )
                          .toList();
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              ...presets.map((p) {
                                final fav = FavoritePlacesService.instance
                                    .findByIcon(p.key);
                                return Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: _favChip(
                                    icon: p.icon,
                                    label: fav?.label ?? p.label,
                                    hasValue: fav != null,
                                    onTap: () {
                                      if (fav != null) {
                                        _navigateToFavorite(fav);
                                      } else {
                                        _promptSetFavorite(p.key, p.label);
                                      }
                                    },
                                    onLongPress: fav != null
                                        ? () => _showFavoriteOptions(fav)
                                        : null,
                                  ),
                                );
                              }),
                              ...custom.map(
                                (f) => Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: _favChip(
                                    icon: Icons.star,
                                    label: f.label,
                                    hasValue: true,
                                    onTap: () => _navigateToFavorite(f),
                                    onLongPress: () => _showFavoriteOptions(f),
                                  ),
                                ),
                              ),
                              _favChip(
                                icon: Icons.add,
                                label: '+',
                                hasValue: false,
                                onTap: _promptAddCustomFavorite,
                                compact: true,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  TextField(
                    controller: _addressController,
                    focusNode: _searchFocus,
                    textInputAction: TextInputAction.search,
                    onChanged: _onSearchChanged,
                    onSubmitted: (q) {
                      setState(() {
                        _showSuggestions = false;
                      });
                      _searchAddress(q);
                    },
                    decoration: InputDecoration(
                      hintText: l10n.mapAddressFieldHint,
                      filled: true,
                      fillColor: const Color(0xCC081B4F),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _addressController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                _addressController.clear();
                                setState(() {
                                  _suggestions = [];
                                  _showSuggestions = false;
                                });
                              },
                            )
                          : IconButton(
                              icon: const Icon(Icons.arrow_forward),
                              onPressed: () {
                                setState(() {
                                  _showSuggestions = false;
                                });
                                _searchAddress(_addressController.text);
                              },
                            ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (_isNavigating) ...[
            // ── Turn instruction banner ─ Waze-style top panel ─────────────
            if (_nextManeuverText.isNotEmpty)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                    child: Container(
                      // Urgency tint improves readability during close/complex turns.
                      // Major apps shift color closer to maneuver for attention.
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black54,
                            blurRadius: 16,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Builder(
                            builder: (_) {
                              final accent = _maneuverAccentColor(
                                _distToNextManeuver,
                                _nextManeuverSign,
                              );
                              return Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.36),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: accent.withValues(alpha: 0.9),
                                    width: 1.2,
                                  ),
                                ),
                                child: Icon(
                                  _turnIcon(_nextManeuverSign),
                                  color: Colors.white,
                                  size: 44,
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Builder(
                              builder: (_) {
                                final accent = _maneuverAccentColor(
                                  _distToNextManeuver,
                                  _nextManeuverSign,
                                );
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: accent,
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        l10n.mapManeuverInDistance(
                                          _formatManeuverDistance(
                                            _distToNextManeuver,
                                          ),
                                        ),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.1,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 7),
                                    Text(
                                      _localizedManeuverPrimaryText(
                                        l10n,
                                        _nextManeuverSign,
                                        _nextManeuverText,
                                      ),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        height: 1.2,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (_maneuverTargetFromText(
                                          _nextManeuverText,
                                        ) !=
                                        null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          l10n.mapManeuverTowardRoad(
                                            _maneuverTargetFromText(
                                              _nextManeuverText,
                                            )!,
                                          ),
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Proximity alert banner
            if (_nearbyAlert != null && _currentLocation != null)
              Positioned(
                top: _nextManeuverText.isNotEmpty ? 165 : 12,
                left: 0,
                right: 0,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xEEF57F17),
                      border: Border(
                        bottom: BorderSide(color: Color(0x66FFCC02), width: 1),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Text(
                          _nearbyAlert!.type.emoji,
                          style: const TextStyle(fontSize: 22),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Builder(
                            builder: (ctx) {
                              final l10n = AppLocalizations.of(ctx)!;
                              return Text(
                                l10n.reportAlertNearby(
                                  _nearbyAlert!.type.localizedLabel(l10n),
                                  _nearbyAlert!
                                      .distanceTo(_currentLocation!)
                                      .round()
                                      .toString(),
                                ),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              );
                            },
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _nearbyAlert = null),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white70,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],

          // Right-side floating buttons
          Positioned(
            right: 14,
            bottom: 155,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 2D / 3D toggle
                _mapCircleButton(
                  onTap: () {
                    setState(() => _use3DMap = !_use3DMap);
                    UserPreferencesService.instance.use3DMap.value = _use3DMap;
                  },
                  child: Text(
                    _use3DMap ? l10n.mapModeLabel3d : l10n.mapModeLabel2d,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Light / Dark map style toggle
                _mapCircleButton(
                  onTap: () => setState(() => _useDarkMap = !_useDarkMap),
                  child: Icon(
                    _useDarkMap ? Icons.dark_mode : Icons.light_mode,
                    color: Colors.white70,
                    size: 19,
                  ),
                ),
                const SizedBox(height: 8),
                // Voice navigation toggle
                ValueListenableBuilder<bool>(
                  valueListenable: TtsService.instance.enabled,
                  builder: (context, ttsOn, _) {
                    return _mapCircleButton(
                      onTap: () {
                        final wasOff = !ttsOn;
                        TtsService.instance.enabled.value = !ttsOn;
                        if (wasOff && TtsService.instance.consumeVoiceHint()) {
                          final l10n = AppLocalizations.of(context)!;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.ttsVoiceHint),
                              duration: const Duration(seconds: 8),
                              action: SnackBarAction(
                                label: l10n.ttsVoiceHintDismiss,
                                onPressed: () => ScaffoldMessenger.of(
                                  context,
                                ).hideCurrentSnackBar(),
                              ),
                            ),
                          );
                        }
                      },
                      child: Icon(
                        ttsOn ? Icons.volume_up : Icons.volume_off,
                        color: Colors.white70,
                        size: 19,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                // Report alert button
                _mapCircleButton(
                  onTap: _showReportAlertSheet,
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFF57F17),
                    size: 19,
                  ),
                ),
              ],
            ),
          ),

          // Re-center button — appears when user pans away during navigation.
          if (_isNavigating && !_isFollowing)
            Positioned(
              right: 14,
              bottom: 345,
              child: GestureDetector(
                onTap: () {
                  setState(() => _isFollowing = true);
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xEE0A1F63),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF3AA8FF),
                      width: 1.5,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black45,
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.my_location,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          // ── Current street name pill ────────────────────────────────
          if (_isNavigating && _currentStreetName.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom:
                  (_destination != null ||
                      _routePoints.isNotEmpty ||
                      _isRouting)
                  ? 165
                  : 100,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    _currentStreetName,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          // ── Navigation bottom panel (Apple Maps dark) ──────────────────
          if (_destination != null || _routePoints.isNotEmpty || _isRouting)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black87,
                      blurRadius: 20,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    child: ValueListenableBuilder<SpeedUnit>(
                      valueListenable: preferences.speedUnit,
                      builder: (context, speedUnit, _) {
                        return ValueListenableBuilder<double>(
                          valueListenable: preferences.maxSpeedKmh,
                          builder: (context, maxSpeedKmh, _) {
                            final roadLimitKmh = _roadSpeedLimitKmh;
                            final effectiveLimitKmh = roadLimitKmh;
                            final over =
                                effectiveLimitKmh != null &&
                                _speedKmh > effectiveLimitKmh;
                            final speedDisplay = preferences.toDisplaySpeed(
                              speedKmh: _speedKmh,
                              unit: speedUnit,
                            );
                            final effectiveLimitDisplay =
                                effectiveLimitKmh == null
                                ? 0.0
                                : preferences.toDisplaySpeed(
                                    speedKmh: effectiveLimitKmh,
                                    unit: speedUnit,
                                  );
                            final roadLimitDisplay = roadLimitKmh == null
                                ? null
                                : preferences.toDisplaySpeed(
                                    speedKmh: roadLimitKmh,
                                    unit: speedUnit,
                                  );
                            final speedRatio = effectiveLimitDisplay > 0
                                ? (speedDisplay / effectiveLimitDisplay).clamp(
                                    0.0,
                                    1.25,
                                  )
                                : 0.0;
                            final hasRoadLimit = roadLimitDisplay != null;
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Drag handle
                                Center(
                                  child: Container(
                                    width: 40,
                                    height: 4,
                                    margin: const EdgeInsets.only(bottom: 14),
                                    decoration: BoxDecoration(
                                      color: Colors.white24,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                                if (_routePoints.isNotEmpty) ...[
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        _RouteStopChip(
                                          icon: Icons.restaurant,
                                          label: l10n.convoyPoiFoodStop,
                                          loading: _isSearchingRouteStops,
                                          onTap: () => _showRouteStopSheet(
                                            title: l10n.convoyPoiFoodStop,
                                            query: 'restaurant food',
                                            icon: Icons.restaurant,
                                          ),
                                        ),
                                        _RouteStopChip(
                                          icon: Icons.local_parking,
                                          label: l10n.convoyPoiParking,
                                          loading: _isSearchingRouteStops,
                                          onTap: () => _showRouteStopSheet(
                                            title: l10n.convoyPoiParking,
                                            query: 'parking',
                                            icon: Icons.local_parking,
                                          ),
                                        ),
                                        _RouteStopChip(
                                          icon: Icons.ev_station,
                                          label: l10n.convoyPoiCharging,
                                          loading: _isSearchingRouteStops,
                                          onTap: () => _showRouteStopSheet(
                                            title: l10n.convoyPoiCharging,
                                            query: 'charging station',
                                            icon: Icons.ev_station,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    if (_isNavigating) ...[
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox(
                                            width: 58,
                                            height: 58,
                                            child: Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                CustomPaint(
                                                  size: const Size(58, 58),
                                                  painter: _SpeedBarsPainter(
                                                    ratio: speedRatio,
                                                    activeColor: over
                                                        ? const Color(
                                                            0xFFFF5A5F,
                                                          )
                                                        : const Color(
                                                            0xFFFF9A2F,
                                                          ),
                                                    inactiveColor: const Color(
                                                      0x40FFFFFF,
                                                    ),
                                                    strokeWidth: 3.6,
                                                    segments: 28,
                                                  ),
                                                ),
                                                Container(
                                                  width: 52,
                                                  height: 52,
                                                  decoration: BoxDecoration(
                                                    color: Colors.black,
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: over
                                                          ? Colors.red
                                                          : Colors.white24,
                                                      width: 2,
                                                    ),
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      speedDisplay
                                                          .toStringAsFixed(0),
                                                      style: TextStyle(
                                                        color: over
                                                            ? Colors.redAccent
                                                            : Colors.white,
                                                        fontSize: 20,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        height: 1.0,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          // EU speed limit sign
                                          Container(
                                            width: 42,
                                            height: 42,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: hasRoadLimit
                                                    ? Colors.red.shade700
                                                    : Colors.grey.shade500,
                                                width: 3.5,
                                              ),
                                            ),
                                            child: Center(
                                              child: Text(
                                                hasRoadLimit
                                                    ? roadLimitDisplay
                                                          .toStringAsFixed(0)
                                                    : '--',
                                                style: TextStyle(
                                                  color: hasRoadLimit
                                                      ? Colors.black
                                                      : Colors.black45,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                  height: 1.0,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 14),
                                    ],
                                    // Destination info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (_destinationLabel.isNotEmpty) ...[
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    _destinationLabel,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      height: 1.2,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (!_isNavigating)
                                                  GestureDetector(
                                                    onTap:
                                                        _showSaveFavoriteSheet,
                                                    child: const Padding(
                                                      padding: EdgeInsets.only(
                                                        left: 6,
                                                      ),
                                                      child: Icon(
                                                        Icons.star_border,
                                                        color: Color(
                                                          0xFFFFB800,
                                                        ),
                                                        size: 22,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                          ],
                                          if (_routeStop != null &&
                                              _routeStopLabel.isNotEmpty) ...[
                                            Container(
                                              margin: const EdgeInsets.only(
                                                bottom: 5,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 9,
                                                    vertical: 5,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF303438),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    Icons.add_location_alt,
                                                    color: Color(0xFF3AA8FF),
                                                    size: 16,
                                                  ),
                                                  const SizedBox(width: 5),
                                                  Flexible(
                                                    child: Text(
                                                      _routeStopLabel,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  GestureDetector(
                                                    onTap: _removeRouteStop,
                                                    child: const Icon(
                                                      Icons.close,
                                                      color: Colors.white54,
                                                      size: 16,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                          Row(
                                            children: [
                                              if (_isRouting)
                                                const Padding(
                                                  padding: EdgeInsets.only(
                                                    right: 6,
                                                  ),
                                                  child: SizedBox(
                                                    width: 12,
                                                    height: 12,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: Colors.white54,
                                                        ),
                                                  ),
                                                ),
                                              Expanded(
                                                child: Text(
                                                  _routingStatus,
                                                  style: const TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 14,
                                                  ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Action button
                                    if (_routePoints.isNotEmpty)
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          _isNavigating
                                              ? GestureDetector(
                                                  onTap: _clearRoute,
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 18,
                                                          vertical: 13,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                        0xFFD32F2F,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            14,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      l10n.mapEndNavigation,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 15,
                                                      ),
                                                    ),
                                                  ),
                                                )
                                              : GestureDetector(
                                                  onTap: () {
                                                    final vt =
                                                        UserPreferencesService
                                                            .instance
                                                            .vehicleType
                                                            .value;
                                                    SlowRoadService.instance
                                                        .startSession(vt);
                                                    setState(() {
                                                      _isNavigating = true;
                                                      _isFollowing = true;
                                                      _tripStartTime =
                                                          DateTime.now();
                                                      _tripDistanceM = 0;
                                                      _lastNavPos =
                                                          _currentLocation;
                                                    });
                                                  },
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 18,
                                                          vertical: 13,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                        0xFF00913F,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            14,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      l10n.mapStartNavigation,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 15,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                          if (!_isNavigating) ...[
                                            const SizedBox(height: 8),
                                            GestureDetector(
                                              onTap: _clearRoute,
                                              child: Text(
                                                l10n.authCancel,
                                                style: TextStyle(
                                                  color: Colors.white38,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                            if (!kReleaseMode) ...[
                                              const SizedBox(height: 8),
                                              GestureDetector(
                                                onTap: _startSimulation,
                                                child: Text(
                                                  l10n.mapSimulateButton,
                                                  style: TextStyle(
                                                    color: Colors.white38,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ],
                                      ),
                                  ],
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
// ── Inline report-alert bottom sheet ─────────────────────────────────────────

class _InlineReportSheet extends StatefulWidget {
  const _InlineReportSheet({
    required this.position,
    required this.controller,
    required this.onSubmitted,
  });

  final LatLng position;
  final AlertsController controller;
  final VoidCallback onSubmitted;

  @override
  State<_InlineReportSheet> createState() => _InlineReportSheetState();
}

class _InlineReportSheetState extends State<_InlineReportSheet> {
  AlertType? _selected;
  bool _submitting = false;

  Future<void> _submit() async {
    if (_selected == null) return;
    setState(() => _submitting = true);
    try {
      await widget.controller.submit(
        type: _selected!,
        position: widget.position,
        description: '',
      );
      widget.onSubmitted();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.alertReportFailed)));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF071739),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: Color(0x443AA8FF), width: 1)),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Builder(
            builder: (ctx) {
              final l10n = AppLocalizations.of(ctx)!;
              return Text(
                l10n.reportAlertTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          Builder(
            builder: (ctx) {
              final l10n = AppLocalizations.of(ctx)!;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AlertType.values.map((t) {
                  final sel = _selected == t;
                  return GestureDetector(
                    onTap: () => setState(() => _selected = t),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: sel
                            ? const Color(0xFF1E6BFF)
                            : const Color(0xFF0A1A46),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: sel ? const Color(0xFF3AA8FF) : Colors.white24,
                        ),
                      ),
                      child: Text(
                        '${t.emoji}  ${t.localizedLabel(l10n)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 16),
          Builder(
            builder: (ctx) {
              final l10n = AppLocalizations.of(ctx)!;
              return SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_selected == null || _submitting)
                      ? null
                      : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E6BFF),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          l10n.reportAlertSubmit,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FavPreset {
  final String key;
  final IconData icon;
  final String label;
  const _FavPreset(this.key, this.icon, this.label);
}

class _RouteStopCandidate {
  const _RouteStopCandidate({
    required this.title,
    required this.subtitle,
    required this.position,
    required this.routeDistanceMeters,
    required this.distanceFromMeMeters,
    required this.routeIndex,
    required this.isAhead,
  });

  final String title;
  final String subtitle;
  final LatLng position;
  final double routeDistanceMeters;
  final double distanceFromMeMeters;
  final int routeIndex;
  final bool isAhead;
}

class _RouteStopChip extends StatelessWidget {
  const _RouteStopChip({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.loading,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: loading ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFF303438),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF3AA8FF),
                  ),
                )
              else
                Icon(icon, color: const Color(0xFF3AA8FF), size: 18),
              const SizedBox(width: 7),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpeedBarsPainter extends CustomPainter {
  final double ratio;
  final Color activeColor;
  final Color inactiveColor;
  final double strokeWidth;
  final int segments;

  const _SpeedBarsPainter({
    required this.ratio,
    required this.activeColor,
    required this.inactiveColor,
    required this.strokeWidth,
    required this.segments,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (math.min(size.width, size.height) / 2) - strokeWidth;
    if (radius <= 0 || segments <= 0) return;

    final rect = Rect.fromCircle(center: center, radius: radius);
    final totalSweep = math.pi * 2;
    // Start at the top (12 o'clock), then fill clockwise.
    const start = -math.pi / 2;
    final normalized = ratio.clamp(0.0, 1.0);
    const gap = 0.06;
    final segSweep = (totalSweep - (segments - 1) * gap) / segments;
    final activeCount = (normalized * segments).round();

    for (int i = 0; i < segments; i++) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = i < activeCount ? activeColor : inactiveColor;
      final segStart = start + i * (segSweep + gap);
      canvas.drawArc(rect, segStart, segSweep, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SpeedBarsPainter oldDelegate) {
    return oldDelegate.ratio != ratio ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.segments != segments;
  }
}
