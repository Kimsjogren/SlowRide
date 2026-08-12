import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:slowride/l10n/app_localizations.dart';
import 'package:slowride/core/constants/backend_config.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:slowride/services/destination_history_service.dart';
import 'package:slowride/services/mapbox_search_service.dart';
import 'package:slowride/services/apple_map_search_service.dart';
import 'package:slowride/services/ad_service.dart';
import 'package:slowride/services/navigation_request_service.dart';
import 'package:slowride/services/osm_speed_bump_service.dart';
import 'package:slowride/services/routing_service.dart';
import 'package:slowride/services/slow_road_service.dart';
import 'package:slowride/services/speed_calibration_service.dart';
import 'package:slowride/services/user_preferences_service.dart';
import 'package:slowride/services/favorite_places_service.dart';
import 'package:slowride/models/country_vehicle_rules.dart';
import 'package:slowride/features/alerts/alerts_controller.dart';
import 'package:slowride/features/paywall/paywall_screen.dart';
import 'package:slowride/models/alert_model.dart';
import 'package:slowride/models/studded_tire_zones.dart';
import 'package:slowride/services/carplay_bridge_service.dart';
import 'package:slowride/services/charging_station_service.dart';
import 'package:slowride/widgets/apple_map_widget.dart';
import 'package:slowride/widgets/map_widget.dart';
import 'package:slowride/widgets/accessible_tap_target.dart';
import 'package:slowride/widgets/vector_map_widget.dart';
import 'package:slowride/services/trafikverket_service.dart';
import 'package:slowride/services/subscription_service.dart';
import 'package:slowride/services/tts_service.dart';
import 'package:slowride/services/ai_route_analysis_service.dart';
import 'package:slowride/services/supabase_service.dart';
import 'package:slowride/features/auth/login_screen.dart';
import 'package:slowride/widgets/cruizx_ai_dialog_style.dart';
import 'package:slowride/widgets/navigation_eta_badge.dart';

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
  StreamSubscription<CompassEvent>? _compassSubscription;
  double _speedKmh = 0;
  LatLng? _currentLocation;
  double? _deviceCompassHeading;

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
  bool _isNavigationPanelExpanded = false;
  // true = camera locked on user (like Waze follow mode)
  bool _isFollowing = false;
  bool _useVectorMap = false;
  bool _use3DMap = true;
  bool _useDarkMap = true;
  // When true, the map style follows time of day; a manual toggle disables it.
  bool _autoMapTheme = true;
  LatLng? _destination;
  String _destinationLabel = '';
  LatLng? _routeStop;
  String _routeStopLabel = '';
  List<LatLng> _routePoints = const [];
  RouteResult? _activeRoute;
  bool _isAiAnalyzing = false;
  bool _isAiLoadingDialogVisible = false;
  bool _analyzeNextSelectedRouteWithAi = false;
  bool _aiDestinationSelectionStarted = false;
  String? _searchingRouteStopKey;

  // ── Turn-by-turn instructions ─────────────────────────────────────
  List<RouteInstruction> _instructions = const [];
  int _nextManeuverSign = 0;
  String _nextManeuverText = '';
  String _nextManeuverStreetName = '';
  double _distToNextManeuver = 0;
  String _lastSpokenManeuver = '';
  bool _spokenEarlyWarning = false;
  String _currentStreetName = '';

  // ── Speed calibration + live ETA ──────────────────────────────────
  // Cumulative distance from route start to each point (metres).
  List<double> _cumulativeDist = const [];
  double _totalRouteDistM = 0;
  double _remainingDistM = 0;
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

  /// Valhalla has no native "high speed bump" costing option. For low
  /// vehicles, route around community-reported bumps as excluded locations.
  Future<List<LatLng>> _lowVehicleBumpAvoidLocations({
    required LatLng origin,
    required LatLng destination,
    LatLng? waypoint,
  }) async {
    if (UserPreferencesService.instance.vehicleType.value != 'Low vehicle') {
      return const [];
    }
    return OsmSpeedBumpService.instance.avoidLocationsForRoute(
      origin: origin,
      destination: destination,
      waypoint: waypoint,
      knownAlerts: _alerts,
    );
  }

  // EV charging stations (fetched when isElectric is on).
  List<LatLng> _chargingStations = const [];
  // Nearest alert within 400 m while navigating (for proximity warning).
  AlertModel? _nearbyAlert;
  AlertModel? _dismissedNearbyAlert;
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
  double _simCurrentSpeedKmh = 0; // varies realistically during simulation
  double _simMaxSpeedKmh = 30;
  static const Duration _simInterval = Duration(milliseconds: 200);

  bool _countryAutoDetected = false;
  bool _localizedDefaultsSet = false;
  int _mapViewEpoch = 0;

  bool get _usingAppleMapKit =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  bool get _supportsVectorMapOnCurrentPlatform => !_usingAppleMapKit;

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
    _startCompassTracking();
    // Delay until after first frame so AppLocalizations/context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startLocationTracking();
    });
    NavigationRequestService.instance.pendingDestination.addListener(
      _onExternalNavigationRequest,
    );
    NavigationRequestService.instance.stopNavigationRequests.addListener(
      _onExternalNavigationStopRequest,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onExternalNavigationRequest();
    });
    _use3DMap = UserPreferencesService.instance.use3DMap.value;
    // iOS now always uses MapKit, so the vector-map preference only applies
    // on platforms where the MapLibre path is still available.
    _useVectorMap =
        _supportsVectorMapOnCurrentPlatform &&
        UserPreferencesService.instance.useVectorMap.value;
    if (_supportsVectorMapOnCurrentPlatform) {
      UserPreferencesService.instance.useVectorMap.addListener(
        _onUseVectorMapChanged,
      );
    }
    // Auto-pick a dark map at night and a light map during the day.
    _useDarkMap = _isNightTime();
    // Lazy-load prefs for speed calibration (fire-and-forget).
    SpeedCalibrationService.instance.initialize();
    FavoritePlacesService.instance.initialize();
    DestinationHistoryService.instance.initialize();
    // Start community alerts polling (immediate + every 30 s).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadAlerts();
    });
    _alertsTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _loadAlerts();
      if (mounted) _loadChargingStations();
      if (mounted && _autoMapTheme) {
        final night = _isNightTime();
        if (night != _useDarkMap) setState(() => _useDarkMap = night);
      }
    });
  }

  // Dark map between sunset and sunrise at the current location. Falls back to
  // 19:00–06:59 when there's no GPS fix yet or during polar day/night.
  bool _isNightTime() {
    final now = DateTime.now();
    final loc = _currentLocation;
    if (loc != null) {
      final sun = _sunriseSunset(now, loc.latitude, loc.longitude);
      if (sun != null) {
        final nowUtc = now.toUtc();
        return nowUtc.isBefore(sun.$1) || nowUtc.isAfter(sun.$2);
      }
    }
    final hour = now.hour;
    return hour < 7 || hour >= 19;
  }

  // Sunrise/sunset (UTC) via the standard sunrise equation. Returns null at
  // high latitudes when the sun never rises/sets on the given day.
  (DateTime, DateTime)? _sunriseSunset(DateTime date, double lat, double lng) {
    const deg = math.pi / 180;
    const zenith = 90.833 * deg;
    final n = date.difference(DateTime(date.year, 1, 1)).inDays + 1;
    final lngHour = lng / 15.0;
    final sinLat = math.sin(lat * deg);
    final cosLat = math.cos(lat * deg);

    DateTime? compute(bool rise) {
      final t = n + ((rise ? 6 : 18) - lngHour) / 24;
      final m = 0.9856 * t - 3.289;
      var l =
          m +
          1.916 * math.sin(m * deg) +
          0.020 * math.sin(2 * m * deg) +
          282.634;
      l %= 360;
      var ra = math.atan(0.91764 * math.tan(l * deg)) / deg;
      ra %= 360;
      ra += ((l / 90).floor() - (ra / 90).floor()) * 90;
      ra /= 15;
      final sinDec = 0.39782 * math.sin(l * deg);
      final cosDec = math.cos(math.asin(sinDec));
      final cosH = (math.cos(zenith) - sinDec * sinLat) / (cosDec * cosLat);
      if (cosH > 1 || cosH < -1) return null; // sun never rises/sets
      final h =
          (rise ? 360 - math.acos(cosH) / deg : math.acos(cosH) / deg) / 15;
      final ut = (h + ra - 0.06571 * t - 6.622 - lngHour) % 24;
      final mins = (((ut + 24) % 24) * 60).round();
      return DateTime.utc(
        date.year,
        date.month,
        date.day,
      ).add(Duration(minutes: mins));
    }

    final sunrise = compute(true);
    final sunset = compute(false);
    if (sunrise == null || sunset == null) return null;
    return (sunrise, sunset);
  }

  void _onExternalNavigationRequest() {
    final request = NavigationRequestService.instance.pendingDestination.value;
    if (request != null) {
      final label = request.label?.trim() ?? '';
      final address = request.address?.trim() ?? '';
      if (label.isNotEmpty || address.isNotEmpty) {
        _addressController.text = address.isNotEmpty ? address : label;
        _destinationLabel = label.isNotEmpty ? label : address;
        _searchFocus.unfocus();
      }
      NavigationRequestService.instance.consume();
      _handleMapTap(request.destination);
    }
  }

  void _onExternalNavigationStopRequest() {
    if (!mounted) return;
    if (_activeRoute == null && _destination == null && !_isNavigating) {
      return;
    }
    _clearRoute();
  }

  Future<void> _loadAlerts() async {
    final center = _currentLocation;
    if (center == null) return;
    try {
      final osmBumps =
          UserPreferencesService.instance.vehicleType.value == 'Low vehicle'
          ? OsmSpeedBumpService.instance.fetchNearby(center)
          : Future.value(const <AlertModel>[]);
      final futures = <Future<List<AlertModel>>>[
        _alertsController.fetchNearby(center),
        TrafikverketService.instance.fetchNearby(center),
        osmBumps,
      ];
      final results = await Future.wait(futures);
      if (!mounted) return;
      final combined = [...results[0], ...results[1], ...results[2]];
      setState(() => _alerts = combined);
    } catch (_) {}
  }

  Future<void> _loadChargingStations() async {
    if (!UserPreferencesService.instance.isElectric.value) {
      if (_chargingStations.isNotEmpty) {
        setState(() => _chargingStations = const []);
      }
      return;
    }
    final center = _currentLocation;
    if (center == null) return;
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

  void _applyGpsPosition(Position position, {required bool hadLocation}) {
    if (!mounted || _isSimulating) return;

    final currentPos = LatLng(position.latitude, position.longitude);
    final newSpeed = (position.speed < 0 ? 0 : position.speed) * 3.6;
    final heading = (position.speed > 0.5 && position.heading >= 0)
        ? position.heading
        : _headingNotifier.value;

    _processLocationUpdate(currentPos, newSpeed, heading);

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

    unawaited(_loadAlerts());
    unawaited(_loadChargingStations());

    if (!hadLocation &&
        _destination != null &&
        _routePoints.isEmpty &&
        !_isRouting) {
      _handleMapTap(_destination!);
    }
  }

  Future<LatLng?> _ensureCurrentLocation({bool forceRefresh = false}) async {
    final existing = _currentLocation;
    if (existing != null && !forceRefresh) return existing;

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          timeLimit: Duration(seconds: 8),
        ),
      );
      _applyGpsPosition(position, hadLocation: false);
      return LatLng(position.latitude, position.longitude);
    } catch (_) {
      return _currentLocation;
    }
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

      try {
        final hadLocation = _currentLocation != null;
        final currentPosition = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            timeLimit: Duration(seconds: 8),
          ),
        );
        _applyGpsPosition(currentPosition, hadLocation: hadLocation);
      } catch (_) {
        try {
          final lastPosition = await Geolocator.getLastKnownPosition();
          final lastPositionAge = lastPosition == null
              ? null
              : DateTime.now().difference(lastPosition.timestamp);
          final isRecentAndAccurate =
              lastPosition != null &&
              lastPositionAge != null &&
              !lastPositionAge.isNegative &&
              lastPositionAge <= const Duration(minutes: 2) &&
              lastPosition.accuracy <= 100;
          if (isRecentAndAccurate) {
            _applyGpsPosition(
              lastPosition,
              hadLocation: _currentLocation != null,
            );
          }
        } catch (_) {}
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
            final hadLocation = _currentLocation != null;
            _applyGpsPosition(position, hadLocation: hadLocation);
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
    NavigationRequestService.instance.stopNavigationRequests.removeListener(
      _onExternalNavigationStopRequest,
    );
    _locationNotifier.dispose();
    _headingNotifier.dispose();
    _addressController.dispose();
    _searchFocus.dispose();
    _debounce?.cancel();
    _simTimer?.cancel();
    _alertsTimer?.cancel();
    _positionSubscription?.cancel();
    _compassSubscription?.cancel();
    if (_supportsVectorMapOnCurrentPlatform) {
      UserPreferencesService.instance.useVectorMap.removeListener(
        _onUseVectorMapChanged,
      );
    }
    super.dispose();
  }

  void _startCompassTracking() {
    _compassSubscription = FlutterCompass.events?.listen((event) {
      final rawHeading = event.heading;
      if (!mounted || rawHeading == null || !rawHeading.isFinite) return;

      final normalizedHeading = (rawHeading % 360 + 360) % 360;
      final previousHeading = _deviceCompassHeading;
      if (previousHeading == null) {
        _deviceCompassHeading = normalizedHeading;
      } else if (_usingAppleMapKit) {
        // Keep iOS heading calm enough to avoid sensor jitter while the native
        // marker animation handles the visual smoothing.
        final shortestTurn =
            ((normalizedHeading - previousHeading + 540) % 360) - 180;
        _deviceCompassHeading =
            (previousHeading + shortestTurn * 0.36 + 360) % 360;
      } else {
        final shortestTurn =
            ((normalizedHeading - previousHeading + 540) % 360) - 180;
        _deviceCompassHeading =
            (previousHeading + shortestTurn * 0.32 + 360) % 360;
      }

      // Outside follow mode, only use the live device compass while nearly
      // stationary. Once we're moving, route/GPS heading should drive the
      // marker so it tracks travel direction instead of phone tilt.
      if (!_isFollowing &&
          (_usingAppleMapKit || !_useVectorMap) &&
          _speedKmh <= 6.0) {
        _headingNotifier.value = _deviceCompassHeading!;
      }
    });
  }

  void _onUseVectorMapChanged() {
    if (mounted) {
      setState(
        () => _useVectorMap =
            _supportsVectorMapOnCurrentPlatform &&
            UserPreferencesService.instance.useVectorMap.value,
      );
    }
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
      'es': 'es',
      'it': 'it',
    };
    return map[appLang] ?? 'sv';
  }

  Future<List<Map<String, dynamic>>> _fetchMapboxResults(
    String query, {
    int limit = 10,
    LatLng? proximity,
    bool useProximity = true,
  }) async {
    final token = BackendConfig.mapboxAccessToken.trim();
    if (token.isEmpty) return const [];

    final prox = useProximity ? (proximity ?? _currentLocation) : null;
    return MapboxSearchService.search(
      query,
      accessToken: token,
      language: _mapboxLanguageCode(),
      countryCodes: CountryVehicleRules.supportedCountries,
      proximity: prox,
      limit: limit,
    );
  }

  Future<List<Map<String, dynamic>>> _fetchPrimaryGeocodingResults(
    String query, {
    int limit = 15,
    LatLng? proximity,
    bool includeGlobalResults = true,
  }) async {
    final effectiveProximity = proximity ?? _currentLocation;
    if (AppleMapSearchService.isSupported) {
      var appleResults = await AppleMapSearchService.search(
        query,
        proximity: effectiveProximity,
        limit: limit,
      );
      if (appleResults.isEmpty &&
          includeGlobalResults &&
          effectiveProximity != null) {
        appleResults = await AppleMapSearchService.search(
          query,
          limit: limit,
        );
      }
      if (appleResults.isNotEmpty) {
        return appleResults;
      }
    }

    var raw = await _fetchMapboxResults(
      query,
      limit: limit,
      proximity: proximity,
    );
    if (raw.isEmpty && includeGlobalResults && effectiveProximity != null) {
      raw = await _fetchMapboxResults(query, limit: limit, useProximity: false);
    }
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
          '${lon - 0.35},${lat + 0.35},${lon + 0.35},${lat - 0.35}';
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

  List<({String key, String values})> _overpassFiltersForQueries(
    List<String> queries,
  ) {
    final normalized = queries.map(_normalizeSearchText).join(' ');
    final filters = <({String key, String values})>[];

    void add(String key, String values) {
      if (!filters.any((f) => f.key == key && f.values == values)) {
        filters.add((key: key, values: values));
      }
    }

    if (normalized.contains('grocery') ||
        normalized.contains('supermarket') ||
        normalized.contains('livsmedel')) {
      add('shop', 'supermarket|convenience|greengrocer|deli|general|organic');
    }
    if (normalized.contains('restaurant') ||
        normalized.contains('food') ||
        normalized.contains('fast food') ||
        normalized.contains('mat')) {
      add('amenity', 'restaurant|fast_food|food_court');
      add('shop', 'deli');
    }
    if (normalized.contains('cafe') ||
        normalized.contains('coffee') ||
        normalized.contains('kafe')) {
      add('amenity', 'cafe');
      add('shop', 'bakery');
    }
    if (normalized.contains('fuel') ||
        normalized.contains('gas station') ||
        normalized.contains('petrol') ||
        normalized.contains('bensinstation')) {
      add('amenity', 'fuel');
    }
    if (normalized.contains('charging') ||
        normalized.contains('laddstation') ||
        normalized.contains('ev charging')) {
      add('amenity', 'charging_station');
    }
    if (normalized.contains('parking') || normalized.contains('parkering')) {
      add('amenity', 'parking');
    }

    return filters;
  }

  Future<List<Map<String, dynamic>>> _fetchOverpassPoiResults({
    required List<String> queries,
    required LatLng center,
    int radiusMeters = 5000,
  }) async {
    final filters = _overpassFiltersForQueries(queries);
    if (filters.isEmpty) return const [];

    final clauses = <String>[];
    for (final filter in filters) {
      for (final type in const ['node', 'way', 'relation']) {
        clauses.add(
          '$type(around:$radiusMeters,${center.latitude},${center.longitude})'
          '["${filter.key}"~"^(${filter.values})\$"];',
        );
      }
    }

    final query =
        '[out:json][timeout:10];(${clauses.join()});out center 300 qt;';

    try {
      final response = await http
          .post(
            Uri.https('overpass-api.de', '/api/interpreter'),
            headers: const {
              'Content-Type':
                  'application/x-www-form-urlencoded; charset=UTF-8',
              'Accept': 'application/json',
              'User-Agent': 'CruizX/1.0 (nearby-poi-search)',
            },
            body: 'data=${Uri.encodeQueryComponent(query)}',
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return const [];

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final elements =
          (decoded['elements'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          const <Map<String, dynamic>>[];

      final results = <Map<String, dynamic>>[];
      for (final element in elements) {
        final tags = element['tags'] as Map<String, dynamic>? ?? const {};
        if (!_includeOverpassPoi(tags, queries: queries)) continue;
        final lat =
            (element['lat'] as num?)?.toDouble() ??
            ((element['center'] as Map?)?['lat'] as num?)?.toDouble();
        final lon =
            (element['lon'] as num?)?.toDouble() ??
            ((element['center'] as Map?)?['lon'] as num?)?.toDouble();
        if (lat == null || lon == null) continue;

        final name = _overpassPoiTitle(tags, queries: queries);
        final brand = (tags['brand'] ?? '').toString().trim();
        final operator = (tags['operator'] ?? '').toString().trim();
        final network = (tags['network'] ?? '').toString().trim();
        final category = (tags['amenity'] ?? tags['shop'] ?? '')
            .toString()
            .trim();
        final street = (tags['addr:street'] ?? '').toString().trim();
        final houseNumber = (tags['addr:housenumber'] ?? '').toString().trim();
        final city = (tags['addr:city'] ?? tags['addr:suburb'] ?? '')
            .toString()
            .trim();
        final addressParts = <String>[
          if (street.isNotEmpty)
            houseNumber.isNotEmpty ? '$street $houseNumber' : street,
          if (city.isNotEmpty) city,
        ];
        final address = <String, String>{
          if (street.isNotEmpty) 'road': street,
          if (houseNumber.isNotEmpty) 'house_number': houseNumber,
          if (city.isNotEmpty) 'city': city,
        };

        results.add({
          'lat': lat,
          'lon': lon,
          'place_id': '${element['type']}_${element['id']}',
          'importance': 1.0,
          'name': name.isNotEmpty ? name : queries.first,
          'category': category,
          'brand': brand,
          'operator': operator,
          'network': network,
          'display_name': [
            if (name.isNotEmpty) name,
            if (addressParts.isNotEmpty) addressParts.join(', '),
          ].join(', '),
          'address': address,
          '_source': 'overpass',
        });
      }
      return results;
    } catch (_) {
      return const [];
    }
  }

  bool _includeOverpassPoi(
    Map<String, dynamic> tags, {
    required List<String> queries,
  }) {
    final normalized = queries.map(_normalizeSearchText).join(' ');
    final amenity = _normalizeSearchText((tags['amenity'] ?? '').toString());
    final shop = _normalizeSearchText((tags['shop'] ?? '').toString());
    final access = _normalizeSearchText((tags['access'] ?? '').toString());
    final motorcar = _normalizeSearchText((tags['motorcar'] ?? '').toString());
    final name = (tags['name'] ?? '').toString().trim();
    final brand = (tags['brand'] ?? '').toString().trim();
    final operator = (tags['operator'] ?? '').toString().trim();
    final network = (tags['network'] ?? '').toString().trim();
    final ref = (tags['ref'] ?? '').toString().trim();
    final street = (tags['addr:street'] ?? '').toString().trim();
    final city = (tags['addr:city'] ?? tags['addr:suburb'] ?? '')
        .toString()
        .trim();
    final hasIdentity = [
      name,
      brand,
      operator,
      network,
      ref,
    ].any((value) => value.isNotEmpty);
    final hasAddress = street.isNotEmpty || city.isNotEmpty;

    final isFoodStop =
        normalized.contains('restaurant') ||
        normalized.contains('food') ||
        normalized.contains('fast food') ||
        normalized.contains('mat');
    if (isFoodStop) {
      if (amenity == 'cafe' ||
          amenity == 'pub' ||
          amenity == 'bar' ||
          shop == 'bakery') {
        return false;
      }
      return hasIdentity;
    }

    final isCharging =
        normalized.contains('charging') ||
        normalized.contains('laddstation') ||
        normalized.contains('ev charging');
    if (isCharging) {
      if (motorcar == 'no') return false;
      if (access == 'private' ||
          access == 'residents' ||
          access == 'no' ||
          access == 'permit') {
        return false;
      }
      return hasIdentity || hasAddress;
    }

    return true;
  }

  String _overpassPoiTitle(
    Map<String, dynamic> tags, {
    required List<String> queries,
  }) {
    final normalized = queries.map(_normalizeSearchText).join(' ');
    final name = (tags['name'] ?? '').toString().trim();
    final brand = (tags['brand'] ?? '').toString().trim();
    final operator = (tags['operator'] ?? '').toString().trim();
    final network = (tags['network'] ?? '').toString().trim();
    final ref = (tags['ref'] ?? '').toString().trim();
    final preferBrand =
        normalized.contains('fuel') ||
        normalized.contains('gas station') ||
        normalized.contains('petrol') ||
        normalized.contains('charging') ||
        normalized.contains('laddstation') ||
        normalized.contains('supermarket') ||
        normalized.contains('grocery') ||
        normalized.contains('livsmedel');

    if (preferBrand) {
      for (final value in [brand, operator, network, name, ref]) {
        if (value.isNotEmpty) return value;
      }
    }

    for (final value in [name, brand, operator, network, ref]) {
      if (value.isNotEmpty) return value;
    }
    if (normalized.contains('charging') ||
        normalized.contains('laddstation') ||
        normalized.contains('ev charging')) {
      return 'Laddstation';
    }
    return queries.first;
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
          ..sort((a, b) {
            final byScore = b.score.compareTo(a.score);
            if (byScore != 0) return byScore;
            final current = _currentLocation;
            if (current != null) {
              double distanceTo(Map<String, dynamic> result) {
                final lat = double.tryParse(result['lat']?.toString() ?? '');
                final lon = double.tryParse(result['lon']?.toString() ?? '');
                if (lat == null || lon == null) return double.infinity;
                return Geolocator.distanceBetween(
                  current.latitude,
                  current.longitude,
                  lat,
                  lon,
                );
              }

              final byDistance = distanceTo(
                a.item,
              ).compareTo(distanceTo(b.item));
              if (byDistance != 0) return byDistance;
            }
            return 0;
          });

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

  void _navigateToHistory(DestinationHistoryEntry entry) {
    _addressController.text = entry.label;
    _destinationLabel = entry.label;
    _searchFocus.unfocus();
    _handleMapTap(entry.position);
  }

  Future<void> _selectSearchSheetSuggestion(
    BuildContext sheetContext,
    Map<String, dynamic> suggestion,
  ) async {
    Navigator.of(sheetContext).pop();
    _selectSuggestion(suggestion);
  }

  Future<void> _openSearchSheetPoi(
    BuildContext sheetContext, {
    required String title,
    required String searchKey,
    required List<String> queries,
    required IconData icon,
  }) async {
    Navigator.of(sheetContext).pop();
    await _showRouteStopSheet(
      title: title,
      searchKey: searchKey,
      queries: queries,
      icon: icon,
    );
  }

  Future<void> _showDestinationSearchSheet() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: _addressController.text);
    Timer? searchDebounce;
    var localSuggestions = <Map<String, dynamic>>[];
    var isSearching = false;

    Future<void> runSearch(String value, StateSetter setSheetState) async {
      final query = value.trim();
      if (query.length < 2) {
        setSheetState(() {
          localSuggestions = [];
          isSearching = false;
        });
        return;
      }
      setSheetState(() => isSearching = true);
      try {
        final raw = await _fetchPrimaryGeocodingResults(query, limit: 15);
        final ranked = _rankAndDedupeSuggestions(raw, query);
        if (!mounted) return;
        setSheetState(() {
          localSuggestions = ranked;
          isSearching = false;
        });
      } catch (_) {
        if (!mounted) return;
        setSheetState(() {
          localSuggestions = [];
          isSearching = false;
        });
      }
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void onChanged(String value) {
              searchDebounce?.cancel();
              searchDebounce = Timer(
                const Duration(milliseconds: 300),
                () => runSearch(value, setSheetState),
              );
            }

            final favorites = FavoritePlacesService.instance.places.value;
            final home = FavoritePlacesService.instance.findByIcon('home');
            final work = FavoritePlacesService.instance.findByIcon('work');
            final school = FavoritePlacesService.instance.findByIcon('school');
            final saved = <FavoritePlace>[
              ...[home, work, school].whereType<FavoritePlace>(),
              ...favorites.where(
                (fav) =>
                    fav.icon != 'home' &&
                    fav.icon != 'work' &&
                    fav.icon != 'school',
              ),
            ];
            final hasQuery = controller.text.trim().isNotEmpty;

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.88,
              minChildSize: 0.58,
              maxChildSize: 0.96,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Color(0xF0071739),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 26),
                    children: [
                      Center(
                        child: Container(
                          width: 48,
                          height: 5,
                          margin: const EdgeInsets.only(bottom: 18),
                          decoration: BoxDecoration(
                            color: Color(0x663AA8FF),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      TextField(
                        controller: controller,
                        autofocus: true,
                        textInputAction: TextInputAction.search,
                        onChanged: onChanged,
                        onSubmitted: (query) {
                          Navigator.of(sheetContext).pop();
                          _addressController.text = query;
                          _searchAddress(query);
                        },
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: l10n.mapAddressFieldHint,
                          hintStyle: const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: const Color(0xEE0A1F63),
                          prefixIcon: IconButton(
                            icon: const Icon(Icons.chevron_left),
                            color: Colors.white54,
                            onPressed: () => Navigator.of(sheetContext).pop(),
                          ),
                          suffixIcon: isSearching
                              ? const Padding(
                                  padding: EdgeInsets.all(14),
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF3AA8FF),
                                    ),
                                  ),
                                )
                              : const Icon(Icons.mic, color: Colors.white70),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(26),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (!hasQuery) ...[
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _SearchShortcutCard(
                                icon: Icons.bookmark,
                                label: l10n.searchSaved,
                              ),
                              _SearchShortcutCard(
                                icon: Icons.ev_station,
                                label: l10n.convoyPoiCharging,
                                onTap: () => _openSearchSheetPoi(
                                  sheetContext,
                                  title: l10n.convoyPoiCharging,
                                  searchKey: 'charging',
                                  queries: const [
                                    'charging station',
                                    'ev charging',
                                    'laddstation',
                                  ],
                                  icon: Icons.ev_station,
                                ),
                              ),
                              _SearchShortcutCard(
                                icon: Icons.restaurant,
                                label: l10n.convoyPoiFoodStop,
                                onTap: () => _openSearchSheetPoi(
                                  sheetContext,
                                  title: l10n.convoyPoiFoodStop,
                                  searchKey: 'food',
                                  queries: const ['restaurant', 'fast food'],
                                  icon: Icons.restaurant,
                                ),
                              ),
                              _SearchShortcutCard(
                                icon: Icons.local_parking,
                                label: l10n.convoyPoiParking,
                                onTap: () => _openSearchSheetPoi(
                                  sheetContext,
                                  title: l10n.convoyPoiParking,
                                  searchKey: 'parking',
                                  queries: const [
                                    'parking',
                                    'car park',
                                    'parkering',
                                  ],
                                  icon: Icons.local_parking,
                                ),
                              ),
                              _SearchShortcutCard(
                                icon: Icons.local_gas_station,
                                label: l10n.routeStopFuel,
                                onTap: () => _openSearchSheetPoi(
                                  sheetContext,
                                  title: l10n.routeStopFuel,
                                  searchKey: 'fuel',
                                  queries: const [
                                    'gas station',
                                    'fuel',
                                    'petrol station',
                                    'bensinstation',
                                  ],
                                  icon: Icons.local_gas_station,
                                ),
                              ),
                              _SearchShortcutCard(
                                icon: Icons.local_cafe,
                                label: l10n.routeStopCafe,
                                onTap: () => _openSearchSheetPoi(
                                  sheetContext,
                                  title: l10n.routeStopCafe,
                                  searchKey: 'cafe',
                                  queries: const ['cafe', 'coffee', 'kafé'],
                                  icon: Icons.local_cafe,
                                ),
                              ),
                              _SearchShortcutCard(
                                icon: Icons.local_grocery_store,
                                label: l10n.routeStopGrocery,
                                onTap: () => _openSearchSheetPoi(
                                  sheetContext,
                                  title: l10n.routeStopGrocery,
                                  searchKey: 'grocery',
                                  queries: const [
                                    'grocery',
                                    'supermarket',
                                    'livsmedel',
                                  ],
                                  icon: Icons.local_grocery_store,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        if (saved.isNotEmpty)
                          ...saved
                              .take(4)
                              .map(
                                (fav) => _SearchDestinationRow(
                                  icon: fav.icon == 'work'
                                      ? Icons.work
                                      : fav.icon == 'school'
                                      ? Icons.school
                                      : fav.icon == 'home'
                                      ? Icons.home
                                      : Icons.star,
                                  title: fav.label,
                                  subtitle: fav.address,
                                  onTap: () {
                                    Navigator.of(sheetContext).pop();
                                    _navigateToFavorite(fav);
                                  },
                                ),
                              ),
                        const SizedBox(height: 14),
                        Text(
                          l10n.searchRecent,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ValueListenableBuilder<List<DestinationHistoryEntry>>(
                          valueListenable:
                              DestinationHistoryService.instance.entries,
                          builder: (context, history, _) {
                            return Column(
                              children: history
                                  .take(8)
                                  .map(
                                    (entry) => _SearchDestinationRow(
                                      icon: Icons.history,
                                      title: entry.label,
                                      subtitle: entry.address,
                                      onTap: () {
                                        Navigator.of(sheetContext).pop();
                                        _navigateToHistory(entry);
                                      },
                                    ),
                                  )
                                  .toList(),
                            );
                          },
                        ),
                      ] else
                        ...localSuggestions.map((suggestion) {
                          final title = _addressTitleFromResult(suggestion);
                          final subtitle = _addressSubtitleFromResult(
                            suggestion,
                          );
                          return _SearchDestinationRow(
                            icon: Icons.location_on,
                            title: title,
                            subtitle: subtitle,
                            onTap: () => _selectSearchSheetSuggestion(
                              sheetContext,
                              suggestion,
                            ),
                          );
                        }),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );

    searchDebounce?.cancel();
    controller.dispose();
  }

  Future<void> _saveDestinationHistory(LatLng destination) async {
    final label = _destinationLabel.trim();
    if (label.isEmpty) return;
    await DestinationHistoryService.instance.add(
      label: label,
      address: _addressController.text.trim(),
      position: destination,
    );
  }

  Future<void> _searchAddress(String rawQuery) async {
    final l10n = AppLocalizations.of(context)!;
    final query = rawQuery.trim();
    if (query.isEmpty) {
      return;
    }
    if (_analyzeNextSelectedRouteWithAi) {
      _aiDestinationSelectionStarted = true;
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
        _cancelPendingAiRouteAnalysis();
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
      _cancelPendingAiRouteAnalysis();
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

    const spacingMeters = 2500.0;
    const maxAnchors = 12;
    var distanceSinceAnchor = 0.0;
    for (var index = start; index < end; index++) {
      distanceSinceAnchor += _segDist(
        _routePoints[index],
        _routePoints[index + 1],
      );
      if (distanceSinceAnchor < spacingMeters && index + 1 < end) continue;
      anchors.add(_routePoints[index + 1]);
      distanceSinceAnchor = 0.0;
      if (anchors.length >= maxAnchors) break;
    }

    final destinationPoint = _routePoints[end];
    if (anchors.isEmpty || _segDist(anchors.last, destinationPoint) > 250) {
      anchors.add(destinationPoint);
    }
    return anchors.toList(growable: false);
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

  double _remainingRouteDistanceToIndex(int routeIndex) {
    if (_routePoints.length < 2) return 0;
    final start = _displayNearestIdx.clamp(0, _routePoints.length - 1);
    final end = routeIndex.clamp(start, _routePoints.length - 1);
    var distance = 0.0;
    for (var index = start; index < end; index++) {
      distance += _segDist(_routePoints[index], _routePoints[index + 1]);
    }
    return distance;
  }

  Future<List<_RouteStopCandidate>> _findStopsAlongRoute({
    required List<String> queries,
    int limit = 20,
  }) async {
    // Max 2 km off-route — tighter than before to keep results relevant.
    const maxDetourFromRouteMeters = 2000.0;
    // Use up to 5 evenly-spaced anchors along the remaining route.
    final anchors = _routeSearchAnchors().take(5).toList();
    final currentLocation = _currentLocation;
    if (anchors.isEmpty || _routePoints.isEmpty || currentLocation == null) {
      return const [];
    }

    // Parallel Overpass POI calls — one per anchor, 3 km radius.
    // This is far more reliable than text geocoding for POI categories.
    final poiLists = await Future.wait(
      anchors.map(
        (anchor) => _fetchOverpassPoiResults(
          queries: queries,
          center: anchor,
          radiusMeters: 3000,
        ),
      ),
    );

    final seen = <String>{};
    final candidates = <_RouteStopCandidate>[];

    for (final poiResults in poiLists) {
      for (final result in poiResults) {
        final lat = double.tryParse(result['lat']?.toString() ?? '');
        final lon = double.tryParse(result['lon']?.toString() ?? '');
        if (lat == null || lon == null) continue;

        final point = LatLng(lat, lon);
        final title = _addressTitleFromResult(result, fallback: queries.first);
        final subtitle = _addressSubtitleFromResult(result);
        final key =
            '${title.toLowerCase()}|${lat.toStringAsFixed(4)},${lon.toStringAsFixed(4)}';
        if (!seen.add(key)) continue;

        final routeDistance = _distanceToRouteMeters(point, _routePoints);
        if (routeDistance > maxDetourFromRouteMeters) continue;
        final routeIndex = _nearestRouteIndexFull(point);
        final isAhead = routeIndex >= (_displayNearestIdx - 5);
        final distanceFromMe = _segDist(currentLocation, point);
        final aheadDistance = isAhead
            ? _remainingRouteDistanceToIndex(routeIndex)
            : double.infinity;
        candidates.add(
          _RouteStopCandidate(
            title: title,
            subtitle: subtitle,
            position: point,
            routeDistanceMeters: routeDistance,
            distanceFromMeMeters: distanceFromMe,
            aheadDistanceMeters: aheadDistance,
            routeIndex: routeIndex,
            isAhead: isAhead,
          ),
        );
      }
    }

    // Sort: ahead-of-me first, then by distance along remaining route.
    candidates.sort((a, b) {
      if (a.isAhead != b.isAhead) return a.isAhead ? -1 : 1;
      return a.aheadDistanceMeters.compareTo(b.aheadDistanceMeters);
    });
    return candidates.take(limit).toList(growable: false);
  }

  double _maxFallbackPoiDistanceMeters(List<String> queries) {
    final normalized = queries.map(_normalizeSearchText).join(' ');
    if (normalized.contains('charging') ||
        normalized.contains('laddstation') ||
        normalized.contains('ev charging')) {
      return 25000;
    }
    if (normalized.contains('parking') || normalized.contains('parkering')) {
      return 12000;
    }
    return 6000;
  }

  Future<List<_RouteStopCandidate>> _findNearbyStops({
    required List<String> queries,
    int limit = 20,
  }) async {
    final currentLocation = await _ensureCurrentLocation(forceRefresh: true);
    if (currentLocation == null) return const [];

    final seen = <String>{};
    final candidates = <_RouteStopCandidate>[];

    void addCandidate(Map<String, dynamic> result, String fallback) {
      final lat = double.tryParse(result['lat']?.toString() ?? '');
      final lon = double.tryParse(result['lon']?.toString() ?? '');
      if (lat == null || lon == null) return;

      final point = LatLng(lat, lon);
      final title = _addressTitleFromResult(result, fallback: fallback);
      final subtitle = _addressSubtitleFromResult(result);
      final key =
          '${title.toLowerCase()}|${lat.toStringAsFixed(4)},${lon.toStringAsFixed(4)}';
      if (!seen.add(key)) return;

      final distanceFromMe = _segDist(currentLocation, point);
      candidates.add(
        _RouteStopCandidate(
          title: title,
          subtitle: subtitle,
          position: point,
          routeDistanceMeters: distanceFromMe,
          distanceFromMeMeters: distanceFromMe,
          aheadDistanceMeters: double.nan,
          routeIndex: 0,
          isAhead: true,
        ),
      );
    }

    // Tiered radius: try 2.5 km first so the result cap (300) easily covers
    // everything nearby. Only expand to 7 km when the area is sparse.
    var poiResults = await _fetchOverpassPoiResults(
      queries: queries,
      center: currentLocation,
      radiusMeters: 2500,
    );
    if (poiResults.length < 5) {
      poiResults = await _fetchOverpassPoiResults(
        queries: queries,
        center: currentLocation,
        radiusMeters: 7000,
      );
    }
    for (final result in poiResults) {
      addCandidate(result, queries.first);
    }
    if (candidates.isNotEmpty) {
      candidates.sort(
        (a, b) => a.distanceFromMeMeters.compareTo(b.distanceFromMeMeters),
      );
      return candidates.take(limit).toList(growable: false);
    }

    final requests = <String>[...queries];
    final responses = await Future.wait(
      requests.map(
        (query) => _fetchPrimaryGeocodingResults(
          query,
          limit: 12,
          proximity: currentLocation,
          includeGlobalResults: false,
        ),
      ),
    );

    for (
      var responseIndex = 0;
      responseIndex < responses.length;
      responseIndex++
    ) {
      final query = requests[responseIndex];
      for (final result in responses[responseIndex]) {
        addCandidate(result, query);
      }
    }

    candidates.sort(
      (a, b) => a.distanceFromMeMeters.compareTo(b.distanceFromMeMeters),
    );
    final maxFallbackDistance = _maxFallbackPoiDistanceMeters(queries);
    return candidates
        .where(
          (candidate) => candidate.distanceFromMeMeters <= maxFallbackDistance,
        )
        .take(limit)
        .toList(growable: false);
  }

  String _formatStopDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  Future<void> _showRouteStopSheet({
    required String title,
    required String searchKey,
    required List<String> queries,
    required IconData icon,
  }) async {
    final ensuredLocation = await _ensureCurrentLocation();
    if (ensuredLocation == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.mapWaitingForGps),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    if (!mounted) return;
    final hasActiveRoute = _destination != null && _routePoints.isNotEmpty;
    setState(() => _searchingRouteStopKey = searchKey);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _RouteStopResultsSheet(
        title: title,
        icon: icon,
        hasActiveRoute: hasActiveRoute,
        loadCandidates: () => hasActiveRoute
            ? _findStopsAlongRoute(queries: queries)
            : _findNearbyStops(queries: queries),
        formatStopDistance: _formatStopDistance,
        onCandidateSelected: (candidate) {
          if (hasActiveRoute) {
            _selectRouteStop(candidate);
          } else {
            _selectStopAsDestination(candidate);
          }
        },
      ),
    );

    if (mounted) {
      setState(() => _searchingRouteStopKey = null);
    }
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
        avoidLocations: await _lowVehicleBumpAvoidLocations(
          origin: current,
          destination: destination,
          waypoint: candidate.position,
        ),
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

  void _selectStopAsDestination(_RouteStopCandidate candidate) {
    _addressController.text = candidate.title;
    _destinationLabel = candidate.title;
    _searchFocus.unfocus();
    _handleMapTap(candidate.position);
  }

  Future<RouteResult?> _tryRelaxedRoute({
    required LatLng destination,
    required String vehicleType,
  }) async {
    final origin = _currentLocation;
    if (origin == null) return null;

    try {
      return await _routingService.getRoute(
        origin: origin,
        destination: destination,
        vehicleType: vehicleType,
        relaxedLegalChecks: true,
        avoidLocations: await _lowVehicleBumpAvoidLocations(
          origin: origin,
          destination: destination,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  // Coarse geometry fingerprint: the set of ~100 m grid cells the route
  // passes through. Lets us compare the actual shape of two routes instead of
  // just their length.
  Set<String> _routeCells(RouteResult route) {
    const cell = 0.0009; // ~100 m
    final cells = <String>{};
    for (final p in route.points) {
      final latKey = (p.latitude / cell).round();
      final lngKey = (p.longitude / cell).round();
      cells.add('$latKey:$lngKey');
    }
    return cells;
  }

  // Two routes are "the same" when most of the shorter route's path coincides
  // with the other. Geometry-based so genuinely different roads stay distinct
  // even when the total distance is nearly identical (Waze-style alternates).
  bool _routesOverlapHeavily(RouteResult a, RouteResult b) {
    final ca = _routeCells(a);
    final cb = _routeCells(b);
    if (ca.isEmpty || cb.isEmpty) return false;
    final smaller = ca.length <= cb.length ? ca : cb;
    final larger = identical(smaller, ca) ? cb : ca;
    var intersection = 0;
    for (final c in smaller) {
      if (larger.contains(c)) intersection++;
    }
    return intersection / smaller.length > 0.9;
  }

  Future<List<_RouteOption>> _buildRouteOptions({
    required LatLng destination,
    required String vehicleType,
    RouteResult? strictRoute,
  }) async {
    final options = <_RouteOption>[
      if (strictRoute != null)
        _RouteOption(route: strictRoute, type: _RouteOptionType.recommended),
    ];

    // Waze-style: always surface genuinely different legal routes when they
    // exist. We force alternatives by re-routing around the primary route and
    // dedupe by geometry so only distinct paths are shown. Cap at 2.
    final origin = _currentLocation;
    if (origin != null && strictRoute != null) {
      final alternatives = await _routingService.getValhallaAlternatives(
        origin: origin,
        destination: destination,
        vehicleType: vehicleType,
        primaryRoute: strictRoute,
        avoidLocations: await _lowVehicleBumpAvoidLocations(
          origin: origin,
          destination: destination,
        ),
      );
      for (final alt in alternatives) {
        if (options
                .where((o) => o.type == _RouteOptionType.alternative)
                .length >=
            2) {
          break;
        }
        final isDuplicate = options.any(
          (option) => _routesOverlapHeavily(option.route, alt),
        );
        if (!isDuplicate) {
          options.add(
            _RouteOption(route: alt, type: _RouteOptionType.alternative),
          );
        }
      }
    }

    final relaxedRoute = await _tryRelaxedRoute(
      destination: destination,
      vehicleType: vehicleType,
    );
    if (relaxedRoute != null &&
        options.every(
          (option) => !_routesOverlapHeavily(option.route, relaxedRoute),
        )) {
      options.add(
        _RouteOption(route: relaxedRoute, type: _RouteOptionType.unverified),
      );
    }

    return options;
  }

  String _routeOptionDistanceText(AppLocalizations l10n, RouteResult route) {
    final km = route.distanceMeters / 1000;
    final minutes = route.durationSeconds / 60;
    return l10n.routeOptionMetrics(
      km.toStringAsFixed(1),
      minutes.toStringAsFixed(0),
    );
  }

  Future<_RouteOption?> _showRouteOptionsSheet({
    required String vehicleName,
    required List<_RouteOption> options,
  }) async {
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    return showModalBottomSheet<_RouteOption>(
      context: rootNavigator.context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        final l10n = AppLocalizations.of(sheetContext)!;
        return SafeArea(
          top: false,
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xF0071739),
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
            ),
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0x663AA8FF),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.alt_route,
                      color: Color(0xFF3AA8FF),
                      size: 28,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.routeOptionsTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 19,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...options.map((option) {
                  final isUnverified =
                      option.type == _RouteOptionType.unverified;
                  final accent = isUnverified
                      ? const Color(0xFFFFCC02)
                      : const Color(0xFF3AA8FF);
                  final String title;
                  final String subtitle;
                  final IconData icon;
                  switch (option.type) {
                    case _RouteOptionType.recommended:
                      title = l10n.routeOptionRecommended;
                      subtitle = l10n.routeOptionRecommendedSubtitle;
                      icon = Icons.verified_rounded;
                      break;
                    case _RouteOptionType.alternative:
                      title = l10n.routeOptionAlternative;
                      subtitle = l10n.routeOptionAlternativeSubtitle;
                      icon = Icons.alt_route_rounded;
                      break;
                    case _RouteOptionType.unverified:
                      title = l10n.routeOptionUnverified;
                      subtitle = l10n.routeOptionUnverifiedSubtitle(
                        vehicleName,
                      );
                      icon = Icons.warning_amber_rounded;
                      break;
                  }
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xEE0A1F63),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isUnverified
                            ? const Color(0x88FFCC02)
                            : const Color(0x663AA8FF),
                      ),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isUnverified
                            ? const Color(0x33FFCC02)
                            : const Color(0x333AA8FF),
                        child: Icon(icon, color: accent),
                      ),
                      title: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      subtitle: Text(
                        '${_routeOptionDistanceText(l10n, option.route)}\n$subtitle',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      isThreeLine: true,
                      trailing: Text(
                        l10n.routeOptionChoose,
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      onTap: () => Navigator.of(sheetContext).pop(option),
                    ),
                  );
                }),
                if (options.any((o) => o.type == _RouteOptionType.unverified))
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      l10n.routeOptionWarningFooter,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
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
        avoidLocations: await _lowVehicleBumpAvoidLocations(
          origin: current,
          destination: destination,
        ),
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
    if (_routePoints.length == 1) return 0;

    final searchStart = _lastNearestIdx.clamp(0, _routePoints.length - 2);
    final searchEnd = (searchStart + 50).clamp(0, _routePoints.length - 1);

    var bestIdx = searchStart;
    var bestDist = double.infinity;

    for (int i = searchStart; i <= searchEnd; i++) {
      final dist = _segDist(pos, _routePoints[i]);
      if (dist < bestDist) {
        bestDist = dist;
        bestIdx = i;
      }
    }

    if (bestIdx > _lastNearestIdx) {
      final distToOld = _segDist(pos, _routePoints[_lastNearestIdx]);
      if (distToOld > 8) {
        _lastNearestIdx = bestIdx;
      }
    }

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
    // Short lookahead so the heading follows the road you're actually on and
    // only rotates as you reach the corner — a longer lookahead pre-rotates
    // the map well before the turn (looks like it "turns too early").
    return _routeLookaheadHeading(nearestIdx, 15.0);
  }

  String _addressTitleFromResult(
    Map<String, dynamic> result, {
    String fallback = '',
  }) {
    final name = (result['name']?.toString() ?? '').trim();
    final category = (result['category']?.toString() ?? '').trim();
    final source = (result['_source']?.toString() ?? '').trim();
    final mapboxPlaceType = (result['_mapbox_place_type']?.toString() ?? '')
        .trim();
    final isPoi =
        source == 'overpass' ||
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
    final source = (result['_source']?.toString() ?? '').trim();
    final address = result['address'];
    if (address is Map) {
      final title = _addressTitleFromResult(result);
      final brand = (result['brand']?.toString() ?? '').trim();
      final operator = (result['operator']?.toString() ?? '').trim();
      final network = (result['network']?.toString() ?? '').trim();
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
      final parts = <String>[];
      final seenParts = <String>{};
      void addPart(String value) {
        final trimmed = value.trim();
        final normalized = _normalizeSearchText(trimmed);
        if (trimmed.isEmpty || !seenParts.add(normalized)) return;
        parts.add(trimmed);
      }

      if (source == 'overpass') {
        for (final value in [brand, operator, network]) {
          if (_normalizeSearchText(value) != _normalizeSearchText(title)) {
            addPart(value);
          }
        }
      }
      if (road.isNotEmpty) {
        addPart(houseNumber.isNotEmpty ? '$road $houseNumber' : road);
      }
      addPart(suburb);
      addPart(city);
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

  String _formatEta() {
    final l10n = AppLocalizations.of(context)!;
    if (!_isNavigating || _remainingDistM <= 50) return '';

    double remainingSec;
    final lastMovement = _etaLastMovementAt;
    final hasFreshLiveSpeed =
        _etaSmoothedSpeedKmh > 0 &&
        lastMovement != null &&
        DateTime.now().difference(lastMovement) <= _etaPauseGrace;

    if (hasFreshLiveSpeed) {
      final baseSec = _remainingDistM / (_etaSmoothedSpeedKmh / 3.6);
      final nearestIdx = _lastNearestIdx.clamp(0, _routePoints.length - 1);
      int instructionIndex = 0;
      for (int i = 0; i < _instructions.length - 1; i++) {
        if (_instructions[i + 1].pointIndex > nearestIdx) {
          instructionIndex = i;
          break;
        }
        instructionIndex = i + 1;
      }
      final maneuvers = _remainingManeuversFrom(instructionIndex);
      remainingSec =
          baseSec +
          _etaManeuverDelaySeconds(
            turns: maneuvers.$1,
            complexTurns: maneuvers.$2,
            remainingMeters: _remainingDistM,
          );
    } else if (_activeRoute != null && _totalRouteDistM > 0) {
      final routeFraction = (_remainingDistM / _totalRouteDistM).clamp(
        0.0,
        1.0,
      );
      remainingSec = _activeRoute!.durationSeconds * routeFraction;
    } else {
      return '';
    }

    final arrival = DateTime.now().add(Duration(seconds: remainingSec.round()));
    final h = arrival.hour.toString().padLeft(2, '0');
    final m = arrival.minute.toString().padLeft(2, '0');
    final hhmm = '$h:$m';
    final minLeft = (remainingSec / 60).ceil();
    if (minLeft < 1) return l10n.convoyEtaArrived;
    if (minLeft < 60) return l10n.convoyEtaMinutes(minLeft, hhmm);
    return l10n.convoyEtaHours(minLeft ~/ 60, minLeft % 60, hhmm);
  }

  Widget _mapCircleButton({
    required VoidCallback onTap,
    required String semanticLabel,
    required Widget child,
    Color? color,
  }) {
    return AccessibleTapTarget(
      label: semanticLabel,
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color ?? const Color(0xEE0A1F63),
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
    return AccessibleTapTarget(
      label: label,
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

  String? _localizedManeuverTarget(
    AppLocalizations l10n,
    String streetName,
    String instructionText,
  ) {
    final parsedTarget = _maneuverTargetFromText(instructionText);
    final target = streetName.trim().isNotEmpty
        ? streetName.trim()
        : parsedTarget;
    if (target == null || target.isEmpty) return null;

    final normalized = target
        .toLowerCase()
        .replaceFirst(
          RegExp(
            r'^(?:the|a|an|den|det|en|ett|le|la|les|un|une|el|los|las|il|lo|i|gli|die|der|das)\s+',
          ),
          '',
        )
        .trim();
    return switch (normalized) {
      'cycleway' ||
      'cycle path' ||
      'cycle track' ||
      'bike path' => l10n.mapManeuverGenericCycleway,
      'footway' ||
      'walkway' ||
      'pedestrian path' => l10n.mapManeuverGenericFootway,
      'path' || 'trail' => l10n.mapManeuverGenericPath,
      'road' || 'street' => l10n.mapManeuverGenericRoad,
      _ => target,
    };
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
      _activeRoute = route;
      _cumulativeDist = cumDist;
      _totalRouteDistM = totalDist;
      _remainingDistM = totalDist;
      _instructions = route.instructions;
      _lastNearestIdx = 0;
      _displayNearestIdx = 0;
      _nextManeuverText = '';
      _nextManeuverStreetName = '';
      _nextManeuverSign = 0;
      _distToNextManeuver = 0;
      _routingStatus = l10n.mapRouteReady(
        km.toStringAsFixed(1),
        minutes.toStringAsFixed(0),
      );
    });
    _analyzeSelectedRouteIfRequested();
    unawaited(_syncCarPlayNavigationState());
  }

  void _cancelPendingAiRouteAnalysis() {
    _analyzeNextSelectedRouteWithAi = false;
    _aiDestinationSelectionStarted = false;
  }

  void _analyzeSelectedRouteIfRequested() {
    if (!_analyzeNextSelectedRouteWithAi || _activeRoute == null) return;
    _cancelPendingAiRouteAnalysis();
    unawaited(_analyzeRouteWithAi());
  }

  Future<bool> _ensureAiConsent(AppLocalizations l10n) async {
    if (await AiRouteAnalysisService.instance.hasConsent()) return true;
    if (!mounted) return false;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: CruizXAiDialogStyle.background,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black87,
        shape: CruizXAiDialogStyle.shape,
        title: Text(
          l10n.aiConsentTitle,
          style: CruizXAiDialogStyle.titleTextStyle,
        ),
        content: Text(
          l10n.aiConsentBody,
          style: CruizXAiDialogStyle.bodyTextStyle,
        ),
        actions: [
          TextButton(
            style: CruizXAiDialogStyle.secondaryButtonStyle,
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.aiConsentDecline),
          ),
          FilledButton(
            style: CruizXAiDialogStyle.primaryButtonStyle,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.aiConsentAccept),
          ),
        ],
      ),
    );
    if (accepted == true) {
      await AiRouteAnalysisService.instance.setConsent(true);
      return true;
    }
    return false;
  }

  Map<String, int> _routeAlertCounts() {
    final counts = <String, int>{};
    for (final alert in _alerts) {
      if (!alert.type.showsProximityWarning ||
          _distanceToRouteMeters(alert.position, _routePoints) > 750) {
        continue;
      }
      counts.update(alert.type.key, (value) => value + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  Future<void> _analyzeRouteWithAi() async {
    final route = _activeRoute;
    if (route == null || _isAiAnalyzing) return;
    final l10n = AppLocalizations.of(context)!;
    if (!await _ensureAiConsent(l10n) || !mounted) return;

    final token = SupabaseService.instance.isEnabled
        ? SupabaseService.instance.client.auth.currentSession?.accessToken
        : null;
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.aiSignInRequired)));
      await Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const LoginScreen()));
      return;
    }

    setState(() => _isAiAnalyzing = true);
    unawaited(_showAiLoadingDialog(l10n));
    AiRouteAnalysis? analysis;
    try {
      final streetNames = route.instructions
          .map((instruction) => instruction.streetName.trim())
          .where((name) => name.isNotEmpty)
          .toSet()
          .toList(growable: false);
      analysis = await AiRouteAnalysisService.instance.analyze(
        language: Localizations.localeOf(context).languageCode,
        vehicleType: UserPreferencesService.instance.vehicleType.value,
        countryCode: UserPreferencesService.instance.countryCode.value,
        maxSpeedKmh: UserPreferencesService.instance.maxSpeedKmh.value,
        distanceKm: route.distanceMeters / 1000,
        durationMinutes: route.durationSeconds / 60,
        streetNames: streetNames,
        alertCounts: _routeAlertCounts(),
      );
    } on AiRouteAnalysisException catch (error) {
      if (!mounted) return;
      final message = switch (error.code) {
        'sign_in_required' => l10n.aiSignInRequired,
        'daily_limit' => l10n.aiDailyLimit,
        _ => l10n.aiUnavailable,
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.aiUnavailable)));
      }
    } finally {
      _closeAiLoadingDialog();
      if (mounted) setState(() => _isAiAnalyzing = false);
    }
    if (mounted && analysis != null) await _showAiAnalysis(analysis);
  }

  Future<void> _showAiLoadingDialog(AppLocalizations l10n) async {
    _isAiLoadingDialogVisible = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: CruizXAiDialogStyle.background,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.black87,
          shape: CruizXAiDialogStyle.shape,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          titlePadding: const EdgeInsets.fromLTRB(18, 18, 18, 4),
          title: Image.asset(
            'assets/CruizX_Ai_transparent.png',
            height: 135,
            fit: BoxFit.contain,
          ),
          contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: CruizXAiDialogStyle.accent,
                  strokeWidth: 2.5,
                ),
              ),
              const SizedBox(width: 14),
              Flexible(
                child: Text(
                  l10n.aiLoading,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: CruizXAiDialogStyle.bodyText,
                    fontSize: 15,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    _isAiLoadingDialogVisible = false;
  }

  void _closeAiLoadingDialog() {
    if (!mounted || !_isAiLoadingDialogVisible) return;
    _isAiLoadingDialogVisible = false;
    Navigator.of(context, rootNavigator: true).pop();
  }

  Future<void> _openAiFromMapButton() async {
    if (_activeRoute == null) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.mapAddressFieldHint),
          duration: const Duration(seconds: 2),
        ),
      );
      _analyzeNextSelectedRouteWithAi = true;
      _aiDestinationSelectionStarted = false;
      await _showDestinationSearchSheet();
      if (!_aiDestinationSelectionStarted) {
        _cancelPendingAiRouteAnalysis();
      }
      return;
    }
    await _analyzeRouteWithAi();
  }

  Future<void> _showAiAnalysis(AiRouteAnalysis analysis) async {
    final l10n = AppLocalizations.of(context)!;
    final color = switch (analysis.suitability) {
      'good' => const Color(0xFF22A95A),
      'not_recommended' => const Color(0xFFD32F2F),
      _ => const Color(0xFFF39C12),
    };
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: CruizXAiDialogStyle.background,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black87,
        shape: CruizXAiDialogStyle.shape,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        titlePadding: const EdgeInsets.fromLTRB(18, 16, 18, 2),
        title: Image.asset(
          'assets/CruizX_Ai_transparent.png',
          height: 145,
          fit: BoxFit.contain,
        ),
        contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  analysis.headline,
                  style: TextStyle(
                    color: color,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    height: 1.24,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  analysis.summary,
                  style: const TextStyle(
                    color: CruizXAiDialogStyle.bodyText,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
                if (analysis.highlights.isNotEmpty)
                  _AiAnalysisSection(
                    title: l10n.aiHighlights,
                    icon: Icons.check_circle_outline,
                    color: const Color(0xFF22A95A),
                    items: analysis.highlights,
                  ),
                if (analysis.cautions.isNotEmpty)
                  _AiAnalysisSection(
                    title: l10n.aiCautions,
                    icon: Icons.warning_amber_rounded,
                    color: const Color(0xFFF39C12),
                    items: analysis.cautions,
                  ),
                _AiAnalysisSection(
                  title: l10n.aiRecommendation,
                  icon: Icons.lightbulb_outline,
                  color: const Color(0xFF3AA8FF),
                  items: [analysis.recommendation],
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.aiDisclaimer,
                  style: const TextStyle(
                    color: CruizXAiDialogStyle.mutedText,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        actions: [
          TextButton.icon(
            style: CruizXAiDialogStyle.secondaryButtonStyle,
            onPressed: () => _reportAiAnswer(analysis.responseId),
            icon: const Icon(Icons.flag_outlined),
            label: Text(l10n.aiReport),
          ),
          FilledButton(
            style: CruizXAiDialogStyle.primaryButtonStyle,
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.ttsVoiceHintDismiss),
          ),
        ],
      ),
    );
  }

  Future<void> _reportAiAnswer(String responseId) async {
    final l10n = AppLocalizations.of(context)!;
    final reason = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(l10n.aiReportTitle)),
            for (final item in <(String, String)>[
              ('incorrect', l10n.aiReportIncorrect),
              ('unsafe', l10n.aiReportUnsafe),
              ('inappropriate', l10n.aiReportInappropriate),
              ('other', l10n.aiReportOther),
            ])
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: Text(item.$2),
                onTap: () => Navigator.pop(sheetContext, item.$1),
              ),
          ],
        ),
      ),
    );
    if (reason == null) return;
    try {
      await AiRouteAnalysisService.instance.report(
        responseId: responseId,
        reason: reason,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.aiReportSent)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.aiUnavailable)));
      }
    }
  }

  Future<bool> _showDailyRouteUpgradePrompt(AppLocalizations l10n) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF0A1F63),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          l10n.routeUpgradePromptTitle,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          l10n.routeUpgradePromptBody,
          style: const TextStyle(color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              l10n.aiConsentDecline,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFFB800),
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.paywallUpgradeButton),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _handleMapTap(LatLng destination) async {
    final l10n = AppLocalizations.of(context)!;
    final preferences = UserPreferencesService.instance;
    final previousDestination = _destination;
    final previousDestinationLabel = _destinationLabel;
    final previousRouteStop = _routeStop;
    final previousRouteStopLabel = _routeStopLabel;
    final previousRoutePoints = List<LatLng>.from(_routePoints);
    final previousInstructions = List<RouteInstruction>.from(_instructions);
    final previousActiveRoute = _activeRoute;
    final previousLastNearestIdx = _lastNearestIdx;
    final previousDisplayNearestIdx = _displayNearestIdx;
    final previousRoutingStatus = _routingStatus;
    final previousNextManeuverSign = _nextManeuverSign;
    final previousNextManeuverText = _nextManeuverText;
    final previousNextManeuverStreetName = _nextManeuverStreetName;
    final previousDistToNextManeuver = _distToNextManeuver;
    final previousCurrentStreetName = _currentStreetName;
    final previousCumulativeDist = List<double>.from(_cumulativeDist);
    final previousTotalRouteDistM = _totalRouteDistM;
    final previousRemainingDistM = _remainingDistM;
    final previousIsNavigating = _isNavigating;
    final previousIsNavigationPanelExpanded = _isNavigationPanelExpanded;

    void restorePreviousRouteState() {
      if (!mounted) {
        return;
      }
      setState(() {
        _mapViewEpoch++;
        _destination = previousDestination;
        _destinationLabel = previousDestinationLabel;
        _routeStop = previousRouteStop;
        _routeStopLabel = previousRouteStopLabel;
        _routePoints = previousRoutePoints;
        _instructions = previousInstructions;
        _activeRoute = previousActiveRoute;
        _lastNearestIdx = previousLastNearestIdx;
        _displayNearestIdx = previousDisplayNearestIdx;
        _routingStatus = previousRoutingStatus;
        _nextManeuverSign = previousNextManeuverSign;
        _nextManeuverText = previousNextManeuverText;
        _nextManeuverStreetName = previousNextManeuverStreetName;
        _distToNextManeuver = previousDistToNextManeuver;
        _currentStreetName = previousCurrentStreetName;
        _cumulativeDist = previousCumulativeDist;
        _totalRouteDistM = previousTotalRouteDistM;
        _remainingDistM = previousRemainingDistM;
        _isNavigating = previousIsNavigating;
        _isNavigationPanelExpanded = previousIsNavigationPanelExpanded;
        _isRouting = false;
      });
      unawaited(_syncCarPlayNavigationState());
      if (previousActiveRoute == null) {
        _cancelPendingAiRouteAnalysis();
      }
    }

    if (_analyzeNextSelectedRouteWithAi) {
      _aiDestinationSelectionStarted = true;
    }

    if (_currentLocation == null) {
      // Save destination so auto-retry fires when first GPS fix arrives.
      setState(() {
        _destination = destination;
        _routingStatus = l10n.mapWaitingForGps;
      });
      return;
    }

    final routeAdShown = await AdService.instance
        .showRouteInterstitialIfNeeded();
    if (!mounted) return;

    final subscriptions = SubscriptionService.instance;
    if (routeAdShown && subscriptions.shouldShowDailyRouteUpgradePrompt) {
      subscriptions.recordDailyRouteUpgradePromptShown();
      final shouldUpgrade = await _showDailyRouteUpgradePrompt(l10n);
      if (!mounted) return;
      if (shouldUpgrade) {
        await Navigator.of(
          context,
        ).push(MaterialPageRoute<bool>(builder: (_) => const PaywallScreen()));
        if (!mounted) return;
      }
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
        avoidLocations: await _lowVehicleBumpAvoidLocations(
          origin: _currentLocation!,
          destination: destination,
        ),
      );

      if (!mounted) {
        return;
      }

      final options = await _buildRouteOptions(
        destination: destination,
        vehicleType: preferences.vehicleType.value,
        strictRoute: route,
      );
      if (!mounted) return;
      final selected = options.length > 1
          ? await _showRouteOptionsSheet(
              vehicleName: switch (preferences.vehicleType.value) {
                'A-tractor' => l10n.settingsVehicleAtractor,
                'Low vehicle' => l10n.settingsVehicleLowVehicle,
                'Moped car' => l10n.settingsVehicleMopedCar,
                'Moped class I' => l10n.settingsVehicleMopedClassI,
                'Moped class II' => l10n.settingsVehicleMopedClassII,
                'Electric scooter' => l10n.settingsVehicleElectricScooter,
                'Tractor' => l10n.settingsVehicleTractor,
                _ => preferences.vehicleType.value,
              },
              options: options,
            )
          : options.first;
      if (!mounted) return;
      if (selected == null) {
        restorePreviousRouteState();
        return;
      }

      _applyRouteResult(selected.route, l10n);
      if (selected.type == _RouteOptionType.unverified) {
        setState(() => _routingStatus = l10n.routeFallbackActive);
      }
      unawaited(_saveDestinationHistory(destination));
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
        _activeRoute = null;
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
      unawaited(_syncCarPlayNavigationState());

      if (isRouteBlocked) {
        final vehicleName = switch (preferences.vehicleType.value) {
          'A-tractor' => l10n.settingsVehicleAtractor,
          'Low vehicle' => l10n.settingsVehicleLowVehicle,
          'Moped car' => l10n.settingsVehicleMopedCar,
          'Moped class I' => l10n.settingsVehicleMopedClassI,
          'Moped class II' => l10n.settingsVehicleMopedClassII,
          'Electric scooter' => l10n.settingsVehicleElectricScooter,
          'Tractor' => l10n.settingsVehicleTractor,
          _ => preferences.vehicleType.value,
        };

        final fallbackRoute = await _tryRelaxedRoute(
          destination: destination,
          vehicleType: preferences.vehicleType.value,
        );
        if (!mounted) return;

        if (fallbackRoute != null) {
          final selected = await _showRouteOptionsSheet(
            vehicleName: vehicleName,
            options: [
              _RouteOption(
                route: fallbackRoute,
                type: _RouteOptionType.unverified,
              ),
            ],
          );
          if (!mounted) return;
          if (selected == null) {
            restorePreviousRouteState();
            return;
          }
          _applyRouteResult(selected.route, l10n);
          setState(() => _routingStatus = l10n.routeFallbackActive);
          unawaited(_saveDestinationHistory(destination));
          SubscriptionService.instance.recordRoute();
        } else {
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
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _routePoints = const [];
        _activeRoute = null;
        _routingStatus = l10n.mapRouteFailed;
      });
      unawaited(_syncCarPlayNavigationState());
    } finally {
      if (mounted) {
        setState(() {
          _isRouting = false;
        });
        if (_activeRoute == null) _cancelPendingAiRouteAnalysis();
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
      _mapViewEpoch++;
      _routePoints = const [];
      _activeRoute = null;
      _lastNearestIdx = 0;
      _displayNearestIdx = 0;
      _destination = null;
      _destinationLabel = '';
      _routeStop = null;
      _routeStopLabel = '';
      _isRouting = false;
      _isNavigating = false;
      _isNavigationPanelExpanded = false;
      _isFollowing = false;
      _showSuggestions = false;
      _suggestions = const [];
      _instructions = const [];
      _nextManeuverText = '';
      _nextManeuverStreetName = '';
      _nextManeuverSign = 0;
      _distToNextManeuver = 0;
      _currentStreetName = '';
      _cumulativeDist = const [];
      _totalRouteDistM = 0;
      _remainingDistM = 0;
      _tripStartTime = null;
      _tripDistanceM = 0;
      _lastNavPos = null;
      _etaSmoothedSpeedKmh = 0;
      _etaLastMovementAt = null;
      _nearbyAlert = null;
      _dismissedNearbyAlert = null;
      _isSimulating = false;
      _routingStatus = AppLocalizations.of(context)!.mapTapToSelectDestination;
    });
    unawaited(CarPlayBridgeService.instance.clearNavigationState());
  }

  void _pruneDismissedNearbyAlert(LatLng currentPos) {
    final dismissed = _dismissedNearbyAlert;
    if (dismissed == null) return;
    final releaseDistance = dismissed.type.warningRadiusMeters + 150;
    if (dismissed.distanceTo(currentPos) > releaseDistance) {
      _dismissedNearbyAlert = null;
    }
  }

  void _dismissNearbyAlert() {
    final nearbyAlert = _nearbyAlert;
    if (nearbyAlert == null) return;
    setState(() {
      _dismissedNearbyAlert = nearbyAlert;
      _nearbyAlert = null;
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

    _pruneDismissedNearbyAlert(currentPos);

    double newTripDist = _tripDistanceM;
    if (_isNavigating && _lastNavPos != null) {
      newTripDist += _segDist(_lastNavPos!, currentPos);
    }

    int? newSign;
    String? newText;
    String? newManeuverStreetName;
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
          newManeuverStreetName = next.streetName;
          newDist = dist;
        } else {
          newText = '';
          newManeuverStreetName = '';
        }
      }
    }

    _locationNotifier.value = currentPos;
    final deviceControlsRasterArrow =
        !_isFollowing &&
        (_usingAppleMapKit || !_useVectorMap) &&
        _deviceCompassHeading != null &&
        newSpeed <= 6.0;
    if (newSpeed > 0.5 && !deviceControlsRasterArrow) {
      var headingForArrow = heading;
      if (_isNavigating &&
          nearestIdxForHeading != null &&
          nearestPointDistM != null) {
        // ROUTE-LOCKED: When on route, use route direction exclusively.
        // This is how Google Maps/Waze work — no GPS/compass blending.
        if (nearestPointDistM < 45) {
          // Full route lock within 45m — handles typical phone GPS inaccuracy.
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
      if (newManeuverStreetName != null) {
        _nextManeuverStreetName = newManeuverStreetName;
      }
      if (newDist != null) _distToNextManeuver = newDist;
      if (newStreetName != null) _currentStreetName = newStreetName;

      // Voice navigation announcements
      if (_isNavigating && newText != null && newDist != null) {
        _announceManeuver(newText, newDist);
      }
      if (newRemaining != null) {
        _remainingDistM = newRemaining;
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
      _nearbyAlert = AlertModel.mostRelevantNearby(
        _alerts,
        currentPos,
        dismissedAlert: _dismissedNearbyAlert,
      );
    });

    unawaited(_syncCarPlayNavigationState());
    unawaited(_maybeRefreshRoadSpeedLimit(currentPos));
  }

  Future<void> _syncCarPlayNavigationState() {
    final destination = _destination;
    final activeRoute = _activeRoute;
    final hasRoute = destination != null && activeRoute != null;
    final upcomingManeuvers = _buildCarPlayUpcomingManeuvers();

    double? remainingDurationSeconds;
    if (hasRoute) {
      if (_isNavigating && _totalRouteDistM > 0 && _remainingDistM >= 0) {
        final routeFraction = (_remainingDistM / _totalRouteDistM).clamp(
          0.0,
          1.0,
        );
        remainingDurationSeconds = activeRoute.durationSeconds * routeFraction;
      } else {
        remainingDurationSeconds = activeRoute.durationSeconds;
      }
    }

    return CarPlayBridgeService.instance.updateNavigationState(
      hasRoute: hasRoute,
      isNavigating: _isNavigating,
      destination: destination,
      destinationLabel: _destinationLabel,
      destinationAddress: _addressController.text.trim(),
      totalDistanceMeters: hasRoute ? activeRoute.distanceMeters : null,
      remainingDistanceMeters: hasRoute
          ? (_isNavigating ? _remainingDistM : activeRoute.distanceMeters)
          : null,
      remainingDurationSeconds: remainingDurationSeconds,
      nextManeuverText: _nextManeuverText,
      currentStreetName: _currentStreetName,
      upcomingManeuvers: upcomingManeuvers,
    );
  }

  List<Map<String, Object?>> _buildCarPlayUpcomingManeuvers() {
    if (_instructions.length < 2 || _routePoints.isEmpty) {
      return const [];
    }

    final currentPos = _currentLocation;
    final nearestIdx = currentPos != null
        ? _nearestRoutePointIndex(currentPos)
        : _lastNearestIdx.clamp(0, _routePoints.length - 1);

    int instructionIndex = 0;
    for (int i = 0; i < _instructions.length - 1; i++) {
      if (_instructions[i + 1].pointIndex > nearestIdx) {
        instructionIndex = i;
        break;
      }
      instructionIndex = i + 1;
    }

    final maneuvers = <Map<String, Object?>>[];
    for (
      int i = instructionIndex + 1;
      i < _instructions.length && maneuvers.length < 3;
      i++
    ) {
      final instruction = _instructions[i];
      final distanceMeters = i == instructionIndex + 1
          ? _distanceToInstructionFromRouteIndex(nearestIdx, instruction)
          : instruction.distanceMeters;

      maneuvers.add({
        'id':
            '${instruction.pointIndex}_${instruction.sign}_${instruction.text}',
        'text': instruction.text,
        'streetName': instruction.streetName,
        'sign': instruction.sign,
        'distanceMeters': distanceMeters,
      });
    }

    return maneuvers;
  }

  double _distanceToInstructionFromRouteIndex(
    int nearestIdx,
    RouteInstruction instruction,
  ) {
    var distance = 0.0;
    for (
      int i = nearestIdx;
      i < instruction.pointIndex && i < _routePoints.length - 1;
      i++
    ) {
      distance += _segDist(_routePoints[i], _routePoints[i + 1]);
    }
    return distance;
  }

  // ── GPS simulation ────────────────────────────────────────────────────────
  void _startSimulation() {
    if (_routePoints.isEmpty) return;
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _simPtIdx = 0;
    _simSegOffsetM = 0;
    _simCurrentSpeedKmh = 0; // start from rest
    final vt = UserPreferencesService.instance.vehicleType.value;
    _simMaxSpeedKmh = switch (vt) {
      'a-traktor' => 30.0,
      'tractor' => 30.0,
      'moped_car' => 45.0,
      _ => 50.0,
    };
    SlowRoadService.instance.startSession(vt);
    setState(() {
      _isSimulating = true;
      _isNavigating = true;
      _isNavigationPanelExpanded = false;
      _isFollowing = true;
      _tripStartTime = DateTime.now();
      _tripDistanceM = 0;
      _lastNavPos = _routePoints[0];
      _currentLocation = _routePoints[0];
    });
    unawaited(_syncCarPlayNavigationState());
    _locationNotifier.value = _routePoints[0];
    _simTimer = Timer.periodic(
      _simInterval,
      (_) => _simStepWithSpeed(_simMaxSpeedKmh),
    );
  }

  void _simStepWithSpeed(double maxSpeedKmh) {
    if (!mounted || _routePoints.isEmpty) {
      _clearRoute();
      return;
    }

    // ── Realistic speed calculation ───────────────────────────────────────
    // Look ahead ~40m to detect upcoming turn sharpness.
    double lookaheadAngle = 0;
    if (_simPtIdx < _routePoints.length - 2) {
      double accum = 0;
      final curHdg = () {
        final a = _routePoints[_simPtIdx];
        final b = _routePoints[_simPtIdx + 1];
        return (math.atan2(b.longitude - a.longitude, b.latitude - a.latitude) *
                    180 /
                    math.pi +
                360) %
            360;
      }();
      for (
        int i = _simPtIdx + 1;
        i < _routePoints.length - 1 && accum < 40;
        i++
      ) {
        accum += _segDist(_routePoints[i], _routePoints[i + 1]);
        final hdg =
            (math.atan2(
                      _routePoints[i + 1].longitude - _routePoints[i].longitude,
                      _routePoints[i + 1].latitude - _routePoints[i].latitude,
                    ) *
                    180 /
                    math.pi +
                360) %
            360;
        final diff = ((hdg - curHdg + 540) % 360) - 180;
        if (diff.abs() > lookaheadAngle.abs()) lookaheadAngle = diff;
      }
    }

    // Speed target: reduce in proportion to turn sharpness.
    // 0°=full speed, 90°=60% speed, 180°=40% speed
    final turnFactor = 1.0 - (lookaheadAngle.abs() / 180.0) * 0.6;
    final targetSpeed = maxSpeedKmh * turnFactor.clamp(0.4, 1.0);

    // Smooth speed change + tiny random noise for realism (±1.5 km/h).
    final noise = (math.Random().nextDouble() - 0.5) * 3.0;
    final accelRate = 8.0; // km/h per 200ms tick
    final diff = (targetSpeed + noise) - _simCurrentSpeedKmh;
    _simCurrentSpeedKmh =
        (_simCurrentSpeedKmh + diff.clamp(-accelRate, accelRate)).clamp(
          0.0,
          maxSpeedKmh,
        );

    final metersPerSec = _simCurrentSpeedKmh / 3.6;
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

    _processLocationUpdate(simPos, _simCurrentSpeedKmh, heading);
  }

  Widget _buildCompactNavigationSpeed(
    AppLocalizations l10n,
    UserPreferencesService preferences,
  ) {
    return ValueListenableBuilder<SpeedUnit>(
      valueListenable: preferences.speedUnit,
      builder: (context, speedUnit, _) {
        return ValueListenableBuilder<double>(
          valueListenable: preferences.maxSpeedKmh,
          builder: (context, maxSpeedKmh, _) {
            final roadLimitKmh = _roadSpeedLimitKmh;
            final effectiveLimitKmh = roadLimitKmh ?? maxSpeedKmh;
            final over = _speedKmh > effectiveLimitKmh;
            final speedDisplay = preferences.toDisplaySpeed(
              speedKmh: _speedKmh,
              unit: speedUnit,
            );
            final roadLimitDisplay = roadLimitKmh == null
                ? null
                : preferences.toDisplaySpeed(
                    speedKmh: roadLimitKmh,
                    unit: speedUnit,
                  );
            final effectiveLimitDisplay = preferences.toDisplaySpeed(
              speedKmh: effectiveLimitKmh,
              unit: speedUnit,
            );
            final speedRatio = effectiveLimitDisplay > 0
                ? (speedDisplay / effectiveLimitDisplay).clamp(0.0, 1.25)
                : 0.0;

            return Column(
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
                              ? const Color(0xFFFF5A5F)
                              : const Color(0xFFFF9A2F),
                          inactiveColor: const Color(0x40FFFFFF),
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
                            color: over ? Colors.red : Colors.white38,
                            width: 2,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black45,
                              blurRadius: 8,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            speedDisplay.toStringAsFixed(0),
                            style: TextStyle(
                              color: over ? Colors.redAccent : Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: roadLimitDisplay != null
                          ? Colors.red.shade700
                          : Colors.grey.shade500,
                      width: 3.5,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black38,
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      roadLimitDisplay?.toStringAsFixed(0) ?? '--',
                      style: TextStyle(
                        color: roadLimitDisplay != null
                            ? Colors.black
                            : Colors.black45,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
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
                  child: Builder(
                    builder: (context) {
                      final useAppleMapKit =
                          !kIsWeb &&
                          defaultTargetPlatform == TargetPlatform.iOS;
                      final routeForMap =
                          _isNavigating && _displayNearestIdx > 0
                          ? _routePoints.sublist(
                              _displayNearestIdx.clamp(0, _routePoints.length),
                            )
                          : _routePoints;
                      if (useAppleMapKit) {
                        return ValueListenableBuilder<MapMarkerStyle>(
                          valueListenable: preferences.mapMarkerStyle,
                          builder: (context, markerStyle, _) {
                            return AppleMapWidget(
                              key: ValueKey('apple-mapkit-$_mapViewEpoch'),
                              locationNotifier: _locationNotifier,
                              headingNotifier: _headingNotifier,
                              markerStyle: markerStyle,
                              destination: _destination,
                              routePoints: routeForMap,
                              alerts: _alerts,
                              nextManeuverDistanceMeters: _isNavigating
                                  ? _distToNextManeuver
                                  : null,
                              nextManeuverSign: _isNavigating
                                  ? _nextManeuverSign
                                  : null,
                              onTap: _isNavigating ? null : _handleMapTap,
                              followUser:
                                  _isFollowing && _currentLocation != null,
                              use3D: _isNavigating && _use3DMap,
                              darkMode: _useDarkMap,
                              onUserPanned: () {
                                if (!_isFollowing) return;
                                setState(() {
                                  _isFollowing = false;
                                  _mapViewEpoch++;
                                });
                              },
                            );
                          },
                        );
                      }
                      if (_useVectorMap && BackendConfig.hasSelfHostedTiles) {
                        return VectorMapWidget(
                          key: ValueKey('vector-$_mapViewEpoch'),
                          locationNotifier: _locationNotifier,
                          headingNotifier: _headingNotifier,
                          destination: _destination,
                          routePoints: routeForMap,
                          alerts: _alerts,
                          nextManeuverDistanceMeters: _isNavigating
                              ? _distToNextManeuver
                              : null,
                          nextManeuverSign: _isNavigating
                              ? _nextManeuverSign
                              : null,
                          onTap: _isNavigating ? null : _handleMapTap,
                          followUser: _isFollowing && _currentLocation != null,
                          use3D: _isNavigating && _use3DMap,
                          darkMode: _useDarkMap,
                          onUserPanned: () {
                            if (!_isFollowing) return;
                            setState(() {
                              _isFollowing = false;
                              _mapViewEpoch++;
                            });
                          },
                        );
                      }
                      return MapWidget(
                        key: ValueKey('raster-$_mapViewEpoch'),
                        locationNotifier: _locationNotifier,
                        headingNotifier: _headingNotifier,
                        destination: _destination,
                        routePoints: routeForMap,
                        studdedTireBanZones:
                            UserPreferencesService
                                .instance
                                .hasStuddedTires
                                .value
                            ? StuddedTireZones.all
                                  .map((z) => z.polygon)
                                  .toList()
                            : const [],
                        chargingStations: _chargingStations,
                        nextManeuverDistanceMeters: _isNavigating
                            ? _distToNextManeuver
                            : null,
                        nextManeuverSign: _isNavigating
                            ? _nextManeuverSign
                            : null,
                        alerts: _alerts,
                        onTap: _isNavigating ? null : _handleMapTap,
                        followUser: _isFollowing && _currentLocation != null,
                        use3D: _isNavigating && _use3DMap,
                        darkMode: _useDarkMap,
                        onUserPanned: () {
                          if (!_isFollowing) return;
                          setState(() {
                            _isFollowing = false;
                            _mapViewEpoch++;
                          });
                        },
                      );
                    },
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
                      final effectiveLimitKmh = roadLimitKmh ?? maxSpeedKmh;
                      final over = _speedKmh > effectiveLimitKmh;
                      final speedDisplay = preferences.toDisplaySpeed(
                        speedKmh: _speedKmh,
                        unit: speedUnit,
                      );
                      final effectiveLimitDisplay = preferences.toDisplaySpeed(
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
                            width: 42,
                            height: 42,
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
                                label: l10n.a11yAddFavorite,
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
                    readOnly: true,
                    textInputAction: TextInputAction.search,
                    onTap: _showDestinationSearchSheet,
                    decoration: InputDecoration(
                      hintText: l10n.mapAddressFieldHint,
                      filled: true,
                      fillColor: const Color(0xCC081B4F),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _addressController.text.isNotEmpty
                          ? IconButton(
                              tooltip: l10n.a11yClearSearch,
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
                              tooltip: l10n.a11yOpenSearch,
                              icon: const Icon(Icons.arrow_forward),
                              onPressed: _showDestinationSearchSheet,
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
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                    child: Container(
                      // Urgency tint improves readability during close/complex turns.
                      // Major apps shift color closer to maneuver for attention.
                      decoration: BoxDecoration(
                        color: const Color(0xFF071739),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black54,
                            blurRadius: 12,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.fromLTRB(12, 10, 14, 11),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Builder(
                            builder: (_) {
                              final accent = _maneuverAccentColor(
                                _distToNextManeuver,
                                _nextManeuverSign,
                              );
                              return Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.36),
                                  borderRadius: BorderRadius.circular(13),
                                  border: Border.all(
                                    color: accent.withValues(alpha: 0.9),
                                    width: 1.2,
                                  ),
                                ),
                                child: Icon(
                                  _turnIcon(_nextManeuverSign),
                                  color: Colors.white,
                                  size: 34,
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 11),
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
                                        horizontal: 9,
                                        vertical: 3,
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
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.1,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      _localizedManeuverPrimaryText(
                                        l10n,
                                        _nextManeuverSign,
                                        _nextManeuverText,
                                      ),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        height: 1.15,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (_localizedManeuverTarget(
                                          l10n,
                                          _nextManeuverStreetName,
                                          _nextManeuverText,
                                        ) !=
                                        null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          l10n.mapManeuverTowardRoad(
                                            _localizedManeuverTarget(
                                              l10n,
                                              _nextManeuverStreetName,
                                              _nextManeuverText,
                                            )!,
                                          ),
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
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
                          const SizedBox(width: 8),
                          NavigationEtaBadge(eta: _formatEta()),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Proximity alert banner
            if (_nearbyAlert != null && _currentLocation != null)
              Positioned(
                top: _nextManeuverText.isNotEmpty ? 128 : 12,
                left: 0,
                right: 0,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: _nearbyAlert!.type == AlertType.roadClosure
                          ? const Color(0xF2B71C1C)
                          : const Color(0xF2D97706),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Text(
                          _nearbyAlert!.type.emoji,
                          style: const TextStyle(fontSize: 18),
                        ),
                        const SizedBox(width: 8),
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
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  height: 1.15,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              );
                            },
                          ),
                        ),
                        AccessibleTapTarget(
                          label: l10n.a11yDismissAlert,
                          onTap: _dismissNearbyAlert,
                          child: const Icon(
                            Icons.close,
                            color: Colors.white70,
                            size: 16,
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
                // GPS / re-center button
                _mapCircleButton(
                  semanticLabel: _isFollowing
                      ? l10n.a11yStopFollowingLocation
                      : l10n.a11yCenterOnLocation,
                  onTap: () => setState(() {
                    final nextFollowing = !_isFollowing;
                    if (_isFollowing && !nextFollowing) {
                      _mapViewEpoch++;
                    }
                    _isFollowing = nextFollowing;
                  }),
                  color: _isFollowing ? const Color(0xFF1E6BFF) : null,
                  child: Icon(
                    _isFollowing ? Icons.my_location : Icons.location_searching,
                    color: Colors.white70,
                    size: 19,
                  ),
                ),
                const SizedBox(height: 8),
                _mapCircleButton(
                  semanticLabel: l10n.aiRouteButton,
                  onTap: _openAiFromMapButton,
                  color: _activeRoute != null ? const Color(0xFF1B4F9C) : null,
                  child: _isAiAnalyzing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF8FCBFF),
                          ),
                        )
                      : const Text(
                          'AI',
                          style: TextStyle(
                            color: Color(0xFF8FCBFF),
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                ),
                const SizedBox(height: 8),
                // 2D / 3D toggle
                _mapCircleButton(
                  semanticLabel: _use3DMap
                      ? l10n.a11ySwitchTo2d
                      : l10n.a11ySwitchTo3d,
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
                  semanticLabel: _useDarkMap
                      ? l10n.a11yUseLightMap
                      : l10n.a11yUseDarkMap,
                  onTap: () => setState(() {
                    _autoMapTheme = false;
                    _useDarkMap = !_useDarkMap;
                  }),
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
                      semanticLabel: ttsOn
                          ? l10n.a11yDisableVoiceNavigation
                          : l10n.a11yEnableVoiceNavigation,
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
                  semanticLabel: l10n.reportAlertTitle,
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

          // ── Current street name pill ────────────────────────────────
          if (_isNavigating && _currentStreetName.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom:
                  (_destination != null ||
                      _routePoints.isNotEmpty ||
                      _isRouting)
                  ? (_isNavigationPanelExpanded ? 165 : 68)
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
          // Minimal driving controls. The full route panel stays out of the
          // map until the driver explicitly opens it from the three-dot button.
          if (_isNavigating &&
              !_isNavigationPanelExpanded &&
              (_destination != null || _routePoints.isNotEmpty))
            Positioned(
              left: 14,
              right: 14,
              bottom: 12,
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: 108,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      Align(
                        alignment: Alignment.bottomLeft,
                        child: _buildCompactNavigationSpeed(l10n, preferences),
                      ),
                      Semantics(
                        button: true,
                        label: l10n.routeOptionsTitle,
                        child: Tooltip(
                          message: l10n.routeOptionsTitle,
                          child: GestureDetector(
                            onTap: () => setState(
                              () => _isNavigationPanelExpanded = true,
                            ),
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: const Color(0x661E6BFF),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0x993AA8FF),
                                  width: 1.5,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black38,
                                    blurRadius: 9,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.more_horiz,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Semantics(
                          button: true,
                          label: l10n.mapEndNavigation,
                          child: Tooltip(
                            message: l10n.mapEndNavigation,
                            child: GestureDetector(
                              onTap: _clearRoute,
                              child: Container(
                                width: 42,
                                height: 42,
                                decoration: const BoxDecoration(
                                  color: Color(0xE6D32F2F),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black45,
                                      blurRadius: 9,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.stop_rounded,
                                  color: Colors.white,
                                  size: 21,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // ── Navigation bottom panel (Apple Maps dark) ──────────────────
          if ((_destination != null || _routePoints.isNotEmpty || _isRouting) &&
              (!_isNavigating || _isNavigationPanelExpanded))
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF071739),
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
                            final effectiveLimitKmh =
                                roadLimitKmh ?? maxSpeedKmh;
                            final over = _speedKmh > effectiveLimitKmh;
                            final speedDisplay = preferences.toDisplaySpeed(
                              speedKmh: _speedKmh,
                              unit: speedUnit,
                            );
                            final effectiveLimitDisplay = preferences
                                .toDisplaySpeed(
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
                                // Tap or drag the handle down to return to the
                                // distraction-free driving layout.
                                Center(
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: _isNavigating
                                        ? () => setState(
                                            () => _isNavigationPanelExpanded =
                                                false,
                                          )
                                        : null,
                                    onVerticalDragEnd: _isNavigating
                                        ? (details) {
                                            if ((details.primaryVelocity ?? 0) >
                                                100) {
                                              setState(
                                                () =>
                                                    _isNavigationPanelExpanded =
                                                        false,
                                              );
                                            }
                                          }
                                        : null,
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        34,
                                        0,
                                        34,
                                        14,
                                      ),
                                      child: Container(
                                        width: 40,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: Colors.white24,
                                          borderRadius: BorderRadius.circular(
                                            2,
                                          ),
                                        ),
                                      ),
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
                                          loading:
                                              _searchingRouteStopKey == 'food',
                                          enabled:
                                              _searchingRouteStopKey == null,
                                          onTap: () => _showRouteStopSheet(
                                            title: l10n.convoyPoiFoodStop,
                                            searchKey: 'food',
                                            queries: const [
                                              'restaurant',
                                              'fast food',
                                            ],
                                            icon: Icons.restaurant,
                                          ),
                                        ),
                                        _RouteStopChip(
                                          icon: Icons.local_parking,
                                          label: l10n.convoyPoiParking,
                                          loading:
                                              _searchingRouteStopKey ==
                                              'parking',
                                          enabled:
                                              _searchingRouteStopKey == null,
                                          onTap: () => _showRouteStopSheet(
                                            title: l10n.convoyPoiParking,
                                            searchKey: 'parking',
                                            queries: const [
                                              'parking',
                                              'car park',
                                              'parkering',
                                            ],
                                            icon: Icons.local_parking,
                                          ),
                                        ),
                                        _RouteStopChip(
                                          icon: Icons.ev_station,
                                          label: l10n.convoyPoiCharging,
                                          loading:
                                              _searchingRouteStopKey ==
                                              'charging',
                                          enabled:
                                              _searchingRouteStopKey == null,
                                          onTap: () => _showRouteStopSheet(
                                            title: l10n.convoyPoiCharging,
                                            searchKey: 'charging',
                                            queries: const [
                                              'charging station',
                                              'ev charging',
                                              'laddstation',
                                            ],
                                            icon: Icons.ev_station,
                                          ),
                                        ),
                                        _RouteStopChip(
                                          icon: Icons.local_gas_station,
                                          label: l10n.routeStopFuel,
                                          loading:
                                              _searchingRouteStopKey == 'fuel',
                                          enabled:
                                              _searchingRouteStopKey == null,
                                          onTap: () => _showRouteStopSheet(
                                            title: l10n.routeStopFuel,
                                            searchKey: 'fuel',
                                            queries: const [
                                              'gas station',
                                              'fuel',
                                              'petrol station',
                                              'bensinstation',
                                            ],
                                            icon: Icons.local_gas_station,
                                          ),
                                        ),
                                        _RouteStopChip(
                                          icon: Icons.local_cafe,
                                          label: l10n.routeStopCafe,
                                          loading:
                                              _searchingRouteStopKey == 'cafe',
                                          enabled:
                                              _searchingRouteStopKey == null,
                                          onTap: () => _showRouteStopSheet(
                                            title: l10n.routeStopCafe,
                                            searchKey: 'cafe',
                                            queries: const [
                                              'cafe',
                                              'coffee',
                                              'kafé',
                                            ],
                                            icon: Icons.local_cafe,
                                          ),
                                        ),
                                        _RouteStopChip(
                                          icon: Icons.local_grocery_store,
                                          label: l10n.routeStopGrocery,
                                          loading:
                                              _searchingRouteStopKey ==
                                              'grocery',
                                          enabled:
                                              _searchingRouteStopKey == null,
                                          onTap: () => _showRouteStopSheet(
                                            title: l10n.routeStopGrocery,
                                            searchKey: 'grocery',
                                            queries: const [
                                              'grocery',
                                              'supermarket',
                                              'livsmedel',
                                            ],
                                            icon: Icons.local_grocery_store,
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
                                                      _isNavigationPanelExpanded =
                                                          false;
                                                      _isFollowing = true;
                                                      _tripStartTime =
                                                          DateTime.now();
                                                      _tripDistanceM = 0;
                                                      _lastNavPos =
                                                          _currentLocation;
                                                    });
                                                    unawaited(
                                                      _syncCarPlayNavigationState(),
                                                    );
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
                                            ConstrainedBox(
                                              constraints: const BoxConstraints(
                                                maxWidth: 140,
                                              ),
                                              child: InkWell(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                onTap: _isAiAnalyzing
                                                    ? null
                                                    : _analyzeRouteWithAi,
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 4,
                                                        vertical: 5,
                                                      ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      if (_isAiAnalyzing)
                                                        const SizedBox(
                                                          width: 14,
                                                          height: 14,
                                                          child:
                                                              CircularProgressIndicator(
                                                                strokeWidth: 2,
                                                                color: Color(
                                                                  0xFF8FCBFF,
                                                                ),
                                                              ),
                                                        )
                                                      else
                                                        const Icon(
                                                          Icons.auto_awesome,
                                                          size: 16,
                                                          color: Color(
                                                            0xFF8FCBFF,
                                                          ),
                                                        ),
                                                      const SizedBox(width: 6),
                                                      Flexible(
                                                        child: Text(
                                                          _isAiAnalyzing
                                                              ? l10n.aiLoading
                                                              : l10n.aiRouteButton,
                                                          maxLines: 2,
                                                          textAlign:
                                                              TextAlign.right,
                                                          style:
                                                              const TextStyle(
                                                                color: Color(
                                                                  0xFF8FCBFF,
                                                                ),
                                                                fontSize: 13,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 3),
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
                                            if (!kReleaseMode ||
                                                BackendConfig
                                                    .enableSimulation) ...[
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

class _AiAnalysisSection extends StatelessWidget {
  const _AiAnalysisSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 7),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(top: 5, left: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '•',
                    style: TextStyle(
                      color: CruizXAiDialogStyle.mutedText,
                      fontSize: 15,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        color: CruizXAiDialogStyle.bodyText,
                        fontSize: 14.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

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
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selected == null) return;
    setState(() => _submitting = true);
    try {
      await widget.controller.submit(
        type: _selected!,
        position: widget.position,
        description: _descriptionController.text.trim(),
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
      child: SingleChildScrollView(
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
                            color: sel
                                ? const Color(0xFF3AA8FF)
                                : Colors.white24,
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
            TextField(
              controller: _descriptionController,
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.reportAlertDescHint,
                hintStyle: const TextStyle(color: Colors.white38),
                counterStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.07),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 8),
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

enum _RouteOptionType { recommended, alternative, unverified }

class _RouteOption {
  const _RouteOption({required this.route, required this.type});

  final RouteResult route;
  final _RouteOptionType type;
}

class _SearchShortcutCard extends StatelessWidget {
  const _SearchShortcutCard({
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          width: 106,
          height: 82,
          decoration: BoxDecoration(
            color: const Color(0xEE0A1F63),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0x553AA8FF)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 27),
              const SizedBox(height: 7),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchDestinationRow extends StatelessWidget {
  const _SearchDestinationRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            Icon(icon, color: Colors.white70, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  if (subtitle.trim().isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteStopCandidate {
  const _RouteStopCandidate({
    required this.title,
    required this.subtitle,
    required this.position,
    required this.routeDistanceMeters,
    required this.distanceFromMeMeters,
    required this.aheadDistanceMeters,
    required this.routeIndex,
    required this.isAhead,
  });

  final String title;
  final String subtitle;
  final LatLng position;
  final double routeDistanceMeters;
  final double distanceFromMeMeters;
  final double aheadDistanceMeters;
  final int routeIndex;
  final bool isAhead;
}

class _RouteStopResultsSheet extends StatefulWidget {
  const _RouteStopResultsSheet({
    required this.title,
    required this.icon,
    required this.hasActiveRoute,
    required this.loadCandidates,
    required this.formatStopDistance,
    required this.onCandidateSelected,
  });

  final String title;
  final IconData icon;
  final bool hasActiveRoute;
  final Future<List<_RouteStopCandidate>> Function() loadCandidates;
  final String Function(double meters) formatStopDistance;
  final void Function(_RouteStopCandidate candidate) onCandidateSelected;

  @override
  State<_RouteStopResultsSheet> createState() => _RouteStopResultsSheetState();
}

class _RouteStopResultsSheetState extends State<_RouteStopResultsSheet> {
  late final Future<List<_RouteStopCandidate>> _candidatesFuture;

  @override
  void initState() {
    super.initState();
    _candidatesFuture = widget.loadCandidates();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.72,
        ),
        decoration: const BoxDecoration(
          color: Color(0xF0071739),
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
                color: Color(0x663AA8FF),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(widget.icon, color: const Color(0xFF3AA8FF)),
              title: Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                widget.hasActiveRoute
                    ? l10n.routeStopSheetSubtitle
                    : l10n.routeStopNearbySubtitle,
                style: const TextStyle(color: Colors.white54),
              ),
            ),
            Flexible(
              child: FutureBuilder<List<_RouteStopCandidate>>(
                future: _candidatesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 34),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF3AA8FF),
                        ),
                      ),
                    );
                  }

                  final candidates = snapshot.data ?? const [];
                  if (candidates.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
                      child: Text(
                        widget.hasActiveRoute
                            ? l10n.routeStopEmpty
                            : l10n.routeStopNearbyEmpty,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: candidates.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: Colors.white12),
                    itemBuilder: (context, index) {
                      final candidate = candidates[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xEE0A1F63),
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
                            if (widget.hasActiveRoute &&
                                candidate.aheadDistanceMeters.isFinite)
                              widget.formatStopDistance(
                                candidate.aheadDistanceMeters,
                              ),
                            if (widget.hasActiveRoute)
                              l10n.routeStopFromRoute(
                                widget.formatStopDistance(
                                  candidate.routeDistanceMeters,
                                ),
                              ),
                            l10n.routeStopAway(
                              widget.formatStopDistance(
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
                          widget.onCandidateSelected(candidate);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteStopChip extends StatelessWidget {
  const _RouteStopChip({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.loading,
    required this.enabled,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool loading;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: enabled || loading
                ? const Color(0xEE0A1F63)
                : const Color(0x880A1F63),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x553AA8FF)),
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
                Icon(
                  icon,
                  color: enabled ? const Color(0xFF3AA8FF) : Colors.white38,
                  size: 18,
                ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: enabled || loading ? Colors.white : Colors.white38,
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
