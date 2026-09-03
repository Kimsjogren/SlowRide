import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

class AppleMapSearchService {
  const AppleMapSearchService._();

  static const MethodChannel _channel = MethodChannel('cruizx/mapkit_search');

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static Future<List<Map<String, dynamic>>> search(
    String query, {
    LatLng? proximity,
    int limit = 10,
    double? radiusMeters,
  }) async {
    if (!isSupported || query.trim().isEmpty) return const [];

    try {
      final results = await _channel.invokeListMethod<dynamic>('search', {
        'query': query.trim(),
        'limit': limit,
        'latitude': proximity?.latitude,
        'longitude': proximity?.longitude,
        'radiusMeters': radiusMeters,
      });
      if (results == null) return const [];
      return results
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }
}
