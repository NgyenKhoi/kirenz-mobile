class BlockRecord {
  const BlockRecord({
    required this.id,
    required this.blockedUserId,
    required this.createdAt,
    this.username,
    this.displayName,
    this.avatarUrl,
  });

  factory BlockRecord.fromJson(Map<String, dynamic> json) {
    final user = _map(json['blockedUser'] ?? json['user']);
    return BlockRecord(
      id: json['id']?.toString() ?? '',
      blockedUserId:
          json['blockedUserId']?.toString() ?? user['id']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      username: json['username']?.toString() ?? user['username']?.toString(),
      displayName:
          json['displayName']?.toString() ?? user['displayName']?.toString(),
      avatarUrl: json['avatarUrl']?.toString() ?? user['avatarUrl']?.toString(),
    );
  }

  final String id;
  final String blockedUserId;
  final DateTime? createdAt;
  final String? username;
  final String? displayName;
  final String? avatarUrl;

  String get resolvedName {
    if (displayName?.trim().isNotEmpty == true) return displayName!.trim();
    if (username?.trim().isNotEmpty == true) return username!.trim();
    return 'Kirenz user';
  }

  BlockRecord withProfile({
    required String username,
    required String displayName,
    required String? avatarUrl,
  }) => BlockRecord(
    id: id,
    blockedUserId: blockedUserId,
    createdAt: createdAt,
    username: username,
    displayName: displayName,
    avatarUrl: avatarUrl,
  );
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const <String, dynamic>{};

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
