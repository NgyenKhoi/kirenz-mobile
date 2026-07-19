import '../domain/entities/social_notification.dart';

String? socialNotificationRoute(SocialNotification notification) {
  final actorId = notification.actorId.trim();
  final targetId = notification.targetId?.trim() ?? '';
  return switch (notification.type) {
    SocialNotificationType.friendRequest => '/friends?segment=requests',
    SocialNotificationType.friendAccept =>
      actorId.isEmpty ? null : '/profile/$actorId',
    SocialNotificationType.postComment ||
    SocialNotificationType.postLike ||
    SocialNotificationType.commentReply ||
    SocialNotificationType.postMention ||
    SocialNotificationType.commentMention =>
      targetId.isEmpty ? null : '/post/$targetId',
    SocialNotificationType.birthday =>
      actorId.isNotEmpty
          ? '/profile/$actorId'
          : targetId.isEmpty
          ? null
          : '/profile/$targetId',
    SocialNotificationType.welcome => '/profile/me',
    SocialNotificationType.unsupported => null,
  };
}
