import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/controllers/session_controller.dart';
import '../../../friends/presentation/controllers/friends_controller.dart';
import '../../../friends/domain/entities/friend_models.dart';
import '../../domain/entities/conversation.dart';
import '../controllers/conversation_controller.dart';
import '../widgets/nickname_dialog.dart';

class GroupSettingsScreen extends ConsumerWidget {
  const GroupSettingsScreen({required this.conversationId, super.key});

  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(conversationControllerProvider);
    final conversation = state.value
        ?.where((item) => item.id == conversationId)
        .firstOrNull;
    final currentUserId = ref.watch(sessionControllerProvider).user?.id;
    final pending = ref.watch(conversationPendingActionsProvider);
    final conversationPending = pending.any(
      (key) => key.split(':').contains(conversationId),
    );
    if (conversation == null) {
      return const Scaffold(
        body: Center(child: Text('Group is no longer available')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Group settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Center(
            child: _GroupAvatar(
              participants: conversation.participants
                  .where((participant) => participant.userId != currentUserId)
                  .take(3)
                  .toList(growable: false),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            conversation.titleFor(currentUserId),
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          Text(
            '${conversation.participants.length} participants${conversation.currentUserAdmin ? ' · You are an admin' : ''}',
            textAlign: TextAlign.center,
          ),
          if (conversation.currentUserAdmin) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: conversationPending
                  ? null
                  : () => _addMember(context, ref, conversation),
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('Add member'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: conversationPending
                  ? null
                  : () => _rename(context, ref, conversation),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Rename group'),
            ),
          ],
          const SizedBox(height: 24),
          Text('Members', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...conversation.participants.map(
            (participant) => _MemberTile(
              conversation: conversation,
              participant: participant,
              currentUserId: currentUserId,
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: conversationPending
                ? null
                : () => _leave(context, ref, conversation),
            icon: const Icon(Icons.logout),
            label: const Text('Leave group'),
          ),
          if (conversation.currentUserAdmin) ...[
            const SizedBox(height: 8),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
                foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
              ),
              onPressed: conversationPending
                  ? null
                  : () => _delete(context, ref, conversation),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete group'),
            ),
          ],
        ],
      ),
    );
  }
}

class _GroupAvatar extends StatelessWidget {
  const _GroupAvatar({required this.participants});

  final List<ConversationParticipant> participants;

  @override
  Widget build(BuildContext context) {
    if (participants.isEmpty) {
      return const CircleAvatar(radius: 42, child: Icon(Icons.groups_outlined));
    }
    const positions = [
      Alignment.topCenter,
      Alignment.bottomLeft,
      Alignment.bottomRight,
    ];
    return SizedBox.square(
      dimension: 84,
      child: Stack(
        children: [
          for (var index = 0; index < participants.length; index++)
            Align(
              alignment: positions[index],
              child: _ParticipantAvatar(participant: participants[index]),
            ),
        ],
      ),
    );
  }
}

class _ParticipantAvatar extends StatelessWidget {
  const _ParticipantAvatar({required this.participant});

  final ConversationParticipant participant;

  @override
  Widget build(BuildContext context) {
    final url = participant.avatarUrl?.trim();
    return CircleAvatar(
      radius: 25,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      backgroundImage: url?.isNotEmpty == true ? NetworkImage(url!) : null,
      child: url?.isNotEmpty == true
          ? null
          : Text(_initials(participant.resolvedName)),
    );
  }
}

Future<void> _addMember(
  BuildContext context,
  WidgetRef ref,
  Conversation conversation,
) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => _AddMemberSheet(conversation: conversation),
  );
}

class _AddMemberSheet extends ConsumerStatefulWidget {
  const _AddMemberSheet({required this.conversation});

  final Conversation conversation;

  @override
  ConsumerState<_AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends ConsumerState<_AddMemberSheet> {
  String _query = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(userSearchProvider(_query));
    final currentUserId = ref.watch(sessionControllerProvider).user?.id;
    final existing = widget.conversation.participants
        .map((participant) => participant.userId)
        .toSet();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .65,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              Text('Add member', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search people',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 450), () {
                    if (mounted) setState(() => _query = value.trim());
                  });
                },
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _query.length < 2
                    ? const Center(child: Text('Type at least 2 characters.'))
                    : results.when(
                        data: (rows) => _results(
                          rows
                              .where(
                                (user) =>
                                    user.id != currentUserId &&
                                    !existing.contains(user.id),
                              )
                              .toList(growable: false),
                        ),
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (error, stackTrace) =>
                            Center(child: Text(error.toString())),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _results(List<UserSearchResult> rows) {
    if (rows.isEmpty) {
      return const Center(child: Text('No people available to add'));
    }
    return ListView.builder(
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final user = rows[index];
        final key = 'add:${widget.conversation.id}:${user.id}';
        final pending = ref.watch(
          conversationPendingActionsProvider.select(
            (actions) => actions.contains(key),
          ),
        );
        return ListTile(
          leading: CircleAvatar(child: Text(_initials(user.resolvedName))),
          title: Text(user.resolvedName),
          subtitle: Text('@${user.username}'),
          enabled: !pending,
          trailing: pending
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.person_add_outlined),
          onTap: pending ? null : () => _add(user.id),
        );
      },
    );
  }

  Future<void> _add(String userId) async {
    final success = await _run(
      context,
      () => ref
          .read(conversationControllerProvider.notifier)
          .addMember(widget.conversation.id, userId),
    );
    if (success && mounted) Navigator.pop(context);
  }
}

class _MemberTile extends ConsumerWidget {
  const _MemberTile({
    required this.conversation,
    required this.participant,
    required this.currentUserId,
  });

  final Conversation conversation;
  final ConversationParticipant participant;
  final String? currentUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canManage =
        conversation.currentUserAdmin && participant.userId != currentUserId;
    final pending = ref
        .watch(conversationPendingActionsProvider)
        .any(
          (key) =>
              key.contains(conversation.id) && key.contains(participant.userId),
        );
    return ListTile(
      leading: CircleAvatar(child: Text(_initials(participant.resolvedName))),
      title: Text(participant.resolvedName),
      subtitle: Text(
        '@${participant.username}${participant.admin ? ' · Admin' : ''}',
      ),
      onTap: () => context.push(
        participant.userId == currentUserId
            ? '/profile/me'
            : '/profile/${participant.userId}',
      ),
      trailing: PopupMenuButton<String>(
        enabled: !pending,
        tooltip: 'Actions for ${participant.resolvedName}',
        icon: pending
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : null,
        itemBuilder: (context) => [
          const PopupMenuItem(value: 'nickname', child: Text('Edit nickname')),
          if (canManage && !participant.admin)
            const PopupMenuItem(value: 'admin', child: Text('Make admin')),
          if (canManage)
            const PopupMenuItem(
              value: 'kick',
              child: Text('Remove from group'),
            ),
        ],
        onSelected: (action) => switch (action) {
          'nickname' => _nickname(context, ref),
          'admin' => _makeAdmin(context, ref),
          'kick' => _kick(context, ref),
          _ => null,
        },
      ),
    );
  }

  Future<void> _nickname(BuildContext context, WidgetRef ref) async {
    final nickname = await showDialog<String>(
      context: context,
      builder: (_) => NicknameDialog(participant: participant),
    );
    if (nickname == null || !context.mounted) return;
    await _run(
      context,
      () => ref
          .read(conversationControllerProvider.notifier)
          .updateNickname(conversation.id, participant.userId, nickname),
    );
  }

  Future<void> _makeAdmin(BuildContext context, WidgetRef ref) async {
    final confirmed = await _confirm(
      context,
      'Make ${participant.resolvedName} an admin?',
      'They will be able to rename the group and manage members.',
      'Make admin',
    );
    if (!confirmed || !context.mounted) return;
    await _run(
      context,
      () => ref
          .read(conversationControllerProvider.notifier)
          .makeAdmin(conversation.id, participant.userId),
    );
  }

  Future<void> _kick(BuildContext context, WidgetRef ref) async {
    final confirmed = await _confirm(
      context,
      'Remove ${participant.resolvedName}?',
      'They will lose access to this group. Their previous messages remain identifiable.',
      'Remove',
    );
    if (!confirmed || !context.mounted) return;
    await _run(
      context,
      () => ref
          .read(conversationControllerProvider.notifier)
          .kickMember(conversation.id, participant.userId),
    );
  }
}

Future<void> _rename(
  BuildContext context,
  WidgetRef ref,
  Conversation conversation,
) async {
  final controller = TextEditingController(text: conversation.name ?? '');
  final original = (conversation.name ?? '').trim();
  final name = await showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final value = controller.text.trim();
        final canSave = value.isNotEmpty && value != original;
        return AlertDialog(
          title: const Text('Rename group'),
          content: TextField(
            controller: controller,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Group name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: canSave
                  ? () => Navigator.pop(context, controller.text.trim())
                  : null,
              child: const Text('Save'),
            ),
          ],
        );
      },
    ),
  );
  controller.dispose();
  if (name == null || name.isEmpty || name == conversation.name) return;
  if (!context.mounted) return;
  await _run(
    context,
    () => ref
        .read(conversationControllerProvider.notifier)
        .renameGroup(conversation.id, name),
  );
}

Future<void> _leave(
  BuildContext context,
  WidgetRef ref,
  Conversation conversation,
) async {
  final confirmed = await _confirm(
    context,
    'Leave ${conversation.name ?? 'this group'}?',
    'You will lose access to this conversation.',
    'Leave',
  );
  if (!confirmed || !context.mounted) return;
  final success = await _run(
    context,
    () => ref
        .read(conversationControllerProvider.notifier)
        .leaveGroup(conversation.id),
  );
  if (success && context.mounted) context.go('/chat');
}

Future<void> _delete(
  BuildContext context,
  WidgetRef ref,
  Conversation conversation,
) async {
  final confirmed = await _confirm(
    context,
    'Delete ${conversation.name ?? 'this group'}?',
    'This removes the group for its members and cannot be undone.',
    'Delete group',
  );
  if (!confirmed || !context.mounted) return;
  final success = await _run(
    context,
    () => ref
        .read(conversationControllerProvider.notifier)
        .deleteGroup(conversation.id),
  );
  if (success && context.mounted) context.go('/chat');
}

Future<bool> _confirm(
  BuildContext context,
  String title,
  String message,
  String action,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;

Future<bool> _run(BuildContext context, Future<void> Function() action) async {
  try {
    await action();
    return true;
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
    return false;
  }
}

String _initials(String value) {
  final words = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .take(2);
  return words.map((word) => word[0].toUpperCase()).join();
}
