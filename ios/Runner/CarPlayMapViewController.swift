import CarPlay
import MapKit
import UIKit

final class CarPlayMapViewController: UIViewController, MKMapViewDelegate {
  private let mapView = MKMapView()
  private let speedometerCluster = UIView()
  private let speedometerStack = UIStackView()
  private let currentSpeedView = CruizXSegmentedSpeedometerView()
  private let currentSpeedLabel = UILabel()
  private let speedUnitLabel = UILabel()
  private let speedLimitView = UIView()
  private let speedLimitLabel = UILabel()
  private var routeOverlay: MKPolyline?
  private var navigationRouteCoordinates: [CLLocationCoordinate2D] = []
  private var destinationAnnotation: MKPointAnnotation?
  private var navigationAnnotation: CruizXNavigationAnnotation?
  private var convoyAnnotations: [String: CruizXConvoyAnnotation] = [:]
  private var manualConvoyCameraUntil: CFTimeInterval = 0
  private var displayLink: CADisplayLink?
  private var interpolationTargetCoordinate: CLLocationCoordinate2D?
  private var displayedCoordinate: CLLocationCoordinate2D?
  private var filteredTargetHeading = 0.0
  private var displayedHeading = 0.0
  private var lastPositionReceivedAt: CFTimeInterval?
  private var lastRawCoordinate: CLLocationCoordinate2D?
  private var estimatedSpeedMetersPerSecond = 0.0
  private var lastDisplayLinkTimestamp: CFTimeInterval?
  private var isFollowingNavigation = false
  private var lastCameraCoordinate: CLLocationCoordinate2D?
  private var lastCameraHeading: Double?
  private var manualPanStartCenter: MKMapPoint?
  private var manualPanStartVisibleRect: MKMapRect?
  private var manualZoomStartDistance: CLLocationDistance?

  override func viewDidLoad() {
    super.viewDidLoad()

    view.backgroundColor = .black
    configureMapView()
    configureSpeedometers()
    startDisplayLink()
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    startDisplayLink()
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    displayLink?.invalidate()
    displayLink = nil
  }

  deinit {
    displayLink?.invalidate()
  }

  private func configureMapView() {
    mapView.translatesAutoresizingMaskIntoConstraints = false
    mapView.showsCompass = false
    mapView.showsScale = false
    mapView.isScrollEnabled = true
    mapView.isZoomEnabled = true
    mapView.isPitchEnabled = true
    mapView.isRotateEnabled = true
    // Let MapKit own the position marker and its internal GPS smoothing. The
    // camera remains CruizX-controlled so the marker can sit left and above
    // CarPlay's bottom estimates panel instead of being forced to the centre.
    mapView.showsUserLocation = true
    mapView.tintColor = UIColor(red: 0.0, green: 0.64, blue: 1.0, alpha: 1)
    mapView.pointOfInterestFilter = .excludingAll
    mapView.overrideUserInterfaceStyle = .dark
    mapView.delegate = self

    let region = MKCoordinateRegion(
      center: CLLocationCoordinate2D(latitude: 59.3293, longitude: 18.0686),
      span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)
    )
    mapView.setRegion(region, animated: false)

    view.addSubview(mapView)

    NSLayoutConstraint.activate([
      mapView.topAnchor.constraint(equalTo: view.topAnchor),
      mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])
  }

  private func configureSpeedometers() {
    speedometerCluster.translatesAutoresizingMaskIntoConstraints = false
    // Keep the two gauges visually separate from the map without wrapping
    // them in an additional dark panel.
    speedometerCluster.backgroundColor = .clear
    speedometerCluster.isHidden = true
    speedometerCluster.isUserInteractionEnabled = false

    speedometerStack.translatesAutoresizingMaskIntoConstraints = false
    speedometerStack.axis = .vertical
    speedometerStack.alignment = .center
    // Slightly overlap the two circles so they still read as one compact unit.
    speedometerStack.spacing = -3
    speedometerStack.isUserInteractionEnabled = false

    currentSpeedView.translatesAutoresizingMaskIntoConstraints = false
    currentSpeedView.backgroundColor = UIColor(red: 0.025, green: 0.075, blue: 0.20, alpha: 0.96)
    currentSpeedView.layer.cornerRadius = 23

    currentSpeedLabel.translatesAutoresizingMaskIntoConstraints = false
    currentSpeedLabel.textAlignment = .center
    currentSpeedLabel.textColor = .white
    currentSpeedLabel.font = .systemFont(ofSize: 18, weight: .bold)

    speedUnitLabel.translatesAutoresizingMaskIntoConstraints = false
    speedUnitLabel.textAlignment = .center
    speedUnitLabel.textColor = UIColor.white.withAlphaComponent(0.7)
    speedUnitLabel.font = .systemFont(ofSize: 6.5, weight: .semibold)

    currentSpeedView.addSubview(currentSpeedLabel)
    currentSpeedView.addSubview(speedUnitLabel)

    speedLimitView.translatesAutoresizingMaskIntoConstraints = false
    speedLimitView.backgroundColor = .white
    speedLimitView.layer.cornerRadius = 15
    speedLimitView.layer.borderWidth = 2.5
    speedLimitView.layer.borderColor = UIColor(red: 0.78, green: 0.06, blue: 0.08, alpha: 1).cgColor

    speedLimitLabel.translatesAutoresizingMaskIntoConstraints = false
    speedLimitLabel.textAlignment = .center
    speedLimitLabel.textColor = .black
    speedLimitLabel.font = .systemFont(ofSize: 10.5, weight: .bold)
    speedLimitView.addSubview(speedLimitLabel)

    speedometerStack.addArrangedSubview(currentSpeedView)
    speedometerStack.addArrangedSubview(speedLimitView)
    speedometerCluster.addSubview(speedometerStack)
    view.addSubview(speedometerCluster)

    NSLayoutConstraint.activate([
      currentSpeedView.widthAnchor.constraint(equalToConstant: 46),
      currentSpeedView.heightAnchor.constraint(equalToConstant: 46),
      currentSpeedLabel.centerXAnchor.constraint(equalTo: currentSpeedView.centerXAnchor),
      currentSpeedLabel.centerYAnchor.constraint(equalTo: currentSpeedView.centerYAnchor, constant: -4),
      speedUnitLabel.topAnchor.constraint(equalTo: currentSpeedLabel.bottomAnchor, constant: -1),
      speedUnitLabel.centerXAnchor.constraint(equalTo: currentSpeedView.centerXAnchor),
      speedLimitView.widthAnchor.constraint(equalToConstant: 30),
      speedLimitView.heightAnchor.constraint(equalToConstant: 30),
      speedLimitLabel.centerXAnchor.constraint(equalTo: speedLimitView.centerXAnchor),
      speedLimitLabel.centerYAnchor.constraint(equalTo: speedLimitView.centerYAnchor),
      speedometerStack.topAnchor.constraint(equalTo: speedometerCluster.topAnchor, constant: 4),
      speedometerStack.bottomAnchor.constraint(equalTo: speedometerCluster.bottomAnchor, constant: -4),
      speedometerStack.centerXAnchor.constraint(equalTo: speedometerCluster.centerXAnchor),
      speedometerCluster.widthAnchor.constraint(equalToConstant: 46),
      // Keep the combined speed unit in the lower-right navigation area,
      // clear of the bottom trip estimates and the guidance card.
      speedometerCluster.trailingAnchor.constraint(
        equalTo: view.safeAreaLayoutGuide.trailingAnchor,
        constant: -16
      ),
      speedometerCluster.bottomAnchor.constraint(
        equalTo: view.safeAreaLayoutGuide.bottomAnchor,
        constant: -18
      ),
    ])
  }

  func updateSpeedometers(
    currentSpeed: Double,
    roadSpeedLimit: Double?,
    vehicleSpeedLimit: Double?,
    unitLabel: String,
    usesSwedishRoadSign: Bool,
    isNavigating: Bool
  ) {
    guard isViewLoaded else { return }
    let limit = roadSpeedLimit ?? vehicleSpeedLimit
    let isOverLimit = limit.map { $0 > 0 && currentSpeed > $0 + 0.5 } ?? false

    currentSpeedLabel.text = String(Int(max(currentSpeed, 0).rounded()))
    speedUnitLabel.text = unitLabel
    currentSpeedLabel.textColor = isOverLimit ? UIColor(red: 1, green: 0.30, blue: 0.32, alpha: 1) : .white
    let effectiveLimit = limit ?? 0
    currentSpeedView.progress = effectiveLimit > 0
      ? min(max(currentSpeed / effectiveLimit, 0), 1.25)
      : 0
    currentSpeedView.isOverLimit = isOverLimit
    speedLimitLabel.text = limit.map { String(Int($0.rounded())) } ?? "--"
    speedLimitLabel.textColor = limit == nil ? UIColor.black.withAlphaComponent(0.4) : .black
    speedLimitView.backgroundColor = roadSpeedLimit != nil && usesSwedishRoadSign
      ? UIColor(red: 1.0, green: 0.80, blue: 0.0, alpha: 1)
      : .white
    speedLimitView.layer.borderColor = (
      roadSpeedLimit != nil
        ? UIColor(red: 0.89, green: 0.0, blue: 0.13, alpha: 1)
        : UIColor(white: 0.48, alpha: 1)
    ).cgColor
    speedometerCluster.isHidden = !isNavigating
  }

  func updateRoute(
    coordinates: [CLLocationCoordinate2D],
    destination: CLLocationCoordinate2D?,
    isNavigating: Bool
  ) {
    guard isViewLoaded else { return }

    if let routeOverlay {
      mapView.removeOverlay(routeOverlay)
    }
    if let destinationAnnotation {
      mapView.removeAnnotation(destinationAnnotation)
    }

    guard coordinates.count >= 2 else {
      routeOverlay = nil
      navigationRouteCoordinates = []
      destinationAnnotation = nil
      mapView.setUserTrackingMode(.follow, animated: true)
      return
    }

    let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
    routeOverlay = polyline
    navigationRouteCoordinates = coordinates
    mapView.addOverlay(polyline, level: .aboveRoads)

    if let destination {
      let annotation = MKPointAnnotation()
      annotation.coordinate = destination
      annotation.title = "Mål"
      destinationAnnotation = annotation
      mapView.addAnnotation(annotation)
    }

    if !isNavigating {
      mapView.setVisibleMapRect(
        polyline.boundingMapRect,
        edgePadding: UIEdgeInsets(top: 100, left: 70, bottom: 80, right: 70),
        animated: true
      )
    }
  }

  func updateNavigationPosition(
    _ coordinate: CLLocationCoordinate2D?,
    headingDegrees: Double,
    isNavigating: Bool
  ) {
    guard isViewLoaded else { return }
    let wasFollowingNavigation = isFollowingNavigation
    isFollowingNavigation = isNavigating
    if wasFollowingNavigation != isNavigating {
      lastDisplayLinkTimestamp = nil
      lastRawCoordinate = nil
      estimatedSpeedMetersPerSecond = 0
      if isNavigating {
        displayedCoordinate = nil
        interpolationTargetCoordinate = nil
      }
    }
    if !isNavigating, coordinate == nil {
      updateNavigationMarkerVisibility(isNavigating: false, coordinate: mapView.centerCoordinate)
    }
    guard let coordinate else { return }
    let displayTarget = isNavigating ? routeSnappedCoordinate(for: coordinate) : coordinate
    updateNavigationMarkerVisibility(isNavigating: isNavigating, coordinate: displayTarget)
    if isNavigating && mapView.userTrackingMode != .none {
      mapView.setUserTrackingMode(.none, animated: false)
    }
    let normalizedHeading = headingDegrees.normalizedHeading
    let now = CACurrentMediaTime()

    guard displayedCoordinate != nil else {
      displayedCoordinate = displayTarget
      interpolationTargetCoordinate = displayTarget
      displayedHeading = normalizedHeading
      filteredTargetHeading = normalizedHeading
      lastRawCoordinate = coordinate
      if isNavigating {
        updateNavigationMarker(at: displayTarget, headingDegrees: normalizedHeading)
        updateNavigationCamera(at: displayTarget, headingDegrees: normalizedHeading)
      }
      lastPositionReceivedAt = now
      return
    }

    if let previousCoordinate = lastRawCoordinate,
       let previousReceivedAt = lastPositionReceivedAt {
      let elapsed = now - previousReceivedAt
      if elapsed > 0.02 {
        let measuredSpeed = MKMapPoint(previousCoordinate).distance(
          to: MKMapPoint(coordinate)
        ) / elapsed
        estimatedSpeedMetersPerSecond = estimatedSpeedMetersPerSecond <= 0
          ? measuredSpeed
          : estimatedSpeedMetersPerSecond * 0.65 + measuredSpeed * 0.35
      }
    }

    if let previousTarget = interpolationTargetCoordinate {
      let correctionDistance = MKMapPoint(previousTarget).distance(to: MKMapPoint(displayTarget))
      if estimatedSpeedMetersPerSecond > 3, correctionDistance < 25 {
        interpolationTargetCoordinate = previousTarget.interpolated(to: displayTarget, fraction: 0.22)
      } else {
        interpolationTargetCoordinate = displayTarget
      }
    } else {
      interpolationTargetCoordinate = displayTarget
    }

    let targetAlpha = min(max(estimatedSpeedMetersPerSecond / 16, 0.08), 0.32)
    let targetHeadingStep = filteredTargetHeading.shortestHeadingDelta(to: normalizedHeading)
    filteredTargetHeading = (filteredTargetHeading + targetHeadingStep * targetAlpha).normalizedHeading
    lastRawCoordinate = coordinate
    lastPositionReceivedAt = now

    if !isNavigating {
      displayedCoordinate = displayTarget
      displayedHeading = normalizedHeading
      lastDisplayLinkTimestamp = nil
    }
  }

  private func startDisplayLink() {
    guard displayLink == nil else { return }
    let link = CADisplayLink(target: self, selector: #selector(advanceNavigationAnimation(_:)))
    if #available(iOS 15.0, *) {
      link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
    } else {
      link.preferredFramesPerSecond = 60
    }
    link.add(to: .main, forMode: .common)
    displayLink = link
  }

  @objc private func advanceNavigationAnimation(_ link: CADisplayLink) {
    guard isFollowingNavigation,
          let current = displayedCoordinate,
          let target = interpolationTargetCoordinate
    else {
      return
    }

    guard let previousTimestamp = lastDisplayLinkTimestamp else {
      lastDisplayLinkTimestamp = link.timestamp
      return
    }
    let elapsed = min(max(link.timestamp - previousTimestamp, 1.0 / 120.0), 0.1)
    lastDisplayLinkTimestamp = link.timestamp

    // Same principle as the phone map: predict movement between sparse GPS
    // fixes so the marker never freezes and jumps once per second.
    var predictedTarget = target
    if estimatedSpeedMetersPerSecond > 0.8,
       let lastPositionReceivedAt,
       link.timestamp - lastPositionReceivedAt < 2.5 {
      predictedTarget = predictedTarget.offset(
        distanceMeters: estimatedSpeedMetersPerSecond * elapsed,
        bearingDegrees: filteredTargetHeading
      )
      interpolationTargetCoordinate = predictedTarget
    }

    let speedFactor = min(max(estimatedSpeedMetersPerSecond / 16, 0), 1)
    let positionAlpha = min(max(elapsed * (2.0 + speedFactor * 2.5), 0.03), 0.30)
    let coordinate = current.interpolated(to: predictedTarget, fraction: positionAlpha)

    let rawHeadingDelta = displayedHeading.shortestHeadingDelta(to: filteredTargetHeading)
    let turnFactor = min(max(abs(rawHeadingDelta) / 45, 0), 1)
    let maximumTurn = (35 + speedFactor * 75) * elapsed * (1 + turnFactor * 2.2)
    let limitedHeadingDelta = min(max(rawHeadingDelta, -maximumTurn), maximumTurn)
    let headingAlpha = min(
      max(elapsed * (1.5 + speedFactor * 2.8) * (1 + turnFactor * 2.0), 0.03),
      0.70
    )
    let heading = (displayedHeading + limitedHeadingDelta * headingAlpha).normalizedHeading

    displayedCoordinate = coordinate
    displayedHeading = heading
    updateNavigationMarker(at: coordinate, headingDegrees: heading)
    updateNavigationCamera(at: coordinate, headingDegrees: heading)
  }

  private func routeSnappedCoordinate(
    for coordinate: CLLocationCoordinate2D
  ) -> CLLocationCoordinate2D {
    guard navigationRouteCoordinates.count >= 2 else { return coordinate }

    let point = MKMapPoint(coordinate)
    var nearestPoint = point
    var nearestDistance = Double.greatestFiniteMagnitude

    for index in 0..<(navigationRouteCoordinates.count - 1) {
      let start = MKMapPoint(navigationRouteCoordinates[index])
      let end = MKMapPoint(navigationRouteCoordinates[index + 1])
      let dx = end.x - start.x
      let dy = end.y - start.y
      let lengthSquared = dx * dx + dy * dy
      guard lengthSquared > 0 else { continue }
      let fraction = min(
        max(((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared, 0),
        1
      )
      let candidate = MKMapPoint(
        x: start.x + dx * fraction,
        y: start.y + dy * fraction
      )
      let distance = point.distance(to: candidate)
      if distance < nearestDistance {
        nearestDistance = distance
        nearestPoint = candidate
      }
    }

    // Match the phone's 45 m route-lock zone while still allowing genuine
    // off-route movement to leave the polyline and trigger rerouting.
    return nearestDistance < 45 ? nearestPoint.coordinate : coordinate
  }

  private func updateNavigationMarkerVisibility(
    isNavigating: Bool,
    coordinate: CLLocationCoordinate2D
  ) {
    if isNavigating {
      if mapView.showsUserLocation {
        mapView.showsUserLocation = false
      }
      if navigationAnnotation == nil {
        let annotation = CruizXNavigationAnnotation()
        annotation.coordinate = coordinate
        navigationAnnotation = annotation
        mapView.addAnnotation(annotation)
      }
    } else {
      if let navigationAnnotation {
        mapView.removeAnnotation(navigationAnnotation)
        self.navigationAnnotation = nil
      }
      if !mapView.showsUserLocation {
        mapView.showsUserLocation = true
      }
    }
  }

  private func updateNavigationMarker(
    at coordinate: CLLocationCoordinate2D,
    headingDegrees: Double
  ) {
    guard let navigationAnnotation else { return }
    navigationAnnotation.coordinate = coordinate
    guard let view = mapView.view(for: navigationAnnotation) else { return }
    // The vehicle stays pointing straight ahead, as in Apple Maps and Waze.
    // Only the map rotates, so the marker never anticipates an upcoming bend.
    view.transform = .identity
  }

  private func updateNavigationCamera(at coordinate: CLLocationCoordinate2D, headingDegrees: Double) {
    if CACurrentMediaTime() < manualConvoyCameraUntil { return }
    // Position and heading have already been filtered together by the display
    // link. Feeding that single heading directly to MapKit avoids a second,
    // lagging smoother that made the road and marker drift apart in turns.
    let cameraHeading = headingDegrees.normalizedHeading

    // Keep the vehicle in the lower third without pushing it into CarPlay's
    // bottom safe area. The previous 260 m offset and 58 degree pitch made the
    // marker disappear near the edge and exaggerated small heading changes.
    // Shift the camera target forward and to the vehicle's right. This makes
    // the marker sit higher and left of centre, clear of the bottom estimates
    // panel and the right-side CarPlay controls.
    let center = coordinate
      .offset(distanceMeters: 68, bearingDegrees: cameraHeading)
      .offset(distanceMeters: 88, bearingDegrees: cameraHeading + 90)
    let camera = MKMapCamera(
      lookingAtCenter: center,
      fromDistance: 610,
      pitch: 46,
      heading: cameraHeading
    )

    // Position and camera advance on the same display link. Avoid feeding
    // MapKit imperceptibly small changes, which otherwise makes road labels
    // and the camera appear to tremble while stopped or moving slowly.
    if let previousCoordinate = lastCameraCoordinate,
       let previousHeading = lastCameraHeading {
      let movement = MKMapPoint(previousCoordinate).distance(to: MKMapPoint(coordinate))
      let cameraHeadingDelta = abs(previousHeading.shortestHeadingDelta(to: cameraHeading))
      if movement < 0.12 && cameraHeadingDelta < 0.12 { return }
    }
    lastCameraCoordinate = coordinate
    lastCameraHeading = cameraHeading
    mapView.setCamera(camera, animated: false)
    updateConvoyMarkerRotations()
  }

  func beginManualMapPan() {
    guard isViewLoaded else { return }
    // Keep automatic navigation updates running, but leave the camera where
    // the driver moved it until Follow me is selected.
    manualConvoyCameraUntil = .greatestFiniteMagnitude
    manualPanStartCenter = MKMapPoint(mapView.centerCoordinate)
    manualPanStartVisibleRect = mapView.visibleMapRect
  }

  func updateManualMapPan(translation: CGPoint) {
    guard let startCenter = manualPanStartCenter,
          let startRect = manualPanStartVisibleRect,
          mapView.bounds.width > 0,
          mapView.bounds.height > 0
    else { return }

    let pointsPerPixelX = startRect.width / Double(mapView.bounds.width)
    let pointsPerPixelY = startRect.height / Double(mapView.bounds.height)
    let center = MKMapPoint(
      x: startCenter.x - Double(translation.x) * pointsPerPixelX,
      y: startCenter.y - Double(translation.y) * pointsPerPixelY
    )
    var camera = mapView.camera
    camera.centerCoordinate = center.coordinate
    mapView.setCamera(camera, animated: false)
  }

  func endManualMapPan() {
    manualPanStartCenter = nil
    manualPanStartVisibleRect = nil
  }

  func panMap(direction: CPMapTemplate.PanDirection) {
    guard isViewLoaded else { return }
    manualConvoyCameraUntil = .greatestFiniteMagnitude
    var offsetX = 0.0
    var offsetY = 0.0
    if direction.contains(.left) { offsetX = -mapView.bounds.width * 0.24 }
    if direction.contains(.right) { offsetX = mapView.bounds.width * 0.24 }
    if direction.contains(.up) { offsetY = -mapView.bounds.height * 0.24 }
    if direction.contains(.down) { offsetY = mapView.bounds.height * 0.24 }

    let targetPoint = CGPoint(
      x: mapView.bounds.midX + offsetX,
      y: mapView.bounds.midY + offsetY
    )
    let coordinate = mapView.convert(targetPoint, toCoordinateFrom: mapView)
    mapView.setCenter(coordinate, animated: true)
  }

  @available(iOS 26.0, *)
  func beginManualMapZoom() {
    guard isViewLoaded else { return }
    manualConvoyCameraUntil = .greatestFiniteMagnitude
    manualZoomStartDistance = mapView.camera.centerCoordinateDistance
  }

  @available(iOS 26.0, *)
  func updateManualMapZoom(scale: CGFloat) {
    guard let startDistance = manualZoomStartDistance, scale > 0 else { return }
    var camera = mapView.camera
    camera.centerCoordinateDistance = min(max(startDistance / Double(scale), 140), 12_000)
    mapView.setCamera(camera, animated: false)
  }

  @available(iOS 26.0, *)
  func endManualMapZoom() {
    manualZoomStartDistance = nil
  }

  func resumeNavigationFollowing() {
    guard isViewLoaded else { return }
    manualConvoyCameraUntil = 0
    manualPanStartCenter = nil
    manualPanStartVisibleRect = nil
    manualZoomStartDistance = nil
    guard isFollowingNavigation, let coordinate = displayedCoordinate else { return }
    updateNavigationCamera(at: coordinate, headingDegrees: displayedHeading)
  }

  func updateConvoyMembers(_ members: [CarPlayManager.ConvoyMember]) {
    guard isViewLoaded else { return }
    let incomingIds = Set(members.map(\.userId))

    let removedIds = convoyAnnotations.keys.filter { !incomingIds.contains($0) }
    for userId in removedIds {
      guard let annotation = convoyAnnotations.removeValue(forKey: userId) else { continue }
      mapView.removeAnnotation(annotation)
    }

    for member in members {
      if let annotation = convoyAnnotations[member.userId] {
        let previous = annotation.coordinate
        let movement = MKMapPoint(previous).distance(to: MKMapPoint(member.coordinate))
        if movement > 1 {
          annotation.headingDegrees = previous.bearing(to: member.coordinate)
        }
        annotation.label = member.label
        annotation.assetPath = member.assetPath
        annotation.iconName = member.iconName
        annotation.tintArgb = member.tintArgb
        UIView.animate(withDuration: 0.85, delay: 0, options: [.curveEaseInOut, .beginFromCurrentState]) {
          annotation.coordinate = member.coordinate
        }
        if let view = mapView.view(for: annotation) {
          configureConvoyAnnotationView(view, annotation: annotation)
        }
      } else {
        let annotation = CruizXConvoyAnnotation(member: member)
        convoyAnnotations[member.userId] = annotation
        mapView.addAnnotation(annotation)
      }
    }
    updateConvoyMarkerRotations()
  }

  func showAllConvoyMembers() {
    guard !convoyAnnotations.isEmpty else { return }
    manualConvoyCameraUntil = CACurrentMediaTime() + 8
    var rect = MKMapRect.null
    for annotation in convoyAnnotations.values {
      let point = MKMapPoint(annotation.coordinate)
      rect = rect.union(MKMapRect(x: point.x, y: point.y, width: 1, height: 1))
    }
    if mapView.userLocation.location != nil {
      let point = MKMapPoint(mapView.userLocation.coordinate)
      rect = rect.union(MKMapRect(x: point.x, y: point.y, width: 1, height: 1))
    }
    mapView.setVisibleMapRect(
      rect,
      edgePadding: UIEdgeInsets(top: 90, left: 80, bottom: 100, right: 90),
      animated: true
    )
  }

  func focusOnConvoyMember(userId: String) {
    guard let annotation = convoyAnnotations[userId] else { return }
    manualConvoyCameraUntil = CACurrentMediaTime() + 8
    let camera = MKMapCamera(
      lookingAtCenter: annotation.coordinate,
      fromDistance: 520,
      pitch: 35,
      heading: mapView.camera.heading
    )
    mapView.setCamera(camera, animated: true)
  }

  private func updateConvoyMarkerRotations() {
    for annotation in convoyAnnotations.values {
      guard let view = mapView.view(for: annotation) else { continue }
      let relative = mapView.camera.heading.shortestHeadingDelta(to: annotation.headingDegrees)
      view.transform = CGAffineTransform(rotationAngle: CGFloat(relative * .pi / 180))
    }
  }

  private func configureConvoyAnnotationView(
    _ view: MKAnnotationView,
    annotation: CruizXConvoyAnnotation
  ) {
    view.annotation = annotation
    view.canShowCallout = false
    if let assetPath = annotation.assetPath, let image = convoyMarkerImage(assetPath: assetPath) {
      view.image = image
    } else {
      let symbolName = switch annotation.iconName {
      case "compass": "location.north.circle.fill"
      case "triangle": "arrowtriangle.up.fill"
      case "flatArrow": "location.fill"
      default: "location.north.fill"
      }
      let configuration = UIImage.SymbolConfiguration(pointSize: 21, weight: .bold)
      view.image = UIImage(systemName: symbolName, withConfiguration: configuration)?
        .withTintColor(annotation.tintColor, renderingMode: .alwaysOriginal)
    }
    view.layer.shadowColor = UIColor.black.cgColor
    view.layer.shadowOpacity = 0.5
    view.layer.shadowRadius = 2
    view.layer.shadowOffset = CGSize(width: 0, height: 1)
  }

  private func convoyMarkerImage(assetPath: String) -> UIImage? {
    let candidates = [
      Bundle.main.bundlePath + "/Frameworks/App.framework/flutter_assets/" + assetPath,
      Bundle.main.bundlePath + "/" + assetPath,
    ]
    guard let source = candidates.lazy.compactMap({ UIImage(contentsOfFile: $0) }).first else {
      return nil
    }
    let target = CGSize(width: 32, height: 32)
    let renderer = UIGraphicsImageRenderer(size: target)
    return renderer.image { _ in
      let scale = min(target.width / source.size.width, target.height / source.size.height)
      let size = CGSize(width: source.size.width * scale, height: source.size.height * scale)
      source.draw(in: CGRect(
        x: (target.width - size.width) / 2,
        y: (target.height - size.height) / 2,
        width: size.width,
        height: size.height
      ))
    }
  }

  func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
    guard let polyline = overlay as? MKPolyline else {
      return MKOverlayRenderer(overlay: overlay)
    }

    let renderer = MKPolylineRenderer(polyline: polyline)
    renderer.strokeColor = UIColor(red: 0.12, green: 0.55, blue: 1.0, alpha: 1)
    renderer.lineWidth = 7
    renderer.lineCap = .round
    renderer.lineJoin = .round
    return renderer
  }

  func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
    if annotation is MKUserLocation {
      // Use MapKit's own blue location dot whenever turn-by-turn navigation
      // is inactive. Returning MKUserLocationView keeps Apple's native
      // accuracy halo, animation and authorization-dependent appearance.
      let identifier = "AppleUserLocation"
      let view = (mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
        as? MKUserLocationView) ?? MKUserLocationView(annotation: annotation, reuseIdentifier: identifier)
      view.annotation = annotation
      view.zPriority = .max
      return view
    }

    if annotation is CruizXNavigationAnnotation {
      let identifier = "AppleNavigationArrow"
      let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
        ?? MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
      view.annotation = annotation
      // Apple Maps' exact turn-by-turn puck isn't part of public MapKit.
      // Build the public equivalent from Apple's location SF Symbol: a
      // compact white-rimmed blue puck that replaces the native dot only
      // while a route is active.
      view.image = appleNavigationMarkerImage()
      view.zPriority = .max
      view.displayPriority = .required
      view.collisionMode = .none
      view.layer.shadowColor = UIColor.black.cgColor
      view.layer.shadowOpacity = 0.42
      view.layer.shadowRadius = 2.5
      view.layer.shadowOffset = CGSize(width: 0, height: 1.5)
      view.canShowCallout = false
      return view
    }

    if let convoy = annotation as? CruizXConvoyAnnotation {
      let identifier = "CruizXConvoyMember"
      let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
        ?? MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
      configureConvoyAnnotationView(view, annotation: convoy)
      return view
    }

    if annotation === destinationAnnotation {
      let identifier = "CruizXDestination"
      let marker = (mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
        as? MKMarkerAnnotationView) ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
      marker.annotation = annotation
      marker.markerTintColor = .systemRed
      marker.glyphImage = UIImage(systemName: "flag.fill")
      marker.titleVisibility = .hidden
      marker.subtitleVisibility = .hidden
      return marker
    }

    return nil
  }

  private func appleNavigationMarkerImage() -> UIImage? {
    let size = CGSize(width: 24, height: 24)
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { context in
      let bounds = CGRect(origin: .zero, size: size)
      UIColor.white.withAlphaComponent(0.96).setFill()
      context.cgContext.fillEllipse(in: bounds.insetBy(dx: 0.5, dy: 0.5))

      UIColor.systemBlue.setFill()
      context.cgContext.fillEllipse(in: bounds.insetBy(dx: 2.5, dy: 2.5))

      let configuration = UIImage.SymbolConfiguration(pointSize: 13.5, weight: .bold)
      guard let symbol = UIImage(systemName: "location.north.fill", withConfiguration: configuration)?
        .withTintColor(.white, renderingMode: .alwaysOriginal)
      else { return }
      let symbolSize = symbol.size
      symbol.draw(at: CGPoint(
        x: (size.width - symbolSize.width) / 2,
        y: (size.height - symbolSize.height) / 2 - 0.4
      ))
    }
  }

}

private final class CruizXNavigationAnnotation: MKPointAnnotation {}

private final class CruizXConvoyAnnotation: MKPointAnnotation {
  let userId: String
  var label: String
  var assetPath: String?
  var iconName: String?
  var tintArgb: Int?
  var headingDegrees = 0.0

  init(member: CarPlayManager.ConvoyMember) {
    userId = member.userId
    label = member.label
    assetPath = member.assetPath
    iconName = member.iconName
    tintArgb = member.tintArgb
    super.init()
    coordinate = member.coordinate
    title = member.label
  }

  var tintColor: UIColor {
    guard let value = tintArgb else { return UIColor(red: 0, green: 0.64, blue: 1, alpha: 1) }
    let unsigned = UInt32(truncatingIfNeeded: value)
    return UIColor(
      red: CGFloat((unsigned >> 16) & 0xff) / 255,
      green: CGFloat((unsigned >> 8) & 0xff) / 255,
      blue: CGFloat(unsigned & 0xff) / 255,
      alpha: CGFloat((unsigned >> 24) & 0xff) / 255
    )
  }
}

private final class CruizXSegmentedSpeedometerView: UIView {
  var progress = 0.0 { didSet { setNeedsLayout() } }
  var isOverLimit = false { didSet { setNeedsLayout() } }

  private let segmentCount = 28
  private var segmentLayers: [CAShapeLayer] = []

  override func layoutSubviews() {
    super.layoutSubviews()
    if segmentLayers.count != segmentCount {
      segmentLayers.forEach { $0.removeFromSuperlayer() }
      segmentLayers = (0..<segmentCount).map { _ in
        let segment = CAShapeLayer()
        segment.fillColor = UIColor.clear.cgColor
        segment.lineCap = .round
        segment.lineWidth = 3.6
        layer.addSublayer(segment)
        return segment
      }
    }

    let center = CGPoint(x: bounds.midX, y: bounds.midY)
    let radius = min(bounds.width, bounds.height) / 2 - 2.2
    let filled = Int((min(max(progress, 0), 1) * Double(segmentCount)).rounded(.down))
    let activeColor = isOverLimit
      ? UIColor(red: 1, green: 0.30, blue: 0.32, alpha: 1)
      : UIColor(red: 1.0, green: 0.57, blue: 0.14, alpha: 1)
    let inactiveColor = UIColor.white.withAlphaComponent(0.30)
    let circle = CGFloat.pi * 2
    let gap = circle / CGFloat(segmentCount) * 0.34

    for index in 0..<segmentCount {
      let start = -CGFloat.pi / 2 + circle * CGFloat(index) / CGFloat(segmentCount) + gap / 2
      let end = -CGFloat.pi / 2 + circle * CGFloat(index + 1) / CGFloat(segmentCount) - gap / 2
      segmentLayers[index].path = UIBezierPath(
        arcCenter: center,
        radius: radius,
        startAngle: start,
        endAngle: end,
        clockwise: true
      ).cgPath
      segmentLayers[index].strokeColor = (index < filled ? activeColor : inactiveColor).cgColor
    }
  }
}

private extension CLLocationCoordinate2D {
  func bearing(to target: CLLocationCoordinate2D) -> Double {
    let startLatitude = latitude * .pi / 180
    let targetLatitude = target.latitude * .pi / 180
    let longitudeDelta = (target.longitude - longitude) * .pi / 180
    let y = sin(longitudeDelta) * cos(targetLatitude)
    let x = cos(startLatitude) * sin(targetLatitude) -
      sin(startLatitude) * cos(targetLatitude) * cos(longitudeDelta)
    return (atan2(y, x) * 180 / .pi).normalizedHeading
  }

  func interpolated(to target: CLLocationCoordinate2D, fraction: Double) -> CLLocationCoordinate2D {
    CLLocationCoordinate2D(
      latitude: latitude + (target.latitude - latitude) * fraction,
      longitude: longitude + (target.longitude - longitude) * fraction
    )
  }

  func offset(distanceMeters: Double, bearingDegrees: Double) -> CLLocationCoordinate2D {
    let earthRadiusMeters = 6_371_000.0
    let angularDistance = distanceMeters / earthRadiusMeters
    let bearing = bearingDegrees * .pi / 180
    let latitudeRadians = latitude * .pi / 180
    let longitudeRadians = longitude * .pi / 180

    let latitude = asin(
      sin(latitudeRadians) * cos(angularDistance) +
        cos(latitudeRadians) * sin(angularDistance) * cos(bearing)
    )
    let longitude = longitudeRadians + atan2(
      sin(bearing) * sin(angularDistance) * cos(latitudeRadians),
      cos(angularDistance) - sin(latitudeRadians) * sin(latitude)
    )
    return CLLocationCoordinate2D(
      latitude: latitude * 180 / .pi,
      longitude: longitude * 180 / .pi
    )
  }
}

private extension Double {
  var normalizedHeading: Double {
    let result = truncatingRemainder(dividingBy: 360)
    return result >= 0 ? result : result + 360
  }

  func interpolatedHeading(to target: Double, fraction: Double) -> Double {
    let delta = ((target - self + 540).truncatingRemainder(dividingBy: 360)) - 180
    return (self + delta * fraction).normalizedHeading
  }

  func shortestHeadingDelta(to target: Double) -> Double {
    ((target - self + 540).truncatingRemainder(dividingBy: 360)) - 180
  }
}
