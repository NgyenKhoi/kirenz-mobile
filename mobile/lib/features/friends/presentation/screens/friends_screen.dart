import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../../shared/widgets/content_frame.dart';
import '../../domain/entities/friend_models.dart';
import '../controllers/friends_controller.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({this.initialSegment, super.key});

  final String? initialSegment;

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      key: ValueKey(widget.initialSegment),
      length: 3,
      initialIndex: switch (widget.initialSegment) {
        'suggestions' => 1,
        'friends' => 2,
        _ => 0,
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Friends'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Requests'),
              Tab(text: 'Suggestions'),
              Tab(text: 'Friends'),
            ],
          ),
        ),
        body: KirenzContentFrame(
          child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search people',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close),
                        ),
                ),
                onChanged: (value) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 450), () {
                    if (mounted) setState(() => _query = value.trim());
                  });
                },
              ),
            ),
            Expanded(
              child: _query.isNotEmpty
                  ? _SearchResults(query: _query)
                  : const TabBarView(
                      children: [
                        _RequestsTab(),
                        _SuggestionsTab(),
                        _FriendsTab(),
                      ],
                    ),
            ),
          ],
          ),
        ),
      ),
    );
  }
}

class _SearchResults extends ConsumerWidget {
  const _SearchResults({required this.query});
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (query.length < 2) {
      return const KirenzStateView(
        icon: Icons.search,
        title: 'Enter at least 2 characters',
      );
    }
    final results = ref.watch(userSearchProvider(query));
    return results.when(
      loading: () => const KirenzSkeletonList(itemCount: 6, itemHeight: 82),
      error: (error, stack) => KirenzStateView(
        icon: Icons.cloud_off_outlined,
        title: 'Could not search people',
        message: error.toString(),
        actionLabel: 'Retry',
        isError: true,
        onAction: () => ref.invalidate(userSearchProvider(query)),
      ),
      data: (items) => items.isEmpty
          ? const KirenzStateView(
              icon: Icons.person_search_outlined,
              title: 'No people found',
            )
          : RefreshIndicator(
              onRefresh: () async =>
                  ref.refresh(userSearchProvider(query).future),
              child: ListView.builder(
                key: const PageStorageKey('friend-search'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (context, index) => _SearchRow(user: items[index]),
              ),
            ),
    );
  }
}

class _RequestsTab extends ConsumerWidget {
  const _RequestsTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incoming = ref.watch(incomingRequestsProvider);
    final outgoing = ref.watch(outgoingRequestsProvider);
    if (incoming.isLoading || outgoing.isLoading) {
      return const KirenzSkeletonList(itemCount: 6, itemHeight: 82);
    }
    final error = incoming.error ?? outgoing.error;
    if (error != null) {
      return KirenzStateView(
        icon: Icons.cloud_off_outlined,
        title: 'Could not load friend requests',
        message: error.toString(),
        actionLabel: 'Retry',
        isError: true,
        onAction: () => _refreshRequests(ref),
      );
    }
    final incomingItems = incoming.value ?? const <FriendRequest>[];
    final outgoingItems = outgoing.value ?? const <FriendRequest>[];
    if (incomingItems.isEmpty && outgoingItems.isEmpty) {
      return const KirenzStateView(
        icon: Icons.mark_email_read_outlined,
        title: 'No pending friend requests',
      );
    }
    return RefreshIndicator(
      onRefresh: () => _refreshRequests(ref),
      child: ListView(
        key: const PageStorageKey('friend-requests'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (incomingItems.isNotEmpty) ...[
            const _SectionTitle('Incoming'),
            ...incomingItems.map(
              (item) => _RequestRow(request: item, incoming: true),
            ),
          ],
          if (outgoingItems.isNotEmpty) ...[
            const _SectionTitle('Sent'),
            ...outgoingItems.map(
              (item) => _RequestRow(request: item, incoming: false),
            ),
          ],
        ],
      ),
    );
  }
}

class _SuggestionsTab extends ConsumerWidget {
  const _SuggestionsTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(friendSuggestionsProvider);
    return data.when(
      loading: () => const KirenzSkeletonList(itemCount: 6, itemHeight: 82),
      error: (error, stack) => KirenzStateView(
        icon: Icons.cloud_off_outlined,
        title: 'Could not load suggestions',
        message: error.toString(),
        actionLabel: 'Retry',
        isError: true,
        onAction: () => ref.invalidate(friendSuggestionsProvider),
      ),
      data: (items) => items.isEmpty
          ? const KirenzStateView(
              icon: Icons.group_add_outlined,
              title: 'No suggestions right now',
            )
          : RefreshIndicator(
              onRefresh: () async =>
                  ref.refresh(friendSuggestionsProvider.future),
              child: ListView.builder(
                key: const PageStorageKey('friend-suggestions'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (context, index) =>
                    _SuggestionRow(suggestion: items[index]),
              ),
            ),
    );
  }
}

class _FriendsTab extends ConsumerWidget {
  const _FriendsTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(friendsProvider(null));
    return data.when(
      loading: () => const KirenzSkeletonList(itemCount: 6, itemHeight: 82),
      error: (error, stack) => KirenzStateView(
        icon: Icons.cloud_off_outlined,
        title: 'Could not load friends',
        message: error.toString(),
        actionLabel: 'Retry',
        isError: true,
        onAction: () => ref.invalidate(friendsProvider(null)),
      ),
      data: (items) => items.isEmpty
          ? const KirenzStateView(
              icon: Icons.people_outline,
              title: 'Your friend list is empty',
            )
          : RefreshIndicator(
              onRefresh: () async => ref.refresh(friendsProvider(null).future),
              child: ListView.builder(
                key: const PageStorageKey('friend-list'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (context, index) =>
                    _FriendRow(friend: items[index]),
              ),
            ),
    );
  }
}

class _SearchRow extends ConsumerWidget {
  const _SearchRow({required this.user});
  final UserSearchResult user;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(friendActionControllerProvider).contains(user.id);
    final incoming =
        ref.watch(incomingRequestsProvider).value ?? const <FriendRequest>[];
    final outgoing =
        ref.watch(outgoingRequestsProvider).value ?? const <FriendRequest>[];
    return _PersonCard(
      userId: user.id,
      name: user.resolvedName,
      username: user.username,
      avatarUrl: user.avatarUrl,
      bio: user.bio,
      trailing: _relationshipAction(
        context,
        ref,
        user,
        pending,
        incoming.where((item) => item.requesterId == user.id).firstOrNull,
        outgoing.where((item) => item.receiverId == user.id).firstOrNull,
      ),
    );
  }
}

Widget? _relationshipAction(
  BuildContext context,
  WidgetRef ref,
  UserSearchResult user,
  bool pending,
  FriendRequest? incomingRequest,
  FriendRequest? outgoingRequest,
) {
  final actions = ref.read(friendActionControllerProvider.notifier);
  Future<void> run(Future<void> Function() action) =>
      _showActionError(context, action);
  return switch (user.relationshipStatus) {
    RelationshipStatus.none => FilledButton(
      onPressed: pending ? null : () => run(() => actions.sendRequest(user.id)),
      child: const Text('Add'),
    ),
    RelationshipStatus.outgoingRequest => OutlinedButton(
      onPressed: pending || outgoingRequest == null
          ? null
          : () => run(() => actions.cancelRequest(user.id, outgoingRequest.id)),
      child: const Text('Cancel'),
    ),
    RelationshipStatus.incomingRequest => Wrap(
      spacing: 4,
      children: [
        TextButton(
          onPressed: pending || incomingRequest == null
              ? null
              : () => run(
                  () => actions.declineRequest(user.id, incomingRequest.id),
                ),
          child: const Text('Decline'),
        ),
        FilledButton(
          onPressed: pending || incomingRequest == null
              ? null
              : () => run(
                  () => actions.acceptRequest(user.id, incomingRequest.id),
                ),
          child: const Text('Accept'),
        ),
      ],
    ),
    RelationshipStatus.friends => const Chip(label: Text('Friends')),
    RelationshipStatus.self => null,
    RelationshipStatus.blocked => const Chip(label: Text('Blocked')),
    RelationshipStatus.blockedByTarget => const Chip(
      label: Text('Unavailable'),
    ),
    RelationshipStatus.unsupported => const Chip(label: Text('Unavailable')),
  };
}

class _RequestRow extends ConsumerWidget {
  const _RequestRow({required this.request, required this.incoming});
  final FriendRequest request;
  final bool incoming;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = incoming ? request.requesterId : request.receiverId;
    final pending = ref.watch(friendActionControllerProvider).contains(userId);
    final actions = ref.read(friendActionControllerProvider.notifier);
    return _PersonCard(
      userId: userId,
      name: request.resolvedName,
      username: request.username,
      avatarUrl: request.avatarUrl,
      bio: request.bio,
      trailing: Wrap(
        spacing: 8,
        children: incoming
            ? [
                TextButton(
                  onPressed: pending
                      ? null
                      : () => _showActionError(
                          context,
                          () => actions.declineRequest(userId, request.id),
                        ),
                  child: const Text('Decline'),
                ),
                FilledButton(
                  onPressed: pending
                      ? null
                      : () => _showActionError(
                          context,
                          () => actions.acceptRequest(userId, request.id),
                        ),
                  child: const Text('Accept'),
                ),
              ]
            : [
                OutlinedButton(
                  onPressed: pending
                      ? null
                      : () => _showActionError(
                          context,
                          () => actions.cancelRequest(userId, request.id),
                        ),
                  child: const Text('Cancel'),
                ),
              ],
      ),
    );
  }
}

class _SuggestionRow extends ConsumerWidget {
  const _SuggestionRow({required this.suggestion});
  final FriendSuggestion suggestion;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref
        .watch(friendActionControllerProvider)
        .contains(suggestion.id);
    return _PersonCard(
      userId: suggestion.id,
      name: suggestion.resolvedName,
      username: suggestion.username,
      avatarUrl: suggestion.avatarUrl,
      bio: suggestion.mutualFriendCount == 0
          ? suggestion.bio
          : '${suggestion.mutualFriendCount} mutual friends',
      trailing: FilledButton(
        onPressed: pending
            ? null
            : () => _showActionError(
                context,
                () => ref
                    .read(friendActionControllerProvider.notifier)
                    .sendRequest(suggestion.id),
              ),
        child: const Text('Add'),
      ),
    );
  }
}

class _FriendRow extends ConsumerWidget {
  const _FriendRow({required this.friend});
  final Friend friend;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref
        .watch(friendActionControllerProvider)
        .contains(friend.friendId);
    return _PersonCard(
      userId: friend.friendId,
      name: friend.resolvedName,
      username: friend.username,
      avatarUrl: friend.avatarUrl,
      bio: friend.bio,
      trailing: IconButton(
        tooltip: 'Remove friend',
        onPressed: pending ? null : () => _confirmRemove(context, ref, friend),
        icon: const Icon(Icons.person_remove_outlined),
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({
    required this.userId,
    required this.name,
    this.username,
    this.avatarUrl,
    this.bio,
    this.trailing,
  });
  final String userId;
  final String name;
  final String? username;
  final String? avatarUrl;
  final String? bio;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: userId.isEmpty ? null : () => context.push('/profile/$userId'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              KirenzUserAvatar(name: name, imageUrl: avatarUrl, radius: 25),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    if (username?.isNotEmpty == true)
                      Text(
                        '@$username',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    if (bio?.isNotEmpty == true)
                      Text(bio!, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
    ),
  );
}

Future<void> _refreshRequests(WidgetRef ref) async {
  ref.invalidate(incomingRequestsProvider);
  ref.invalidate(outgoingRequestsProvider);
  await Future.wait([
    ref.read(incomingRequestsProvider.future),
    ref.read(outgoingRequestsProvider.future),
  ]);
}

Future<void> _showActionError(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } on Object catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}

Future<void> _confirmRemove(
  BuildContext context,
  WidgetRef ref,
  Friend friend,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Remove ${friend.resolvedName}?'),
      content: const Text('You will no longer be friends.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Keep friend'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Remove'),
        ),
      ],
    ),
  );
  if (confirmed == true && context.mounted) {
    await _showActionError(
      context,
      () => ref
          .read(friendActionControllerProvider.notifier)
          .removeFriend(friend.friendId),
    );
  }
}

