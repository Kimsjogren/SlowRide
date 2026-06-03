import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class ChargingStation {
  const ChargingStation({required this.position, this.name});

  final LatLng position;
  final String? name;
}

/// Fetches EV charging stations from OpenStreetMap via Overpass API.
class ChargingStationService {
  ChargingStationService._();
  static final ChargingStationService instance = ChargingStationService._();

  List<ChargingStation> _cache = const [];
  LatLng? _lastCenter;
  DateTime _lastFetch = DateTime.fromMillisecondsSinceEpoch(0);

  /// Fetch charging stations within [radiusM] metres of [center].
  /// Results are cached for 60 s / 500 m to reduce API calls.
  Future<List<ChargingStation>> fetchNearby(
    LatLng center, {
    int radiusM = 5000,
    int maxResults = 40,
  }) async {
    // Return cache if still fresh and the user hasn't moved far.
    if (_cache.isNotEmpty && _lastCenter != null) {
      final age = DateTime.now().difference(_lastFetch);
      if (age.inSeconds < 60 && _distMeters(_lastCenter!, center) < 500) {
        return _cache;
      }
    }

    final query =
        '[out:json][timeout:8];'
        'node["amenity"="charging_station"]'
        '(around:$radiusM,${center.latitude},${center.longitude});'
        'out $maxResults;';

    final url = Uri.parse(
      'https://overpass-api.de/api/interpreter?data=${Uri.encodeComponent(query)}',
    );

    try {
      final resp = await http.get(url).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return _cache;

      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final elements = json['elements'] as List<dynamic>? ?? [];

      final stations = <ChargingStation>[];
      for (final e in elements) {
        final m = e as Map<String, dynamic>;
        final lat = (m['lat'] as num?)?.toDouble();
        final lon = (m['lon'] as num?)?.toDouble();
        if (lat == null || lon == null) continue;
        final tags = m['tags'] as Map<String, dynamic>?;
        stations.add(
          ChargingStation(
            position: LatLng(lat, lon),
            name: tags?['name'] as String?,
          ),
        );
      }

      _cache = stations;
      _lastCenter = center;
      _lastFetch = DateTime.now();
      return stations;
    } catch (_) {
      return _cache;
    }
  }

  static double _distMeters(LatLng a, LatLng b) {
    const lat2m = 111320.0;
    final lng2m = 111320.0 * math.cos(a.latitude * math.pi / 180.0);
    final dx = (b.latitude - a.latitude) * lat2m;
    final dy = (b.longitude - a.longitude) * lng2m;
    return math.sqrt(dx * dx + dy * dy);
  }
}
