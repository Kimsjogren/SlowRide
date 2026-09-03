import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Mapbox Search Box text search for addresses, streets and current POIs.
///
/// The legacy Geocoding v5 endpoint no longer supplies current POI data, so
/// business searches such as "Lidl" must use Search Box.
class MapboxSearchService {
  const MapboxSearchService._();

  static Future<List<Map<String, dynamic>>> search(
    String query, {
    required String accessToken,
    required String language,
    required List<String> countryCodes,
    LatLng? proximity,
    int limit = 10,
    http.Client? client,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty || accessToken.trim().isEmpty) return const [];

    final params = <String, String>{
      'q': trimmed,
      'access_token': accessToken.trim(),
      'language': language,
      'limit': '${math.min(math.max(limit, 1), 10)}',
      'country': countryCodes.map((code) => code.toUpperCase()).join(','),
      'types': 'address,street,place,city,locality,neighborhood,postcode,poi',
      'auto_complete': 'true',
      if (proximity != null)
        'proximity': '${proximity.longitude},${proximity.latitude}',
    };
    final uri = Uri.https(
      'api.mapbox.com',
      '/search/searchbox/v1/forward',
      params,
    );
    final response =
        await (client?.get(uri, headers: _headers) ??
            http.get(uri, headers: _headers));
    if (response.statusCode != 200) return const [];

    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['features'] is! List) return const [];
    return (decoded['features'] as List)
        .whereType<Map<String, dynamic>>()
        .map(featureToResult)
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  static const _headers = <String, String>{
    'User-Agent': 'CruizX/1.1 (mapbox-search-box)',
    'Accept': 'application/json',
  };

  static Map<String, dynamic>? featureToResult(Map<String, dynamic> feature) {
    final properties = feature['properties'];
    if (properties is! Map) return null;

    final coordinates = properties['coordinates'];
    final geometry = feature['geometry'];
    final geometryCoordinates = geometry is Map
        ? geometry['coordinates']
        : null;
    final lon =
        _number(coordinates is Map ? coordinates['longitude'] : null) ??
        _coordinateAt(geometryCoordinates, 0);
    final lat =
        _number(coordinates is Map ? coordinates['latitude'] : null) ??
        _coordinateAt(geometryCoordinates, 1);
    if (lat == null || lon == null) return null;

    final context = properties['context'] is Map
        ? properties['context'] as Map
        : const {};
    final addressContext = context['address'] is Map
        ? context['address'] as Map
        : const {};
    final streetContext = context['street'] is Map
        ? context['street'] as Map
        : const {};

    final preferredName = _text(properties['name_preferred']);
    final title = preferredName.isNotEmpty
        ? preferredName
        : _text(properties['name']);
    final featureType = _text(properties['feature_type']);
    final street = _firstText([
      streetContext['name'],
      addressContext['street_name'],
    ]);
    final houseNumber = _text(addressContext['address_number']);
    final formattedAddress = _text(properties['address']);
    final road = street.isNotEmpty ? street : formattedAddress;
    final city = _contextName(context, const ['place', 'locality']);
    final suburb = _contextName(context, const ['neighborhood', 'district']);
    final municipality = _contextName(context, const ['region']);
    final country = _contextName(context, const ['country']);
    final countryContext = context['country'];
    final countryCode = countryContext is Map
        ? _text(countryContext['country_code']).toUpperCase()
        : '';
    final fullAddress = _text(properties['full_address']);
    final placeFormatted = _text(properties['place_formatted']);

    final address = <String, String>{
      if (road.isNotEmpty) 'road': road,
      if (street.isNotEmpty && houseNumber.isNotEmpty)
        'house_number': houseNumber,
      if (suburb.isNotEmpty) 'suburb': suburb,
      if (city.isNotEmpty) 'city': city,
      if (municipality.isNotEmpty) 'municipality': municipality,
      if (country.isNotEmpty) 'country': country,
      if (countryCode.isNotEmpty) 'country_code': countryCode,
    };
    final detail = fullAddress.isNotEmpty ? fullAddress : placeFormatted;
    final displayName = [
      title,
      if (detail.isNotEmpty) detail,
    ].where((part) => part.isNotEmpty).join(', ');

    return {
      'lat': lat.toString(),
      'lon': lon.toString(),
      'place_id': _text(properties['mapbox_id']).isNotEmpty
          ? _text(properties['mapbox_id'])
          : '$lat,$lon',
      'importance': 1.0,
      'name': title,
      'display_name': displayName,
      'address': address,
      '_mapbox_place_type': featureType,
      '_source': 'mapbox_search_box',
    };
  }

  static double? _number(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static double? _coordinateAt(Object? coordinates, int index) {
    if (coordinates is! List || coordinates.length <= index) return null;
    return _number(coordinates[index]);
  }

  static String _text(Object? value) => value?.toString().trim() ?? '';

  static String _firstText(List<Object?> values) {
    for (final value in values) {
      final text = _text(value);
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  static String _contextName(Map context, List<String> keys) {
    for (final key in keys) {
      final value = context[key];
      if (value is! Map) continue;
      final name = _text(value['name']);
      if (name.isNotEmpty) return name;
    }
    return '';
  }
}
