import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:slowride/features/alerts/alerts_controller.dart';
import 'package:slowride/features/convoy/convoy_controller.dart';
import 'package:slowride/models/alert_model.dart';
import 'package:slowride/services/auth_service.dart';
import 'package:slowride/services/routing_service.dart';
import 'package:slowride/services/supabase_service.dart';
import 'package:slowride/services/user_preferences_service.dart';
import 'package:slowride/l10n/app_localizations.dart';
import 'package:slowride/models/convoy_member_location.dart';
import 'package:slowride/models/convoy_message.dart';
import 'package:slowride/models/convoy_model.dart';
import 'package:slowride/models/convoy_pin.dart';

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
  final TextEditingController _addressSearchController =
      TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final MapController _mapController = MapController();
  Timer? _searchDebounce;
  List<Map<String, dynamic>> _suggestions = [];
  bool _showSuggestions = false;

  // ── Smooth camera animation (same as MapWidget) ────────────────────────
  late final Ticker _camTicker;
  double _curLat = 0, _curLng = 0, _curHdg = 0;
  double _tgtLat = 0, _tgtLng = 0, _tgtHdg = 0;
  bool _camInitialized = false;

  StreamSubscription<Position>? _positionSubscription;
  Timer? _pinRefreshTimer;
  Timer? _locationPollTimer;
  Timer? _alertsTimer;
  List<ConvoyMemberLocation> _memberLocations = [];
  List<AlertModel> _alerts = const [];
  AlertModel? _nearbyAlert;
  LatLng? _myLocation;
  double _myHeading = 0;
  bool _isFollowingMyPosition = true;
  bool _use3DMap = true;
  String? _myUserId;

  // ── Inline routing state ────────────────────────────────────────────────
  List<LatLng> _routePoints = const [];
  LatLng? _routeDestination;
  LatLng? _pendingDestination; // set before GPS is ready
  bool _isRouting = false;
  String _routingStatus = '';

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
  static const Duration _pinTtl = Duration(minutes: 30);

  @override
  void initState() {
    super.initState();
    _camTicker = createTicker(_onCamTick)..start();
    _addressSearchController.addListener(() => setState(() {}));
    _myUserId = AuthService.instance.userId.value;
    _use3DMap = UserPreferencesService.instance.use3DMap.value;
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

  Future<void> _fetchMemberLocations() async {
    try {
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
          .toList();
      setState(() => _memberLocations = locations);
    } catch (_) {}
  }

  bool _isPinActive(ConvoyPin pin) {
    return DateTime.now().difference(pin.createdAt) <= _pinTtl;
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
        ).listen((position) async {
          final point = LatLng(position.latitude, position.longitude);
          final heading = position.heading >= 0 ? position.heading : _myHeading;
          final hadLocation = _myLocation != null;

          if (mounted) {
            setState(() {
              _myLocation = point;
              _myHeading = heading;
              // Proximity check: find any alert within 400 m.
              _nearbyAlert = _alerts
                  .where((a) => a.distanceTo(point) <= 400)
                  .fold<AlertModel?>(
                    null,
                    (best, a) =>
                        best == null ||
                            a.distanceTo(point) < best.distanceTo(point)
                        ? a
                        : best,
                  );
            });

            // Feed the camera ticker with the latest target.
            // The ticker interpolates smoothly at 60 fps — no direct
            // moveAndRotate call here (that was causing jank).
            if (_isFollowingMyPosition) {
              if (!_camInitialized) {
                _curLat = _tgtLat = point.latitude;
                _curLng = _tgtLng = point.longitude;
                _curHdg = _tgtHdg = heading;
                _camInitialized = true;
                final zoom = _use3DMap ? 18.5 : _followZoom;
                _mapController.moveAndRotate(
                  point,
                  zoom,
                  _use3DMap ? -heading : 0,
                );
              } else {
                _tgtLat = point.latitude;
                _tgtLng = point.longitude;
                _tgtHdg = heading;
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

          await _controller.updateMyLocation(
            convoyId: widget.convoy.id,
            position: point,
          );
        });
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _pinRefreshTimer?.cancel();
    _locationPollTimer?.cancel();
    _alertsTimer?.cancel();
    _searchDebounce?.cancel();
    _camTicker.dispose();
    _messageController.dispose();
    _addressSearchController.dispose();
    _searchFocus.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) {
      return;
    }

    await _controller.sendMessage(convoyId: widget.convoy.id, text: text);
    if (!mounted) {
      return;
    }
    _messageController.clear();
  }

  void _onCamTick(Duration _) {
    if (!_isFollowingMyPosition || !_camInitialized) return;
    const kPos = 0.25;
    const kHdg = 0.32;
    final dLat = _tgtLat - _curLat;
    final dLng = _tgtLng - _curLng;
    final diff = ((_tgtHdg - _curHdg + 540) % 360) - 180;
    // Deadband: skip GPU work when already at target.
    if (dLat.abs() < 1e-7 && dLng.abs() < 1e-7 && diff.abs() < 0.05) return;
    _curLat += dLat * kPos;
    _curLng += dLng * kPos;
    _curHdg = (_curHdg + diff * kHdg + 360) % 360;
    final zoom = _use3DMap ? 18.5 : _followZoom;
    if (_use3DMap) {
      const offsetDeg = 0.00045;
      final rad = _curHdg * math.pi / 180.0;
      final cLat = _curLat + offsetDeg * math.cos(rad);
      final cLng = _curLng + offsetDeg * math.sin(rad);
      _mapController.moveAndRotate(LatLng(cLat, cLng), zoom, -_curHdg);
    } else {
      _mapController.moveAndRotate(LatLng(_curLat, _curLng), zoom, -_curHdg);
    }
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    if (query.trim().length < 2) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
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

  Future<void> _searchAddress(String rawQuery) async {
    final l10n = AppLocalizations.of(context)!;
    final query = rawQuery.trim();
    if (query.isEmpty) return;
    setState(() => _showSuggestions = false);
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
      if (response.statusCode != 200) throw StateError('lookup_failed');
      final decoded = jsonDecode(response.body);
      if (decoded is! List || decoded.isEmpty) {
        if (!mounted) return;
        setState(() {
          _routingStatus = l10n.mapAddressNotFound;
        });
        return;
      }
      final first = decoded.first;
      if (first is! Map<String, dynamic>) throw StateError('lookup_failed');
      final lat = double.tryParse(first['lat']?.toString() ?? '');
      final lon = double.tryParse(first['lon']?.toString() ?? '');
      if (lat == null || lon == null) throw StateError('lookup_failed');
      if (!mounted) return;
      _routeToDestination(LatLng(lat, lon));
    } catch (_) {
      if (!mounted) return;
      setState(() => _routingStatus = l10n.mapAddressLookupFailed);
    }
  }

  void _selectSuggestion(Map<String, dynamic> s) {
    final lat = double.tryParse(s['lat']?.toString() ?? '');
    final lon = double.tryParse(s['lon']?.toString() ?? '');
    final name = s['display_name']?.toString() ?? '';
    if (lat == null || lon == null) return;
    _addressSearchController.text = name.split(',').first.trim();
    _searchFocus.unfocus();
    setState(() {
      _suggestions = [];
      _showSuggestions = false;
    });
    _routeToDestination(LatLng(lat, lon));
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
    return Opacity(
      opacity: stale ? 0.4 : 1.0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.5),
                  blurRadius: 6,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Text(
              isMe ? l10n.convoyMemberMe : member.userLabel,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: isMe ? 2.5 : 1.5),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.6),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: isMe
                ? Transform.rotate(
                    angle: _myHeading * 3.14159265 / 180,
                    child: const Icon(
                      Icons.navigation,
                      color: Colors.white,
                      size: 22,
                    ),
                  )
                : Center(
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _fitAllMembers(List<ConvoyMemberLocation> locations) {
    final points = [...locations.map((m) => m.position), ?_myLocation];
    if (points.isEmpty) return;
    if (points.length == 1) {
      _mapController.move(points.first, _followZoom);
      return;
    }
    final bounds = LatLngBounds.fromPoints(points);
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(72)),
    );
    setState(() => _isFollowingMyPosition = false);
  }

  Future<void> _loadAlerts() async {
    final center = _myLocation ?? const LatLng(59.3293, 18.0686);
    try {
      final result = await _alertsController.fetchNearby(center);
      if (!mounted) return;
      setState(() => _alerts = result);
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
    Navigator.of(context).pop(); // close bottom sheet
    _routeToDestination(pin.position);
  }

  Future<void> _routeToDestination(LatLng destination) async {
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
      _routingStatus = AppLocalizations.of(context)!.mapCalculatingRoute;
      _isFollowingMyPosition = false;
    });
    // Zoom in on my vehicle while the route is being calculated.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _mapController.move(_myLocation!, 16.5);
    });

    try {
      final route = await _routingService.getRoute(
        origin: _myLocation!,
        destination: destination,
        vehicleType: UserPreferencesService.instance.vehicleType.value,
      );
      if (!mounted) return;
      final km = route.distanceMeters / 1000;
      final minutes = (route.durationSeconds / 60).round();
      setState(() {
        _routePoints = route.points;
        _routingStatus = AppLocalizations.of(
          context,
        )!.mapRouteReady(km.toStringAsFixed(1), minutes.toString());
        _isFollowingMyPosition = false;
      });
      // Zoom to fit the full route so the driver sees start→destination.
      if (route.points.length >= 2) {
        final bounds = LatLngBounds.fromPoints(route.points);
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
      setState(() {
        _routePoints = const [];
        _routingStatus = switch (e.code) {
          RoutingErrorCode.noRouteFound => AppLocalizations.of(
            context,
          )!.mapRouteNoRouteFound,
          RoutingErrorCode.providerUnavailable => AppLocalizations.of(
            context,
          )!.mapRouteProviderUnavailable,
          _ => AppLocalizations.of(context)!.mapRouteFailed,
        };
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _routePoints = const [];
        _routingStatus = AppLocalizations.of(context)!.mapRouteFailed;
      });
    } finally {
      if (mounted) setState(() => _isRouting = false);
    }
  }

  void _clearConvoyRoute() {
    setState(() {
      _routePoints = const [];
      _routeDestination = null;
      _pendingDestination = null;
      _routingStatus = '';
    });
  }

  void _showPinOptions(ConvoyPin pin) {
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
                    'Markerad av ${pin.userLabel}',
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
                    label: const Text(
                      'Navigera hit',
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
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.local_police, color: Colors.blue),
                title: Text(l10n.convoyHazardPolice),
                onTap: () async {
                  await _controller.addPin(
                    convoyId: widget.convoy.id,
                    position: point,
                    label: l10n.convoyHazardPolice,
                    pinType: 'police',
                  );
                  if (!context.mounted) {
                    return;
                  }
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.construction, color: Colors.orange),
                title: Text(l10n.convoyHazardRoadwork),
                onTap: () async {
                  await _controller.addPin(
                    convoyId: widget.convoy.id,
                    position: point,
                    label: l10n.convoyHazardRoadwork,
                    pinType: 'roadwork',
                  );
                  if (!context.mounted) {
                    return;
                  }
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.car_crash, color: Colors.redAccent),
                title: Text(l10n.convoyHazardAccident),
                onTap: () async {
                  await _controller.addPin(
                    convoyId: widget.convoy.id,
                    position: point,
                    label: l10n.convoyHazardAccident,
                    pinType: 'accident',
                  );
                  if (!context.mounted) {
                    return;
                  }
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.traffic, color: Colors.amber),
                title: Text(l10n.convoyHazardTrafficJam),
                onTap: () async {
                  await _controller.addPin(
                    convoyId: widget.convoy.id,
                    position: point,
                    label: l10n.convoyHazardTrafficJam,
                    pinType: 'traffic_jam',
                  );
                  if (!context.mounted) {
                    return;
                  }
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.speed, color: Colors.deepPurple),
                title: Text(l10n.convoyHazardSpeedCamera),
                onTap: () async {
                  await _controller.addPin(
                    convoyId: widget.convoy.id,
                    position: point,
                    label: l10n.convoyHazardSpeedCamera,
                    pinType: 'speed_camera',
                  );
                  if (!context.mounted) {
                    return;
                  }
                  Navigator.of(context).pop();
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
      _ => Colors.red,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A1628),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0D1B2E),
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text(
            widget.convoy.name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
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
              stream: _controller.watchPins(convoyId: widget.convoy.id),
              builder: (context, pinSnapshot) {
                final allPins = pinSnapshot.data ?? const [];
                final locations = _memberLocations;
                final pins = allPins
                    .where(_isPinActive)
                    .toList(growable: false);
                final center =
                    _myLocation ??
                    (locations.isNotEmpty
                        ? locations.first.position
                        : const LatLng(59.3293, 18.0686));

                return Column(
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: RepaintBoundary(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final h = constraints.maxHeight;
                                    final w = constraints.maxWidth;
                                    final is3D =
                                        _isFollowingMyPosition && _use3DMap;
                                    final matrix = is3D
                                        ? (Matrix4.identity()
                                            ..setEntry(3, 2, 0.001)
                                            ..rotateX(0.65))
                                        : Matrix4.identity();
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
                                              child: FlutterMap(
                                                options: MapOptions(
                                                  initialCenter: center,
                                                  initialZoom: _followZoom,
                                                  initialRotation: 0,
                                                  onTap: (_, point) =>
                                                      _showQuickHazardPicker(
                                                        point,
                                                        l10n,
                                                      ),
                                                  onPositionChanged: (_, hasGesture) {
                                                    if (!hasGesture ||
                                                        !_isFollowingMyPosition) {
                                                      return;
                                                    }
                                                    setState(() {
                                                      _isFollowingMyPosition =
                                                          false;
                                                    });
                                                  },
                                                ),
                                                mapController: _mapController,
                                                children: [
                                                  TileLayer(
                                                    urlTemplate:
                                                        'https://api.mapbox.com/styles/v1/mapbox/dark-v11/tiles/{z}/{x}/{y}@2x?access_token={mapbox_token}',
                                                    additionalOptions: const {
                                                      'mapbox_token':
                                                          'pk.eyJ1Ijoia2ltc2pvZ3JlbjE5ODciLCJhIjoiY21taXQ0dDB3MWJlMzJxczUzc2tvZDN2NyJ9.-eZcy-sIG46WBe_y05rUeQ',
                                                    },
                                                    userAgentPackageName:
                                                        'com.kimtechtool.slowride',
                                                    tileDimension: 512,
                                                    zoomOffset: -1,
                                                  ),
                                                  MarkerLayer(
                                                    markers: [
                                                      // Alert markers
                                                      for (final alert
                                                          in _alerts)
                                                        Marker(
                                                          point: alert.position,
                                                          width: 44,
                                                          height: 52,
                                                          alignment:
                                                              const Alignment(
                                                                0,
                                                                -1,
                                                              ),
                                                          child:
                                                              _ConvoyAlertMarker(
                                                                alert: alert,
                                                              ),
                                                        ),
                                                      for (final member
                                                          in locations)
                                                        Marker(
                                                          point:
                                                              member.position,
                                                          width: 100,
                                                          height: 72,
                                                          child:
                                                              _buildMemberMarker(
                                                                member,
                                                                l10n,
                                                              ),
                                                        ),
                                                      for (final pin in pins)
                                                        Marker(
                                                          point: pin.position,
                                                          width: 90,
                                                          height: 42,
                                                          child: GestureDetector(
                                                            onTap: () =>
                                                                _showPinOptions(
                                                                  pin,
                                                                ),
                                                            child: Column(
                                                              children: [
                                                                Container(
                                                                  padding:
                                                                      const EdgeInsets.symmetric(
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
                                                                            alpha:
                                                                                0.6,
                                                                          ),
                                                                    ),
                                                                  ),
                                                                  child: Text(
                                                                    pin.label,
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                    style: Theme.of(
                                                                      context,
                                                                    ).textTheme.labelSmall,
                                                                  ),
                                                                ),
                                                                Icon(
                                                                  _pinIcon(
                                                                    pin.type,
                                                                  ),
                                                                  color:
                                                                      _pinColor(
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
                                                  // Route polyline
                                                  if (_routePoints.isNotEmpty)
                                                    PolylineLayer(
                                                      polylines: [
                                                        Polyline(
                                                          points: _routePoints,
                                                          color: const Color(
                                                            0xFF3AA8FF,
                                                          ),
                                                          strokeWidth: 5,
                                                          borderColor:
                                                              const Color(
                                                                0xFF0A3D6E,
                                                              ),
                                                          borderStrokeWidth: 2,
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
                          ),
                          // Address search bar (replaces hint overlay)
                          Positioned(
                            left: 16,
                            top: 16,
                            right: 72,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  height: 44,
                                  child: TextField(
                                    controller: _addressSearchController,
                                    focusNode: _searchFocus,
                                    textInputAction: TextInputAction.search,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                    onChanged: _onSearchChanged,
                                    onSubmitted: (q) {
                                      setState(
                                        () => _showSuggestions = false,
                                      );
                                      _searchAddress(q);
                                    },
                                    decoration: InputDecoration(
                                      hintText: l10n.mapAddressFieldHint,
                                      hintStyle: const TextStyle(
                                        color: Colors.white38,
                                        fontSize: 13,
                                      ),
                                      filled: true,
                                      fillColor: const Color(0xDD071739),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 0,
                                          ),
                                      prefixIcon: const Icon(
                                        Icons.search,
                                        color: Colors.white54,
                                        size: 20,
                                      ),
                                      suffixIcon:
                                          _addressSearchController
                                                  .text
                                                  .isNotEmpty
                                              ? IconButton(
                                                  icon: const Icon(
                                                    Icons.close,
                                                    size: 18,
                                                    color: Colors.white54,
                                                  ),
                                                  onPressed: () {
                                                    _addressSearchController
                                                        .clear();
                                                    setState(() {
                                                      _suggestions = [];
                                                      _showSuggestions =
                                                          false;
                                                    });
                                                  },
                                                )
                                              : null,
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        borderSide: const BorderSide(
                                          color: Color(0x553AA8FF),
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        borderSide: const BorderSide(
                                          color: Color(0x553AA8FF),
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        borderSide: const BorderSide(
                                          color: Color(0xFF3AA8FF),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (_showSuggestions &&
                                    _suggestions.isNotEmpty)
                                  Container(
                                    margin: const EdgeInsets.only(top: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xF0071739),
                                      borderRadius:
                                          BorderRadius.circular(10),
                                      border: Border.all(
                                        color: const Color(0x553AA8FF),
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(10),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: _suggestions.map((s) {
                                          final parts = (s['display_name']
                                                      as String? ??
                                                  '')
                                              .split(',');
                                          final title =
                                              parts.first.trim();
                                          final subtitle = parts
                                              .skip(1)
                                              .take(3)
                                              .map((e) => e.trim())
                                              .join(', ');
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
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          title,
                                                          style: const TextStyle(
                                                            color:
                                                                Colors.white,
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
                                                            style:
                                                                const TextStyle(
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
                              ],
                            ),
                          ),
                          // Proximity alert banner
                          if (_nearbyAlert != null && _myLocation != null)
                            Positioned(
                              top: 80,
                              left: 0,
                              right: 0,
                              child: Material(
                                color: Colors.transparent,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Color(0xEEF57F17),
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Color(0x66FFCC02),
                                        width: 1,
                                      ),
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
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () =>
                                            setState(() => _nearbyAlert = null),
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
                          // Report alert button
                          Positioned(
                            right: 24,
                            top: 90,
                            child: GestureDetector(
                              onTap: _showReportAlertSheet,
                              child: Container(
                                width: 44,
                                height: 44,
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
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                          // Route status bar
                          if (_routeDestination != null || _isRouting)
                            Positioned(
                              left: 16,
                              right: 16,
                              bottom: 24,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xEE0D1B2E),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0x553AA8FF),
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black45,
                                      blurRadius: 12,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    if (_isRouting)
                                      const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFF3AA8FF),
                                        ),
                                      )
                                    else
                                      const Icon(
                                        Icons.alt_route,
                                        color: Color(0xFF3AA8FF),
                                        size: 18,
                                      ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _routingStatus,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: _clearConvoyRoute,
                                      child: const Icon(
                                        Icons.close_rounded,
                                        color: Colors.white38,
                                        size: 20,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          // Buttons overlay
                          Positioned(
                            right: 24,
                            bottom: _routeDestination != null || _isRouting
                                ? 90
                                : 24,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
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
                                const SizedBox(height: 8),
                                FloatingActionButton.small(
                                  heroTag: 'fit_all',
                                  tooltip: AppLocalizations.of(
                                    context,
                                  )!.convoyShowAll,
                                  backgroundColor: const Color(0xFF1E3A5F),
                                  onPressed: () => _fitAllMembers(locations),
                                  child: const Icon(
                                    Icons.people_alt_outlined,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                FloatingActionButton.small(
                                  heroTag: 'recenter',
                                  tooltip: l10n.convoyRecenterTooltip,
                                  backgroundColor: _isFollowingMyPosition
                                      ? const Color(0xFF1E6BFF)
                                      : const Color(0xFF1E3A5F),
                                  onPressed: () {
                                    final me = _myLocation;
                                    if (me == null) return;
                                    // Snap ticker to current position so
                                    // the transition starts from here.
                                    _curLat = _tgtLat = me.latitude;
                                    _curLng = _tgtLng = me.longitude;
                                    _curHdg = _tgtHdg = _myHeading;
                                    _camInitialized = true;
                                    setState(
                                      () => _isFollowingMyPosition = true,
                                    );
                                    final zoom = _use3DMap ? 18.5 : _followZoom;
                                    _mapController.moveAndRotate(
                                      me,
                                      zoom,
                                      _use3DMap ? -_myHeading : 0,
                                    );
                                  },
                                  child: Icon(
                                    _isFollowingMyPosition
                                        ? Icons.my_location
                                        : Icons.location_searching,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Members strip
                    if (locations.isNotEmpty)
                      Container(
                        height: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0A1628),
                          border: Border(
                            top: BorderSide(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                        ),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          itemCount: locations.length,
                          itemBuilder: (ctx, i) {
                            final m = locations[i];
                            final isMe = m.userId == _myUserId;
                            final stale = _isMemberStale(m);
                            final color = isMe
                                ? const Color(0xFF1E6BFF)
                                : _memberColor(m.userId);
                            final minsAgo = DateTime.now()
                                .difference(m.updatedAt)
                                .inMinutes;
                            return GestureDetector(
                              onTap: () =>
                                  _mapController.move(m.position, _followZoom),
                              child: Padding(
                                padding: const EdgeInsets.only(right: 16),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Opacity(
                                      opacity: stale ? 0.4 : 1.0,
                                      child: Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: color,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: isMe ? 2.5 : 1.5,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: color.withValues(
                                                alpha: 0.4,
                                              ),
                                              blurRadius: 6,
                                            ),
                                          ],
                                        ),
                                        child: Center(
                                          child: isMe
                                              ? const Icon(
                                                  Icons.navigation,
                                                  color: Colors.white,
                                                  size: 16,
                                                )
                                              : Text(
                                                  m.userLabel.isNotEmpty
                                                      ? m.userLabel[0]
                                                            .toUpperCase()
                                                      : '?',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      stale
                                          ? l10n.convoyMemberStaleTime(minsAgo)
                                          : (isMe
                                                ? l10n.convoyMemberMe
                                                : m.userLabel.split(' ').first),
                                      style: TextStyle(
                                        color: stale
                                            ? Colors.white30
                                            : Colors.white70,
                                        fontSize: 9,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
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
                    stream: _controller.watchMessages(
                      convoyId: widget.convoy.id,
                    ),
                    builder: (context, snapshot) {
                      final messages = snapshot.data ?? const [];
                      if (messages.isEmpty) {
                        return Center(
                          child: Text(
                            l10n.convoyChatEmpty,
                            style: const TextStyle(color: Colors.white54),
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          return Container(
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
                            onSubmitted: (_) => _sendMessage(),
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
                          onPressed: _sendMessage,
                          child: Text(l10n.convoyChatSend),
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

// ── Alert marker (replicates MapWidget's _AlertMarker) ───────────────────────

class _ConvoyAlertMarker extends StatelessWidget {
  const _ConvoyAlertMarker({required this.alert});
  final AlertModel alert;

  Color _bgColor(AlertType t) => switch (t) {
    AlertType.police => const Color(0xFF1565C0),
    AlertType.roadwork => const Color(0xFFE65100),
    AlertType.accident => const Color(0xFFC62828),
    AlertType.trafficJam => const Color(0xFFF57F17),
    AlertType.speedCamera => const Color(0xFF6A1B9A),
    AlertType.narrowRoad => const Color(0xFF00695C),
    AlertType.steepHill => const Color(0xFF37474F),
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
