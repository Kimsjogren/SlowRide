import 'package:latlong2/latlong.dart';
import 'dart:math' as math;
import 'package:slowride/l10n/app_localizations.dart';

enum AlertType {
  police,
  roadwork,
  accident,
  trafficJam,
  speedCamera,
  hazard,
  narrowRoad,
  steepHill,
}

extension AlertTypeX on AlertType {
  String get key => switch (this) {
    AlertType.police => 'police',
    AlertType.roadwork => 'roadwork',
    AlertType.accident => 'accident',
    AlertType.trafficJam => 'traffic_jam',
    AlertType.speedCamera => 'speed_camera',
    AlertType.hazard => 'hazard',
    AlertType.narrowRoad => 'narrow_road',
    AlertType.steepHill => 'steep_hill',
  };

  String get label => switch (this) {
    AlertType.police => 'Police',
    AlertType.roadwork => 'Roadwork',
    AlertType.accident => 'Accident',
    AlertType.trafficJam => 'Traffic jam',
    AlertType.speedCamera => 'Speed camera',
    AlertType.hazard => 'Hazard',
    AlertType.narrowRoad => 'Narrow road',
    AlertType.steepHill => 'Steep hill',
  };

  String localizedLabel(AppLocalizations l10n) => switch (this) {
    AlertType.police => l10n.alertTypePolice,
    AlertType.roadwork => l10n.alertTypeRoadwork,
    AlertType.accident => l10n.alertTypeAccident,
    AlertType.trafficJam => l10n.alertTypeTrafficJam,
    AlertType.speedCamera => l10n.alertTypeSpeedCamera,
    AlertType.hazard => l10n.alertTypeHazard,
    AlertType.narrowRoad => l10n.alertTypeNarrowRoad,
    AlertType.steepHill => l10n.alertTypeSteepHill,
  };

  String get emoji => switch (this) {
    AlertType.police => '👮',
    AlertType.roadwork => '🚧',
    AlertType.accident => '🚗',
    AlertType.trafficJam => '🚦',
    AlertType.speedCamera => '📷',
    AlertType.hazard => '⚠️',
    AlertType.narrowRoad => '↔️',
    AlertType.steepHill => '⛰️',
  };

  static AlertType fromKey(String key) => switch (key) {
    'police' => AlertType.police,
    'roadwork' => AlertType.roadwork,
    'accident' => AlertType.accident,
    'traffic_jam' => AlertType.trafficJam,
    'speed_camera' => AlertType.speedCamera,
    'narrow_road' => AlertType.narrowRoad,
    'steep_hill' => AlertType.steepHill,
    _ => AlertType.hazard,
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

  /// Alerts expire after 2 h (roadworks: 24 h).
  static Duration ttlFor(AlertType type) => type == AlertType.roadwork
      ? const Duration(hours: 24)
      : const Duration(hours: 2);

  bool get isExpired =>
      DateTime.now().difference(createdAt) > AlertModel.ttlFor(type);

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
