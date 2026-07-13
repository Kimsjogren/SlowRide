import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:slowride/models/country_vehicle_rules.dart';
import 'package:slowride/services/routing_service.dart';

void main() {
  final service = RoutingService();
  const origin = LatLng(59.2596, 18.1127);
  const destination = LatLng(59.2768, 18.1316);

  group('RoutingService Valhalla slow vehicle profiles', () {
    test('low vehicle matches A-tractor rules in every supported country', () {
      for (final country in CountryVehicleRules.supportedCountries) {
        final lowVehicle = CountryVehicleRules.getProfile(
          country,
          'Low vehicle',
        );
        final aTractor = CountryVehicleRules.getProfile(country, 'A-tractor');

        expect(lowVehicle, same(aTractor), reason: country);
      }
    });

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

    test('low vehicle uses A-tractor speed and excludes unpaved roads', () {
      final payload = service.debugBuildValhallaRequestPayload(
        origin: origin,
        destination: destination,
        vehicleType: 'Low vehicle',
        userSpeedKmh: 90,
        countryCode: 'SE',
        avoidLocations: const [origin, LatLng(59.268, 18.12)],
      );

      expect(payload['costing'], 'motor_scooter');

      final costingOptions =
          (payload['costing_options'] as Map<String, dynamic>)['motor_scooter']
              as Map<String, dynamic>;
      expect(costingOptions['top_speed'], 30);
      expect(costingOptions['use_highways'], 0.0);
      expect(costingOptions['use_primary'], 0.0);
      expect(costingOptions['use_tracks'], 0.0);
      expect(costingOptions['exclude_unpaved'], isTrue);
      expect(payload['exclude_locations'], [
        {'lat': 59.268, 'lon': 18.12},
      ]);
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

  group('RoutingService fallback slow vehicle profiles', () {
    test('strict slow routing never falls back to OSRM', () {
      final providers = service.debugEligibleProviders(
        configuredProvider: 'osrm_public',
        vehicleType: 'A-tractor',
        countryCode: 'SE',
      );

      expect(providers.first, 'valhalla');
      expect(providers, isNot(contains('osrm_public')));
      expect(providers, isNot(contains('osrm_self_hosted')));
    });

    test('GraphHopper fallback keeps motorway, ferry and toll avoids', () {
      final uri = service.debugBuildGraphHopperUri(
        origin: origin,
        destination: destination,
        vehicleType: 'A-tractor',
        countryCode: 'SE',
      );

      expect(uri.queryParameters['profile'], 'car');
      expect(uri.queryParameters['avoid'], 'motorway,ferry,toll');
      expect(uri.queryParametersAll['point'], hasLength(2));
    });

    test('OpenRouteService fallback keeps highway, ferry and toll avoids', () {
      final payload = service.debugBuildOpenRouteServiceRequestPayload(
        origin: origin,
        destination: destination,
        vehicleType: 'A-tractor',
        countryCode: 'SE',
      );

      final options = payload['options'] as Map<String, dynamic>;
      expect(
        options['avoid_features'],
        containsAll(<String>['highways', 'ferries', 'tollways']),
      );
    });
  });
}
