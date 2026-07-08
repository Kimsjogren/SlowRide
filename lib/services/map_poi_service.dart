import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:slowride/models/map_poi.dart';

class MapPoiService {
  MapPoiService._();

  static final MapPoiService instance = MapPoiService._();

  List<MapPoi> _cache = const [];
  LatLng? _lastCenter;
  int _lastRadiusMeters = 0;
  DateTime _lastFetch = DateTime.fromMillisecondsSinceEpoch(0);

  Future<List<MapPoi>> fetchNearby(
    LatLng center, {
    required int radiusMeters,
    int maxResults = 220,
  }) async {
    final lastCenter = _lastCenter;
    if (_cache.isNotEmpty && lastCenter != null) {
      final age = DateTime.now().difference(_lastFetch);
      final cacheDistance = math.min(radiusMeters, _lastRadiusMeters) * 0.3;
      if (age.inMinutes < 2 &&
          _distanceMeters(lastCenter, center) < cacheDistance) {
        return _cache;
      }
    }

    final query =
        '[out:json][timeout:12];'
        '('
        'nwr["amenity"~"^(restaurant|fast_food|food_court|cafe|bar|pub|fuel|parking|pharmacy|hospital|clinic|doctors|dentist|bank|atm|charging_station)\$"]'
        '(around:$radiusMeters,${center.latitude},${center.longitude});'
        'nwr["shop"]'
        '(around:$radiusMeters,${center.latitude},${center.longitude});'
        'nwr["tourism"~"^(hotel|hostel|motel|museum|attraction|information)\$"]'
        '(around:$radiusMeters,${center.latitude},${center.longitude});'
        'nwr["leisure"~"^(fitness_centre|sports_centre|park|playground)\$"]'
        '(around:$radiusMeters,${center.latitude},${center.longitude});'
        ');'
        'out center ${maxResults * 2};';

    try {
      final response = await http
          .post(
            Uri.https('overpass-api.de', '/api/interpreter'),
            body: {'data': query},
            headers: const {'User-Agent': 'CruizX/1.0 (map POI display)'},
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return _cache;

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final elements = decoded['elements'] as List<dynamic>? ?? const [];
      final categoryCounts = <MapPoiCategory, int>{};
      final pois = <MapPoi>[];

      for (final value in elements) {
        final element = value as Map<String, dynamic>;
        final centerData = element['center'] as Map<String, dynamic>?;
        final latitude =
            (element['lat'] as num?)?.toDouble() ??
            (centerData?['lat'] as num?)?.toDouble();
        final longitude =
            (element['lon'] as num?)?.toDouble() ??
            (centerData?['lon'] as num?)?.toDouble();
        if (latitude == null || longitude == null) continue;

        final tags = (element['tags'] as Map<String, dynamic>?) ?? const {};
        final category = _categoryFor(tags);
        if (category == null) continue;

        final count = categoryCounts[category] ?? 0;
        if (count >= _categoryLimit(category)) continue;
        categoryCounts[category] = count + 1;

        final rawName = (tags['name'] ?? tags['brand'] ?? tags['operator'])
            ?.toString()
            .trim();
        pois.add(
          MapPoi(
            id: '${element['type']}-${element['id']}',
            position: LatLng(latitude, longitude),
            category: category,
            name: rawName == null || rawName.isEmpty ? null : rawName,
          ),
        );
        if (pois.length >= maxResults) break;
      }

      pois.sort(
        (a, b) => _distanceMeters(
          center,
          a.position,
        ).compareTo(_distanceMeters(center, b.position)),
      );
      _cache = List.unmodifiable(pois);
      _lastCenter = center;
      _lastRadiusMeters = radiusMeters;
      _lastFetch = DateTime.now();
      return _cache;
    } catch (_) {
      return _cache;
    }
  }

  MapPoiCategory? _categoryFor(Map<String, dynamic> tags) {
    final amenity = tags['amenity']?.toString();
    if (const {'restaurant', 'fast_food', 'food_court'}.contains(amenity)) {
      return MapPoiCategory.food;
    }
    if (const {'cafe', 'bar', 'pub'}.contains(amenity)) {
      return MapPoiCategory.cafe;
    }
    if (amenity == 'fuel') return MapPoiCategory.fuel;
    if (amenity == 'parking') return MapPoiCategory.parking;
    if (amenity == 'charging_station') return MapPoiCategory.charging;
    if (const {
      'pharmacy',
      'hospital',
      'clinic',
      'doctors',
      'dentist',
    }.contains(amenity)) {
      return MapPoiCategory.health;
    }
    if (const {'bank', 'atm'}.contains(amenity)) {
      return MapPoiCategory.services;
    }
    if (tags.containsKey('shop')) return MapPoiCategory.shopping;

    final tourism = tags['tourism']?.toString();
    if (const {'hotel', 'hostel', 'motel'}.contains(tourism)) {
      return MapPoiCategory.lodging;
    }
    if (tourism != null) return MapPoiCategory.attraction;
    if (tags.containsKey('leisure')) return MapPoiCategory.attraction;
    return null;
  }

  int _categoryLimit(MapPoiCategory category) => switch (category) {
    MapPoiCategory.shopping => 65,
    MapPoiCategory.food => 45,
    MapPoiCategory.cafe => 35,
    MapPoiCategory.parking => 25,
    MapPoiCategory.attraction => 20,
    _ => 18,
  };

  double _distanceMeters(LatLng a, LatLng b) {
    const latitudeMeters = 111320.0;
    final longitudeMeters =
        latitudeMeters * math.cos(a.latitude * math.pi / 180.0);
    final latitudeDelta = (b.latitude - a.latitude) * latitudeMeters;
    final longitudeDelta = (b.longitude - a.longitude) * longitudeMeters;
    return math.sqrt(
      latitudeDelta * latitudeDelta + longitudeDelta * longitudeDelta,
    );
  }
}
