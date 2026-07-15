import 'package:latlong2/latlong.dart';

class ConvoyMemberLocation {
  const ConvoyMemberLocation({
    required this.convoyId,
    required this.userId,
    required this.userLabel,
    required this.position,
    required this.updatedAt,
    this.vehicleStyle = 'navigation',
  });

  final String convoyId;
  final String userId;
  final String userLabel;
  final LatLng position;
  final DateTime updatedAt;
  final String vehicleStyle;

  factory ConvoyMemberLocation.fromMap(Map<String, dynamic> map) {
    final rawUpdatedAt = map['updated_at'];
    final updatedAt =
        DateTime.tryParse(rawUpdatedAt?.toString() ?? '') ?? DateTime.now();

    return ConvoyMemberLocation(
      convoyId: map['convoy_id'].toString(),
      userId: map['user_id'].toString(),
      userLabel: map['user_label']?.toString() ?? 'Rider',
      position: LatLng(
        (map['lat'] as num?)?.toDouble() ?? 0,
        (map['lng'] as num?)?.toDouble() ?? 0,
      ),
      updatedAt: updatedAt,
      vehicleStyle: map['vehicle_style']?.toString() ?? 'navigation',
    );
  }
}
