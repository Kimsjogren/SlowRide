import 'package:latlong2/latlong.dart';

class ConvoyModel {
  const ConvoyModel({
    required this.id,
    required this.name,
    required this.leaderId,
    required this.memberCount,
    required this.createdAt,
    this.isJoined = false,
    this.isPublic = false,
    this.meetupLat,
    this.meetupLng,
    this.meetupLabel = '',
    this.startsAt,
    this.endsAt,
  });

  final String id;
  final String name;
  final String leaderId;
  final int memberCount;
  final DateTime createdAt;
  final bool isJoined;
  final bool isPublic;
  final double? meetupLat;
  final double? meetupLng;
  final String meetupLabel;
  final DateTime? startsAt;
  final DateTime? endsAt;

  LatLng? get meetupPosition {
    final lat = meetupLat;
    final lng = meetupLng;
    return lat == null || lng == null ? null : LatLng(lat, lng);
  }

  bool get hasStarted => startsAt == null || !startsAt!.isAfter(DateTime.now());
  bool get hasEnded => endsAt != null && !endsAt!.isAfter(DateTime.now());
  bool get isActive => hasStarted && !hasEnded;

  factory ConvoyModel.fromMap({
    required String id,
    required Map<String, dynamic> map,
  }) {
    final rawCreatedAt = map['createdAt'];
    DateTime createdAt;

    if (rawCreatedAt is DateTime) {
      createdAt = rawCreatedAt;
    } else {
      createdAt =
          DateTime.tryParse(rawCreatedAt?.toString() ?? '') ?? DateTime.now();
    }

    return ConvoyModel(
      id: id,
      name: map['name']?.toString() ?? 'Convoy',
      leaderId: map['leaderId']?.toString() ?? 'unknown',
      memberCount: (map['memberCount'] as num?)?.toInt() ?? 1,
      createdAt: createdAt,
      isJoined: map['isJoined'] == true,
      isPublic:
          map['isPublic'] == true || map['visibility']?.toString() == 'public',
      meetupLat: ((map['meetupLat'] ?? map['meetup_lat']) as num?)?.toDouble(),
      meetupLng: ((map['meetupLng'] ?? map['meetup_lng']) as num?)?.toDouble(),
      meetupLabel:
          (map['meetupLabel'] ?? map['meetup_label'])?.toString() ?? '',
      startsAt: DateTime.tryParse(
        (map['startsAt'] ?? map['starts_at'])?.toString() ?? '',
      ),
      endsAt: DateTime.tryParse(
        (map['endsAt'] ?? map['ends_at'])?.toString() ?? '',
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'leaderId': leaderId,
      'memberCount': memberCount,
      'createdAt': createdAt.toIso8601String(),
      'isJoined': isJoined,
      'isPublic': isPublic,
      'meetupLat': meetupLat,
      'meetupLng': meetupLng,
      'meetupLabel': meetupLabel,
      'startsAt': startsAt?.toIso8601String(),
      'endsAt': endsAt?.toIso8601String(),
    };
  }
}
