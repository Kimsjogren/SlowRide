import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:slowride/l10n/app_localizations.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:slowride/services/navigation_request_service.dart';
import 'package:slowride/services/routing_service.dart';
import 'package:slowride/services/slow_road_service.dart';
import 'package:slowride/services/speed_calibration_service.dart';
import 'package:slowride/services/user_preferences_service.dart';
import 'package:slowride/features/alerts/alerts_controller.dart';
import 'package:slowride/models/alert_model.dart';
import 'package:slowride/widgets/map_widget.dart';
import 'package:slowride/widgets/speedometer_widget.dart';
import 'package:slowride/features/paywall/paywall_screen.dart';
import 'package:slowride/services/subscription_service.dart';

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
  String _locationStatus = '';

  // Notifiers that feed MapWidget directly — updating them does NOT cause
  // the whole screen to rebuild (unlike setState).
  final ValueNotifier<LatLng?> _locationNotifier = ValueNotifier(null);
  final ValueNotifier<double> _headingNotifier = ValueNotifier(0);

  // Tracks progress along route so nearest-point scan is O(1) not O(n).
  int _lastNearestIdx = 0;
  String _routingStatus = '';
  bool _isRouting = false;
  bool _isNavigating = false;
  // true = camera locked on user (like Waze follow mode)
  bool _isFollowing = false;
  bool _use3DMap = true;
  bool _useDarkMap = false;
  LatLng? _destination;
  String _destinationLabel = '';
  List<LatLng> _routePoints = const [];

  // ── Turn-by-turn instructions ─────────────────────────────────────
  List<RouteInstruction> _instructions = const [];
  int _nextManeuverSign = 0;
  String _nextManeuverText = '';
  double _distToNextManeuver = 0;

  // ── Speed calibration + live ETA ──────────────────────────────────
  // Cumulative distance from route start to each point (metres).
  List<double> _cumulativeDist = const [];
  double _totalRouteDistM = 0;
  // Per-trip tracking: accumulated while _isNavigating is true.
  DateTime? _tripStartTime;
  LatLng? _lastNavPos;
  double _tripDistanceM = 0;

  // ── Community alerts ──────────────────────────────────────────
  final AlertsController _alertsController = AlertsController();
  List<AlertModel> _alerts = const [];
  Timer? _alertsTimer;
  // Nearest alert within 400 m while navigating (for proximity warning).
  AlertModel? _nearbyAlert;

  // ── GPS simulation (test-only, visible in debug builds) ──────────────
  bool _isSimulating = false;
  Timer? _simTimer;
  int _simPtIdx = 0;
  double _simSegOffsetM = 0;
  static const double _simSpeedKmh = 50.0;
  static const Duration _simInterval = Duration(milliseconds: 200);

  bool _localizedDefaultsSet = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_localizedDefaultsSet) {
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    _locationStatus = l10n.mapStartingGps;
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
    // Start community alerts polling (immediate + every 30 s).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadAlerts();
    });
    _alertsTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _loadAlerts();
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
    final l10n = AppLocalizations.of(context)!;

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) {
          return;
        }
        setState(() {
          _locationStatus = l10n.mapLocationServicesDisabled;
        });
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
        setState(() {
          _locationStatus = l10n.mapLocationPermissionMissing;
        });
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
      setState(() {
        _locationStatus = l10n.mapGpsUnavailable;
      });
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

  Future<void> _fetchSuggestions(String query) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': query,
        'format': 'jsonv2',
        'addressdetails': '1',
        'limit': '6',
        'countrycodes': 'se',
      });
      final response = await http.get(
        uri,
        headers: const {
          'User-Agent': 'CruizX/1.0 (address-search)',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode != 200 || !mounted) return;
      final decoded = jsonDecode(response.body);
      if (decoded is! List) return;
      setState(() {
        _suggestions = decoded.whereType<Map<String, dynamic>>().toList();
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
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': query,
        'format': 'jsonv2',
        'addressdetails': '1',
        'limit': '1',
      });

      final response = await http.get(
        uri,
        headers: const {
          'User-Agent': 'CruizX/1.0 (address-search)',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw StateError('address_lookup_failed');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List || decoded.isEmpty) {
        if (!mounted) {
          return;
        }
        setState(() {
          _isRouting = false;
          _routingStatus = l10n.mapAddressNotFound;
        });
        return;
      }

      final first = decoded.first;
      if (first is! Map<String, dynamic>) {
        throw StateError('address_lookup_failed');
      }

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
    _lastNearestIdx = idx;
    return idx;
  }

  double _segDist(LatLng a, LatLng b) {
    const lat2m = 111320.0;
    final lng2m = 111320.0 * math.cos(a.latitude * math.pi / 180.0);
    final dx = (b.latitude - a.latitude) * lat2m;
    final dy = (b.longitude - a.longitude) * lng2m;
    return math.sqrt(dx * dx + dy * dy);
  }

  double _normalizeDeg(double angle) => (angle % 360 + 360) % 360;

  double _bearingDeg(LatLng a, LatLng b) {
    final dLat = b.latitude - a.latitude;
    final dLng = b.longitude - a.longitude;
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
      if (road.isNotEmpty) {
        return houseNumber.isNotEmpty ? '$road $houseNumber' : road;
      }
    }

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

      final km = route.distanceMeters / 1000;
      final minutes = route.durationSeconds / 60;
      final cumDist = _buildCumulativeDist(route.points);
      final totalDist = cumDist.isNotEmpty ? cumDist.last : 0.0;

      setState(() {
        _routePoints = route.points;
        _cumulativeDist = cumDist;
        _totalRouteDistM = totalDist;
        _instructions = route.instructions;
        _lastNearestIdx = 0; // reset forward-scan index for new route
        _nextManeuverText = '';
        _nextManeuverSign = 0;
        _distToNextManeuver = 0;
        _routingStatus = l10n.mapRouteReady(
          km.toStringAsFixed(1),
          minutes.toStringAsFixed(0),
        );
      });
      SubscriptionService.instance.recordRoute();
    } on RoutingException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _routePoints = const [];
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
      _destination = null;
      _destinationLabel = '';
      _isNavigating = false;
      _isFollowing = false;
      _instructions = const [];
      _nextManeuverText = '';
      _nextManeuverSign = 0;
      _distToNextManeuver = 0;
      _cumulativeDist = const [];
      _totalRouteDistM = 0;
      _tripStartTime = null;
      _tripDistanceM = 0;
      _lastNavPos = null;
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
    int? nearestIdxForHeading;
    double? nearestPointDistM;
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
      _locationStatus = l10n.mapGpsActive;
      if (_isNavigating) {
        _tripDistanceM = newTripDist;
        _lastNavPos = currentPos;
      }
      if (newSign != null) _nextManeuverSign = newSign;
      if (newText != null) _nextManeuverText = newText;
      if (newDist != null) _distToNextManeuver = newDist;
      if (newRemaining != null) {
        final remKm = newRemaining / 1000;
        final distStr = remKm >= 1.0
            ? '${remKm.toStringAsFixed(1)} km ${l10n.mapRemaining}'
            : '${newRemaining.round()} m ${l10n.mapRemaining}';
        final vehicleType = UserPreferencesService.instance.vehicleType.value;
        final effSpd = SpeedCalibrationService.instance.effectiveSpeedKmh(
          vehicleType,
        );
        if (effSpd > 0 && newRemaining > 50) {
          final sec = newRemaining / (effSpd / 3.6);
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
                    routePoints: _routePoints,
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
          // ── Top UI: logo + speedometer (hidden while navigating) ──
          if (!_isNavigating)
            Positioned(
              top: 18,
              left: 20,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xCC071739),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x883AA8FF)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/logga_nobg.png',
                          height: 96,
                          fit: BoxFit.contain,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ValueListenableBuilder<SpeedUnit>(
                    valueListenable: preferences.speedUnit,
                    builder: (context, speedUnit, _) {
                      return ValueListenableBuilder<double>(
                        valueListenable: preferences.maxSpeedKmh,
                        builder: (context, maxSpeedKmh, _) {
                          final speedDisplay = preferences.toDisplaySpeed(
                            speedKmh: _speedKmh,
                            unit: speedUnit,
                          );
                          final maxSpeedDisplay = preferences.toDisplaySpeed(
                            speedKmh: maxSpeedKmh,
                            unit: speedUnit,
                          );
                          final speedUnitLabel = speedUnit == SpeedUnit.kmh
                              ? l10n.settingsSpeedUnitKmh
                              : l10n.settingsSpeedUnitMph;

                          return SpeedometerWidget(
                            speedValue: speedDisplay,
                            speedUnitLabel: speedUnitLabel,
                            maxSpeedValue: maxSpeedDisplay,
                            isOverSpeed: _speedKmh > maxSpeedKmh,
                            statusText: _locationStatus,
                          );
                        },
                      );
                    },
                  ),
                ],
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
                  ? 170
                  : 80,
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
                                      _maneuverPrimaryText(_nextManeuverText),
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

          // Right-side floating buttons (report + 2D/3D)
          Positioned(
            right: 14,
            bottom: 155,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 2D / 3D toggle
                GestureDetector(
                  onTap: () {
                    setState(() => _use3DMap = !_use3DMap);
                    UserPreferencesService.instance.use3DMap.value = _use3DMap;
                  },
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xEE0A1F63),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0x883AA8FF),
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
                    child: Center(
                      child: Text(
                        _use3DMap ? l10n.mapModeLabel3d : l10n.mapModeLabel2d,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Light / Dark map style toggle
                GestureDetector(
                  onTap: () {
                    setState(() => _useDarkMap = !_useDarkMap);
                  },
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xEE0A1F63),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0x883AA8FF),
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
                    child: Icon(
                      _useDarkMap ? Icons.dark_mode : Icons.light_mode,
                      color: Colors.white70,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Report alert button
                GestureDetector(
                  onTap: _showReportAlertSheet,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xEE0A1F63),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0x883AA8FF),
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
                      Icons.warning_amber_rounded,
                      color: Color(0xFFF57F17),
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Re-center button — appears when user pans away during navigation.
          if (_isNavigating && !_isFollowing)
            Positioned(
              right: 14,
              bottom: 335,
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
                            final over = _speedKmh > maxSpeedKmh;
                            final speedDisplay = preferences.toDisplaySpeed(
                              speedKmh: _speedKmh,
                              unit: speedUnit,
                            );
                            final limitDisplay = preferences.toDisplaySpeed(
                              speedKmh: maxSpeedKmh,
                              unit: speedUnit,
                            );
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
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    if (_isNavigating) ...[
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
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
                                                speedDisplay.toStringAsFixed(0),
                                                style: TextStyle(
                                                  color: over
                                                      ? Colors.redAccent
                                                      : Colors.white,
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                  height: 1.0,
                                                ),
                                              ),
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
                                                color: Colors.red.shade700,
                                                width: 3.5,
                                              ),
                                            ),
                                            child: Center(
                                              child: Text(
                                                limitDisplay.toStringAsFixed(0),
                                                style: const TextStyle(
                                                  color: Colors.black,
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
                                            Text(
                                              _destinationLabel,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                height: 1.2,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
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
                                            const SizedBox(height: 8),
                                            GestureDetector(
                                              onTap: _startSimulation,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 7,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFF7B2FBE,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                  '▶ ${l10n.mapSimulateButton}',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
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
