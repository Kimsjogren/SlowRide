import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:slowride/models/country_vehicle_rules.dart';
import 'package:slowride/services/routing_service.dart';

void main() {
  final service = RoutingService();
  const origin = LatLng(59.2596, 18.1127);
  const destination = LatLng(59.2768, 18.1316);

  group('RoutingService Valhalla slow vehicle profiles', () {
    test('Italy is detected and uses Italian slow-vehicle limits', () {
      expect(
        CountryVehicleRules.countryFromCoordinates(41.9028, 12.4964),
        'IT',
      );
      expect(CountryVehicleRules.countryFromCoordinates(45.4642, 9.1900), 'IT');
      expect(
        CountryVehicleRules.countryFromCoordinates(38.1157, 13.3615),
        'IT',
      );
      expect(CountryVehicleRules.countryFromCoordinates(40.1209, 9.0129), 'IT');

      final aTractor = CountryVehicleRules.getProfile('IT', 'A-tractor');
      final mopedCar = CountryVehicleRules.getProfile('IT', 'Moped car');
      final tractor = CountryVehicleRules.getProfile('IT', 'Tractor');

      expect(aTractor.maxLegalSpeedKmh, 30);
      expect(mopedCar.maxLegalSpeedKmh, 45);
      expect(tractor.defaultSpeedKmh, 30);
      expect(tractor.maxLegalSpeedKmh, 40);
      expect(aTractor.useHighways, 0);
      expect(mopedCar.useHighways, 0);
      expect(tractor.useHighways, 0);
    });

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

    test('class I moped uses 45 km/h moped rules in every country', () {
      for (final country in CountryVehicleRules.supportedCountries) {
        final moped = CountryVehicleRules.getProfile(country, 'Moped class I');
        final mopedCar = CountryVehicleRules.getProfile(country, 'Moped car');

        expect(moped, isNot(same(mopedCar)), reason: country);
        expect(moped.maxLegalSpeedKmh, 45, reason: country);
        expect(moped.useHighways, 0, reason: country);
        expect(moped.usePrimary, 0, reason: country);
        expect(moped.useTracks, 0, reason: country);
        expect(moped.excludeUnpaved, isTrue, reason: country);
        expect(moped.allowsCyclewaysByDefault, isFalse, reason: country);
        expect(moped.legalCategory, isNotEmpty, reason: country);
      }

      expect(
        CountryVehicleRules.getProfile(
          'ES',
          'Moped class I',
        ).requiresRoadShoulderWhereAvailable,
        isTrue,
      );
      expect(
        CountryVehicleRules.getProfile(
          'NO',
          'Moped class I',
        ).allowsTwoWheelBusLanes,
        isTrue,
      );
      expect(
        CountryVehicleRules.getProfile('GB', 'Moped class I').forbidsMotorRoads,
        isFalse,
      );
    });

    test('class I moped motorway words follow each country', () {
      expect(
        service.debugForbiddenRoadKeywords(
          countryCode: 'IT',
          vehicleType: 'Moped class I',
        ),
        containsAll(['autostrada', 'strada extraurbana principale']),
      );
      expect(
        service.debugForbiddenRoadKeywords(
          countryCode: 'FI',
          vehicleType: 'Moped class I',
        ),
        contains('moottoriliikennetie'),
      );
      expect(
        service.debugForbiddenRoadKeywords(
          countryCode: 'GB',
          vehicleType: 'Moped class I',
        ),
        isNot(contains('expressway')),
      );
    });

    test('class II moped has explicit 25 km/h rules in every country', () {
      for (final country in CountryVehicleRules.supportedCountries) {
        final moped = CountryVehicleRules.getProfile(country, 'Moped class II');

        expect(moped.defaultSpeedKmh, 25, reason: country);
        expect(moped.maxLegalSpeedKmh, 25, reason: country);
        expect(moped.useHighways, 0, reason: country);
        expect(moped.useTracks, 0, reason: country);
        expect(moped.excludeUnpaved, isTrue, reason: country);
        expect(moped.legalCategory, isNotEmpty, reason: country);
      }

      expect(
        CountryVehicleRules.getProfile('SE', 'Moped class II').prefersCycleways,
        isTrue,
      );
      expect(
        CountryVehicleRules.getProfile('DK', 'Moped class II').prefersCycleways,
        isTrue,
      );
      expect(
        CountryVehicleRules.getProfile('NO', 'Moped class II').prefersCycleways,
        isFalse,
      );
      expect(
        CountryVehicleRules.getProfile(
          'ES',
          'Moped class II',
        ).requiresRoadShoulderWhereAvailable,
        isTrue,
      );
      expect(
        CountryVehicleRules.getProfile(
          'GB',
          'Moped class II',
        ).forbidsMotorRoads,
        isFalse,
      );
    });

    test('electric scooter uses explicit rules in every country', () {
      const expectedSpeeds = <String, double>{
        'SE': 20,
        'NO': 20,
        'DK': 20,
        'FI': 25,
        'FR': 25,
        'ES': 25,
        'IT': 20,
        'GB': 25,
      };

      for (final country in CountryVehicleRules.supportedCountries) {
        final scooter = CountryVehicleRules.getProfile(
          country,
          'Electric scooter',
        );
        expect(
          scooter.maxLegalSpeedKmh,
          expectedSpeeds[country],
          reason: country,
        );
        expect(scooter.prefersCycleways, isTrue, reason: country);
        expect(scooter.useHighways, 0, reason: country);
        expect(scooter.useTracks, 0, reason: country);
        expect(scooter.excludeUnpaved, isTrue, reason: country);
        expect(scooter.legalCategory, isNotEmpty, reason: country);
      }

      expect(
        CountryVehicleRules.getProfile('ES', 'Electric scooter').urbanRoadsOnly,
        isTrue,
      );
      expect(
        CountryVehicleRules.getProfile(
          'GB',
          'Electric scooter',
        ).requiresApprovedRental,
        isTrue,
      );
      expect(
        CountryVehicleRules.getProfile(
          'NO',
          'Electric scooter',
        ).allowsFootwaysAtWalkingSpeed,
        isTrue,
      );
      expect(
        CountryVehicleRules.getProfile(
          'IT',
          'Electric scooter',
        ).maxRoadSpeedLimitKmh,
        50,
      );
      for (final country in CountryVehicleRules.supportedCountries) {
        expect(
          CountryVehicleRules.maxSelectableSpeedFor(
            country,
            'Electric scooter',
          ),
          40,
          reason: country,
        );
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

    test('class I moped uses motor_scooter at no more than 45 km/h', () {
      final payload = service.debugBuildValhallaRequestPayload(
        origin: origin,
        destination: destination,
        vehicleType: 'Moped class I',
        userSpeedKmh: 90,
        countryCode: 'SE',
      );

      expect(payload['costing'], 'motor_scooter');

      final costingOptions =
          (payload['costing_options'] as Map<String, dynamic>)['motor_scooter']
              as Map<String, dynamic>;
      expect(costingOptions['top_speed'], 45);
      expect(costingOptions['use_highways'], 0.0);
      expect(costingOptions['use_primary'], 0.0);
      expect(costingOptions['use_tracks'], 0.0);
      expect(costingOptions['exclude_unpaved'], isTrue);
      expect(costingOptions['ignore_access'], isFalse);
      expect(costingOptions['use_tolls'], 0.5);
      expect(costingOptions['disable_hierarchy_pruning'], isTrue);
    });

    test('Swedish class II moped prefers cycleways at 25 km/h', () {
      final payload = service.debugBuildValhallaRequestPayload(
        origin: origin,
        destination: destination,
        vehicleType: 'Moped class II',
        userSpeedKmh: 90,
        countryCode: 'SE',
      );

      expect(payload['costing'], 'bicycle');
      final costingOptions =
          (payload['costing_options'] as Map<String, dynamic>)['bicycle']
              as Map<String, dynamic>;
      expect(costingOptions['cycling_speed'], 25);
      expect(costingOptions['use_roads'], 0.0);
      expect(costingOptions['avoid_bad_surfaces'], 1.0);
      expect(costingOptions['ignore_access'], isFalse);
    });

    test('Norwegian class II moped stays on motor-scooter road profile', () {
      final payload = service.debugBuildValhallaRequestPayload(
        origin: origin,
        destination: destination,
        vehicleType: 'Moped class II',
        userSpeedKmh: 90,
        countryCode: 'NO',
      );

      expect(payload['costing'], 'motor_scooter');
      final costingOptions =
          (payload['costing_options'] as Map<String, dynamic>)['motor_scooter']
              as Map<String, dynamic>;
      expect(costingOptions['top_speed'], 25);
      expect(costingOptions['use_primary'], 0.0);
      expect(costingOptions['use_tracks'], 0.0);
      expect(costingOptions['exclude_unpaved'], isTrue);
    });

    test('electric scooter uses country speed and cycleway preferences', () {
      final swedishPayload = service.debugBuildValhallaRequestPayload(
        origin: origin,
        destination: destination,
        vehicleType: 'Electric scooter',
        userSpeedKmh: 90,
        countryCode: 'SE',
      );
      final spanishPayload = service.debugBuildValhallaRequestPayload(
        origin: origin,
        destination: destination,
        vehicleType: 'Electric scooter',
        userSpeedKmh: 90,
        countryCode: 'ES',
      );

      expect(swedishPayload['costing'], 'bicycle');
      final swedishOptions =
          (swedishPayload['costing_options'] as Map<String, dynamic>)['bicycle']
              as Map<String, dynamic>;
      expect(swedishOptions['cycling_speed'], 20);
      expect(swedishOptions['use_roads'], 0.1);
      expect(swedishOptions['avoid_bad_surfaces'], 1.0);

      final spanishOptions =
          (spanishPayload['costing_options'] as Map<String, dynamic>)['bicycle']
              as Map<String, dynamic>;
      expect(spanishOptions['cycling_speed'], 25);
      expect(spanishOptions['use_roads'], 0.8);
      expect(spanishOptions['use_ferry'], 0.0);
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

    test('ordinary car has no vehicle top-speed restriction', () {
      expect(CountryVehicleRules.hasVehicleSpeedLimit('Car'), isFalse);

      final payload = service.debugBuildValhallaRequestPayload(
        origin: origin,
        destination: destination,
        vehicleType: 'Car',
        userSpeedKmh: 30,
        countryCode: 'SE',
      );

      expect(payload['costing'], 'auto');
      final costingOptions =
          (payload['costing_options'] as Map<String, dynamic>)['auto']
              as Map<String, dynamic>;
      expect(costingOptions, isNot(contains('top_speed')));
      expect(costingOptions['use_highways'], 1.0);
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

    test('class II moped only uses Valhalla legal routing', () {
      final providers = service.debugEligibleProviders(
        configuredProvider: 'graphhopper',
        vehicleType: 'Moped class II',
        countryCode: 'SE',
      );

      expect(providers, ['valhalla']);
    });

    test('electric scooter only uses Valhalla legal routing', () {
      final providers = service.debugEligibleProviders(
        configuredProvider: 'graphhopper',
        vehicleType: 'Electric scooter',
        countryCode: 'SE',
      );

      expect(providers, ['valhalla']);
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

  group('RoutingService route speed limits', () {
    test('maps Valhalla edge limits onto every covered route point', () {
      final limits = service.debugParseRouteSpeedLimits([
        {
          'speed_limit': 50,
          'begin_shape_index': 0,
          'end_shape_index': 2,
        },
        {
          'speed_limit': 70,
          'begin_shape_index': 3,
          'end_shape_index': 4,
        },
      ], 5);

      expect(limits, [50, 50, 50, 70, 70]);
    });

    test('ignores absent and sentinel speed limits', () {
      final limits = service.debugParseRouteSpeedLimits([
        {
          'speed_limit': 0,
          'begin_shape_index': 0,
          'end_shape_index': 1,
        },
        {
          'speed_limit': 255,
          'begin_shape_index': 2,
          'end_shape_index': 3,
        },
      ], 4);

      expect(limits, [null, null, null, null]);
    });
  });
}
