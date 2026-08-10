import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:slowride/models/alert_model.dart';

class AppleMapWidget extends StatefulWidget {
  const AppleMapWidget({
    super.key,
    required this.locationNotifier,
    required this.headingNotifier,
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
  Timer? _syncDebounce;
  String? _lastPayloadJson;

  @override
  void initState() {
    super.initState();
    widget.locationNotifier.addListener(_scheduleSync);
    widget.headingNotifier.addListener(_scheduleSync);
  }

  @override
  void didUpdateWidget(covariant AppleMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.locationNotifier != widget.locationNotifier) {
      oldWidget.locationNotifier.removeListener(_scheduleSync);
      widget.locationNotifier.addListener(_scheduleSync);
    }
    if (oldWidget.headingNotifier != widget.headingNotifier) {
      oldWidget.headingNotifier.removeListener(_scheduleSync);
      widget.headingNotifier.addListener(_scheduleSync);
    }
    _scheduleSync();
  }

  @override
  void dispose() {
    widget.locationNotifier.removeListener(_scheduleSync);
    widget.headingNotifier.removeListener(_scheduleSync);
    _syncDebounce?.cancel();
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  void _onPlatformViewCreated(int id) {
    _channel = MethodChannel('cruizx/mapkit_view_$id');
    _channel?.setMethodCallHandler(_handleMethodCall);
    _scheduleSync(immediate: true);
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

  void _scheduleSync({bool immediate = false}) {
    if (_channel == null) return;
    if (immediate) {
      _syncDebounce?.cancel();
      unawaited(_syncState());
      return;
    }

    _syncDebounce?.cancel();
    _syncDebounce = Timer(
      const Duration(milliseconds: 90),
      () => unawaited(_syncState()),
    );
  }

  Future<void> _syncState() async {
    final channel = _channel;
    if (channel == null) return;

    final payload = <String, Object?>{
      'location': _encodePoint(widget.locationNotifier.value),
      'heading': widget.headingNotifier.value,
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

  Map<String, double>? _encodePoint(LatLng? point) {
    if (point == null) return null;
    return {
      'latitude': point.latitude,
      'longitude': point.longitude,
    };
  }

  double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value');
  }

  @override
  Widget build(BuildContext context) {
    return UiKitView(
      viewType: 'cruizx/mapkit-view',
      onPlatformViewCreated: _onPlatformViewCreated,
      creationParams: const <String, Object?>{},
      creationParamsCodec: const StandardMessageCodec(),
    );
  }
}
