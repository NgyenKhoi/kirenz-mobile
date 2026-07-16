enum ConversationType { direct, group }

class ConversationParticipant {
  const ConversationParticipant({
    required this.userId,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.allowDirectMessages,
    required this.nickname,
    required this.admin,
  });

  factory ConversationParticipant.fromJson(Map<String, dynamic> json) =>
      ConversationParticipant(
        userId: json['userId']?.toString() ?? '',
        username: json['username']?.toString() ?? '',
        displayName: json['displayName']?.toString(),
        avatarUrl: json['avatarUrl']?.toString(),
        allowDirectMessages: json['allowDirectMessages'] == true,
        nickname: json['nickname']?.toString(),
        admin: json['admin'] == true,
      );

  final String userId;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final bool allowDirectMessages;
  final String? nickname;
  final bool admin;

  String get resolvedName {
    for (final value in [nickname, displayName, username]) {
      if (value != null && value.trim().isNotEmpty) return value.trim();
    }
    return 'Unknown';
  }
}

class ConversationLastMessage {
  const ConversationLastMessage({
    required this.messageId,
    required this.content,
    required this.senderId,
    required this.senderName,
    required this.type,
    required this.sentAt,
  });

  factory ConversationLastMessage.fromJson(Map<String, dynamic> json) =>
      ConversationLastMessage(
        messageId: json['messageId']?.toString() ?? '',
        content: json['content']?.toString() ?? '',
        senderId: json['senderId']?.toString() ?? '',
        senderName: json['senderName']?.toString() ?? '',
        type: json['type']?.toString().toUpperCase() ?? 'TEXT',
        sentAt: DateTime.tryParse(json['sentAt']?.toString() ?? ''),
      );

  final String messageId;
  final String content;
  final String senderId;
  final String senderName;
  final String type;
  final DateTime? sentAt;
}

class Conversation {
  const Conversation({
    required this.id,
    required this.type,
    required this.name,
    required this.participants,
    required this.adminIds,
    required this.currentUserAdmin,
    required this.lastMessage,
    required this.createdAt,
    required this.updatedAt,
    required this.unreadCount,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
    id: json['id']?.toString() ?? '',
    type: json['type']?.toString() == 'GROUP'
        ? ConversationType.group
        : ConversationType.direct,
    name: json['name']?.toString(),
    participants: _list(json['participants'])
        .map(ConversationParticipant.fromJson)
        .where((participant) => participant.userId.isNotEmpty)
        .toList(growable: false),
    adminIds: (json['adminIds'] is List ? json['adminIds'] as List : const [])
        .map((value) => value.toString())
        .toSet(),
    currentUserAdmin: json['currentUserAdmin'] == true,
    lastMessage: json['lastMessage'] == null
        ? null
        : ConversationLastMessage.fromJson(_map(json['lastMessage'])),
    createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
    unreadCount: int.tryParse(json['unreadCount']?.toString() ?? '') ?? 0,
  );

  final String id;
  final ConversationType type;
  final String? name;
  final List<ConversationParticipant> participants;
  final Set<String> adminIds;
  final bool currentUserAdmin;
  final ConversationLastMessage? lastMessage;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int unreadCount;

  String titleFor(String? currentUserId) {
    if (type == ConversationType.group) {
      final value = name?.trim();
      return value == null || value.isEmpty ? 'Group Chat' : value;
    }
    return participants
        .where((participant) => participant.userId != currentUserId)
        .map((participant) => participant.resolvedName)
        .firstWhere((_) => true, orElse: () => 'Unknown');
  }

  String previewFor(String? currentUserId) {
    final message = lastMessage;
    if (message == null) return 'No messages yet';
    final content = switch (message.type) {
      'IMAGE' => 'Sent an image',
      'VIDEO' => 'Sent a video',
      'FILE' => 'Sent a file',
      _ => message.content.trim().isEmpty ? 'New message' : message.content,
    };
    return message.senderId == currentUserId ? 'You: $content' : content;
  }
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<Map<String, dynamic>> _list(Object? value) =>
    value is List ? value.map(_map).toList(growable: false) : const [];
