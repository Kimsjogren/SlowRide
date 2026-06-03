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
  ];

  /// Default country when none is set.
  static const String defaultCountry = 'SE';

  /// Get the routing profile for a [countryCode] + [vehicleType] combination.
  /// Falls back to Swedish rules if the country is unknown.
  static VehicleRoutingProfile getProfile(
    String countryCode,
    String vehicleType,
  ) {
    return _profiles['${countryCode}_$vehicleType'] ??
        _profiles['SE_$vehicleType'] ??
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

  /// Attempt to detect country from GPS coordinates.
  /// Returns null if coordinates don't match any supported country.
  static String? countryFromCoordinates(double lat, double lon) {
    // Spain mainland — check before France to avoid overlap in Pyrenees area.
    if (lat >= 35.9 && lat <= 43.8 && lon >= -9.3 && lon <= 3.3) return 'ES';

    // France mainland.
    if (lat >= 43.0 && lat <= 51.1 && lon >= -5.2 && lon <= 9.6) return 'FR';

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
    // Spain has no native A-tractor class; similar agricultural-derived
    // vehicles are limited to 45 km/h on public roads (DGT circular).
    'ES_A-tractor': VehicleRoutingProfile(
      defaultSpeedKmh: 40,
      maxLegalSpeedKmh: 45,
      useHighways: 0.0,
      useTolls: 0.0,
      useFerry: 0.3,
    ),
    // Cuadriciclo ligero (microcar / moped car): EU-harmonised 45 km/h.
    'ES_Moped car': VehicleRoutingProfile(
      defaultSpeedKmh: 45,
      maxLegalSpeedKmh: 45,
      useHighways: 0.0,
      useTolls: 0.0,
      useFerry: 0.3,
    ),
    // Tractor agrícola: max 40 km/h on public roads (RGC Art. 49).
    'ES_Tractor': VehicleRoutingProfile(
      defaultSpeedKmh: 30,
      maxLegalSpeedKmh: 40,
      useHighways: 0.0,
      useTolls: 0.0,
      useFerry: 0.3,
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
  });

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
}
