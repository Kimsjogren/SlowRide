import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:slowride/features/convoy/convoy_controller.dart';
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

class _ConvoyRoomScreenState extends State<ConvoyRoomScreen> {
  final ConvoyController _controller = ConvoyController();
  final TextEditingController _messageController = TextEditingController();
  final MapController _mapController = MapController();

  StreamSubscription<Position>? _positionSubscription;
  Timer? _pinRefreshTimer;
  LatLng? _myLocation;
  double _myHeading = 0;
  bool _isFollowingMyPosition = true;

  static const double _followZoom = 16;
  static const Duration _pinTtl = Duration(minutes: 30);

  @override
  void initState() {
    super.initState();
    _startLocationSync();
    _pinRefreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) {
        return;
      }
      setState(() {});
    });
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
            StreamBuilder<List<ConvoyMemberLocation>>(
              stream: _controller.watchMemberLocations(
                convoyId: widget.convoy.id,
              ),
              builder: (context, locationSnapshot) {
                final locations = locationSnapshot.data ?? const [];
                return StreamBuilder<List<ConvoyPin>>(
                  stream: _controller.watchPins(convoyId: widget.convoy.id),
                  builder: (context, pinSnapshot) {
                    final allPins = pinSnapshot.data ?? const [];
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
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              l10n.convoyMapHint,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
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
                                          width: 90,
                                          height: 42,
                                          child: Column(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primaryContainer,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  member.userLabel,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: Theme.of(
                                                    context,
                                                  ).textTheme.labelSmall,
                                                ),
                                              ),
                                              const Icon(
                                                Icons.navigation,
                                                color: Colors.blue,
                                                size: 18,
                                              ),
                                            ],
                                          ),
                                        ),
                                      for (final pin in pins)
                                        Marker(
                                          point: pin.position,
                                          width: 90,
                                          height: 42,
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
                                                      BorderRadius.circular(8),
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
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(0, 0, 16, 16),
                          child: Align(
                            alignment: Alignment.bottomRight,
                            child: FloatingActionButton.small(
                              onPressed: () {
                                final me = _myLocation;
                                if (me == null) {
                                  return;
                                }

                                setState(() {
                                  _isFollowingMyPosition = true;
                                });
                                _mapController.move(me, _followZoom);
                                _mapController.rotate(-_myHeading);
                              },
                              tooltip: l10n.convoyRecenterTooltip,
                              child: Icon(
                                _isFollowingMyPosition
                                    ? Icons.my_location
                                    : Icons.location_searching,
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
