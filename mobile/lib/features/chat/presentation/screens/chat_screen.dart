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
import '../../../../shared/widgets/user_avatar.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  bool _searching = false;
  bool _showFab = true;
  double _lastOffset = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_handleScroll)
      ..dispose();
    _search.dispose();
    super.dispose();
  }

  void _handleScroll() {
    final offset = _scroll.offset;
    final next = offset <= 24 || offset < _lastOffset;
    if (next != _showFab) setState(() => _showFab = next);
    _lastOffset = offset;
  }

  @override
  Widget build(BuildContext context) {
    final conversations = ref.watch(conversationControllerProvider);
    final cachedAt = ref.watch(conversationCacheStatusProvider);
    final currentUser = ref.watch(sessionControllerProvider).user;
    final currentUserId = currentUser?.id;
    final realtime = ref.watch(chatRealtimeControllerProvider);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        titleSpacing: 16,
        title: AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 180),
          child: _searching
              ? TextField(
                  key: const ValueKey('chat-search'),
                  controller: _search,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: 'Search conversations',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onChanged: (_) => setState(() {}),
                )
              : Row(
                  key: const ValueKey('chat-title'),
                  children: [
                    KirenzUserAvatar(
                      name: currentUser?.displayName ?? 'Kirenz user',
                      imageUrl: currentUser?.avatarUrl,
                      radius: 21,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Chats',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
        ),
        actions: [
          IconButton(
            tooltip: _searching ? 'Close search' : 'Search conversations',
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) _search.clear();
            }),
            icon: Icon(_searching ? Icons.close_rounded : Icons.search_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: AnimatedScale(
        scale: _showFab ? 1 : 0,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: FloatingActionButton.extended(
          tooltip: 'New message',
          onPressed: () => _showComposeActions(context),
          icon: const Icon(Icons.edit_rounded),
          label: const Text('New message'),
        ),
      ),
      body: conversations.when(
        skipLoadingOnRefresh: true,
        skipError: true,
        data: (rows) {
          final query = _search.text.trim().toLowerCase();
          final visible = query.isEmpty
              ? rows
              : rows
                    .where(
                      (conversation) =>
                          conversation
                              .titleFor(currentUserId)
                              .toLowerCase()
                              .contains(query) ||
                          conversation
                              .previewFor(currentUserId)
                              .toLowerCase()
                              .contains(query),
                    )
                    .toList(growable: false);
          return Column(
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
                  onRefresh: () => ref
                      .read(conversationControllerProvider.notifier)
                      .refresh(),
                  child: visible.isEmpty
                      ? ListView(
                          controller: _scroll,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          children: [
                            const SizedBox(height: 144),
                            Icon(
                              query.isEmpty
                                  ? Icons.forum_outlined
                                  : Icons.search_off_rounded,
                              size: 56,
                            ),
                            const SizedBox(height: 16),
                            Center(
                              child: Text(
                                query.isEmpty
                                    ? 'No conversations yet'
                                    : 'No conversations found',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Center(
                              child: Text(
                                query.isEmpty
                                    ? 'Start a message or create a group.'
                                    : 'Try a different name or message.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
                          itemCount: visible.length,
                          itemBuilder: (context, index) => _ConversationTile(
                            conversation: visible[index],
                            currentUserId: currentUserId,
                            presence: realtime.presence,
                          ),
                        ),
                ),
              ),
            ],
          );
        },
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
    final unread = conversation.unreadCount > 0;
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: unread ? colors.surfaceContainerLowest : Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/chat/${conversation.id}'),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Semantics(
                  label: isOnline ? '$title, Online' : title,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _ConversationAvatar(
                        conversation: conversation,
                        currentUserId: currentUserId,
                        title: title,
                        size: 56,
                      ),
                      if (isOnline)
                        Positioned(
                          right: 1,
                          bottom: 1,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0xFF22C55E),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: colors.surfaceContainerLowest,
                                width: 2,
                              ),
                            ),
                            child: const SizedBox.square(dimension: 13),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: unread
                                        ? FontWeight.w800
                                        : FontWeight.w700,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatConversationTime(
                              conversation.lastMessage?.sentAt ??
                                  conversation.updatedAt,
                            ),
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: colors.outline),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              conversation.previewFor(currentUserId),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: unread
                                        ? colors.onSurfaceVariant
                                        : colors.outline,
                                    fontWeight: unread
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                  ),
                            ),
                          ),
                          if (unread) ...[
                            const SizedBox(width: 10),
                            Badge(
                              label: Text(
                                conversation.unreadCount > 99
                                    ? '99+'
                                    : '${conversation.unreadCount}',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConversationAvatar extends StatelessWidget {
  const _ConversationAvatar({
    required this.conversation,
    required this.currentUserId,
    required this.title,
    this.size = 40,
  });

  final Conversation conversation;
  final String? currentUserId;
  final String title;
  final double size;

  @override
  Widget build(BuildContext context) {
    final people = conversation.participants
        .where((person) => person.userId != currentUserId)
        .take(2)
        .toList();
    if (conversation.type == ConversationType.direct) {
      return _PersonAvatar(
        person: people.firstOrNull,
        fallback: title,
        radius: size / 2,
      );
    }
    if (people.isEmpty) {
      return CircleAvatar(radius: size / 2, child: Text(_initials(title)));
    }
    return SizedBox.square(
      dimension: size,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: _PersonAvatar(
              person: people.first,
              fallback: title,
              radius: size * .34,
            ),
          ),
          if (people.length > 1)
            Align(
              alignment: Alignment.bottomRight,
              child: _PersonAvatar(
                person: people[1],
                fallback: title,
                radius: size * .34,
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
      itemCount: 7,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Container(
          height: 80,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: index.isEven
                ? Theme.of(context).colorScheme.surfaceContainerLowest
                : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              CircleAvatar(radius: 28, backgroundColor: color),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FractionallySizedBox(
                      widthFactor: .55,
                      child: Container(height: 14, color: color),
                    ),
                    const SizedBox(height: 9),
                    FractionallySizedBox(
                      widthFactor: .86,
                      child: Container(height: 12, color: color),
                    ),
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

Future<void> _showComposeActions(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                child: Text(
                  'Start a conversation',
                  style: Theme.of(
                    sheetContext,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.person_add_alt_1_rounded),
                title: const Text('New direct message'),
                subtitle: const Text('Find someone and start chatting'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showDirectSearch(context);
                },
              ),
              const SizedBox(height: 4),
              ListTile(
                leading: const Icon(Icons.group_add_rounded),
                title: const Text('Create a group'),
                subtitle: const Text('Bring several people together'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showCreateGroup(context);
                },
              ),
            ],
          ),
        ),
      ),
    );

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
