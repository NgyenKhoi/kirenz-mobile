import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../friends/domain/entities/friend_models.dart';
import '../../../friends/presentation/controllers/friends_controller.dart';
import '../../../posts/domain/entities/post.dart';
import '../../data/repositories/discussion_repository.dart';
import '../../domain/entities/comment.dart';
import '../controllers/comment_controller.dart';

class DiscussionSection extends ConsumerWidget {
  const DiscussionSection({
    required this.postId,
    required this.currentUserId,
    super.key,
  });

  final String postId;
  final String? currentUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(commentControllerProvider(postId));
    final controller = ref.read(commentControllerProvider(postId).notifier);
    if (state.loading && state.comments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.error != null && state.comments.isEmpty) {
      return _DiscussionError(
        message: state.error!,
        onRetry: () => controller.load(),
      );
    }
    final roots = state.comments
        .where((comment) => comment.parentCommentId == null)
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.isCached)
          Material(
            color: Theme.of(context).colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(14),
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.cloud_off_outlined),
              title: const Text('Showing saved comments while offline.'),
              trailing: TextButton(
                onPressed: () => controller.load(refresh: true),
                child: const Text('Refresh'),
              ),
            ),
          ),
        Row(
          children: [
            Text('Comments', style: Theme.of(context).textTheme.titleLarge),
            const Spacer(),
            if (state.refreshing)
              const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              IconButton(
                tooltip: 'Refresh comments',
                onPressed: () => controller.load(refresh: true),
                icon: const Icon(Icons.refresh),
              ),
          ],
        ),
        if (state.error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              state.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (roots.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(child: Text('No comments yet')),
          )
        else
          for (final root in roots) ...[
            _CommentTile(
              comment: root,
              currentUserId: currentUserId,
              pending: state.isCached || state.pendingIds.contains(root.id),
              onReply: () => controller.replyTo(root),
              onEdit: (content) => controller.update(root, content),
              onDelete: () => controller.delete(root),
              onReact: (reaction) => controller.react(root, reaction),
            ),
            for (final reply in _repliesForRoot(state.comments, root.id))
              Padding(
                padding: const EdgeInsets.only(left: 28),
                child: _CommentTile(
                  comment: reply,
                  currentUserId: currentUserId,
                  pending:
                      state.isCached || state.pendingIds.contains(reply.id),
                  replyingTo: _parentName(state.comments, reply),
                  onReply: () => controller.replyTo(reply),
                  onEdit: (content) => controller.update(reply, content),
                  onDelete: () => controller.delete(reply),
                  onReact: (reaction) => controller.react(reply, reaction),
                ),
              ),
          ],
      ],
    );
  }
}

class CommentComposer extends ConsumerStatefulWidget {
  const CommentComposer({required this.postId, super.key});

  final String postId;

  @override
  ConsumerState<CommentComposer> createState() => _CommentComposerState();
}

class _CommentComposerState extends ConsumerState<CommentComposer> {
  final _text = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<CommentState>(commentControllerProvider(widget.postId), (
      previous,
      next,
    ) {
      if (previous?.replyTarget?.id != next.replyTarget?.id &&
          next.replyTarget != null) {
        _focus.requestFocus();
      }
    });
    final state = ref.watch(commentControllerProvider(widget.postId));
    final friends = ref.watch(friendsProvider(null));
    final controller = ref.read(
      commentControllerProvider(widget.postId).notifier,
    );
    final selectedFriends = friends.valueOrNull
            ?.where((friend) => state.taggedUserIds.contains(friend.friendId))
            .toList(growable: false) ??
        const <Friend>[];
    if (_text.text != state.draft) {
      _text.value = _text.value.copyWith(
        text: state.draft,
        selection: TextSelection.collapsed(offset: state.draft.length),
      );
    }
    return Material(
      elevation: 8,
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (state.replyTarget != null)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Replying to ${state.replyTarget!.author.resolvedName}',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cancel reply',
                      onPressed: controller.cancelReply,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              if (selectedFriends.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final friend in selectedFriends)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: InputChip(
                              avatar: CircleAvatar(
                                backgroundImage:
                                    friend.avatarUrl?.isNotEmpty == true
                                    ? CachedNetworkImageProvider(
                                        friend.avatarUrl!,
                                      )
                                    : null,
                                child: friend.avatarUrl?.isNotEmpty == true
                                    ? null
                                    : Text(friend.resolvedName[0].toUpperCase()),
                              ),
                              label: Text(friend.resolvedName),
                              tooltip: 'Remove ${friend.resolvedName}',
                              onDeleted: state.sending || state.isCached
                                  ? null
                                  : () => controller.toggleTaggedUser(
                                      friend.friendId,
                                    ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _text,
                      focusNode: _focus,
                      enabled: !state.sending && !state.isCached,
                      minLines: 1,
                      maxLines: 5,
                      onChanged: controller.updateDraft,
                      decoration: InputDecoration(
                        hintText: state.replyTarget == null
                            ? 'Write a comment...'
                            : 'Write a reply...',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: state.taggedUserIds.isEmpty
                        ? 'Tag friends'
                        : 'Tag friends (${state.taggedUserIds.length} selected)',
                    onPressed: state.sending || state.isCached
                        ? null
                        : () => showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            useSafeArea: true,
                            builder: (_) => _CommentTagSheet(
                              postId: widget.postId,
                            ),
                          ),
                    icon: Badge.count(
                      count: state.taggedUserIds.length,
                      isLabelVisible: state.taggedUserIds.isNotEmpty,
                      child: const Icon(Icons.alternate_email),
                    ),
                  ),
                  IconButton.filled(
                    tooltip: 'Send comment',
                    onPressed:
                        state.sending ||
                            state.isCached ||
                            state.draft.trim().isEmpty
                        ? null
                        : () async {
                            if (await controller.send()) _text.clear();
                          },
                    icon: state.sending
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
              if (state.composerError != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      state.composerError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                )
              else if (state.isCached)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text('Reconnect to comment or react.'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommentTagSheet extends ConsumerStatefulWidget {
  const _CommentTagSheet({required this.postId});

  final String postId;

  @override
  ConsumerState<_CommentTagSheet> createState() => _CommentTagSheetState();
}

class _CommentTagSheetState extends ConsumerState<_CommentTagSheet> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(friendsProvider(null));
    final selectedIds = ref.watch(
      commentControllerProvider(
        widget.postId,
      ).select((state) => state.taggedUserIds),
    );
    final controller = ref.read(
      commentControllerProvider(widget.postId).notifier,
    );
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .72,
      child: Column(
        children: [
          ListTile(
            title: const Text('Tag friends'),
            subtitle: Text('${selectedIds.length} selected'),
            trailing: TextButton(
              onPressed: () => context.pop(),
              child: const Text('Done'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _search,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: (value) => setState(() => _query = value.trim()),
              decoration: InputDecoration(
                hintText: 'Search your friends',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
          ),
          Expanded(
            child: friends.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _DiscussionError(
                message: error.toString(),
                onRetry: () => ref.invalidate(friendsProvider(null)),
              ),
              data: (items) {
                final normalized = _query.toLowerCase();
                final visible = items.where((friend) {
                  if (normalized.isEmpty) return true;
                  return friend.resolvedName.toLowerCase().contains(
                            normalized,
                          ) ||
                      (friend.username?.toLowerCase().contains(normalized) ??
                          false);
                }).toList(growable: false)
                  ..sort((left, right) {
                    final leftSelected = selectedIds.contains(left.friendId);
                    final rightSelected = selectedIds.contains(right.friendId);
                    if (leftSelected != rightSelected) {
                      return leftSelected ? -1 : 1;
                    }
                    return left.resolvedName.compareTo(right.resolvedName);
                  });
                if (visible.isEmpty) {
                  return Center(
                    child: Text(
                      normalized.isEmpty
                          ? 'No friends available to tag'
                          : 'No friends match your search',
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final friend = visible[index];
                    final selected = selectedIds.contains(friend.friendId);
                    return CheckboxListTile(
                      value: selected,
                      onChanged: (_) =>
                          controller.toggleTaggedUser(friend.friendId),
                      secondary: CircleAvatar(
                        backgroundImage: friend.avatarUrl?.isNotEmpty == true
                            ? CachedNetworkImageProvider(friend.avatarUrl!)
                            : null,
                        child: friend.avatarUrl?.isNotEmpty == true
                            ? null
                            : Text(friend.resolvedName[0].toUpperCase()),
                      ),
                      title: Text(friend.resolvedName),
                      subtitle: friend.username?.isNotEmpty == true
                          ? Text('@${friend.username}')
                          : null,
                      controlAffinity: ListTileControlAffinity.trailing,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.currentUserId,
    required this.pending,
    required this.onReply,
    required this.onEdit,
    required this.onDelete,
    required this.onReact,
    this.replyingTo,
  });

  final PostComment comment;
  final String? currentUserId;
  final bool pending;
  final VoidCallback onReply;
  final Future<bool> Function(String content) onEdit;
  final Future<bool> Function() onDelete;
  final Future<bool> Function(ReactionType? reaction) onReact;
  final String? replyingTo;

  @override
  Widget build(BuildContext context) {
    final current = comment.reactionSummary.currentUserReaction;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: comment.author.id.isEmpty
                ? null
                : () => context.push('/profile/${comment.author.id}'),
            child: CircleAvatar(
              radius: 18,
              backgroundImage: comment.author.avatarUrl?.isNotEmpty == true
                  ? CachedNetworkImageProvider(comment.author.avatarUrl!)
                  : null,
              child: comment.author.avatarUrl?.isNotEmpty == true
                  ? null
                  : Text(comment.author.resolvedName[0].toUpperCase()),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              comment.author.resolvedName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (comment.author.id == currentUserId)
                            PopupMenuButton<String>(
                              enabled: !pending,
                              tooltip: 'Comment actions',
                              onSelected: (value) {
                                if (value == 'edit') _edit(context);
                                if (value == 'delete') _delete(context);
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete'),
                                ),
                              ],
                            ),
                        ],
                      ),
                      if (replyingTo != null)
                        Text(
                          'Replying to $replyingTo',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      Text(comment.content),
                      if (pending) const LinearProgressIndicator(),
                    ],
                  ),
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: pending ? null : onReply,
                      child: const Text('Reply'),
                    ),
                    GestureDetector(
                      onLongPress: pending
                          ? null
                          : () => _pickReaction(context),
                      child: TextButton(
                        onPressed: pending
                            ? null
                            : () => onReact(current ?? ReactionType.like),
                        child: Text(
                          current == null
                              ? 'React'
                              : '${reactionEmoji(current)} ${reactionLabel(current)}',
                        ),
                      ),
                    ),
                    if (comment.reactionSummary.totalCount > 0)
                      TextButton(
                        onPressed: () => showReactionUsersSheet(
                          context,
                          targetId: comment.id,
                          comment: true,
                          summary: comment.reactionSummary,
                        ),
                        child: Text('${comment.reactionSummary.totalCount}'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickReaction(BuildContext context) async {
    final selected = await showReactionPicker(context);
    if (selected != null) await onReact(selected);
  }

  Future<void> _edit(BuildContext context) async {
    final text = TextEditingController(text: comment.content);
    var saving = false;
    String? error;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit comment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: text, minLines: 2, maxLines: 6),
              if (error != null) Text(error!),
            ],
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => dialogContext.pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (text.text.trim().isEmpty) return;
                      setState(() => saving = true);
                      if (await onEdit(text.text)) {
                        if (dialogContext.mounted) dialogContext.pop();
                      } else {
                        setState(() {
                          saving = false;
                          error = 'Could not save. Your edit is still here.';
                        });
                      }
                    },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    text.dispose();
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete comment?'),
        content: const Text('Replies under this comment will also be removed.'),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => context.pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) await onDelete();
  }
}

Future<ReactionType?> showReactionPicker(BuildContext context) {
  final reduceMotion = MediaQuery.disableAnimationsOf(context);
  return showModalBottomSheet<ReactionType>(
    context: context,
    sheetAnimationStyle: reduceMotion
        ? AnimationStyle.noAnimation
        : const AnimationStyle(
            duration: Duration(milliseconds: 180),
            reverseDuration: Duration(milliseconds: 140),
          ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: ReactionType.values
              .map(
                (type) => _ReactionPickerOption(
                  type: type,
                  reduceMotion: reduceMotion,
                ),
              )
              .toList(growable: false),
        ),
      ),
    ),
  );
}

class _ReactionPickerOption extends StatelessWidget {
  const _ReactionPickerOption({
    required this.type,
    required this.reduceMotion,
  });

  final ReactionType type;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: reduceMotion ? 1 : .72, end: 1),
    duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 240),
    curve: reduceMotion ? Curves.linear : Curves.easeOutBack,
    builder: (context, value, child) => Opacity(
      opacity: value.clamp(0, 1),
      child: Transform.scale(scale: value, child: child),
    ),
    child: Semantics(
      button: true,
      label: 'React with ${reactionLabel(type)}',
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => context.pop(type),
        child: SizedBox.square(
          dimension: 52,
          child: Center(
            child: Text(
              reactionEmoji(type),
              style: const TextStyle(fontSize: 28),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> showReactionUsersSheet(
  BuildContext context, {
  required String targetId,
  required bool comment,
  required PostReactionSummary summary,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _ReactionUsersSheet(
      targetId: targetId,
      comment: comment,
      summary: summary,
    ),
  );
}

class _ReactionUsersSheet extends ConsumerStatefulWidget {
  const _ReactionUsersSheet({
    required this.targetId,
    required this.comment,
    required this.summary,
  });

  final String targetId;
  final bool comment;
  final PostReactionSummary summary;

  @override
  ConsumerState<_ReactionUsersSheet> createState() =>
      _ReactionUsersSheetState();
}

class _ReactionUsersSheetState extends ConsumerState<_ReactionUsersSheet> {
  ReactionType? _filter;
  late Future<List<ReactionUser>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = ref
        .read(discussionRepositoryProvider)
        .getReactionUsers(targetId: widget.targetId, comment: widget.comment);
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * .72,
    child: Column(
      children: [
        ListTile(
          title: Text('${widget.summary.totalCount} reactions'),
          trailing: IconButton(
            tooltip: 'Close',
            onPressed: () => context.pop(),
            icon: const Icon(Icons.close),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('All'),
                selected: _filter == null,
                onSelected: (_) => setState(() => _filter = null),
              ),
              const SizedBox(width: 6),
              for (final entry in widget.summary.breakdown.entries)
                if (entry.value > 0) ...[
                  ChoiceChip(
                    label: Text('${reactionEmoji(entry.key)} ${entry.value}'),
                    selected: _filter == entry.key,
                    onSelected: (_) => setState(() => _filter = entry.key),
                  ),
                  const SizedBox(width: 6),
                ],
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<ReactionUser>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _DiscussionError(
                  message: snapshot.error.toString(),
                  onRetry: () => setState(_load),
                );
              }
              final users = (snapshot.data ?? const [])
                  .where((user) => _filter == null || user.type == _filter)
                  .toList(growable: false);
              if (users.isEmpty) {
                return const Center(child: Text('No reactions in this filter'));
              }
              return ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: user.avatarUrl?.isNotEmpty == true
                          ? CachedNetworkImageProvider(user.avatarUrl!)
                          : null,
                      child: user.avatarUrl?.isNotEmpty == true
                          ? null
                          : Text(user.resolvedName[0].toUpperCase()),
                    ),
                    title: Text(user.resolvedName),
                    subtitle: user.username?.isNotEmpty == true
                        ? Text('@${user.username}')
                        : null,
                    trailing: Text(
                      user.type == null ? '' : reactionEmoji(user.type!),
                    ),
                    onTap: user.userId.isEmpty
                        ? null
                        : () => context.push('/profile/${user.userId}'),
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
  );
}

class _DiscussionError extends StatelessWidget {
  const _DiscussionError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 10),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}

List<PostComment> _repliesForRoot(List<PostComment> comments, String rootId) {
  return comments
      .where(
        (comment) =>
            comment.parentCommentId != null &&
            _rootId(comments, comment) == rootId,
      )
      .toList(growable: false);
}

String? _rootId(List<PostComment> comments, PostComment comment) {
  var parentId = comment.parentCommentId;
  final visited = <String>{comment.id};
  while (parentId != null && visited.add(parentId)) {
    final parent = comments.where((item) => item.id == parentId).firstOrNull;
    if (parent == null) return null;
    if (parent.parentCommentId == null) return parent.id;
    parentId = parent.parentCommentId;
  }
  return null;
}

String? _parentName(List<PostComment> comments, PostComment comment) => comments
    .where((item) => item.id == comment.parentCommentId)
    .firstOrNull
    ?.author
    .resolvedName;

String reactionEmoji(ReactionType type) => switch (type) {
  ReactionType.like => '👍',
  ReactionType.love => '❤️',
  ReactionType.haha => '😆',
  ReactionType.wow => '😮',
  ReactionType.sad => '😢',
  ReactionType.angry => '😡',
};

String reactionLabel(ReactionType type) => switch (type) {
  ReactionType.like => 'Like',
  ReactionType.love => 'Love',
  ReactionType.haha => 'Haha',
  ReactionType.wow => 'Wow',
  ReactionType.sad => 'Sad',
  ReactionType.angry => 'Angry',
};
