import 'package:latlong2/latlong.dart';
import 'dart:math' as math;
import 'package:slowride/l10n/app_localizations.dart';

enum AlertType {
  roadClosure,
  police,
  roadwork,
  accident,
  trafficJam,
  speedCamera,
  hazard,
  narrowRoad,
  steepHill,
  speedBump,
  meetup,
  parking,
  foodStop,
  charging,
  hangout,
}

extension AlertTypeX on AlertType {
  String get key => switch (this) {
    AlertType.roadClosure => 'road_closure',
    AlertType.police => 'police',
    AlertType.roadwork => 'roadwork',
    AlertType.accident => 'accident',
    AlertType.trafficJam => 'traffic_jam',
    AlertType.speedCamera => 'speed_camera',
    AlertType.hazard => 'hazard',
    AlertType.narrowRoad => 'narrow_road',
    AlertType.steepHill => 'steep_hill',
    AlertType.speedBump => 'speed_bump',
    AlertType.meetup => 'meetup',
    AlertType.parking => 'parking',
    AlertType.foodStop => 'food_stop',
    AlertType.charging => 'charging',
    AlertType.hangout => 'hangout',
  };

  String get label => switch (this) {
    AlertType.roadClosure => 'Road closure',
    AlertType.police => 'Police',
    AlertType.roadwork => 'Roadwork',
    AlertType.accident => 'Accident',
    AlertType.trafficJam => 'Traffic jam',
    AlertType.speedCamera => 'Speed camera',
    AlertType.hazard => 'Hazard',
    AlertType.narrowRoad => 'Narrow road',
    AlertType.steepHill => 'Steep hill',
    AlertType.speedBump => 'High speed bump',
    AlertType.meetup => 'Meetup spot',
    AlertType.parking => 'Parking',
    AlertType.foodStop => 'Food stop',
    AlertType.charging => 'Charging',
    AlertType.hangout => 'Hangout',
  };

  String localizedLabel(AppLocalizations l10n) => switch (this) {
    AlertType.roadClosure => l10n.alertTypeRoadClosure,
    AlertType.police => l10n.alertTypePolice,
    AlertType.roadwork => l10n.alertTypeRoadwork,
    AlertType.accident => l10n.alertTypeAccident,
    AlertType.trafficJam => l10n.alertTypeTrafficJam,
    AlertType.speedCamera => l10n.alertTypeSpeedCamera,
    AlertType.hazard => l10n.alertTypeHazard,
    AlertType.narrowRoad => l10n.alertTypeNarrowRoad,
    AlertType.steepHill => l10n.alertTypeSteepHill,
    AlertType.speedBump => l10n.alertTypeSpeedBump,
    AlertType.meetup => l10n.alertTypeMeetup,
    AlertType.parking => l10n.alertTypeParking,
    AlertType.foodStop => l10n.alertTypeFoodStop,
    AlertType.charging => l10n.alertTypeCharging,
    AlertType.hangout => l10n.alertTypeHangout,
  };

  String get emoji => switch (this) {
    AlertType.roadClosure => '⛔',
    AlertType.police => '👮',
    AlertType.roadwork => '🚧',
    AlertType.accident => '🚗',
    AlertType.trafficJam => '🚦',
    AlertType.speedCamera => '📷',
    AlertType.hazard => '⚠️',
    AlertType.narrowRoad => '↔️',
    AlertType.steepHill => '⛰️',
    AlertType.speedBump => '〰️',
    AlertType.meetup => '📍',
    AlertType.parking => '🅿️',
    AlertType.foodStop => '🍔',
    AlertType.charging => '🔌',
    AlertType.hangout => '⭐',
  };

  static AlertType fromKey(String key) => switch (key) {
    'road_closure' => AlertType.roadClosure,
    'police' => AlertType.police,
    'roadwork' => AlertType.roadwork,
    'accident' => AlertType.accident,
    'traffic_jam' => AlertType.trafficJam,
    'speed_camera' => AlertType.speedCamera,
    'narrow_road' => AlertType.narrowRoad,
    'steep_hill' => AlertType.steepHill,
    'speed_bump' => AlertType.speedBump,
    'meetup' => AlertType.meetup,
    'parking' => AlertType.parking,
    'food_stop' => AlertType.foodStop,
    'charging' => AlertType.charging,
    'hangout' => AlertType.hangout,
    _ => AlertType.hazard,
  };

  /// Roadside warnings participate in the proximity banner. Community POIs
  /// remain visible on the map without interrupting navigation.
  bool get showsProximityWarning => switch (this) {
    AlertType.meetup ||
    AlertType.parking ||
    AlertType.foodStop ||
    AlertType.charging ||
    AlertType.hangout => false,
    _ => true,
  };

  int get warningRadiusMeters => switch (this) {
    AlertType.roadClosure => 1000,
    AlertType.accident => 800,
    AlertType.trafficJam || AlertType.roadwork => 700,
    AlertType.police || AlertType.speedCamera => 600,
    AlertType.speedBump => 300,
    _ => 400,
  };

  int get warningPriority => switch (this) {
    AlertType.roadClosure => 100,
    AlertType.accident => 90,
    AlertType.trafficJam => 80,
    AlertType.roadwork => 70,
    AlertType.police => 65,
    AlertType.speedCamera => 60,
    AlertType.hazard => 55,
    AlertType.narrowRoad || AlertType.steepHill => 50,
    AlertType.speedBump => 45,
    _ => 0,
  };
}

class AlertModel {
  const AlertModel({
    required this.id,
    required this.type,
    required this.position,
    required this.description,
    required this.upvotes,
    required this.createdAt,
    this.userId,
  });

  final String id;
  final AlertType type;
  final LatLng position;
  final String description;
  final int upvotes;
  final DateTime createdAt;
  final String? userId;

  /// Alerts expire quickly, while community POIs live longer.
  static Duration ttlFor(AlertType type) => switch (type) {
    AlertType.roadClosure => const Duration(hours: 6),
    AlertType.roadwork => const Duration(hours: 24),
    // Speed bumps are infrastructure and remain relevant much longer than
    // temporary traffic alerts.
    AlertType.speedBump => const Duration(days: 365),
    AlertType.meetup ||
    AlertType.parking ||
    AlertType.foodStop ||
    AlertType.charging ||
    AlertType.hangout => const Duration(days: 30),
    _ => const Duration(hours: 2),
  };

  bool get isExpired =>
      DateTime.now().difference(createdAt) > AlertModel.ttlFor(type);

  /// Picks the most important nearby road warning, then the closest warning
  /// when two candidates have the same priority.
  static AlertModel? mostRelevantNearby(
    Iterable<AlertModel> alerts,
    LatLng position, {
    String? excludedId,
  }) {
    final candidates = alerts.where((alert) {
      return alert.id != excludedId &&
          alert.type.showsProximityWarning &&
          alert.distanceTo(position) <= alert.type.warningRadiusMeters;
    }).toList();
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) {
      final priority = b.type.warningPriority.compareTo(a.type.warningPriority);
      if (priority != 0) return priority;
      return a.distanceTo(position).compareTo(b.distanceTo(position));
    });
    return candidates.first;
  }

  /// Haversine distance in metres to [other].
  double distanceTo(LatLng other) {
    const r = 6371000.0;
    final lat1 = position.latitude * math.pi / 180;
    final lat2 = other.latitude * math.pi / 180;
    final dLat = (other.latitude - position.latitude) * math.pi / 180;
    final dLng = (other.longitude - position.longitude) * math.pi / 180;
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return r * 2 * math.asin(math.sqrt(a));
  }

  factory AlertModel.fromMap(Map<String, dynamic> m) {
    return AlertModel(
      id: m['id'].toString(),
      type: AlertTypeX.fromKey(m['type']?.toString() ?? ''),
      position: LatLng(
        (m['lat'] as num?)?.toDouble() ?? 0,
        (m['lng'] as num?)?.toDouble() ?? 0,
      ),
      description: m['description']?.toString() ?? '',
      upvotes: (m['upvotes'] as num?)?.toInt() ?? 0,
      createdAt:
          DateTime.tryParse(m['created_at']?.toString() ?? '') ??
          DateTime.now(),
      userId: m['user_id']?.toString(),
    );
  }
}
