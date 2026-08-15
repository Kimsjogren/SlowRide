import Flutter
import MapKit
import UIKit

final class AppleMapSearchPlugin: NSObject, FlutterPlugin {
  private static let channelName = "cruizx/mapkit_search"

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )
    let instance = AppleMapSearchPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "search":
      search(arguments: call.arguments, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func search(arguments: Any?, result: @escaping FlutterResult) {
    guard let payload = arguments as? [String: Any] else {
      result([])
      return
    }

    let query = (payload["query"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else {
      result([])
      return
    }

    let limit = max(1, min((payload["limit"] as? NSNumber)?.intValue ?? 10, 10))
    let latitude = (payload["latitude"] as? NSNumber)?.doubleValue
    let longitude = (payload["longitude"] as? NSNumber)?.doubleValue
    let proximity = coordinate(latitude: latitude, longitude: longitude)

    performSearch(
      query: query,
      proximity: proximity,
      limit: limit,
      allowGlobalFallback: proximity != nil
    ) { items in
      result(items)
    }
  }

  private func performSearch(
    query: String,
    proximity: CLLocationCoordinate2D?,
    limit: Int,
    allowGlobalFallback: Bool,
    completion: @escaping ([[String: Any]]) -> Void
  ) {
    let request = MKLocalSearch.Request()
    request.naturalLanguageQuery = query
    request.resultTypes = [.address, .pointOfInterest]
    if let proximity {
      request.region = MKCoordinateRegion(
        center: proximity,
        latitudinalMeters: 70000,
        longitudinalMeters: 70000
      )
    }

    MKLocalSearch(request: request).start { [weak self] response, _ in
      let mapped = self?.mapItems(response?.mapItems ?? [], query: query, limit: limit) ?? []
      if !mapped.isEmpty || !allowGlobalFallback || proximity == nil {
        completion(mapped)
        return
      }

      self?.performSearch(
        query: query,
        proximity: nil,
        limit: limit,
        allowGlobalFallback: false,
        completion: completion
      ) ?? completion([])
    }
  }

  private func mapItems(
    _ items: [MKMapItem],
    query: String,
    limit: Int
  ) -> [[String: Any]] {
    var mapped: [[String: Any]] = []
    var seen = Set<String>()

    for item in items {
      let serialized = serialize(item: item, fallbackQuery: query)
      let dedupeKey = [
        serialized["name"] as? String ?? "",
        serialized["display_name"] as? String ?? "",
        serialized["lat"] as? String ?? "",
        serialized["lon"] as? String ?? "",
      ].joined(separator: "|")
      guard seen.insert(dedupeKey).inserted else { continue }
      mapped.append(serialized)
      if mapped.count >= limit { break }
    }

    return mapped
  }

  private func serialize(item: MKMapItem, fallbackQuery: String) -> [String: Any] {
    let placemark = item.placemark
    let coordinate = placemark.coordinate
    let street = placemark.thoroughfare?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let houseNumber = placemark.subThoroughfare?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let city = placemark.locality?.trimmingCharacters(in: .whitespacesAndNewlines)
      ?? placemark.subLocality?.trimmingCharacters(in: .whitespacesAndNewlines)
      ?? ""
    let municipality = placemark.subAdministrativeArea?.trimmingCharacters(in: .whitespacesAndNewlines)
      ?? placemark.administrativeArea?.trimmingCharacters(in: .whitespacesAndNewlines)
      ?? ""
    let country = placemark.country?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let countryCode = placemark.isoCountryCode?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() ?? ""
    let postalCode = placemark.postalCode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let pointOfInterest: Bool
    if #available(iOS 13.0, *) {
      pointOfInterest = item.pointOfInterestCategory != nil
    } else {
      pointOfInterest = !(item.name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) &&
        streetLine(street: street, houseNumber: houseNumber) !=
        (item.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
    }
    let title = preferredTitle(for: item, placemark: placemark, fallbackQuery: fallbackQuery)
    let streetLine = streetLine(street: street, houseNumber: houseNumber)
    var address: [String: String] = [:]
    if !street.isEmpty { address["road"] = street }
    if !houseNumber.isEmpty { address["house_number"] = houseNumber }
    if !city.isEmpty { address["city"] = city }
    if !municipality.isEmpty { address["municipality"] = municipality }
    if !country.isEmpty { address["country"] = country }
    if !countryCode.isEmpty { address["country_code"] = countryCode }
    if !postalCode.isEmpty { address["postcode"] = postalCode }

    let displayName = [
      title,
      streetLine == title ? "" : streetLine,
      city,
      municipality == city ? "" : municipality,
      country,
    ]
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
      .joined(separator: ", ")

    return [
      "lat": String(coordinate.latitude),
      "lon": String(coordinate.longitude),
      "place_id": "\(coordinate.latitude),\(coordinate.longitude)|\(title)",
      "importance": 1.0,
      "name": title,
      "display_name": displayName,
      "address": address,
      "category": pointOfInterest ? "poi" : "",
      "_mapbox_place_type": pointOfInterest ? "poi" : "address",
      "_source": "apple_mapkit",
    ]
  }

  private func preferredTitle(
    for item: MKMapItem,
    placemark: MKPlacemark,
    fallbackQuery: String
  ) -> String {
    let itemName = item.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if !itemName.isEmpty {
      return itemName
    }

    let placemarkName = placemark.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if !placemarkName.isEmpty {
      return placemarkName
    }

    let street = placemark.thoroughfare?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let houseNumber = placemark.subThoroughfare?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let streetLine = streetLine(street: street, houseNumber: houseNumber)
    if !streetLine.isEmpty {
      return streetLine
    }

    let city = placemark.locality?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return city.isEmpty ? fallbackQuery : city
  }

  private func streetLine(street: String, houseNumber: String) -> String {
    if !street.isEmpty && !houseNumber.isEmpty {
      return "\(street) \(houseNumber)"
    }
    return street
  }

  private func coordinate(
    latitude: Double?,
    longitude: Double?
  ) -> CLLocationCoordinate2D? {
    guard let latitude, let longitude else { return nil }
    return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
  }
}

private struct CruizXUserMarkerStyle: Equatable {
  let assetPath: String?
  let iconName: String?
  let tintColor: UIColor
  let rotatesWithHeading: Bool

  static let fallback = CruizXUserMarkerStyle(
    assetPath: nil,
    iconName: "navigation",
    tintColor: UIColor(red: 0.12, green: 0.56, blue: 1.0, alpha: 1),
    rotatesWithHeading: true
  )

  static func == (lhs: CruizXUserMarkerStyle, rhs: CruizXUserMarkerStyle) -> Bool {
    lhs.assetPath == rhs.assetPath &&
      lhs.iconName == rhs.iconName &&
      lhs.rotatesWithHeading == rhs.rotatesWithHeading &&
      lhs.tintColor.isEqual(rhs.tintColor)
  }
}

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

fileprivate final class CruizXConvoyMemberAnnotation: MKPointAnnotation {
  let userId: String
  let markerStyle: CruizXUserMarkerStyle

  init(userId: String, title: String, coordinate: CLLocationCoordinate2D, markerStyle: CruizXUserMarkerStyle) {
    self.userId = userId
    self.markerStyle = markerStyle
    super.init()
    self.title = title
    self.coordinate = coordinate
  }
}

final class CruizXConvoyPinAnnotation: MKPointAnnotation {
  let pinId: String
  let pinType: String

  init(pinId: String, label: String, pinType: String, coordinate: CLLocationCoordinate2D) {
    self.pinId = pinId
    self.pinType = pinType
    super.init()
    self.title = label
    self.coordinate = coordinate
  }
}

final class CruizXMeetupAnnotation: MKPointAnnotation {}

final class CruizXAlertAnnotation: MKPointAnnotation {
  let alertId: String
  let typeKey: String
  let emoji: String

  init(alertId: String, title: String, typeKey: String, emoji: String, coordinate: CLLocationCoordinate2D) {
    self.alertId = alertId
    self.typeKey = typeKey
    self.emoji = emoji
    super.init()
    self.title = title
    self.coordinate = coordinate
  }
}

final class FlutterMapKitView: NSObject, FlutterPlatformView, MKMapViewDelegate, CLLocationManagerDelegate {
  private let mapView = MKMapView()
  private let channel: FlutterMethodChannel
  private let locationManager = CLLocationManager()
  private let userAnnotation = MKPointAnnotation()
  private let destinationAnnotation = MKPointAnnotation()
  private let meetupAnnotation = CruizXMeetupAnnotation()
  private var hasUserAnnotation = false
  private var hasDestinationAnnotation = false
  private var hasMeetupAnnotation = false
  private var routeOverlay: MKPolyline?
  private var hasCenteredInitialLocation = false
  private var suppressUserPanUntil = Date.distantPast
  private var lastRoutePoints: [CLLocationCoordinate2D] = []
  private var lastFollowUser = false
  private var isFollowingUser = false
  private var userMarkerStyle = CruizXUserMarkerStyle.fallback
  private var lastHeading = 0.0
  private var deviceCompassHeading: Double?
  private var renderedUserHeading = 0.0
  private var hasRenderedUserHeading = false
  private var markerImageCache: [String: UIImage] = [:]
  private var didNotifyUserPan = false
  private var followReleaseTargetsAttached = false
  private var memberAnnotations: [String: CruizXConvoyMemberAnnotation] = [:]
  private var pinAnnotations: [String: CruizXConvoyPinAnnotation] = [:]
  private var alertAnnotations: [String: CruizXAlertAnnotation] = [:]
  private var lastViewportCommandId: Int?
  private var hideUserMarkerWhenFollowing = false
  private var lastUserLocationUpdateAt: Date?
  private var lastRawUserCoordinate: CLLocationCoordinate2D?
  private var targetUserCoordinate: CLLocationCoordinate2D?
  private var renderedUserCoordinate: CLLocationCoordinate2D?
  private var lastUserVelocityMps = 0.0
  private var navigationRoutePoints: [CLLocationCoordinate2D] = []
  private var userMarkerDisplayLink: CADisplayLink?
  private var lastUserDisplayTimestamp: CFTimeInterval?
  // ── Smooth follow-camera state (driven at 60fps by the display link) ──
  private var followCameraEngaged = false
  private var followCameraUse3D = true
  private var targetCameraHeading = 0.0
  private var filteredTargetCameraHeading = 0.0
  private var renderedCameraHeading = 0.0
  private var renderedMarkerRelativeHeading = 0.0
  private var hasRenderedCameraHeading = false
  private var targetCameraDistance: CLLocationDistance = 850
  private var renderedCameraDistance: CLLocationDistance = 850
  private var hasRenderedCameraDistance = false
  private var lastAppliedCameraCenter: CLLocationCoordinate2D?
  private var lastAppliedCameraHeading = 0.0
  private var lastAppliedCameraDistance: CLLocationDistance = 0

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

    locationManager.delegate = self
    locationManager.headingFilter = 4
    if CLLocationManager.headingAvailable() {
      locationManager.startUpdatingHeading()
    }

    let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
    tapRecognizer.cancelsTouchesInView = false
    mapView.addGestureRecognizer(tapRecognizer)
    DispatchQueue.main.async { [weak self] in
      self?.attachFollowReleaseTargetsIfNeeded()
    }

    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  deinit {
    stopUserMarkerDisplayLink()
  }

  func view() -> UIView {
    mapView
  }

  private func handle(_ call: FlutterMethodCall, result: FlutterResult) {
    switch call.method {
    case "setState":
      apply(call.arguments)
      result(nil)
    case "setHeading":
      applyHeadingPayload(call.arguments)
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
    let meetup = meetupPayload(from: payload["meetup"])
    let currentUserId = (payload["currentUserId"] as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let members = convoyMemberPayloads(
      from: payload["convoyMembers"],
      excludingUserId: currentUserId?.isEmpty == false ? currentUserId : nil
    )
    let pins = convoyPinPayloads(from: payload["convoyPins"])
    let alerts = alertPayloads(from: payload["alerts"])
    let followUser = payload["followUser"] as? Bool ?? false
    let use3D = payload["use3D"] as? Bool ?? true
    let darkMode = payload["darkMode"] as? Bool ?? false
    let hideUserMarkerWhenFollowing =
      payload["hideUserMarkerWhenFollowing"] as? Bool ?? false
    let markerStyle = markerStyle(from: payload["markerStyle"])
    let nextManeuverDistanceMeters = doubleValue(payload["nextManeuverDistanceMeters"])
    let routeChanged = !sameCoordinates(routePoints, lastRoutePoints)
    let routeTrimmedOnly = isTrimmedContinuation(routePoints, of: lastRoutePoints)
    let followModeChanged = followUser != lastFollowUser

    mapView.overrideUserInterfaceStyle = darkMode ? .dark : .light
    navigationRoutePoints = routePoints
    isFollowingUser = followUser
    self.hideUserMarkerWhenFollowing = hideUserMarkerWhenFollowing
    if followModeChanged {
      // Re-establish the smooth camera the next time updateCamera runs.
      followCameraEngaged = false
    }
    // The display link now interpolates the marker AND (in follow mode) the
    // camera at 60fps, so keep it running in both modes.
    ensureUserMarkerDisplayLink()
    if markerStyle != userMarkerStyle {
      userMarkerStyle = markerStyle
      updateUserAnnotationViewIfNeeded()
    } else if followModeChanged {
      updateUserAnnotationViewIfNeeded()
    } else if isFollowingUser {
      updateUserAnnotationHeadingIfNeeded()
    }

    updateUserAnnotation(with: location)
    updateDestinationAnnotation(with: destination)
    updateMeetupAnnotation(with: meetup)
    updateConvoyMemberAnnotations(with: members)
    updateConvoyPinAnnotations(with: pins)
    updateAlertAnnotations(with: alerts)
    updateRouteOverlay(with: routePoints, routeChanged: routeChanged)
    updateCamera(
      location: location,
      routePoints: routePoints,
      routeChanged: routeChanged,
      routeTrimmedOnly: routeTrimmedOnly,
      followModeChanged: followModeChanged,
      followUser: followUser,
      use3D: use3D,
      heading: lastHeading,
      nextManeuverDistanceMeters: nextManeuverDistanceMeters
    )
    applyViewportCommand(payload["viewportCommand"])

    lastRoutePoints = routePoints
    lastFollowUser = followUser
  }

  private func applyHeadingPayload(_ arguments: Any?) {
    guard let payload = arguments as? [String: Any],
          let heading = doubleValue(payload["heading"])
    else {
      return
    }

    lastHeading = heading
    targetCameraHeading = heading
    updateUserAnnotationHeadingIfNeeded()
  }

  private func updateUserAnnotation(with coordinate: CLLocationCoordinate2D?) {
    guard let coordinate else { return }
    let updateTime = Date()

    if !hasUserAnnotation {
      hasUserAnnotation = true
      userAnnotation.title = "Du"
      userAnnotation.coordinate = coordinate
      lastUserLocationUpdateAt = updateTime
      lastRawUserCoordinate = coordinate
      targetUserCoordinate = coordinate
      renderedUserCoordinate = coordinate
      filteredTargetCameraHeading = normalizedDegrees(lastHeading)
      mapView.addAnnotation(userAnnotation)
      updateUserAnnotationViewIfNeeded()
      return
    }

    let previousRawCoordinate = lastRawUserCoordinate ?? userAnnotation.coordinate
    let sampleInterval = lastUserLocationUpdateAt.map {
      updateTime.timeIntervalSince($0)
    }
    lastUserLocationUpdateAt = updateTime
    lastRawUserCoordinate = coordinate

    let rawDistance = CLLocation(
      latitude: previousRawCoordinate.latitude,
      longitude: previousRawCoordinate.longitude
    ).distance(
      from: CLLocation(
        latitude: coordinate.latitude,
        longitude: coordinate.longitude
      )
    )
    let interval = sampleInterval ?? 0.9
    if interval > 0.20, rawDistance >= 0.8, rawDistance <= 120 {
      let measuredVelocity = min(rawDistance / interval, 55.0)
      if lastUserVelocityMps <= 0.01 {
        lastUserVelocityMps = measuredVelocity
      } else {
        lastUserVelocityMps = lastUserVelocityMps * 0.42 + measuredVelocity * 0.58
      }
    } else if rawDistance < 0.8 {
      lastUserVelocityMps *= 0.55
    }

    var nextTarget = targetUserCoordinate ?? coordinate
    let distanceToTarget = CLLocation(
      latitude: nextTarget.latitude,
      longitude: nextTarget.longitude
    ).distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))

    // Build 142: blend fresh GPS into the predicted position at speed, but
    // snap at low speed or after a large location jump.
    if lastUserVelocityMps > 2.0 || distanceToTarget > 2.0 {
      if lastUserVelocityMps > 3.0, distanceToTarget < 25.0 {
        nextTarget = interpolatedCoordinate(from: nextTarget, to: coordinate, progress: 0.22)
      } else {
        nextTarget = coordinate
      }
    }

    // Build 142 route magnet: progressively pull the position onto the road
    // inside a 45 metre corridor so the marker does not drift beside the line.
    if let projection = projectedOntoNavigationRoute(coordinate),
       projection.distanceMeters < 45 {
      let snapBlend = min(max((45.0 - projection.distanceMeters) / 45.0, 0), 1)
      nextTarget = interpolatedCoordinate(
        from: nextTarget,
        to: projection.coordinate,
        progress: snapBlend
      )
    }
    targetUserCoordinate = nextTarget

    // Build 142 used a separate speed-adaptive low-pass for the route heading.
    let targetAlpha = min(max(lastUserVelocityMps / 16.0, 0.08), 0.32)
    let targetTurn = shortestDegrees(
      from: filteredTargetCameraHeading,
      to: normalizedDegrees(targetCameraHeading)
    )
    filteredTargetCameraHeading = normalizedDegrees(
      filteredTargetCameraHeading + targetTurn * targetAlpha
    )

    if renderedUserCoordinate == nil {
      renderedUserCoordinate = coordinate
      userAnnotation.coordinate = coordinate
    } else if rawDistance > 120 || interval > 2.5 {
      renderedUserCoordinate = coordinate
      userAnnotation.coordinate = coordinate
    }
    ensureUserMarkerDisplayLink()
    updateUserAnnotationHeadingIfNeeded()
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

  private func updateMeetupAnnotation(with payload: (coordinate: CLLocationCoordinate2D, label: String)?) {
    guard let payload else {
      if hasMeetupAnnotation {
        hasMeetupAnnotation = false
        mapView.removeAnnotation(meetupAnnotation)
      }
      return
    }

    if !hasMeetupAnnotation {
      hasMeetupAnnotation = true
      meetupAnnotation.title = payload.label
      meetupAnnotation.coordinate = payload.coordinate
      mapView.addAnnotation(meetupAnnotation)
      return
    }

    meetupAnnotation.title = payload.label
    meetupAnnotation.coordinate = payload.coordinate
  }

  private func updateConvoyMemberAnnotations(
    with payloads: [(userId: String, label: String, coordinate: CLLocationCoordinate2D, markerStyle: CruizXUserMarkerStyle)]
  ) {
    let incomingIds = Set(payloads.map(\.userId))
    let currentIds = Set(memberAnnotations.keys)

    for removedId in currentIds.subtracting(incomingIds) {
      if let annotation = memberAnnotations.removeValue(forKey: removedId) {
        mapView.removeAnnotation(annotation)
      }
    }

    for payload in payloads {
      if let existing = memberAnnotations[payload.userId] {
        existing.title = payload.label
        existing.coordinate = payload.coordinate
        if existing.markerStyle != payload.markerStyle {
          let replacement = CruizXConvoyMemberAnnotation(
            userId: payload.userId,
            title: payload.label,
            coordinate: payload.coordinate,
            markerStyle: payload.markerStyle
          )
          memberAnnotations[payload.userId] = replacement
          mapView.removeAnnotation(existing)
          mapView.addAnnotation(replacement)
        }
        continue
      }

      let annotation = CruizXConvoyMemberAnnotation(
        userId: payload.userId,
        title: payload.label,
        coordinate: payload.coordinate,
        markerStyle: payload.markerStyle
      )
      memberAnnotations[payload.userId] = annotation
      mapView.addAnnotation(annotation)
    }
  }

  private func updateConvoyPinAnnotations(
    with payloads: [(pinId: String, label: String, type: String, coordinate: CLLocationCoordinate2D)]
  ) {
    let incomingIds = Set(payloads.map(\.pinId))
    let currentIds = Set(pinAnnotations.keys)

    for removedId in currentIds.subtracting(incomingIds) {
      if let annotation = pinAnnotations.removeValue(forKey: removedId) {
        mapView.removeAnnotation(annotation)
      }
    }

    for payload in payloads {
      if let existing = pinAnnotations[payload.pinId] {
        existing.title = payload.label
        existing.coordinate = payload.coordinate
        continue
      }

      let annotation = CruizXConvoyPinAnnotation(
        pinId: payload.pinId,
        label: payload.label,
        pinType: payload.type,
        coordinate: payload.coordinate
      )
      pinAnnotations[payload.pinId] = annotation
      mapView.addAnnotation(annotation)
    }
  }

  private func updateAlertAnnotations(
    with payloads: [(alertId: String, label: String, typeKey: String, emoji: String, coordinate: CLLocationCoordinate2D)]
  ) {
    let incomingIds = Set(payloads.map(\.alertId))
    let currentIds = Set(alertAnnotations.keys)

    for removedId in currentIds.subtracting(incomingIds) {
      if let annotation = alertAnnotations.removeValue(forKey: removedId) {
        mapView.removeAnnotation(annotation)
      }
    }

    for payload in payloads {
      if let existing = alertAnnotations[payload.alertId] {
        existing.title = payload.label
        existing.coordinate = payload.coordinate
        continue
      }

      let annotation = CruizXAlertAnnotation(
        alertId: payload.alertId,
        title: payload.label,
        typeKey: payload.typeKey,
        emoji: payload.emoji,
        coordinate: payload.coordinate
      )
      alertAnnotations[payload.alertId] = annotation
      mapView.addAnnotation(annotation)
    }
  }

  private func updateRouteOverlay(with points: [CLLocationCoordinate2D], routeChanged: Bool) {
    guard routeChanged else { return }

    guard points.count >= 2 else {
      if let routeOverlay {
        mapView.removeOverlay(routeOverlay)
        self.routeOverlay = nil
      }
      return
    }

    var mutablePoints = points
    let polyline = MKPolyline(coordinates: &mutablePoints, count: mutablePoints.count)
    let previousOverlay = routeOverlay
    routeOverlay = polyline
    // Add the replacement before removing the previous line. This prevents a
    // one-frame blue-route flash while the route is trimmed during navigation.
    mapView.addOverlay(polyline)
    if let previousOverlay {
      mapView.removeOverlay(previousOverlay)
    }
  }

  private func updateCamera(
    location: CLLocationCoordinate2D?,
    routePoints: [CLLocationCoordinate2D],
    routeChanged: Bool,
    routeTrimmedOnly: Bool,
    followModeChanged: Bool,
    followUser: Bool,
    use3D: Bool,
    heading: Double,
    nextManeuverDistanceMeters: Double?
  ) {
    if followUser, let location {
      suppressUserPanUntil = Date().addingTimeInterval(0.7)
      // Feed the smooth follow-camera its targets; the 60fps display link
      // interpolates between GPS samples so the map glides like Waze/Google
      // Maps instead of jumping once per second.
      targetCameraDistance = cameraDistance(for: nextManeuverDistanceMeters)
      targetCameraHeading = heading
      followCameraUse3D = use3D
      ensureUserMarkerDisplayLink()

      if !followCameraEngaged || followModeChanged || (routeChanged && !routeTrimmedOnly) {
        // Establish the camera once; the display link takes over from here.
        followCameraEngaged = true
        hasRenderedCameraHeading = false
        hasRenderedCameraDistance = false
        lastAppliedCameraCenter = nil
        filteredTargetCameraHeading = normalizedDegrees(heading)
        renderedMarkerRelativeHeading = 0
        renderedUserCoordinate = location
        let distance = targetCameraDistance
        let focusDistance = min(
          max(distance * (use3D ? 0.11 : 0.10), use3D ? 26 : 20),
          use3D ? 58 : 46
        )
        let focusCoordinate =
          use3D
          ? projectedCoordinate(
            from: location,
            distanceMeters: focusDistance,
            headingDegrees: heading
          )
          : location
        let camera = MKMapCamera(
          lookingAtCenter: focusCoordinate,
          fromDistance: distance,
          pitch: use3D ? 52 : 0,
          // Navigation is heading-up in both modes. 2D only removes the
          // perspective pitch; it must not switch the map back to north-up.
          heading: normalizedDegrees(heading)
        )
        mapView.setCamera(camera, animated: followModeChanged)
      }
      hasCenteredInitialLocation = true
      return
    }

    if followModeChanged && !followUser {
      suppressUserPanUntil = Date.distantPast
      let currentCamera = mapView.camera.copy() as? MKMapCamera ?? mapView.camera
      mapView.setCamera(currentCamera, animated: false)
      return
    }

    if !routePoints.isEmpty && routeChanged && !routeTrimmedOnly {
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

  private func ensureUserMarkerDisplayLink() {
    guard userMarkerDisplayLink == nil else { return }
    let displayLink = CADisplayLink(target: self, selector: #selector(handleUserMarkerDisplayLink(_:)))
    if #available(iOS 15.0, *) {
      displayLink.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
    } else {
      displayLink.preferredFramesPerSecond = 60
    }
    displayLink.add(to: .main, forMode: .common)
    userMarkerDisplayLink = displayLink
  }

  private func stopUserMarkerDisplayLink() {
    userMarkerDisplayLink?.invalidate()
    userMarkerDisplayLink = nil
    lastUserDisplayTimestamp = nil
  }

  @objc
  private func handleUserMarkerDisplayLink(_ displayLink: CADisplayLink) {
    guard hasUserAnnotation else {
      lastUserDisplayTimestamp = displayLink.timestamp
      return
    }

    guard var targetCoordinate = targetUserCoordinate else {
      lastUserDisplayTimestamp = displayLink.timestamp
      return
    }

    let previousTimestamp = lastUserDisplayTimestamp ?? displayLink.timestamp
    lastUserDisplayTimestamp = displayLink.timestamp
    let dt = min(max(displayLink.timestamp - previousTimestamp, 1.0 / 120.0), 0.12)

    let sampleAge = lastUserLocationUpdateAt.map { Date().timeIntervalSince($0) } ?? 0

    // Build 142 dead reckoning: advance the target continuously between the
    // roughly 1 Hz GPS samples, but stop after 2.5 seconds to prevent runaway.
    if lastUserVelocityMps > 0.8, sampleAge >= 0, sampleAge < 2.5 {
      targetCoordinate = projectedCoordinate(
        from: targetCoordinate,
        distanceMeters: lastUserVelocityMps * dt,
        headingDegrees: filteredTargetCameraHeading
      )
      targetUserCoordinate = targetCoordinate
    }

    let currentCoordinate = renderedUserCoordinate ?? userAnnotation.coordinate
    let remainingDistance = CLLocation(
      latitude: currentCoordinate.latitude,
      longitude: currentCoordinate.longitude
    ).distance(
      from: CLLocation(
        latitude: targetCoordinate.latitude,
        longitude: targetCoordinate.longitude
      )
    )

    let nextCoordinate: CLLocationCoordinate2D
    if remainingDistance < 0.35 {
      nextCoordinate = targetCoordinate
    } else {
      let speedN = min(max(lastUserVelocityMps / 16.0, 0), 1)
      let positionAlpha = min(max(dt * (2.0 + speedN * 2.5), 0.03), 0.30)
      let headingDifference = abs(
        shortestDegrees(from: renderedCameraHeading, to: filteredTargetCameraHeading)
      )
      let turnN = min(max(headingDifference / 45.0, 0), 1)
      let blend = min(max(positionAlpha * (1.0 + turnN * 0.35), 0.04), 0.55)
      nextCoordinate = interpolatedCoordinate(
        from: currentCoordinate,
        to: targetCoordinate,
        progress: blend
      )
    }

    renderedUserCoordinate = nextCoordinate
    UIView.performWithoutAnimation {
      userAnnotation.coordinate = nextCoordinate
    }

    if isFollowingUser {
      updateFollowCamera(userCoordinate: nextCoordinate, dt: dt)
    }
  }

  /// Smoothly drives the map camera every frame while following the user.
  /// Heading and zoom distance are eased toward their targets so turns and
  /// zoom changes glide instead of snapping on each ~1Hz GPS/heading sample.
  private func updateFollowCamera(userCoordinate: CLLocationCoordinate2D, dt: Double) {
    let targetHeading = normalizedDegrees(filteredTargetCameraHeading)
    if !hasRenderedCameraHeading {
      renderedCameraHeading = targetHeading
      hasRenderedCameraHeading = true
    } else {
      // Build 142 speed-adaptive turn smoothing and turn-rate cap. It remains
      // calm at low speed but lets the map catch up decisively in a real turn.
      let speedN = min(max(lastUserVelocityMps / 16.0, 0), 1)
      let rawTurn = shortestDegrees(from: renderedCameraHeading, to: targetHeading)
      let turnN = min(max(abs(rawTurn) / 45.0, 0), 1)
      let maxTurnPerSecond = 35.0 + speedN * 75.0
      let boostedMaximum = maxTurnPerSecond * dt * (1.0 + turnN * 2.2)
      let limitedTurn = min(max(rawTurn, -boostedMaximum), boostedMaximum)
      let headingAlpha = min(
        max(dt * (1.5 + speedN * 2.8) * (1.0 + turnN * 2.0), 0.03),
        0.70
      )
      renderedCameraHeading = normalizedDegrees(
        renderedCameraHeading + limitedTurn * headingAlpha
      )
    }

    // Match CarPlay: the vehicle marker is screen-locked straight ahead and
    // the map itself turns underneath it.
    renderedMarkerRelativeHeading = 0
    if let markerView = mapView.view(for: userAnnotation) {
      applyFollowMarkerRotation(view: markerView)
    }

    if !hasRenderedCameraDistance {
      renderedCameraDistance = targetCameraDistance
      hasRenderedCameraDistance = true
    } else {
      let blend = min(max(dt * 3.0, 0.03), 0.3)
      renderedCameraDistance += (targetCameraDistance - renderedCameraDistance) * blend
    }

    let use3D = followCameraUse3D
    let focusDistance = min(
      max(renderedCameraDistance * (use3D ? 0.11 : 0.10), use3D ? 26 : 20),
      use3D ? 58 : 46
    )
    let focusCoordinate =
      use3D
      ? projectedCoordinate(
        from: userCoordinate,
        distanceMeters: focusDistance,
        headingDegrees: renderedCameraHeading
      )
      : userCoordinate

    // Deadband: skip the camera write when nothing meaningfully changed so a
    // parked car doesn't burn battery pushing identical cameras at 60fps.
    if let lastCenter = lastAppliedCameraCenter {
      let centerMoved = CLLocation(
        latitude: lastCenter.latitude,
        longitude: lastCenter.longitude
      ).distance(
        from: CLLocation(
          latitude: focusCoordinate.latitude,
          longitude: focusCoordinate.longitude
        )
      )
      let headingMoved = abs(shortestDegrees(from: lastAppliedCameraHeading, to: renderedCameraHeading))
      let distanceMoved = abs(lastAppliedCameraDistance - renderedCameraDistance)
      if centerMoved < 0.15, headingMoved < 0.05, distanceMoved < 0.5 {
        return
      }
    }

    lastAppliedCameraCenter = focusCoordinate
    lastAppliedCameraHeading = renderedCameraHeading
    lastAppliedCameraDistance = renderedCameraDistance

    let camera = MKMapCamera(
      lookingAtCenter: focusCoordinate,
      fromDistance: renderedCameraDistance,
      pitch: use3D ? 52 : 0,
      // Let the route turn the map in both 2D and 3D. The navigation marker
      // is screen-locked straight ahead below, so only the map rotates.
      heading: renderedCameraHeading
    )
    // Refresh the pan-suppression window so per-frame programmatic camera
    // moves are never misread as the user dragging the map.
    suppressUserPanUntil = Date().addingTimeInterval(0.2)
    UIView.performWithoutAnimation {
      mapView.setCamera(camera, animated: false)
    }
  }

  private func applyViewportCommand(_ raw: Any?) {
    guard let values = raw as? [String: Any],
          let commandId = (values["id"] as? NSNumber)?.intValue,
          commandId != lastViewportCommandId,
          let type = values["type"] as? String
    else {
      return
    }

    lastViewportCommandId = commandId
    guard type == "fit_points" else { return }
    let points = coordinates(from: values["points"])
    guard !points.isEmpty else { return }

    suppressUserPanUntil = Date().addingTimeInterval(0.7)
    if points.count == 1 {
      let region = MKCoordinateRegion(
        center: points[0],
        latitudinalMeters: 1200,
        longitudinalMeters: 1200
      )
      mapView.setRegion(region, animated: true)
      return
    }

    let mapPoints = points.map(MKMapPoint.init)
    let rect = mapPoints.reduce(MKMapRect.null) { partial, point in
      partial.union(MKMapRect(origin: point, size: MKMapSize(width: 0, height: 0)))
    }
    let padded = mapView.mapRectThatFits(
      rect,
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

  private func meetupPayload(from raw: Any?) -> (coordinate: CLLocationCoordinate2D, label: String)? {
    guard let values = raw as? [String: Any],
          let coordinate = coordinate(from: values["position"])
    else {
      return nil
    }

    return (coordinate, values["label"] as? String ?? "Meetup")
  }

  private func convoyMemberPayloads(
    from raw: Any?,
    excludingUserId: String?
  ) -> [(userId: String, label: String, coordinate: CLLocationCoordinate2D, markerStyle: CruizXUserMarkerStyle)] {
    guard let items = raw as? [Any] else { return [] }
    return items.compactMap { item in
      guard let values = item as? [String: Any],
            let userId = values["userId"] as? String,
            let coordinate = coordinate(from: values["position"])
      else {
        return nil
      }
      if let excludingUserId, userId == excludingUserId {
        return nil
      }
      return (
        userId,
        values["userLabel"] as? String ?? "Rider",
        coordinate,
        markerStyle(from: values["markerStyle"])
      )
    }
  }

  private func convoyPinPayloads(
    from raw: Any?
  ) -> [(pinId: String, label: String, type: String, coordinate: CLLocationCoordinate2D)] {
    guard let items = raw as? [Any] else { return [] }
    return items.compactMap { item in
      guard let values = item as? [String: Any],
            let pinId = values["pinId"] as? String,
            let coordinate = coordinate(from: values["position"])
      else {
        return nil
      }
      return (
        pinId,
        values["label"] as? String ?? "Pin",
        values["type"] as? String ?? "custom",
        coordinate
      )
    }
  }

  private func alertPayloads(
    from raw: Any?
  ) -> [(alertId: String, label: String, typeKey: String, emoji: String, coordinate: CLLocationCoordinate2D)] {
    guard let items = raw as? [Any] else { return [] }
    return items.compactMap { item in
      guard let values = item as? [String: Any],
            let alertId = values["id"] as? String,
            let coordinate = coordinate(from: values["position"])
      else {
        return nil
      }
      return (
        alertId,
        values["description"] as? String ?? "Alert",
        values["typeKey"] as? String ?? "hazard",
        values["emoji"] as? String ?? "⚠️",
        coordinate
      )
    }
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

  private func userMarkerAnimationDuration(
    from oldCoordinate: CLLocationCoordinate2D,
    to newCoordinate: CLLocationCoordinate2D,
    sampleInterval: TimeInterval?
  ) -> CFTimeInterval? {
    guard !isFollowingUser else { return nil }

    let oldLocation = CLLocation(latitude: oldCoordinate.latitude, longitude: oldCoordinate.longitude)
    let newLocation = CLLocation(latitude: newCoordinate.latitude, longitude: newCoordinate.longitude)
    let distance = oldLocation.distance(from: newLocation)

    // Keep the marker gliding through most of the GPS interval so it doesn't
    // jump forward briefly and then freeze until the next sample arrives.
    guard distance >= 0.8, distance <= 120 else { return nil }
    let interval = min(max(sampleInterval ?? 0.9, 0.45), 1.20)

    switch distance {
    case ..<2:
      return min(interval * 0.58, 0.48)
    case ..<8:
      return min(interval * 0.78, 0.72)
    case ..<25:
      return min(interval * 0.88, 0.82)
    case ..<70:
      return min(interval * 0.92, 0.88)
    default:
      return min(interval * 0.95, 0.94)
    }
  }

  private func isTrimmedContinuation(
    _ newPoints: [CLLocationCoordinate2D],
    of oldPoints: [CLLocationCoordinate2D]
  ) -> Bool {
    guard newPoints.count >= 2, oldPoints.count >= 2 else { return false }

    // The first point moves continuously because Flutter projects it onto the
    // active road segment. Everything after it must remain an exact suffix of
    // the original route for this to count as progress rather than a reroute.
    let newSuffix = Array(newPoints.dropFirst())
    guard let firstSuffixPoint = newSuffix.first else { return false }
    for oldIndex in 1..<oldPoints.count where coordinatesEqual(
      firstSuffixPoint,
      oldPoints[oldIndex]
    ) {
      let oldSuffix = Array(oldPoints[oldIndex...])
      if sameCoordinates(newSuffix, oldSuffix) {
        return true
      }
    }
    return false
  }

  private func coordinatesEqual(
    _ lhs: CLLocationCoordinate2D,
    _ rhs: CLLocationCoordinate2D
  ) -> Bool {
    abs(lhs.latitude - rhs.latitude) <= 0.000001 &&
      abs(lhs.longitude - rhs.longitude) <= 0.000001
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

  private func projectedOntoNavigationRoute(
    _ coordinate: CLLocationCoordinate2D
  ) -> (coordinate: CLLocationCoordinate2D, distanceMeters: CLLocationDistance)? {
    guard navigationRoutePoints.count >= 2 else { return nil }

    let point = MKMapPoint(coordinate)
    let lastSegment = min(navigationRoutePoints.count - 2, 50)
    var bestPoint: MKMapPoint?
    var bestDistance = CLLocationDistance.greatestFiniteMagnitude

    for index in 0...lastSegment {
      let start = MKMapPoint(navigationRoutePoints[index])
      let end = MKMapPoint(navigationRoutePoints[index + 1])
      let dx = end.x - start.x
      let dy = end.y - start.y
      let lengthSquared = dx * dx + dy * dy
      guard lengthSquared > 0.000_001 else { continue }

      let rawProgress = ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared
      let progress = min(max(rawProgress, 0), 1)
      let projected = MKMapPoint(
        x: start.x + progress * dx,
        y: start.y + progress * dy
      )
      let distance = point.distance(to: projected)
      if distance < bestDistance {
        bestDistance = distance
        bestPoint = projected
      }
    }

    guard let bestPoint else { return nil }
    return (bestPoint.coordinate, bestDistance)
  }

  private func interpolatedCoordinate(
    from start: CLLocationCoordinate2D,
    to end: CLLocationCoordinate2D,
    progress: Double
  ) -> CLLocationCoordinate2D {
    let clamped = min(max(progress, 0), 1)
    return CLLocationCoordinate2D(
      latitude: start.latitude + (end.latitude - start.latitude) * clamped,
      longitude: start.longitude + (end.longitude - start.longitude) * clamped
    )
  }

  private func bearingDegrees(
    from start: CLLocationCoordinate2D,
    to end: CLLocationCoordinate2D
  ) -> Double {
    let lat1 = start.latitude * .pi / 180
    let lat2 = end.latitude * .pi / 180
    let deltaLon = (end.longitude - start.longitude) * .pi / 180
    let y = sin(deltaLon) * cos(lat2)
    let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)
    let degrees = atan2(y, x) * 180 / .pi
    return normalizedDegrees(degrees)
  }

  private func projectedCoordinate(
    from start: CLLocationCoordinate2D,
    distanceMeters: Double,
    headingDegrees: Double
  ) -> CLLocationCoordinate2D {
    let earthRadius = 6_371_000.0
    let angularDistance = distanceMeters / earthRadius
    let bearing = headingDegrees * .pi / 180
    let lat1 = start.latitude * .pi / 180
    let lon1 = start.longitude * .pi / 180

    let lat2 = asin(
      sin(lat1) * cos(angularDistance) +
      cos(lat1) * sin(angularDistance) * cos(bearing)
    )
    let lon2 = lon1 + atan2(
      sin(bearing) * sin(angularDistance) * cos(lat1),
      cos(angularDistance) - sin(lat1) * sin(lat2)
    )

    return CLLocationCoordinate2D(
      latitude: lat2 * 180 / .pi,
      longitude: lon2 * 180 / .pi
    )
  }

  private func markerStyle(from raw: Any?) -> CruizXUserMarkerStyle {
    guard let values = raw as? [String: Any] else {
      return .fallback
    }

    return CruizXUserMarkerStyle(
      assetPath: values["assetPath"] as? String,
      iconName: values["iconName"] as? String,
      tintColor: color(from: values["tintArgb"]) ?? CruizXUserMarkerStyle.fallback.tintColor,
      rotatesWithHeading: values["rotatesWithHeading"] as? Bool ?? false
    )
  }

  private func color(from raw: Any?) -> UIColor? {
    guard let argb = raw as? NSNumber else { return nil }
    let value = UInt32(argb.int64Value)
    let alpha = CGFloat((value >> 24) & 0xff) / 255
    let red = CGFloat((value >> 16) & 0xff) / 255
    let green = CGFloat((value >> 8) & 0xff) / 255
    let blue = CGFloat(value & 0xff) / 255
    return UIColor(red: red, green: green, blue: blue, alpha: alpha)
  }

  private func convoyPinColor(for type: String) -> UIColor {
    switch type {
    case "meetup":
      return UIColor(red: 0.12, green: 0.53, blue: 0.90, alpha: 1)
    case "parking":
      return UIColor(red: 0.01, green: 0.47, blue: 0.74, alpha: 1)
    case "food_stop":
      return UIColor(red: 0.94, green: 0.42, blue: 0.00, alpha: 1)
    case "charging":
      return UIColor(red: 0.00, green: 0.66, blue: 0.42, alpha: 1)
    case "hangout":
      return UIColor(red: 1.00, green: 0.70, blue: 0.00, alpha: 1)
    default:
      return UIColor(red: 0.20, green: 0.52, blue: 1.00, alpha: 1)
    }
  }

  private func convoyPinGlyph(for type: String) -> String {
    switch type {
    case "meetup":
      return "mappin"
    case "parking":
      return "parkingsign"
    case "food_stop":
      return "fork.knife"
    case "charging":
      return "bolt.car"
    case "hangout":
      return "star"
    default:
      return "mappin"
    }
  }

  private func alertColor(for typeKey: String) -> UIColor {
    switch typeKey {
    case "road_closure":
      return UIColor(red: 0.72, green: 0.11, blue: 0.11, alpha: 1)
    case "police":
      return UIColor(red: 0.08, green: 0.40, blue: 0.75, alpha: 1)
    case "roadwork":
      return UIColor(red: 0.90, green: 0.32, blue: 0.00, alpha: 1)
    case "accident":
      return UIColor(red: 0.78, green: 0.16, blue: 0.16, alpha: 1)
    case "traffic_jam":
      return UIColor(red: 0.96, green: 0.50, blue: 0.09, alpha: 1)
    case "speed_camera":
      return UIColor(red: 0.42, green: 0.11, blue: 0.60, alpha: 1)
    case "narrow_road":
      return UIColor(red: 0.00, green: 0.41, blue: 0.36, alpha: 1)
    case "steep_hill":
      return UIColor(red: 0.22, green: 0.29, blue: 0.31, alpha: 1)
    case "speed_bump":
      return UIColor(red: 1.00, green: 0.48, blue: 0.00, alpha: 1)
    case "meetup":
      return UIColor(red: 0.12, green: 0.53, blue: 0.90, alpha: 1)
    case "parking":
      return UIColor(red: 0.01, green: 0.47, blue: 0.74, alpha: 1)
    case "food_stop":
      return UIColor(red: 0.94, green: 0.42, blue: 0.00, alpha: 1)
    case "charging":
      return UIColor(red: 0.00, green: 0.66, blue: 0.42, alpha: 1)
    case "hangout":
      return UIColor(red: 1.00, green: 0.70, blue: 0.00, alpha: 1)
    default:
      return UIColor(red: 0.29, green: 0.08, blue: 0.55, alpha: 1)
    }
  }

  private func updateUserAnnotationViewIfNeeded() {
    guard hasUserAnnotation,
          let view = mapView.view(for: userAnnotation)
    else {
      return
    }

    configureUserAnnotationView(view)
  }

  private func updateUserAnnotationHeadingIfNeeded() {
    guard hasUserAnnotation,
          let view = mapView.view(for: userAnnotation)
    else {
      return
    }

    let effectiveHeading = resolvedUserHeading()
    applyHeading(effectiveHeading, to: view)
  }

  private func configureUserAnnotationView(_ view: MKAnnotationView) {
    view.canShowCallout = false
    view.annotation = userAnnotation
    view.isHidden = hideUserMarkerWhenFollowing && isFollowingUser

    if let assetPath = userMarkerStyle.assetPath,
       let image = markerImage(for: assetPath) {
      view.image = image
      view.centerOffset = .zero
    } else {
      view.image = symbolMarkerImage(
        iconName: userMarkerStyle.iconName ?? "navigation",
        tintColor: userMarkerStyle.tintColor
      )
      view.centerOffset = .zero
    }

    let effectiveHeading = resolvedUserHeading()
    applyHeading(effectiveHeading, to: view)
  }

  private func resolvedUserHeading() -> Double {
    if isFollowingUser {
      return lastHeading
    }
    // Non-follow: while essentially stationary, point the marker the way the
    // phone physically points (live compass). Once moving, keep the travel
    // heading so the marker tracks direction of movement, not phone tilt.
    if lastUserVelocityMps < 1.5, let compass = deviceCompassHeading {
      return compass
    }
    return lastHeading
  }

  private func applyHeading(_ heading: Double, to view: MKAnnotationView) {
    guard userMarkerStyle.rotatesWithHeading else {
      renderedUserHeading = 0
      hasRenderedUserHeading = false
      view.layer.removeAnimation(forKey: "cruizx.userHeading")
      view.transform = .identity
      return
    }

    if isFollowingUser {
      // Map is heading-up: rotate the marker only by its offset from the
      // camera heading so it points along travel (straight up once aligned).
      applyFollowMarkerRotation(view: view)
      return
    }

    let normalizedHeading = normalizedDegrees(heading)
    if !hasRenderedUserHeading {
      renderedUserHeading = normalizedHeading
      hasRenderedUserHeading = true
    } else {
      let shortestTurn = shortestDegrees(from: renderedUserHeading, to: normalizedHeading)
      let turnMagnitude = abs(shortestTurn)
      if turnMagnitude < 1.5 {
        return
      }

      if turnMagnitude > 120 {
        renderedUserHeading = normalizedHeading
      } else {
        let blend: Double
        if isFollowingUser {
          blend = 1.0
        } else if turnMagnitude > 32 {
          blend = 0.46
        } else if turnMagnitude > 14 {
          blend = 0.34
        } else {
          blend = 0.24
        }
        renderedUserHeading = normalizedDegrees(renderedUserHeading + shortestTurn * blend)
      }
    }

    let angle = CGFloat(renderedUserHeading * .pi / 180)
    UIView.performWithoutAnimation {
      view.transform = CGAffineTransform(rotationAngle: angle)
      view.layer.removeAnimation(forKey: "cruizx.userHeading")
    }
  }

  /// During navigation the marker stays straight ahead, matching CarPlay.
  /// The map camera carries all heading changes underneath it.
  private func applyFollowMarkerRotation(view: MKAnnotationView) {
    UIView.performWithoutAnimation {
      view.transform = .identity
      view.layer.removeAnimation(forKey: "cruizx.userHeading")
    }
  }

  private func markerImage(for assetPath: String) -> UIImage? {
    if let cached = markerImageCache[assetPath] {
      return cached
    }

    let lookupKey = FlutterDartProject.lookupKey(forAsset: assetPath)
    let candidatePaths = [
      Bundle.main.bundlePath + "/" + lookupKey,
      Bundle.main.bundlePath + "/Frameworks/App.framework/" + lookupKey,
      Bundle.main.bundlePath + "/Frameworks/App.framework/flutter_assets/" + assetPath,
      Bundle.main.bundlePath + "/Frameworks/App.framework/flutter_assets/" + assetPath.replacingOccurrences(of: " ", with: "%20")
    ]

    for path in candidatePaths {
      guard FileManager.default.fileExists(atPath: path),
            let image = UIImage(contentsOfFile: path)
      else {
        continue
      }

      let scaled = scaledMarkerImage(image, maxDimension: 34)
      markerImageCache[assetPath] = scaled
      return scaled
    }

    return nil
  }

  private func scaledMarkerImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
    let originalSize = image.size
    guard originalSize.width > 0, originalSize.height > 0 else { return image }

    let scale = min(maxDimension / originalSize.width, maxDimension / originalSize.height)
    guard scale < 1 else { return image }

    let targetSize = CGSize(
      width: originalSize.width * scale,
      height: originalSize.height * scale
    )
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = UIScreen.main.scale
    let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
    return renderer.image { _ in
      image.draw(in: CGRect(origin: .zero, size: targetSize))
    }
  }

  private func scaledMarkerImage(_ image: UIImage, to targetSize: CGSize) -> UIImage {
    guard targetSize.width > 0, targetSize.height > 0 else { return image }
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = UIScreen.main.scale
    let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
    return renderer.image { _ in
      image.draw(in: CGRect(origin: .zero, size: targetSize))
    }
  }

  private func convoyMemberImage(label: String, markerStyle: CruizXUserMarkerStyle) -> UIImage {
    let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
    let font = UIFont.systemFont(ofSize: 9, weight: .semibold)
    let labelPaddingX: CGFloat = 6
    let labelPaddingY: CGFloat = 2
    let markerDiameter: CGFloat = 24
    let spacing: CGFloat = 2
    let maxLabelWidth: CGFloat = 96

    let rawTextSize = (trimmedLabel as NSString).size(withAttributes: [.font: font])
    let labelWidth = min(maxLabelWidth, ceil(rawTextSize.width) + labelPaddingX * 2)
    let labelHeight = ceil(rawTextSize.height) + labelPaddingY * 2
    let canvasWidth = max(markerDiameter, labelWidth)
    let canvasHeight = labelHeight + spacing + markerDiameter
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = UIScreen.main.scale
    let renderer = UIGraphicsImageRenderer(
      size: CGSize(width: canvasWidth, height: canvasHeight),
      format: format
    )

    return renderer.image { _ in
      let labelRect = CGRect(
        x: (canvasWidth - labelWidth) / 2,
        y: 0,
        width: labelWidth,
        height: labelHeight
      )
      let labelPath = UIBezierPath(roundedRect: labelRect, cornerRadius: 8)
      let fillColor = markerStyle.tintColor.withAlphaComponent(0.95)
      fillColor.setFill()
      labelPath.fill()
      UIColor.white.withAlphaComponent(0.24).setStroke()
      labelPath.lineWidth = 1
      labelPath.stroke()

      let paragraph = NSMutableParagraphStyle()
      paragraph.alignment = .center
      let textRect = CGRect(
        x: labelRect.minX + labelPaddingX,
        y: labelRect.minY + labelPaddingY - 0.5,
        width: labelRect.width - labelPaddingX * 2,
        height: rawTextSize.height + 2
      )
      (trimmedLabel as NSString).draw(
        in: textRect,
        withAttributes: [
          .font: font,
          .foregroundColor: UIColor.white,
          .paragraphStyle: paragraph,
        ]
      )

      let iconRect = CGRect(
        x: (canvasWidth - markerDiameter) / 2,
        y: labelHeight + spacing,
        width: markerDiameter,
        height: markerDiameter
      )

      if let assetPath = markerStyle.assetPath,
         let image = markerImage(for: assetPath) {
        let scaledAsset = scaledMarkerImage(
          image,
          to: CGSize(width: markerDiameter, height: markerDiameter)
        )
        scaledAsset.draw(in: iconRect)
      } else {
        let iconImage = symbolMarkerImage(
          iconName: markerStyle.iconName ?? "navigation",
          tintColor: markerStyle.tintColor
        )
        let scaledIcon = scaledMarkerImage(
          iconImage,
          to: CGSize(width: markerDiameter, height: markerDiameter)
        )
        scaledIcon.draw(in: iconRect)
      }
    }
  }

  private func symbolMarkerImage(iconName: String, tintColor: UIColor) -> UIImage {
    let size = CGSize(width: 40, height: 40)
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = UIScreen.main.scale
    let renderer = UIGraphicsImageRenderer(size: size, format: format)

    return renderer.image { _ in
      if iconName == "flatArrow" {
        let outlineSize: CGFloat = 23
        let symbolSize = CGSize(width: outlineSize, height: outlineSize)
        let outlineConfiguration = UIImage.SymbolConfiguration(pointSize: outlineSize, weight: .bold)
        let outlineSymbol = UIImage(systemName: "paperplane.fill", withConfiguration: outlineConfiguration)?
          .withTintColor(.white, renderingMode: .alwaysOriginal)
        let fillConfiguration = UIImage.SymbolConfiguration(pointSize: 20, weight: .bold)
        let fillSymbol = UIImage(systemName: "paperplane.fill", withConfiguration: fillConfiguration)?
          .withTintColor(tintColor, renderingMode: .alwaysOriginal)
        let origin = CGPoint(
          x: (size.width - symbolSize.width) / 2,
          y: (size.height - symbolSize.height) / 2
        )

        if let context = UIGraphicsGetCurrentContext() {
          context.saveGState()
          context.setShadow(
            offset: .zero,
            blur: 12,
            color: tintColor.withAlphaComponent(0.40).cgColor
          )
          fillSymbol?.draw(in: CGRect(origin: origin, size: symbolSize))
          context.restoreGState()
        }

        outlineSymbol?.draw(in: CGRect(origin: origin, size: symbolSize))
        let insetOrigin = CGPoint(
          x: origin.x + 1.5,
          y: origin.y + 1.5
        )
        let insetSize = CGSize(width: symbolSize.width - 3, height: symbolSize.height - 3)
        fillSymbol?.draw(in: CGRect(origin: insetOrigin, size: insetSize))
        return
      }

      let rect = CGRect(origin: .zero, size: size)
      // Inset the circle so the white ring and its antialiased edge fit inside
      // the canvas instead of being clipped flat by the image bounds.
      let circleRect = rect.insetBy(dx: 5, dy: 5)
      let circlePath = UIBezierPath(ovalIn: circleRect)
      let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
          tintColor.withAlphaComponent(0.72).cgColor,
          tintColor.cgColor,
        ] as CFArray,
        locations: [0, 1]
      )

      if let context = UIGraphicsGetCurrentContext() {
        // Soft drop shadow gives the round marker depth and a clean edge.
        context.saveGState()
        context.setShadow(
          offset: CGSize(width: 0, height: 1),
          blur: 6,
          color: UIColor.black.withAlphaComponent(0.35).cgColor
        )
        tintColor.setFill()
        circlePath.fill()
        context.restoreGState()
      }

      if let gradient, let context = UIGraphicsGetCurrentContext() {
        context.saveGState()
        circlePath.addClip()
        context.drawLinearGradient(
          gradient,
          start: CGPoint(x: circleRect.minX, y: circleRect.minY),
          end: CGPoint(x: circleRect.maxX, y: circleRect.maxY),
          options: []
        )
        context.restoreGState()
      }

      UIColor.white.setStroke()
      circlePath.lineWidth = 2.2
      circlePath.stroke()

      let pointSize: CGFloat
      switch iconName {
      case "dot":
        pointSize = 11
      case "triangle":
        pointSize = 15
      default:
        pointSize = 17
      }
      let configuration = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .bold)
      let symbolName: String
      switch iconName {
      case "compass":
        symbolName = "location.north.line.fill"
      case "triangle":
        symbolName = "triangle.fill"
      case "dot":
        symbolName = "circle.fill"
      default:
        symbolName = "paperplane.fill"
      }

      let symbol = UIImage(systemName: symbolName, withConfiguration: configuration)?
        .withTintColor(.white, renderingMode: .alwaysOriginal)
      let symbolSize = CGSize(width: pointSize, height: pointSize)
      let origin = CGPoint(
        x: (size.width - symbolSize.width) / 2,
        y: (size.height - symbolSize.height) / 2
      )
      symbol?.draw(in: CGRect(origin: origin, size: symbolSize))
    }
  }

  @objc
  private func handleTap(_ recognizer: UITapGestureRecognizer) {
    guard recognizer.state == .ended else { return }
    let point = recognizer.location(in: mapView)
    for annotation in mapView.annotations {
      guard let view = mapView.view(for: annotation),
            !view.frame.isEmpty
      else {
        continue
      }
      let expandedFrame = view.frame.insetBy(dx: -10, dy: -10)
      if expandedFrame.contains(point) {
        return
      }
    }
    let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
    channel.invokeMethod("mapTapped", arguments: [
      "latitude": coordinate.latitude,
      "longitude": coordinate.longitude,
    ])
  }

  private func attachFollowReleaseTargetsIfNeeded() {
    guard !followReleaseTargetsAttached else { return }
    followReleaseTargetsAttached = true
    for recognizer in mapView.gestureRecognizers ?? [] {
      guard recognizer is UIPanGestureRecognizer ||
            recognizer is UIPinchGestureRecognizer ||
            recognizer is UIRotationGestureRecognizer
      else {
        continue
      }
      recognizer.addTarget(self, action: #selector(handleMapInteractionGesture(_:)))
    }
  }

  @objc
  private func handleMapInteractionGesture(_ recognizer: UIGestureRecognizer) {
    switch recognizer.state {
    case .began:
      notifyDirectUserPanIfNeeded()
    case .ended, .cancelled, .failed:
      didNotifyUserPan = false
    default:
      break
    }
  }

  private func notifyDirectUserPanIfNeeded() {
    guard isFollowingUser else { return }
    guard !didNotifyUserPan else { return }
    isFollowingUser = false
    lastFollowUser = false
    suppressUserPanUntil = Date.distantPast
    let frozenCamera = mapView.camera.copy() as? MKMapCamera ?? mapView.camera
    mapView.setCamera(frozenCamera, animated: false)
    didNotifyUserPan = true
    channel.invokeMethod("userPanned", arguments: nil)
  }

  private func notifyUserPanIfNeeded() {
    guard isFollowingUser else { return }
    guard Date() >= suppressUserPanUntil else { return }
    guard !didNotifyUserPan else { return }
    didNotifyUserPan = true
    channel.invokeMethod("userPanned", arguments: nil)
  }

  func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
    guard isGestureDrivenChange() else { return }
    notifyUserPanIfNeeded()
  }

  func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
    if !isGestureDrivenChange() {
      didNotifyUserPan = false
    }
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
        ?? MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
      configureUserAnnotationView(view)
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
        marker.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
      }
      return view
    }

    if annotation === meetupAnnotation {
      let identifier = "CruizXMeetup"
      let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
        ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
      view.annotation = annotation
      if let marker = view as? MKMarkerAnnotationView {
        marker.markerTintColor = UIColor(red: 0.12, green: 0.53, blue: 0.90, alpha: 1)
        marker.glyphImage = UIImage(systemName: "flag.fill")
        marker.titleVisibility = .adaptive
        marker.subtitleVisibility = .hidden
        marker.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
      }
      return view
    }

    if let member = annotation as? CruizXConvoyMemberAnnotation {
      let identifier = "CruizXConvoyMember"
      let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
        ?? MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
      view.annotation = annotation
      view.canShowCallout = false
      view.image = convoyMemberImage(
        label: member.title ?? "Rider",
        markerStyle: member.markerStyle
      )
      view.centerOffset = CGPoint(x: 0, y: -12)
      return view
    }

    if let pin = annotation as? CruizXConvoyPinAnnotation {
      let identifier = "CruizXConvoyPin"
      let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
        ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
      view.annotation = annotation
      if let marker = view as? MKMarkerAnnotationView {
        marker.markerTintColor = convoyPinColor(for: pin.pinType)
        marker.glyphImage = UIImage(systemName: convoyPinGlyph(for: pin.pinType))
        marker.titleVisibility = .adaptive
        marker.subtitleVisibility = .hidden
        marker.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
      }
      return view
    }

    if let alert = annotation as? CruizXAlertAnnotation {
      let identifier = "CruizXAlert"
      let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
        ?? MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
      view.annotation = annotation
      view.canShowCallout = false
      view.image = alertMarkerImage(emoji: alert.emoji, color: alertColor(for: alert.typeKey))
      view.centerOffset = CGPoint(x: 0, y: -2)
      return view
    }

    return nil
  }

  func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
    defer {
      if let annotation = view.annotation {
        mapView.deselectAnnotation(annotation, animated: false)
      }
    }

    if let member = view.annotation as? CruizXConvoyMemberAnnotation {
      channel.invokeMethod("memberTapped", arguments: ["userId": member.userId])
      return
    }

    if let pin = view.annotation as? CruizXConvoyPinAnnotation {
      channel.invokeMethod("pinTapped", arguments: ["pinId": pin.pinId])
      return
    }

    if view.annotation === meetupAnnotation {
      channel.invokeMethod("meetupTapped", arguments: nil)
    }
  }

  private func isGestureDrivenChange() -> Bool {
    let states: [UIGestureRecognizer.State] = [.began, .changed, .ended]
    return (mapView.gestureRecognizers ?? []).contains { states.contains($0.state) }
  }

  func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
    guard newHeading.headingAccuracy >= 0 else { return }
    let rawHeading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
    guard rawHeading.isFinite else { return }
    deviceCompassHeading = normalizedDegrees(rawHeading)
    if !isFollowingUser {
      updateUserAnnotationHeadingIfNeeded()
    }
  }

  func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
    false
  }

  private func normalizedDegrees(_ value: Double) -> Double {
    let normalized = value.truncatingRemainder(dividingBy: 360)
    return normalized >= 0 ? normalized : normalized + 360
  }

  private func shortestDegrees(from: Double, to: Double) -> Double {
    let fromValue = normalizedDegrees(from)
    let toValue = normalizedDegrees(to)
    return ((toValue - fromValue + 540).truncatingRemainder(dividingBy: 360)) - 180
  }

  private func alertMarkerImage(emoji: String, color: UIColor) -> UIImage {
    let size = CGSize(width: 36, height: 42)
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = UIScreen.main.scale
    let renderer = UIGraphicsImageRenderer(size: size, format: format)

    return renderer.image { _ in
      let bodyRect = CGRect(x: 3, y: 2, width: 30, height: 30)
      let bodyPath = UIBezierPath(roundedRect: bodyRect, cornerRadius: 10)
      color.setFill()
      bodyPath.fill()

      UIColor.white.setStroke()
      bodyPath.lineWidth = 1.5
      bodyPath.stroke()

      let paragraph = NSMutableParagraphStyle()
      paragraph.alignment = .center
      let textRect = CGRect(x: 4, y: 6, width: 28, height: 22)
      let attrs: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: 18),
        .paragraphStyle: paragraph,
      ]
      emoji.draw(in: textRect, withAttributes: attrs)

      let tailPath = UIBezierPath()
      tailPath.move(to: CGPoint(x: size.width / 2 - 4.5, y: 31))
      tailPath.addLine(to: CGPoint(x: size.width / 2 + 4.5, y: 31))
      tailPath.addLine(to: CGPoint(x: size.width / 2, y: 38))
      tailPath.close()
      color.setFill()
      tailPath.fill()
    }
  }
}
