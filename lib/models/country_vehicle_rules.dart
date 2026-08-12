/// Country-specific vehicle routing rules.
///
/// Different countries have different speed limits and road restrictions
/// for slow vehicles. This class provides a lookup table mapping
/// country + vehicle type to the correct routing parameters.
///
/// Sources:
///   SE – Transportstyrelsen (Swedish Transport Agency)
///   NO – Statens vegvesen (Norwegian Public Roads Administration)
///   DK – Færdselsstyrelsen (Danish Road Safety Agency)
///   FI – Traficom (Finnish Transport and Communications Agency)
///   FR – Code de la route (French Highway Code)
///   IT – Codice della strada / Ministero delle Infrastrutture e dei Trasporti
///   GB – GOV.UK / DVLA vehicle categories
class CountryVehicleRules {
  CountryVehicleRules._();

  /// Supported country codes (ISO 3166-1 alpha-2).
  static const List<String> supportedCountries = [
    'SE',
    'NO',
    'DK',
    'FI',
    'FR',
    'ES',
    'IT',
    'GB',
  ];

  /// Default country when none is set.
  static const String defaultCountry = 'SE';

  /// Get the routing profile for a [countryCode] + [vehicleType] combination.
  /// Falls back to Swedish rules if the country is unknown.
  static VehicleRoutingProfile getProfile(
    String countryCode,
    String vehicleType,
  ) {
    // Low vehicles use A-tractor rules. Class I mopeds have explicit profiles
    // because their road-position and access rules differ between countries.
    final profileVehicleType = switch (vehicleType) {
      'Low vehicle' => 'A-tractor',
      _ => vehicleType,
    };
    return _profiles['${countryCode}_$profileVehicleType'] ??
        _profiles['SE_$profileVehicleType'] ??
        _defaultProfile;
  }

  /// Default speed (km/h) for a vehicle in a given country.
  static double defaultSpeedFor(String countryCode, String vehicleType) {
    return getProfile(countryCode, vehicleType).defaultSpeedKmh;
  }

  /// Legal max speed (km/h) for a vehicle in a given country.
  static double maxLegalSpeedFor(String countryCode, String vehicleType) {
    return getProfile(countryCode, vehicleType).maxLegalSpeedKmh;
  }

  /// Highest value exposed by the user speed control.
  ///
  /// Electric scooters can be configured up to 40 km/h for private-area and
  /// hardware calibration use. Public-road routing remains capped separately
  /// by [maxLegalSpeedFor].
  static double maxSelectableSpeedFor(String countryCode, String vehicleType) {
    if (vehicleType == 'Electric scooter') return 40;
    return maxLegalSpeedFor(countryCode, vehicleType) + 5;
  }

  /// Attempt to detect country from GPS coordinates.
  /// Returns null if coordinates don't match any supported country.
  static String? countryFromCoordinates(double lat, double lon) {
    // Spain mainland — check before France to avoid overlap in Pyrenees area.
    if (lat >= 35.9 && lat <= 43.8 && lon >= -9.3 && lon <= 3.3) return 'ES';

    // Italy — mainland/peninsula plus Sicily and Sardinia. Split boxes reduce
    // false matches with nearby Corsica and the French Riviera.
    if (lat >= 43.75 && lat <= 46.7 && lon >= 7.0 && lon <= 10.7) return 'IT';
    if (lat >= 44.7 && lat <= 47.1 && lon > 10.7 && lon <= 13.9) return 'IT';
    if (lat >= 42.0 && lat < 44.8 && lon >= 9.4 && lon <= 14.0) return 'IT';
    if (lat >= 37.8 && lat < 42.2 && lon >= 12.0 && lon <= 18.7) return 'IT';
    if (lat >= 36.6 && lat < 38.4 && lon >= 12.3 && lon <= 15.8) return 'IT';
    if (lat >= 38.8 && lat <= 41.4 && lon >= 8.0 && lon <= 9.9) return 'IT';

    // France mainland.
    if (lat >= 43.0 && lat <= 51.1 && lon >= -5.2 && lon <= 9.6) return 'FR';

    // Great Britain (England, Scotland, Wales).
    if (lat >= 49.8 && lat <= 58.8 && lon >= -8.7 && lon <= 2.0) return 'GB';

    // Denmark – Jutland (west of Great Belt).
    if (lat >= 54.5 && lat <= 57.8 && lon >= 8.0 && lon <= 10.9) return 'DK';
    // Denmark – Islands (Zealand, Funen, Bornholm).
    if (lat >= 54.5 && lat <= 56.5 && lon > 10.9 && lon <= 12.8) return 'DK';

    // Finland – east of 20.5°E.
    if (lat >= 59.7 && lat <= 70.1 && lon >= 20.5 && lon <= 31.6) return 'FI';

    // Norway – western Scandinavia south of 68°N.
    if (lat >= 57.9 && lat <= 68.0 && lon >= 4.5 && lon <= 12.5) return 'NO';
    // Northern Norway extends east above 68°N.
    if (lat > 68.0 && lat <= 71.2 && lon >= 4.5 && lon <= 31.0) return 'NO';

    // Sweden – remaining Nordic area.
    if (lat >= 55.3 && lat <= 69.1 && lon >= 10.9 && lon <= 24.2) return 'SE';

    return null;
  }

  // ── Profiles ──────────────────────────────────────────────────────────

  static const _defaultProfile = VehicleRoutingProfile(
    defaultSpeedKmh: 30,
    maxLegalSpeedKmh: 30,
    useHighways: 0.0,
    useTolls: 0.0,
    useFerry: 0.0,
  );

  static const _profiles = <String, VehicleRoutingProfile>{
    // ── Sweden (SE) ─────────────────────────────────────────────────────
    // A-traktor: motorväg & motortrafikled förbjudet, max 30 km/h.
    'SE_A-tractor': VehicleRoutingProfile(
      defaultSpeedKmh: 30,
      maxLegalSpeedKmh: 30,
      useHighways: 0.0,
      useTolls: 0.0,
      useFerry: 0.0,
    ),
    // Mopedbil: motorväg & motortrafikled förbjudet, max 45 km/h.
    'SE_Moped car': VehicleRoutingProfile(
      defaultSpeedKmh: 45,
      maxLegalSpeedKmh: 45,
      useHighways: 0.0,
      useTolls: 0.0,
      useFerry: 0.0,
    ),
    // Moped klass I (L1e-B): max 45 km/h. No motorway, motor-traffic road,
    // cycleway, footway, or pedestrian-only path.
    'SE_Moped class I': VehicleRoutingProfile.mopedClassI(
      legalCategory: 'Moped klass I',
      useFerry: 0.3,
    ),
    // Two-wheel class II moped: max 25 km/h and bicycle traffic rules. It
    // normally uses a cycleway unless a supplementary sign prohibits mopeds.
    'SE_Moped class II': VehicleRoutingProfile.mopedClassII(
      legalCategory: 'Moped klass II',
      useFerry: 0.3,
      prefersCycleways: true,
    ),
    // A compliant Swedish e-scooter is legally a bicycle: max 20 km/h and
    // 250 W, with bicycle access and no pavement riding.
    'SE_Electric scooter': VehicleRoutingProfile.electricScooter(
      legalCategory: 'Cykel (elsparkcykel)',
      maxSpeedKmh: 20,
      useFerry: 0.3,
      useRoads: 0.1,
    ),
    // Traktor: motorväg förbjudet, färja tillåten.
    'SE_Tractor': VehicleRoutingProfile(
      defaultSpeedKmh: 30,
      maxLegalSpeedKmh: 30,
      useHighways: 0.0,
      useTolls: 0.5,
      useFerry: 0.5,
    ),

    // ── Norway (NO) ─────────────────────────────────────────────────────
    // EPA-traktor: motorvei & motortrafikkvei forbudt, max 30 km/h.
    // Ferries are common in Norway and generally accessible to slow vehicles.
    'NO_A-tractor': VehicleRoutingProfile(
      defaultSpeedKmh: 30,
      maxLegalSpeedKmh: 30,
      useHighways: 0.0,
      useTolls: 0.0,
      useFerry: 0.5,
    ),
    'NO_Moped car': VehicleRoutingProfile(
      defaultSpeedKmh: 45,
      maxLegalSpeedKmh: 45,
      useHighways: 0.0,
      useTolls: 0.0,
      useFerry: 0.5,
    ),
    // AM146 two-wheel moped: no motorway/motor-traffic road or cycleway.
    // Two-wheel mopeds may use bus lanes unless signs restrict access.
    'NO_Moped class I': VehicleRoutingProfile.mopedClassI(
      legalCategory: 'Moped AM146',
      useFerry: 0.7,
      allowsTwoWheelBusLanes: true,
    ),
    // Norway has no direct Swedish class-II category. Route the 25 km/h
    // vehicle under local moped road rules and keep it off cycleways.
    'NO_Moped class II': VehicleRoutingProfile.mopedClassII(
      legalCategory: 'Moped (25 km/t)',
      useFerry: 0.7,
      allowsTwoWheelBusLanes: true,
    ),
    // Small electric motor vehicle: max 20 km/h. Cycle lanes, shared paths,
    // roads and considerate pavement use are permitted under local rules.
    'NO_Electric scooter': VehicleRoutingProfile.electricScooter(
      legalCategory: 'Liten elektrisk motorvogn',
      maxSpeedKmh: 20,
      useFerry: 0.7,
      useRoads: 0.1,
      allowsFootwaysAtWalkingSpeed: true,
    ),
    // Traktor: ferries very common and allowed in Norway.
    'NO_Tractor': VehicleRoutingProfile(
      defaultSpeedKmh: 30,
      maxLegalSpeedKmh: 30,
      useHighways: 0.0,
      useTolls: 0.5,
      useFerry: 0.7,
    ),

    // ── Denmark (DK) ────────────────────────────────────────────────────
    // EPA-traktor: motorvej & motortrafikvej forbudt, max 30 km/h.
    'DK_A-tractor': VehicleRoutingProfile(
      defaultSpeedKmh: 30,
      maxLegalSpeedKmh: 30,
      useHighways: 0.0,
      useTolls: 0.0,
      useFerry: 0.3,
    ),
    'DK_Moped car': VehicleRoutingProfile(
      defaultSpeedKmh: 45,
      maxLegalSpeedKmh: 45,
      useHighways: 0.0,
      useTolls: 0.0,
      useFerry: 0.3,
    ),
    // Stor knallert: roadway only, not cycleway, motorway, or motor-traffic
    // road. The Danish 30 km/h "lille knallert" is a separate class.
    'DK_Moped class I': VehicleRoutingProfile.mopedClassI(
      legalCategory: 'Stor knallert',
      useFerry: 0.5,
    ),
    // A 25 km/h vehicle falls within "lille knallert" (legal ceiling 30).
    // A two-wheel small moped must use the cycleway unless signs say otherwise.
    'DK_Moped class II': VehicleRoutingProfile.mopedClassII(
      legalCategory: 'Lille knallert',
      useFerry: 0.5,
      prefersCycleways: true,
    ),
    // Electric scooters follow bicycle rules, must use a cycleway when one is
    // present, and may not be capable of more than 20 km/h.
    'DK_Electric scooter': VehicleRoutingProfile.electricScooter(
      legalCategory: 'El-løbehjul',
      maxSpeedKmh: 20,
      useFerry: 0.5,
      useRoads: 0.0,
    ),
    'DK_Tractor': VehicleRoutingProfile(
      defaultSpeedKmh: 30,
      maxLegalSpeedKmh: 30,
      useHighways: 0.0,
      useTolls: 0.5,
      useFerry: 0.5,
    ),

    // ── Finland (FI) ────────────────────────────────────────────────────
    // Finland has no native A-tractor class. If a Swedish A-tractor is
    // driven in Finland it remains construction-limited to 30 km/h.
    'FI_A-tractor': VehicleRoutingProfile(
      defaultSpeedKmh: 30,
      maxLegalSpeedKmh: 30,
      useHighways: 0.0,
      useTolls: 0.0,
      useFerry: 0.3,
    ),
    // Mopoauto: 45 km/h as in all EU countries.
    'FI_Moped car': VehicleRoutingProfile(
      defaultSpeedKmh: 45,
      maxLegalSpeedKmh: 45,
      useHighways: 0.0,
      useTolls: 0.0,
      useFerry: 0.3,
    ),
    // AM/120 mopo (L1e-B): max 45 km/h; no motorway/motor-traffic road.
    // Cycleways are excluded unless local signs explicitly allow mopeds.
    'FI_Moped class I': VehicleRoutingProfile.mopedClassI(
      legalCategory: 'Mopo AM/120',
      useFerry: 0.5,
    ),
    // No direct class-II equivalent for every Swedish class-II design. A
    // pedal-equipped L1e-A may follow cycle rules, but other mopeds do not;
    // default to the conservative local moped road profile.
    'FI_Moped class II': VehicleRoutingProfile.mopedClassII(
      legalCategory: 'Mopo / L1e-A (25 km/h)',
      useFerry: 0.5,
    ),
    // Light electric vehicle: max 25 km/h and 1 kW, following bicycle rules.
    'FI_Electric scooter': VehicleRoutingProfile.electricScooter(
      legalCategory: 'Kevyt sähköajoneuvo',
      maxSpeedKmh: 25,
      useFerry: 0.5,
      useRoads: 0.1,
    ),
    // Traktori: up to 40 km/h in Finland.
    'FI_Tractor': VehicleRoutingProfile(
      defaultSpeedKmh: 40,
      maxLegalSpeedKmh: 40,
      useHighways: 0.0,
      useTolls: 0.0,
      useFerry: 0.5,
    ),

    // ── France (FR) ─────────────────────────────────────────────────────
    // Voiture sans permis (VSP) – the French equivalent of Moped car.
    // Autoroute & voie express forbidden, max 45 km/h.
    'FR_A-tractor': VehicleRoutingProfile(
      defaultSpeedKmh: 45,
      maxLegalSpeedKmh: 45,
      useHighways: 0.0,
      useTolls: 0.0,
      useFerry: 0.3,
    ),
    'FR_Moped car': VehicleRoutingProfile(
      defaultSpeedKmh: 45,
      maxLegalSpeedKmh: 45,
      useHighways: 0.0,
      useTolls: 0.0,
      useFerry: 0.3,
    ),
    // Cyclomoteur: max 45 km/h; excluded from autoroutes/voies express.
    // Cycleways are excluded unless the local authority explicitly permits it.
    'FR_Moped class I': VehicleRoutingProfile.mopedClassI(
      legalCategory: 'Cyclomoteur',
      useFerry: 0.5,
    ),
    // France has no direct class-II category. Keep the vehicle's 25 km/h
    // construction limit and use cyclomoteur access rules.
    'FR_Moped class II': VehicleRoutingProfile.mopedClassII(
      legalCategory: 'Cyclomoteur (25 km/h)',
      useFerry: 0.5,
    ),
    // EDPM: max 25 km/h. Cycle lanes/tracks are mandatory when present;
    // outside built-up areas use greenways/cycleways unless locally authorised.
    'FR_Electric scooter': VehicleRoutingProfile.electricScooter(
      legalCategory: 'EDPM / trottinette électrique',
      maxSpeedKmh: 25,
      useFerry: 0.5,
      useRoads: 0.0,
    ),
    // Tracteur agricole: older models limited to 25 km/h (Art. R413-12),
    // but 2016 reform allows EU T1 tractors up to 40 km/h on public roads.
    'FR_Tractor': VehicleRoutingProfile(
      defaultSpeedKmh: 25,
      maxLegalSpeedKmh: 40,
      useHighways: 0.0,
      useTolls: 0.0,
      useFerry: 0.3,
    ),

    // ── Spain (ES) ──────────────────────────────────────────────────────
    // In Spain autopista/autovía are OSM `motorway` (always forbidden here),
    // while `trunk` maps to ordinary N-roads (carreteras nacionales) that
    // these vehicles ARE allowed to use — so motor roads (trunk) are NOT
    // additionally forbidden.
    // Spain has no native A-tractor class; similar agricultural-derived
    // vehicles are limited to 45 km/h on public roads (DGT circular).
    'ES_A-tractor': VehicleRoutingProfile(
      defaultSpeedKmh: 40,
      maxLegalSpeedKmh: 45,
      useHighways: 0.0,
      useTolls: 0.0,
      useFerry: 0.3,
      forbidsMotorRoads: false,
    ),
    // Cuadriciclo ligero (microcar / moped car): EU-harmonised 45 km/h.
    'ES_Moped car': VehicleRoutingProfile(
      defaultSpeedKmh: 45,
      maxLegalSpeedKmh: 45,
      useHighways: 0.0,
      useTolls: 0.0,
      useFerry: 0.3,
      forbidsMotorRoads: false,
    ),
    // Ciclomotor: max 45 km/h; no autopista/autovía (OSM motorway). On
    // conventional interurban N-roads (trunk) the rider must use the passable
    // shoulder when present, but the road itself is allowed.
    'ES_Moped class I': VehicleRoutingProfile.mopedClassI(
      legalCategory: 'Ciclomotor',
      useFerry: 0.5,
      requiresRoadShoulderWhereAvailable: true,
      forbidsMotorRoads: false,
    ),
    // Spain treats it as a ciclomotor. It must use a passable shoulder on
    // conventional interurban roads and may not use autopistas/autovías.
    'ES_Moped class II': VehicleRoutingProfile.mopedClassII(
      legalCategory: 'Ciclomotor (25 km/h)',
      useFerry: 0.5,
      requiresRoadShoulderWhereAvailable: true,
    ),
    // VMP: 6–25 km/h and urban routes only. Municipal ordinances decide which
    // urban roads are authorised; interurban roads and urban tunnels are banned.
    'ES_Electric scooter': VehicleRoutingProfile.electricScooter(
      legalCategory: 'VMP / patinete eléctrico',
      maxSpeedKmh: 25,
      useFerry: 0.0,
      useRoads: 0.8,
      urbanRoadsOnly: true,
    ),
    // Tractor agrícola: max 40 km/h on public roads (RGC Art. 49). Allowed on
    // N-roads (trunk); only autopista/autovía (motorway) are forbidden.
    'ES_Tractor': VehicleRoutingProfile(
      defaultSpeedKmh: 30,
      maxLegalSpeedKmh: 40,
      forbidsMotorRoads: false,
      useHighways: 0.0,
      useTolls: 0.0,
      useFerry: 0.3,
    ),

    // ── Italy (IT) ──────────────────────────────────────────────────────
    // Italy has no native A-tractor category. A Swedish A-tractor remains
    // construction-limited to 30 km/h and is conservatively kept away from
    // autostrade and main extra-urban roads.
    'IT_A-tractor': VehicleRoutingProfile(
      defaultSpeedKmh: 30,
      maxLegalSpeedKmh: 30,
      useHighways: 0.0,
      useTolls: 0.0,
      useFerry: 0.3,
    ),
    // Quadriciclo leggero / minicar (L6e): construction speed max 45 km/h.
    'IT_Moped car': VehicleRoutingProfile(
      defaultSpeedKmh: 45,
      maxLegalSpeedKmh: 45,
      useHighways: 0.0,
      useTolls: 0.0,
      useFerry: 0.3,
    ),
    // Ciclomotore: max 45 km/h; forbidden on autostrade and strade
    // extraurbane principali, and on cycle-only infrastructure.
    'IT_Moped class I': VehicleRoutingProfile.mopedClassI(
      legalCategory: 'Ciclomotore',
      useFerry: 0.5,
    ),
    // Italy treats the vehicle as a ciclomotore; the Swedish vehicle's lower
    // 25 km/h construction speed remains the routing ceiling.
    'IT_Moped class II': VehicleRoutingProfile.mopedClassII(
      legalCategory: 'Ciclomotore (25 km/h)',
      useFerry: 0.5,
    ),
    // Electric scooter: max 20 km/h (6 km/h in pedestrian areas). In built-up
    // areas it may use roads limited to 50 km/h and authorised cycle routes.
    'IT_Electric scooter': VehicleRoutingProfile.electricScooter(
      legalCategory: 'Monopattino elettrico',
      maxSpeedKmh: 20,
      useFerry: 0.3,
      useRoads: 0.25,
      maxRoadSpeedLimitKmh: 50,
    ),
    // Agricultural machines: normally 40 km/h with pneumatic-equivalent
    // running gear (15 km/h otherwise). Use 30 km/h as the safe default.
    'IT_Tractor': VehicleRoutingProfile(
      defaultSpeedKmh: 30,
      maxLegalSpeedKmh: 40,
      useHighways: 0.0,
      useTolls: 0.0,
      useFerry: 0.3,
    ),

    // ── United Kingdom / Great Britain (GB) ─────────────────────────────
    // Light quadricycles/moped cars use the AM-style 45 km/h class.
    // Agricultural tractors are treated as slow vehicles and kept off motorways.
    // UK law allows these on A-roads/dual carriageways (trunk); only motorways
    // are forbidden, so forbidsMotorRoads is false here.
    'GB_A-tractor': VehicleRoutingProfile(
      defaultSpeedKmh: 45,
      maxLegalSpeedKmh: 45,
      useHighways: 0.0,
      useTolls: 0.0,
      useFerry: 0.3,
      forbidsMotorRoads: false,
    ),
    'GB_Moped car': VehicleRoutingProfile(
      defaultSpeedKmh: 45,
      maxLegalSpeedKmh: 45,
      useHighways: 0.0,
      useTolls: 0.0,
      useFerry: 0.3,
      forbidsMotorRoads: false,
    ),
    // Category AM moped: max 45 km/h. Motorways are forbidden; ordinary dual
    // carriageways remain legally possible, although the router penalises
    // high-speed primary roads for safety. Cycle-only lanes remain excluded.
    'GB_Moped class I': VehicleRoutingProfile.mopedClassI(
      legalCategory: 'Category AM moped',
      useFerry: 0.5,
      forbidsMotorRoads: false,
    ),
    // Category Q covers two/three-wheel vehicles without pedals at no more
    // than 25 km/h. They use roads, not cycle tracks or cycle lanes.
    'GB_Moped class II': VehicleRoutingProfile.mopedClassII(
      legalCategory: 'Category Q (25 km/h)',
      useFerry: 0.5,
      forbidsMotorRoads: false,
    ),
    // Public-road use is limited to approved rental trials. Private e-scooters
    // remain illegal on public roads and in public spaces.
    'GB_Electric scooter': VehicleRoutingProfile.electricScooter(
      legalCategory: 'Approved rental e-scooter',
      maxSpeedKmh: 25,
      useFerry: 0.0,
      useRoads: 0.4,
      requiresApprovedRental: true,
      forbidsMotorRoads: false,
    ),
    'GB_Tractor': VehicleRoutingProfile(
      defaultSpeedKmh: 30,
      maxLegalSpeedKmh: 40,
      useHighways: 0.0,
      useTolls: 0.0,
      useFerry: 0.3,
      forbidsMotorRoads: false,
    ),
  };
}

/// Routing parameters for a specific vehicle type in a specific country.
class VehicleRoutingProfile {
  const VehicleRoutingProfile({
    required this.defaultSpeedKmh,
    required this.maxLegalSpeedKmh,
    required this.useHighways,
    required this.useTolls,
    required this.useFerry,
    this.usePrimary = 0.0,
    this.useTracks = 0.5,
    this.excludeUnpaved = false,
    this.legalCategory,
    this.allowsCyclewaysByDefault = false,
    this.requiresRoadShoulderWhereAvailable = false,
    this.allowsTwoWheelBusLanes = false,
    this.forbidsMotorRoads = true,
    this.prefersCycleways = false,
    this.useRoads = 0.5,
    this.urbanRoadsOnly = false,
    this.requiresApprovedRental = false,
    this.allowsFootwaysAtWalkingSpeed = false,
    this.maxRoadSpeedLimitKmh,
  });

  const VehicleRoutingProfile.mopedClassI({
    required this.legalCategory,
    required this.useFerry,
    this.requiresRoadShoulderWhereAvailable = false,
    this.allowsTwoWheelBusLanes = false,
    this.forbidsMotorRoads = true,
  }) : defaultSpeedKmh = 45,
       maxLegalSpeedKmh = 45,
       useHighways = 0.0,
       useTolls = 0.5,
       usePrimary = 0.0,
       useTracks = 0.0,
       excludeUnpaved = true,
       allowsCyclewaysByDefault = false,
       prefersCycleways = false,
       useRoads = 0.5,
       urbanRoadsOnly = false,
       requiresApprovedRental = false,
       allowsFootwaysAtWalkingSpeed = false,
       maxRoadSpeedLimitKmh = null;

  const VehicleRoutingProfile.mopedClassII({
    required this.legalCategory,
    required this.useFerry,
    this.prefersCycleways = false,
    this.requiresRoadShoulderWhereAvailable = false,
    this.allowsTwoWheelBusLanes = false,
    this.forbidsMotorRoads = true,
  }) : defaultSpeedKmh = 25,
       maxLegalSpeedKmh = 25,
       useHighways = 0.0,
       useTolls = 0.5,
       usePrimary = 0.0,
       useTracks = 0.0,
       excludeUnpaved = true,
       allowsCyclewaysByDefault = prefersCycleways,
       useRoads = 0.0,
       urbanRoadsOnly = false,
       requiresApprovedRental = false,
       allowsFootwaysAtWalkingSpeed = false,
       maxRoadSpeedLimitKmh = null;

  const VehicleRoutingProfile.electricScooter({
    required this.legalCategory,
    required double maxSpeedKmh,
    required this.useFerry,
    required this.useRoads,
    this.urbanRoadsOnly = false,
    this.requiresApprovedRental = false,
    this.allowsFootwaysAtWalkingSpeed = false,
    this.maxRoadSpeedLimitKmh,
    this.forbidsMotorRoads = true,
  }) : defaultSpeedKmh = maxSpeedKmh,
       maxLegalSpeedKmh = maxSpeedKmh,
       useHighways = 0.0,
       useTolls = 0.0,
       usePrimary = 0.0,
       useTracks = 0.0,
       excludeUnpaved = true,
       allowsCyclewaysByDefault = true,
       prefersCycleways = true,
       requiresRoadShoulderWhereAvailable = false,
       allowsTwoWheelBusLanes = false;

  /// Default speed for this vehicle type (km/h).
  final double defaultSpeedKmh;

  /// Legal maximum speed for this vehicle (km/h).
  final double maxLegalSpeedKmh;

  /// Valhalla highway avoidance: 0.0 = avoid completely, 1.0 = use freely.
  final double useHighways;

  /// Valhalla toll avoidance: 0.0 = avoid tolls, 1.0 = use freely.
  final double useTolls;

  /// Valhalla ferry avoidance: 0.0 = avoid ferries, 1.0 = use freely.
  final double useFerry;

  /// Preference for primary roads. Kept at zero for vulnerable slow vehicles.
  final double usePrimary;

  /// Preference for tracks. Class I mopeds avoid tracks by default.
  final double useTracks;

  /// Whether unpaved ways should be excluded where map data permits it.
  final bool excludeUnpaved;

  /// Local legal name, retained for audits and server-side safety context.
  final String? legalCategory;

  /// Whether ordinary cycleways are legal without an explicit moped sign.
  final bool allowsCyclewaysByDefault;

  /// Spain requires the passable shoulder on conventional interurban roads.
  final bool requiresRoadShoulderWhereAvailable;

  /// Norway permits two-wheel mopeds in bus lanes unless signs say otherwise.
  final bool allowsTwoWheelBusLanes;

  /// Whether the country's motorway-like motor-road class is also forbidden.
  final bool forbidsMotorRoads;

  /// Whether routing should prefer cycleways under the local two-wheel rules.
  final bool prefersCycleways;

  /// Bicycle-costing preference for ordinary roads (0 = prefer cycleways).
  final double useRoads;

  /// Whether public routing is restricted to locally authorised urban roads.
  final bool urbanRoadsOnly;

  /// Whether public-road use requires an approved rental scheme.
  final bool requiresApprovedRental;

  /// Whether pavement/footway use is allowed only at walking speed.
  final bool allowsFootwaysAtWalkingSpeed;

  /// Maximum posted road speed where this vehicle is permitted, if specified.
  final double? maxRoadSpeedLimitKmh;
}
