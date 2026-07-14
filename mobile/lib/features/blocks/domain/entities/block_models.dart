class BlockRecord {
  const BlockRecord({
    required this.id,
    required this.blockedUserId,
    required this.createdAt,
  });

  factory BlockRecord.fromJson(Map<String, dynamic> json) => BlockRecord(
    id: json['id']?.toString() ?? '',
    blockedUserId: json['blockedUserId']?.toString() ?? '',
    createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
  );

  final String id;
  final String blockedUserId;
  final DateTime? createdAt;
}

class BlockStatus {
  const BlockStatus({
    required this.viewerId,
    required this.targetUserId,
    required this.blockedByViewer,
    required this.blockedViewer,
  });

  factory BlockStatus.fromJson(Map<String, dynamic> json) => BlockStatus(
    viewerId: json['viewerId']?.toString() ?? '',
    targetUserId: json['targetUserId']?.toString() ?? '',
    blockedByViewer: json['blockedByViewer'] == true,
    blockedViewer: json['blockedViewer'] == true,
  );

  final String viewerId;
  final String targetUserId;
  final bool blockedByViewer;
  final bool blockedViewer;
}
