import 'package:latlong2/latlong.dart';

class ConvoyPin {
  const ConvoyPin({
    required this.id,
    required this.convoyId,
    required this.userId,
    required this.userLabel,
    required this.label,
    required this.type,
    required this.position,
    required this.createdAt,
  });

  final String id;
  final String convoyId;
  final String userId;
  final String userLabel;
  final String label;
  final String type;
  final LatLng position;
  final DateTime createdAt;

  factory ConvoyPin.fromMap(Map<String, dynamic> map) {
    final rawCreatedAt = map['created_at'];
    final createdAt =
        DateTime.tryParse(rawCreatedAt?.toString() ?? '') ?? DateTime.now();

    return ConvoyPin(
      id: map['id'].toString(),
      convoyId: map['convoy_id'].toString(),
      userId: map['user_id'].toString(),
      userLabel: map['user_label']?.toString() ?? 'Rider',
      label: map['label']?.toString() ?? 'Pin',
      type: map['type']?.toString() ?? 'custom',
      position: LatLng(
        (map['lat'] as num?)?.toDouble() ?? 0,
        (map['lng'] as num?)?.toDouble() ?? 0,
      ),
      createdAt: createdAt,
    );
  }
}
