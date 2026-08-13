import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

class NavigationRequest {
  const NavigationRequest({
    required this.destination,
    this.label,
    this.address,
    this.startImmediately = false,
  });

  final LatLng destination;
  final String? label;
  final String? address;
  final bool startImmediately;
}

/// Singleton that lets any screen request navigation to a coordinate.
/// AppShell listens and switches to the map tab.
/// MapScreen listens and starts the route calculation.
class NavigationRequestService {
  NavigationRequestService._();

  static final NavigationRequestService instance = NavigationRequestService._();

  final ValueNotifier<NavigationRequest?> pendingDestination =
      ValueNotifier<NavigationRequest?>(null);
  final ValueNotifier<int> stopNavigationRequests = ValueNotifier<int>(0);

  void requestNavigation(
    LatLng destination, {
    String? label,
    String? address,
    bool startImmediately = false,
  }) {
    pendingDestination.value = NavigationRequest(
      destination: destination,
      label: label,
      address: address,
      startImmediately: startImmediately,
    );
  }

  void consume() {
    pendingDestination.value = null;
  }

  void requestStopNavigation() {
    pendingDestination.value = null;
    stopNavigationRequests.value = stopNavigationRequests.value + 1;
  }
}
