import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:slowride/services/mapbox_search_service.dart';

void main() {
  test('Search Box request includes POIs and GPS proximity', () async {
    late Uri requestedUri;
    final client = MockClient((request) async {
      requestedUri = request.url;
      return http.Response(
        jsonEncode({
          'type': 'FeatureCollection',
          'features': [
            {
              'type': 'Feature',
              'geometry': {
                'type': 'Point',
                'coordinates': [1.05815013, 41.07271126],
              },
              'properties': {
                'name': 'Lidl',
                'mapbox_id': 'poi.lidl-vinyols',
                'feature_type': 'poi',
                'address': 'Carrere de la',
                'full_address':
                    'Carrere de la, 43391 Vinyols i els Arcs, Spanien',
                'coordinates': {
                  'longitude': 1.05815013,
                  'latitude': 41.07271126,
                },
                'context': {
                  'place': {'name': 'Vinyols i els Arcs'},
                  'region': {'name': 'Katalonien'},
                  'country': {'name': 'Spanien', 'country_code': 'ES'},
                },
              },
            },
          ],
        }),
        200,
      );
    });

    final results = await MapboxSearchService.search(
      'Lidl',
      accessToken: 'pk.test',
      language: 'sv',
      countryCodes: const ['SE', 'ES', 'IT'],
      proximity: const LatLng(41.05, 0.92),
      limit: 15,
      client: client,
    );

    expect(requestedUri.path, '/search/searchbox/v1/forward');
    expect(requestedUri.queryParameters['q'], 'Lidl');
    expect(requestedUri.queryParameters['proximity'], '0.92,41.05');
    expect(requestedUri.queryParameters['country'], 'SE,ES,IT');
    expect(requestedUri.queryParameters['types'], contains('poi'));
    expect(requestedUri.queryParameters['auto_complete'], 'true');
    expect(requestedUri.queryParameters['limit'], '10');
    expect(results.single['name'], 'Lidl');
    expect(results.single['_mapbox_place_type'], 'poi');
    expect(results.single['address']['city'], 'Vinyols i els Arcs');
    expect(results.single['address']['country_code'], 'ES');
  });

  test('invalid Search Box features are discarded', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'features': [
            {
              'properties': {'name': 'Missing coordinates'},
            },
          ],
        }),
        200,
      ),
    );

    final results = await MapboxSearchService.search(
      'test',
      accessToken: 'pk.test',
      language: 'en',
      countryCodes: const ['ES'],
      client: client,
    );

    expect(results, isEmpty);
  });
}
