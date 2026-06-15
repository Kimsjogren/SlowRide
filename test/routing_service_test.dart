import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:slowride/services/routing_service.dart';

void main() {
  group('RoutingService Valhalla slow vehicle profiles', () {
    final service = RoutingService();
    const origin = LatLng(59.2596, 18.1127);
    const destination = LatLng(59.2768, 18.1316);

    test('A-tractor uses motor_scooter profile and avoids fast roads', () {
      final payload = service.debugBuildValhallaRequestPayload(
        origin: origin,
        destination: destination,
        vehicleType: 'A-tractor',
        userSpeedKmh: 30,
        countryCode: 'SE',
      );

      expect(payload['costing'], 'motor_scooter');

      final costingOptions =
          (payload['costing_options'] as Map<String, dynamic>)['motor_scooter']
              as Map<String, dynamic>;
      expect(costingOptions['top_speed'], 30);
      expect(costingOptions['use_highways'], 0.0);
      expect(costingOptions['use_primary'], 0.0);
      expect(costingOptions['use_tolls'], 0.0);
      expect(costingOptions['use_ferry'], 0.0);
      expect(costingOptions['disable_hierarchy_pruning'], isTrue);
    });

    test('moped car uses same slow-vehicle highway avoidance', () {
      final payload = service.debugBuildValhallaRequestPayload(
        origin: origin,
        destination: destination,
        vehicleType: 'Moped car',
        userSpeedKmh: 45,
        countryCode: 'SE',
      );

      expect(payload['costing'], 'motor_scooter');

      final costingOptions =
          (payload['costing_options'] as Map<String, dynamic>)['motor_scooter']
              as Map<String, dynamic>;
      expect(costingOptions['top_speed'], 45);
      expect(costingOptions['use_highways'], 0.0);
      expect(costingOptions['use_primary'], 0.0);
    });

    test('unknown vehicle types fail safe as slow vehicles', () {
      final payload = service.debugBuildValhallaRequestPayload(
        origin: origin,
        destination: destination,
        vehicleType: 'Unknown vehicle',
        userSpeedKmh: 90,
        countryCode: 'SE',
      );

      expect(payload['costing'], 'motor_scooter');

      final costingOptions =
          (payload['costing_options'] as Map<String, dynamic>)['motor_scooter']
              as Map<String, dynamic>;
      expect(costingOptions['top_speed'], 30);
      expect(costingOptions['use_highways'], 0.0);
      expect(costingOptions['use_primary'], 0.0);
    });
  });
}
