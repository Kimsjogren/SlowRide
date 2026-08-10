import CarPlay
import CoreLocation
import Flutter
import MapKit
import UIKit

final class CarPlayManager: NSObject {
  static let shared = CarPlayManager()
  static let channelName = "cruizx/carplay"

  struct Destination {
    enum Source {
      case favorite
      case recent

      var sectionTitle: String {
        switch self {
        case .favorite:
          return "Favoriter"
        case .recent:
          return "Senaste mål"
        }
      }

      var routeSummary: String {
        switch self {
        case .favorite:
          return "Favorit"
        case .recent:
          return "Senaste sökning"
        }
      }
    }

    let title: String
    let subtitle: String
    let coordinate: CLLocationCoordinate2D
    let source: Source
  }

  struct NavigationState {
    let hasRoute: Bool
    let isNavigating: Bool
    let totalDistanceMeters: Double?
    let remainingDistanceMeters: Double?
    let remainingDurationSeconds: Double?
    let nextManeuverText: String
    let currentStreetName: String
    let upcomingManeuvers: [ManeuverPayload]
  }

  struct ManeuverPayload {
    let id: String
    let text: String
    let streetName: String
    let sign: Int
    let distanceMeters: Double
  }

  private weak var interfaceController: CPInterfaceController?
  private weak var carWindow: CPWindow?
  private var mapTemplate: CPMapTemplate?
  private var activeTrip: CPTrip?
  private var activeDestination: Destination?
  private var navigationSession: CPNavigationSession?
  private var flutterChannel: FlutterMethodChannel?
  private var favoriteDestinations: [Destination] = []
  private var recentDestinations: [Destination] = []
  private var navigationState = NavigationState(
    hasRoute: false,
    isNavigating: false,
    totalDistanceMeters: nil,
    remainingDistanceMeters: nil,
    remainingDurationSeconds: nil,
    nextManeuverText: "",
    currentStreetName: "",
    upcomingManeuvers: []
  )
  private var maneuverCache: [String: CPManeuver] = [:]
  private let locationManager = CLLocationManager()

  private override init() {
    super.init()
    locationManager.desiredAccuracy = kCLLocationAccuracyBest
    locationManager.activityType = .automotiveNavigation
  }

  func connect(interfaceController: CPInterfaceController, window: CPWindow) {
    self.interfaceController = interfaceController
    self.carWindow = window

    if locationManager.authorizationStatus == .notDetermined {
      locationManager.requestWhenInUseAuthorization()
    }
    locationManager.startUpdatingLocation()

    let rootViewController = CarPlayMapViewController()
    window.rootViewController = rootViewController
    window.isHidden = false
    updateMapOverlay()

    let template = makeMapTemplate()
    mapTemplate = template
    interfaceController.delegate = self
    interfaceController.setRootTemplate(template, animated: false, completion: nil)
    requestDestinationSync()
  }

  func disconnect() {
    navigationSession = nil
    activeTrip = nil
    activeDestination = nil
    maneuverCache.removeAll()
    mapTemplate = nil
    interfaceController?.delegate = nil
    interfaceController = nil
    carWindow?.rootViewController = nil
    carWindow = nil
    locationManager.stopUpdatingLocation()
  }

  func configureFlutterBridge(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
    flutterChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handleFlutterCall(call, result: result)
    }
    requestDestinationSync()
  }

  private func makeMapTemplate() -> CPMapTemplate {
    let template = CPMapTemplate()
    template.mapDelegate = self
    template.automaticallyHidesNavigationBar = false
    template.hidesButtonsWithNavigationBar = false
    template.guidanceBackgroundColor = UIColor(red: 0.04, green: 0.16, blue: 0.62, alpha: 1)

    let destinationsButton = CPBarButton(title: "Mål") { [weak self] _ in
      self?.showDestinationsList()
    }
    destinationsButton.buttonStyle = .rounded

    let overviewButton = CPBarButton(title: "Översikt") { [weak self] _ in
      self?.resetToOverview()
    }

    template.leadingNavigationBarButtons = [destinationsButton]
    template.trailingNavigationBarButtons = [overviewButton]

    let browseButton = CPMapButton { [weak self] _ in
      self?.showDestinationsList()
    }
    browseButton.image = UIImage(systemName: "magnifyingglass.circle.fill")

    let endButton = CPMapButton { [weak self] _ in
      self?.endActiveNavigation(notifyFlutter: true)
    }
    endButton.image = UIImage(systemName: "xmark.circle.fill")

    template.mapButtons = [browseButton, endButton]
    return template
  }

  private func showDestinationsList() {
    guard let interfaceController else { return }

    let template = CPListTemplate(title: "CruizX mål", sections: makeDestinationSections())
    template.emptyViewTitleVariants = ["Inga destinationer"]
    template.emptyViewSubtitleVariants = ["Spara favoriter eller välj mål i appen så dyker de upp här."]
    interfaceController.pushTemplate(template, animated: true, completion: nil)
  }

  private func previewTrip(to destination: Destination) {
    guard let interfaceController, let mapTemplate else { return }

    let trip = makeTrip(for: destination)
    activeTrip = trip
    activeDestination = destination

    let estimates = makeEstimates(for: destination)
    mapTemplate.showTripPreviews([trip], selectedTrip: trip, textConfiguration: nil)
    mapTemplate.updateEstimates(estimates, for: trip)

    interfaceController.popToRootTemplate(animated: true, completion: nil)
  }

  private func makeTrip(for destination: Destination) -> CPTrip {
    let originPlacemark = MKPlacemark(coordinate: currentOriginCoordinate())
    let destinationPlacemark = MKPlacemark(coordinate: destination.coordinate)
    let originItem = MKMapItem(placemark: originPlacemark)
    let destinationItem = MKMapItem(placemark: destinationPlacemark)
    originItem.name = "Nuvarande position"
    destinationItem.name = destination.title

    let estimates = makeEstimates(for: destination)
    let minutes = max(1, Int((estimates.timeRemaining / 60).rounded()))
    let distanceKilometers = estimates.distanceRemaining.converted(to: .kilometers).value

    let routeChoice = CPRouteChoice(
      summaryVariants: [destination.source.routeSummary],
      additionalInformationVariants: ["\(minutes) min", "\(distanceKilometers.formatted(.number.precision(.fractionLength(1)))) km"],
      selectionSummaryVariants: ["Starta till \(destination.title)"]
    )

    let trip = CPTrip(origin: originItem, destination: destinationItem, routeChoices: [routeChoice])
    if #available(iOS 17.4, *) {
      trip.destinationNameVariants = [destination.title]
    }
    return trip
  }

  private func resetToOverview() {
    activeTrip = nil
    activeDestination = nil
    mapTemplate?.hideTripPreviews()
  }

  private func endActiveNavigation(notifyFlutter: Bool = false) {
    navigationSession?.finishTrip()
    navigationSession = nil
    activeTrip = nil
    activeDestination = nil
    mapTemplate?.hideTripPreviews()
    if notifyFlutter {
      stopFlutterNavigation()
    }
  }

  private func requestDestinationSync() {
    flutterChannel?.invokeMethod("requestSyncState", arguments: nil)
  }

  private func handleFlutterCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "syncState":
      applyFlutterState(call.arguments)
      result(nil)
    case "syncNavigationState":
      applyNavigationState(call.arguments)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func applyFlutterState(_ arguments: Any?) {
    guard let payload = arguments as? [String: Any] else { return }
    favoriteDestinations = decodeDestinations(payload["favorites"], source: .favorite)
    recentDestinations = decodeDestinations(payload["recents"], source: .recent)
    updateMapOverlay()
    refreshVisibleDestinationListIfNeeded()
  }

  private func decodeDestinations(_ raw: Any?, source: Destination.Source) -> [Destination] {
    guard let items = raw as? [Any] else { return [] }

    return items.compactMap { item in
      guard let values = item as? [String: Any],
            let title = stringValue(values["title"]),
            let latitude = doubleValue(values["latitude"] ?? values["lat"]),
            let longitude = doubleValue(values["longitude"] ?? values["lon"])
      else {
        return nil
      }

      return Destination(
        title: title,
        subtitle: stringValue(values["subtitle"] ?? values["address"]) ?? "",
        coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
        source: source
      )
    }
  }

  private func applyNavigationState(_ arguments: Any?) {
    guard let payload = arguments as? [String: Any] else { return }

    navigationState = NavigationState(
      hasRoute: (payload["hasRoute"] as? Bool) ?? false,
      isNavigating: (payload["isNavigating"] as? Bool) ?? false,
      totalDistanceMeters: doubleValue(payload["totalDistanceMeters"]),
      remainingDistanceMeters: doubleValue(payload["remainingDistanceMeters"]),
      remainingDurationSeconds: doubleValue(payload["remainingDurationSeconds"]),
      nextManeuverText: stringValue(payload["nextManeuverText"]) ?? "",
      currentStreetName: stringValue(payload["currentStreetName"]) ?? "",
      upcomingManeuvers: decodeManeuverPayloads(payload["upcomingManeuvers"])
    )

    if let destinationPayload = payload["destination"] as? [String: Any],
       let latitude = doubleValue(destinationPayload["latitude"] ?? destinationPayload["lat"]),
       let longitude = doubleValue(destinationPayload["longitude"] ?? destinationPayload["lon"]) {
      let title = stringValue(destinationPayload["title"] ?? destinationPayload["label"]) ?? "Vald destination"
      activeDestination = Destination(
        title: title,
        subtitle: stringValue(destinationPayload["subtitle"] ?? destinationPayload["address"]) ?? "",
        coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
        source: .recent
      )
    } else if !navigationState.hasRoute {
      activeDestination = nil
    }

    syncCarPlayNavigationUI()
  }

  private func decodeManeuverPayloads(_ raw: Any?) -> [ManeuverPayload] {
    guard let items = raw as? [Any] else { return [] }

    return items.compactMap { item in
      guard let values = item as? [String: Any],
            let id = stringValue(values["id"]),
            let text = stringValue(values["text"]),
            let sign = intValue(values["sign"]),
            let distanceMeters = doubleValue(values["distanceMeters"])
      else {
        return nil
      }

      return ManeuverPayload(
        id: id,
        text: text,
        streetName: stringValue(values["streetName"]) ?? "",
        sign: sign,
        distanceMeters: distanceMeters
      )
    }
  }

  private func stringValue(_ value: Any?) -> String? {
    guard let value else { return nil }
    let text = String(describing: value).trimmingCharacters(in: .whitespacesAndNewlines)
    return text.isEmpty || text == "null" ? nil : text
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

  private func intValue(_ value: Any?) -> Int? {
    switch value {
    case let number as NSNumber:
      return number.intValue
    case let text as String:
      return Int(text)
    default:
      return nil
    }
  }

  private func makeDestinationSections() -> [CPListSection] {
    var sections: [CPListSection] = []

    if !favoriteDestinations.isEmpty {
      sections.append(
        CPListSection(
          items: favoriteDestinations.map(makeDestinationListItem),
          header: Destination.Source.favorite.sectionTitle,
          sectionIndexTitle: nil
        )
      )
    }

    if !recentDestinations.isEmpty {
      sections.append(
        CPListSection(
          items: recentDestinations.map(makeDestinationListItem),
          header: Destination.Source.recent.sectionTitle,
          sectionIndexTitle: nil
        )
      )
    }

    return sections
  }

  private func makeDestinationListItem(for destination: Destination) -> CPListItem {
    let item = CPListItem(text: destination.title, detailText: destination.subtitle)
    item.handler = { [weak self] _, completion in
      self?.previewTrip(to: destination)
      completion()
    }
    return item
  }

  private func makeEstimates(for destination: Destination) -> CPTravelEstimates {
    let origin = CLLocation(latitude: currentOriginCoordinate().latitude, longitude: currentOriginCoordinate().longitude)
    let target = CLLocation(latitude: destination.coordinate.latitude, longitude: destination.coordinate.longitude)
    let straightDistanceMeters = max(origin.distance(from: target), 500)
    let routeDistanceMeters = straightDistanceMeters * 1.18
    let averageSpeedMetersPerSecond = 15.0
    let timeSeconds = max(routeDistanceMeters / averageSpeedMetersPerSecond, 60)

    return CPTravelEstimates(
      distanceRemaining: Measurement(value: routeDistanceMeters / 1000, unit: UnitLength.kilometers),
      timeRemaining: timeSeconds
    )
  }

  private func makeEstimatesFromNavigationState(for destination: Destination) -> CPTravelEstimates {
    let fallback = makeEstimates(for: destination)
    let distanceMeters = max(
      navigationState.remainingDistanceMeters ??
        fallback.distanceRemaining.converted(to: .meters).value,
      0
    )
    let timeSeconds = max(
      navigationState.remainingDurationSeconds ?? fallback.timeRemaining,
      0
    )

    return CPTravelEstimates(
      distanceRemaining: Measurement(value: distanceMeters / 1000, unit: UnitLength.kilometers),
      timeRemaining: timeSeconds
    )
  }

  private func currentOriginCoordinate() -> CLLocationCoordinate2D {
    if let coordinate = locationManager.location?.coordinate {
      return coordinate
    }
    return CLLocationCoordinate2D(latitude: 59.3293, longitude: 18.0686)
  }

  private func refreshVisibleDestinationListIfNeeded() {
    guard let listTemplate = interfaceController?.topTemplate as? CPListTemplate,
          listTemplate.title == "CruizX mål"
    else {
      return
    }
    listTemplate.updateSections(makeDestinationSections())
  }

  private func updateMapOverlay() {
    guard let rootViewController = carWindow?.rootViewController as? CarPlayMapViewController else {
      return
    }

    rootViewController.updateOverlay(
      title: "CruizX CarPlay",
      subtitle: overlaySubtitle(),
      status: overlayStatus()
    )
  }

  private func startFlutterNavigation(to destination: Destination) {
    flutterChannel?.invokeMethod("startNavigation", arguments: [
      "lat": destination.coordinate.latitude,
      "lon": destination.coordinate.longitude,
      "label": destination.title,
      "address": destination.subtitle,
    ])
  }

  private func stopFlutterNavigation() {
    flutterChannel?.invokeMethod("stopNavigation", arguments: nil)
  }

  private func syncCarPlayNavigationUI() {
    if !navigationState.hasRoute {
      endActiveNavigation()
      updateMapOverlay()
      return
    }

    guard let destination = activeDestination else {
      updateMapOverlay()
      return
    }

    let trip = activeTrip ?? makeTrip(for: destination)
    activeTrip = trip

    if navigationState.isNavigating {
      if navigationSession == nil, let mapTemplate {
        navigationSession = mapTemplate.startNavigationSession(for: trip)
      }
      updateNavigationSessionGuidance()
    } else if let mapTemplate {
      mapTemplate.showTripPreviews([trip], selectedTrip: trip, textConfiguration: nil)
    }

    if let mapTemplate {
      mapTemplate.update(makeEstimatesFromNavigationState(for: destination), for: trip, with: .green)
    }

    updateMapOverlay()
  }

  private func updateNavigationSessionGuidance() {
    guard #available(iOS 17.4, *),
          let navigationSession
    else {
      return
    }

    let maneuvers = navigationState.upcomingManeuvers.map(makeOrUpdateManeuver)
    let newManeuvers = maneuvers.filter { maneuver in
      !navigationSession.upcomingManeuvers.contains { $0 === maneuver }
    }
    if !newManeuvers.isEmpty {
      navigationSession.add(newManeuvers)
    }
    navigationSession.upcomingManeuvers = maneuvers

    if let firstManeuver = maneuvers.first {
      navigationSession.updateEstimates(
        CPTravelEstimates(
          distanceRemaining: Measurement(
            value: max(navigationState.upcomingManeuvers.first?.distanceMeters ?? 0, 0),
            unit: UnitLength.meters
          ),
          timeRemaining: firstManeuver.initialTravelEstimates?.timeRemaining ?? 0
        ),
        for: firstManeuver
      )
      navigationSession.maneuverState = maneuverState(
        forDistanceMeters: navigationState.upcomingManeuvers.first?.distanceMeters
      )
    }

    let roadName = navigationState.currentStreetName.trimmingCharacters(in: .whitespacesAndNewlines)
    navigationSession.currentRoadNameVariants = roadName.isEmpty ? [] : [roadName]
  }

  @available(iOS 17.4, *)
  private func makeOrUpdateManeuver(from payload: ManeuverPayload) -> CPManeuver {
    let maneuver = maneuverCache[payload.id] ?? {
      let created = CPManeuver()
      maneuverCache[payload.id] = created
      return created
    }()

    maneuver.instructionVariants = [payload.text]
    maneuver.dashboardInstructionVariants = [payload.text]
    maneuver.notificationInstructionVariants = [payload.text]
    maneuver.initialTravelEstimates = CPTravelEstimates(
      distanceRemaining: Measurement(
        value: max(payload.distanceMeters, 0),
        unit: UnitLength.meters
      ),
      timeRemaining: estimatedTimeForManeuver(distanceMeters: payload.distanceMeters)
    )
    maneuver.maneuverType = maneuverType(forSign: payload.sign)
    if !payload.streetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      maneuver.roadFollowingManeuverVariants = [payload.streetName]
    } else {
      maneuver.roadFollowingManeuverVariants = nil
    }
    maneuver.trafficSide = .right
    return maneuver
  }

  @available(iOS 17.4, *)
  private func maneuverType(forSign sign: Int) -> CPManeuverType {
    switch sign {
    case -3:
      return .sharpLeftTurn
    case -2:
      return .leftTurn
    case -1:
      return .slightLeftTurn
    case 0:
      return .straightAhead
    case 1:
      return .slightRightTurn
    case 2:
      return .rightTurn
    case 3:
      return .sharpRightTurn
    case 4:
      return .arriveAtDestination
    case -6, 6:
      return .exitRoundabout
    default:
      return .followRoad
    }
  }

  @available(iOS 17.4, *)
  private func maneuverState(forDistanceMeters distanceMeters: Double?) -> CPManeuverState {
    let distance = distanceMeters ?? .greatestFiniteMagnitude
    if distance <= 50 {
      return .execute
    }
    if distance <= 200 {
      return .prepare
    }
    if distance <= 1000 {
      return .initial
    }
    return .continue
  }

  private func estimatedTimeForManeuver(distanceMeters: Double) -> TimeInterval {
    max(distanceMeters / 15.0, 1)
  }

  private func overlaySubtitle() -> String {
    if navigationState.hasRoute {
      let remaining = formattedDistanceMeters(navigationState.remainingDistanceMeters)
      let destinationText = activeDestination?.title ?? "Aktiv rutt"
      if !remaining.isEmpty {
        return "\(destinationText) • \(remaining) kvar"
      }
      return destinationText
    }

    let favoriteCount = favoriteDestinations.count
    let recentCount = recentDestinations.count
    if favoriteCount == 0 && recentCount == 0 {
      return "Inga mål synkade ännu. Spara favoriter eller välj en destination i appen för att fylla CarPlay."
    }
    return "\(favoriteCount) favoriter och \(recentCount) senaste mål synkade från appen."
  }

  private func overlayStatus() -> String {
    if navigationState.hasRoute {
      let maneuver = navigationState.nextManeuverText.trimmingCharacters(in: .whitespacesAndNewlines)
      let street = navigationState.currentStreetName.trimmingCharacters(in: .whitespacesAndNewlines)
      if !maneuver.isEmpty && !street.isEmpty {
        return "\(maneuver) • \(street)"
      }
      if !maneuver.isEmpty {
        return maneuver
      }
      if !street.isEmpty {
        return street
      }
      return navigationState.isNavigating ? "Navigation pågår" : "Rutt klar att starta"
    }

    return "Synkar sparade och senaste mål från appen."
  }

  private func formattedDistanceMeters(_ meters: Double?) -> String {
    guard let meters else { return "" }
    if meters >= 1000 {
      return "\(String(format: "%.1f", meters / 1000)) km"
    }
    return "\(Int(meters.rounded())) m"
  }
}

extension CarPlayManager: CPInterfaceControllerDelegate {}

extension CarPlayManager: CPMapTemplateDelegate {
  func mapTemplateShouldProvideNavigationMetadata(_ mapTemplate: CPMapTemplate) -> Bool {
    if #available(iOS 17.4, *) {
      return true
    }
    return false
  }

  func mapTemplate(_ mapTemplate: CPMapTemplate, selectedPreviewFor trip: CPTrip, using routeChoice: CPRouteChoice) {
    activeTrip = trip
  }

  func mapTemplate(_ mapTemplate: CPMapTemplate, startedTrip trip: CPTrip, using routeChoice: CPRouteChoice) {
    activeTrip = trip
    navigationSession = mapTemplate.startNavigationSession(for: trip)

    if let activeDestination {
      mapTemplate.update(makeEstimatesFromNavigationState(for: activeDestination), for: trip, with: .green)
      startFlutterNavigation(to: activeDestination)
    }
  }

  func mapTemplateDidCancelNavigation(_ mapTemplate: CPMapTemplate) {
    endActiveNavigation(notifyFlutter: true)
  }
}
