import 'package:latlong2/latlong.dart';

/// A geographic zone where studded tires are banned.
class StuddedTireZone {
  const StuddedTireZone({
    required this.name,
    required this.city,
    required this.polygon,
  });

  final String name;
  final String city;

  /// Closed polygon ring describing the ban zone boundary.
  final List<LatLng> polygon;
}

/// Known studded-tire ban zones in Scandinavia.
/// Polygons are narrow corridors (~30 m buffer) around the actual streets.
class StuddedTireZones {
  StuddedTireZones._();

  static const _zones = <StuddedTireZone>[
    // ── Stockholm ────────────────────────────────────────────────────────
    // Hornsgatan: Långholmsgatan → Ringvägen  (year-round ban since 2020)
    StuddedTireZone(
      name: 'Hornsgatan',
      city: 'Stockholm',
      polygon: [
        // North side (west → east)
        LatLng(59.31790, 18.04580),
        LatLng(59.31840, 18.05200),
        LatLng(59.31870, 18.05800),
        LatLng(59.31905, 18.06400),
        LatLng(59.31940, 18.07000),
        LatLng(59.31960, 18.07280),
        // South side (east → west)
        LatLng(59.31910, 18.07280),
        LatLng(59.31890, 18.07000),
        LatLng(59.31855, 18.06400),
        LatLng(59.31820, 18.05800),
        LatLng(59.31790, 18.05200),
        LatLng(59.31740, 18.04580),
      ],
    ),
  ];

  /// All known ban zones.
  static List<StuddedTireZone> get all => _zones;

  /// Zones formatted as Valhalla `exclude_polygons` payload.
  static List<List<Map<String, double>>> toValhallaExcludePolygons() {
    return _zones.map((zone) {
      return zone.polygon
          .map((p) => {'lat': p.latitude, 'lon': p.longitude})
          .toList();
    }).toList();
  }
}
