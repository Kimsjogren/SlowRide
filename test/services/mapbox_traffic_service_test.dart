import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slowride/services/mapbox_traffic_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('samples a long route to the Mapbox 25-coordinate limit', () {
    final route = List.generate(
      101,
      (index) => LatLng(59 + index / 1000, 18 + index / 1000),
    );

    final sampled = MapboxTrafficService.sampleRoutePoints(route);

    expect(sampled, hasLength(25));
    expect(sampled.first, route.first);
    expect(sampled.last, route.last);
  });

  test('returns only the live-versus-typical traffic delay', () async {
    Uri? requestedUri;
    final service = MapboxTrafficService(
      client: MockClient((request) async {
        requestedUri = request.url;
        return http.Response(
          jsonEncode({
            'routes': [
              {
                'duration': 900,
                'duration_typical': 600,
                'distance': 5000,
              },
            ],
          }),
          200,
        );
      }),
    );

    final estimate = await service.estimate(
      routeId: 'route-a',
      remainingRoutePoints: const [LatLng(59.3, 18.0), LatLng(59.4, 18.1)],
    );

    expect(estimate, isNotNull);
    expect(estimate!.delaySeconds, 300);
    expect(requestedUri!.path, contains('/mapbox/driving-traffic/'));
    expect(requestedUri!.queryParameters['overview'], 'full');
    expect(requestedUri!.queryParameters['annotations'], 'congestion');
  });

  test('reuses the five-minute cache without a second request', () async {
    var requests = 0;
    final service = MapboxTrafficService(
      client: MockClient((request) async {
        requests++;
        return http.Response(
          jsonEncode({
            'routes': [
              {
                'duration': 700,
                'duration_typical': 650,
                'distance': 4200,
              },
            ],
          }),
          200,
        );
      }),
    );
    const route = [LatLng(59.3, 18.0), LatLng(59.4, 18.1)];

    await service.estimate(routeId: 'route-a', remainingRoutePoints: route);
    await service.estimate(routeId: 'route-a', remainingRoutePoints: route);

    expect(requests, 1);
  });

  test('never reuses another route estimate when a request fails', () async {
    final service = MapboxTrafficService(
      client: MockClient((request) async {
        if (request.url.path.contains('18.000000,59.300000')) {
          return http.Response(
            jsonEncode({
              'routes': [
                {
                  'duration': 700,
                  'duration_typical': 650,
                  'distance': 4200,
                },
              ],
            }),
            200,
          );
        }
        return http.Response('unavailable', 503);
      }),
    );

    final first = await service.estimate(
      routeId: 'route-a',
      remainingRoutePoints: const [LatLng(59.3, 18.0), LatLng(59.4, 18.1)],
    );
    final failed = await service.estimate(
      routeId: 'route-b',
      remainingRoutePoints: const [LatLng(60.3, 19.0), LatLng(60.4, 19.1)],
    );

    expect(first, isNotNull);
    expect(failed, isNull);
  });

  test('groups orange, red and severe congestion route sections', () async {
    final service = MapboxTrafficService(
      client: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'routes': [
              {
                'duration': 900,
                'duration_typical': 600,
                'distance': 5000,
                'geometry': {
                  'coordinates': [
                    [18.00, 59.30],
                    [18.01, 59.31],
                    [18.02, 59.32],
                    [18.03, 59.33],
                    [18.04, 59.34],
                  ],
                },
                'legs': [
                  {
                    'annotation': {
                      'congestion': ['low', 'moderate', 'heavy', 'severe'],
                    },
                  },
                ],
              },
            ],
          }),
          200,
        );
      }),
    );

    final estimate = await service.estimate(
      routeId: 'route-colors',
      remainingRoutePoints: const [LatLng(59.3, 18.0), LatLng(59.34, 18.04)],
    );

    expect(estimate!.trafficSections, hasLength(3));
    expect(
      estimate.trafficSections.map((section) => section.level),
      [
        TrafficCongestionLevel.moderate,
        TrafficCongestionLevel.heavy,
        TrafficCongestionLevel.severe,
      ],
    );
  });
}
