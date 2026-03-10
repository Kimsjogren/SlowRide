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
import 'package:slowride/services/user_preferences_service.dart';
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
  }

  void _onExternalNavigationRequest() {
    final dest = NavigationRequestService.instance.pendingDestination.value;
    if (dest != null) {
      NavigationRequestService.instance.consume();
      _handleMapTap(dest);
    }
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

            // Compute new instruction state synchronously (no setState inside).
            int? newSign;
            String? newText;
            double? newDist;
            if (_isNavigating &&
                _instructions.isNotEmpty &&
                _routePoints.isNotEmpty) {
              final nearestIdx = _nearestRoutePointIndex(currentPos);
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

            // Single setState — one rebuild per GPS tick.
            setState(() {
              _speedKmh = newSpeed;
              // Only update heading when moving to avoid jitter when still.
              if (position.speed > 0.5 && position.heading >= 0) {
                _headingDegrees = position.heading;
              }
              _currentLocation = currentPos;
              _locationStatus = l10n.mapGpsActive;
              if (newSign != null) _nextManeuverSign = newSign;
              if (newText != null) _nextManeuverText = newText;
              if (newDist != null) _distToNextManeuver = newDist;
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
          'User-Agent': 'SlowRide/1.0 (address-search)',
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
          'User-Agent': 'SlowRide/1.0 (address-search)',
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

      setState(() {
        _routePoints = route.points;
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
    // End or cancel the SlowRoad learning session.
    if (_isNavigating) {
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
                child: MapWidget(
                  currentLocation: _currentLocation,
                  destination: _destination,
                  routePoints: _routePoints,
                  onTap: _isNavigating ? null : _handleMapTap,
                  followUser: _isNavigating && _isFollowing,
                  heading: _headingDegrees,
                  use3D: _use3DMap,
                  onUserPanned: _isNavigating
                      ? () => setState(() => _isFollowing = false)
                      : null,
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
                          width: 30,
                          height: 30,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.appTitle,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                shadows: const [
                                  Shadow(
                                    color: Colors.black87,
                                    blurRadius: 6,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
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

            // Speed badge — bottom-left during navigation.
            Positioned(
              bottom: 130,
              left: 16,
              child: ValueListenableBuilder<SpeedUnit>(
                valueListenable: preferences.speedUnit,
                builder: (context, speedUnit, _) {
                  return ValueListenableBuilder<double>(
                    valueListenable: preferences.maxSpeedKmh,
                    builder: (context, maxSpeedKmh, _) {
                      final speedDisplay = preferences.toDisplaySpeed(
                        speedKmh: _speedKmh,
                        unit: speedUnit,
                      );
                      final over = _speedKmh > maxSpeedKmh;
                      return Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: over
                              ? Colors.red.shade700
                              : const Color(0xEE0A1F63),
                          border: Border.all(
                            color: over
                                ? Colors.red.shade300
                                : const Color(0xFF3AA8FF),
                            width: 2.5,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black54,
                              blurRadius: 10,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              speedDisplay.toStringAsFixed(0),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                height: 1,
                              ),
                            ),
                            Text(
                              speedUnit == SpeedUnit.kmh ? 'km/h' : 'mph',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
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

          // 3D / 2D toggle — bottom-right during navigation.
          if (_isNavigating)
            Positioned(
              bottom: 130,
              right: 16,
              child: GestureDetector(
                onTap: () {
                  setState(() => _use3DMap = !_use3DMap);
                  UserPreferencesService.instance.use3DMap.value = _use3DMap;
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xEE0A1F63),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _use3DMap
                          ? const Color(0xFF3AA8FF)
                          : Colors.white30,
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
                  child: Text(
                    _use3DMap ? '3D' : '2D',
                    style: TextStyle(
                      color: _use3DMap
                          ? const Color(0xFF3AA8FF)
                          : Colors.white60,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),

          // Re-center button — appears when user pans away during navigation.
          if (_isNavigating && !_isFollowing)
            Positioned(
              right: 20,
              bottom: 205,
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
          Positioned(
            left: 20,
            right: 20,
            bottom: 22,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xCC071739),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0x553AA8FF)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      if (_isRouting)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white70,
                          ),
                        ),
                      if (_isRouting) const SizedBox(width: 8),
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
                  if (_routePoints.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _isNavigating
                              ? _NavButton(
                                  icon: Icons.stop_circle_outlined,
                                  label: 'Avsluta navigation',
                                  color: const Color(0xFFD32F2F),
                                  onTap: _clearRoute,
                                )
                              : _NavButton(
                                  icon: Icons.navigation_rounded,
                                  label: 'Starta navigation',
                                  color: const Color(0xFF0A7E3F),
                                  onTap: () {
                                    final vehicleType = UserPreferencesService
                                        .instance
                                        .vehicleType
                                        .value;
                                    SlowRoadService.instance.startSession(
                                      vehicleType,
                                    );
                                    setState(() {
                                      _isNavigating = true;
                                      _isFollowing = true;
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
                  ],
                ],
              ),
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
