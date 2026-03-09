import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// Singleton that lets any screen request navigation to a coordinate.
/// AppShell listens and switches to the map tab.
/// MapScreen listens and starts the route calculation.
class NavigationRequestService {
  NavigationRequestService._();

  static final NavigationRequestService instance = NavigationRequestService._();

  final ValueNotifier<LatLng?> pendingDestination = ValueNotifier<LatLng?>(
    null,
  );

  void requestNavigation(LatLng destination) {
    pendingDestination.value = destination;
  }

  void consume() {
    pendingDestination.value = null;
  }
}
