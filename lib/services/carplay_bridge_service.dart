import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:slowride/services/destination_history_service.dart';
import 'package:slowride/services/favorite_places_service.dart';
import 'package:slowride/services/navigation_request_service.dart';

class CarPlayBridgeService {
  CarPlayBridgeService._();

  static final CarPlayBridgeService instance = CarPlayBridgeService._();
  static const MethodChannel _channel = MethodChannel('cruizx/carplay');
  static const Duration _navigationSyncMinInterval = Duration(
    milliseconds: 300,
  );
  final ValueNotifier<bool> isConnected = ValueNotifier<bool>(false);
  final ValueNotifier<bool> companionMode = ValueNotifier<bool>(false);

  Future<void>? _initializeFuture;
  bool _listenersAttached = false;
  String? _lastNavigationPayloadJson;
  String? _lastRouteGeometryPayloadJson;
  String? _lastConvoyPayloadJson;
  DateTime _lastNavigationSyncAt = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _navigationSyncTimer;
  Map<String, Object?>? _pendingNavigationPayload;
  bool _navigationActive = false;

  Future<void> initialize() {
    return _initializeFuture ??= _initialize();
  }

  Future<void> _initialize() async {
    await FavoritePlacesService.instance.initialize();
    await DestinationHistoryService.instance.initialize();

    _channel.setMethodCallHandler(_handleMethodCall);
    try {
      isConnected.value =
          await _channel.invokeMethod<bool>('getConnectionState') ?? false;
    } on MissingPluginException {
      isConnected.value = false;
    }
    _refreshCompanionMode();

    if (!_listenersAttached) {
      FavoritePlacesService.instance.places.addListener(_onStateChanged);
      DestinationHistoryService.instance.entries.addListener(_onStateChanged);
      _listenersAttached = true;
    }

    await syncState();
  }

  Future<void> syncState() async {
    final payload = <String, Object?>{
      'favorites': FavoritePlacesService.instance.places.value
          .map(
            (place) => <String, Object?>{
              'id': place.id,
              'title': place.label,
              'subtitle': place.address,
              'latitude': place.lat,
              'longitude': place.lon,
              'icon': place.icon,
            },
          )
          .toList(growable: false),
      'recents': DestinationHistoryService.instance.entries.value
          .map(
            (entry) => <String, Object?>{
              'id': entry.id,
              'title': entry.label,
              'subtitle': entry.address,
              'latitude': entry.lat,
              'longitude': entry.lon,
              'updatedAt': entry.updatedAt.toIso8601String(),
            },
          )
          .toList(growable: false),
    };

    try {
      await _channel.invokeMethod<void>('syncState', payload);
    } on MissingPluginException {
      // CarPlay bridge is only available on iOS when the native side is loaded.
    } catch (error, stackTrace) {
      debugPrint('CarPlay sync failed: $error\n$stackTrace');
    }
  }

  Future<void> updateNavigationState({
    required bool hasRoute,
    required bool isNavigating,
    required LatLng? currentLocation,
    required double headingDegrees,
    required double currentSpeed,
    required double? roadSpeedLimit,
    required double? vehicleSpeedLimit,
    required String speedUnitLabel,
    required LatLng? destination,
    required String destinationLabel,
    required String destinationAddress,
    required double? totalDistanceMeters,
    required double? remainingDistanceMeters,
    required double? remainingDurationSeconds,
    required String nextManeuverText,
    required String currentStreetName,
    required List<Map<String, Object?>> upcomingManeuvers,
  }) async {
    _navigationActive = isNavigating;
    _refreshCompanionMode();
    final payload = <String, Object?>{
      'hasRoute': hasRoute,
      'isNavigating': isNavigating,
      'currentLocation': currentLocation == null
          ? null
          : <String, double>{
              'latitude': currentLocation.latitude,
              'longitude': currentLocation.longitude,
            },
      'headingDegrees': headingDegrees,
      'currentSpeed': currentSpeed,
      'roadSpeedLimit': roadSpeedLimit,
      'vehicleSpeedLimit': vehicleSpeedLimit,
      'speedUnitLabel': speedUnitLabel,
      'destination': destination == null
          ? null
          : <String, Object?>{
              'latitude': destination.latitude,
              'longitude': destination.longitude,
              'title': destinationLabel,
              'subtitle': destinationAddress,
            },
      'totalDistanceMeters': totalDistanceMeters,
      'remainingDistanceMeters': remainingDistanceMeters,
      'remainingDurationSeconds': remainingDurationSeconds,
      'nextManeuverText': nextManeuverText.trim(),
      'currentStreetName': currentStreetName.trim(),
      'upcomingManeuvers': upcomingManeuvers,
    };

    final payloadJson = jsonEncode(payload);
    if (_lastNavigationPayloadJson == payloadJson) {
      return;
    }

    final now = DateTime.now();
    if (now.difference(_lastNavigationSyncAt) >= _navigationSyncMinInterval) {
      await _sendNavigationPayload(payload, payloadJson: payloadJson);
      return;
    }

    _pendingNavigationPayload = payload;
    _navigationSyncTimer?.cancel();
    final wait =
        _navigationSyncMinInterval - now.difference(_lastNavigationSyncAt);
    _navigationSyncTimer = Timer(wait, () {
      final pending = _pendingNavigationPayload;
      _pendingNavigationPayload = null;
      if (pending != null) {
        unawaited(_sendNavigationPayload(pending));
      }
    });
  }

  Future<void> clearNavigationState() async {
    _navigationSyncTimer?.cancel();
    _pendingNavigationPayload = null;
    await updateRouteGeometry(routePoints: const [], destination: null);
    await updateNavigationState(
      hasRoute: false,
      isNavigating: false,
      currentLocation: null,
      headingDegrees: 0,
      currentSpeed: 0,
      roadSpeedLimit: null,
      vehicleSpeedLimit: null,
      speedUnitLabel: 'km/h',
      destination: null,
      destinationLabel: '',
      destinationAddress: '',
      totalDistanceMeters: null,
      remainingDistanceMeters: null,
      remainingDurationSeconds: null,
      nextManeuverText: '',
      currentStreetName: '',
      upcomingManeuvers: const [],
    );
  }

  Future<void> updateRouteGeometry({
    required List<LatLng> routePoints,
    required LatLng? destination,
  }) async {
    final payload = <String, Object?>{
      'points': routePoints
          .map(
            (point) => <String, double>{
              'latitude': point.latitude,
              'longitude': point.longitude,
            },
          )
          .toList(growable: false),
      'destination': destination == null
          ? null
          : <String, double>{
              'latitude': destination.latitude,
              'longitude': destination.longitude,
            },
    };
    final payloadJson = jsonEncode(payload);
    if (_lastRouteGeometryPayloadJson == payloadJson) return;

    try {
      await _channel.invokeMethod<void>('syncRouteGeometry', payload);
      _lastRouteGeometryPayloadJson = payloadJson;
    } on MissingPluginException {
      // CarPlay bridge is only available on iOS when the native side is loaded.
    } catch (error, stackTrace) {
      debugPrint('CarPlay route geometry sync failed: $error\n$stackTrace');
    }
  }

  Future<void> updateConvoyState({
    required bool isActive,
    required String convoyName,
    required String? currentUserId,
    required List<Map<String, Object?>> members,
    LatLng? currentLocation,
    double headingDegrees = 0,
    double currentSpeed = 0,
  }) async {
    final payload = <String, Object?>{
      'isActive': isActive,
      'convoyName': convoyName.trim(),
      'currentUserId': currentUserId,
      'members': members,
      'currentLocation': currentLocation == null
          ? null
          : <String, double>{
              'latitude': currentLocation.latitude,
              'longitude': currentLocation.longitude,
            },
      'headingDegrees': headingDegrees,
      'currentSpeed': currentSpeed,
    };
    final payloadJson = jsonEncode(payload);
    if (_lastConvoyPayloadJson == payloadJson) return;

    try {
      await _channel.invokeMethod<void>('syncConvoyState', payload);
      _lastConvoyPayloadJson = payloadJson;
    } on MissingPluginException {
      // CarPlay bridge is only available on iOS when the native side is loaded.
    } catch (error, stackTrace) {
      debugPrint('CarPlay convoy sync failed: $error\n$stackTrace');
    }
  }

  Future<void> clearConvoyState() => updateConvoyState(
    isActive: false,
    convoyName: '',
    currentUserId: null,
    members: const [],
  );

  Future<Object?> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'requestSyncState':
        await syncState();
        return true;
      case 'carPlayConnectionChanged':
        isConnected.value = call.arguments == true;
        _refreshCompanionMode();
        return true;
      case 'startNavigation':
        final args = Map<String, dynamic>.from(
          (call.arguments as Map?) ?? const <String, dynamic>{},
        );
        final lat = _asDouble(args['lat']);
        final lon = _asDouble(args['lon'] ?? args['longitude']);
        if (lat == null || lon == null) {
          return false;
        }

        final label = _asTrimmedString(args['label'] ?? args['title']);
        final address = _asTrimmedString(args['address'] ?? args['subtitle']);
        NavigationRequestService.instance.requestNavigation(
          LatLng(lat, lon),
          label: label,
          address: address,
          startImmediately: args['startImmediately'] == true,
        );
        return true;
      case 'stopNavigation':
        NavigationRequestService.instance.requestStopNavigation();
        return true;
      default:
        throw MissingPluginException('Unhandled CarPlay method ${call.method}');
    }
  }

  void _onStateChanged() {
    unawaited(syncState());
  }

  void _refreshCompanionMode() {
    companionMode.value = isConnected.value && _navigationActive;
  }

  Future<void> _sendNavigationPayload(
    Map<String, Object?> payload, {
    String? payloadJson,
  }) async {
    try {
      await _channel.invokeMethod<void>('syncNavigationState', payload);
      _lastNavigationPayloadJson = payloadJson ?? jsonEncode(payload);
      _lastNavigationSyncAt = DateTime.now();
    } on MissingPluginException {
      // CarPlay bridge is only available on iOS when the native side is loaded.
    } catch (error, stackTrace) {
      debugPrint('CarPlay navigation sync failed: $error\n$stackTrace');
    }
  }

  double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value');
  }

  String? _asTrimmedString(Object? value) {
    final text = '$value'.trim();
    return text.isEmpty || text == 'null' ? null : text;
  }
}
