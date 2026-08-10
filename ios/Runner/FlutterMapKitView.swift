import Flutter
import MapKit
import UIKit

final class CruizXMapKitViewPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let factory = FlutterMapKitViewFactory(messenger: registrar.messenger())
    registrar.register(factory, withId: "cruizx/mapkit-view")
  }
}

final class FlutterMapKitViewFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    FlutterMapKitView(frame: frame, viewId: viewId, messenger: messenger)
  }
}

final class FlutterMapKitView: NSObject, FlutterPlatformView, MKMapViewDelegate {
  private let mapView = MKMapView()
  private let channel: FlutterMethodChannel
  private let userAnnotation = MKPointAnnotation()
  private let destinationAnnotation = MKPointAnnotation()
  private var hasUserAnnotation = false
  private var hasDestinationAnnotation = false
  private var routeOverlay: MKPolyline?
  private var hasCenteredInitialLocation = false
  private var suppressUserPanUntil = Date.distantPast
  private var lastRoutePoints: [CLLocationCoordinate2D] = []
  private var lastFollowUser = false

  init(frame: CGRect, viewId: Int64, messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "cruizx/mapkit_view_\(viewId)",
      binaryMessenger: messenger
    )

    super.init()

    mapView.frame = frame
    mapView.delegate = self
    mapView.showsCompass = false
    mapView.showsScale = false
    mapView.isPitchEnabled = true
    mapView.pointOfInterestFilter = .includingAll

    let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
    tapRecognizer.cancelsTouchesInView = false
    mapView.addGestureRecognizer(tapRecognizer)

    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  func view() -> UIView {
    mapView
  }

  private func handle(_ call: FlutterMethodCall, result: FlutterResult) {
    switch call.method {
    case "setState":
      apply(call.arguments)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func apply(_ arguments: Any?) {
    guard let payload = arguments as? [String: Any] else { return }

    let location = coordinate(from: payload["location"])
    let destination = coordinate(from: payload["destination"])
    let routePoints = coordinates(from: payload["routePoints"])
    let followUser = payload["followUser"] as? Bool ?? false
    let use3D = payload["use3D"] as? Bool ?? true
    let darkMode = payload["darkMode"] as? Bool ?? false
    let heading = doubleValue(payload["heading"]) ?? 0
    let nextManeuverDistanceMeters = doubleValue(payload["nextManeuverDistanceMeters"])
    let routeChanged = !sameCoordinates(routePoints, lastRoutePoints)
    let followModeChanged = followUser != lastFollowUser

    mapView.overrideUserInterfaceStyle = darkMode ? .dark : .light

    updateUserAnnotation(with: location)
    updateDestinationAnnotation(with: destination)
    updateRouteOverlay(with: routePoints, routeChanged: routeChanged)
    updateCamera(
      location: location,
      routePoints: routePoints,
      routeChanged: routeChanged,
      followModeChanged: followModeChanged,
      followUser: followUser,
      use3D: use3D,
      heading: heading,
      nextManeuverDistanceMeters: nextManeuverDistanceMeters
    )

    lastRoutePoints = routePoints
    lastFollowUser = followUser
  }

  private func updateUserAnnotation(with coordinate: CLLocationCoordinate2D?) {
    guard let coordinate else { return }

    if !hasUserAnnotation {
      hasUserAnnotation = true
      userAnnotation.title = "Du"
      userAnnotation.coordinate = coordinate
      mapView.addAnnotation(userAnnotation)
      return
    }

    userAnnotation.coordinate = coordinate
  }

  private func updateDestinationAnnotation(with coordinate: CLLocationCoordinate2D?) {
    guard let coordinate else {
      if hasDestinationAnnotation {
        hasDestinationAnnotation = false
        mapView.removeAnnotation(destinationAnnotation)
      }
      return
    }

    if !hasDestinationAnnotation {
      hasDestinationAnnotation = true
      destinationAnnotation.title = "Destination"
      destinationAnnotation.coordinate = coordinate
      mapView.addAnnotation(destinationAnnotation)
      return
    }

    destinationAnnotation.coordinate = coordinate
  }

  private func updateRouteOverlay(with points: [CLLocationCoordinate2D], routeChanged: Bool) {
    guard routeChanged else { return }

    if let routeOverlay {
      mapView.removeOverlay(routeOverlay)
      self.routeOverlay = nil
    }

    guard points.count >= 2 else { return }

    var mutablePoints = points
    let polyline = MKPolyline(coordinates: &mutablePoints, count: mutablePoints.count)
    routeOverlay = polyline
    mapView.addOverlay(polyline)
  }

  private func updateCamera(
    location: CLLocationCoordinate2D?,
    routePoints: [CLLocationCoordinate2D],
    routeChanged: Bool,
    followModeChanged: Bool,
    followUser: Bool,
    use3D: Bool,
    heading: Double,
    nextManeuverDistanceMeters: Double?
  ) {
    if followUser, let location {
      suppressUserPanUntil = Date().addingTimeInterval(0.7)
      let camera = MKMapCamera(
        lookingAtCenter: location,
        fromDistance: cameraDistance(for: nextManeuverDistanceMeters),
        pitch: use3D ? 52 : 0,
        heading: use3D ? heading : 0
      )
      mapView.setCamera(camera, animated: true)
      hasCenteredInitialLocation = true
      return
    }

    if !routePoints.isEmpty && (routeChanged || followModeChanged) {
      suppressUserPanUntil = Date().addingTimeInterval(0.7)
      fitRoute(routePoints)
      return
    }

    if let location, !hasCenteredInitialLocation {
      suppressUserPanUntil = Date().addingTimeInterval(0.7)
      hasCenteredInitialLocation = true
      let region = MKCoordinateRegion(
        center: location,
        latitudinalMeters: 1200,
        longitudinalMeters: 1200
      )
      mapView.setRegion(region, animated: false)
    }
  }

  private func fitRoute(_ points: [CLLocationCoordinate2D]) {
    guard let polyline = routeOverlay else { return }

    let routeRect = polyline.boundingMapRect
    let padded = mapView.mapRectThatFits(
      routeRect,
      edgePadding: UIEdgeInsets(top: 90, left: 50, bottom: 180, right: 50)
    )
    mapView.setVisibleMapRect(padded, animated: true)
  }

  private func cameraDistance(for nextManeuverDistanceMeters: Double?) -> CLLocationDistance {
    guard let nextManeuverDistanceMeters else { return 850 }
    switch nextManeuverDistanceMeters {
    case ..<80:
      return 260
    case ..<180:
      return 360
    case ..<320:
      return 520
    default:
      return 850
    }
  }

  private func coordinate(from raw: Any?) -> CLLocationCoordinate2D? {
    guard let values = raw as? [String: Any],
          let latitude = doubleValue(values["latitude"]),
          let longitude = doubleValue(values["longitude"])
    else {
      return nil
    }

    return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
  }

  private func coordinates(from raw: Any?) -> [CLLocationCoordinate2D] {
    guard let items = raw as? [Any] else { return [] }
    return items.compactMap { coordinate(from: $0) }
  }

  private func sameCoordinates(
    _ lhs: [CLLocationCoordinate2D],
    _ rhs: [CLLocationCoordinate2D]
  ) -> Bool {
    guard lhs.count == rhs.count else { return false }
    for (left, right) in zip(lhs, rhs) {
      if abs(left.latitude - right.latitude) > 0.000001 {
        return false
      }
      if abs(left.longitude - right.longitude) > 0.000001 {
        return false
      }
    }
    return true
  }

  private func doubleValue(_ value: Any?) -> Double? {
    switch value {
    case let number as NSNumber:
      return number.doubleValue
    case let text as String:
      return Double(text)
    default:
      return nil
    }
  }

  @objc
  private func handleTap(_ recognizer: UITapGestureRecognizer) {
    guard recognizer.state == .ended else { return }
    let point = recognizer.location(in: mapView)
    let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
    channel.invokeMethod("mapTapped", arguments: [
      "latitude": coordinate.latitude,
      "longitude": coordinate.longitude,
    ])
  }

  func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
    guard Date() >= suppressUserPanUntil else { return }
    guard isGestureDrivenChange() else { return }
    channel.invokeMethod("userPanned", arguments: nil)
  }

  func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
    guard let polyline = overlay as? MKPolyline else {
      return MKOverlayRenderer(overlay: overlay)
    }

    let renderer = MKPolylineRenderer(polyline: polyline)
    renderer.strokeColor = UIColor(red: 0.04, green: 0.38, blue: 1.0, alpha: 0.94)
    renderer.lineWidth = 7
    renderer.lineCap = .round
    renderer.lineJoin = .round
    return renderer
  }

  func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
    if annotation === userAnnotation {
      let identifier = "CruizXUser"
      let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
        ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
      view.annotation = annotation
      if let marker = view as? MKMarkerAnnotationView {
        marker.markerTintColor = UIColor(red: 0.04, green: 0.38, blue: 1.0, alpha: 1)
        marker.glyphImage = UIImage(systemName: "location.fill")
        marker.titleVisibility = .hidden
        marker.subtitleVisibility = .hidden
      }
      return view
    }

    if annotation === destinationAnnotation {
      let identifier = "CruizXDestination"
      let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
        ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
      view.annotation = annotation
      if let marker = view as? MKMarkerAnnotationView {
        marker.markerTintColor = UIColor.systemRed
        marker.glyphImage = UIImage(systemName: "flag.fill")
        marker.titleVisibility = .hidden
        marker.subtitleVisibility = .hidden
      }
      return view
    }

    return nil
  }

  private func isGestureDrivenChange() -> Bool {
    let states: [UIGestureRecognizer.State] = [.began, .changed, .ended]
    return (mapView.gestureRecognizers ?? []).contains { states.contains($0.state) }
  }
}
