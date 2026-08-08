import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:slowride/services/parent_service.dart';

void main() {
  group('ParentService parsing', () {
    test('skips malformed linked child rows instead of crashing', () {
      final parsed = ParentService.parseLinkedChildRow({
        'child_id': 'child-1',
        'linked_at': 'not-a-date',
        'profiles': {'email': 'child@example.com'},
      });

      expect(parsed, isNull);
    });

    test('parses linked child rows with optional share data safely', () {
      final parsed = ParentService.parseLinkedChildRow({
        'child_id': 'child-1',
        'linked_at': '2026-08-08T10:00:00Z',
        'profiles': {'email': 'child@example.com', 'display_name': 'Kim'},
        'parent_shares': {
          'last_location': {'lat': 59.33, 'lng': 18.06},
          'last_speed_kmh': 42,
          'is_driving': true,
          'last_update': '2026-08-08T10:05:00Z',
        },
      });

      expect(parsed, isNotNull);
      expect(parsed!.displayName, 'Kim');
      expect(parsed.location, const LatLng(59.33, 18.06));
      expect(parsed.speedKmh, 42);
      expect(parsed.isDriving, isTrue);
      expect(parsed.lastUpdate, DateTime.parse('2026-08-08T10:05:00Z'));
    });

    test('skips malformed parent alerts instead of crashing', () {
      final parsed = ParentService.parseParentAlertRow(
        {
          'id': 'alert-1',
          'child_id': 'child-1',
          'type': 'speeding',
          'created_at': 'bad-date',
        },
        childMap: const {'child-1': 'Kim'},
      );

      expect(parsed, isNull);
    });

    test('parses parent alerts with missing data map as empty payload', () {
      final parsed = ParentService.parseParentAlertRow(
        {
          'id': 'alert-1',
          'child_id': 'child-1',
          'type': 'speeding',
          'created_at': '2026-08-08T10:05:00Z',
        },
        childMap: const {'child-1': 'Kim'},
      );

      expect(parsed, isNotNull);
      expect(parsed!.childName, 'Kim');
      expect(parsed.data, isEmpty);
    });
  });
}
