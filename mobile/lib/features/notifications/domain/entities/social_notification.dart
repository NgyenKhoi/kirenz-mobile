enum SocialNotificationType {
  friendRequest,
  friendAccept,
  postComment,
  postLike,
  commentReply,
  postMention,
  commentMention,
  birthday,
  welcome,
  unsupported,
}

class SocialNotification {
  const SocialNotification({
    required this.id,
    required this.receiverId,
    required this.actorId,
    required this.actorName,
    required this.actorAvatar,
    required this.type,
    required this.targetId,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  factory SocialNotification.fromJson(Map<String, dynamic> json) =>
      SocialNotification(
        id: json['id']?.toString() ?? '',
        receiverId: json['receiverId']?.toString() ?? '',
        actorId: json['actorId']?.toString() ?? '',
        actorName: json['actorName']?.toString() ?? 'Kirenz',
        actorAvatar: json['actorAvatar']?.toString(),
        type: socialNotificationTypeFromWire(json['type']),
        targetId: json['targetId']?.toString(),
        message: json['message']?.toString() ?? 'You have a new alert.',
        isRead: json['isRead'] == true,
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      );

  final String id;
  final String receiverId;
  final String actorId;
  final String actorName;
  final String? actorAvatar;
  final SocialNotificationType type;
  final String? targetId;
  final String message;
  final bool isRead;
  final DateTime? createdAt;

  SocialNotification copyWith({bool? isRead}) => SocialNotification(
    id: id,
    receiverId: receiverId,
    actorId: actorId,
    actorName: actorName,
    actorAvatar: actorAvatar,
    type: type,
    targetId: targetId,
    message: message,
    isRead: isRead ?? this.isRead,
    createdAt: createdAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'receiverId': receiverId,
    'actorId': actorId,
    'actorName': actorName,
    'actorAvatar': actorAvatar,
    'type': type.wireName,
    'targetId': targetId,
    'message': message,
    'isRead': isRead,
    'createdAt': createdAt?.toUtc().toIso8601String(),
  };
}

SocialNotificationType socialNotificationTypeFromWire(Object? value) =>
    switch (value?.toString()) {
      'FRIEND_REQUEST' => SocialNotificationType.friendRequest,
      'FRIEND_ACCEPT' => SocialNotificationType.friendAccept,
      'POST_COMMENT' => SocialNotificationType.postComment,
      'POST_LIKE' => SocialNotificationType.postLike,
      'COMMENT_REPLY' => SocialNotificationType.commentReply,
      'POST_MENTION' => SocialNotificationType.postMention,
      'COMMENT_MENTION' => SocialNotificationType.commentMention,
      'BIRTHDAY' => SocialNotificationType.birthday,
      'WELCOME' => SocialNotificationType.welcome,
      _ => SocialNotificationType.unsupported,
    };

extension SocialNotificationTypeWire on SocialNotificationType {
  String get wireName => switch (this) {
    SocialNotificationType.friendRequest => 'FRIEND_REQUEST',
    SocialNotificationType.friendAccept => 'FRIEND_ACCEPT',
    SocialNotificationType.postComment => 'POST_COMMENT',
    SocialNotificationType.postLike => 'POST_LIKE',
    SocialNotificationType.commentReply => 'COMMENT_REPLY',
    SocialNotificationType.postMention => 'POST_MENTION',
    SocialNotificationType.commentMention => 'COMMENT_MENTION',
    SocialNotificationType.birthday => 'BIRTHDAY',
    SocialNotificationType.welcome => 'WELCOME',
    SocialNotificationType.unsupported => 'UNSUPPORTED',
  };
}
