class ConvoyModel {
  const ConvoyModel({
    required this.id,
    required this.name,
    required this.leaderId,
    required this.memberCount,
    required this.createdAt,
    this.isJoined = false,
  });

  final String id;
  final String name;
  final String leaderId;
  final int memberCount;
  final DateTime createdAt;
  final bool isJoined;

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
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'leaderId': leaderId,
      'memberCount': memberCount,
      'createdAt': createdAt.toIso8601String(),
      'isJoined': isJoined,
    };
  }
}
