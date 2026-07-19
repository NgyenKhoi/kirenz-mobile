import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/controllers/session_controller.dart';
import '../../../friends/domain/entities/friend_models.dart';
import '../../../friends/presentation/controllers/friends_controller.dart';
import '../../../privacy/data/repositories/privacy_repository.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/realtime_chat.dart';
import '../controllers/conversation_controller.dart';
import '../controllers/chat_realtime_controller.dart';

class ChatScreen extends ConsumerWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(conversationControllerProvider);
    final cachedAt = ref.watch(conversationCacheStatusProvider);
    final currentUserId = ref.watch(sessionControllerProvider).user?.id;
    final realtime = ref.watch(chatRealtimeControllerProvider);
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
        skipError: true,
        data: (rows) => Column(
          children: [
            if (realtime.status == ChatConnectionStatus.reconnecting ||
                realtime.status == ChatConnectionStatus.disconnected)
              const _RealtimeListNotice(message: 'Reconnecting…'),
            if (realtime.status == ChatConnectionStatus.failed)
              _RealtimeListNotice(
                message: 'Live updates unavailable',
                onRetry: () =>
                    ref.read(chatRealtimeControllerProvider.notifier).retry(),
              ),
            if (cachedAt != null) const _OfflineNotice(),
            if (conversations.hasError) const _RefreshErrorNotice(),
            Expanded(
              child: RefreshIndicator(
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
                          Center(
                            child: Text('Start a message or create a group.'),
                          ),
                        ],
                      )
                    : ListView.separated(
                        itemCount: rows.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) => _ConversationTile(
                          conversation: rows[index],
                          currentUserId: currentUserId,
                          presence: realtime.presence,
                        ),
                      ),
              ),
            ),
          ],
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

class _RealtimeListNotice extends StatelessWidget {
  const _RealtimeListNotice({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerHigh,
    child: ListTile(
      dense: true,
      leading: const Icon(Icons.sync_outlined),
      title: Text(message),
      trailing: onRetry == null
          ? null
          : TextButton(onPressed: onRetry, child: const Text('Retry')),
    ),
  );
}

class _OfflineNotice extends StatelessWidget {
  const _OfflineNotice();

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.secondaryContainer,
    child: const ListTile(
      dense: true,
      leading: Icon(Icons.cloud_off_outlined),
      title: Text('Showing saved conversations'),
      subtitle: Text('Pull to reconnect and refresh.'),
    ),
  );
}

class _RefreshErrorNotice extends StatelessWidget {
  const _RefreshErrorNotice();

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.errorContainer,
    child: const ListTile(
      dense: true,
      leading: Icon(Icons.sync_problem_outlined),
      title: Text('Could not refresh conversations'),
      subtitle: Text('Showing the last available list.'),
    ),
  );
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.currentUserId,
    required this.presence,
  });

  final Conversation conversation;
  final String? currentUserId;
  final Map<String, UserPresence> presence;

  @override
  Widget build(BuildContext context) {
    final title = conversation.titleFor(currentUserId);
    final otherUser = conversation.type == ConversationType.direct
        ? conversation.participants
              .where((person) => person.userId != currentUserId)
              .firstOrNull
        : null;
    final isOnline =
        otherUser != null && presence[otherUser.userId]?.isOnline == true;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Semantics(
        label: isOnline ? '$title, Online' : title,
        child: Badge(
          isLabelVisible: isOnline,
          backgroundColor: Colors.green,
          smallSize: 10,
          child: _ConversationAvatar(
            conversation: conversation,
            currentUserId: currentUserId,
            title: title,
          ),
        ),
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        conversation.previewFor(currentUserId),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formatConversationTime(
              conversation.lastMessage?.sentAt ?? conversation.updatedAt,
            ),
            style: Theme.of(context).textTheme.labelSmall,
          ),
          if (conversation.unreadCount > 0) ...[
            const SizedBox(height: 4),
            Badge(label: Text('${conversation.unreadCount}')),
          ],
        ],
      ),
      onTap: () => context.push('/chat/${conversation.id}'),
    );
  }
}

class _ConversationAvatar extends StatelessWidget {
  const _ConversationAvatar({
    required this.conversation,
    required this.currentUserId,
    required this.title,
  });

  final Conversation conversation;
  final String? currentUserId;
  final String title;

  @override
  Widget build(BuildContext context) {
    final people = conversation.participants
        .where((person) => person.userId != currentUserId)
        .take(2)
        .toList();
    if (conversation.type == ConversationType.direct) {
      return _PersonAvatar(person: people.firstOrNull, fallback: title);
    }
    if (people.isEmpty) return CircleAvatar(child: Text(_initials(title)));
    return SizedBox.square(
      dimension: 40,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: _PersonAvatar(
              person: people.first,
              fallback: title,
              radius: 14,
            ),
          ),
          if (people.length > 1)
            Align(
              alignment: Alignment.bottomRight,
              child: _PersonAvatar(
                person: people[1],
                fallback: title,
                radius: 14,
              ),
            ),
        ],
      ),
    );
  }
}

class _PersonAvatar extends StatelessWidget {
  const _PersonAvatar({
    required this.person,
    required this.fallback,
    this.radius,
  });

  final ConversationParticipant? person;
  final String fallback;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final url = person?.avatarUrl?.trim();
    return CircleAvatar(
      radius: radius,
      backgroundImage: url?.isNotEmpty == true ? NetworkImage(url!) : null,
      child: url?.isNotEmpty == true
          ? null
          : Text(_initials(person?.resolvedName ?? fallback)),
    );
  }
}

String _formatConversationTime(DateTime? value) {
  if (value == null) return '';
  final local = value.toLocal();
  final now = DateTime.now();
  if (local.year == now.year &&
      local.month == now.month &&
      local.day == now.day) {
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
  return '${local.day}/${local.month}';
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
  Timer? _debounce;
  String? _pendingId;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

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
                onChanged: (value) {
                  _debounce?.cancel();
                  setState(() => _error = null);
                  _debounce = Timer(const Duration(milliseconds: 450), () {
                    if (mounted) setState(() => _query = value.trim());
                  });
                },
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
      data: (users) {
        final currentUserId = ref.read(sessionControllerProvider).user?.id;
        final availableUsers = users
            .where(
              (user) =>
                  user.relationshipStatus != RelationshipStatus.self &&
                  user.id != currentUserId,
            )
            .toList(growable: false);
        return availableUsers.isEmpty
            ? const Center(child: Text('No people found'))
            : ListView.builder(
                itemCount: availableUsers.length,
                itemBuilder: (context, index) {
                  final user = availableUsers[index];
                  final unavailable =
                      user.relationshipStatus == RelationshipStatus.blocked ||
                      user.relationshipStatus ==
                          RelationshipStatus.blockedByTarget ||
                      user.allowDirectMessages == false;
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(_initials(user.resolvedName)),
                    ),
                    title: Text(user.resolvedName),
                    subtitle: Text(
                      user.allowDirectMessages == false
                          ? 'Direct messages are disabled'
                          : unavailable
                          ? 'Messaging unavailable'
                          : '@${user.username}',
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
              );
      },
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
      final allowed = await ref
          .read(privacyRepositoryProvider)
          .canSendDirectMessage(userId);
      if (!allowed) {
        if (mounted) {
          setState(() {
            _error = 'This person only accepts messages from friends.';
          });
        }
        return;
      }
      final conversation = await ref
          .read(conversationControllerProvider.notifier)
          .getOrCreateDirect(userId);
      if (mounted) {
        final router = GoRouter.of(context);
        Navigator.of(context).pop();
        router.go('/chat/${conversation.id}');
      }
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
  final Map<String, UserSearchResult> _selected = {};
  String _query = '';
  Timer? _debounce;
  bool _pending = false;
  String? _error;
  bool _allowPop = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(userSearchProvider(_query));
    final currentUserId = ref.watch(sessionControllerProvider).user?.id;
    return PopScope(
      canPop: _allowPop || !_hasDraft,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _allowPop || !_hasDraft) return;
        final discard = await _confirmDiscard();
        if (!discard || !mounted) return;
        setState(() => _allowPop = true);
        Navigator.of(this.context).pop();
      },
      child: SafeArea(
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
                TextField(
                  enabled: !_pending,
                  decoration: const InputDecoration(
                    labelText: 'Search people',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) {
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 450), () {
                      if (mounted) setState(() => _query = value.trim());
                    });
                  },
                ),
                if (_selected.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _selected.values
                        .map(
                          (user) => InputChip(
                            label: Text(user.resolvedName),
                            onDeleted: _pending
                                ? null
                                : () =>
                                      setState(() => _selected.remove(user.id)),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  '${_selected.length} selected',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                const SizedBox(height: 8),
                Expanded(
                  child: _query.length < 2
                      ? const Center(child: Text('Type at least 2 characters.'))
                      : results.when(
                          data: (rows) {
                            final available = rows
                                .where((user) => user.id != currentUserId)
                                .toList(growable: false);
                            if (available.isEmpty) {
                              return const Center(
                                child: Text('No people found'),
                              );
                            }
                            return ListView.builder(
                              itemCount: available.length,
                              itemBuilder: (context, index) {
                                final user = available[index];
                                return CheckboxListTile(
                                  value: _selected.containsKey(user.id),
                                  title: Text(user.resolvedName),
                                  subtitle: Text('@${user.username}'),
                                  onChanged: _pending
                                      ? null
                                      : (selected) => setState(() {
                                          selected == true
                                              ? _selected[user.id] = user
                                              : _selected.remove(user.id);
                                        }),
                                );
                              },
                            );
                          },
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
      ),
    );
  }

  bool get _hasDraft => _name.text.trim().isNotEmpty || _selected.isNotEmpty;

  Future<bool> _confirmDiscard() async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard group draft?'),
          content: const Text(
            'The group name and selected members will be lost.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep editing'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _create() async {
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      final conversation = await ref
          .read(conversationControllerProvider.notifier)
          .createGroup(
            name: _name.text,
            participantIds: _selected.keys.toList(growable: false),
          );
      if (mounted) {
        final router = GoRouter.of(context);
        setState(() => _allowPop = true);
        Navigator.of(context).pop();
        router.go('/chat/${conversation.id}');
      }
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
