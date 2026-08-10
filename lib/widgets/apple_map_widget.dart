import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:slowride/models/alert_model.dart';
import 'package:slowride/services/user_preferences_service.dart';
import 'package:slowride/widgets/user_location_marker.dart';

class AppleMapWidget extends StatefulWidget {
  const AppleMapWidget({
    super.key,
    required this.locationNotifier,
    required this.headingNotifier,
    required this.markerStyle,
    this.destination,
    this.routePoints = const [],
    this.alerts = const [],
    this.studdedTireBanZones = const [],
    this.chargingStations = const [],
    this.onTap,
    this.followUser = false,
    this.onUserPanned,
    this.use3D = true,
    this.darkMode = false,
    this.nextManeuverDistanceMeters,
    this.nextManeuverSign,
  });

  final ValueNotifier<LatLng?> locationNotifier;
  final ValueNotifier<double> headingNotifier;
  final MapMarkerStyle markerStyle;
  final LatLng? destination;
  final List<LatLng> routePoints;
  final List<AlertModel> alerts;
  final List<List<LatLng>> studdedTireBanZones;
  final List<LatLng> chargingStations;
  final ValueChanged<LatLng>? onTap;
  final bool followUser;
  final VoidCallback? onUserPanned;
  final bool use3D;
  final bool darkMode;
  final double? nextManeuverDistanceMeters;
  final int? nextManeuverSign;

  @override
  State<AppleMapWidget> createState() => _AppleMapWidgetState();
}

class _AppleMapWidgetState extends State<AppleMapWidget> {
  MethodChannel? _channel;
  Timer? _stateSyncDebounce;
  Timer? _headingSyncDebounce;
  Timer? _userPanCooldownTimer;
  String? _lastPayloadJson;
  double? _lastHeading;
  bool _userPanning = false;

  @override
  void initState() {
    super.initState();
    widget.locationNotifier.addListener(_scheduleStateSync);
    widget.headingNotifier.addListener(_scheduleHeadingSync);
  }

  @override
  void didUpdateWidget(covariant AppleMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.locationNotifier != widget.locationNotifier) {
      oldWidget.locationNotifier.removeListener(_scheduleStateSync);
      widget.locationNotifier.addListener(_scheduleStateSync);
    }
    if (oldWidget.headingNotifier != widget.headingNotifier) {
      oldWidget.headingNotifier.removeListener(_scheduleHeadingSync);
      widget.headingNotifier.addListener(_scheduleHeadingSync);
    }
    _scheduleStateSync();
    _scheduleHeadingSync();
  }

  @override
  void dispose() {
    widget.locationNotifier.removeListener(_scheduleStateSync);
    widget.headingNotifier.removeListener(_scheduleHeadingSync);
    _stateSyncDebounce?.cancel();
    _headingSyncDebounce?.cancel();
    _userPanCooldownTimer?.cancel();
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  void _onPlatformViewCreated(int id) {
    _channel = MethodChannel('cruizx/mapkit_view_$id');
    _channel?.setMethodCallHandler(_handleMethodCall);
    _scheduleStateSync(immediate: true);
    _scheduleHeadingSync(immediate: true);
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'mapTapped':
        final args = Map<String, dynamic>.from(
          (call.arguments as Map?) ?? const <String, dynamic>{},
        );
        final lat = _asDouble(args['latitude']);
        final lon = _asDouble(args['longitude']);
        if (lat != null && lon != null) {
          widget.onTap?.call(LatLng(lat, lon));
        }
        break;
      case 'userPanned':
        widget.onUserPanned?.call();
        break;
    }
  }

  void _scheduleStateSync({bool immediate = false}) {
    if (_channel == null) return;
    if (immediate) {
      _stateSyncDebounce?.cancel();
      unawaited(_syncState());
      return;
    }

    _stateSyncDebounce?.cancel();
    _stateSyncDebounce = Timer(
      const Duration(milliseconds: 90),
      () => unawaited(_syncState()),
    );
  }

  void _scheduleHeadingSync({bool immediate = false}) {
    if (_channel == null) return;
    if (immediate) {
      _headingSyncDebounce?.cancel();
      unawaited(_syncHeading());
      return;
    }

    _headingSyncDebounce?.cancel();
    _headingSyncDebounce = Timer(
      const Duration(milliseconds: 24),
      () => unawaited(_syncHeading()),
    );
  }

  Future<void> _syncState() async {
    final channel = _channel;
    if (channel == null) return;

    final payload = <String, Object?>{
      'location': _encodePoint(widget.locationNotifier.value),
      'markerStyle': _encodeMarkerStyle(widget.markerStyle),
      'destination': _encodePoint(widget.destination),
      'routePoints': widget.routePoints
          .map(
            (point) => {
              'latitude': point.latitude,
              'longitude': point.longitude,
            },
          )
          .toList(growable: false),
      'followUser': widget.followUser,
      'use3D': widget.use3D,
      'darkMode': widget.darkMode,
      'nextManeuverDistanceMeters': widget.nextManeuverDistanceMeters,
      'nextManeuverSign': widget.nextManeuverSign,
    };

    final payloadJson = jsonEncode(payload);
    if (_lastPayloadJson == payloadJson) return;

    try {
      await channel.invokeMethod<void>('setState', payload);
      _lastPayloadJson = payloadJson;
    } on MissingPluginException {
      // The native view only exists on iOS.
    } catch (error, stackTrace) {
      debugPrint('AppleMapWidget sync failed: $error\n$stackTrace');
    }
  }

  Future<void> _syncHeading() async {
    final channel = _channel;
    if (channel == null) return;
    if (!widget.followUser) {
      _lastHeading = null;
      return;
    }

    final heading = widget.headingNotifier.value;
    if (_lastHeading == heading) return;

    try {
      await channel.invokeMethod<void>('setHeading', <String, Object?>{
        'heading': heading,
      });
      _lastHeading = heading;
    } on MissingPluginException {
      // The native view only exists on iOS.
    } catch (error, stackTrace) {
      debugPrint('AppleMapWidget heading sync failed: $error\n$stackTrace');
    }
  }

  Map<String, double>? _encodePoint(LatLng? point) {
    if (point == null) return null;
    return {
      'latitude': point.latitude,
      'longitude': point.longitude,
    };
  }

  Map<String, Object?> _encodeMarkerStyle(MapMarkerStyle style) {
    final option = UserLocationMarker.optionFor(style);
    return {
      'styleName': style.name,
      'resolvedStyleName': option.style.name,
      'assetPath': option.assetPath,
      'rotatesWithHeading': option.rotatesWithHeading,
      'tintArgb': option.tint?.toARGB32(),
      'iconName': switch (option.style) {
        MapMarkerStyle.navigation => 'navigation',
        MapMarkerStyle.compass => 'compass',
        MapMarkerStyle.triangle => 'triangle',
        MapMarkerStyle.dot => 'flatArrow',
        _ => null,
      },
    };
  }

  double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value');
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) {
        if (widget.followUser && !_userPanning) {
          _userPanning = true;
          widget.onUserPanned?.call();
          _userPanCooldownTimer?.cancel();
          _userPanCooldownTimer = Timer(const Duration(milliseconds: 900), () {
            if (mounted) {
              _userPanning = false;
            }
          });
        }
      },
      child: UiKitView(
        viewType: 'cruizx/mapkit-view',
        gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
          Factory<EagerGestureRecognizer>(() => EagerGestureRecognizer()),
        },
        onPlatformViewCreated: _onPlatformViewCreated,
        creationParams: const <String, Object?>{},
        creationParamsCodec: const StandardMessageCodec(),
      ),
    );
  }
}
