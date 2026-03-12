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
  double _headingDegrees = 0;
  LatLng? _currentLocation;
  String _locationStatus = '';
  // Tracks progress along route so nearest-point scan is O(1) not O(n).
  int _lastNearestIdx = 0;
  String _routingStatus = '';
  bool _isRouting = false;
  bool _isNavigating = false;
  // true = camera locked on user (like Waze follow mode)
  bool _isFollowing = false;
  bool _use3DMap = true;
  LatLng? _destination;
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
  double _remainingDistM = 0;
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
            if (!mounted) {
              return;
            }

            final speedMetersPerSecond = position.speed < 0
                ? 0
                : position.speed;

            final hadLocation = _currentLocation != null;
            final currentPos = LatLng(position.latitude, position.longitude);
            final newSpeed = speedMetersPerSecond * 3.6;

            // Record GPS trace while navigating (SlowRoad Learning Engine).
            // Do this BEFORE setState so we don't trigger an extra rebuild.
            if (_isNavigating) {
              SlowRoadService.instance.addPoint(currentPos, newSpeed);
            }

            // ── Trip-distance accumulation (speed calibration) ─────────────
            double newTripDist = _tripDistanceM;
            if (_isNavigating && _lastNavPos != null) {
              newTripDist += _segDist(_lastNavPos!, currentPos);
            }

            // Compute new instruction state + remaining distance synchronously.
            int? newSign;
            String? newText;
            double? newDist;
            double? newRemaining;
            if (_isNavigating && _routePoints.isNotEmpty) {
              final nearestIdx = _nearestRoutePointIndex(currentPos);
              // Remaining distance via O(1) cumulative-dist lookup.
              if (_cumulativeDist.length == _routePoints.length) {
                newRemaining = (_totalRouteDistM - _cumulativeDist[nearestIdx])
                    .clamp(0.0, _totalRouteDistM);
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

            // Single setState — one rebuild per GPS tick.
            setState(() {
              _speedKmh = newSpeed;
              // Only update heading when moving to avoid jitter when still.
              if (position.speed > 0.5 && position.heading >= 0) {
                _headingDegrees = position.heading;
              }
              _currentLocation = currentPos;
              _locationStatus = l10n.mapGpsActive;
              if (_isNavigating) {
                _tripDistanceM = newTripDist;
                _lastNavPos = currentPos;
              }
              if (newSign != null) _nextManeuverSign = newSign;
              if (newText != null) _nextManeuverText = newText;
              if (newDist != null) _distToNextManeuver = newDist;
              if (newRemaining != null) _remainingDistM = newRemaining;
              // Proximity check: find any alert within 400 m.
              _nearbyAlert = _alerts
                  .where((a) => a.distanceTo(currentPos) <= 400)
                  .fold<AlertModel?>(
                    null,
                    (best, a) =>
                        best == null ||
                            a.distanceTo(currentPos) <
                                best.distanceTo(currentPos)
                        ? a
                        : best,
                  );
            });
            // If this is the first GPS fix and a destination was already set
            // (e.g. from a convoy pin tap before GPS was ready), start routing.
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
    _addressController.dispose();
    _searchFocus.dispose();
    _debounce?.cancel();
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
    final name = suggestion['display_name']?.toString() ?? '';
    if (lat == null || lon == null) return;
    setState(() {
      _suggestions = [];
      _showSuggestions = false;
    });
    _addressController.text = name.split(',').first.trim();
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

  /// Precompute cumulative distances so remaining-dist lookups are O(1).
  List<double> _buildCumulativeDist(List<LatLng> pts) {
    if (pts.isEmpty) return const [];
    final result = List<double>.filled(pts.length, 0);
    for (int i = 1; i < pts.length; i++) {
      result[i] = result[i - 1] + _segDist(pts[i - 1], pts[i]);
    }
    return result;
  }

  /// Formatted ETA string using the learned (or fallback) speed.
  /// Returns empty string when not navigating or remaining < 50 m.
  String _formatEta() {
    if (!_isNavigating || _remainingDistM <= 50) return '';
    final vehicleType = UserPreferencesService.instance.vehicleType.value;
    final effectiveSpeed = SpeedCalibrationService.instance.effectiveSpeedKmh(
      vehicleType,
    );
    if (effectiveSpeed <= 0) return '';
    final remainingSec = _remainingDistM / (effectiveSpeed / 3.6);
    final arrival = DateTime.now().add(Duration(seconds: remainingSec.round()));
    final h = arrival.hour.toString().padLeft(2, '0');
    final m = arrival.minute.toString().padLeft(2, '0');
    final minLeft = (remainingSec / 60).ceil();
    if (minLeft < 1) return 'Framme!';
    if (minLeft < 60) return '$minLeft min · $h:$m';
    final hours = minLeft ~/ 60;
    final mins = minLeft % 60;
    return '${hours}h ${mins}min · $h:$m';
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
        _remainingDistM = totalDist;
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
      _isNavigating = false;
      _isFollowing = false;
      _instructions = const [];
      _nextManeuverText = '';
      _nextManeuverSign = 0;
      _distToNextManeuver = 0;
      _cumulativeDist = const [];
      _totalRouteDistM = 0;
      _remainingDistM = 0;
      _tripStartTime = null;
      _tripDistanceM = 0;
      _lastNavPos = null;
      _nearbyAlert = null;
      _routingStatus = AppLocalizations.of(context)!.mapTapToSelectDestination;
    });
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
                    currentLocation: _currentLocation,
                    destination: _destination,
                    routePoints: _routePoints,
                    alerts: _alerts,
                    onTap: _isNavigating ? null : _handleMapTap,
                    followUser: _isNavigating && _isFollowing,
                    heading: _headingDegrees,
                    use3D: _use3DMap,
                    distToManeuver: _isNavigating
                        ? _distToNextManeuver
                        : double.infinity,
                    onUserPanned: _isNavigating
                        ? () => setState(() => _isFollowing = false)
                        : null,
                  ),
                ),
              ),
            ),
          ),
          // ── Top UI: logo + search + speedometer (hidden while navigating) ──
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
                          height: 76,
                          fit: BoxFit.contain,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Column(
                    children: [
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
                      if (_showSuggestions && _suggestions.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 2),
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
                                final parts =
                                    (s['display_name'] as String? ?? '').split(
                                      ',',
                                    );
                                final title = parts.first.trim();
                                final subtitle = parts
                                    .skip(1)
                                    .take(3)
                                    .map((e) => e.trim())
                                    .join(', ');
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
                                                    color: Colors.white
                                                        .withValues(alpha: 0.5),
                                                    fontSize: 12,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
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
                    ],
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

          if (_isNavigating) ...[
            // ── Turn instruction banner ─ Waze-style top panel ─────────────
            if (_nextManeuverText.isNotEmpty)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xF2101E38),
                    border: Border(
                      bottom: BorderSide(color: Color(0x443AA8FF), width: 1),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 50, 16, 14),
                  child: Row(
                    children: [
                      Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A5DCC),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x661E6BFF),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          _turnIcon(_nextManeuverSign),
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          _nextManeuverText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _distToNextManeuver >= 1000
                            ? '${(_distToNextManeuver / 1000).toStringAsFixed(1)} km'
                            : '${_distToNextManeuver.round()} m',
                        style: const TextStyle(
                          color: Color(0xFF3AA8FF),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Proximity alert banner — shown when a nearby alert is within 400 m.
            if (_nearbyAlert != null && _currentLocation != null)
              Positioned(
                top: _nextManeuverText.isNotEmpty ? 130 : 50,
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

          // Report alert button — always top-right.
          Positioned(
            right: 16,
            top: 90,
            child: GestureDetector(
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
          ),

          // Re-center button — appears when user pans away during navigation.
          if (_isNavigating && !_isFollowing)
            Positioned(
              right: 20,
              bottom: 196,
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
          // ── Unified bottom nav panel ────────────────────────────────────
          Positioned(
            left: 16,
            right: 16,
            bottom: 22,
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
                    final eta = _isNavigating ? _formatEta() : '';
                    return Container(
                      decoration: BoxDecoration(
                        color: const Color(0xF0071428),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0x553AA8FF)),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black54,
                            blurRadius: 14,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Speed circle
                                if (_isNavigating)
                                  Container(
                                    width: 68,
                                    height: 68,
                                    margin: const EdgeInsets.only(right: 12),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: over
                                          ? Colors.red.shade800.withValues(
                                              alpha: 0.9,
                                            )
                                          : const Color(0xFF091428),
                                      border: Border.all(
                                        color: over
                                            ? Colors.red.shade300
                                            : const Color(0xFF3AA8FF),
                                        width: 2.5,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          speedDisplay.toStringAsFixed(0),
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            height: 1.0,
                                          ),
                                        ),
                                        Text(
                                          speedUnit == SpeedUnit.kmh
                                              ? 'km/h'
                                              : 'mph',
                                          style: const TextStyle(
                                            color: Colors.white60,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                // Route status + ETA
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
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
                                                      color: Colors.white70,
                                                    ),
                                              ),
                                            ),
                                          Expanded(
                                            child: Text(
                                              _routingStatus,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 13,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (eta.isNotEmpty) ...[
                                        const SizedBox(height: 5),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.access_time_rounded,
                                              size: 13,
                                              color: Color(0xFF3AA8FF),
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              eta,
                                              style: const TextStyle(
                                                color: Color(0xFF3AA8FF),
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                // 3D / 2D toggle
                                if (_isNavigating) ...[
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() => _use3DMap = !_use3DMap);
                                      UserPreferencesService
                                              .instance
                                              .use3DMap
                                              .value =
                                          _use3DMap;
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 11,
                                        vertical: 7,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF091428),
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: _use3DMap
                                              ? const Color(0xFF3AA8FF)
                                              : Colors.white30,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Text(
                                        _use3DMap ? '3D' : '2D',
                                        style: TextStyle(
                                          color: _use3DMap
                                              ? const Color(0xFF3AA8FF)
                                              : Colors.white60,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          // Action button row
                          if (_routePoints.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _isNavigating
                                        ? _NavButton(
                                            icon: Icons.stop_circle_outlined,
                                            label: l10n.mapEndNavigation,
                                            color: const Color(0xFFD32F2F),
                                            onTap: _clearRoute,
                                          )
                                        : _NavButton(
                                            icon: Icons.navigation_rounded,
                                            label: l10n.mapStartNavigation,
                                            color: const Color(0xFF0A7E3F),
                                            onTap: () {
                                              final vehicleType =
                                                  UserPreferencesService
                                                      .instance
                                                      .vehicleType
                                                      .value;
                                              SlowRoadService.instance
                                                  .startSession(vehicleType);
                                              setState(() {
                                                _isNavigating = true;
                                                _isFollowing = true;
                                                _tripStartTime = DateTime.now();
                                                _tripDistanceM = 0;
                                                _lastNavPos = _currentLocation;
                                              });
                                            },
                                          ),
                                  ),
                                  if (!_isNavigating) ...[
                                    const SizedBox(width: 8),
                                    _IconNavButton(
                                      icon: Icons.close_rounded,
                                      onTap: _clearRoute,
                                    ),
                                  ],
                                ],
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
        ],
      ),
    );
  }
}
// ── Reusable nav button widgets ───────────────────────────────────────────────

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.45),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconNavButton extends StatelessWidget {
  const _IconNavButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Icon(icon, color: Colors.white60, size: 20),
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
    await widget.controller.submit(
      type: _selected!,
      position: widget.position,
      description: '',
    );
    widget.onSubmitted();
    if (mounted) Navigator.of(context).pop();
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
