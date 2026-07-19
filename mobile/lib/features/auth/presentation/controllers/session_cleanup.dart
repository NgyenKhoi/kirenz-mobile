import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../blocks/presentation/controllers/block_controller.dart';
import '../../../friends/presentation/controllers/friends_controller.dart';
import '../../../privacy/presentation/controllers/privacy_controller.dart';
import '../../../profile/data/repositories/profile_content_repository.dart';
import '../../../profile/data/repositories/profile_repository.dart';
import '../../../profile/data/cache/profile_cache.dart';
import '../../../chat/data/cache/conversation_cache.dart';
import '../../../chat/data/cache/message_cache.dart';
import '../../../chat/presentation/controllers/conversation_controller.dart';
import '../../../chat/presentation/controllers/chat_realtime_controller.dart';
import '../../../feed/presentation/controllers/feed_controller.dart';
import '../../../explore/presentation/controllers/explore_controller.dart';
import '../../../posts/presentation/controllers/post_composer_controller.dart';
import '../../../notifications/presentation/controllers/notification_controller.dart';
import '../../data/services/google_auth_client.dart';

final sessionCleanupProvider = Provider<SessionCleanup>((ref) {
  return SessionCleanup(
    disconnectGoogle: ref.watch(googleAuthClientProvider).disconnect,
    disconnectRealtime: ref
        .watch(chatRealtimeControllerProvider.notifier)
        .disconnect,
    disconnectNotifications: () =>
        ref.read(notificationControllerProvider.notifier).disconnect(),
    clearPrivateDrafts: () async {
      ref.invalidate(postComposerControllerProvider);
    },
    clearUserCache: () async {
      await ref.watch(profileCacheProvider).clear();
      await ref.watch(conversationCacheProvider).clear();
      await ref.watch(messageCacheProvider).clear();
    },
    clearAccountState: () {
      ref.invalidate(currentUserProfileProvider);
      ref.invalidate(userProfileProvider);
      ref.invalidate(profilePostsProvider);
      ref.invalidate(profilePhotosProvider);
      ref.invalidate(incomingRequestsProvider);
      ref.invalidate(outgoingRequestsProvider);
      ref.invalidate(friendSuggestionsProvider);
      ref.invalidate(friendsProvider);
      ref.invalidate(friendStatusProvider);
      ref.invalidate(userSearchProvider);
      ref.invalidate(currentPrivacyProvider);
      ref.invalidate(userPrivacyProvider);
      ref.invalidate(blockedUsersProvider);
      ref.invalidate(blockStatusProvider);
      ref.invalidate(conversationControllerProvider);
      ref.invalidate(conversationCacheStatusProvider);
      ref.invalidate(chatRealtimeControllerProvider);
      ref.invalidate(feedControllerProvider);
      ref.invalidate(exploreControllerProvider);
      ref.invalidate(postComposerControllerProvider);
      ref.invalidate(notificationControllerProvider);
    },
  );
});

class SessionCleanup {
  const SessionCleanup({
    required this.disconnectGoogle,
    required this.disconnectRealtime,
    this.disconnectNotifications = _noopAsync,
    required this.clearPrivateDrafts,
    required this.clearUserCache,
    required this.clearAccountState,
  });

  final Future<void> Function() disconnectGoogle;
  final Future<void> Function() disconnectRealtime;
  final Future<void> Function() disconnectNotifications;
  final Future<void> Function() clearPrivateDrafts;
  final Future<void> Function() clearUserCache;
  final void Function() clearAccountState;

  Future<void> run() async {
    for (final step in [
      disconnectGoogle,
      disconnectRealtime,
      disconnectNotifications,
      clearPrivateDrafts,
      clearUserCache,
    ]) {
      try {
        await step();
      } on Object {
        continue;
      }
    }
    try {
      clearAccountState();
    } on Object {
      return;
    }
  }
}

Future<void> _noopAsync() async {}
