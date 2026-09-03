class SupportMessage {
  const SupportMessage({
    required this.id,
    required this.userId,
    required this.body,
    required this.isFromSupport,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final String userId;
  final String body;
  final bool isFromSupport;
  final DateTime createdAt;
  final DateTime? readAt;

  factory SupportMessage.fromMap(Map<String, dynamic> map) {
    return SupportMessage(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      body: map['body']?.toString() ?? '',
      isFromSupport: map['sender']?.toString() == 'support',
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
      readAt: DateTime.tryParse(map['read_at']?.toString() ?? '')?.toLocal(),
    );
  }
}
