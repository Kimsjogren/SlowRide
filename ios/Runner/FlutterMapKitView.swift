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

final class FlutterMapKitView: NSObject, FlutterPlatformView, MKMapViewDelegate, CLLocationManagerDelegate {
  private let mapView = MKMapView()
  private let channel: FlutterMethodChannel
  private let locationManager = CLLocationManager()
  private let userAnnotation = MKPointAnnotation()
  private let destinationAnnotation = MKPointAnnotation()
  private var hasUserAnnotation = false
  private var hasDestinationAnnotation = false
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
    let followUser = payload["followUser"] as? Bool ?? false
    let use3D = payload["use3D"] as? Bool ?? true
    let darkMode = payload["darkMode"] as? Bool ?? false
    let markerStyle = markerStyle(from: payload["markerStyle"])
    let nextManeuverDistanceMeters = doubleValue(payload["nextManeuverDistanceMeters"])
    let routeChanged = !sameCoordinates(routePoints, lastRoutePoints)
    let routeTrimmedOnly = isTrimmedContinuation(routePoints, of: lastRoutePoints)
    let followModeChanged = followUser != lastFollowUser

    mapView.overrideUserInterfaceStyle = darkMode ? .dark : .light
    isFollowingUser = followUser
    if markerStyle != userMarkerStyle {
      userMarkerStyle = markerStyle
      updateUserAnnotationViewIfNeeded()
    } else if isFollowingUser {
      updateUserAnnotationHeadingIfNeeded()
    }

    updateUserAnnotation(with: location)
    updateDestinationAnnotation(with: destination)
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
    updateUserAnnotationHeadingIfNeeded()
  }

  private func updateUserAnnotation(with coordinate: CLLocationCoordinate2D?) {
    guard let coordinate else { return }

    if !hasUserAnnotation {
      hasUserAnnotation = true
      userAnnotation.title = "Du"
      userAnnotation.coordinate = coordinate
      mapView.addAnnotation(userAnnotation)
      updateUserAnnotationViewIfNeeded()
      return
    }

    let previousCoordinate = userAnnotation.coordinate
    if let animationDuration = userMarkerAnimationDuration(
      from: previousCoordinate,
      to: coordinate
    ) {
      CATransaction.begin()
      CATransaction.setAnimationDuration(animationDuration)
      CATransaction.setAnimationTimingFunction(
        CAMediaTimingFunction(name: .easeInEaseOut)
      )
      userAnnotation.coordinate = coordinate
      CATransaction.commit()
    } else {
      userAnnotation.coordinate = coordinate
    }
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
    routeTrimmedOnly: Bool,
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

  private func userMarkerAnimationDuration(
    from oldCoordinate: CLLocationCoordinate2D,
    to newCoordinate: CLLocationCoordinate2D
  ) -> CFTimeInterval? {
    guard !isFollowingUser else { return nil }

    let oldLocation = CLLocation(latitude: oldCoordinate.latitude, longitude: oldCoordinate.longitude)
    let newLocation = CLLocation(latitude: newCoordinate.latitude, longitude: newCoordinate.longitude)
    let distance = oldLocation.distance(from: newLocation)

    // Apple-like feel: animate normal movement briefly, but snap tiny jitter
    // and larger GPS jumps so the marker doesn't lag behind reality.
    guard distance >= 0.8, distance <= 120 else { return nil }

    switch distance {
    case ..<3:
      return 0.18
    case ..<10:
      return 0.28
    case ..<30:
      return 0.40
    case ..<70:
      return 0.55
    default:
      return 0.72
    }
  }

  private func isTrimmedContinuation(
    _ newPoints: [CLLocationCoordinate2D],
    of oldPoints: [CLLocationCoordinate2D]
  ) -> Bool {
    guard !newPoints.isEmpty,
          newPoints.count < oldPoints.count
    else {
      return false
    }

    let expectedSuffix = oldPoints.suffix(newPoints.count)
    return sameCoordinates(newPoints, Array(expectedSuffix))
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

    let effectiveHeading = isFollowingUser ? lastHeading : (deviceCompassHeading ?? lastHeading)
    applyHeading(effectiveHeading, to: view)
  }

  private func configureUserAnnotationView(_ view: MKAnnotationView) {
    view.canShowCallout = false
    view.annotation = userAnnotation

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

    let effectiveHeading = isFollowingUser ? lastHeading : (deviceCompassHeading ?? lastHeading)
    applyHeading(effectiveHeading, to: view)
  }

  private func applyHeading(_ heading: Double, to view: MKAnnotationView) {
    guard userMarkerStyle.rotatesWithHeading else {
      renderedUserHeading = 0
      hasRenderedUserHeading = false
      view.layer.removeAnimation(forKey: "cruizx.userHeading")
      view.transform = .identity
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

      let scaled = scaledMarkerImage(image, maxDimension: 40)
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

  private func symbolMarkerImage(iconName: String, tintColor: UIColor) -> UIImage {
    let size = CGSize(width: 38, height: 38)
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = UIScreen.main.scale
    let renderer = UIGraphicsImageRenderer(size: size, format: format)

    return renderer.image { _ in
      if iconName == "flatArrow" {
        let outlineSize: CGFloat = 27
        let symbolSize = CGSize(width: outlineSize, height: outlineSize)
        let outlineConfiguration = UIImage.SymbolConfiguration(pointSize: outlineSize, weight: .bold)
        let outlineSymbol = UIImage(systemName: "paperplane.fill", withConfiguration: outlineConfiguration)?
          .withTintColor(.white, renderingMode: .alwaysOriginal)
        let fillConfiguration = UIImage.SymbolConfiguration(pointSize: 24, weight: .bold)
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
      let circlePath = UIBezierPath(ovalIn: rect)
      let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
          tintColor.withAlphaComponent(0.72).cgColor,
          tintColor.cgColor,
        ] as CFArray,
        locations: [0, 1]
      )

      if let gradient {
        UIGraphicsGetCurrentContext()?.saveGState()
        circlePath.addClip()
        UIGraphicsGetCurrentContext()?.drawLinearGradient(
          gradient,
          start: CGPoint(x: 0, y: 0),
          end: CGPoint(x: size.width, y: size.height),
          options: []
        )
        UIGraphicsGetCurrentContext()?.restoreGState()
      } else {
        tintColor.setFill()
        circlePath.fill()
      }

      UIColor.white.setStroke()
      circlePath.lineWidth = 1.8
      circlePath.stroke()

      let pointSize: CGFloat
      switch iconName {
      case "dot":
        pointSize = 13
      case "triangle":
        pointSize = 17
      default:
        pointSize = 19
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
      notifyUserPanIfNeeded()
    case .ended, .cancelled, .failed:
      didNotifyUserPan = false
    default:
      break
    }
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
      }
      return view
    }

    return nil
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
}
