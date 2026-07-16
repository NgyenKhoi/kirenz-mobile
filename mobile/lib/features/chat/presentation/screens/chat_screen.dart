import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/controllers/session_controller.dart';
import '../../../friends/domain/entities/friend_models.dart';
import '../../../friends/presentation/controllers/friends_controller.dart';
import '../../domain/entities/conversation.dart';
import '../controllers/conversation_controller.dart';

class ChatScreen extends ConsumerWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(conversationControllerProvider);
    final currentUserId = ref.watch(sessionControllerProvider).user?.id;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        actions: [
          IconButton(
            tooltip: 'New message',
            onPressed: () => _showDirectSearch(context),
            icon: const Icon(Icons.edit_square),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateGroup(context),
        icon: const Icon(Icons.group_add_outlined),
        label: const Text('New group'),
      ),
      body: conversations.when(
        skipLoadingOnRefresh: true,
        data: (rows) => RefreshIndicator(
          onRefresh: () =>
              ref.read(conversationControllerProvider.notifier).refresh(),
          child: rows.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 160),
                    Icon(Icons.forum_outlined, size: 56),
                    SizedBox(height: 16),
                    Center(child: Text('No conversations yet')),
                    SizedBox(height: 8),
                    Center(child: Text('Start a message or create a group.')),
                  ],
                )
              : ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) => _ConversationTile(
                    conversation: rows[index],
                    currentUserId: currentUserId,
                  ),
                ),
        ),
        loading: () => const _ConversationSkeleton(),
        error: (error, stackTrace) => _ConversationError(
          message: error.toString(),
          onRetry: () => ref.invalidate(conversationControllerProvider),
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.currentUserId,
  });

  final Conversation conversation;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    final title = conversation.titleFor(currentUserId);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        child: conversation.type == ConversationType.group
            ? const Icon(Icons.groups_outlined)
            : Text(_initials(title)),
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        conversation.previewFor(currentUserId),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: conversation.unreadCount > 0
          ? Badge(label: Text('${conversation.unreadCount}'))
          : null,
      onTap: () => context.push('/chat/${conversation.id}'),
    );
  }
}

class _ConversationSkeleton extends StatelessWidget {
  const _ConversationSkeleton();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHigh;
    return ListView.builder(
      itemCount: 7,
      itemBuilder: (context, index) => ListTile(
        leading: CircleAvatar(backgroundColor: color),
        title: FractionallySizedBox(
          widthFactor: .55,
          alignment: Alignment.centerLeft,
          child: Container(height: 14, color: color),
        ),
        subtitle: Container(
          height: 12,
          margin: const EdgeInsets.only(top: 8),
          color: color,
        ),
      ),
    );
  }
}

class _ConversationError extends StatelessWidget {
  const _ConversationError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 52),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}

Future<void> _showDirectSearch(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _DirectSearchSheet(),
    );

class _DirectSearchSheet extends ConsumerStatefulWidget {
  const _DirectSearchSheet();

  @override
  ConsumerState<_DirectSearchSheet> createState() => _DirectSearchSheetState();
}

class _DirectSearchSheetState extends ConsumerState<_DirectSearchSheet> {
  String _query = '';
  String? _pendingId;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(userSearchProvider(_query));
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .72,
          child: Column(
            children: [
              Text(
                'New message',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search people',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) => setState(() {
                  _query = value.trim();
                  _error = null;
                }),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Expanded(child: _searchResults(results)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _searchResults(AsyncValue<List<UserSearchResult>> results) {
    if (_query.length < 2) {
      return const Center(child: Text('Type at least 2 characters.'));
    }
    return results.when(
      data: (users) => users.isEmpty
          ? const Center(child: Text('No people found'))
          : ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                final unavailable =
                    user.relationshipStatus == RelationshipStatus.blocked ||
                    user.relationshipStatus ==
                        RelationshipStatus.blockedByTarget;
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(_initials(user.resolvedName)),
                  ),
                  title: Text(user.resolvedName),
                  subtitle: Text(
                    unavailable ? 'Messaging unavailable' : '@${user.username}',
                  ),
                  enabled: !unavailable && _pendingId == null,
                  trailing: _pendingId == user.id
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: unavailable ? null : () => _openDirect(user.id),
                );
              },
            ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text(error.toString())),
    );
  }

  Future<void> _openDirect(String userId) async {
    setState(() {
      _pendingId = userId;
      _error = null;
    });
    try {
      final conversation = await ref
          .read(conversationControllerProvider.notifier)
          .getOrCreateDirect(userId);
      if (mounted) context.go('/chat/${conversation.id}');
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _pendingId = null);
    }
  }
}

Future<void> _showCreateGroup(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _CreateGroupSheet(),
    );

class _CreateGroupSheet extends ConsumerStatefulWidget {
  const _CreateGroupSheet();

  @override
  ConsumerState<_CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends ConsumerState<_CreateGroupSheet> {
  final _name = TextEditingController();
  final Set<String> _selected = {};
  bool _pending = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(friendsProvider(null));
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .78,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Create group',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                enabled: !_pending,
                decoration: const InputDecoration(labelText: 'Group name'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              Text(
                '${_selected.length} selected',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const SizedBox(height: 8),
              Expanded(
                child: friends.when(
                  data: (rows) => ListView.builder(
                    itemCount: rows.length,
                    itemBuilder: (context, index) {
                      final friend = rows[index];
                      return CheckboxListTile(
                        value: _selected.contains(friend.friendId),
                        title: Text(friend.resolvedName),
                        subtitle: friend.username == null
                            ? null
                            : Text('@${friend.username}'),
                        onChanged: _pending
                            ? null
                            : (selected) => setState(() {
                                selected == true
                                    ? _selected.add(friend.friendId)
                                    : _selected.remove(friend.friendId);
                              }),
                      );
                    },
                  ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stackTrace) =>
                      Center(child: Text(error.toString())),
                ),
              ),
              FilledButton(
                onPressed:
                    !_pending &&
                        _name.text.trim().isNotEmpty &&
                        _selected.length >= 2
                    ? _create
                    : null,
                child: _pending
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create group'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _create() async {
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      final conversation = await ref
          .read(conversationControllerProvider.notifier)
          .createGroup(name: _name.text, participantIds: _selected.toList());
      if (mounted) context.go('/chat/${conversation.id}');
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }
}

String _initials(String value) {
  final words = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .take(2);
  final result = words.map((word) => word[0].toUpperCase()).join();
  return result.isEmpty ? '?' : result;
}
