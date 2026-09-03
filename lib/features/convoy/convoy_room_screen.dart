// ignore_for_file: deprecated_member_use, unused_element, duplicate_ignore, use_build_context_synchronously

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:slowride/core/constants/backend_config.dart';
import 'package:slowride/features/alerts/alerts_controller.dart';
import 'package:slowride/features/auth/login_screen.dart';
import 'package:slowride/features/convoy/convoy_controller.dart';
import 'package:slowride/models/alert_model.dart';
import 'package:slowride/services/auth_service.dart';
import 'package:slowride/services/ai_route_analysis_service.dart';
import 'package:slowride/services/ad_service.dart';
import 'package:slowride/services/routing_service.dart';
import 'package:slowride/services/apple_map_search_service.dart';
import 'package:slowride/services/carplay_bridge_service.dart';
import 'package:slowride/services/mapbox_search_service.dart';
import 'package:slowride/services/osm_speed_bump_service.dart';
import 'package:slowride/services/supabase_service.dart';
import 'package:slowride/services/tts_service.dart';
import 'package:slowride/services/trafikverket_service.dart';
import 'package:slowride/services/user_preferences_service.dart';
import 'package:slowride/services/favorite_places_service.dart';
import 'package:slowride/services/convoy_favorite_places_service.dart';
import 'package:slowride/models/country_vehicle_rules.dart';
import 'package:slowride/l10n/app_localizations.dart';
import 'package:slowride/models/convoy_member_location.dart';
import 'package:slowride/models/convoy_message.dart';
import 'package:slowride/models/convoy_model.dart';
import 'package:slowride/models/convoy_pin.dart';
import 'package:slowride/widgets/user_location_marker.dart';
import 'package:slowride/widgets/accessible_tap_target.dart';
import 'package:slowride/widgets/ad_banner_widget.dart';
import 'package:slowride/services/destination_history_service.dart';
import 'package:slowride/widgets/apple_convoy_map_widget.dart';
import 'package:slowride/widgets/cruizx_ai_dialog_style.dart';
import 'package:slowride/widgets/navigation_eta_badge.dart';

class ConvoyRoomScreen extends StatefulWidget {
  const ConvoyRoomScreen({required this.convoy, super.key});

  final ConvoyModel convoy;

  @override
  State<ConvoyRoomScreen> createState() => _ConvoyRoomScreenState();
}

class _ConvoyRoomScreenState extends State<ConvoyRoomScreen>
    with SingleTickerProviderStateMixin {
  final ConvoyController _controller = ConvoyController();
  final RoutingService _routingService = RoutingService();
  final AlertsController _alertsController = AlertsController();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  final TextEditingController _addressSearchController =
      TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final MapController _mapController = MapController();
  late final http.Client _tileHttpClient;
  late final NetworkTileProvider _tileProvider;
  Timer? _searchDebounce;
  List<Map<String, dynamic>> _suggestions = [];
  bool _showSuggestions = false;
  late Stream<List<ConvoyPin>> _pinsStream;
  late Stream<List<ConvoyMessage>> _messagesStream;
  List<ConvoyMessage> _sentMessages = const [];
  bool _isSendingMessage = false;

  // ── Smooth camera animation (same as MapWidget) ────────────────────────
  late final Ticker _camTicker;
  double _curLat = 0, _curLng = 0, _curHdg = 0;
  double _tgtLat = 0, _tgtLng = 0, _tgtHdg = 0;
  double _filteredTgtHdg = 0;
  double _rawCompassHdg = 0;
  double _gpsSpeedMps = 0;
  double _curZoom = _followZoom;
  double _tgtZoom = _followZoom;
  Duration? _lastCamTick;
  bool _camInitialized = false;
  LatLng? _lastLocForBearing;
  DateTime? _lastGpsAt;

  // Smooth arrow heading — ticker drives it when following, GPS otherwise.
  final ValueNotifier<double> _arrowHdg = ValueNotifier<double>(0);
  // Location notifier for convoy map follow handling.
  final ValueNotifier<LatLng?> _locationNotifier = ValueNotifier<LatLng?>(null);
  // Speed notifier — drives speed display without setState.
  final ValueNotifier<double> _speedNotifier = ValueNotifier<double>(0);
  Duration? _lastCameraTickAt;

  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<CompassEvent>? _compassSubscription;
  double? _deviceCompassHeading;
  Timer? _pinRefreshTimer;
  Timer? _locationPollTimer;
  Timer? _alertsTimer;
  Timer? _themeTimer;
  List<ConvoyMemberLocation> _memberLocations = [];
  Set<String> _blockedParticipantIds = <String>{};
  List<AlertModel> _alerts = const [];

  Future<List<LatLng>> _lowVehicleBumpAvoidLocations({
    required LatLng origin,
    required LatLng destination,
  }) async {
    if (UserPreferencesService.instance.vehicleType.value != 'Low vehicle') {
      return const [];
    }
    return OsmSpeedBumpService.instance.avoidLocationsForRoute(
      origin: origin,
      destination: destination,
      knownAlerts: _alerts,
    );
  }

  AlertModel? _nearbyAlert;
  AlertModel? _dismissedNearbyAlert;
  double? _roadSpeedLimitKmh;
  LatLng? _lastRoadLimitLookupPos;
  DateTime _lastRoadLimitLookupAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _roadLimitLookupInFlight = false;
  static const Duration _roadLimitLookupInterval = Duration(seconds: 10);
  static const double _roadLimitLookupMinMoveMeters = 55;
  LatLng? _myLocation;
  bool _hasCenteredOnInitialGps = false;
  double _myHeading = 0;
  bool _isFollowingMyPosition = false;
  bool _shareLiveLocation = false;
  bool _use3DMap = true;
  bool _useDarkMap = true;
  bool _useSatelliteMap = false;
  Timer? _mapInteractionResumeTimer;
  // When true, the map style follows time of day; a manual toggle disables it.
  bool _autoMapTheme = true;
  String? _myUserId;
  String _destinationLabel = '';

  // ── Inline routing state ────────────────────────────────────────────────
  List<LatLng> _routePoints = const [];
  LatLng? _routeDestination;
  LatLng? _pendingDestination; // set before GPS is ready
  bool _isRouting = false;
  String _routingStatus = '';
  List<RouteInstruction> _routeInstructions = const [];
  RouteResult? _activeRoute;
  bool _isAiAnalyzing = false;
  bool _isAiLoadingDialogVisible = false;
  bool _analyzeNextSelectedRouteWithAi = false;
  bool _aiDestinationSelectionStarted = false;
  double _distToNextManeuver = double.infinity;
  int _mapViewEpoch = 0;
  int _mapViewportCommandId = 0;
  List<LatLng> _mapViewportCommandPoints = const [];

  // ── Navigation mode state ──────────────────────────────────────────────────
  bool _isNavigating = false;
  bool _isNavigationPanelExpanded = false;
  int _nextManeuverSign = 0;
  String _nextManeuverText = '';
  String _nextManeuverStreetName = '';
  String _currentStreetName = '';
  String _lastSpokenManeuver = '';
  bool _spokenEarlyWarning = false;
  List<double> _cumulativeDist = const [];
  double _totalRouteDistM = 0;
  double _remainingDistM = 0;
  double _etaSmoothedSpeedKmh = 0;
  DateTime? _etaLastMovementAt;
  int _lastNearestIdx = 0;
  int _displayNearestIdx = 0;

  static const List<Color> _avatarPalette = [
    Color(0xFF1E6BFF),
    Color(0xFF00C896),
    Color(0xFFE85D5D),
    Color(0xFFFFB800),
    Color(0xFFAA55FF),
    Color(0xFF00D4FF),
    Color(0xFFFF6B35),
    Color(0xFF4CAF50),
  ];

  static const double _followZoom = 16;
  static const double _k3DTiltRad = 0.44; // ~25 deg
  static const double _k3DArrowAlignmentY = 0.30;
  static const double _k3DLeadBaseDeg = 0.00042;
  static const Duration _pinTtl = Duration(minutes: 30);
  static const Duration _poiPinTtl = Duration(hours: 6);
  static const Duration _etaPauseGrace = Duration(seconds: 25);

  bool get _usingAppleMapKit =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  double _wrap360(double angle) => (angle % 360 + 360) % 360;

  double _angleDiff(double from, double to) {
    return ((to - from + 540) % 360) - 180;
  }

  LatLng _cameraCenterForNav({
    required double lat,
    required double lng,
    required double headingDeg,
    required double zoom,
  }) {
    if (!_use3DMap) return LatLng(lat, lng);

    // Keep vehicle in lower part of screen in 3D by shifting camera center
    // ahead along heading. Scale by zoom to keep visual lead stable.
    final offsetDeg = _k3DLeadBaseDeg * math.pow(2.0, 17.2 - zoom).toDouble();
    final rad = headingDeg * math.pi / 180.0;
    final cLat = lat + offsetDeg * math.cos(rad);
    final cLng = lng + offsetDeg * math.sin(rad);
    return LatLng(cLat, cLng);
  }

  void _moveCameraForNav({
    required double lat,
    required double lng,
    required double headingDeg,
    required double zoom,
  }) {
    if (_usingAppleMapKit) {
      return;
    }
    final center = _cameraCenterForNav(
      lat: lat,
      lng: lng,
      headingDeg: headingDeg,
      zoom: zoom,
    );
    try {
      _mapController.moveAndRotate(center, zoom, _use3DMap ? -headingDeg : 0);
    } catch (e) {
      debugPrint('Convoy map moveAndRotate skipped: $e');
    }
  }

  void _queueViewportFit(List<LatLng> points) {
    setState(() {
      _mapViewportCommandId++;
      _mapViewportCommandPoints = points;
    });
  }

  ConvoyMemberLocation? _memberByUserId(
    List<ConvoyMemberLocation> locations,
    String userId,
  ) {
    for (final member in locations) {
      if (member.userId == userId) {
        return member;
      }
    }
    return null;
  }

  ConvoyPin? _pinById(List<ConvoyPin> pins, String pinId) {
    for (final pin in pins) {
      if (pin.id == pinId) {
        return pin;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _startCompassTracking();
    _bindRealtimeStreams();
    _tileHttpClient = http.Client();
    _tileProvider = NetworkTileProvider(
      httpClient: _tileHttpClient,
      abortObsoleteRequests: true,
      cachingProvider: BuiltInMapCachingProvider.getOrCreateInstance(
        maxCacheSize: 1_000_000_000,
      ),
    );
    _camTicker = createTicker(_onCamTick)..start();
    _addressSearchController.addListener(() => setState(() {}));
    _myUserId = AuthService.instance.userId.value;
    _shareLiveLocation = !widget.convoy.isPublic;
    if (widget.convoy.isPublic) {
      unawaited(_controller.clearMyLocation(convoyId: widget.convoy.id));
    }
    _use3DMap = UserPreferencesService.instance.use3DMap.value;
    _useSatelliteMap = UserPreferencesService.instance.useSatelliteMap.value;
    ConvoyFavoritePlacesService.instance.initialize();
    // Auto-pick a dark map at night and a light map during the day.
    _useDarkMap = _isNightTime();
    _themeTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted && _autoMapTheme) {
        final night = _isNightTime();
        if (night != _useDarkMap) setState(() => _useDarkMap = night);
      }
    });
    // Delay GPS request until after first frame (avoids InheritedWidget issue)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startLocationSync();
      if (mounted) _loadAlerts();
    });
    _alertsTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _loadAlerts();
    });
    _pinRefreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });
    // Poll member locations every 5 s — Supabase composite-key stream is unreliable
    _locationPollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) _fetchMemberLocations();
    });
    _fetchMemberLocations(); // immediate first load
  }

  void _bindRealtimeStreams() {
    _pinsStream = _controller.watchPins(convoyId: widget.convoy.id);
    _messagesStream = _controller.watchMessages(convoyId: widget.convoy.id);
  }

  Future<void> _fetchMemberLocations() async {
    try {
      final blockedIds = await _controller.blockedParticipantIds();
      final rows = await SupabaseService.instance.client
          .from('convoy_locations')
          .select()
          .eq('convoy_id', widget.convoy.id);
      if (!mounted) return;
      final locations = (rows as List)
          .map(
            (row) => ConvoyMemberLocation.fromMap(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .where(
            (location) =>
                !blockedIds.contains(location.userId) &&
                (!widget.convoy.isPublic ||
                    DateTime.now().difference(location.updatedAt) <
                        const Duration(minutes: 2)),
          )
          .toList();
      setState(() {
        _blockedParticipantIds = blockedIds;
        _memberLocations = locations;
      });
      unawaited(_syncCarPlayConvoyState(locations));
    } catch (_) {}
  }

  Future<void> _syncCarPlayConvoyState(
    List<ConvoyMemberLocation> locations,
  ) {
    final currentUserId = (AuthService.instance.userId.value ?? _myUserId)
        ?.trim();
    final members = locations
        .map((member) {
          final style = MapMarkerStyle.values.firstWhere(
            (candidate) => candidate.name == member.vehicleStyle,
            orElse: () => MapMarkerStyle.navigation,
          );
          final option = UserLocationMarker.optionFor(style);
          return <String, Object?>{
            'userId': member.userId,
            'label': member.userLabel,
            'latitude': member.position.latitude,
            'longitude': member.position.longitude,
            'assetPath': option.assetPath,
            'iconName': switch (option.style) {
              MapMarkerStyle.navigation => 'navigation',
              MapMarkerStyle.compass => 'compass',
              MapMarkerStyle.triangle => 'triangle',
              MapMarkerStyle.dot => 'flatArrow',
              _ => null,
            },
            'tintArgb': option.tint?.toARGB32(),
          };
        })
        .toList(growable: false);

    return CarPlayBridgeService.instance.updateConvoyState(
      isActive: true,
      convoyName: widget.convoy.name,
      currentUserId: currentUserId,
      members: members,
      currentLocation: _myLocation,
      headingDegrees: _arrowHdg.value,
      currentSpeed: _speedNotifier.value,
    );
  }

  Future<String?> _chooseParticipantReportReason(AppLocalizations l10n) {
    final reasons = <String, String>{
      'inappropriate': l10n.reportReasonInappropriate,
      'harassment': l10n.reportReasonHarassment,
      'dangerous': l10n.reportReasonDangerous,
      'spam': l10n.reportReasonSpam,
      'other': l10n.reportReasonOther,
    };
    return showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                l10n.publicGatheringReportReason,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            for (final entry in reasons.entries)
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: Text(entry.value),
                onTap: () => Navigator.pop(sheetContext, entry.key),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showParticipantSafetyActions(
    ConvoyMemberLocation member,
    AppLocalizations l10n,
  ) async {
    if (!widget.convoy.isPublic || member.userId == _myUserId) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                member.userLabel,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: Text(l10n.publicGatheringReportParticipant),
              onTap: () => Navigator.pop(sheetContext, 'report'),
            ),
            ListTile(
              leading: const Icon(Icons.block),
              title: Text(l10n.publicGatheringBlockParticipant),
              onTap: () => Navigator.pop(sheetContext, 'block'),
            ),
          ],
        ),
      ),
    );
    if (action == 'report') {
      final reason = await _chooseParticipantReportReason(l10n);
      if (reason == null) return;
      await _controller.reportParticipant(
        convoyId: widget.convoy.id,
        participantId: member.userId,
        reason: reason,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.publicGatheringReportSent)));
      }
    } else if (action == 'block') {
      await _controller.blockParticipant(participantId: member.userId);
      if (!mounted) return;
      setState(() {
        _blockedParticipantIds.add(member.userId);
        _memberLocations.removeWhere((item) => item.userId == member.userId);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.publicGatheringBlocked)));
    }
  }

  bool _isPinActive(ConvoyPin pin) {
    final ttl = switch (pin.type) {
      'meetup' ||
      'parking' ||
      'food_stop' ||
      'charging' ||
      'hangout' => _poiPinTtl,
      _ => _pinTtl,
    };
    return DateTime.now().difference(pin.createdAt) <= ttl;
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

  // Dark map between sunset and sunrise at the current location. Falls back to
  // 19:00–06:59 when there's no GPS fix yet or during polar day/night.
  bool _isNightTime() {
    final now = DateTime.now();
    final loc = _myLocation;
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

  Future<void> _startLocationSync() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    _positionSubscription?.cancel();
    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: AppleSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 0,
            activityType: ActivityType.automotiveNavigation,
            pauseLocationUpdatesAutomatically: false,
            showBackgroundLocationIndicator: true,
          ),
        ).listen((position) {
          final point = LatLng(position.latitude, position.longitude);
          final rawSpeed = position.speed < 0 ? 0.0 : position.speed;
          final newSpeed = rawSpeed * 3.6;
          final newHeading = (position.speed > 0.5 && position.heading >= 0)
              ? position.heading
              : _myHeading;
          final hadLocation = _myLocation != null;

          if (mounted) {
            // Compute navigation state synchronously (before setState).
            double newDistToManeuver = double.infinity;
            int? newSign;
            String? newText;
            String? newManeuverStreetName;
            String? newStreetName;
            double? newRemaining;
            double headingForArrow = newHeading;

            if (_routePoints.isNotEmpty && _routeInstructions.isNotEmpty) {
              // Use segment projection for accurate route position.
              final (_, nearestIdx, distToRouteM) = _projectOntoRoute(point);

              // Remaining distance via O(1) cumulative-dist lookup.
              if (_isNavigating &&
                  _cumulativeDist.length == _routePoints.length) {
                newRemaining = (_totalRouteDistM - _cumulativeDist[nearestIdx])
                    .clamp(0.0, _totalRouteDistM);
              }

              int instrIdx = 0;
              for (int i = 0; i < _routeInstructions.length - 1; i++) {
                if (_routeInstructions[i + 1].pointIndex > nearestIdx) {
                  instrIdx = i;
                  break;
                }
                instrIdx = i + 1;
              }
              // Track current street name
              final currentInstr = _routeInstructions[instrIdx];
              if (currentInstr.streetName.isNotEmpty) {
                newStreetName = currentInstr.streetName;
              }
              final nextIdx = instrIdx + 1;
              if (nextIdx < _routeInstructions.length) {
                final next = _routeInstructions[nextIdx];
                double dist = 0;
                for (
                  int i = nearestIdx;
                  i < next.pointIndex && i < _routePoints.length - 1;
                  i++
                ) {
                  dist += _segDist(_routePoints[i], _routePoints[i + 1]);
                }
                newDistToManeuver = dist;
                newSign = next.sign;
                newText = next.text;
                newManeuverStreetName = next.streetName;
              } else {
                newText = '';
                newManeuverStreetName = '';
              }

              // ROUTE-LOCKED HEADING: Use route direction exclusively when
              // on route. This is how Google Maps/Waze work — no blending.
              final routeHeading = _routeHeadingAt(nearestIdx);
              if (distToRouteM < 45) {
                // Full route lock within 45m — handles typical GPS inaccuracy.
                headingForArrow = routeHeading;
              } else {
                // Off-route: use GPS heading.
                headingForArrow = newHeading;
              }
            }

            // Always update fields directly (no setState for position/speed
            // in follow mode — avoids full widget-tree rebuild every GPS tick,
            // which was causing the arrow to stutter every ~1-3 s).
            _speedNotifier.value = newSpeed;
            _myLocation = point;
            _locationNotifier.value = point;
            _myHeading = headingForArrow;
            if (!_isFollowingMyPosition &&
                (_deviceCompassHeading == null || newSpeed > 6.0)) {
              _arrowHdg.value = headingForArrow;
            }
            _distToNextManeuver = newDistToManeuver;
            unawaited(_maybeRefreshRoadSpeedLimit(point));

            if (!_hasCenteredOnInitialGps &&
                !_isFollowingMyPosition &&
                _routePoints.isEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted || _hasCenteredOnInitialGps) return;
                if (_usingAppleMapKit) {
                  setState(() {
                    _hasCenteredOnInitialGps = true;
                  });
                  return;
                }
                try {
                  _mapController.move(point, _followZoom);
                  _hasCenteredOnInitialGps = true;
                } catch (e) {
                  debugPrint('Convoy initial GPS centering skipped: $e');
                }
              });
            }
            if (!hadLocation) {
              unawaited(_loadAlerts());
            }

            // Voice navigation (fire before setState check).
            if (_isNavigating &&
                newText != null &&
                newDistToManeuver.isFinite) {
              _announceManeuver(newText, newDistToManeuver);
            }

            // Compute routing status string.
            if (newRemaining != null) {
              _remainingDistM = newRemaining;
              final remKm = newRemaining / 1000;
              final l10nR = AppLocalizations.of(context)!;
              final distStr = remKm >= 1.0
                  ? '${remKm.toStringAsFixed(1)} km ${l10nR.mapRemaining}'
                  : '${newRemaining.round()} m ${l10nR.mapRemaining}';
              final etaSpeedKmh = _smartEtaSpeedKmh(newSpeed);
              if (etaSpeedKmh > 0 && newRemaining > 50) {
                final sec = newRemaining / (etaSpeedKmh / 3.6);
                final arrival = DateTime.now().add(
                  Duration(seconds: sec.round()),
                );
                final hh = arrival.hour.toString().padLeft(2, '0');
                final mm = arrival.minute.toString().padLeft(2, '0');
                _routingStatus = '$distStr  •  $hh:$mm';
              } else {
                _routingStatus = distStr;
              }
            }

            // Proximity check.
            _pruneDismissedNearbyAlert(point);
            _nearbyAlert = AlertModel.mostRelevantNearby(
              _alerts,
              point,
              dismissedAlert: _dismissedNearbyAlert,
            );

            // Only call setState when UI-visible text actually changes, or
            // when not following (marker layer needs rebuild).
            final needsRebuild =
                !_isFollowingMyPosition ||
                newSign != null ||
                newText != null ||
                newManeuverStreetName != null ||
                newStreetName != null;
            if (needsRebuild) {
              setState(() {
                if (newSign != null) _nextManeuverSign = newSign;
                if (newText != null) _nextManeuverText = newText;
                if (newManeuverStreetName != null) {
                  _nextManeuverStreetName = newManeuverStreetName;
                }
                if (newStreetName != null) _currentStreetName = newStreetName;
              });
            }

            // Feed the camera ticker with the latest target.
            // The ticker interpolates smoothly at 60 fps — no direct
            // moveAndRotate call here (that was causing jank).
            if (_isFollowingMyPosition) {
              if (!_camInitialized) {
                _curLat = _tgtLat = point.latitude;
                _curLng = _tgtLng = point.longitude;
                _curHdg = _tgtHdg = _filteredTgtHdg = headingForArrow;
                _rawCompassHdg = headingForArrow;
                _gpsSpeedMps = rawSpeed;
                _lastLocForBearing = point;
                _lastGpsAt = DateTime.now();
                _camInitialized = true;
                final zoom = _targetZoom();
                _curZoom = _tgtZoom = zoom;
                _moveCameraForNav(
                  lat: point.latitude,
                  lng: point.longitude,
                  headingDeg: headingForArrow,
                  zoom: zoom,
                );
              } else {
                // Blend new GPS fix instead of snapping target → eliminates
                // the 1Hz "tick-tick" jump. Dead reckoning in _onCamTick
                // keeps moving the target forward between samples.
                final distToTarget = math.sqrt(
                  math.pow((_tgtLat - point.latitude) * 111320.0, 2) +
                      math.pow(
                        (_tgtLng - point.longitude) *
                            111320.0 *
                            math.cos(point.latitude * math.pi / 180.0),
                        2,
                      ),
                );
                if (rawSpeed > 3.0 && distToTarget < 25.0) {
                  // Lower blend = trust dead reckoning more → smoother ride.
                  const blend = 0.22;
                  _tgtLat = _tgtLat * (1 - blend) + point.latitude * blend;
                  _tgtLng = _tgtLng * (1 - blend) + point.longitude * blend;
                } else {
                  _tgtLat = point.latitude;
                  _tgtLng = point.longitude;
                }
                _rawCompassHdg = headingForArrow;
                _gpsSpeedMps = rawSpeed;
                _lastGpsAt = DateTime.now();

                // When route-locked heading is active (headingForArrow came
                // from the route), use it directly instead of blending with
                // motion heading. This prevents jitter at low GPS speeds.
                final onRoute =
                    _routePoints.isNotEmpty && _routeInstructions.isNotEmpty;
                if (onRoute) {
                  _tgtHdg = headingForArrow;

                  // POSITION SNAPPING: progressive blend toward route.
                  // Wider zone (45m) handles phone GPS inaccuracy reliably.
                  final (snapped, _, distM) = _projectOntoRoute(point);
                  if (distM < 45) {
                    final snapBlend = ((45.0 - distM) / 45.0).clamp(0.0, 1.0);
                    _tgtLat =
                        _tgtLat * (1 - snapBlend) +
                        snapped.latitude * snapBlend;
                    _tgtLng =
                        _tgtLng * (1 - snapBlend) +
                        snapped.longitude * snapBlend;
                  }
                } else {
                  // Movement-derived bearing is much stabler than raw compass.
                  final prev = _lastLocForBearing;
                  if (prev != null) {
                    final dLat = point.latitude - prev.latitude;
                    final dLng = point.longitude - prev.longitude;
                    final move2 = dLat * dLat + dLng * dLng;
                    if (move2 > 1.0e-10) {
                      final motionHeading = _wrap360(
                        math.atan2(dLng, dLat) * 180 / math.pi,
                      );
                      final compassWeight = (_gpsSpeedMps < 2.0)
                          ? ((2.0 - _gpsSpeedMps) / 2.0).clamp(0.0, 1.0)
                          : 0.0;
                      final motionToCompass = _angleDiff(
                        motionHeading,
                        _rawCompassHdg,
                      );
                      _tgtHdg = _wrap360(
                        motionHeading + motionToCompass * compassWeight * 0.35,
                      );
                    }
                  }
                }
                _lastLocForBearing = point;

                final targetAlpha = (_gpsSpeedMps / 16.0).clamp(0.14, 0.45);
                final targetStep = _angleDiff(_filteredTgtHdg, _tgtHdg);
                _filteredTgtHdg = _wrap360(
                  _filteredTgtHdg + targetStep * targetAlpha,
                );
                _tgtZoom = _targetZoom();
              }
            }

            // Auto-retry pending route on first GPS fix.
            if (!hadLocation &&
                _pendingDestination != null &&
                _routePoints.isEmpty &&
                !_isRouting) {
              final dest = _pendingDestination!;
              _pendingDestination = null;
              _routeToDestination(dest);
            }
          }

          // Fire-and-forget — never await network I/O inside GPS stream.
          if (_shareLiveLocation) {
            _controller.updateMyLocation(
              convoyId: widget.convoy.id,
              position: point,
            );
          }
          unawaited(_syncCarPlayConvoyState(_memberLocations));
        });
  }

  Future<void> _setLiveLocationSharing(bool enabled) async {
    if (!widget.convoy.isPublic || enabled == _shareLiveLocation) return;
    setState(() => _shareLiveLocation = enabled);
    if (enabled) {
      final position = _myLocation;
      if (position != null) {
        await _controller.updateMyLocation(
          convoyId: widget.convoy.id,
          position: position,
        );
      }
    } else {
      await _controller.clearMyLocation(convoyId: widget.convoy.id);
    }
  }

  @override
  void dispose() {
    unawaited(CarPlayBridgeService.instance.clearConvoyState());
    if (widget.convoy.isPublic && _shareLiveLocation) {
      unawaited(_controller.clearMyLocation(convoyId: widget.convoy.id));
    }
    _positionSubscription?.cancel();
    _compassSubscription?.cancel();
    _pinRefreshTimer?.cancel();
    _locationPollTimer?.cancel();
    _alertsTimer?.cancel();
    _themeTimer?.cancel();
    _mapInteractionResumeTimer?.cancel();
    _tileHttpClient.close();
    _arrowHdg.dispose();
    _speedNotifier.dispose();
    _locationNotifier.dispose();
    _searchDebounce?.cancel();
    _camTicker.dispose();
    _messageController.dispose();
    _chatScrollController.dispose();
    _addressSearchController.dispose();
    _searchFocus.dispose();
    _controller.dispose();
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
      } else {
        final shortestTurn =
            ((normalizedHeading - previousHeading + 540) % 360) - 180;
        _deviceCompassHeading =
            (previousHeading + shortestTurn * 0.32 + 360) % 360;
      }

      if (!_isFollowingMyPosition && _speedNotifier.value <= 6.0) {
        _arrowHdg.value = _deviceCompassHeading!;
      }
    });
  }

  @override
  void didUpdateWidget(covariant ConvoyRoomScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.convoy.id != widget.convoy.id) {
      _bindRealtimeStreams();
      _sentMessages = const [];
      _isSendingMessage = false;
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSendingMessage) {
      return;
    }

    setState(() => _isSendingMessage = true);
    try {
      final message = await _controller.sendMessage(
        convoyId: widget.convoy.id,
        text: text,
      );
      if (!mounted) return;
      setState(() {
        _sentMessages = [..._sentMessages, message];
        _isSendingMessage = false;
      });
      if (_messageController.text.trim() == text) {
        _messageController.clear();
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_chatScrollController.hasClients) return;
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      });
    } catch (error) {
      debugPrint('Convoy message send failed: $error');
      if (!mounted) return;
      setState(() => _isSendingMessage = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.authGenericError)),
      );
    }
  }

  // ── Waze-style dynamic zoom ────────────────────────────────────────────
  double _targetZoom() {
    final base = _use3DMap ? 17.5 : _followZoom;
    final d = _distToNextManeuver;
    if (d <= 0) return base;

    final nearFactor = ((320.0 - d) / 320.0).clamp(0.0, 1.0);
    final distBoost = math.pow(nearFactor, 1.28).toDouble() * 1.05;

    final absSign = _nextManeuverSign.abs();
    final signBoost = switch (absSign) {
      3 => 0.42,
      2 => 0.28,
      1 => 0.14,
      6 => 0.34,
      _ => 0.0,
    };
    final proximityWeight = ((220.0 - d) / 220.0).clamp(0.0, 1.0);
    final add = distBoost + signBoost * proximityWeight;

    final maxZoom = _use3DMap ? 18.8 : 17.2;
    return (base + add).clamp(base, maxZoom);
  }

  /// Distance-based lookahead: find heading 40m ahead along route.
  /// Much more stable than naive "next 3 points" approach.
  double _routeLookaheadHeading(int startIdx, double lookaheadM) {
    if (_routePoints.length < 2) return _myHeading;
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

    final a = _routePoints[i];
    final b = _routePoints[endIdx];
    return _wrap360(
      math.atan2(b.longitude - a.longitude, b.latitude - a.latitude) *
          180 /
          math.pi,
    );
  }

  /// Project location onto nearest route segment (not just nearest point).
  /// Returns (closestPoint, segmentIndex, distanceToRoute).
  (LatLng, int, double) _projectOntoRoute(LatLng loc) {
    if (_routePoints.length < 2) return (loc, 0, 0);

    // Scan forward from last known index (never go backwards to avoid jumps).
    final searchStart = _lastNearestIdx.clamp(0, _routePoints.length - 2);
    final searchEnd = (searchStart + 50).clamp(0, _routePoints.length - 2);

    int bestSeg = searchStart;
    double bestDistSq = double.infinity;
    LatLng bestProj = _routePoints[searchStart];

    for (int i = searchStart; i <= searchEnd; i++) {
      final a = _routePoints[i];
      final b = _routePoints[i + 1];
      // Project loc onto segment a–b.
      final (proj, distSq) = _projectPointOnSegment(loc, a, b);
      if (distSq < bestDistSq) {
        bestDistSq = distSq;
        bestProj = proj;
        bestSeg = i;
      }
    }

    // Only advance if we've clearly passed current segment start.
    // This prevents "magnetizing" to far-ahead segments at intersections.
    if (bestSeg > _lastNearestIdx) {
      final distToOldStart = _segDist(loc, _routePoints[_lastNearestIdx]);
      if (distToOldStart > 8) {
        _lastNearestIdx = bestSeg;
      }
    }

    // Smooth visual trim so the passed route removal does not appear jumpy.
    if (_displayNearestIdx < _lastNearestIdx) {
      final step = (_lastNearestIdx - _displayNearestIdx).clamp(0, 6);
      _displayNearestIdx += step;
    }

    return (bestProj, _lastNearestIdx, math.sqrt(bestDistSq));
  }

  /// Project point P onto line segment A–B, return (projectedPoint, distanceSq).
  (LatLng, double) _projectPointOnSegment(LatLng p, LatLng a, LatLng b) {
    const lat2m = 111320.0;
    final lng2m = 111320.0 * math.cos(a.latitude * math.pi / 180.0);

    final ax = a.latitude * lat2m;
    final ay = a.longitude * lng2m;
    final bx = b.latitude * lat2m;
    final by = b.longitude * lng2m;
    final px = p.latitude * lat2m;
    final py = p.longitude * lng2m;

    final abx = bx - ax;
    final aby = by - ay;
    final apx = px - ax;
    final apy = py - ay;

    final abLenSq = abx * abx + aby * aby;
    if (abLenSq < 1e-10) {
      // Degenerate segment.
      final dx = px - ax;
      final dy = py - ay;
      return (a, dx * dx + dy * dy);
    }

    var t = (apx * abx + apy * aby) / abLenSq;
    t = t.clamp(0.0, 1.0);

    final projX = ax + t * abx;
    final projY = ay + t * aby;
    final dx = px - projX;
    final dy = py - projY;

    final projLat = projX / lat2m;
    final projLng = projY / lng2m;
    return (LatLng(projLat, projLng), dx * dx + dy * dy);
  }

  double _routeHeadingAt(int idx) {
    // Use 40m lookahead for smooth and stable heading.
    return _routeLookaheadHeading(idx, 40.0);
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

  String _addressTitleFromResult(Map<String, dynamic> result) {
    // Show business / POI name when available
    final name = (result['name']?.toString() ?? '').trim();
    if (name.isNotEmpty) return name;

    final addr = result['address'];
    if (addr is Map<String, dynamic>) {
      String fromAddress(String key) => (addr[key] ?? '').toString().trim();
      final road = [
        fromAddress('road'),
        fromAddress('pedestrian'),
        fromAddress('residential'),
        fromAddress('street'),
        fromAddress('footway'),
      ].firstWhere((v) => v.isNotEmpty, orElse: () => '');
      final houseNumber = fromAddress('house_number');
      if (road.isNotEmpty) {
        return houseNumber.isNotEmpty ? '$road $houseNumber' : road;
      }
    }

    final display = (result['display_name']?.toString() ?? '').trim();
    if (display.isEmpty) return '';
    final parts = display
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '';

    final first = parts[0];
    final second = parts.length > 1 ? parts[1] : '';
    final firstIsHouseNumber = RegExp(r'^\d+[A-Za-z]?$').hasMatch(first);
    if (firstIsHouseNumber && second.isNotEmpty) {
      return '$second $first';
    }

    return first;
  }

  String _addressSubtitleFromResult(Map<String, dynamic> result) {
    // When result has a POI name, show the street as subtitle
    final name = (result['name']?.toString() ?? '').trim();
    if (name.isNotEmpty) {
      final addr = result['address'];
      if (addr is Map) {
        String getPart(String key) => (addr[key] ?? '').toString().trim();
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
        ].firstWhere((v) => v.isNotEmpty, orElse: () => '');
        final parts = <String>[
          if (road.isNotEmpty)
            houseNumber.isNotEmpty ? '$road $houseNumber' : road,
          if (city.isNotEmpty) city,
        ];
        if (parts.isNotEmpty) return parts.join(', ');
      }
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

  // ── Navigation helpers ─────────────────────────────────────────────────
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

    final cappedLive = liveSpeedKmh
        .clamp(0.0, selectedVehicleSpeedKmh)
        .toDouble();
    if (cappedLive >= 3.0) {
      _etaLastMovementAt = DateTime.now();
      if (_etaSmoothedSpeedKmh <= 0) {
        _etaSmoothedSpeedKmh = cappedLive;
      } else {
        _etaSmoothedSpeedKmh = _etaSmoothedSpeedKmh * 0.75 + cappedLive * 0.25;
      }
      return _etaSmoothedSpeedKmh
          .clamp(1.0, selectedVehicleSpeedKmh)
          .toDouble();
    }

    if (_etaSmoothedSpeedKmh > 0 && _etaLastMovementAt != null) {
      final pause = DateTime.now().difference(_etaLastMovementAt!);
      if (pause <= _etaPauseGrace) {
        _etaSmoothedSpeedKmh = (_etaSmoothedSpeedKmh * 0.96)
            .clamp(3.0, selectedVehicleSpeedKmh)
            .toDouble();
        return _etaSmoothedSpeedKmh;
      }
    }

    return 0;
  }

  double _currentEtaSpeedKmh() {
    final selectedVehicleSpeedKmh =
        UserPreferencesService.instance.maxSpeedKmh.value;
    if (selectedVehicleSpeedKmh <= 0 || _etaSmoothedSpeedKmh <= 0) return 0;
    final lastMovement = _etaLastMovementAt;
    if (lastMovement == null) return 0;
    if (DateTime.now().difference(lastMovement) > _etaPauseGrace) return 0;
    return _etaSmoothedSpeedKmh.clamp(1.0, selectedVehicleSpeedKmh).toDouble();
  }

  (int turns, int complexTurns) _remainingManeuversFromCurrentPosition() {
    if (_routeInstructions.isEmpty) return (0, 0);

    int instrIdx = 0;
    for (int i = 0; i < _routeInstructions.length - 1; i++) {
      if (_routeInstructions[i + 1].pointIndex > _lastNearestIdx) {
        instrIdx = i;
        break;
      }
      instrIdx = i + 1;
    }

    final start = (instrIdx + 1).clamp(0, _routeInstructions.length);
    var turns = 0;
    var complexTurns = 0;
    for (int i = start; i < _routeInstructions.length; i++) {
      final sign = _routeInstructions[i].sign;
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
    final etaSpeedKmh = _currentEtaSpeedKmh();
    if (etaSpeedKmh <= 0) return '';
    final baseSec = _remainingDistM / (etaSpeedKmh / 3.6);
    final remaining = _remainingManeuversFromCurrentPosition();
    final maneuverDelaySec = _etaManeuverDelaySeconds(
      turns: remaining.$1,
      complexTurns: remaining.$2,
      remainingMeters: _remainingDistM,
    );
    final remainingSec = baseSec + maneuverDelaySec;
    final arrival = DateTime.now().add(Duration(seconds: remainingSec.round()));
    final h = arrival.hour.toString().padLeft(2, '0');
    final m = arrival.minute.toString().padLeft(2, '0');
    final hhmm = '$h:$m';
    final minLeft = (remainingSec / 60).ceil();
    if (minLeft < 1) return l10n.convoyEtaArrived;
    if (minLeft < 60) return l10n.convoyEtaMinutes(minLeft, hhmm);
    final hours = minLeft ~/ 60;
    final mins = minLeft % 60;
    return l10n.convoyEtaHours(hours, mins, hhmm);
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

  // Cheap flat-earth approximation — accurate enough for short segments.
  double _segDist(LatLng a, LatLng b) {
    const lat2m = 111320.0;
    final lng2m = 111320.0 * math.cos(a.latitude * math.pi / 180.0);
    final dx = (b.latitude - a.latitude) * lat2m;
    final dy = (b.longitude - a.longitude) * lng2m;
    return math.sqrt(dx * dx + dy * dy);
  }

  void _onCamTick(Duration elapsed) {
    if (!_isFollowingMyPosition || !_camInitialized) return;

    final last = _lastCamTick;
    _lastCamTick = elapsed;
    if (last == null) return;
    final dtSec = (elapsed - last).inMicroseconds / 1000000.0;
    if (dtSec <= 0) return;

    // Dead reckoning: extrapolate target forward between 1Hz GPS samples so
    // the camera glides instead of freezing for ~1s and then jumping.
    final lastGps = _lastGpsAt;
    if (_gpsSpeedMps > 0.8 &&
        lastGps != null &&
        DateTime.now().difference(lastGps).inMilliseconds < 2500) {
      final hdgRad = _filteredTgtHdg * math.pi / 180.0;
      final dM = _gpsSpeedMps * dtSec;
      const lat2m = 111320.0;
      final lng2m = 111320.0 * math.cos(_tgtLat * math.pi / 180.0);
      _tgtLat += dM * math.cos(hdgRad) / lat2m;
      _tgtLng += dM * math.sin(hdgRad) / lng2m;
    }

    final speedN = (_gpsSpeedMps / 16.0).clamp(0.0, 1.0);
    final kPos = (dtSec * (2.3 + speedN * 2.9)).clamp(0.04, 0.35);
    final kHdg = (dtSec * (1.9 + speedN * 3.2)).clamp(0.03, 0.33);
    final maxTurnPerSec = 55.0 + speedN * 95.0;
    final maxTurnThisTick = maxTurnPerSec * dtSec;

    final dLat = _tgtLat - _curLat;
    final dLng = _tgtLng - _curLng;
    final rawDiff = _angleDiff(_curHdg, _filteredTgtHdg);
    final turnN = (rawDiff.abs() / 45.0).clamp(0.0, 1.0);
    final boostedMaxTurn = maxTurnThisTick * (1.0 + turnN * 2.2);
    final diff = rawDiff.clamp(-boostedMaxTurn, boostedMaxTurn);
    // Deadband: skip GPU work when already at target.
    if (dLat.abs() < 1e-7 && dLng.abs() < 1e-7 && diff.abs() < 0.05) return;
    final turnPosAlpha = (kPos * (1.0 + turnN * 0.35)).clamp(0.04, 0.55);
    final turnHdgAlpha = (kHdg * (1.0 + turnN * 2.0)).clamp(0.03, 0.70);
    _curLat += dLat * turnPosAlpha;
    _curLng += dLng * turnPosAlpha;
    _curHdg = _wrap360(_curHdg + diff * turnHdgAlpha);
    final zoomAlpha = (dtSec * 2.8).clamp(0.04, 0.25);
    _curZoom += (_tgtZoom - _curZoom) * zoomAlpha;
    // Arrow shows offset between camera heading and route heading
    // so the arrow always points along the road on screen.
    _arrowHdg.value = _angleDiff(_curHdg, _filteredTgtHdg);
    final zoom = _curZoom;

    // Paint every tick (60fps) while actively moving. The previous 33ms
    // throttle produced visible 30fps stutter especially in 3D where the
    // perspective magnifies translation. Only throttle when stationary.
    final moveDelta2 = dLat * dLat + dLng * dLng;
    final lastCam = _lastCameraTickAt;
    final isMoving =
        _gpsSpeedMps > 1.0 || moveDelta2 > 1e-12 || diff.abs() > 0.05;
    final shouldPaintCamera =
        isMoving ||
        lastCam == null ||
        (elapsed - lastCam).inMilliseconds >= 100;
    if (!shouldPaintCamera) return;
    _lastCameraTickAt = elapsed;

    _moveCameraForNav(
      lat: _curLat,
      lng: _curLng,
      headingDeg: _curHdg,
      zoom: zoom,
    );
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
    int limit = 12,
    LatLng? proximity,
    bool useProximity = true,
  }) async {
    final token = BackendConfig.mapboxAccessToken.trim();
    if (token.isEmpty) return const [];

    return MapboxSearchService.search(
      query,
      accessToken: token,
      language: _mapboxLanguageCode(),
      countryCodes: CountryVehicleRules.supportedCountries,
      proximity: useProximity ? (proximity ?? _myLocation) : null,
      limit: limit,
    );
  }

  Future<List<Map<String, dynamic>>> _fetchPrimaryGeocodingResults(
    String query, {
    int limit = 12,
    LatLng? proximity,
    bool includeGlobalResults = true,
  }) async {
    final effectiveProximity = proximity ?? _myLocation;
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
      'q': query,
      'format': 'jsonv2',
      'addressdetails': '1',
      'limit': '$limit',
      'dedupe': '1',
      'countrycodes': codes,
    };

    final hnMatch = RegExp(
      r'^\s*(.+?)\s+(\d+\s*[A-Za-z]?)\s*$',
    ).firstMatch(query);
    final structuredParams = <String, String>{...baseParams};
    if (hnMatch != null) {
      structuredParams['street'] = '${hnMatch.group(1)} ${hnMatch.group(2)}';
      structuredParams.remove('q');
    }

    final prox = proximity ?? _myLocation;
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
    if (_myLocation != null && lat != null && lon != null) {
      final m = Geolocator.distanceBetween(
        _myLocation!.latitude,
        _myLocation!.longitude,
        lat,
        lon,
      );
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

      if (strict.isNotEmpty) candidates = strict;
    }

    final scored =
        candidates
            .map((r) => (item: r, score: _scoreSuggestion(r, query, hnMatch)))
            .toList()
          ..sort((a, b) {
            final byScore = b.score.compareTo(a.score);
            if (byScore != 0) return byScore;
            final current = _myLocation;
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
      final key = '$title|$subtitle';
      if (seen.add(key)) deduped.add(s.item);
      if (deduped.length >= 6) break;
    }
    return deduped;
  }

  Future<void> _searchAddress(String rawQuery) async {
    final l10n = AppLocalizations.of(context)!;
    final query = rawQuery.trim();
    if (query.isEmpty) return;
    if (_analyzeNextSelectedRouteWithAi) {
      _aiDestinationSelectionStarted = true;
    }
    setState(() => _showSuggestions = false);
    try {
      final raw = await _fetchPrimaryGeocodingResults(query, limit: 12);
      if (raw.isEmpty) {
        if (!mounted) return;
        setState(() {
          _routingStatus = l10n.mapAddressNotFound;
        });
        _cancelPendingConvoyAiRouteAnalysis();
        return;
      }
      final ranked = _rankAndDedupeSuggestions(raw, query);
      if (ranked.isEmpty) throw StateError('lookup_failed');
      final first = ranked.first;
      final lat = double.tryParse(first['lat']?.toString() ?? '');
      final lon = double.tryParse(first['lon']?.toString() ?? '');
      if (lat == null || lon == null) throw StateError('lookup_failed');
      if (!mounted) return;
      _routeToDestination(LatLng(lat, lon));
    } catch (_) {
      if (!mounted) return;
      setState(() => _routingStatus = l10n.mapAddressLookupFailed);
      _cancelPendingConvoyAiRouteAnalysis();
    }
  }

  void _selectSuggestion(Map<String, dynamic> s) {
    final lat = double.tryParse(s['lat']?.toString() ?? '');
    final lon = double.tryParse(s['lon']?.toString() ?? '');
    if (lat == null || lon == null) return;
    final label = _addressTitleFromResult(s);
    _addressSearchController.text = label;
    _destinationLabel = label;
    _searchFocus.unfocus();
    setState(() {
      _suggestions = [];
      _showSuggestions = false;
    });
    _routeToDestination(LatLng(lat, lon));
  }

  Future<void> _showConvoySearchSheet() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(
      text: _addressSearchController.text,
    );
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
        final raw = await _fetchPrimaryGeocodingResults(query, limit: 12);
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
          builder: (ctx, setSheetState) {
            void onChanged(String value) {
              searchDebounce?.cancel();
              setSheetState(() {});
              searchDebounce = Timer(
                const Duration(milliseconds: 300),
                () => runSearch(value, setSheetState),
              );
            }

            final favorites = ConvoyFavoritePlacesService.instance.places.value;
            final home = ConvoyFavoritePlacesService.instance.findByIcon(
              'home',
            );
            final work = ConvoyFavoritePlacesService.instance.findByIcon(
              'work',
            );
            final school = ConvoyFavoritePlacesService.instance.findByIcon(
              'school',
            );
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
                            color: const Color(0x663AA8FF),
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
                          _addressSearchController.text = query;
                          _destinationLabel = query;
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
                        // ── POI shortcut cards ──────────────────────────
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _ConvoySearchShortcutCard(
                                icon: Icons.bookmark,
                                label: l10n.searchSaved,
                              ),
                              _ConvoySearchShortcutCard(
                                icon: Icons.ev_station,
                                label: l10n.convoyPoiCharging,
                                onTap: () => _showConvoyPoiSheet(
                                  sheetCtx: sheetContext,
                                  title: l10n.convoyPoiCharging,
                                  queries: const [
                                    'charging station',
                                    'ev charging',
                                    'laddstation',
                                  ],
                                  icon: Icons.ev_station,
                                ),
                              ),
                              _ConvoySearchShortcutCard(
                                icon: Icons.restaurant,
                                label: l10n.convoyPoiFoodStop,
                                onTap: () => _showConvoyPoiSheet(
                                  sheetCtx: sheetContext,
                                  title: l10n.convoyPoiFoodStop,
                                  queries: const ['restaurant', 'fast food'],
                                  icon: Icons.restaurant,
                                ),
                              ),
                              _ConvoySearchShortcutCard(
                                icon: Icons.local_parking,
                                label: l10n.convoyPoiParking,
                                onTap: () => _showConvoyPoiSheet(
                                  sheetCtx: sheetContext,
                                  title: l10n.convoyPoiParking,
                                  queries: const ['parking', 'parkering'],
                                  icon: Icons.local_parking,
                                ),
                              ),
                              _ConvoySearchShortcutCard(
                                icon: Icons.local_gas_station,
                                label: l10n.routeStopFuel,
                                onTap: () => _showConvoyPoiSheet(
                                  sheetCtx: sheetContext,
                                  title: l10n.routeStopFuel,
                                  queries: const [
                                    'gas station',
                                    'fuel',
                                    'bensinstation',
                                  ],
                                  icon: Icons.local_gas_station,
                                ),
                              ),
                              _ConvoySearchShortcutCard(
                                icon: Icons.local_cafe,
                                label: l10n.routeStopCafe,
                                onTap: () => _showConvoyPoiSheet(
                                  sheetCtx: sheetContext,
                                  title: l10n.routeStopCafe,
                                  queries: const ['cafe', 'coffee', 'kafé'],
                                  icon: Icons.local_cafe,
                                ),
                              ),
                              _ConvoySearchShortcutCard(
                                icon: Icons.local_grocery_store,
                                label: l10n.routeStopGrocery,
                                onTap: () => _showConvoyPoiSheet(
                                  sheetCtx: sheetContext,
                                  title: l10n.routeStopGrocery,
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
                              .take(5)
                              .map(
                                (fav) => _ConvoySearchDestRow(
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
                                    (entry) => _ConvoySearchDestRow(
                                      icon: Icons.history,
                                      title: entry.label,
                                      subtitle: entry.address,
                                      onTap: () {
                                        Navigator.of(sheetContext).pop();
                                        _addressSearchController.text =
                                            entry.label;
                                        _destinationLabel = entry.label;
                                        _routeToDestination(entry.position);
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
                          return _ConvoySearchDestRow(
                            icon: Icons.location_on,
                            title: title,
                            subtitle: subtitle,
                            onTap: () {
                              Navigator.of(sheetContext).pop();
                              _addressSearchController.text = title;
                              _destinationLabel = title;
                              _selectSuggestion(suggestion);
                            },
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

  // ── Overpass POI helpers ────────────────────────────────────────────────
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
        final street = (tags['addr:street'] ?? '').toString().trim();
        final houseNumber = (tags['addr:housenumber'] ?? '').toString().trim();
        final city = (tags['addr:city'] ?? tags['addr:suburb'] ?? '')
            .toString()
            .trim();
        results.add({
          'lat': lat,
          'lon': lon,
          'name': name.isNotEmpty ? name : queries.first,
          'address': {
            if (street.isNotEmpty) 'road': street,
            if (houseNumber.isNotEmpty) 'house_number': houseNumber,
            if (city.isNotEmpty) 'city': city,
          },
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
    ].any((v) => v.isNotEmpty);
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
    final preferBrand =
        normalized.contains('fuel') ||
        normalized.contains('charging') ||
        normalized.contains('laddstation') ||
        normalized.contains('supermarket') ||
        normalized.contains('grocery') ||
        normalized.contains('livsmedel');
    if (preferBrand) {
      for (final v in [brand, operator, network, name]) {
        if (v.isNotEmpty) return v;
      }
    }
    for (final v in [name, brand, operator, network]) {
      if (v.isNotEmpty) return v;
    }
    return queries.first;
  }

  double _maxConvoyPoiFallbackDistanceMeters(List<String> queries) {
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

  Future<List<_ConvoyPoiCandidate>> _findConvoyNearbyPoi({
    required List<String> queries,
    int limit = 20,
  }) async {
    final me = _myLocation;
    if (me == null) return const [];

    final seen = <String>{};
    final candidates = <_ConvoyPoiCandidate>[];

    void addCandidate(Map<String, dynamic> r, String fallback) {
      final lat = double.tryParse(r['lat']?.toString() ?? '');
      final lon = double.tryParse(r['lon']?.toString() ?? '');
      if (lat == null || lon == null) return;
      final point = LatLng(lat, lon);
      final title = (r['name'] ?? fallback).toString().trim();
      final subtitle = _addressSubtitleFromResult(r);
      final key =
          '${title.toLowerCase()}|${lat.toStringAsFixed(4)},${lon.toStringAsFixed(4)}';
      if (!seen.add(key)) return;
      candidates.add(
        _ConvoyPoiCandidate(
          title: title,
          subtitle: subtitle,
          position: point,
          distanceMeters: _segDist(me, point),
        ),
      );
    }

    // Tiered Overpass radius: 2.5 km first, expand to 7 km if sparse.
    var poiResults = await _fetchOverpassPoiResults(
      queries: queries,
      center: me,
      radiusMeters: 2500,
    );
    if (poiResults.length < 5) {
      poiResults = await _fetchOverpassPoiResults(
        queries: queries,
        center: me,
        radiusMeters: 7000,
      );
    }
    for (final r in poiResults) {
      addCandidate(r, queries.first);
    }

    // Geocoding fallback when Overpass comes up empty.
    if (candidates.isEmpty) {
      final responses = await Future.wait(
        queries.map(
          (q) => _fetchPrimaryGeocodingResults(
            q,
            limit: 12,
            proximity: me,
            includeGlobalResults: false,
          ).catchError((_) => <Map<String, dynamic>>[]),
        ),
      );
      for (var i = 0; i < responses.length; i++) {
        for (final r in responses[i]) {
          addCandidate(r, queries[i]);
        }
      }
      final maxDist = _maxConvoyPoiFallbackDistanceMeters(queries);
      candidates.removeWhere((c) => c.distanceMeters > maxDist);
    }

    candidates.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return candidates.take(limit).toList(growable: false);
  }

  String _formatPoiDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  Future<void> _showConvoyPoiSheet({
    required BuildContext sheetCtx,
    required String title,
    required List<String> queries,
    required IconData icon,
  }) async {
    Navigator.of(sheetCtx).pop();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ConvoyPoiResultsSheet(
        title: title,
        icon: icon,
        loadCandidates: () => _findConvoyNearbyPoi(queries: queries),
        formatDistance: _formatPoiDistance,
        onSelected: (candidate) {
          _addressSearchController.text = candidate.title;
          _destinationLabel = candidate.title;
          _routeToDestination(candidate.position);
        },
      ),
    );
  }

  Color _memberColor(String userId) {
    final idx =
        userId.codeUnits.fold(0, (a, b) => a + b) % _avatarPalette.length;
    return _avatarPalette[idx];
  }

  bool _isMemberStale(ConvoyMemberLocation m) {
    return DateTime.now().difference(m.updatedAt) > const Duration(minutes: 5);
  }

  Widget _buildMemberMarker(
    ConvoyMemberLocation member,
    AppLocalizations l10n,
  ) {
    final isMe = member.userId == _myUserId;
    final stale = _isMemberStale(member);
    final color = isMe ? const Color(0xFF1E6BFF) : _memberColor(member.userId);
    final initial = member.userLabel.isNotEmpty
        ? member.userLabel[0].toUpperCase()
        : '?';
    final labelText = isMe ? l10n.convoyMemberMe : member.userLabel;
    final memberStyle = MapMarkerStyle.values.firstWhere(
      (style) => style.name == member.vehicleStyle,
      orElse: () => MapMarkerStyle.navigation,
    );
    final labelFontSize = isMe ? 11.0 : 9.0;
    final labelPadding = EdgeInsets.symmetric(
      horizontal: isMe ? 8 : 6,
      vertical: isMe ? 3 : 2,
    );
    final labelRadius = isMe ? 10.0 : 8.0;
    final markerSize = isMe ? 34.0 : 25.0;
    final iconSize = isMe ? 32.0 : 21.0;
    final arrowSize = isMe ? 30.0 : 21.0;
    return Opacity(
      opacity: stale ? 0.4 : 1.0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: labelPadding,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(labelRadius),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.5),
                  blurRadius: isMe ? 6 : 4,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Text(
              labelText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: labelFontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Container(
            width: markerSize,
            height: markerSize,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: isMe ? 2.5 : 1.5),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.6),
                  blurRadius: isMe ? 10 : 7,
                  spreadRadius: isMe ? 2 : 1,
                ),
              ],
            ),
            child: isMe
                ? UserLocationMarker(
                    headingNotifier: _arrowHdg,
                    lockNorthUp: false,
                    size: arrowSize,
                    backgroundColor: Colors.transparent,
                    borderColor: Colors.transparent,
                    borderWidth: 0,
                    showOuterGlow: false,
                  )
                : Center(
                    child: member.vehicleStyle.isEmpty
                        ? Text(
                            initial,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : UserLocationMarker.stylePreview(
                            memberStyle,
                            size: iconSize,
                            selected: false,
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _convoyCircleButton({
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

  void _pauseConvoyMapFollowingForInteraction() {
    _mapInteractionResumeTimer?.cancel();
    if (!_isFollowingMyPosition) return;
    setState(() => _isFollowingMyPosition = false);
  }

  void _resumeConvoyMapFollowingAfterInteraction() {
    _mapInteractionResumeTimer?.cancel();
    if (!_isNavigating) return;
    _mapInteractionResumeTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted || _isFollowingMyPosition || _myLocation == null) return;
      setState(() => _isFollowingMyPosition = true);
    });
  }

  Future<void> _showConvoyMapLayerPicker(AppLocalizations l10n) async {
    final useSatellite = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: const Color(0xFF0A1F63),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.mapLayerStyleTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.map_outlined, color: Colors.white70),
                title: Text(
                  l10n.mapLayerStandard,
                  style: const TextStyle(color: Colors.white),
                ),
                trailing: !_useSatelliteMap
                    ? const Icon(Icons.check, color: Color(0xFF55C8FF))
                    : null,
                onTap: () => Navigator.pop(sheetContext, false),
              ),
              ListTile(
                leading: const Icon(
                  Icons.satellite_alt_outlined,
                  color: Colors.white70,
                ),
                title: Text(
                  l10n.mapLayerSatellite,
                  style: const TextStyle(color: Colors.white),
                ),
                trailing: _useSatelliteMap
                    ? const Icon(Icons.check, color: Color(0xFF55C8FF))
                    : null,
                onTap: () => Navigator.pop(sheetContext, true),
              ),
            ],
          ),
        ),
      ),
    );
    if (useSatellite == null || useSatellite == _useSatelliteMap || !mounted) {
      return;
    }
    setState(() => _useSatelliteMap = useSatellite);
    UserPreferencesService.instance.useSatelliteMap.value = useSatellite;
  }

  Future<void> _openAiFromConvoyButton() async {
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
      await _showConvoySearchSheet();
      if (!_aiDestinationSelectionStarted) {
        _cancelPendingConvoyAiRouteAnalysis();
      }
      return;
    }
    await _analyzeConvoyRouteWithAi();
  }

  void _cancelPendingConvoyAiRouteAnalysis() {
    _analyzeNextSelectedRouteWithAi = false;
    _aiDestinationSelectionStarted = false;
  }

  void _analyzeSelectedConvoyRouteIfRequested() {
    if (!_analyzeNextSelectedRouteWithAi || _activeRoute == null) return;
    _cancelPendingConvoyAiRouteAnalysis();
    unawaited(_analyzeConvoyRouteWithAi());
  }

  Future<bool> _ensureConvoyAiConsent(AppLocalizations l10n) async {
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
    if (accepted != true) return false;
    await AiRouteAnalysisService.instance.setConsent(true);
    return true;
  }

  double _distanceToConvoyRouteMeters(LatLng point) {
    if (_routePoints.isEmpty) return double.infinity;
    if (_routePoints.length == 1) return _segDist(point, _routePoints.first);

    const lat2m = 111320.0;
    var best = double.infinity;
    for (var i = 0; i < _routePoints.length - 1; i++) {
      final a = _routePoints[i];
      final b = _routePoints[i + 1];
      final lng2m =
          lat2m *
          math.cos(
            ((point.latitude + a.latitude + b.latitude) / 3) * math.pi / 180,
          );
      final ax = a.longitude * lng2m;
      final ay = a.latitude * lat2m;
      final bx = b.longitude * lng2m;
      final by = b.latitude * lat2m;
      final px = point.longitude * lng2m;
      final py = point.latitude * lat2m;
      final dx = bx - ax;
      final dy = by - ay;
      final denominator = dx * dx + dy * dy;
      final t = denominator == 0
          ? 0.0
          : (((px - ax) * dx + (py - ay) * dy) / denominator).clamp(0.0, 1.0);
      final distance = math.sqrt(
        math.pow(px - (ax + t * dx), 2) + math.pow(py - (ay + t * dy), 2),
      );
      if (distance < best) best = distance;
    }
    return best;
  }

  Map<String, int> _convoyRouteAlertCounts() {
    final counts = <String, int>{};
    for (final alert in _alerts) {
      if (!alert.type.showsProximityWarning ||
          _distanceToConvoyRouteMeters(alert.position) > 750) {
        continue;
      }
      counts.update(alert.type.key, (value) => value + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  Future<void> _analyzeConvoyRouteWithAi() async {
    final route = _activeRoute;
    if (route == null || _isAiAnalyzing) return;
    final l10n = AppLocalizations.of(context)!;
    if (!await _ensureConvoyAiConsent(l10n) || !mounted) return;

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
    unawaited(_showConvoyAiLoadingDialog(l10n));
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
        alertCounts: _convoyRouteAlertCounts(),
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
      _closeConvoyAiLoadingDialog();
      if (mounted) setState(() => _isAiAnalyzing = false);
    }
    if (mounted && analysis != null) {
      await _showConvoyAiAnalysis(analysis);
    }
  }

  Future<void> _showConvoyAiLoadingDialog(AppLocalizations l10n) async {
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

  void _closeConvoyAiLoadingDialog() {
    if (!mounted || !_isAiLoadingDialogVisible) return;
    _isAiLoadingDialogVisible = false;
    Navigator.of(context, rootNavigator: true).pop();
  }

  Future<void> _showConvoyAiAnalysis(AiRouteAnalysis analysis) async {
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
                  _ConvoyAiAnalysisSection(
                    title: l10n.aiHighlights,
                    icon: Icons.check_circle_outline,
                    color: const Color(0xFF22A95A),
                    items: analysis.highlights,
                  ),
                if (analysis.cautions.isNotEmpty)
                  _ConvoyAiAnalysisSection(
                    title: l10n.aiCautions,
                    icon: Icons.warning_amber_rounded,
                    color: const Color(0xFFF39C12),
                    items: analysis.cautions,
                  ),
                _ConvoyAiAnalysisSection(
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
            onPressed: () => _reportConvoyAiAnswer(analysis.responseId),
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

  Future<void> _reportConvoyAiAnswer(String responseId) async {
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
    _addressSearchController.text = fav.label;
    _destinationLabel = fav.label;
    _searchFocus.unfocus();
    _routeToDestination(LatLng(fav.lat, fav.lon));
  }

  Future<void> _promptSetFavorite(String iconKey, String defaultLabel) async {
    if (_routeDestination == null) {
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
    final dest = _routeDestination!;
    final label = _destinationLabel.isNotEmpty
        ? _destinationLabel
        : defaultLabel;
    await ConvoyFavoritePlacesService.instance.initialize();
    await ConvoyFavoritePlacesService.instance.add(
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
    if (_routeDestination == null) {
      _searchFocus.requestFocus();
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final dest = _routeDestination!;
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
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              await ConvoyFavoritePlacesService.instance.initialize();
              await ConvoyFavoritePlacesService.instance.add(
                FavoritePlace(
                  id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                  label: name,
                  lat: dest.latitude,
                  lon: dest.longitude,
                  address: _destinationLabel,
                ),
              );
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              // ignore: use_build_context_synchronously
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
              onTap: () async {
                await ConvoyFavoritePlacesService.instance.initialize();
                await ConvoyFavoritePlacesService.instance.remove(fav.id);
                if (!ctx.mounted) return;
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

  void _fitAllMembers(List<ConvoyMemberLocation> locations) {
    final points = [...locations.map((m) => m.position), ?_myLocation];
    if (points.isEmpty) return;
    // Disable 3D before zooming out to prevent white bleed.
    setState(() {
      _isFollowingMyPosition = false;
      _use3DMap = false;
    });
    if (_usingAppleMapKit) {
      _queueViewportFit(points);
      return;
    }
    if (points.length == 1) {
      _mapController.moveAndRotate(points.first, _followZoom, 0);
      return;
    }
    final bounds = LatLngBounds.fromPoints(points);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(72),
        maxZoom: 17,
      ),
    );
    _mapController.rotate(0);
  }

  Future<void> _loadAlerts() async {
    final center = _myLocation;
    if (center == null) return;
    try {
      final results = await Future.wait<List<AlertModel>>([
        _alertsController.fetchNearby(center),
        TrafikverketService.instance.fetchNearby(center),
        if (UserPreferencesService.instance.vehicleType.value == 'Low vehicle')
          OsmSpeedBumpService.instance.fetchNearby(center)
        else
          Future.value(const <AlertModel>[]),
      ]);
      if (!mounted) return;
      setState(() => _alerts = results.expand((alerts) => alerts).toList());
    } catch (_) {}
  }

  Future<void> _showReportAlertSheet() async {
    final pos = _myLocation;
    if (pos == null) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ConvoyInlineReportSheet(
        position: pos,
        controller: _alertsController,
        onSubmitted: _loadAlerts,
      ),
    );
  }

  void _routeToPin(ConvoyPin pin) {
    _destinationLabel = pin.label;
    Navigator.of(context).pop(); // close bottom sheet
    _routeToDestination(pin.position);
  }

  Future<void> _routeToDestination(LatLng destination) async {
    final previousRouteDestination = _routeDestination;
    final previousRoutePoints = List<LatLng>.from(_routePoints);
    final previousActiveRoute = _activeRoute;
    final previousRoutingStatus = _routingStatus;
    final previousIsFollowingMyPosition = _isFollowingMyPosition;
    final previousRouteInstructions = List<RouteInstruction>.from(
      _routeInstructions,
    );
    final previousCumulativeDist = List<double>.from(_cumulativeDist);
    final previousTotalRouteDistM = _totalRouteDistM;
    final previousRemainingDistM = _remainingDistM;
    final previousLastNearestIdx = _lastNearestIdx;
    final previousDisplayNearestIdx = _displayNearestIdx;
    final previousDistToNextManeuver = _distToNextManeuver;
    final previousNextManeuverSign = _nextManeuverSign;
    final previousNextManeuverText = _nextManeuverText;
    final previousNextManeuverStreetName = _nextManeuverStreetName;
    final previousCurrentStreetName = _currentStreetName;
    final previousDestinationLabel = _destinationLabel;

    void restorePreviousRouteState() {
      if (!mounted) {
        return;
      }
      setState(() {
        _mapViewEpoch++;
        _routeDestination = previousRouteDestination;
        _routePoints = previousRoutePoints;
        _activeRoute = previousActiveRoute;
        _routingStatus = previousRoutingStatus;
        _isFollowingMyPosition = previousIsFollowingMyPosition;
        _routeInstructions = previousRouteInstructions;
        _cumulativeDist = previousCumulativeDist;
        _totalRouteDistM = previousTotalRouteDistM;
        _remainingDistM = previousRemainingDistM;
        _lastNearestIdx = previousLastNearestIdx;
        _displayNearestIdx = previousDisplayNearestIdx;
        _distToNextManeuver = previousDistToNextManeuver;
        _nextManeuverSign = previousNextManeuverSign;
        _nextManeuverText = previousNextManeuverText;
        _nextManeuverStreetName = previousNextManeuverStreetName;
        _currentStreetName = previousCurrentStreetName;
        _destinationLabel = previousDestinationLabel;
        _isRouting = false;
      });
      if (previousActiveRoute == null) {
        _cancelPendingConvoyAiRouteAnalysis();
      }
    }

    if (_analyzeNextSelectedRouteWithAi) {
      _aiDestinationSelectionStarted = true;
    }
    if (_myLocation == null) {
      // GPS not ready yet — save destination, auto-retry on first fix.
      setState(() {
        _pendingDestination = destination;
        _routeDestination = destination;
        _routingStatus = AppLocalizations.of(context)!.mapStartingGps;
      });
      return;
    }

    setState(() {
      _isRouting = true;
      _routeDestination = destination;
      _routePoints = const [];
      _activeRoute = null;
      _routingStatus = AppLocalizations.of(context)!.mapCalculatingRoute;
      _isFollowingMyPosition = false;
    });
    // Zoom in on my vehicle while the route is being calculated.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_usingAppleMapKit) {
        _mapController.move(_myLocation!, 16.5);
      }
    });

    try {
      final route = await _routingService.getRoute(
        origin: _myLocation!,
        destination: destination,
        vehicleType: UserPreferencesService.instance.vehicleType.value,
        avoidLocations: await _lowVehicleBumpAvoidLocations(
          origin: _myLocation!,
          destination: destination,
        ),
      );
      if (!mounted) return;

      // Build route options — recommended + Valhalla alternatives + optional relaxed fallback.
      final options = await _buildConvoyRouteOptions(
        destination: destination,
        vehicleType: UserPreferencesService.instance.vehicleType.value,
        strictRoute: route,
      );
      if (!mounted) return;

      final selected = options.length > 1
          ? await _showConvoyRouteOptionsSheet(options: options)
          : options.first;
      if (!mounted) return;
      if (selected == null) {
        restorePreviousRouteState();
        return;
      }

      final chosenRoute = selected.route;
      final km = chosenRoute.distanceMeters / 1000;
      final minutes = (chosenRoute.durationSeconds / 60).round();
      final cumDist = _buildCumulativeDist(chosenRoute.points);
      setState(() {
        _routePoints = chosenRoute.points;
        _activeRoute = chosenRoute;
        _routeInstructions = chosenRoute.instructions;
        _cumulativeDist = cumDist;
        _totalRouteDistM = cumDist.isNotEmpty ? cumDist.last : 0;
        _remainingDistM = _totalRouteDistM;
        _lastNearestIdx = 0;
        _displayNearestIdx = 0;
        _distToNextManeuver = double.infinity;
        _nextManeuverSign = 0;
        _nextManeuverText = '';
        _nextManeuverStreetName = '';
        _routingStatus = AppLocalizations.of(
          context,
        )!.mapRouteReady(km.toStringAsFixed(1), minutes.toString());
        _isFollowingMyPosition = false;
      });
      _analyzeSelectedConvoyRouteIfRequested();
      // Zoom to fit the full route so the driver sees start→destination.
      if (_usingAppleMapKit) {
        _queueViewportFit(chosenRoute.points);
      } else if (chosenRoute.points.length >= 2) {
        final bounds = LatLngBounds.fromPoints(chosenRoute.points);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _mapController.fitCamera(
            CameraFit.bounds(
              bounds: bounds,
              padding: const EdgeInsets.fromLTRB(40, 80, 40, 120),
            ),
          );
        });
      }
    } on RoutingException catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;

      final isRouteBlocked =
          e.code == RoutingErrorCode.noRouteFound ||
          e.code == RoutingErrorCode.routeTooFastForVehicle ||
          e.code == RoutingErrorCode.routeNotAllowedForVehicle;

      setState(() {
        _routePoints = const [];
        _lastNearestIdx = 0;
        _displayNearestIdx = 0;
        _routingStatus = switch (e.code) {
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
        final vehicleType = UserPreferencesService.instance.vehicleType.value;
        final vehicleName = switch (vehicleType) {
          'A-tractor' => l10n.settingsVehicleAtractor,
          'Low vehicle' => l10n.settingsVehicleLowVehicle,
          'Moped car' => l10n.settingsVehicleMopedCar,
          'Moped class I' => l10n.settingsVehicleMopedClassI,
          'Moped class II' => l10n.settingsVehicleMopedClassII,
          'Electric scooter' => l10n.settingsVehicleElectricScooter,
          'Tractor' => l10n.settingsVehicleTractor,
          'Car' => l10n.settingsVehicleCar,
          _ => vehicleType,
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
    } catch (e) {
      if (!mounted) return;
      debugPrint('Convoy routing error: $e');
      setState(() {
        _routePoints = const [];
        _lastNearestIdx = 0;
        _displayNearestIdx = 0;
        _routingStatus = AppLocalizations.of(context)!.mapRouteFailed;
      });
    } finally {
      if (mounted) {
        setState(() => _isRouting = false);
        if (_activeRoute == null) {
          _cancelPendingConvoyAiRouteAnalysis();
        }
      }
    }
  }

  // ── Alternative route helpers ───────────────────────────────────────────

  Future<RouteResult?> _tryConvoyRelaxedRoute(LatLng destination) async {
    final origin = _myLocation;
    if (origin == null) return null;
    try {
      return await _routingService.getRoute(
        origin: origin,
        destination: destination,
        vehicleType: UserPreferencesService.instance.vehicleType.value,
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
  bool _convoyRoutesOverlapHeavily(RouteResult a, RouteResult b) {
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

  bool _convoyRoutesLookSimilar(RouteResult a, RouteResult b) {
    final distanceDelta =
        (a.distanceMeters - b.distanceMeters).abs() /
        math.max(a.distanceMeters, 1);
    final durationDelta =
        (a.durationSeconds - b.durationSeconds).abs() /
        math.max(a.durationSeconds, 1);
    return distanceDelta < 0.04 && durationDelta < 0.08;
  }

  Future<List<_ConvoyRouteOption>> _buildConvoyRouteOptions({
    required LatLng destination,
    required String vehicleType,
    RouteResult? strictRoute,
  }) async {
    final options = <_ConvoyRouteOption>[
      if (strictRoute != null)
        _ConvoyRouteOption(
          route: strictRoute,
          type: _ConvoyRouteOptionType.recommended,
        ),
    ];

    // Waze-style: always surface genuinely different legal routes when they
    // exist. We force alternatives by re-routing around the primary route and
    // dedupe by geometry so only distinct paths are shown. Cap at 2.
    final origin = _myLocation;
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
                .where((o) => o.type == _ConvoyRouteOptionType.alternative)
                .length >=
            2) {
          break;
        }
        final isDuplicate = options.any(
          (option) => _convoyRoutesOverlapHeavily(option.route, alt),
        );
        if (!isDuplicate) {
          options.add(
            _ConvoyRouteOption(
              route: alt,
              type: _ConvoyRouteOptionType.alternative,
            ),
          );
        }
      }
    }

    final relaxedRoute = await _tryConvoyRelaxedRoute(destination);
    if (relaxedRoute != null &&
        options.every(
          (option) => !_convoyRoutesOverlapHeavily(option.route, relaxedRoute),
        )) {
      options.add(
        _ConvoyRouteOption(
          route: relaxedRoute,
          type: _ConvoyRouteOptionType.unverified,
        ),
      );
    }

    return options;
  }

  String _convoyRouteOptionDistanceText(
    AppLocalizations l10n,
    RouteResult route,
  ) {
    final km = route.distanceMeters / 1000;
    final minutes = route.durationSeconds / 60;
    return l10n.routeOptionMetrics(
      km.toStringAsFixed(1),
      minutes.toStringAsFixed(0),
    );
  }

  Future<_ConvoyRouteOption?> _showConvoyRouteOptionsSheet({
    required List<_ConvoyRouteOption> options,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final vehicleType = UserPreferencesService.instance.vehicleType.value;
    final vehicleName = switch (vehicleType) {
      'A-tractor' => l10n.settingsVehicleAtractor,
      'Low vehicle' => l10n.settingsVehicleLowVehicle,
      'Moped car' => l10n.settingsVehicleMopedCar,
      'Moped class I' => l10n.settingsVehicleMopedClassI,
      'Moped class II' => l10n.settingsVehicleMopedClassII,
      'Electric scooter' => l10n.settingsVehicleElectricScooter,
      'Tractor' => l10n.settingsVehicleTractor,
      'Car' => l10n.settingsVehicleCar,
      _ => vehicleType,
    };
    return showModalBottomSheet<_ConvoyRouteOption>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
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
                      option.type == _ConvoyRouteOptionType.unverified;
                  final accent = isUnverified
                      ? const Color(0xFFFFCC02)
                      : const Color(0xFF3AA8FF);
                  final String title;
                  final String subtitle;
                  final IconData icon;
                  switch (option.type) {
                    case _ConvoyRouteOptionType.recommended:
                      title = l10n.routeOptionRecommended;
                      subtitle = l10n.routeOptionRecommendedSubtitle;
                      icon = Icons.verified_rounded;
                      break;
                    case _ConvoyRouteOptionType.alternative:
                      title = l10n.routeOptionAlternative;
                      subtitle = l10n.routeOptionAlternativeSubtitle;
                      icon = Icons.alt_route_rounded;
                      break;
                    case _ConvoyRouteOptionType.unverified:
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
                        color: accent.withAlpha((accent.alpha * 0.4).toInt()),
                      ),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: accent.withAlpha(
                          (accent.alpha * 0.2).toInt(),
                        ),
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
                        '${_convoyRouteOptionDistanceText(l10n, option.route)}\n$subtitle',
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
                      onTap: () => Navigator.of(ctx).pop(option),
                    ),
                  );
                }),
                if (options.any(
                  (o) => o.type == _ConvoyRouteOptionType.unverified,
                ))
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

  void _clearConvoyRoute() {
    setState(() {
      _routePoints = const [];
      _activeRoute = null;
      _routeDestination = null;
      _pendingDestination = null;
      _isNavigating = false;
      _isNavigationPanelExpanded = false;
      _destinationLabel = '';
      _routingStatus = '';
      _routeInstructions = const [];
      _distToNextManeuver = double.infinity;
      _nextManeuverSign = 0;
      _nextManeuverText = '';
      _nextManeuverStreetName = '';
      _currentStreetName = '';
      _lastSpokenManeuver = '';
      _spokenEarlyWarning = false;
      _cumulativeDist = const [];
      _totalRouteDistM = 0;
      _remainingDistM = 0;
      _etaSmoothedSpeedKmh = 0;
      _etaLastMovementAt = null;
      _lastNearestIdx = 0;
      _displayNearestIdx = 0;
      _nearbyAlert = null;
      _dismissedNearbyAlert = null;
    });
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

  void _announceManeuver(String text, double distMeters) {
    if (text.isEmpty) return;
    final l10n = AppLocalizations.of(context)!;
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
    if (distMeters > 250) {
      _spokenEarlyWarning = false;
    }
  }

  void _showPinOptions(ConvoyPin pin) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1B2E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF1E6BFF).withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _pinIcon(pin.type),
                      color: _pinColor(pin.type),
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        pin.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                if (pin.userLabel.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    l10n.convoyPinMarkedBy(pin.userLabel),
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1E6BFF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.alt_route),
                    label: Text(
                      l10n.convoyNavigateToPin,
                      style: TextStyle(fontSize: 16),
                    ),
                    onPressed: () => _routeToPin(pin),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showPinDialog(LatLng point, AppLocalizations l10n) async {
    final labelController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.convoyPinDialogTitle),
          content: TextField(
            controller: labelController,
            decoration: InputDecoration(
              labelText: l10n.convoyPinLabel,
              hintText: l10n.convoyPinHint,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.convoyCreateCancel),
            ),
            FilledButton(
              onPressed: () async {
                await _controller.addPin(
                  convoyId: widget.convoy.id,
                  position: point,
                  label: labelController.text,
                  pinType: 'custom',
                );
                if (!context.mounted) {
                  return;
                }
                Navigator.of(context).pop();
              },
              child: Text(l10n.convoyPinAdd),
            ),
          ],
        );
      },
    );

    labelController.dispose();
  }

  Future<void> _showQuickHazardPicker(
    LatLng point,
    AppLocalizations l10n,
  ) async {
    Future<void> addQuickPin({
      required String label,
      required String pinType,
    }) async {
      await _controller.addPin(
        convoyId: widget.convoy.id,
        position: point,
        label: label,
        pinType: pinType,
      );
    }

    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: const Icon(Icons.place, color: Color(0xFF1E88E5)),
                title: Text(l10n.convoyPoiMeetup),
                subtitle: Text(l10n.convoyPoiMeetupSubtitle),
                onTap: () async {
                  await addQuickPin(
                    label: l10n.convoyPoiMeetup,
                    pinType: 'meetup',
                  );
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.local_parking, color: Colors.blue),
                title: Text(l10n.convoyPoiParking),
                onTap: () async {
                  await addQuickPin(
                    label: l10n.convoyPoiParking,
                    pinType: 'parking',
                  );
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.restaurant, color: Colors.deepOrange),
                title: Text(l10n.convoyPoiFoodStop),
                onTap: () async {
                  await addQuickPin(
                    label: l10n.convoyPoiFoodStop,
                    pinType: 'food_stop',
                  );
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.ev_station, color: Colors.green),
                title: Text(l10n.convoyPoiCharging),
                onTap: () async {
                  await addQuickPin(
                    label: l10n.convoyPoiCharging,
                    pinType: 'charging',
                  );
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.star, color: Colors.amber),
                title: Text(l10n.convoyPoiHangout),
                onTap: () async {
                  await addQuickPin(
                    label: l10n.convoyPoiHangout,
                    pinType: 'hangout',
                  );
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.local_police, color: Colors.blue),
                title: Text(l10n.convoyHazardPolice),
                onTap: () async {
                  await addQuickPin(
                    label: l10n.convoyHazardPolice,
                    pinType: 'police',
                  );
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.construction, color: Colors.orange),
                title: Text(l10n.convoyHazardRoadwork),
                onTap: () async {
                  await addQuickPin(
                    label: l10n.convoyHazardRoadwork,
                    pinType: 'roadwork',
                  );
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.car_crash, color: Colors.redAccent),
                title: Text(l10n.convoyHazardAccident),
                onTap: () async {
                  await addQuickPin(
                    label: l10n.convoyHazardAccident,
                    pinType: 'accident',
                  );
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.traffic, color: Colors.amber),
                title: Text(l10n.convoyHazardTrafficJam),
                onTap: () async {
                  await addQuickPin(
                    label: l10n.convoyHazardTrafficJam,
                    pinType: 'traffic_jam',
                  );
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.speed, color: Colors.deepPurple),
                title: Text(l10n.convoyHazardSpeedCamera),
                onTap: () async {
                  await addQuickPin(
                    label: l10n.convoyHazardSpeedCamera,
                    pinType: 'speed_camera',
                  );
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.push_pin, color: Colors.red),
                title: Text(l10n.convoyHazardCustom),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _showPinDialog(point, l10n);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _pinIcon(String type) {
    return switch (type) {
      'police' => Icons.local_police,
      'roadwork' => Icons.construction,
      'accident' => Icons.car_crash,
      'traffic_jam' => Icons.traffic,
      'speed_camera' => Icons.speed,
      'meetup' => Icons.place,
      'parking' => Icons.local_parking,
      'food_stop' => Icons.restaurant,
      'charging' => Icons.ev_station,
      'hangout' => Icons.star,
      _ => Icons.push_pin,
    };
  }

  Color _pinColor(String type) {
    return switch (type) {
      'police' => Colors.blue,
      'roadwork' => Colors.orange,
      'accident' => Colors.redAccent,
      'traffic_jam' => Colors.amber,
      'speed_camera' => Colors.deepPurple,
      'meetup' => const Color(0xFF1E88E5),
      'parking' => Colors.blue,
      'food_stop' => Colors.deepOrange,
      'charging' => Colors.green,
      'hangout' => Colors.amber,
      _ => Colors.red,
    };
  }

  Widget _buildCompactConvoyNavigationSpeed() {
    final preferences = UserPreferencesService.instance;
    return ValueListenableBuilder<double>(
      valueListenable: _speedNotifier,
      builder: (context, liveSpeed, _) {
        return ValueListenableBuilder<SpeedUnit>(
          valueListenable: preferences.speedUnit,
          builder: (context, speedUnit, _) {
            return ValueListenableBuilder<double>(
              valueListenable: preferences.maxSpeedKmh,
              builder: (context, maxSpeedKmh, _) {
                final roadLimitKmh = _roadSpeedLimitKmh;
                final effectiveLimitKmh = roadLimitKmh ?? maxSpeedKmh;
                final over = liveSpeed > effectiveLimitKmh;
                final speedDisplay = preferences.toDisplaySpeed(
                  speedKmh: liveSpeed,
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
                    ? (speedDisplay / effectiveLimitDisplay).clamp(0.0, 1.25)
                    : 0.0;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 50,
                      height: 50,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: const Size(50, 50),
                            painter: _ConvoySpeedBarsPainter(
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
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: over ? Colors.red : Colors.white24,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                speedDisplay.toStringAsFixed(0),
                                style: TextStyle(
                                  color: over ? Colors.redAccent : Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A1628),
        bottomNavigationBar: AdBannerWidget(
          adUnitId: AdService.instance.bannerConvoyUnitId,
        ),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0D1B2E),
          foregroundColor: Colors.white,
          elevation: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.convoy.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (widget.convoy.isPublic)
                Text(
                  widget.convoy.meetupLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF66D9FF),
                    fontSize: 11,
                    fontWeight: FontWeight.normal,
                  ),
                ),
            ],
          ),
          actions: [
            if (widget.convoy.isPublic)
              IconButton(
                tooltip: _shareLiveLocation
                    ? l10n.publicGatheringStopSharing
                    : l10n.publicGatheringStartSharing,
                onPressed: () => _setLiveLocationSharing(!_shareLiveLocation),
                icon: Icon(
                  _shareLiveLocation
                      ? Icons.location_on
                      : Icons.location_off_outlined,
                  color: _shareLiveLocation
                      ? const Color(0xFF00C896)
                      : Colors.white54,
                ),
              ),
          ],
          bottom: TabBar(
            labelColor: const Color(0xFF3AA8FF),
            unselectedLabelColor: Colors.white54,
            indicatorColor: const Color(0xFF1E6BFF),
            indicatorSize: TabBarIndicatorSize.tab,
            tabs: [
              Tab(text: l10n.convoyTabMap),
              Tab(text: l10n.convoyTabChat),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            StreamBuilder<List<ConvoyPin>>(
              stream: _pinsStream,
              builder: (context, pinSnapshot) {
                final allPins = pinSnapshot.data ?? const [];
                final locations = _memberLocations;
                final pins = allPins
                    .where(_isPinActive)
                    .toList(growable: false);
                final currentUserId =
                    (AuthService.instance.userId.value ?? _myUserId)?.trim();
                final meetupPosition = widget.convoy.meetupPosition;
                final hasInitialMapCenter =
                    _myLocation != null ||
                    locations.isNotEmpty ||
                    meetupPosition != null;
                final center =
                    _myLocation ??
                    (locations.isNotEmpty
                        ? locations.first.position
                        : meetupPosition ?? const LatLng(20, 0));

                return Column(
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          RepaintBoundary(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(0),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final h = constraints.maxHeight;
                                  final w = constraints.maxWidth;
                                  final useAppleMapKit = _usingAppleMapKit;
                                  final is3D =
                                      !useAppleMapKit &&
                                      _isFollowingMyPosition &&
                                      _use3DMap;
                                  final matrix = is3D
                                      ? (Matrix4.identity()
                                          ..setEntry(3, 2, 0.0008)
                                          ..rotateX(_k3DTiltRad))
                                      : Matrix4.identity();
                                  final routeForMap =
                                      _isNavigating && _displayNearestIdx > 0
                                      ? _routePoints.sublist(
                                          _displayNearestIdx.clamp(
                                            0,
                                            _routePoints.length,
                                          ),
                                        )
                                      : _routePoints;
                                  final selfUserIds = <String>{
                                    if ((currentUserId ?? '').isNotEmpty)
                                      currentUserId!,
                                    if ((_myUserId ?? '').trim().isNotEmpty)
                                      (_myUserId ?? '').trim(),
                                  };
                                  final convoyMembersForApple = locations
                                      .where(
                                        (member) => !selfUserIds.contains(
                                          member.userId.trim(),
                                        ),
                                      )
                                      .toList(growable: false);
                                  final initialZoom = hasInitialMapCenter
                                      ? _followZoom
                                      : 2.0;
                                  return Stack(
                                    clipBehavior: Clip.hardEdge,
                                    children: [
                                      // Dark fill — prevent white bleed
                                      // behind the 3D-tilted map.
                                      const Positioned.fill(
                                        child: ColoredBox(
                                          color: Color(0xFF0A1628),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 0,
                                        left: 0,
                                        right: 0,
                                        height: h,
                                        child: Transform(
                                          alignment: Alignment.bottomCenter,
                                          transform: matrix,
                                          child: SizedBox(
                                            width: w,
                                            height: h,
                                            child: useAppleMapKit
                                                ? ValueListenableBuilder<
                                                    MapMarkerStyle
                                                  >(
                                                    valueListenable:
                                                        UserPreferencesService
                                                            .instance
                                                            .mapMarkerStyle,
                                                    builder:
                                                        (
                                                          context,
                                                          markerStyle,
                                                          _,
                                                        ) {
                                                          return AppleConvoyMapWidget(
                                                            key: ValueKey(
                                                              'apple-convoy-mapkit-$_mapViewEpoch',
                                                            ),
                                                            currentUserId:
                                                                currentUserId,
                                                            locationNotifier:
                                                                _locationNotifier,
                                                            headingNotifier:
                                                                _arrowHdg,
                                                            markerStyle:
                                                                markerStyle,
                                                            members:
                                                                convoyMembersForApple,
                                                            pins: pins,
                                                            destination:
                                                                _routeDestination,
                                                            routePoints:
                                                                routeForMap,
                                                            alerts: _alerts,
                                                            meetupPosition:
                                                                meetupPosition,
                                                            meetupLabel: widget
                                                                .convoy
                                                                .meetupLabel,
                                                            followUser:
                                                                _isFollowingMyPosition &&
                                                                _myLocation !=
                                                                    null,
                                                            use3D:
                                                                _isNavigating &&
                                                                _use3DMap,
                                                            darkMode:
                                                                _useDarkMap,
                                                            satellite:
                                                                _useSatelliteMap,
                                                            nextManeuverDistanceMeters:
                                                                _isNavigating
                                                                ? _distToNextManeuver
                                                                : null,
                                                            nextManeuverSign:
                                                                _isNavigating
                                                                ? _nextManeuverSign
                                                                : null,
                                                            viewportCommandId:
                                                                _mapViewportCommandId,
                                                            viewportCommandPoints:
                                                                _mapViewportCommandPoints,
                                                            onTap: (point) =>
                                                                _showQuickHazardPicker(
                                                                  point,
                                                                  l10n,
                                                                ),
                                                            onUserPanned: () {
                                                              _pauseConvoyMapFollowingForInteraction();
                                                            },
                                                            onUserInteractionEnded:
                                                                _resumeConvoyMapFollowingAfterInteraction,
                                                            onMeetupTap: () {
                                                              if (meetupPosition ==
                                                                  null) {
                                                                return;
                                                              }
                                                              _destinationLabel =
                                                                  widget
                                                                      .convoy
                                                                      .meetupLabel;
                                                              _routeToDestination(
                                                                meetupPosition,
                                                              );
                                                            },
                                                            onMemberTap: (userId) {
                                                              final member =
                                                                  _memberByUserId(
                                                                    locations,
                                                                    userId,
                                                                  );
                                                              if (member ==
                                                                  null) {
                                                                return;
                                                              }
                                                              _showParticipantSafetyActions(
                                                                member,
                                                                l10n,
                                                              );
                                                            },
                                                            onPinTap: (pinId) {
                                                              final tappedPin =
                                                                  _pinById(
                                                                    pins,
                                                                    pinId,
                                                                  );
                                                              if (tappedPin ==
                                                                  null) {
                                                                return;
                                                              }
                                                              _showPinOptions(
                                                                tappedPin,
                                                              );
                                                            },
                                                          );
                                                        },
                                                  )
                                                : FlutterMap(
                                                    options: MapOptions(
                                                      initialCenter: center,
                                                      initialZoom: initialZoom,
                                                      initialRotation: 0,
                                                      onTap: (_, point) =>
                                                          _showQuickHazardPicker(
                                                            point,
                                                            l10n,
                                                          ),
                                                      onPositionChanged:
                                                          (
                                                            _,
                                                            hasGesture,
                                                          ) {
                                                            if (!hasGesture) {
                                                              return;
                                                            }
                                                            _pauseConvoyMapFollowingForInteraction();
                                                            _resumeConvoyMapFollowingAfterInteraction();
                                                          },
                                                    ),
                                                    mapController:
                                                        _mapController,
                                                    children: [
                                                      TileLayer(
                                                        urlTemplate:
                                                            _useSatelliteMap
                                                            ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                                                            : _useDarkMap
                                                            ? 'https://{s}.basemaps.cartocdn.com/dark_nolabels/{z}/{x}/{y}{r}.png'
                                                            : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                                                        fallbackUrl:
                                                            _useSatelliteMap
                                                            ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                                                            : _useDarkMap
                                                            ? 'https://{s}.basemaps.cartocdn.com/dark_nolabels/{z}/{x}/{y}{r}.png'
                                                            : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                                                        subdomains:
                                                            _useSatelliteMap
                                                            ? const []
                                                            : const [
                                                                'a',
                                                                'b',
                                                                'c',
                                                                'd',
                                                              ],
                                                        userAgentPackageName:
                                                            'com.cruizx.mobile',
                                                        tileProvider:
                                                            _tileProvider,
                                                        tileUpdateTransformer:
                                                            TileUpdateTransformers.throttle(
                                                              const Duration(
                                                                milliseconds:
                                                                    28,
                                                              ),
                                                            ),
                                                        retinaMode:
                                                            RetinaMode.isHighDensity(
                                                              context,
                                                            ),
                                                        maxNativeZoom: 20,
                                                        keepBuffer: 3,
                                                        panBuffer: 1,
                                                        tileDisplay:
                                                            const TileDisplay.instantaneous(),
                                                      ),
                                                      if (_useSatelliteMap)
                                                        TileLayer(
                                                          urlTemplate:
                                                              'https://services.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
                                                          userAgentPackageName:
                                                              'com.cruizx.mobile',
                                                          tileProvider:
                                                              _tileProvider,
                                                          maxNativeZoom: 20,
                                                          tileDisplay:
                                                              const TileDisplay.instantaneous(),
                                                        )
                                                      else if (_useDarkMap)
                                                        TileLayer(
                                                          urlTemplate:
                                                              'https://{s}.basemaps.cartocdn.com/dark_only_labels/{z}/{x}/{y}{r}.png',
                                                          fallbackUrl:
                                                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                                          subdomains: const [
                                                            'a',
                                                            'b',
                                                            'c',
                                                            'd',
                                                          ],
                                                          userAgentPackageName:
                                                              'com.cruizx.mobile',
                                                          tileProvider:
                                                              _tileProvider,
                                                          tileUpdateTransformer:
                                                              TileUpdateTransformers.throttle(
                                                                const Duration(
                                                                  milliseconds:
                                                                      28,
                                                                ),
                                                              ),
                                                          retinaMode:
                                                              RetinaMode.isHighDensity(
                                                                context,
                                                              ),
                                                          maxNativeZoom: 20,
                                                          keepBuffer: 2,
                                                          panBuffer: 1,
                                                          tileDisplay:
                                                              const TileDisplay.instantaneous(),
                                                        ),
                                                      MarkerLayer(
                                                        markers: [
                                                          if (meetupPosition !=
                                                              null)
                                                            Marker(
                                                              point:
                                                                  meetupPosition,
                                                              width: 120,
                                                              height: 64,
                                                              alignment:
                                                                  const Alignment(
                                                                    0,
                                                                    -0.8,
                                                                  ),
                                                              child: GestureDetector(
                                                                onTap: () {
                                                                  _destinationLabel =
                                                                      widget
                                                                          .convoy
                                                                          .meetupLabel;
                                                                  _routeToDestination(
                                                                    meetupPosition,
                                                                  );
                                                                },
                                                                child: Column(
                                                                  children: [
                                                                    Container(
                                                                      padding: const EdgeInsets.symmetric(
                                                                        horizontal:
                                                                            8,
                                                                        vertical:
                                                                            3,
                                                                      ),
                                                                      decoration: BoxDecoration(
                                                                        color: const Color(
                                                                          0xEE071739,
                                                                        ),
                                                                        borderRadius:
                                                                            BorderRadius.circular(
                                                                              9,
                                                                            ),
                                                                        border: Border.all(
                                                                          color: const Color(
                                                                            0xFF66D9FF,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                      child: Text(
                                                                        widget
                                                                            .convoy
                                                                            .meetupLabel,
                                                                        maxLines:
                                                                            1,
                                                                        overflow:
                                                                            TextOverflow.ellipsis,
                                                                        style: const TextStyle(
                                                                          color:
                                                                              Colors.white,
                                                                          fontSize:
                                                                              11,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    const Icon(
                                                                      Icons
                                                                          .location_on,
                                                                      color: Color(
                                                                        0xFF66D9FF,
                                                                      ),
                                                                      size: 28,
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                          for (final alert
                                                              in _alerts)
                                                            Marker(
                                                              point: alert
                                                                  .position,
                                                              width: 44,
                                                              height: 52,
                                                              alignment:
                                                                  const Alignment(
                                                                    0,
                                                                    -1,
                                                                  ),
                                                              child:
                                                                  _ConvoyAlertMarker(
                                                                    alert:
                                                                        alert,
                                                                  ),
                                                            ),
                                                          for (final member
                                                              in locations)
                                                            if (!(member.userId ==
                                                                    _myUserId &&
                                                                _isFollowingMyPosition))
                                                              Marker(
                                                                point: member
                                                                    .position,
                                                                width: 86,
                                                                height: 56,
                                                                child: AccessibleTapTarget(
                                                                  label: member
                                                                      .userLabel,
                                                                  onTap: () =>
                                                                      _showParticipantSafetyActions(
                                                                        member,
                                                                        l10n,
                                                                      ),
                                                                  child:
                                                                      _buildMemberMarker(
                                                                        member,
                                                                        l10n,
                                                                      ),
                                                                ),
                                                              ),
                                                          for (final pin
                                                              in pins)
                                                            Marker(
                                                              point:
                                                                  pin.position,
                                                              width: 90,
                                                              height: 42,
                                                              child: AccessibleTapTarget(
                                                                label:
                                                                    pin.label,
                                                                onTap: () =>
                                                                    _showPinOptions(
                                                                      pin,
                                                                    ),
                                                                child: Column(
                                                                  children: [
                                                                    Container(
                                                                      padding: const EdgeInsets.symmetric(
                                                                        horizontal:
                                                                            6,
                                                                        vertical:
                                                                            2,
                                                                      ),
                                                                      decoration: BoxDecoration(
                                                                        color: Theme.of(
                                                                          context,
                                                                        ).colorScheme.surface,
                                                                        borderRadius:
                                                                            BorderRadius.circular(
                                                                              8,
                                                                            ),
                                                                        border: Border.all(
                                                                          color:
                                                                              _pinColor(
                                                                                pin.type,
                                                                              ).withValues(
                                                                                alpha: 0.6,
                                                                              ),
                                                                        ),
                                                                      ),
                                                                      child: Text(
                                                                        pin.label,
                                                                        overflow:
                                                                            TextOverflow.ellipsis,
                                                                        style: Theme.of(
                                                                          context,
                                                                        ).textTheme.labelSmall,
                                                                      ),
                                                                    ),
                                                                    Icon(
                                                                      _pinIcon(
                                                                        pin.type,
                                                                      ),
                                                                      color: _pinColor(
                                                                        pin.type,
                                                                      ),
                                                                      size: 18,
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                      RichAttributionWidget(
                                                        attributions: [
                                                          TextSourceAttribution(
                                                            '© Mapbox',
                                                          ),
                                                          TextSourceAttribution(
                                                            '© OpenStreetMap contributors',
                                                          ),
                                                        ],
                                                      ),
                                                      if (_routePoints
                                                          .isNotEmpty)
                                                        PolylineLayer(
                                                          polylines: [
                                                            Polyline(
                                                              points:
                                                                  routeForMap,
                                                              color:
                                                                  const Color(
                                                                    0xFF3AA8FF,
                                                                  ),
                                                              strokeWidth: 5,
                                                              borderColor:
                                                                  const Color(
                                                                    0xFF0A3D6E,
                                                                  ),
                                                              borderStrokeWidth:
                                                                  2,
                                                            ),
                                                          ],
                                                        ),
                                                    ],
                                                  ),
                                          ),
                                        ),
                                      ),
                                      // Horizon fade — covers top ~45%
                                      Positioned(
                                        top: 0,
                                        left: 0,
                                        right: 0,
                                        height: h * 0.45,
                                        child: IgnorePointer(
                                          child: AnimatedOpacity(
                                            opacity: is3D ? 1.0 : 0.0,
                                            duration: const Duration(
                                              milliseconds: 300,
                                            ),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                  colors: [
                                                    const Color(
                                                      0xFF0A1628,
                                                    ).withValues(alpha: 0.98),
                                                    Colors.transparent,
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                          if (widget.convoy.isPublic)
                            Positioned(
                              top: 12,
                              left: 16,
                              right: 16,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => _setLiveLocationSharing(
                                    !_shareLiveLocation,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xEE071739),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _shareLiveLocation
                                            ? const Color(0xFF00C896)
                                            : Colors.white24,
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          _shareLiveLocation
                                              ? Icons.location_on
                                              : Icons.location_off_outlined,
                                          color: _shareLiveLocation
                                              ? const Color(0xFF00C896)
                                              : Colors.white54,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _shareLiveLocation
                                                ? l10n.publicGatheringStopSharing
                                                : l10n.publicGatheringStartSharing,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        Switch.adaptive(
                                          value: _shareLiveLocation,
                                          onChanged: _setLiveLocationSharing,
                                          activeThumbColor: const Color(
                                            0xFF00C896,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          // ── Fixed arrow overlay (follow mode) ──
                          if (_isFollowingMyPosition && _myLocation != null)
                            IgnorePointer(
                              child: Align(
                                alignment: _use3DMap
                                    ? const Alignment(0, _k3DArrowAlignmentY)
                                    : Alignment.center,
                                child: UserLocationMarker(
                                  headingNotifier: _arrowHdg,
                                  lockNorthUp: false,
                                ),
                              ),
                            ),
                          // Address search bar (hidden during navigation)
                          if (!_isNavigating)
                            Positioned(
                              left: 16,
                              right: 16,
                              bottom: (_routeDestination != null || _isRouting)
                                  ? 110
                                  : 24,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (_showSuggestions &&
                                      _suggestions.isNotEmpty)
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xF0071739),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: const Color(0x553AA8FF),
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxHeight: 220,
                                          ),
                                          child: SingleChildScrollView(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: _suggestions.take(5).map((
                                                s,
                                              ) {
                                                final title =
                                                    _addressTitleFromResult(s);
                                                final subtitle =
                                                    _addressSubtitleFromResult(
                                                      s,
                                                    );
                                                return InkWell(
                                                  onTap: () =>
                                                      _selectSuggestion(s),
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 12,
                                                          vertical: 9,
                                                        ),
                                                    child: Row(
                                                      children: [
                                                        const Icon(
                                                          Icons.location_on,
                                                          size: 16,
                                                          color: Colors.white54,
                                                        ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                title,
                                                                style: const TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontSize: 13,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                ),
                                                                maxLines: 1,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                              ),
                                                              if (subtitle
                                                                  .isNotEmpty)
                                                                Text(
                                                                  subtitle,
                                                                  style: const TextStyle(
                                                                    color: Colors
                                                                        .white38,
                                                                    fontSize:
                                                                        11,
                                                                  ),
                                                                  maxLines: 1,
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
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
                                      ),
                                    ),
                                  ValueListenableBuilder<List<FavoritePlace>>(
                                    valueListenable: ConvoyFavoritePlacesService
                                        .instance
                                        .places,
                                    builder: (context, favs, _) {
                                      if (_showSuggestions &&
                                          _suggestions.isNotEmpty) {
                                        return const SizedBox.shrink();
                                      }
                                      final presets = <_ConvoyFavPreset>[
                                        _ConvoyFavPreset(
                                          'home',
                                          Icons.home,
                                          l10n.favHome,
                                        ),
                                        _ConvoyFavPreset(
                                          'school',
                                          Icons.school,
                                          l10n.favSchool,
                                        ),
                                        _ConvoyFavPreset(
                                          'work',
                                          Icons.work,
                                          l10n.favWork,
                                        ),
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
                                        margin: const EdgeInsets.only(
                                          bottom: 6,
                                        ),
                                        child: SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: Row(
                                            children: [
                                              ...presets.map((p) {
                                                final fav =
                                                    ConvoyFavoritePlacesService
                                                        .instance
                                                        .findByIcon(p.key);
                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        right: 6,
                                                      ),
                                                  child: _favChip(
                                                    icon: p.icon,
                                                    label:
                                                        fav?.label ?? p.label,
                                                    hasValue: fav != null,
                                                    onTap: () {
                                                      if (fav != null) {
                                                        _navigateToFavorite(
                                                          fav,
                                                        );
                                                      } else {
                                                        _promptSetFavorite(
                                                          p.key,
                                                          p.label,
                                                        );
                                                      }
                                                    },
                                                    onLongPress: fav != null
                                                        ? () =>
                                                              _showFavoriteOptions(
                                                                fav,
                                                              )
                                                        : null,
                                                  ),
                                                );
                                              }),
                                              ...custom.map(
                                                (f) => Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        right: 6,
                                                      ),
                                                  child: _favChip(
                                                    icon: Icons.star,
                                                    label: f.label,
                                                    hasValue: true,
                                                    onTap: () =>
                                                        _navigateToFavorite(f),
                                                    onLongPress: () =>
                                                        _showFavoriteOptions(f),
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
                                  SizedBox(
                                    height: 44,
                                    child: TextField(
                                      controller: _addressSearchController,
                                      focusNode: _searchFocus,
                                      readOnly: true,
                                      onTap: _showConvoySearchSheet,
                                      decoration: InputDecoration(
                                        hintText: l10n.mapAddressFieldHint,
                                        filled: true,
                                        fillColor: const Color(0xCC081B4F),
                                        prefixIcon: const Icon(Icons.search),
                                        suffixIcon:
                                            _addressSearchController
                                                .text
                                                .isNotEmpty
                                            ? IconButton(
                                                tooltip: l10n.a11yClearSearch,
                                                icon: const Icon(Icons.close),
                                                onPressed: () {
                                                  _addressSearchController
                                                      .clear();
                                                  setState(() {
                                                    _suggestions = [];
                                                    _showSuggestions = false;
                                                  });
                                                },
                                              )
                                            : IconButton(
                                                tooltip: l10n.a11yOpenSearch,
                                                icon: const Icon(
                                                  Icons.arrow_forward,
                                                ),
                                                onPressed:
                                                    _showConvoySearchSheet,
                                              ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          // Navigation turn banner (Apple Maps dark)
                          if (_isNavigating && _nextManeuverText.isNotEmpty)
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              child: SafeArea(
                                bottom: false,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    14,
                                    8,
                                    14,
                                    0,
                                  ),
                                  child: Container(
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
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      10,
                                      14,
                                      11,
                                    ),
                                    child: Row(
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
                                                color: accent.withValues(
                                                  alpha: 0.36,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(13),
                                                border: Border.all(
                                                  color: accent.withValues(
                                                    alpha: 0.9,
                                                  ),
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
                                              final accent =
                                                  _maneuverAccentColor(
                                                    _distToNextManeuver,
                                                    _nextManeuverSign,
                                                  );
                                              return Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 9,
                                                          vertical: 3,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: accent,
                                                      borderRadius:
                                                          BorderRadius.circular(
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
                                                        fontWeight:
                                                            FontWeight.w700,
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
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      height: 1.15,
                                                    ),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  if (_localizedManeuverTarget(
                                                        l10n,
                                                        _nextManeuverStreetName,
                                                        _nextManeuverText,
                                                      ) !=
                                                      null)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            top: 4,
                                                          ),
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
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
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
                          if (_nearbyAlert != null && _myLocation != null)
                            Positioned(
                              top: _isNavigating && _nextManeuverText.isNotEmpty
                                  ? 128
                                  : 80,
                              left: 0,
                              right: 0,
                              child: Material(
                                color: Colors.transparent,
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        _nearbyAlert!.type ==
                                            AlertType.roadClosure
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
                                            final l10n = AppLocalizations.of(
                                              ctx,
                                            )!;
                                            return Text(
                                              l10n.reportAlertNearby(
                                                _nearbyAlert!.type
                                                    .localizedLabel(l10n),
                                                _nearbyAlert!
                                                    .distanceTo(_myLocation!)
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
                          // ── Current street name pill ─────────────────────
                          if (_isNavigating && _currentStreetName.isNotEmpty)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: (_routeDestination != null || _isRouting)
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
                                        color: Colors.black.withValues(
                                          alpha: 0.2,
                                        ),
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
                          if (_isNavigating &&
                              !_isNavigationPanelExpanded &&
                              _routeDestination != null)
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
                                        child:
                                            _buildCompactConvoyNavigationSpeed(),
                                      ),
                                      Semantics(
                                        button: true,
                                        label: l10n.routeOptionsTitle,
                                        child: Tooltip(
                                          message: l10n.routeOptionsTitle,
                                          child: GestureDetector(
                                            onTap: () => setState(
                                              () => _isNavigationPanelExpanded =
                                                  true,
                                            ),
                                            child: Container(
                                              width: 42,
                                              height: 42,
                                              decoration: BoxDecoration(
                                                color: const Color(0x661E6BFF),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: const Color(
                                                    0x993AA8FF,
                                                  ),
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
                                              onTap: _clearConvoyRoute,
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
                          // Route / navigation bottom panel (Apple Maps dark)
                          if ((_routeDestination != null || _isRouting) &&
                              (!_isNavigating || _isNavigationPanelExpanded))
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Color(0xFF071739),
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(22),
                                  ),
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
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      8,
                                      12,
                                      6,
                                    ),
                                    child: ValueListenableBuilder<double>(
                                      valueListenable: _speedNotifier,
                                      builder: (context, liveSpeed, _) {
                                        return ValueListenableBuilder<
                                          SpeedUnit
                                        >(
                                          valueListenable:
                                              UserPreferencesService
                                                  .instance
                                                  .speedUnit,
                                          builder: (context, speedUnit, _) {
                                            return ValueListenableBuilder<
                                              double
                                            >(
                                              valueListenable:
                                                  UserPreferencesService
                                                      .instance
                                                      .maxSpeedKmh,
                                              builder: (context, maxSpeedKmh, _) {
                                                final roadLimitKmh =
                                                    _roadSpeedLimitKmh;
                                                final effectiveLimitKmh =
                                                    roadLimitKmh ?? maxSpeedKmh;
                                                final over =
                                                    liveSpeed >
                                                    effectiveLimitKmh;
                                                final speedDisplay =
                                                    UserPreferencesService
                                                        .instance
                                                        .toDisplaySpeed(
                                                          speedKmh: liveSpeed,
                                                          unit: speedUnit,
                                                        );
                                                final effectiveLimitDisplay =
                                                    UserPreferencesService
                                                        .instance
                                                        .toDisplaySpeed(
                                                          speedKmh:
                                                              effectiveLimitKmh,
                                                          unit: speedUnit,
                                                        );
                                                final roadLimitDisplay =
                                                    roadLimitKmh == null
                                                    ? null
                                                    : UserPreferencesService
                                                          .instance
                                                          .toDisplaySpeed(
                                                            speedKmh:
                                                                roadLimitKmh,
                                                            unit: speedUnit,
                                                          );
                                                final speedRatio =
                                                    effectiveLimitDisplay > 0
                                                    ? (speedDisplay /
                                                              effectiveLimitDisplay)
                                                          .clamp(0.0, 1.25)
                                                    : 0.0;
                                                final hasRoadLimit =
                                                    roadLimitDisplay != null;
                                                final eta = _isNavigating
                                                    ? _formatEta()
                                                    : '';
                                                return Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    // Drag handle
                                                    Center(
                                                      child: GestureDetector(
                                                        behavior:
                                                            HitTestBehavior
                                                                .opaque,
                                                        onTap: _isNavigating
                                                            ? () => setState(
                                                                () =>
                                                                    _isNavigationPanelExpanded =
                                                                        false,
                                                              )
                                                            : null,
                                                        onVerticalDragEnd:
                                                            _isNavigating
                                                            ? (details) {
                                                                if ((details.primaryVelocity ??
                                                                        0) >
                                                                    100) {
                                                                  setState(
                                                                    () => _isNavigationPanelExpanded =
                                                                        false,
                                                                  );
                                                                }
                                                              }
                                                            : null,
                                                        child: Padding(
                                                          padding:
                                                              const EdgeInsets.fromLTRB(
                                                                34,
                                                                0,
                                                                34,
                                                                8,
                                                              ),
                                                          child: Container(
                                                            width: 34,
                                                            height: 3,
                                                            decoration:
                                                                BoxDecoration(
                                                                  color: Colors
                                                                      .white24,
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        2,
                                                                      ),
                                                                ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    Row(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .center,
                                                      children: [
                                                        if (_isNavigating) ...[
                                                          Column(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              SizedBox(
                                                                width: 50,
                                                                height: 50,
                                                                child: Stack(
                                                                  alignment:
                                                                      Alignment
                                                                          .center,
                                                                  children: [
                                                                    CustomPaint(
                                                                      size:
                                                                          const Size(
                                                                            50,
                                                                            50,
                                                                          ),
                                                                      painter: _ConvoySpeedBarsPainter(
                                                                        ratio:
                                                                            speedRatio,
                                                                        activeColor:
                                                                            over
                                                                            ? const Color(
                                                                                0xFFFF5A5F,
                                                                              )
                                                                            : const Color(
                                                                                0xFFFF9A2F,
                                                                              ),
                                                                        inactiveColor:
                                                                            const Color(
                                                                              0x40FFFFFF,
                                                                            ),
                                                                        strokeWidth:
                                                                            3.6,
                                                                        segments:
                                                                            28,
                                                                      ),
                                                                    ),
                                                                    Container(
                                                                      width: 44,
                                                                      height:
                                                                          44,
                                                                      decoration: BoxDecoration(
                                                                        color: Colors
                                                                            .black,
                                                                        shape: BoxShape
                                                                            .circle,
                                                                        border: Border.all(
                                                                          color:
                                                                              over
                                                                              ? Colors.red
                                                                              : Colors.white24,
                                                                          width:
                                                                              2,
                                                                        ),
                                                                      ),
                                                                      child: Center(
                                                                        child: Text(
                                                                          speedDisplay.toStringAsFixed(
                                                                            0,
                                                                          ),
                                                                          style: TextStyle(
                                                                            color:
                                                                                over
                                                                                ? Colors.redAccent
                                                                                : Colors.white,
                                                                            fontSize:
                                                                                16,
                                                                            fontWeight:
                                                                                FontWeight.bold,
                                                                            height:
                                                                                1.0,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                height: 4,
                                                              ),
                                                              // EU speed limit sign
                                                              Container(
                                                                width: 34,
                                                                height: 34,
                                                                decoration: BoxDecoration(
                                                                  color: Colors
                                                                      .white,
                                                                  shape: BoxShape
                                                                      .circle,
                                                                  border: Border.all(
                                                                    color:
                                                                        hasRoadLimit
                                                                        ? Colors
                                                                              .red
                                                                              .shade700
                                                                        : Colors
                                                                              .grey
                                                                              .shade500,
                                                                    width: 3.5,
                                                                  ),
                                                                ),
                                                                child: Center(
                                                                  child: Text(
                                                                    hasRoadLimit
                                                                        ? roadLimitDisplay.toStringAsFixed(
                                                                            0,
                                                                          )
                                                                        : '--',
                                                                    style: TextStyle(
                                                                      color:
                                                                          hasRoadLimit
                                                                          ? Colors.black
                                                                          : Colors.black45,
                                                                      fontSize:
                                                                          13,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                      height:
                                                                          1.0,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          const SizedBox(
                                                            width: 14,
                                                          ),
                                                        ],
                                                        // Destination info
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              if (_destinationLabel
                                                                  .isNotEmpty) ...[
                                                                Text(
                                                                  _destinationLabel,
                                                                  style: const TextStyle(
                                                                    color: Colors
                                                                        .white,
                                                                    fontSize:
                                                                        16,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    height: 1.2,
                                                                  ),
                                                                  maxLines: 1,
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                ),
                                                                const SizedBox(
                                                                  height: 2,
                                                                ),
                                                              ],
                                                              Row(
                                                                children: [
                                                                  if (_isRouting)
                                                                    const Padding(
                                                                      padding:
                                                                          EdgeInsets.only(
                                                                            right:
                                                                                6,
                                                                          ),
                                                                      child: SizedBox(
                                                                        width:
                                                                            12,
                                                                        height:
                                                                            12,
                                                                        child: CircularProgressIndicator(
                                                                          strokeWidth:
                                                                              2,
                                                                          color:
                                                                              Colors.white54,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  Expanded(
                                                                    child: Text(
                                                                      _routingStatus,
                                                                      style: const TextStyle(
                                                                        color: Colors
                                                                            .white70,
                                                                        fontSize:
                                                                            13,
                                                                      ),
                                                                      maxLines:
                                                                          2,
                                                                      overflow:
                                                                          TextOverflow
                                                                              .ellipsis,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                              if (eta
                                                                  .isNotEmpty) ...[
                                                                const SizedBox(
                                                                  height: 2,
                                                                ),
                                                                Text(
                                                                  eta,
                                                                  style: const TextStyle(
                                                                    color: Colors
                                                                        .white54,
                                                                    fontSize:
                                                                        12,
                                                                  ),
                                                                ),
                                                              ],
                                                            ],
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 12,
                                                        ),
                                                        // Action button
                                                        if (_routePoints
                                                            .isNotEmpty)
                                                          Column(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .end,
                                                            children: [
                                                              _isNavigating
                                                                  ? GestureDetector(
                                                                      onTap:
                                                                          _clearConvoyRoute,
                                                                      child: Container(
                                                                        padding: const EdgeInsets.symmetric(
                                                                          horizontal:
                                                                              12,
                                                                          vertical:
                                                                              9,
                                                                        ),
                                                                        decoration: BoxDecoration(
                                                                          color: const Color(
                                                                            0xFFD32F2F,
                                                                          ),
                                                                          borderRadius: BorderRadius.circular(
                                                                            14,
                                                                          ),
                                                                        ),
                                                                        child: Text(
                                                                          l10n.mapEndNavigation,
                                                                          style: const TextStyle(
                                                                            color:
                                                                                Colors.white,
                                                                            fontWeight:
                                                                                FontWeight.bold,
                                                                            fontSize:
                                                                                13,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    )
                                                                  : GestureDetector(
                                                                      onTap: () => setState(() {
                                                                        _isNavigating =
                                                                            true;
                                                                        _isNavigationPanelExpanded =
                                                                            false;
                                                                        _isFollowingMyPosition =
                                                                            true;
                                                                        _lastNearestIdx =
                                                                            0;
                                                                      }),
                                                                      child: Container(
                                                                        padding: const EdgeInsets.symmetric(
                                                                          horizontal:
                                                                              18,
                                                                          vertical:
                                                                              13,
                                                                        ),
                                                                        decoration: BoxDecoration(
                                                                          color: const Color(
                                                                            0xFF00913F,
                                                                          ),
                                                                          borderRadius: BorderRadius.circular(
                                                                            14,
                                                                          ),
                                                                        ),
                                                                        child: Text(
                                                                          l10n.mapStartNavigation,
                                                                          style: const TextStyle(
                                                                            color:
                                                                                Colors.white,
                                                                            fontWeight:
                                                                                FontWeight.bold,
                                                                            fontSize:
                                                                                15,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ),
                                                              if (!_isNavigating) ...[
                                                                const SizedBox(
                                                                  height: 8,
                                                                ),
                                                                GestureDetector(
                                                                  onTap:
                                                                      _clearConvoyRoute,
                                                                  child: Text(
                                                                    l10n.authCancel,
                                                                    style: TextStyle(
                                                                      color: Colors
                                                                          .white38,
                                                                      fontSize:
                                                                          13,
                                                                    ),
                                                                  ),
                                                                ),
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
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          // ── Speed bubble (left side, like regular map) ─
                          if (!_isNavigating)
                            Positioned(
                              left: 14,
                              bottom: 155,
                              child: ValueListenableBuilder<double>(
                                valueListenable: _speedNotifier,
                                builder: (context, speedKmh, _) {
                                  return ValueListenableBuilder<SpeedUnit>(
                                    valueListenable: UserPreferencesService
                                        .instance
                                        .speedUnit,
                                    builder: (context, speedUnit, _) {
                                      final prefs =
                                          UserPreferencesService.instance;
                                      final roadLimitKmh = _roadSpeedLimitKmh;
                                      final over =
                                          roadLimitKmh != null &&
                                          speedKmh > roadLimitKmh;
                                      final speedDisplay = prefs.toDisplaySpeed(
                                        speedKmh: speedKmh,
                                        unit: speedUnit,
                                      );
                                      final limitDisplay = roadLimitKmh == null
                                          ? null
                                          : prefs.toDisplaySpeed(
                                              speedKmh: roadLimitKmh,
                                              unit: speedUnit,
                                            );
                                      final limitRatio =
                                          limitDisplay != null &&
                                              limitDisplay > 0
                                          ? (speedDisplay / limitDisplay).clamp(
                                              0.0,
                                              1.25,
                                            )
                                          : 0.0;
                                      final unitLabel =
                                          speedUnit == SpeedUnit.kmh
                                          ? l10n.settingsSpeedUnitKmh
                                          : l10n.settingsSpeedUnitMph;
                                      return Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox(
                                            width: 64,
                                            height: 64,
                                            child: Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                CustomPaint(
                                                  size: const Size(64, 64),
                                                  painter:
                                                      _ConvoySpeedBarsPainter(
                                                        ratio: limitRatio,
                                                        activeColor: over
                                                            ? const Color(
                                                                0xFFFF5A5F,
                                                              )
                                                            : const Color(
                                                                0xFFFF9A2F,
                                                              ),
                                                        inactiveColor:
                                                            const Color(
                                                              0x40FFFFFF,
                                                            ),
                                                        strokeWidth: 4.0,
                                                        segments: 30,
                                                      ),
                                                ),
                                                Container(
                                                  width: 58,
                                                  height: 58,
                                                  decoration: BoxDecoration(
                                                    color: over
                                                        ? const Color(
                                                            0xFFD32F2F,
                                                          )
                                                        : const Color(
                                                            0xEE0A1F63,
                                                          ),
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: over
                                                          ? Colors.red.shade300
                                                          : const Color(
                                                              0x883AA8FF,
                                                            ),
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
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Text(
                                                        speedDisplay
                                                            .toStringAsFixed(0),
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 22,
                                                          fontWeight:
                                                              FontWeight.bold,
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
                                          Container(
                                            width: 42,
                                            height: 42,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: limitDisplay != null
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
                                                limitDisplay != null
                                                    ? limitDisplay
                                                          .toStringAsFixed(0)
                                                    : '--',
                                                style: TextStyle(
                                                  color: limitDisplay != null
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
                          // Buttons overlay
                          Positioned(
                            right: 14,
                            bottom: _routeDestination != null || _isRouting
                                ? 214
                                : 84,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _convoyCircleButton(
                                  semanticLabel: _isFollowingMyPosition
                                      ? l10n.a11yStopFollowingLocation
                                      : l10n.a11yCenterOnLocation,
                                  onTap: () {
                                    final me = _myLocation;
                                    if (me == null) return;
                                    final nextFollowing =
                                        !_isFollowingMyPosition;
                                    setState(() {
                                      if (_isFollowingMyPosition &&
                                          !nextFollowing) {
                                        _mapViewEpoch++;
                                      }
                                      _isFollowingMyPosition = nextFollowing;
                                    });

                                    if (_isFollowingMyPosition) {
                                      _curLat = _tgtLat = me.latitude;
                                      _curLng = _tgtLng = me.longitude;
                                      _curHdg = _tgtHdg = _filteredTgtHdg =
                                          _myHeading;
                                      _rawCompassHdg = _myHeading;
                                      _lastLocForBearing = me;
                                      _lastCamTick = null;
                                      _camInitialized = true;
                                      final zoom = _targetZoom();
                                      _moveCameraForNav(
                                        lat: me.latitude,
                                        lng: me.longitude,
                                        headingDeg: _myHeading,
                                        zoom: zoom,
                                      );
                                    }
                                  },
                                  color: _isFollowingMyPosition
                                      ? const Color(0xFF1E6BFF)
                                      : null,
                                  child: Icon(
                                    _isFollowingMyPosition
                                        ? Icons.my_location
                                        : Icons.location_searching,
                                    color: Colors.white70,
                                    size: 19,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _convoyCircleButton(
                                  semanticLabel: l10n.convoyMembers(
                                    locations.length,
                                  ),
                                  onTap: () => _fitAllMembers(locations),
                                  child: const Icon(
                                    Icons.people_alt_outlined,
                                    color: Colors.white70,
                                    size: 19,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _convoyCircleButton(
                                  semanticLabel: l10n.a11yChooseMapLayer,
                                  color: _useSatelliteMap
                                      ? const Color(0xFF1E6BFF)
                                      : null,
                                  onTap: () => _showConvoyMapLayerPicker(l10n),
                                  child: Icon(
                                    Icons.layers_outlined,
                                    color: _useSatelliteMap
                                        ? Colors.white
                                        : Colors.white70,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _convoyCircleButton(
                                  semanticLabel: l10n.aiRouteButton,
                                  onTap: _openAiFromConvoyButton,
                                  color: _activeRoute != null
                                      ? const Color(0xFF1B4F9C)
                                      : null,
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
                                _convoyCircleButton(
                                  semanticLabel: _use3DMap
                                      ? l10n.a11ySwitchTo2d
                                      : l10n.a11ySwitchTo3d,
                                  onTap: () {
                                    setState(() => _use3DMap = !_use3DMap);
                                    UserPreferencesService
                                            .instance
                                            .use3DMap
                                            .value =
                                        _use3DMap;
                                  },
                                  child: Text(
                                    _use3DMap
                                        ? l10n.mapModeLabel3d
                                        : l10n.mapModeLabel2d,
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Light / Dark map style toggle
                                _convoyCircleButton(
                                  semanticLabel: _useDarkMap
                                      ? l10n.a11yUseLightMap
                                      : l10n.a11yUseDarkMap,
                                  onTap: () {
                                    setState(() {
                                      _useDarkMap = !_useDarkMap;
                                      _autoMapTheme = false;
                                    });
                                  },
                                  child: Icon(
                                    _useDarkMap
                                        ? Icons.dark_mode
                                        : Icons.light_mode,
                                    color: Colors.white70,
                                    size: 19,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Voice navigation toggle
                                ValueListenableBuilder<bool>(
                                  valueListenable: TtsService.instance.enabled,
                                  builder: (context, ttsOn, _) {
                                    return _convoyCircleButton(
                                      semanticLabel: ttsOn
                                          ? l10n.a11yDisableVoiceNavigation
                                          : l10n.a11yEnableVoiceNavigation,
                                      onTap: () {
                                        TtsService.instance.enabled.value =
                                            !ttsOn;
                                      },
                                      child: Icon(
                                        ttsOn
                                            ? Icons.volume_up
                                            : Icons.volume_off,
                                        color: Colors.white70,
                                        size: 19,
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 8),
                                // Report alert button
                                _convoyCircleButton(
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
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            Column(
              children: [
                Expanded(
                  child: StreamBuilder<List<ConvoyMessage>>(
                    stream: _messagesStream,
                    builder: (context, snapshot) {
                      final remoteMessages = snapshot.data ?? const [];
                      final remoteIds = remoteMessages
                          .map((message) => message.id)
                          .toSet();
                      final messages = [
                        ...remoteMessages,
                        ..._sentMessages.where(
                          (message) => !remoteIds.contains(message.id),
                        ),
                      ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
                      if (messages.isEmpty) {
                        return Center(
                          child: Text(
                            l10n.convoyChatEmpty,
                            style: const TextStyle(color: Colors.white54),
                          ),
                        );
                      }

                      return ListView.builder(
                        controller: _chatScrollController,
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          return Container(
                            key: ValueKey(message.id),
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  message.userLabel,
                                  style: const TextStyle(
                                    color: Color(0xFF3AA8FF),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  message.text,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: l10n.convoyChatPlaceholder,
                              hintStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),
                              ),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.08),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.2),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.2),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: const BorderSide(
                                  color: Color(0xFF1E6BFF),
                                ),
                              ),
                            ),
                            onSubmitted: (_) {
                              if (!_isSendingMessage) _sendMessage();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF1E6BFF),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                          ),
                          onPressed: _isSendingMessage ? null : _sendMessage,
                          child: _isSendingMessage
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(l10n.convoyChatSend),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _ConvoyRouteOptionType { recommended, alternative, unverified }

class _ConvoyAiAnalysisSection extends StatelessWidget {
  const _ConvoyAiAnalysisSection({
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
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
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

class _ConvoyRouteOption {
  const _ConvoyRouteOption({required this.route, required this.type});
  final RouteResult route;
  final _ConvoyRouteOptionType type;
}

class _ConvoyPoiCandidate {
  const _ConvoyPoiCandidate({
    required this.title,
    required this.subtitle,
    required this.position,
    required this.distanceMeters,
  });
  final String title;
  final String subtitle;
  final LatLng position;
  final double distanceMeters;
}

class _ConvoyPoiResultsSheet extends StatefulWidget {
  const _ConvoyPoiResultsSheet({
    required this.title,
    required this.icon,
    required this.loadCandidates,
    required this.formatDistance,
    required this.onSelected,
  });
  final String title;
  final IconData icon;
  final Future<List<_ConvoyPoiCandidate>> Function() loadCandidates;
  final String Function(double) formatDistance;
  final void Function(_ConvoyPoiCandidate) onSelected;
  @override
  State<_ConvoyPoiResultsSheet> createState() => _ConvoyPoiResultsSheetState();
}

class _ConvoyPoiResultsSheetState extends State<_ConvoyPoiResultsSheet> {
  late final Future<List<_ConvoyPoiCandidate>> _future;
  @override
  void initState() {
    super.initState();
    _future = widget.loadCandidates();
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
                color: const Color(0x663AA8FF),
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
                l10n.routeStopNearbySubtitle,
                style: const TextStyle(color: Colors.white54),
              ),
            ),
            Flexible(
              child: FutureBuilder<List<_ConvoyPoiCandidate>>(
                future: _future,
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
                        l10n.routeStopNearbyEmpty,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: candidates.length,
                    // ignore: unnecessary_underscores
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: Colors.white12),
                    itemBuilder: (context, index) {
                      final c = candidates[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xEE0A1F63),
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(
                          c.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          [
                            if (c.subtitle.isNotEmpty) c.subtitle,
                            l10n.routeStopAway(
                              widget.formatDistance(c.distanceMeters),
                            ),
                          ].join(' · '),
                          maxLines: 2,
                          style: const TextStyle(color: Colors.white54),
                        ),
                        trailing: const Icon(
                          Icons.add_circle,
                          color: Color(0xFF3AA8FF),
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          widget.onSelected(c);
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

class _ConvoySearchShortcutCard extends StatelessWidget {
  const _ConvoySearchShortcutCard({
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

class _ConvoySearchDestRow extends StatelessWidget {
  const _ConvoySearchDestRow({
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

class _ConvoySpeedBarsPainter extends CustomPainter {
  final double ratio;
  final Color activeColor;
  final Color inactiveColor;
  final double strokeWidth;
  final int segments;

  const _ConvoySpeedBarsPainter({
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
    const start = -math.pi / 2;
    const gap = 0.06;
    final segSweep = (totalSweep - (segments - 1) * gap) / segments;
    final activeCount = (ratio.clamp(0.0, 1.0) * segments).round();

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
  bool shouldRepaint(covariant _ConvoySpeedBarsPainter oldDelegate) {
    return oldDelegate.ratio != ratio ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.segments != segments;
  }
}

class _ConvoyFavPreset {
  final String key;
  final IconData icon;
  final String label;
  const _ConvoyFavPreset(this.key, this.icon, this.label);
}

// ── Alert marker (replicates MapWidget's _AlertMarker) ───────────────────────

class _ConvoyAlertMarker extends StatelessWidget {
  const _ConvoyAlertMarker({required this.alert});
  final AlertModel alert;

  Color _bgColor(AlertType t) => switch (t) {
    AlertType.roadClosure => const Color(0xFFB71C1C),
    AlertType.police => const Color(0xFF1565C0),
    AlertType.roadwork => const Color(0xFFE65100),
    AlertType.accident => const Color(0xFFC62828),
    AlertType.trafficJam => const Color(0xFFF57F17),
    AlertType.speedCamera => const Color(0xFF6A1B9A),
    AlertType.narrowRoad => const Color(0xFF00695C),
    AlertType.steepHill => const Color(0xFF37474F),
    AlertType.speedBump => const Color(0xFFFF7A00),
    AlertType.meetup => const Color(0xFF1E88E5),
    AlertType.parking => const Color(0xFF0277BD),
    AlertType.foodStop => const Color(0xFFEF6C00),
    AlertType.charging => const Color(0xFF00A86B),
    AlertType.hangout => const Color(0xFFFFB300),
    _ => const Color(0xFF4A148C),
  };

  @override
  Widget build(BuildContext context) {
    final color = _bgColor(alert.type);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.6),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Center(
            child: Text(alert.type.emoji, style: const TextStyle(fontSize: 20)),
          ),
        ),
        CustomPaint(
          size: const Size(10, 8),
          painter: _AlertTailPainter(color: color),
        ),
      ],
    );
  }
}

class _AlertTailPainter extends CustomPainter {
  const _AlertTailPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_AlertTailPainter old) => old.color != color;
}

// ── Inline report sheet ───────────────────────────────────────────────────────

class _ConvoyInlineReportSheet extends StatefulWidget {
  const _ConvoyInlineReportSheet({
    required this.position,
    required this.controller,
    required this.onSubmitted,
  });

  final LatLng position;
  final AlertsController controller;
  final VoidCallback onSubmitted;

  @override
  State<_ConvoyInlineReportSheet> createState() =>
      _ConvoyInlineReportSheetState();
}

class _ConvoyInlineReportSheetState extends State<_ConvoyInlineReportSheet> {
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
    await widget.controller.submit(
      type: _selected!,
      position: widget.position,
      description: _descriptionController.text.trim(),
    );
    widget.onSubmitted();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF071739),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: Color(0x443AA8FF), width: 1)),
        ),
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 16),
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
      ),
    );
  }
}
