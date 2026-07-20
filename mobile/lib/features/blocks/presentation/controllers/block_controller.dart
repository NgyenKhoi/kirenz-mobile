import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../feed/presentation/controllers/feed_controller.dart';
import '../../../friends/presentation/controllers/friends_controller.dart';
import '../../../privacy/data/repositories/privacy_repository.dart';
import '../../../profile/data/repositories/profile_content_repository.dart';
import '../../../profile/data/cache/profile_cache.dart';
import '../../../profile/data/repositories/profile_repository.dart';
import '../../data/repositories/block_repository.dart';
import '../../domain/entities/block_models.dart';

final blockedUsersProvider = FutureProvider<List<BlockRecord>>((ref) async {
  final records = await ref.watch(blockRepositoryProvider).listBlockedUsers();
  return Future.wait(
    records.map((record) async {
      if (record.displayName?.trim().isNotEmpty == true ||
          record.username?.trim().isNotEmpty == true) {
        return record;
      }
      try {
        final profile = await ref
            .watch(profileRepositoryProvider)
            .getUser(record.blockedUserId);
        return record.withProfile(
          username: profile.username,
          displayName: profile.displayName,
          avatarUrl: profile.avatarUrl,
        );
      } on Object {
        return record;
      }
    }),
  );
});

final blockStatusProvider = FutureProvider.family<BlockStatus, String>((
  ref,
  userId,
) {
  return ref.watch(blockRepositoryProvider).getStatus(userId);
});

final blockActionControllerProvider =
    NotifierProvider<BlockActionController, Set<String>>(
      BlockActionController.new,
    );

class BlockActionController extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{};

  Future<void> block(String userId) =>
      _run(userId, () => ref.read(blockRepositoryProvider).block(userId));

  Future<void> unblock(String userId) =>
      _run(userId, () => ref.read(blockRepositoryProvider).unblock(userId));

  Future<void> _run(String userId, Future<void> Function() action) async {
    if (state.contains(userId)) return;
    state = {...state, userId};
    try {
      await action();
      await ref.read(profileCacheProvider).removeUser(userId);
      ref.invalidate(blockedUsersProvider);
      ref.invalidate(blockStatusProvider(userId));
      ref.invalidate(friendStatusProvider(userId));
      ref.invalidate(incomingRequestsProvider);
      ref.invalidate(outgoingRequestsProvider);
      ref.invalidate(friendSuggestionsProvider);
      ref.invalidate(friendsProvider);
      ref.invalidate(userSearchProvider);
      ref.invalidate(profilePostsProvider(userId));
      ref.invalidate(profilePhotosProvider(userId));
      ref.invalidate(feedControllerProvider);
      ref.invalidate(privacyRepositoryProvider);
    } finally {
      state = {...state}..remove(userId);
    }
  }
}
