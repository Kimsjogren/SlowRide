import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:slowride/models/alert_model.dart';
import 'package:slowride/models/convoy_member_location.dart';
import 'package:slowride/models/convoy_pin.dart';
import 'package:slowride/services/user_preferences_service.dart';
import 'package:slowride/widgets/user_location_marker.dart';

class AppleConvoyMapWidget extends StatefulWidget {
  const AppleConvoyMapWidget({
    super.key,
    required this.locationNotifier,
    required this.headingNotifier,
    required this.markerStyle,
    required this.members,
    required this.pins,
    required this.viewportCommandId,
    this.currentUserId,
    this.destination,
    this.routePoints = const [],
    this.alerts = const [],
    this.meetupPosition,
    this.meetupLabel,
    this.viewportCommandPoints = const [],
    this.onTap,
    this.onUserPanned,
    this.onUserInteractionEnded,
    this.onMemberTap,
    this.onPinTap,
    this.onMeetupTap,
    this.followUser = false,
    this.use3D = true,
    this.darkMode = false,
    this.satellite = false,
    this.nextManeuverDistanceMeters,
    this.nextManeuverSign,
  });

  final ValueNotifier<LatLng?> locationNotifier;
  final ValueNotifier<double> headingNotifier;
  final MapMarkerStyle markerStyle;
  final List<ConvoyMemberLocation> members;
  final List<ConvoyPin> pins;
  final int viewportCommandId;
  final String? currentUserId;
  final LatLng? destination;
  final List<LatLng> routePoints;
  final List<AlertModel> alerts;
  final LatLng? meetupPosition;
  final String? meetupLabel;
  final List<LatLng> viewportCommandPoints;
  final ValueChanged<LatLng>? onTap;
  final VoidCallback? onUserPanned;
  final VoidCallback? onUserInteractionEnded;
  final ValueChanged<String>? onMemberTap;
  final ValueChanged<String>? onPinTap;
  final VoidCallback? onMeetupTap;
  final bool followUser;
  final bool use3D;
  final bool darkMode;
  final bool satellite;
  final double? nextManeuverDistanceMeters;
  final int? nextManeuverSign;

  @override
  State<AppleConvoyMapWidget> createState() => _AppleConvoyMapWidgetState();
}

class _AppleConvoyMapWidgetState extends State<AppleConvoyMapWidget> {
  static const double _k3DArrowAlignmentY = 0.30;
  MethodChannel? _channel;
  Timer? _stateSyncDebounce;
  Timer? _headingSyncDebounce;
  String? _lastPayloadJson;
  double? _lastHeading;

  @override
  void initState() {
    super.initState();
    widget.locationNotifier.addListener(_scheduleStateSync);
    widget.headingNotifier.addListener(_scheduleHeadingSync);
  }

  @override
  void didUpdateWidget(covariant AppleConvoyMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final followChanged = oldWidget.followUser != widget.followUser;
    if (oldWidget.locationNotifier != widget.locationNotifier) {
      oldWidget.locationNotifier.removeListener(_scheduleStateSync);
      widget.locationNotifier.addListener(_scheduleStateSync);
    }
    if (oldWidget.headingNotifier != widget.headingNotifier) {
      oldWidget.headingNotifier.removeListener(_scheduleHeadingSync);
      widget.headingNotifier.addListener(_scheduleHeadingSync);
    }
    _scheduleStateSync(immediate: followChanged);
    _scheduleHeadingSync(immediate: followChanged);
  }

  @override
  void dispose() {
    widget.locationNotifier.removeListener(_scheduleStateSync);
    widget.headingNotifier.removeListener(_scheduleHeadingSync);
    _stateSyncDebounce?.cancel();
    _headingSyncDebounce?.cancel();
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
      case 'userInteractionEnded':
        widget.onUserInteractionEnded?.call();
        break;
      case 'memberTapped':
        final args = Map<String, dynamic>.from(
          (call.arguments as Map?) ?? const <String, dynamic>{},
        );
        final userId = args['userId']?.toString();
        if (userId != null && userId.isNotEmpty) {
          widget.onMemberTap?.call(userId);
        }
        break;
      case 'pinTapped':
        final args = Map<String, dynamic>.from(
          (call.arguments as Map?) ?? const <String, dynamic>{},
        );
        final pinId = args['pinId']?.toString();
        if (pinId != null && pinId.isNotEmpty) {
          widget.onPinTap?.call(pinId);
        }
        break;
      case 'meetupTapped':
        widget.onMeetupTap?.call();
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
      const Duration(milliseconds: 24),
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
          .map(_encodePoint)
          .toList(growable: false),
      'alerts': widget.alerts.map(_encodeAlert).toList(growable: false),
      'meetup': widget.meetupPosition == null
          ? null
          : {
              'position': _encodePoint(widget.meetupPosition),
              'label': widget.meetupLabel ?? '',
            },
      'convoyMembers': widget.members
          .map(_encodeMember)
          .toList(growable: false),
      'convoyPins': widget.pins.map(_encodePin).toList(growable: false),
      'currentUserId': widget.currentUserId,
      'hideUserMarkerWhenFollowing': true,
      'followUser': widget.followUser,
      'use3D': widget.use3D,
      'darkMode': widget.darkMode,
      'satellite': widget.satellite,
      'nextManeuverDistanceMeters': widget.nextManeuverDistanceMeters,
      'nextManeuverSign': widget.nextManeuverSign,
      'viewportCommand': widget.viewportCommandPoints.isEmpty
          ? null
          : {
              'id': widget.viewportCommandId,
              'type': 'fit_points',
              'points': widget.viewportCommandPoints
                  .map(_encodePoint)
                  .toList(growable: false),
            },
    };

    final payloadJson = jsonEncode(payload);
    if (_lastPayloadJson == payloadJson) return;

    try {
      await channel.invokeMethod<void>('setState', payload);
      _lastPayloadJson = payloadJson;
    } on MissingPluginException {
      // Native view only exists on iOS.
    } catch (error, stackTrace) {
      debugPrint('AppleConvoyMapWidget sync failed: $error\n$stackTrace');
    }
  }

  Future<void> _syncHeading() async {
    final channel = _channel;
    if (channel == null) return;

    final heading = widget.headingNotifier.value;
    if (_lastHeading == heading) return;

    try {
      await channel.invokeMethod<void>('setHeading', <String, Object?>{
        'heading': heading,
      });
      _lastHeading = heading;
    } on MissingPluginException {
      // Native view only exists on iOS.
    } catch (error, stackTrace) {
      debugPrint(
        'AppleConvoyMapWidget heading sync failed: $error\n$stackTrace',
      );
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

  Map<String, Object?> _encodeAlert(AlertModel alert) {
    return {
      'id': alert.id,
      'position': _encodePoint(alert.position),
      'typeKey': alert.type.key,
      'emoji': alert.type.emoji,
      'description': alert.description,
    };
  }

  Map<String, Object?> _encodeMember(ConvoyMemberLocation member) {
    final style = _parseMarkerStyle(member.vehicleStyle);
    return {
      'userId': member.userId,
      'userLabel': member.userLabel,
      'position': _encodePoint(member.position),
      'markerStyle': _encodeMarkerStyle(style),
    };
  }

  Map<String, Object?> _encodePin(ConvoyPin pin) {
    return {
      'pinId': pin.id,
      'label': pin.label,
      'type': pin.type,
      'position': _encodePoint(pin.position),
    };
  }

  MapMarkerStyle _parseMarkerStyle(String rawStyle) {
    for (final style in MapMarkerStyle.values) {
      if (style.name == rawStyle) {
        return style;
      }
    }
    return MapMarkerStyle.navigation;
  }

  double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value');
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        UiKitView(
          viewType: 'cruizx/mapkit-view',
          gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
            Factory<EagerGestureRecognizer>(() => EagerGestureRecognizer()),
          },
          onPlatformViewCreated: _onPlatformViewCreated,
        ),
        if (widget.followUser)
          IgnorePointer(
            child: Align(
              alignment: widget.use3D
                  ? const Alignment(0, _k3DArrowAlignmentY)
                  : Alignment.center,
              child: UserLocationMarker(
                headingNotifier: widget.headingNotifier,
                lockNorthUp: false,
                size: 30,
              ),
            ),
          ),
      ],
    );
  }
}
