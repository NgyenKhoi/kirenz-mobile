import 'conversation.dart';

class UserPresence {
  const UserPresence({required this.isOnline, this.lastSeen});

  final bool isOnline;
  final DateTime? lastSeen;

  String label(DateTime now) {
    if (isOnline) return 'Online';
    final seen = lastSeen;
    if (seen == null) return 'Offline';
    final elapsed = now.difference(seen.toLocal());
    if (elapsed.inMinutes < 1) return 'Active just now';
    if (elapsed.inHours < 1) return 'Active ${elapsed.inMinutes}m ago';
    if (elapsed.inDays < 1) return 'Active ${elapsed.inHours}h ago';
    return 'Active ${elapsed.inDays}d ago';
  }
}

class ConversationRealtimeUpdate {
  const ConversationRealtimeUpdate({
    required this.conversationId,
    required this.lastMessage,
    required this.unreadCount,
    required this.updatedAt,
  });

  factory ConversationRealtimeUpdate.fromJson(Map<String, dynamic> json) {
    final conversationId = json['conversationId']?.toString().trim() ?? '';
    if (conversationId.isEmpty) {
      throw const FormatException('Conversation update has no id.');
    }
    final rawMessage = json['lastMessage'];
    return ConversationRealtimeUpdate(
      conversationId: conversationId,
      lastMessage: rawMessage is Map
          ? ConversationLastMessage.fromJson(
              Map<String, dynamic>.from(rawMessage),
            )
          : null,
      unreadCount: int.tryParse(json['unreadCount']?.toString() ?? '') ?? 0,
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
    );
  }

  final String conversationId;
  final ConversationLastMessage? lastMessage;
  final int unreadCount;
  final DateTime? updatedAt;
}

class TypingUser {
  const TypingUser({required this.userId, required this.name});

  final String userId;
  final String name;
}
