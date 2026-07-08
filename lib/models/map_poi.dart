import 'package:latlong2/latlong.dart';

enum MapPoiCategory {
  food,
  cafe,
  fuel,
  shopping,
  parking,
  charging,
  health,
  lodging,
  attraction,
  services,
}

class MapPoi {
  const MapPoi({
    required this.id,
    required this.position,
    required this.category,
    this.name,
  });

  final String id;
  final LatLng position;
  final MapPoiCategory category;
  final String? name;
}
