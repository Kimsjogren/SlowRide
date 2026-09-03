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
      case search

      var sectionTitle: String {
        switch self {
        case .favorite:
          return "Favoriter"
        case .recent:
          return "Senaste mål"
        case .search:
          return "Sökresultat"
        }
      }

      var routeSummary: String {
        switch self {
        case .favorite:
          return "Favorit"
        case .recent:
          return "Senaste sökning"
        case .search:
          return "Sökresultat"
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
    let currentLocation: CLLocationCoordinate2D?
    let headingDegrees: Double
    let currentSpeed: Double
    let roadSpeedLimit: Double?
    let vehicleSpeedLimit: Double?
    let speedUnitLabel: String
    let countryCode: String
    let totalDistanceMeters: Double?
    let remainingDistanceMeters: Double?
    let remainingDurationSeconds: Double?
    let nextManeuverText: String
    let currentStreetName: String
    let upcomingManeuvers: [ManeuverPayload]
    let markerAssetPath: String?
    let markerIconName: String?
    let markerTintArgb: Int?
  }

  struct ManeuverPayload {
    let id: String
    let text: String
    let shortInstruction: String
    let streetName: String
    let sign: Int
    let distanceMeters: Double
  }

  struct ConvoyMember {
    let userId: String
    let label: String
    let coordinate: CLLocationCoordinate2D
    let assetPath: String?
    let iconName: String?
    let tintArgb: Int?
  }

  struct MapMarker {
    let id: String
    let label: String
    let typeKey: String
    let emoji: String
    let coordinate: CLLocationCoordinate2D
  }

  private weak var interfaceController: CPInterfaceController?
  private weak var carWindow: CPWindow?
  private var dashboardController: CPDashboardController?
  private var dashboardWindow: UIWindow?
  private var mapTemplate: CPMapTemplate?
  private var activeTrip: CPTrip?
  private var activeDestination: Destination?
  private var navigationSession: CPNavigationSession?
  private var isShowingTripPreview = false
  private var flutterChannel: FlutterMethodChannel?
  private var pendingTrafficProposalID: String?
  private var pendingTrafficProposalResult: FlutterResult?
  private var pendingTrafficProposalTemplate: CPAlertTemplate?
  private var favoriteDestinations: [Destination] = []
  private var recentDestinations: [Destination] = []
  private var routeCoordinates: [CLLocationCoordinate2D] = []
  private var routeTrafficSections: [CruizXTrafficSection] = []
  private var routeDestinationCoordinate: CLLocationCoordinate2D?
  private var activeSearch: MKLocalSearch?
  private var searchDestinations: [ObjectIdentifier: Destination] = [:]
  private var activeConvoyName = ""
  private var convoyMembers: [ConvoyMember] = []
  private var mapMarkers: [MapMarker] = []
  private var navigationState = NavigationState(
    hasRoute: false,
    isNavigating: false,
    currentLocation: nil,
    headingDegrees: 0,
    currentSpeed: 0,
    roadSpeedLimit: nil,
    vehicleSpeedLimit: nil,
    speedUnitLabel: "km/h",
    countryCode: "",
    totalDistanceMeters: nil,
    remainingDistanceMeters: nil,
    remainingDurationSeconds: nil,
    nextManeuverText: "",
    currentStreetName: "",
    upcomingManeuvers: [],
    markerAssetPath: nil,
    markerIconName: nil,
    markerTintArgb: nil
  )
  private var maneuverCache: [String: CPManeuver] = [:]
  private var maneuverPresentationCache: [String: String] = [:]
  private var publishedManeuverIDs: [String] = []
  private let locationManager = CLLocationManager()
  private var lastAcceptedCarPlayLocation: CLLocation?

  /// Do not rely only on the scene delegate's disconnect callback. A CarPlay
  /// scene can be torn down while Flutter is suspended, leaving its last
  /// connection event cached on the phone until the next bridge call.
  private var hasLiveCarPlayTemplateScene: Bool {
    guard interfaceController != nil, carWindow != nil else { return false }
    return UIApplication.shared.connectedScenes.contains { scene in
      scene.session.role == .carTemplateApplication
        && scene.activationState != .unattached
    }
  }

  private override init() {
    super.init()
    locationManager.delegate = self
    locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
    locationManager.distanceFilter = kCLDistanceFilterNone
    locationManager.activityType = .automotiveNavigation
    locationManager.pausesLocationUpdatesAutomatically = false
    locationManager.headingFilter = 1
    // Keep a native stream for the CarPlay surface. iOS can pause Flutter UI
    // work while the handset is locked, but active in-car navigation must
    // continue following the vehicle.
    if #available(iOS 9.0, *) {
      locationManager.allowsBackgroundLocationUpdates = true
    }
    if #available(iOS 11.0, *) {
      locationManager.showsBackgroundLocationIndicator = true
    }
  }

  func connect(interfaceController: CPInterfaceController, window: CPWindow) {
    self.interfaceController = interfaceController
    self.carWindow = window

    switch locationManager.authorizationStatus {
    case .notDetermined, .authorizedWhenInUse:
      // "Always" access is the iOS authorization required for GPS updates
      // after the phone is locked during an active CarPlay route.
      locationManager.requestAlwaysAuthorization()
    case .authorizedAlways, .denied, .restricted:
      break
    @unknown default:
      break
    }
    locationManager.startUpdatingLocation()

    let rootViewController = CarPlayMapViewController()
    window.rootViewController = rootViewController
    window.isHidden = false
    updateMapOverlay()
    updateRouteMap()
    updateConvoyMap()

    let template = makeMapTemplate()
    mapTemplate = template
    interfaceController.delegate = self
    interfaceController.setRootTemplate(template, animated: false, completion: nil)
    notifyFlutterConnectionState(true)
    requestDestinationSync()
  }

  func disconnect() {
    finishTrafficRerouteProposal(accepted: false, dismissTemplate: false)
    activeSearch?.cancel()
    activeSearch = nil
    searchDestinations.removeAll()
    navigationSession = nil
    activeTrip = nil
    activeDestination = nil
    isShowingTripPreview = false
    maneuverCache.removeAll()
    maneuverPresentationCache.removeAll()
    publishedManeuverIDs.removeAll()
    mapTemplate = nil
    interfaceController?.delegate = nil
    interfaceController = nil
    carWindow?.rootViewController = nil
    carWindow = nil
    locationManager.stopUpdatingLocation()
    notifyFlutterConnectionState(false)
  }

  func connectDashboard(controller: CPDashboardController, window: UIWindow) {
    dashboardController = controller
    dashboardWindow = window

    let rootViewController = CarPlayMapViewController(isDashboardSurface: true)
    window.rootViewController = rootViewController
    window.isHidden = false
    rootViewController.loadViewIfNeeded()

    // CarPlay displays these only while route guidance is inactive and hides
    // them automatically when active guidance takes over the dashboard.
    controller.shortcutButtons = makeDashboardButtons()

    updateMapOverlay()
    updateRouteMap()
    updateConvoyMap()
    requestDestinationSync()
  }

  func disconnectDashboard() {
    dashboardController?.shortcutButtons = []
    dashboardController = nil
    dashboardWindow?.rootViewController = nil
    dashboardWindow = nil
  }

  private func makeDashboardButtons() -> [CPDashboardButton] {
    let searchButton = CPDashboardButton(
      titleVariants: ["Sök mål", "Sök"],
      subtitleVariants: [],
      image: UIImage(systemName: "magnifyingglass") ?? UIImage()
    ) { [weak self] _ in
      self?.showSearch()
    }
    let recentsButton = CPDashboardButton(
      titleVariants: ["Senaste mål", "Senaste"],
      subtitleVariants: [],
      image: UIImage(systemName: "clock.arrow.circlepath") ?? UIImage()
    ) { [weak self] _ in
      self?.showRecentDestinationsList()
    }
    return [searchButton, recentsButton]
  }

  func configureFlutterBridge(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
    flutterChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handleFlutterCall(call, result: result)
    }
    notifyFlutterConnectionState(hasLiveCarPlayTemplateScene)
    requestDestinationSync()
  }

  private func makeMapTemplate() -> CPMapTemplate {
    let template = CPMapTemplate()
    template.mapDelegate = self
    // Restore CarPlay's normal uncluttered navigation behavior: the map
    // controls fade away after interaction and appear only when needed.
    template.automaticallyHidesNavigationBar = true
    template.hidesButtonsWithNavigationBar = true
    // CarPlay owns the guidance card's dimensions. A deeper CruizX navy makes
    // the system card less visually dominant without reducing legibility.
    template.guidanceBackgroundColor = UIColor(red: 0.025, green: 0.10, blue: 0.38, alpha: 0.96)

    let recentsButton = CPBarButton(
      image: UIImage(systemName: "clock.arrow.circlepath") ?? UIImage()
    ) { [weak self] _ in
      self?.showRecentDestinationsList()
    }

    // Keep history available in the auto-hiding navigation bar; CarPlay only
    // permits four persistent map buttons on the right.
    template.leadingNavigationBarButtons = [recentsButton]
    template.trailingNavigationBarButtons = []

    let followButton = CPMapButton { [weak self, weak template] _ in
      guard let self else { return }
      (self.carWindow?.rootViewController as? CarPlayMapViewController)?
        .resumeNavigationFollowing()
      if template?.isPanningInterfaceVisible == true {
        template?.dismissPanningInterface(animated: true)
      }
    }
    // "scope" is the familiar follow/re-centre target used by navigation
    // apps. Keep the glyph padded so CarPlay's fixed circular button appears
    // lighter and less dominant without reducing its required tap target.
    followButton.image = makeMapButtonImage(systemName: "scope")

    let browseButton = CPMapButton { [weak self] _ in
      self?.showSearch()
    }
    browseButton.image = makeMapButtonImage(systemName: "magnifyingglass")

    let convoyButton = CPMapButton { [weak self] _ in
      self?.showConvoyList()
    }
    convoyButton.image = makeMapButtonImage(systemName: "person.3.fill")

    let endButton = CPMapButton { [weak self] _ in
      self?.endActiveNavigation(notifyFlutter: true)
    }
    endButton.image = makeMapButtonImage(systemName: "xmark")

    // CarPlay renders at most four map buttons in array order, top to bottom.
    template.mapButtons = [followButton, browseButton, convoyButton, endButton]
    return template
  }

  private func makeMapButtonImage(systemName: String) -> UIImage {
    let canvasSize = CGSize(width: 30, height: 30)
    let symbolConfiguration = UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
    guard let symbol = UIImage(systemName: systemName, withConfiguration: symbolConfiguration) else {
      return UIImage()
    }
    let renderer = UIGraphicsImageRenderer(size: canvasSize)
    let image = renderer.image { _ in
      let symbolSize = symbol.size
      symbol.withTintColor(.black, renderingMode: .alwaysOriginal).draw(
        at: CGPoint(
          x: (canvasSize.width - symbolSize.width) / 2,
          y: (canvasSize.height - symbolSize.height) / 2
        )
      )
    }
    return image.withRenderingMode(.alwaysTemplate)
  }

  private func showDestinationsList() {
    guard let interfaceController else { return }

    let template = CPListTemplate(title: "CruizX mål", sections: makeDestinationSections())
    template.emptyViewTitleVariants = ["Inga destinationer"]
    template.emptyViewSubtitleVariants = ["Spara favoriter eller välj mål i appen så dyker de upp här."]
    interfaceController.pushTemplate(template, animated: true, completion: nil)
  }

  private func showSearch() {
    guard let interfaceController else { return }
    activeSearch?.cancel()
    searchDestinations.removeAll()
    let template = CPSearchTemplate()
    template.delegate = self
    interfaceController.pushTemplate(template, animated: true, completion: nil)
  }

  private func showRecentDestinationsList() {
    guard let interfaceController else { return }
    let sections = recentDestinations.isEmpty
      ? []
      : [
          CPListSection(
            items: recentDestinations.map(makeDestinationListItem),
            header: Destination.Source.recent.sectionTitle,
            sectionIndexTitle: nil
          )
        ]
    let template = CPListTemplate(title: "Senaste", sections: sections)
    template.emptyViewTitleVariants = ["Inga senaste mål"]
    template.emptyViewSubtitleVariants = ["Sök efter en adress eller välj ett mål i appen först."]
    interfaceController.pushTemplate(template, animated: true, completion: nil)
  }

  private func showConvoyList() {
    guard let interfaceController else { return }

    var items: [CPListItem] = []
    if !convoyMembers.isEmpty {
      let showAll = CPListItem(text: "Visa hela konvojen", detailText: "\(convoyMembers.count) deltagare")
      showAll.handler = { [weak self] _, completion in
        self?.showAllConvoyMembers()
        completion()
      }
      items.append(showAll)

      items.append(contentsOf: convoyMembers.map { member in
        let item = CPListItem(text: member.label, detailText: "Visa på kartan")
        item.handler = { [weak self] _, completion in
          self?.focusOnConvoyMember(member)
          completion()
        }
        return item
      })
    }

    let title = activeConvoyName.isEmpty ? "Konvoj" : activeConvoyName
    let template = CPListTemplate(
      title: title,
      sections: items.isEmpty ? [] : [CPListSection(items: items)]
    )
    template.emptyViewTitleVariants = ["Ingen aktiv konvoj"]
    template.emptyViewSubtitleVariants = ["Öppna en konvoj på mobilen så visas deltagarna här."]
    interfaceController.pushTemplate(template, animated: true, completion: nil)
  }

  private func showAllConvoyMembers() {
    interfaceController?.popToRootTemplate(animated: true, completion: nil)
    (carWindow?.rootViewController as? CarPlayMapViewController)?.showAllConvoyMembers()
  }

  private func focusOnConvoyMember(_ member: ConvoyMember) {
    interfaceController?.popToRootTemplate(animated: true, completion: nil)
    (carWindow?.rootViewController as? CarPlayMapViewController)?
      .focusOnConvoyMember(userId: member.userId)
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

    let routeChoice = CPRouteChoice(
      summaryVariants: [destination.source.routeSummary],
      additionalInformationVariants: [
        "\(minutes) min",
        guidanceDistanceText(estimates.distanceRemaining)
      ],
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
    isShowingTripPreview = false
    mapTemplate?.hideTripPreviews()
  }

  private func endActiveNavigation(notifyFlutter: Bool = false) {
    navigationSession?.finishTrip()
    navigationSession = nil
    activeTrip = nil
    activeDestination = nil
    isShowingTripPreview = false
    maneuverCache.removeAll()
    maneuverPresentationCache.removeAll()
    publishedManeuverIDs.removeAll()
    mapTemplate?.hideTripPreviews()
    if notifyFlutter {
      stopFlutterNavigation()
    }
  }

  private func requestDestinationSync() {
    flutterChannel?.invokeMethod("requestSyncState", arguments: nil)
  }

  private func notifyFlutterConnectionState(_ connected: Bool) {
    flutterChannel?.invokeMethod("carPlayConnectionChanged", arguments: connected)
  }

  private func handleFlutterCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "syncState":
      applyFlutterState(call.arguments)
      result(nil)
    case "syncNavigationState":
      applyNavigationState(call.arguments)
      result(nil)
    case "syncRouteGeometry":
      applyRouteGeometry(call.arguments)
      result(nil)
    case "syncConvoyState":
      applyConvoyState(call.arguments)
      result(nil)
    case "showTrafficRerouteProposal":
      showTrafficRerouteProposal(call.arguments, result: result)
    case "showTrafficWarning":
      // Traffic-delay alerts used CPAlertTemplate and covered the entire
      // CarPlay map (for example: "Incident – 4 min extra").  Navigation
      // must stay visible while driving, so delay/incident information is
      // reflected in ETA only and is never presented as a modal in CarPlay.
      result(nil)
    case "getConnectionState":
      result(hasLiveCarPlayTemplateScene)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func showTrafficRerouteProposal(
    _ arguments: Any?,
    result: @escaping FlutterResult
  ) {
    guard hasLiveCarPlayTemplateScene,
          let controller = interfaceController,
          let payload = arguments as? [String: Any]
    else {
      result(nil)
      return
    }

    finishTrafficRerouteProposal(accepted: false)
    let proposalID = stringValue(payload["id"]) ?? UUID().uuidString
    let title = stringValue(payload["title"]) ?? "Snabbare rutt hittad"
    let body = stringValue(payload["body"]) ?? "En snabbare verifierad rutt finns."
    let keepLabel = stringValue(payload["keepLabel"]) ?? "Behåll"
    let useLabel = stringValue(payload["useLabel"]) ?? "Byt rutt"
    let timeout = max(5, min(intValue(payload["timeoutSeconds"]) ?? 20, 60))

    let keepAction = CPAlertAction(title: keepLabel, style: .cancel) { [weak self] _ in
      self?.finishTrafficRerouteProposal(id: proposalID, accepted: false)
    }
    let useAction = CPAlertAction(title: useLabel, style: .default) { [weak self] _ in
      self?.finishTrafficRerouteProposal(id: proposalID, accepted: true)
    }
    let alert = CPAlertTemplate(
      titleVariants: ["\(title)\n\(body)", "\(title) – \(body)", title],
      actions: [keepAction, useAction]
    )

    pendingTrafficProposalID = proposalID
    pendingTrafficProposalResult = result
    pendingTrafficProposalTemplate = alert
    controller.presentTemplate(alert, animated: true, completion: nil)

    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(timeout)) { [weak self] in
      self?.finishTrafficRerouteProposal(id: proposalID, accepted: false)
    }
  }

  private func finishTrafficRerouteProposal(
    id: String? = nil,
    accepted: Bool,
    dismissTemplate: Bool = true
  ) {
    guard pendingTrafficProposalResult != nil else { return }
    if let id, id != pendingTrafficProposalID { return }

    let callback = pendingTrafficProposalResult
    pendingTrafficProposalID = nil
    pendingTrafficProposalResult = nil
    pendingTrafficProposalTemplate = nil
    if dismissTemplate {
      interfaceController?.dismissTemplate(animated: true, completion: nil)
    }
    callback?(accepted)
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
    let markerStyle = payload["markerStyle"] as? [String: Any]

    navigationState = NavigationState(
      hasRoute: (payload["hasRoute"] as? Bool) ?? false,
      isNavigating: (payload["isNavigating"] as? Bool) ?? false,
      currentLocation: decodeCoordinate(payload["currentLocation"]),
      headingDegrees: doubleValue(payload["headingDegrees"]) ?? 0,
      currentSpeed: doubleValue(payload["currentSpeed"]) ?? 0,
      roadSpeedLimit: doubleValue(payload["roadSpeedLimit"]),
      vehicleSpeedLimit: doubleValue(payload["vehicleSpeedLimit"]),
      speedUnitLabel: stringValue(payload["speedUnitLabel"]) ?? "km/h",
      countryCode: stringValue(payload["countryCode"])?.uppercased() ?? "",
      totalDistanceMeters: doubleValue(payload["totalDistanceMeters"]),
      remainingDistanceMeters: doubleValue(payload["remainingDistanceMeters"]),
      remainingDurationSeconds: doubleValue(payload["remainingDurationSeconds"]),
      nextManeuverText: stringValue(payload["nextManeuverText"]) ?? "",
      currentStreetName: stringValue(payload["currentStreetName"]) ?? "",
      upcomingManeuvers: decodeManeuverPayloads(payload["upcomingManeuvers"]),
      markerAssetPath: stringValue(markerStyle?["assetPath"]),
      markerIconName: stringValue(markerStyle?["iconName"]),
      markerTintArgb: intValue(markerStyle?["tintArgb"])
    )
    mapMarkers = decodeMapMarkers(payload["mapMarkers"])

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

  private func applyRouteGeometry(_ arguments: Any?) {
    guard let payload = arguments as? [String: Any] else { return }
    routeCoordinates = decodeCoordinates(payload["points"])
    routeTrafficSections = decodeTrafficSections(payload["trafficSections"])

    if let destination = payload["destination"] as? [String: Any],
       let latitude = doubleValue(destination["latitude"] ?? destination["lat"]),
       let longitude = doubleValue(destination["longitude"] ?? destination["lon"]) {
      routeDestinationCoordinate = CLLocationCoordinate2D(
        latitude: latitude,
        longitude: longitude
      )
    } else {
      routeDestinationCoordinate = nil
    }

    updateRouteMap()
  }

  private func decodeTrafficSections(_ value: Any?) -> [CruizXTrafficSection] {
    guard let rawSections = value as? [Any] else { return [] }
    return rawSections.compactMap { raw in
      guard let values = raw as? [String: Any] else { return nil }
      let coordinates = decodeCoordinates(values["points"])
      guard coordinates.count >= 2 else { return nil }
      return CruizXTrafficSection(
        level: stringValue(values["level"]) ?? "moderate",
        coordinates: coordinates
      )
    }
  }

  private func applyConvoyState(_ arguments: Any?) {
    guard let payload = arguments as? [String: Any] else { return }
    let isActive = (payload["isActive"] as? Bool) ?? false
    activeConvoyName = isActive ? (stringValue(payload["convoyName"]) ?? "Konvoj") : ""
    let currentUserId = stringValue(payload["currentUserId"])?.trimmingCharacters(in: .whitespacesAndNewlines)

    guard isActive, let rawMembers = payload["members"] as? [Any] else {
      convoyMembers = []
      updateConvoyMap()
      refreshVisibleConvoyListIfNeeded()
      return
    }

    convoyMembers = rawMembers.compactMap { raw in
      guard let values = raw as? [String: Any],
            let userId = stringValue(values["userId"])?.trimmingCharacters(in: .whitespacesAndNewlines),
            !userId.isEmpty,
            userId != currentUserId,
            let latitude = doubleValue(values["latitude"] ?? values["lat"]),
            let longitude = doubleValue(values["longitude"] ?? values["lon"])
      else {
        return nil
      }
      return ConvoyMember(
        userId: userId,
        label: stringValue(values["label"]) ?? "Deltagare",
        coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
        assetPath: stringValue(values["assetPath"]),
        iconName: stringValue(values["iconName"]),
        tintArgb: intValue(values["tintArgb"])
      )
    }
    updateConvoyMap()
    refreshVisibleConvoyListIfNeeded()
  }

  private func decodeCoordinates(_ raw: Any?) -> [CLLocationCoordinate2D] {
    guard let items = raw as? [Any] else { return [] }
    return items.compactMap { item in
      guard let values = item as? [String: Any],
            let latitude = doubleValue(values["latitude"] ?? values["lat"]),
            let longitude = doubleValue(values["longitude"] ?? values["lon"])
      else {
        return nil
      }
      return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
  }

  private func decodeMapMarkers(_ raw: Any?) -> [MapMarker] {
    guard let items = raw as? [Any] else { return [] }
    return items.compactMap { item in
      guard let values = item as? [String: Any],
            let id = stringValue(values["id"]),
            let latitude = doubleValue(values["latitude"] ?? values["lat"]),
            let longitude = doubleValue(values["longitude"] ?? values["lon"])
      else {
        return nil
      }
      return MapMarker(
        id: id,
        label: stringValue(values["label"]) ?? "Markör",
        typeKey: stringValue(values["typeKey"] ?? values["type"]) ?? "hazard",
        emoji: stringValue(values["emoji"]) ?? "⚠️",
        coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
      )
    }
  }

  private func decodeCoordinate(_ raw: Any?) -> CLLocationCoordinate2D? {
    guard let values = raw as? [String: Any],
          let latitude = doubleValue(values["latitude"] ?? values["lat"]),
          let longitude = doubleValue(values["longitude"] ?? values["lon"])
    else {
      return nil
    }
    return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
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
        shortInstruction: stringValue(values["shortInstruction"]) ?? "",
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
      distanceRemaining: guidanceDistanceMeasurement(routeDistanceMeters),
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
    let exactTimeSeconds = max(
      navigationState.remainingDurationSeconds ?? fallback.timeRemaining,
      0
    )
    // The phone UI presents a rounded-up minute count. CarPlay rounds its
    // supplied seconds down when rendering, so send the same minute-rounded
    // value to prevent a visible "0 min" / "1 min" disagreement.
    let timeSeconds = exactTimeSeconds > 0
      ? ceil(exactTimeSeconds / 60) * 60
      : 0

    return CPTravelEstimates(
      distanceRemaining: guidanceDistanceMeasurement(distanceMeters),
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
    guard let listTemplate = interfaceController?.topTemplate as? CPListTemplate else { return }
    if listTemplate.title == "CruizX mål" {
      listTemplate.updateSections(makeDestinationSections())
    } else if listTemplate.title == "Senaste" {
      let sections = recentDestinations.isEmpty
        ? []
        : [
            CPListSection(
              items: recentDestinations.map(makeDestinationListItem),
              header: Destination.Source.recent.sectionTitle,
              sectionIndexTitle: nil
            )
          ]
      listTemplate.updateSections(sections)
    }
  }

  private func refreshVisibleConvoyListIfNeeded() {
    guard let listTemplate = interfaceController?.topTemplate as? CPListTemplate else { return }
    let expectedTitle = activeConvoyName.isEmpty ? "Konvoj" : activeConvoyName
    guard listTemplate.title == "Konvoj" || listTemplate.title == expectedTitle else { return }

    var items: [CPListItem] = []
    if !convoyMembers.isEmpty {
      let showAll = CPListItem(text: "Visa hela konvojen", detailText: "\(convoyMembers.count) deltagare")
      showAll.handler = { [weak self] _, completion in
        self?.showAllConvoyMembers()
        completion()
      }
      items.append(showAll)
      items.append(contentsOf: convoyMembers.map { member in
        let item = CPListItem(text: member.label, detailText: "Visa på kartan")
        item.handler = { [weak self] _, completion in
          self?.focusOnConvoyMember(member)
          completion()
        }
        return item
      })
    }
    listTemplate.updateSections(items.isEmpty ? [] : [CPListSection(items: items)])
  }

  private func updateMapOverlay() {
    for rootViewController in carPlayMapViewControllers {
      rootViewController.updateNavigationMarkerStyle(
        assetPath: navigationState.markerAssetPath,
        iconName: navigationState.markerIconName,
        tintArgb: navigationState.markerTintArgb
      )
      rootViewController.updateNavigationPosition(
        navigationState.currentLocation,
        headingDegrees: navigationState.headingDegrees,
        isNavigating: navigationState.isNavigating
      )
      rootViewController.updateMapMarkers(mapMarkers)
      rootViewController.updateSpeedometers(
        currentSpeed: navigationState.currentSpeed,
        roadSpeedLimit: navigationState.roadSpeedLimit,
        vehicleSpeedLimit: navigationState.vehicleSpeedLimit,
        unitLabel: navigationState.speedUnitLabel,
        usesSwedishRoadSign: navigationState.countryCode == "SE",
        isNavigating: navigationState.isNavigating
      )
    }
  }

  private func updateRouteMap() {
    for rootViewController in carPlayMapViewControllers {
      rootViewController.updateRoute(
        coordinates: routeCoordinates,
        destination: routeDestinationCoordinate,
        isNavigating: navigationState.isNavigating,
        trafficSections: routeTrafficSections
      )
    }
  }

  private func updateConvoyMap() {
    for rootViewController in carPlayMapViewControllers {
      rootViewController.updateConvoyMembers(convoyMembers)
    }
  }

  private var carPlayMapViewControllers: [CarPlayMapViewController] {
    [
      carWindow?.rootViewController as? CarPlayMapViewController,
      dashboardWindow?.rootViewController as? CarPlayMapViewController,
    ].compactMap { $0 }
  }

  private func startFlutterNavigation(to destination: Destination) {
    guard hasLiveCarPlayTemplateScene else {
      notifyFlutterConnectionState(false)
      return
    }
    flutterChannel?.invokeMethod("startNavigation", arguments: [
      "lat": destination.coordinate.latitude,
      "lon": destination.coordinate.longitude,
      "label": destination.title,
      "address": destination.subtitle,
      "startImmediately": true,
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
        isShowingTripPreview = false
      }
      updateNavigationSessionGuidance()
    } else if let mapTemplate, !isShowingTripPreview {
      // Repeating showTripPreviews for every GPS/state sync makes the system
      // card animate up and down just as navigation is started from the phone.
      // Show it once, then leave it stable until a session begins or ends.
      mapTemplate.showTripPreviews([trip], selectedTrip: trip, textConfiguration: nil)
      isShowingTripPreview = true
    }

    for rootViewController in carPlayMapViewControllers {
      rootViewController.updateNavigationPosition(
        navigationState.currentLocation,
        headingDegrees: navigationState.headingDegrees,
        isNavigating: navigationState.isNavigating
      )
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

    // A single concise maneuver keeps the guidance card usable on smaller
    // CarPlay units. The arrow and distance already communicate *when* to
    // turn; the road/exit name communicates *towards what*.
    let payloads = Array(navigationState.upcomingManeuvers.prefix(1))
    let maneuvers = payloads.map(makeOrUpdateManeuver)
    let maneuverIDs = payloads.map(\.id)

    // Replacing upcomingManeuvers makes CarPlay animate the blue guidance
    // card. Keep the same array and objects while the instruction IDs are
    // unchanged; distance is updated separately below.
    if maneuverIDs != publishedManeuverIDs {
      let newManeuvers = maneuvers.filter { maneuver in
        !navigationSession.upcomingManeuvers.contains { $0 === maneuver }
      }
      if !newManeuvers.isEmpty {
        navigationSession.add(newManeuvers)
      }
      navigationSession.upcomingManeuvers = maneuvers
      publishedManeuverIDs = maneuverIDs
    }

    if let firstManeuver = maneuvers.first {
      let firstDistance = max(payloads.first?.distanceMeters ?? 0, 0)
      navigationSession.updateEstimates(
        CPTravelEstimates(
          distanceRemaining: guidanceDistanceMeasurement(firstDistance),
          timeRemaining: estimatedTimeToNextManeuver(distanceMeters: firstDistance)
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

    let streetName = payload.streetName.trimmingCharacters(in: .whitespacesAndNewlines)
    let presentationSignature = "\(payload.sign)|\(streetName)|\(payload.text)"
    guard maneuverPresentationCache[payload.id] != presentationSignature else {
      return maneuver
    }
    maneuverPresentationCache[payload.id] = presentationSignature

    // Retain the action (for example "Sväng höger") plus the destination
    // road, but never the long spoken turn-by-turn sentence.
    let action = payload.shortInstruction.trimmingCharacters(in: .whitespacesAndNewlines)
    let displayedAction = isRoundaboutSign(payload.sign)
      ? roundaboutInstruction(from: payload.text, fallback: action)
      : action
    let conciseInstruction: String
    if streetName.isEmpty {
      conciseInstruction = displayedAction.isEmpty
        ? conciseManeuverText(payload.text)
        : displayedAction
    } else if displayedAction.isEmpty {
      conciseInstruction = streetName
    } else {
      conciseInstruction = "\(displayedAction) · \(streetName)"
    }
    let compactVariants = [conciseInstruction]
    maneuver.instructionVariants = compactVariants
    maneuver.dashboardInstructionVariants = compactVariants
    maneuver.notificationInstructionVariants = compactVariants
    maneuver.initialTravelEstimates = CPTravelEstimates(
      distanceRemaining: guidanceDistanceMeasurement(payload.distanceMeters),
      timeRemaining: estimatedTimeToNextManeuver(distanceMeters: payload.distanceMeters)
    )
    maneuver.maneuverType = maneuverType(forSign: payload.sign)
    if !streetName.isEmpty {
      maneuver.roadFollowingManeuverVariants = [streetName]
    } else {
      maneuver.roadFollowingManeuverVariants = nil
    }
    maneuver.trafficSide = .right
    return maneuver
  }

  /// CarPlay otherwise renders the raw floating point value it receives, for
  /// example `67.3 m`. Navigation distances should be readable at a glance:
  /// 10-metre steps below 1 km, then 0.5-km steps (2, 2.5, 3 … km).
  private func guidanceDistanceMeasurement(_ distanceMeters: Double) -> Measurement<UnitLength> {
    let meters = max(distanceMeters, 0)
    if meters >= 1000 {
      let roundedKilometers = (meters / 500).rounded() * 0.5
      return Measurement(value: max(roundedKilometers, 1), unit: .kilometers)
    }
    let roundedMeters = (meters / 10).rounded() * 10
    return Measurement(value: roundedMeters, unit: .meters)
  }

  private func guidanceDistanceText(_ distance: Measurement<UnitLength>) -> String {
    let formatter = MeasurementFormatter()
    formatter.unitOptions = .providedUnit
    formatter.unitStyle = .short
    formatter.numberFormatter.maximumFractionDigits = 1
    formatter.numberFormatter.minimumFractionDigits = 0
    return formatter.string(from: distance)
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

  private func conciseManeuverText(_ text: String) -> String {
    let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cleaned.isEmpty else { return "Fortsätt" }

    // Routing engines often append a second instruction after "och". That is
    // useful for voice guidance but unnecessarily large on a CarPlay card.
    let firstClause = cleaned.components(separatedBy: " och ").first ?? cleaned
    return String(firstClause.prefix(56)).trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func isRoundaboutSign(_ sign: Int) -> Bool {
    sign == -6 || sign == 6
  }

  /// Preserve the useful exit number in roundabout instructions. The old
  /// compact formatter deliberately cut after "och", which reduced
  /// "Kör in i rondellen och ta 2:a avfarten" to just the first clause.
  private func roundaboutInstruction(from text: String, fallback: String) -> String {
    let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cleaned.isEmpty else { return fallback }

    let patterns = [
      #"(?i)ta\s+(?:den\s+)?(?:\d+(?::[ae])?|första|andra|tredje|fjärde|femte)\s+avfarten"#,
      #"(?i)take\s+(?:the\s+)?(?:\d+(?:st|nd|rd|th)?|first|second|third|fourth|fifth)\s+exit"#,
      #"(?i)tom[ae]\s+(?:la\s+)?(?:\d+(?:ª|º)?|primera|segunda|tercera|cuarta|quinta)\s+salida"#,
      #"(?i)prendre\s+(?:la\s+)?(?:\d+(?:e|ère)?|première|deuxième|troisième|quatrième|cinquième)\s+sortie"#,
      #"(?i)prendi\s+(?:la\s+)?(?:\d+[ªa]?|prima|seconda|terza|quarta|quinta)\s+uscita"#,
    ]

    for pattern in patterns {
      guard let range = cleaned.range(of: pattern, options: .regularExpression) else {
        continue
      }
      let exitInstruction = String(cleaned[range])
      // Use the localised primary action when available, followed by the
      // concrete exit instruction that drivers need before the roundabout.
      return fallback.isEmpty ? exitInstruction : "\(fallback) · \(exitInstruction)"
    }

    return fallback.isEmpty ? conciseManeuverText(cleaned) : fallback
  }

  private func estimatedTimeToNextManeuver(distanceMeters: Double) -> TimeInterval {
    let remainingDistance = navigationState.remainingDistanceMeters ?? 0
    let remainingTime = navigationState.remainingDurationSeconds ?? 0
    if remainingDistance > 1, remainingTime > 0 {
      return min(max(remainingTime * (distanceMeters / remainingDistance), 1), remainingTime)
    }

    return max(distanceMeters / 15.0, 1)
  }

}

extension CarPlayManager: CLLocationManagerDelegate {
  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    switch manager.authorizationStatus {
    case .authorizedAlways, .authorizedWhenInUse:
      manager.startUpdatingLocation()
    case .notDetermined, .denied, .restricted:
      break
    @unknown default:
      break
    }
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let location = locations.last,
          location.horizontalAccuracy >= 0,
          location.horizontalAccuracy <= 120
    else {
      return
    }

    // Ignore a single impossible Core Location jump while the receiver is
    // reacquiring GPS. This keeps CarPlay's marker on its actual road rather
    // than snapping across the map or initiating a false reroute.
    if let previous = lastAcceptedCarPlayLocation {
      let elapsed = location.timestamp.timeIntervalSince(previous.timestamp)
      if elapsed > 0 && elapsed <= 20 {
        let maximumPlausibleJump =
          90 + elapsed * 60 + previous.horizontalAccuracy + location.horizontalAccuracy
        if location.distance(from: previous) > maximumPlausibleJump {
          return
        }
      }
    }
    lastAcceptedCarPlayLocation = location

    // Update the native CarPlay map directly. This remains live even if iOS
    // temporarily suspends Flutter rendering while the phone is locked.
    let heading = location.course >= 0 ? location.course : navigationState.headingDegrees
    for rootViewController in carPlayMapViewControllers {
      if rootViewController.requiresImmediateNativePositionUpdate() {
        // A connected iPhone can keep UIApplication marked active even after
        // its display turns black. Detect the paused display link directly.
        rootViewController.updateBackgroundNavigationPosition(
          location.coordinate,
          headingDegrees: heading,
          isNavigating: navigationState.isNavigating
        )
      } else {
        rootViewController.updateNavigationPosition(
          location.coordinate,
          headingDegrees: heading,
          isNavigating: navigationState.isNavigating
        )
      }
    }
  }
}

extension CarPlayManager: CPInterfaceControllerDelegate {}

extension CarPlayManager: CPSearchTemplateDelegate {
  func searchTemplate(
    _ searchTemplate: CPSearchTemplate,
    updatedSearchText searchText: String,
    completionHandler: @escaping ([CPListItem]) -> Void
  ) {
    activeSearch?.cancel()
    searchDestinations.removeAll()

    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard query.count >= 2 else {
      completionHandler([])
      return
    }

    let request = MKLocalSearch.Request()
    request.naturalLanguageQuery = query
    request.resultTypes = [.address, .pointOfInterest]
    request.region = MKCoordinateRegion(
      center: navigationState.currentLocation ?? currentOriginCoordinate(),
      latitudinalMeters: 80_000,
      longitudinalMeters: 80_000
    )

    let search = MKLocalSearch(request: request)
    activeSearch = search
    search.start { [weak self, weak search] response, _ in
      DispatchQueue.main.async {
        guard let self, let search, self.activeSearch === search else {
          completionHandler([])
          return
        }

        let items = (response?.mapItems ?? []).prefix(12).map { mapItem -> CPListItem in
          let title = mapItem.name?.trimmingCharacters(in: .whitespacesAndNewlines)
          let fallbackTitle = mapItem.placemark.name?.trimmingCharacters(in: .whitespacesAndNewlines)
          let resolvedTitle = (title?.isEmpty == false ? title : fallbackTitle) ?? query
          let fullAddress = mapItem.placemark.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
          let subtitle = fullAddress.caseInsensitiveCompare(resolvedTitle) == .orderedSame
            ? ""
            : fullAddress
          let destination = Destination(
            title: resolvedTitle,
            subtitle: subtitle,
            coordinate: mapItem.placemark.coordinate,
            source: .search
          )
          let item = CPListItem(text: resolvedTitle, detailText: subtitle)
          self.searchDestinations[ObjectIdentifier(item)] = destination
          return item
        }
        completionHandler(Array(items))
      }
    }
  }

  func searchTemplate(
    _ searchTemplate: CPSearchTemplate,
    selectedResult item: CPListItem,
    completionHandler: @escaping () -> Void
  ) {
    defer { completionHandler() }
    guard let destination = searchDestinations[ObjectIdentifier(item)] else { return }
    activeSearch?.cancel()
    activeSearch = nil
    previewTrip(to: destination)
  }

  func searchTemplateSearchButtonPressed(_ searchTemplate: CPSearchTemplate) {
    // Results update continuously through MKLocalSearch while the user types.
  }
}

extension CarPlayManager: CPMapTemplateDelegate {
  func mapTemplateShouldProvideNavigationMetadata(_ mapTemplate: CPMapTemplate) -> Bool {
    if #available(iOS 17.4, *) {
      return true
    }
    return false
  }

  @available(iOS 26.4, *)
  func mapTemplateShouldProvideRouteSharing(_ mapTemplate: CPMapTemplate) -> Bool {
    // Route sharing is a vehicle-integration feature that CruizX does not
    // currently use. Opt out explicitly so compatible CarPlay hosts do not
    // request route-sharing data from the navigation session.
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

  func mapTemplateDidShowPanningInterface(_ mapTemplate: CPMapTemplate) {
    (carWindow?.rootViewController as? CarPlayMapViewController)?.beginManualMapPan()
  }

  func mapTemplateWillDismissPanningInterface(_ mapTemplate: CPMapTemplate) {
    (carWindow?.rootViewController as? CarPlayMapViewController)?.endManualMapPan()
  }

  func mapTemplateDidBeginPanGesture(_ mapTemplate: CPMapTemplate) {
    (carWindow?.rootViewController as? CarPlayMapViewController)?.beginManualMapPan()
  }

  func mapTemplate(
    _ mapTemplate: CPMapTemplate,
    didUpdatePanGestureWithTranslation translation: CGPoint,
    velocity: CGPoint
  ) {
    (carWindow?.rootViewController as? CarPlayMapViewController)?
      .updateManualMapPan(translation: translation)
  }

  func mapTemplate(_ mapTemplate: CPMapTemplate, didEndPanGestureWithVelocity velocity: CGPoint) {
    (carWindow?.rootViewController as? CarPlayMapViewController)?.endManualMapPan()
  }

  func mapTemplate(
    _ mapTemplate: CPMapTemplate,
    panBeganWith direction: CPMapTemplate.PanDirection
  ) {
    (carWindow?.rootViewController as? CarPlayMapViewController)?.panMap(direction: direction)
  }

  func mapTemplate(_ mapTemplate: CPMapTemplate, panWith direction: CPMapTemplate.PanDirection) {
    (carWindow?.rootViewController as? CarPlayMapViewController)?.panMap(direction: direction)
  }

  @available(iOS 26.0, *)
  func mapTemplateDidBeginZoomGesture(_ mapTemplate: CPMapTemplate) {
    (carWindow?.rootViewController as? CarPlayMapViewController)?.beginManualMapZoom()
  }

  @available(iOS 26.0, *)
  func mapTemplate(
    _ mapTemplate: CPMapTemplate,
    didUpdateZoomGestureWithCenter center: CGPoint,
    scale: CGFloat,
    velocity: CGFloat
  ) {
    (carWindow?.rootViewController as? CarPlayMapViewController)?
      .updateManualMapZoom(scale: scale)
  }

  @available(iOS 26.0, *)
  func mapTemplate(_ mapTemplate: CPMapTemplate, didEndZoomGestureWithVelocity velocity: CGFloat) {
    (carWindow?.rootViewController as? CarPlayMapViewController)?.endManualMapZoom()
  }
}
