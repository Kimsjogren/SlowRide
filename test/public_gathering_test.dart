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
          'starts_at': '2020-07-15T12:00:00Z',
          'ends_at': '2099-07-15T16:00:00Z',
        },
      );

      expect(gathering.isPublic, isTrue);
      expect(gathering.isActive, isTrue);
      expect(gathering.meetupPosition?.latitude, 61.004);
      expect(gathering.meetupPosition?.longitude, 14.537);
      expect(gathering.meetupLabel, 'Torget i Mora');
      expect(gathering.startsAt, DateTime.parse('2020-07-15T12:00:00Z'));
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

    test('keeps an upcoming public gathering discoverable but inactive', () {
      final gathering = ConvoyModel.fromMap(
        id: 'gathering-3',
        map: {
          'name': 'Future meetup',
          'leaderId': 'leader-1',
          'visibility': 'public',
          'starts_at': '2099-01-01T12:00:00Z',
          'ends_at': '2099-01-01T18:00:00Z',
        },
      );

      expect(gathering.hasStarted, isFalse);
      expect(gathering.hasEnded, isFalse);
      expect(gathering.isActive, isFalse);
    });
  });
}
