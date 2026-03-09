class ConvoyMessage {
  const ConvoyMessage({
    required this.id,
    required this.convoyId,
    required this.userId,
    required this.userLabel,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String convoyId;
  final String userId;
  final String userLabel;
  final String text;
  final DateTime createdAt;

  factory ConvoyMessage.fromMap(Map<String, dynamic> map) {
    final rawCreatedAt = map['created_at'];
    final createdAt =
        DateTime.tryParse(rawCreatedAt?.toString() ?? '') ?? DateTime.now();

    return ConvoyMessage(
      id: map['id'].toString(),
      convoyId: map['convoy_id'].toString(),
      userId: map['user_id'].toString(),
      userLabel: map['user_label']?.toString() ?? 'Rider',
      text: map['text']?.toString() ?? '',
      createdAt: createdAt,
    );
  }
}
