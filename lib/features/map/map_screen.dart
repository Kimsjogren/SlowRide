import 'dart:async';
import 'dart:convert';

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
  String _routingStatus = '';
  bool _isRouting = false;
  bool _isNavigating = false;
  // true = camera locked on user (like Waze follow mode)
  bool _isFollowing = false;
  LatLng? _destination;
  List<LatLng> _routePoints = const [];
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

      const settings = LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 3,
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
            setState(() {
              _speedKmh = speedMetersPerSecond * 3.6;
              // heading is 0–360 degrees, 0 = north. Only update when
              // moving (speed > 0.5 m/s) to avoid jitter when standing still.
              if (position.speed > 0.5 && position.heading >= 0) {
                _headingDegrees = position.heading;
              }
              _currentLocation = currentPos;
              _locationStatus = l10n.mapGpsActive;
            });
            // Record GPS trace while navigating (SlowRoad Learning Engine).
            if (_isNavigating) {
              SlowRoadService.instance.addPoint(currentPos, _speedKmh);
            }
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
          // ── Navigation HUD (fullscreen mode) ──────────────────────────────
          if (_isNavigating) ...[
            // Speed badge — top-left corner (Waze-style).
            Positioned(
              top: 52,
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

          // Re-center button — appears when user pans away during navigation.
          if (_isNavigating && !_isFollowing)
            Positioned(
              right: 20,
              bottom: 140,
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
                              ? FilledButton.icon(
                                  onPressed: _clearRoute,
                                  icon: const Icon(Icons.stop),
                                  label: const Text('Avsluta'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.red.shade700,
                                  ),
                                )
                              : FilledButton.icon(
                                  onPressed: () {
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
                                  icon: const Icon(Icons.navigation),
                                  label: const Text('Starta'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.green.shade700,
                                  ),
                                ),
                        ),
                        if (!_isNavigating) ...[
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            onPressed: _clearRoute,
                            icon: const Icon(Icons.clear, size: 16),
                            label: const Text('Rensa'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white60,
                              side: const BorderSide(color: Colors.white24),
                            ),
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
