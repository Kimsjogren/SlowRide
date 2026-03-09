import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:slowride/features/convoy/convoy_controller.dart';
import 'package:slowride/services/auth_service.dart';
import 'package:slowride/services/supabase_service.dart';
import 'package:slowride/l10n/app_localizations.dart';
import 'package:slowride/models/convoy_member_location.dart';
import 'package:slowride/models/convoy_message.dart';
import 'package:slowride/models/convoy_model.dart';
import 'package:slowride/models/convoy_pin.dart';
import 'package:slowride/services/navigation_request_service.dart';

class ConvoyRoomScreen extends StatefulWidget {
  const ConvoyRoomScreen({required this.convoy, super.key});

  final ConvoyModel convoy;

  @override
  State<ConvoyRoomScreen> createState() => _ConvoyRoomScreenState();
}

class _ConvoyRoomScreenState extends State<ConvoyRoomScreen> {
  final ConvoyController _controller = ConvoyController();
  final TextEditingController _messageController = TextEditingController();
  final MapController _mapController = MapController();

  StreamSubscription<Position>? _positionSubscription;
  Timer? _pinRefreshTimer;
  Timer? _locationPollTimer;
  List<ConvoyMemberLocation> _memberLocations = [];
  LatLng? _myLocation;
  double _myHeading = 0;
  bool _isFollowingMyPosition = true;
  String? _myUserId;

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
    _myUserId = AuthService.instance.userId.value;
    // Delay GPS request until after first frame (avoids InheritedWidget issue)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startLocationSync();
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
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 5,
          ),
        ).listen((position) async {
          final point = LatLng(position.latitude, position.longitude);
          final heading = position.heading >= 0 ? position.heading : _myHeading;

          if (mounted) {
            setState(() {
              _myLocation = point;
              _myHeading = heading;
            });

            if (_isFollowingMyPosition) {
              _mapController.move(point, _followZoom);
              _mapController.rotate(-heading);
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
    _messageController.dispose();
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

  Color _memberColor(String userId) {
    final idx =
        userId.codeUnits.fold(0, (a, b) => a + b) % _avatarPalette.length;
    return _avatarPalette[idx];
  }

  bool _isMemberStale(ConvoyMemberLocation m) {
    return DateTime.now().difference(m.updatedAt) > const Duration(minutes: 5);
  }

  Widget _buildMemberMarker(ConvoyMemberLocation member) {
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
              isMe ? 'Jag' : member.userLabel,
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
    final points = [
      ...locations.map((m) => m.position),
      if (_myLocation != null) _myLocation!,
    ];
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

  void _navigateToPin(ConvoyPin pin) {
    // Request navigation via the app's own routing engine,
    // then pop back to AppShell which will switch to the map tab.
    NavigationRequestService.instance.requestNavigation(pin.position);
    Navigator.of(context).popUntil((route) => route.isFirst);
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
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _navigateToPin(pin);
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
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: FlutterMap(
                                options: MapOptions(
                                  initialCenter: center,
                                  initialZoom: _followZoom,
                                  initialRotation: -_myHeading,
                                  onTap: (_, point) =>
                                      _showQuickHazardPicker(point, l10n),
                                  onPositionChanged: (_, hasGesture) {
                                    if (!hasGesture ||
                                        !_isFollowingMyPosition) {
                                      return;
                                    }
                                    setState(() {
                                      _isFollowingMyPosition = false;
                                    });
                                  },
                                ),
                                mapController: _mapController,
                                children: [
                                  TileLayer(
                                    urlTemplate:
                                        'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray_Base/MapServer/tile/{z}/{y}/{x}',
                                    userAgentPackageName:
                                        'com.kimtechtool.slowride',
                                  ),
                                  MarkerLayer(
                                    markers: [
                                      for (final member in locations)
                                        Marker(
                                          point: member.position,
                                          width: 100,
                                          height: 72,
                                          child: _buildMemberMarker(member),
                                        ),
                                      for (final pin in pins)
                                        Marker(
                                          point: pin.position,
                                          width: 90,
                                          height: 42,
                                          child: GestureDetector(
                                            onTap: () => _showPinOptions(pin),
                                            child: Column(
                                              children: [
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
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
                                                      color: _pinColor(
                                                        pin.type,
                                                      ).withValues(alpha: 0.6),
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
                                                  _pinIcon(pin.type),
                                                  color: _pinColor(pin.type),
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
                                        '© OpenStreetMap contributors',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Hint overlay
                          Positioned(
                            left: 24,
                            top: 24,
                            right: 80,
                            child: IgnorePointer(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF0A1628,
                                  ).withValues(alpha: 0.72),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  l10n.convoyMapHint,
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Buttons overlay
                          Positioned(
                            right: 24,
                            bottom: 24,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                FloatingActionButton.small(
                                  heroTag: 'fit_all',
                                  tooltip: 'Visa alla',
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
                                    setState(
                                      () => _isFollowingMyPosition = true,
                                    );
                                    _mapController.move(me, _followZoom);
                                    _mapController.rotate(-_myHeading);
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
                                          ? '${minsAgo}m sedan'
                                          : (isMe
                                                ? 'Jag'
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
