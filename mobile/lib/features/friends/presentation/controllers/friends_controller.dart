import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/friend_repository.dart';
import '../../../profile/data/cache/profile_cache.dart';
import '../../domain/entities/friend_models.dart';

final incomingRequestsProvider = FutureProvider<List<FriendRequest>>((ref) {
  return ref.watch(friendRepositoryProvider).getIncomingRequests();
});

final outgoingRequestsProvider = FutureProvider<List<FriendRequest>>((ref) {
  return ref.watch(friendRepositoryProvider).getOutgoingRequests();
});

final friendSuggestionsProvider = FutureProvider<List<FriendSuggestion>>((ref) {
  return ref.watch(friendRepositoryProvider).getSuggestions();
});

final friendsProvider = FutureProvider.family<List<Friend>, String?>((
  ref,
  userId,
) {
  return ref.watch(friendRepositoryProvider).getFriends(userId: userId);
});

final friendStatusProvider = FutureProvider.family<RelationshipStatus, String>((
  ref,
  userId,
) {
  return ref.watch(friendRepositoryProvider).getStatus(userId);
});

final userSearchProvider = FutureProvider.autoDispose
    .family<List<UserSearchResult>, String>((ref, query) {
      final normalized = query.trim();
      if (normalized.length < 2) return <UserSearchResult>[];
      return ref.watch(friendRepositoryProvider).searchUsers(normalized);
    });

final friendActionControllerProvider =
    NotifierProvider<FriendActionController, Set<String>>(
      FriendActionController.new,
    );

class FriendActionController extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{};

  Future<void> sendRequest(String userId) => _run(
    userId,
    () => ref.read(friendRepositoryProvider).sendRequest(userId),
  );

  Future<void> acceptRequest(String userId, String requestId) => _run(
    userId,
    () => ref.read(friendRepositoryProvider).acceptRequest(requestId),
  );

  Future<void> declineRequest(String userId, String requestId) => _run(
    userId,
    () => ref.read(friendRepositoryProvider).declineRequest(requestId),
  );

  Future<void> cancelRequest(String userId, String requestId) => _run(
    userId,
    () => ref.read(friendRepositoryProvider).cancelRequest(requestId),
  );

  Future<void> removeFriend(String userId) => _run(
    userId,
    () => ref.read(friendRepositoryProvider).removeFriend(userId),
  );

  Future<void> acceptRequestForUser(String userId) => _run(userId, () async {
    final requests = await ref
        .read(friendRepositoryProvider)
        .getIncomingRequests();
    final request = requests
        .where((item) => item.requesterId == userId)
        .firstOrNull;
    if (request == null) {
      throw StateError('The incoming request is no longer available.');
    }
    await ref.read(friendRepositoryProvider).acceptRequest(request.id);
  });

  Future<void> declineRequestForUser(String userId) => _run(userId, () async {
    final requests = await ref
        .read(friendRepositoryProvider)
        .getIncomingRequests();
    final request = requests
        .where((item) => item.requesterId == userId)
        .firstOrNull;
    if (request == null) {
      throw StateError('The incoming request is no longer available.');
    }
    await ref.read(friendRepositoryProvider).declineRequest(request.id);
  });

  Future<void> cancelRequestForUser(String userId) => _run(userId, () async {
    final requests = await ref
        .read(friendRepositoryProvider)
        .getOutgoingRequests();
    final request = requests
        .where((item) => item.receiverId == userId)
        .firstOrNull;
    if (request == null) {
      throw StateError('The outgoing request is no longer available.');
    }
    await ref.read(friendRepositoryProvider).cancelRequest(request.id);
  });

  Future<void> _run(String userId, Future<void> Function() action) async {
    if (state.contains(userId)) return;
    state = {...state, userId};
    try {
      await action();
      await ref.read(profileCacheProvider).removeUser(userId);
      ref.invalidate(incomingRequestsProvider);
      ref.invalidate(outgoingRequestsProvider);
      ref.invalidate(friendSuggestionsProvider);
      ref.invalidate(friendsProvider);
      ref.invalidate(userSearchProvider);
      ref.invalidate(friendStatusProvider(userId));
    } finally {
      state = {...state}..remove(userId);
    }
  }
}
