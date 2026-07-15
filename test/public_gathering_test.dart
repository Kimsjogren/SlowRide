import 'package:flutter_test/flutter_test.dart';
import 'package:slowride/models/convoy_model.dart';

void main() {
  group('public gatherings', () {
    test('parses public meetup metadata from Supabase rows', () {
      final gathering = ConvoyModel.fromMap(
        id: 'gathering-1',
        map: {
          'name': 'CruizX Mora',
          'leaderId': 'leader-1',
          'memberCount': 3,
          'createdAt': '2026-07-15T10:00:00Z',
          'visibility': 'public',
          'meetup_lat': 61.004,
          'meetup_lng': 14.537,
          'meetup_label': 'Torget i Mora',
          'ends_at': '2099-07-15T16:00:00Z',
        },
      );

      expect(gathering.isPublic, isTrue);
      expect(gathering.isActive, isTrue);
      expect(gathering.meetupPosition?.latitude, 61.004);
      expect(gathering.meetupPosition?.longitude, 14.537);
      expect(gathering.meetupLabel, 'Torget i Mora');
    });

    test('marks an expired public gathering as inactive', () {
      final gathering = ConvoyModel.fromMap(
        id: 'gathering-2',
        map: {
          'name': 'Old meetup',
          'leaderId': 'leader-1',
          'visibility': 'public',
          'ends_at': '2020-01-01T00:00:00Z',
        },
      );

      expect(gathering.isActive, isFalse);
    });
  });
}
