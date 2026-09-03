import CarPlay
import MapKit
import UIKit

struct CruizXTrafficSection {
  let level: String
  let coordinates: [CLLocationCoordinate2D]
}

final class CarPlayMapViewController: UIViewController, MKMapViewDelegate {
  private let isDashboardSurface: Bool
  private let mapView = MKMapView()
  private let speedometerCluster = UIView()
  private let logoBadge = UIView()
  private let logoImageView = UIImageView()
  private let speedometerStack = UIStackView()
  private let currentSpeedView = CruizXSegmentedSpeedometerView()
  private let currentSpeedLabel = UILabel()
  private let speedUnitLabel = UILabel()
  private let speedLimitView = UIView()
  private let speedLimitLabel = UILabel()
  private var routeOverlay: MKPolyline?
  private var trafficOverlays: [CruizXTrafficPolyline] = []
  private var trafficOverlaySignature = ""
  private var navigationRouteCoordinates: [CLLocationCoordinate2D] = []
  private var destinationAnnotation: MKPointAnnotation?
  private var navigationAnnotation: CruizXNavigationAnnotation?
  private var convoyAnnotations: [String: CruizXConvoyAnnotation] = [:]
  private var mapMarkerAnnotations: [String: CruizXMapMarkerAnnotation] = [:]
  private var navigationMarkerAssetPath: String?
  private var navigationMarkerIconName: String?
  private var navigationMarkerTintArgb: Int?
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

  init(isDashboardSurface: Bool = false) {
    self.isDashboardSurface = isDashboardSurface
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    isDashboardSurface = false
    super.init(coder: coder)
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    view.backgroundColor = .black
    configureMapView()
    // Dashboard owns the surrounding cards and controls. Keep CruizX branding
    // on the full-screen surface, but expose the compact driving gauges on
    // both surfaces.
    if !isDashboardSurface {
      configureBranding()
    }
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
    mapView.showsTraffic = false
    mapView.isScrollEnabled = true
    // Handle pinch zoom ourselves so it works on CarPlay units that do not
    // forward MapKit's built-in zoom gesture to an app-owned map view.
    mapView.isZoomEnabled = false
    mapView.isPitchEnabled = true
    mapView.isRotateEnabled = true
    // Let MapKit own the position marker and its internal GPS smoothing. The
    // camera remains CruizX-controlled so the marker can sit left and above
    // CarPlay's bottom estimates panel instead of being forced to the centre.
    mapView.showsUserLocation = true
    mapView.tintColor = UIColor(red: 0.0, green: 0.64, blue: 1.0, alpha: 1)
    // Show businesses and other useful places directly on the in-car map,
    // matching the richer map view on the phone.
    mapView.pointOfInterestFilter = .includingAll
    mapView.overrideUserInterfaceStyle = .dark
    mapView.delegate = self

    let pinchZoom = UIPinchGestureRecognizer(
      target: self,
      action: #selector(handleMapPinch(_:))
    )
    mapView.addGestureRecognizer(pinchZoom)

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

  private func configureBranding() {
    logoBadge.translatesAutoresizingMaskIntoConstraints = false
    // This logo has a transparent background, so show it directly on the
    // map rather than putting it inside the previous dark rounded badge.
    logoBadge.backgroundColor = .clear
    logoBadge.layer.cornerRadius = 0
    logoBadge.layer.borderWidth = 0
    logoBadge.isUserInteractionEnabled = false

    logoImageView.translatesAutoresizingMaskIntoConstraints = false
    logoImageView.contentMode = .scaleAspectFit
    logoImageView.clipsToBounds = true
    logoImageView.image = cruizXLogoImage()
    logoBadge.isHidden = logoImageView.image == nil

    logoBadge.addSubview(logoImageView)
    view.addSubview(logoBadge)
    NSLayoutConstraint.activate([
      logoBadge.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
      logoBadge.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -14),
      logoBadge.widthAnchor.constraint(equalToConstant: 82),
      logoBadge.heightAnchor.constraint(equalToConstant: 69),
      logoImageView.topAnchor.constraint(equalTo: logoBadge.topAnchor),
      logoImageView.leadingAnchor.constraint(equalTo: logoBadge.leadingAnchor),
      logoImageView.trailingAnchor.constraint(equalTo: logoBadge.trailingAnchor),
      logoImageView.bottomAnchor.constraint(equalTo: logoBadge.bottomAnchor),
    ])
  }

  private func cruizXLogoImage() -> UIImage? {
    let assetPath = "assets/logga_nobg.png"
    let candidates = [
      Bundle.main.bundlePath + "/Frameworks/App.framework/flutter_assets/" + assetPath,
      Bundle.main.bundlePath + "/" + assetPath,
    ]
    return candidates.lazy.compactMap { UIImage(contentsOfFile: $0) }.first
  }

  private func configureSpeedometers() {
    let currentGaugeSize: CGFloat = isDashboardSurface ? 40 : 46
    let speedLimitSize: CGFloat = isDashboardSurface ? 27 : 30
    let trailingInset: CGFloat = isDashboardSurface ? 8 : 16
    let clusterWidth: CGFloat = isDashboardSurface
      ? currentGaugeSize + speedLimitSize - 2
      : currentGaugeSize
    // Lower the compact gauges in the small dashboard map while retaining
    // enough clearance for CarPlay's native ETA field below them.
    let bottomInset: CGFloat = isDashboardSurface ? 30 : 14

    speedometerCluster.translatesAutoresizingMaskIntoConstraints = false
    // Keep the two gauges visually separate from the map without wrapping
    // them in an additional dark panel.
    speedometerCluster.backgroundColor = .clear
    speedometerCluster.isHidden = true
    speedometerCluster.isUserInteractionEnabled = false

    speedometerStack.translatesAutoresizingMaskIntoConstraints = false
    speedometerStack.axis = isDashboardSurface ? .horizontal : .vertical
    speedometerStack.alignment = .center
    // Let the speed-limit sign tuck slightly into the speedometer so the two
    // circles read as one unit in both dashboard and full-screen layouts.
    speedometerStack.spacing = -2
    speedometerStack.isUserInteractionEnabled = false

    currentSpeedView.translatesAutoresizingMaskIntoConstraints = false
    currentSpeedView.backgroundColor = UIColor(red: 0.025, green: 0.075, blue: 0.20, alpha: 0.96)
    currentSpeedView.layer.cornerRadius = currentGaugeSize / 2

    currentSpeedLabel.translatesAutoresizingMaskIntoConstraints = false
    currentSpeedLabel.textAlignment = .center
    currentSpeedLabel.textColor = .white
    currentSpeedLabel.font = .systemFont(
      ofSize: isDashboardSurface ? 16 : 18,
      weight: .bold
    )

    speedUnitLabel.translatesAutoresizingMaskIntoConstraints = false
    speedUnitLabel.textAlignment = .center
    speedUnitLabel.textColor = UIColor.white.withAlphaComponent(0.7)
    speedUnitLabel.font = .systemFont(ofSize: 6.5, weight: .semibold)

    currentSpeedView.addSubview(currentSpeedLabel)
    currentSpeedView.addSubview(speedUnitLabel)

    speedLimitView.translatesAutoresizingMaskIntoConstraints = false
    speedLimitView.backgroundColor = .white
    speedLimitView.layer.cornerRadius = speedLimitSize / 2
    speedLimitView.layer.borderWidth = isDashboardSurface ? 2.2 : 2.5
    speedLimitView.layer.borderColor = UIColor(red: 0.78, green: 0.06, blue: 0.08, alpha: 1).cgColor

    speedLimitLabel.translatesAutoresizingMaskIntoConstraints = false
    speedLimitLabel.textAlignment = .center
    speedLimitLabel.textColor = .black
    speedLimitLabel.font = .systemFont(
      ofSize: isDashboardSurface ? 9.5 : 10.5,
      weight: .bold
    )
    speedLimitView.addSubview(speedLimitLabel)

    speedometerStack.addArrangedSubview(currentSpeedView)
    speedometerStack.addArrangedSubview(speedLimitView)
    speedometerCluster.addSubview(speedometerStack)
    view.addSubview(speedometerCluster)

    NSLayoutConstraint.activate([
      currentSpeedView.widthAnchor.constraint(equalToConstant: currentGaugeSize),
      currentSpeedView.heightAnchor.constraint(equalToConstant: currentGaugeSize),
      currentSpeedLabel.centerXAnchor.constraint(equalTo: currentSpeedView.centerXAnchor),
      currentSpeedLabel.centerYAnchor.constraint(equalTo: currentSpeedView.centerYAnchor, constant: -4),
      speedUnitLabel.topAnchor.constraint(equalTo: currentSpeedLabel.bottomAnchor, constant: -1),
      speedUnitLabel.centerXAnchor.constraint(equalTo: currentSpeedView.centerXAnchor),
      speedLimitView.widthAnchor.constraint(equalToConstant: speedLimitSize),
      speedLimitView.heightAnchor.constraint(equalToConstant: speedLimitSize),
      speedLimitLabel.centerXAnchor.constraint(equalTo: speedLimitView.centerXAnchor),
      speedLimitLabel.centerYAnchor.constraint(equalTo: speedLimitView.centerYAnchor),
      speedometerStack.topAnchor.constraint(equalTo: speedometerCluster.topAnchor, constant: 4),
      speedometerStack.bottomAnchor.constraint(equalTo: speedometerCluster.bottomAnchor, constant: -4),
      speedometerStack.centerXAnchor.constraint(equalTo: speedometerCluster.centerXAnchor),
      speedometerCluster.widthAnchor.constraint(equalToConstant: clusterWidth),
      // Keep the combined speed unit in the lower-right navigation area,
      // clear of the bottom trip estimates and the guidance card.
      speedometerCluster.trailingAnchor.constraint(
        equalTo: view.safeAreaLayoutGuide.trailingAnchor,
        constant: -trailingInset
      ),
      speedometerCluster.bottomAnchor.constraint(
        equalTo: view.safeAreaLayoutGuide.bottomAnchor,
        constant: -bottomInset
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
    isNavigating: Bool,
    trafficSections: [CruizXTrafficSection]
  ) {
    guard isViewLoaded else { return }
    mapView.showsTraffic = coordinates.count >= 2

    if let routeOverlay {
      mapView.removeOverlay(routeOverlay)
    }
    if let destinationAnnotation {
      mapView.removeAnnotation(destinationAnnotation)
    }

    guard coordinates.count >= 2 else {
      updateTrafficOverlays([])
      routeOverlay = nil
      navigationRouteCoordinates = []
      destinationAnnotation = nil
      mapView.setUserTrackingMode(.follow, animated: true)
      return
    }

    let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
    routeOverlay = polyline
    navigationRouteCoordinates = coordinates
    if let firstTrafficOverlay = trafficOverlays.first {
      mapView.insertOverlay(polyline, below: firstTrafficOverlay)
    } else {
      mapView.addOverlay(polyline, level: .aboveRoads)
    }
    updateTrafficOverlays(trafficSections)

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

  private func updateTrafficOverlays(_ sections: [CruizXTrafficSection]) {
    let signature = sections.map { section in
      section.level + ":" + section.coordinates.map {
        String(format: "%.6f,%.6f", $0.latitude, $0.longitude)
      }.joined(separator: ";")
    }.joined(separator: "|")
    guard signature != trafficOverlaySignature else { return }
    trafficOverlaySignature = signature
    mapView.removeOverlays(trafficOverlays)
    trafficOverlays = sections.compactMap { section in
      guard section.coordinates.count >= 2 else { return nil }
      var points = section.coordinates
      let overlay = CruizXTrafficPolyline(coordinates: &points, count: points.count)
      overlay.congestionLevel = section.level
      return overlay
    }
    mapView.addOverlays(trafficOverlays, level: .aboveRoads)
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
    // Once the position is locked to the route, use that route segment's
    // bearing for the map. GPS heading can be a few degrees off (especially
    // at low speed), which made the fixed upright marker look angled relative
    // to the road beneath it.
    let normalizedHeading = (
      isNavigating ? routeHeading(for: coordinate) : nil
    ) ?? headingDegrees.normalizedHeading
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
      // GPS fixes and route snapping can move the target a few metres between
      // samples. Blend those corrections over several display frames rather
      // than letting the marker visibly catch up in one hop.
      if estimatedSpeedMetersPerSecond > 2.0, correctionDistance < 40 {
        interpolationTargetCoordinate = previousTarget.interpolated(to: displayTarget, fraction: 0.16)
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

  func updateNavigationMarkerStyle(
    assetPath: String?,
    iconName: String?,
    tintArgb: Int?
  ) {
    guard navigationMarkerAssetPath != assetPath
      || navigationMarkerIconName != iconName
      || navigationMarkerTintArgb != tintArgb
    else {
      return
    }
    navigationMarkerAssetPath = assetPath
    navigationMarkerIconName = iconName
    navigationMarkerTintArgb = tintArgb
    if let navigationAnnotation,
       let view = mapView.view(for: navigationAnnotation) {
      configureNavigationAnnotationView(view, annotation: navigationAnnotation)
    }
  }

  /// Applies a native GPS fix immediately when the phone is locked. A
  /// CADisplayLink is allowed to pause while the handset is in the background,
  /// even though the CarPlay scene and CLLocationManager are still active.
  /// In that state the normal interpolator would retain its old target and the
  /// marker/camera would look frozen. CarPlay gets the newest safe, route-
  /// snapped position directly instead.
  func updateBackgroundNavigationPosition(
    _ coordinate: CLLocationCoordinate2D,
    headingDegrees: Double,
    isNavigating: Bool
  ) {
    guard isViewLoaded else { return }

    let wasFollowingNavigation = isFollowingNavigation
    isFollowingNavigation = isNavigating
    if wasFollowingNavigation != isNavigating {
      lastRawCoordinate = nil
      estimatedSpeedMetersPerSecond = 0
    }

    let displayTarget = isNavigating ? routeSnappedCoordinate(for: coordinate) : coordinate
    let normalizedHeading = (
      isNavigating ? routeHeading(for: coordinate) : nil
    ) ?? headingDegrees.normalizedHeading
    updateNavigationMarkerVisibility(isNavigating: isNavigating, coordinate: displayTarget)

    if isNavigating && mapView.userTrackingMode != .none {
      mapView.setUserTrackingMode(.none, animated: false)
    }

    // Keep the normal interpolator in sync for when the phone is unlocked,
    // but do not depend on its display link to move the visible map now.
    displayedCoordinate = displayTarget
    interpolationTargetCoordinate = displayTarget
    displayedHeading = normalizedHeading
    filteredTargetHeading = normalizedHeading
    lastRawCoordinate = coordinate
    lastPositionReceivedAt = CACurrentMediaTime()
    lastDisplayLinkTimestamp = nil

    guard isNavigating else { return }
    updateNavigationMarker(at: displayTarget, headingDegrees: normalizedHeading, animated: true)
    updateNavigationCamera(at: displayTarget, headingDegrees: normalizedHeading, animated: true)
  }

  /// UIApplication can remain `.active` while an attached handset turns its
  /// display off. Detect the *actual* paused rendering loop instead of relying
  /// on application state, so native GPS keeps the CarPlay map alive.
  func requiresImmediateNativePositionUpdate() -> Bool {
    guard isFollowingNavigation else { return false }
    guard let lastDisplayLinkTimestamp else { return true }
    return CACurrentMediaTime() - lastDisplayLinkTimestamp > 0.75
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

  /// Returns the direction of the same nearby route segment used for
  /// map-matching. The marker itself remains upright; rotating the map to this
  /// bearing makes the blue route and the marker agree visually.
  private func routeHeading(for coordinate: CLLocationCoordinate2D) -> Double? {
    guard navigationRouteCoordinates.count >= 2 else { return nil }

    let point = MKMapPoint(coordinate)
    var nearestDistance = Double.greatestFiniteMagnitude
    var nearestStart: CLLocationCoordinate2D?
    var nearestEnd: CLLocationCoordinate2D?

    for index in 0..<(navigationRouteCoordinates.count - 1) {
      let startCoordinate = navigationRouteCoordinates[index]
      let endCoordinate = navigationRouteCoordinates[index + 1]
      let start = MKMapPoint(startCoordinate)
      let end = MKMapPoint(endCoordinate)
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
        nearestStart = startCoordinate
        nearestEnd = endCoordinate
      }
    }

    guard nearestDistance < 45,
          let nearestStart,
          let nearestEnd
    else {
      return nil
    }
    return nearestStart.bearing(to: nearestEnd)
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
    headingDegrees: Double,
    animated: Bool = false
  ) {
    guard let navigationAnnotation else { return }
    if animated {
      // CADisplayLink is paused when the phone screen is off. Core Location
      // still provides native fixes for CarPlay, so interpolate the annotation
      // between those fixes instead of stepping once per GPS sample.
      UIView.animate(
        withDuration: 0.82,
        delay: 0,
        options: [.beginFromCurrentState, .curveLinear, .allowUserInteraction]
      ) {
        navigationAnnotation.coordinate = coordinate
      }
    } else {
      navigationAnnotation.coordinate = coordinate
    }
    guard let view = mapView.view(for: navigationAnnotation) else { return }
    // The vehicle stays pointing straight ahead, as in Apple Maps and Waze.
    // Only the map rotates, so the marker never anticipates an upcoming bend.
    view.transform = .identity
  }

  private func updateNavigationCamera(
    at coordinate: CLLocationCoordinate2D,
    headingDegrees: Double,
    animated: Bool = false
  ) {
    if CACurrentMediaTime() < manualConvoyCameraUntil { return }
    // Position and heading have already been filtered together by the display
    // link. Feeding that single heading directly to MapKit avoids a second,
    // lagging smoother that made the road and marker drift apart in turns.
    let cameraHeading = headingDegrees.normalizedHeading

    // The dashboard map is much narrower than the full-screen map. Centre the
    // vehicle laterally there; the full-screen surface still leaves room for
    // CarPlay's controls and guidance card on the right.
    let forwardOffset = isDashboardSurface ? 42.0 : 68.0
    let lateralOffset = isDashboardSurface ? 0.0 : 88.0
    let center = coordinate
      .offset(distanceMeters: forwardOffset, bearingDegrees: cameraHeading)
      .offset(distanceMeters: lateralOffset, bearingDegrees: cameraHeading + 90)
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
      // MapKit camera updates are substantially more expensive than moving
      // the annotation. Updating it for every sub-pixel GPS interpolation
      // step can make the CarPlay renderer miss frames and look jerky. Keep
      // the marker on the 60 fps display link, while refreshing the camera
      // only when its movement is actually visible.
      // Keep position updates close to the display cadence. At the earlier
      // 0.4 m threshold the camera advanced in clearly visible steps on some
      // 30 fps CarPlay head units. Heading still has a wider dead zone to
      // prevent tiny compass changes from making the map wobble.
      if movement < 0.2 && cameraHeadingDelta < 0.45 { return }
    }
    lastCameraCoordinate = coordinate
    lastCameraHeading = cameraHeading
    mapView.setCamera(camera, animated: animated)
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

  func beginManualMapZoom() {
    guard isViewLoaded else { return }
    manualConvoyCameraUntil = .greatestFiniteMagnitude
    manualZoomStartDistance = mapView.camera.centerCoordinateDistance
  }

  func updateManualMapZoom(scale: CGFloat) {
    guard let startDistance = manualZoomStartDistance, scale > 0 else { return }
    var camera = mapView.camera
    camera.centerCoordinateDistance = min(max(startDistance / Double(scale), 140), 12_000)
    mapView.setCamera(camera, animated: false)
  }

  func endManualMapZoom() {
    manualZoomStartDistance = nil
  }

  @objc private func handleMapPinch(_ recognizer: UIPinchGestureRecognizer) {
    switch recognizer.state {
    case .began:
      beginManualMapZoom()
    case .changed:
      updateManualMapZoom(scale: recognizer.scale)
    case .ended, .cancelled, .failed:
      endManualMapZoom()
    default:
      break
    }
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

  func updateMapMarkers(_ markers: [CarPlayManager.MapMarker]) {
    guard isViewLoaded else { return }
    let incomingIds = Set(markers.map(\.id))

    for id in mapMarkerAnnotations.keys.filter({ !incomingIds.contains($0) }) {
      guard let annotation = mapMarkerAnnotations.removeValue(forKey: id) else { continue }
      mapView.removeAnnotation(annotation)
    }

    for marker in markers {
      if let existing = mapMarkerAnnotations[marker.id],
         existing.typeKey == marker.typeKey,
         existing.emoji == marker.emoji {
        existing.title = marker.label
        existing.coordinate = marker.coordinate
        continue
      }
      if let existing = mapMarkerAnnotations.removeValue(forKey: marker.id) {
        mapView.removeAnnotation(existing)
      }
      let annotation = CruizXMapMarkerAnnotation(marker: marker)
      mapMarkerAnnotations[marker.id] = annotation
      mapView.addAnnotation(annotation)
    }
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
    if let traffic = polyline as? CruizXTrafficPolyline {
      renderer.strokeColor = switch traffic.congestionLevel {
      case "severe": UIColor(red: 0.55, green: 0.0, blue: 0.08, alpha: 1)
      case "heavy": UIColor(red: 0.92, green: 0.08, blue: 0.12, alpha: 1)
      default: UIColor(red: 1.0, green: 0.56, blue: 0.0, alpha: 1)
      }
      renderer.lineWidth = 8
    } else {
      renderer.strokeColor = UIColor(red: 0.12, green: 0.55, blue: 1.0, alpha: 1)
      renderer.lineWidth = 7
    }
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
      configureNavigationAnnotationView(view, annotation: annotation)
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

    if let mapMarker = annotation as? CruizXMapMarkerAnnotation {
      let identifier = "CruizXMapMarker"
      let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
        ?? MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
      view.annotation = mapMarker
      view.canShowCallout = false
      view.image = mapMarkerImage(
        emoji: mapMarker.emoji,
        color: mapMarkerColor(for: mapMarker.typeKey)
      )
      view.centerOffset = CGPoint(x: 0, y: -2)
      view.displayPriority = .defaultHigh
      view.collisionMode = .circle
      return view
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

  private func configureNavigationAnnotationView(
    _ view: MKAnnotationView,
    annotation: MKAnnotation
  ) {
    view.annotation = annotation
    if let assetPath = navigationMarkerAssetPath,
       let image = markerAssetImage(assetPath: assetPath, size: CGSize(width: 38, height: 38)) {
      view.image = image
    } else {
      let tint = markerTintColor
      switch navigationMarkerIconName {
      case "compass":
        let configuration = UIImage.SymbolConfiguration(pointSize: 27, weight: .bold)
        view.image = UIImage(systemName: "location.north.circle.fill", withConfiguration: configuration)?
          .withTintColor(tint, renderingMode: .alwaysOriginal)
      case "triangle":
        let configuration = UIImage.SymbolConfiguration(pointSize: 25, weight: .bold)
        view.image = UIImage(systemName: "arrowtriangle.up.fill", withConfiguration: configuration)?
          .withTintColor(tint, renderingMode: .alwaysOriginal)
      case "flatArrow":
        let configuration = UIImage.SymbolConfiguration(pointSize: 25, weight: .bold)
        view.image = UIImage(systemName: "location.fill", withConfiguration: configuration)?
          .withTintColor(tint, renderingMode: .alwaysOriginal)
      default:
        view.image = appleNavigationMarkerImage()
      }
    }
    view.zPriority = .max
    view.displayPriority = .required
    view.collisionMode = .none
    view.layer.shadowColor = UIColor.black.cgColor
    view.layer.shadowOpacity = 0.42
    view.layer.shadowRadius = 2.5
    view.layer.shadowOffset = CGSize(width: 0, height: 1.5)
    view.canShowCallout = false
  }

  private var markerTintColor: UIColor {
    guard let value = navigationMarkerTintArgb else {
      return UIColor(red: 0, green: 0.64, blue: 1, alpha: 1)
    }
    let unsigned = UInt32(truncatingIfNeeded: value)
    return UIColor(
      red: CGFloat((unsigned >> 16) & 0xff) / 255,
      green: CGFloat((unsigned >> 8) & 0xff) / 255,
      blue: CGFloat(unsigned & 0xff) / 255,
      alpha: CGFloat((unsigned >> 24) & 0xff) / 255
    )
  }

  private func markerAssetImage(assetPath: String, size target: CGSize) -> UIImage? {
    let candidates = [
      Bundle.main.bundlePath + "/Frameworks/App.framework/flutter_assets/" + assetPath,
      Bundle.main.bundlePath + "/" + assetPath,
    ]
    guard let source = candidates.lazy.compactMap({ UIImage(contentsOfFile: $0) }).first else {
      return nil
    }
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

  private func mapMarkerColor(for typeKey: String) -> UIColor {
    switch typeKey {
    case "road_closure": return UIColor(red: 0.72, green: 0.11, blue: 0.11, alpha: 1)
    case "police": return UIColor(red: 0.08, green: 0.40, blue: 0.75, alpha: 1)
    case "roadwork": return UIColor(red: 0.90, green: 0.32, blue: 0.00, alpha: 1)
    case "accident": return UIColor(red: 0.78, green: 0.16, blue: 0.16, alpha: 1)
    case "traffic_jam": return UIColor(red: 0.96, green: 0.50, blue: 0.09, alpha: 1)
    case "speed_camera": return UIColor(red: 0.42, green: 0.11, blue: 0.60, alpha: 1)
    case "narrow_road": return UIColor(red: 0.00, green: 0.41, blue: 0.36, alpha: 1)
    case "steep_hill": return UIColor(red: 0.22, green: 0.29, blue: 0.31, alpha: 1)
    case "speed_bump": return UIColor(red: 1.00, green: 0.48, blue: 0.00, alpha: 1)
    case "meetup": return UIColor(red: 0.12, green: 0.53, blue: 0.90, alpha: 1)
    case "parking": return UIColor(red: 0.01, green: 0.47, blue: 0.74, alpha: 1)
    case "food_stop": return UIColor(red: 0.94, green: 0.42, blue: 0.00, alpha: 1)
    case "charging": return UIColor(red: 0.00, green: 0.66, blue: 0.42, alpha: 1)
    case "hangout": return UIColor(red: 1.00, green: 0.70, blue: 0.00, alpha: 1)
    default: return UIColor(red: 0.29, green: 0.08, blue: 0.55, alpha: 1)
    }
  }

  private func mapMarkerImage(emoji: String, color: UIColor) -> UIImage {
    let size = CGSize(width: 32, height: 38)
    return UIGraphicsImageRenderer(size: size).image { _ in
      let bodyRect = CGRect(x: 3, y: 2, width: 26, height: 26)
      let bodyPath = UIBezierPath(roundedRect: bodyRect, cornerRadius: 9)
      color.setFill()
      bodyPath.fill()
      UIColor.white.setStroke()
      bodyPath.lineWidth = 1.4
      bodyPath.stroke()

      let paragraph = NSMutableParagraphStyle()
      paragraph.alignment = .center
      emoji.draw(
        in: CGRect(x: 4, y: 5, width: 24, height: 20),
        withAttributes: [
          .font: UIFont.systemFont(ofSize: 16),
          .paragraphStyle: paragraph,
        ]
      )

      let tail = UIBezierPath()
      tail.move(to: CGPoint(x: 12, y: 27))
      tail.addLine(to: CGPoint(x: 20, y: 27))
      tail.addLine(to: CGPoint(x: 16, y: 34))
      tail.close()
      color.setFill()
      tail.fill()
    }
  }

}

private final class CruizXNavigationAnnotation: MKPointAnnotation {}

private final class CruizXMapMarkerAnnotation: MKPointAnnotation {
  let markerId: String
  let typeKey: String
  let emoji: String

  init(marker: CarPlayManager.MapMarker) {
    markerId = marker.id
    typeKey = marker.typeKey
    emoji = marker.emoji
    super.init()
    coordinate = marker.coordinate
    title = marker.label
  }
}

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
      : UIColor(red: 0.12, green: 0.55, blue: 1.0, alpha: 1)
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
