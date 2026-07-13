import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:slowride/models/alert_model.dart';
import 'package:slowride/services/osm_speed_bump_service.dart';

void main() {
  test('parses and deduplicates OSM speed bumps', () {
    const response = '''
      {
        "fetched_at": "2026-07-14T08:00:00Z",
        "bumps": [
          {"id":"osm_node_1","lat":59.3,"lng":18.1,"kind":"bump"},
          {"id":"osm_node_1","lat":59.3,"lng":18.1,"kind":"bump"},
          {"id":"osm_way_2","lat":59.4,"lng":18.2,"kind":"table"},
          {"id":"bad","lat":999,"lng":18.2,"kind":"hump"}
        ]
      }
    ''';

    final bumps = OsmSpeedBumpService.parseResponse(response);

    expect(bumps, hasLength(2));
    expect(bumps.every((bump) => bump.type == AlertType.speedBump), isTrue);
    expect(bumps.first.id, 'osm_node_1');
    expect(bumps.last.description, 'OpenStreetMap · table');
    expect(bumps.first.createdAt, DateTime.utc(2026, 7, 14, 8));
  });

  test('returns empty list when bumps are missing', () {
    expect(OsmSpeedBumpService.parseResponse('{"count":0}'), isEmpty);
  });

  test('prioritizes bumps closest to the route corridor', () {
    final now = DateTime.utc(2026, 7, 14);
    final alerts = [
      AlertModel(
        id: 'off-route',
        type: AlertType.speedBump,
        position: const LatLng(59.5, 18.5),
        description: '',
        upvotes: 0,
        createdAt: now,
      ),
      AlertModel(
        id: 'on-route',
        type: AlertType.speedBump,
        position: const LatLng(59.35, 18.15),
        description: '',
        upvotes: 0,
        createdAt: now,
      ),
    ];

    final selected = OsmSpeedBumpService.selectForRoute(
      alerts: alerts,
      origin: const LatLng(59.3, 18.1),
      destination: const LatLng(59.4, 18.2),
      maxLocations: 1,
    );

    expect(selected, [const LatLng(59.35, 18.15)]);
  });
}
