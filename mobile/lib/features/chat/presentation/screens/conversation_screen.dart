import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/controllers/session_controller.dart';
import '../../../blocks/domain/entities/block_models.dart';
import '../../../blocks/presentation/controllers/block_controller.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../controllers/conversation_controller.dart';
import '../controllers/chat_realtime_controller.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/chat_message.dart';
import '../../../privacy/data/repositories/privacy_repository.dart';
import '../controllers/message_controller.dart';
import '../widgets/nickname_dialog.dart';
import '../../../../shared/widgets/media_viewer.dart';

final directMessagePermissionProvider = FutureProvider.family<bool, String>((
  ref,
  receiverId,
) {
  return ref.watch(privacyRepositoryProvider).canSendDirectMessage(receiverId);
});

final sharedGroupBlockedParticipantsProvider = FutureProvider.autoDispose
    .family<List<ConversationParticipant>, Conversation>((ref, conversation) {
      if (conversation.type != ConversationType.group) {
        return const <ConversationParticipant>[];
      }
      return Future.wait(
        conversation.participants.map((participant) async {
          try {
            final status = await ref.watch(
              blockStatusProvider(participant.userId).future,
            );
            return status.blockedByViewer || status.blockedViewer
                ? participant
                : null;
          } on Object {
            return null;
          }
        }),
      ).then(
        (items) =>
            items.whereType<ConversationParticipant>().toList(growable: false),
      );
    });

class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({required this.conversationId, super.key});

  final String conversationId;

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  String? _openedId;
  ChatRealtimeController? _realtimeController;
  final _messageController = TextEditingController();
  final _messageFocus = FocusNode();
  final _scrollController = ScrollController();
  final _acknowledgedBlockWarnings = <String>{};

  @override
  void initState() {
    super.initState();
    _messageFocus.addListener(_handleFocusChanged);
  }

  @override
  void dispose() {
    final openedId = _openedId;
    if (openedId != null) {
      _realtimeController?.closeConversation(openedId);
    }
    _messageFocus
      ..removeListener(_handleFocusChanged)
      ..dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    if (!_messageFocus.hasFocus) {
      ref
          .read(messageControllerProvider(widget.conversationId).notifier)
          .stopTyping();
    }
  }

  @override
  Widget build(BuildContext context) {
    final conversationId = widget.conversationId;
    final currentUserId = ref.watch(sessionControllerProvider).user?.id;
    final list = ref.watch(conversationControllerProvider);
    final realtime = ref.watch(chatRealtimeControllerProvider);
    final messageState = ref.watch(messageControllerProvider(conversationId));
    final existing = list.value
        ?.where((item) => item.id == conversationId)
        .firstOrNull;
    if (existing == null) {
      return FutureBuilder(
        future: ref
            .read(conversationControllerProvider.notifier)
            .loadById(conversationId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Scaffold(
              appBar: AppBar(),
              body: Center(
                child: Text('Conversation unavailable: ${snapshot.error}'),
              ),
            );
          }
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        },
      );
    }
    final conversation = existing;
    if (_openedId != conversation.id) {
      _openedId = conversation.id;
      _realtimeController = ref.read(chatRealtimeControllerProvider.notifier);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _realtimeController?.openConversation(conversation);
      });
    }
    final otherUser = conversation.type == ConversationType.direct
        ? conversation.participants
              .where((person) => person.userId != currentUserId)
              .firstOrNull
        : null;
    final presence = otherUser == null
        ? null
        : realtime.presence[otherUser.userId];
    final typing = realtime.typingByConversation[conversationId] ?? const [];
    final permission = otherUser == null
        ? const AsyncData(true)
        : ref.watch(directMessagePermissionProvider(otherUser.userId));
    final directBlockStatus = otherUser == null
        ? const AsyncData<BlockStatus>(
            BlockStatus(
              viewerId: '',
              targetUserId: '',
              blockedByViewer: false,
              blockedViewer: false,
            ),
          )
        : ref.watch(blockStatusProvider(otherUser.userId));
    final hasDirectBlock =
        directBlockStatus.value?.blockedByViewer == true ||
        directBlockStatus.value?.blockedViewer == true;
    final permissionPending =
        permission.isLoading || directBlockStatus.isLoading;
    final canMessage =
        permission.value == true &&
        directBlockStatus.hasValue &&
        !hasDirectBlock;
    final headerTitle = otherUser?.displayName?.trim().isNotEmpty == true
        ? otherUser!.displayName!.trim()
        : conversation.titleFor(currentUserId);
    final nickname = otherUser?.nickname?.trim();
    final presenceLabel = presence?.label(DateTime.now());
    final headerSubtitle = [
      if (nickname?.isNotEmpty == true && nickname != headerTitle) nickname!,
      ?presenceLabel,
    ].join(' · ');
    if (conversation.type == ConversationType.group) {
      final blocked = ref.watch(
        sharedGroupBlockedParticipantsProvider(conversation),
      );
      final participants = blocked.value ?? const <ConversationParticipant>[];
      if (participants.isNotEmpty &&
          _acknowledgedBlockWarnings.add(conversation.id)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showSharedGroupBlockWarning(participants);
        });
      }
    }
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 4,
        title: Row(
          children: [
            if (otherUser != null)
              KirenzUserAvatar(
                name: headerTitle,
                imageUrl: otherUser.avatarUrl,
                radius: 20,
              )
            else
              CircleAvatar(
                radius: 20,
                child: Text(_initials(conversation.titleFor(currentUserId))),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    headerTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (headerSubtitle.isNotEmpty)
                    Text(
                      headerSubtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (realtime.status == ChatConnectionStatus.connecting ||
              realtime.status == ChatConnectionStatus.reconnecting)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          if (conversation.type.name == 'group')
            IconButton(
              tooltip: 'Group settings',
              onPressed: () => context.push('/chat/$conversationId/settings'),
              icon: const Icon(Icons.settings_outlined),
            ),
          if (otherUser != null)
            IconButton(
              tooltip: 'Edit nickname',
              onPressed: () => _editDirectNickname(conversation, otherUser),
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: Column(
        children: [
          if (realtime.status == ChatConnectionStatus.disconnected ||
              realtime.status == ChatConnectionStatus.reconnecting)
            const _RealtimeNotice(message: 'Reconnecting…'),
          if (realtime.status == ChatConnectionStatus.failed)
            _RealtimeNotice(
              message: 'Realtime connection unavailable',
              onRetry: () =>
                  ref.read(chatRealtimeControllerProvider.notifier).retry(),
            ),
          if (realtime.operationError != null)
            Material(
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.error_outline),
                title: Text(realtime.operationError!),
                trailing: IconButton(
                  tooltip: 'Dismiss',
                  onPressed: () => ref
                      .read(chatRealtimeControllerProvider.notifier)
                      .clearOperationError(),
                  icon: const Icon(Icons.close),
                ),
              ),
            ),
          if (messageState.isCached)
            _ComposerNotice(
              message: messageState.cachedAt == null
                  ? 'Showing saved messages while offline.'
                  : 'Showing saved messages from ${_cachedTime(messageState.cachedAt!)}.',
              action: 'Refresh',
              onAction: () => ref
                  .read(messageControllerProvider(conversationId).notifier)
                  .loadInitial(),
            ),
          Expanded(
            child: _MessageHistory(
              state: messageState,
              currentUserId: currentUserId,
              scrollController: _scrollController,
              onRetryInitial: () => ref
                  .read(messageControllerProvider(conversationId).notifier)
                  .loadInitial(),
              onLoadOlder: () => ref
                  .read(messageControllerProvider(conversationId).notifier)
                  .loadOlder(),
              onReachedBottom: () => ref
                  .read(messageControllerProvider(conversationId).notifier)
                  .clearNewMessageCount(),
              onShowNewMessages: () => _scrollToBottom(conversationId),
            ),
          ),
          if (typing.isNotEmpty)
            Semantics(
              liveRegion: true,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(typingLabel(typing)),
              ),
            ),
          if (permission.hasError || directBlockStatus.hasError)
            _ComposerNotice(
              message: 'Could not verify messaging access.',
              action: 'Retry',
              onAction: otherUser == null
                  ? null
                  : () {
                      ref.invalidate(
                        directMessagePermissionProvider(otherUser.userId),
                      );
                      ref.invalidate(blockStatusProvider(otherUser.userId));
                    },
            )
          else if (hasDirectBlock)
            const _ComposerNotice(
              message:
                  'Direct messaging is unavailable because one of you has blocked the other.',
            )
          else if (permission.hasValue && !canMessage)
            const _ComposerNotice(
              message: 'This person only accepts messages from friends.',
            ),
          _MessageComposer(
            state: messageState,
            connected: realtime.canSend,
            permissionPending: permissionPending,
            permissionAllowed: canMessage,
            textController: _messageController,
            focusNode: _messageFocus,
            onChanged: (value) => ref
                .read(messageControllerProvider(conversationId).notifier)
                .updateDraft(value, hasFocus: _messageFocus.hasFocus),
            onAttach: () => _pickAttachments(conversationId),
            onRemoveAttachment: (path) => ref
                .read(messageControllerProvider(conversationId).notifier)
                .removeAttachment(path),
            onRetryAttachment: (path) => ref
                .read(messageControllerProvider(conversationId).notifier)
                .uploadAttachment(path),
            onSend: () => _send(conversationId),
          ),
        ],
      ),
    );
  }

  Future<void> _editDirectNickname(
    Conversation conversation,
    ConversationParticipant participant,
  ) async {
    final nickname = await showDialog<String>(
      context: context,
      builder: (_) => NicknameDialog(participant: participant),
    );
    if (nickname == null || !mounted) return;
    try {
      await ref
          .read(conversationControllerProvider.notifier)
          .updateNickname(conversation.id, participant.userId, nickname);
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _showSharedGroupBlockWarning(
    List<ConversationParticipant> participants,
  ) {
    final names = participants.map((item) => item.resolvedName).join(', ');
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded),
        title: const Text('Blocked participant in this group'),
        content: Text(
          'This shared group includes $names. Blocking does not remove existing group membership, so messages in this group remain visible.',
        ),
        actions: [
          FilledButton(
            onPressed: () => context.pop(),
            child: const Text('I understand'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAttachments(String conversationId) async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const [
        'jpg',
        'jpeg',
        'png',
        'gif',
        'webp',
        'heic',
        'mp4',
        'mov',
        'm4v',
        'webm',
        'pdf',
        'docx',
      ],
    );
    if (result == null || !mounted) return;
    final files = <DraftAttachment>[];
    final rejected = <String>[];
    for (final file in result.files) {
      final attachment = _draftAttachmentFor(file);
      if (attachment == null) {
        rejected.add(
          '${file.name} is not a supported image, video, PDF, or DOCX file.',
        );
      } else {
        files.add(attachment);
      }
    }
    final controller = ref.read(
      messageControllerProvider(conversationId).notifier,
    );
    if (files.isNotEmpty) controller.addAttachments(files);
    if (rejected.isNotEmpty) {
      controller.reportAttachmentError(rejected.join('\n'));
    }
  }

  Future<void> _send(String conversationId) async {
    final sent = await ref
        .read(messageControllerProvider(conversationId).notifier)
        .publish();
    if (!sent || !mounted) return;
    _messageController.clear();
    _scrollToBottom(conversationId);
  }

  void _scrollToBottom(String conversationId) {
    ref
        .read(messageControllerProvider(conversationId).notifier)
        .clearNewMessageCount();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }
}

class _MessageHistory extends StatefulWidget {
  const _MessageHistory({
    required this.state,
    required this.currentUserId,
    required this.scrollController,
    required this.onRetryInitial,
    required this.onLoadOlder,
    required this.onReachedBottom,
    required this.onShowNewMessages,
  });

  final MessageState state;
  final String? currentUserId;
  final ScrollController scrollController;
  final VoidCallback onRetryInitial;
  final Future<void> Function() onLoadOlder;
  final VoidCallback onReachedBottom;
  final VoidCallback onShowNewMessages;

  @override
  State<_MessageHistory> createState() => _MessageHistoryState();
}

class _MessageHistoryState extends State<_MessageHistory> {
  bool _preservingAnchor = false;

  @override
  void didUpdateWidget(covariant _MessageHistory oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.messages.length <= oldWidget.state.messages.length ||
        !widget.scrollController.hasClients ||
        widget.scrollController.position.extentAfter > 100) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.scrollController.hasClients) return;
      widget.scrollController.animateTo(
        widget.scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
      widget.onReachedBottom();
    });
  }

  Future<void> _loadOlderPreservingAnchor() async {
    if (_preservingAnchor ||
        widget.state.loading ||
        widget.state.loadingOlder ||
        !widget.state.hasMore ||
        !widget.scrollController.hasClients) {
      return;
    }
    _preservingAnchor = true;
    final position = widget.scrollController.position;
    final oldMaxExtent = position.maxScrollExtent;
    final oldOffset = position.pixels;
    await widget.onLoadOlder();
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preservingAnchor = false;
      if (!mounted || !widget.scrollController.hasClients) return;
      final newMaxExtent = widget.scrollController.position.maxScrollExtent;
      final target = oldOffset + (newMaxExtent - oldMaxExtent);
      widget.scrollController.jumpTo(
        target.clamp(
          widget.scrollController.position.minScrollExtent,
          widget.scrollController.position.maxScrollExtent,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    if (state.loading && state.messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(state.error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: widget.onRetryInitial,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (state.messages.isEmpty) {
      return const Center(child: Text('No messages yet'));
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.pixels < 120 && state.hasMore) {
          _loadOlderPreservingAnchor();
        }
        if (notification.metrics.extentAfter < 80) {
          widget.onReachedBottom();
        }
        return false;
      },
      child: Stack(
        children: [
          ListView.builder(
            controller: widget.scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            itemCount: state.messages.length + (state.loadingOlder ? 1 : 0),
            itemBuilder: (context, index) {
              if (state.loadingOlder && index == 0) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              final offset = state.loadingOlder ? 1 : 0;
              final messageIndex = index - offset;
              final message = state.messages[messageIndex];
              final previous = messageIndex == 0
                  ? null
                  : state.messages[messageIndex - 1];
              final next = messageIndex == state.messages.length - 1
                  ? null
                  : state.messages[messageIndex + 1];
              final groupedWithPrevious = _messagesAreGrouped(
                previous,
                message,
              );
              final groupedWithNext = _messagesAreGrouped(message, next);
              return Column(
                children: [
                  if (previous == null ||
                      !_sameDay(previous.sentAt, message.sentAt))
                    _DateSeparator(date: message.sentAt),
                  _MessageBubble(
                    message: message,
                    own: message.senderId == widget.currentUserId,
                    showSender: !groupedWithPrevious,
                    showAvatar: !groupedWithNext,
                    compact: groupedWithPrevious,
                  ),
                ],
              );
            },
          ),
          if (state.newMessageCount > 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: 12,
              child: Center(
                child: FilledButton.tonalIcon(
                  onPressed: widget.onShowNewMessages,
                  icon: const Icon(Icons.arrow_downward, size: 18),
                  label: Text(
                    '${state.newMessageCount} new message${state.newMessageCount == 1 ? '' : 's'}',
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.date});

  final DateTime? date;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(
      _dateLabel(date),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.own,
    required this.showSender,
    required this.showAvatar,
    required this.compact,
  });

  final ChatMessage message;
  final bool own;
  final bool showSender;
  final bool showAvatar;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (message.type == 'SYSTEM') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
        child: Text(
          message.content,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    final colors = Theme.of(context).colorScheme;
    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 300),
      margin: EdgeInsets.only(bottom: compact ? 3 : 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: own ? colors.primaryContainer : colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!own && showSender)
            Text(
              message.senderName,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          if (message.attachments.isNotEmpty)
            _MessageAttachments(attachments: message.attachments),
          if (message.content.isNotEmpty) ...[
            if (message.attachments.isNotEmpty) const SizedBox(height: 8),
            Text(message.content),
          ],
          const SizedBox(height: 4),
          Text(
            _messageTime(message.sentAt),
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
    return Align(
      alignment: own ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!own) ...[
            if (showAvatar)
              KirenzUserAvatar(
                name: message.senderName,
                imageUrl: message.senderAvatar,
                radius: 16,
              )
            else
              const SizedBox(width: 32),
            const SizedBox(width: 6),
          ],
          Flexible(child: bubble),
        ],
      ),
    );
  }
}

class _MessageAttachments extends StatelessWidget {
  const _MessageAttachments({required this.attachments});

  final List<ChatAttachment> attachments;

  @override
  Widget build(BuildContext context) {
    final media = attachments
        .where((item) => item.type == 'IMAGE' || item.type == 'VIDEO')
        .toList(growable: false);
    final viewerItems = media
        .map(
          (item) =>
              MediaViewerItem(url: item.url, type: item.type, name: item.name),
        )
        .toList(growable: false);
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 316.0;
        final mediaWidth = media.length <= 1
            ? availableWidth.clamp(0, 240).toDouble()
            : media.length == 2
            ? (availableWidth - 4) / 2
            : (availableWidth - 8) / 3;
        return Wrap(
          spacing: 4,
          runSpacing: 4,
          children: attachments
              .map((attachment) {
                if (attachment.type == 'FILE') {
                  return SizedBox(
                    width: availableWidth,
                    child: ListTile(
                      onTap: () => openMediaUrl(context, attachment.url),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.description_outlined),
                      title: Text(
                        attachment.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: attachment.bytes == null
                          ? null
                          : Text(_formatBytes(attachment.bytes!)),
                      trailing: const Icon(Icons.open_in_new),
                    ),
                  );
                }
                final viewerIndex = media.indexOf(attachment);
                return InkWell(
                  onTap: () => showAttachmentViewer(
                    context,
                    items: viewerItems,
                    initialIndex: viewerIndex,
                  ),
                  child: Container(
                    width: mediaWidth,
                    height: media.length == 1 ? 180 : mediaWidth,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (attachment.type == 'IMAGE')
                          Image.network(
                            attachment.url,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                const Icon(Icons.broken_image_outlined),
                          )
                        else
                          const ColoredBox(
                            color: Colors.black87,
                            child: Center(
                              child: CircleAvatar(
                                child: Icon(Icons.play_arrow),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              })
              .toList(growable: false),
        );
      },
    );
  }
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.state,
    required this.connected,
    required this.permissionPending,
    required this.permissionAllowed,
    required this.textController,
    required this.focusNode,
    required this.onChanged,
    required this.onAttach,
    required this.onRemoveAttachment,
    required this.onRetryAttachment,
    required this.onSend,
  });

  final MessageState state;
  final bool connected;
  final bool permissionPending;
  final bool permissionAllowed;
  final TextEditingController textController;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onAttach;
  final ValueChanged<String> onRemoveAttachment;
  final ValueChanged<String> onRetryAttachment;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final enabled = connected && permissionAllowed && !permissionPending;
    return SafeArea(
      top: false,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (state.attachmentError != null)
                Text(
                  state.attachmentError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (state.error != null)
                Text(
                  state.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (state.attachments.isNotEmpty)
                SizedBox(
                  height: 96,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: state.attachments.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final attachment = state.attachments[index];
                      return _DraftAttachmentTile(
                        attachment: attachment,
                        onRemove: () => onRemoveAttachment(attachment.path),
                        onRetry: () => onRetryAttachment(attachment.path),
                      );
                    },
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'Attach media or document',
                    style: IconButton.styleFrom(
                      minimumSize: const Size.square(42),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: enabled && !state.publishing ? onAttach : null,
                    icon: const Icon(Icons.attach_file, size: 21),
                  ),
                  Expanded(
                    child: TextField(
                      controller: textController,
                      focusNode: focusNode,
                      enabled: enabled && !state.publishing,
                      minLines: 1,
                      maxLines: 4,
                      onChanged: onChanged,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
                        ),
                        hintText: permissionAllowed
                            ? connected
                                  ? 'Write a message'
                                  : 'Reconnecting...'
                            : 'Messaging is unavailable',
                      ),
                    ),
                  ),
                  IconButton.filled(
                    tooltip: 'Send message',
                    style: IconButton.styleFrom(
                      minimumSize: const Size.square(42),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: enabled && state.canPublish ? onSend : null,
                    icon: state.publishing
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send, size: 20),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DraftAttachmentTile extends StatelessWidget {
  const _DraftAttachmentTile({
    required this.attachment,
    required this.onRemove,
    required this.onRetry,
  });

  final DraftAttachment attachment;
  final VoidCallback onRemove;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 88,
    child: Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: attachment.type == 'IMAGE'
                ? Image.file(File(attachment.path), fit: BoxFit.cover)
                : ColoredBox(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    child: Icon(
                      attachment.type == 'VIDEO'
                          ? Icons.video_file_outlined
                          : Icons.description_outlined,
                    ),
                  ),
          ),
        ),
        if (attachment.status == DraftAttachmentStatus.uploading)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black45,
              child: Center(
                child: CircularProgressIndicator(value: attachment.progress),
              ),
            ),
          ),
        if (attachment.status == DraftAttachmentStatus.failed)
          Positioned.fill(
            child: Material(
              color: Theme.of(context).colorScheme.errorContainer,
              child: InkWell(
                onTap: onRetry,
                child: const Center(child: Text('Retry')),
              ),
            ),
          ),
        Positioned(
          right: 0,
          top: 0,
          child: IconButton(
            tooltip: 'Remove attachment',
            onPressed: onRemove,
            icon: const Icon(Icons.close),
          ),
        ),
      ],
    ),
  );
}

class _ComposerNotice extends StatelessWidget {
  const _ComposerNotice({required this.message, this.action, this.onAction});

  final String message;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.secondaryContainer,
    child: ListTile(
      dense: true,
      leading: const Icon(Icons.info_outline),
      title: Text(message),
      trailing: onAction == null
          ? null
          : TextButton(onPressed: onAction, child: Text(action!)),
    ),
  );
}

DraftAttachment? _draftAttachmentFor(PlatformFile file) {
  final path = file.path;
  if (path == null || path.isEmpty) return null;
  final extension = (file.extension ?? file.name.split('.').last).toLowerCase();
  final type = switch (extension) {
    'jpg' || 'jpeg' || 'png' || 'gif' || 'webp' || 'heic' => 'IMAGE',
    'mp4' || 'mov' || 'm4v' || 'webm' => 'VIDEO',
    'pdf' || 'docx' => 'FILE',
    _ => null,
  };
  if (type == null) return null;
  final contentType = switch (extension) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'gif' => 'image/gif',
    'webp' => 'image/webp',
    'heic' => 'image/heic',
    'mp4' || 'm4v' => 'video/mp4',
    'mov' => 'video/quicktime',
    'webm' => 'video/webm',
    'pdf' => 'application/pdf',
    'docx' =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    _ => 'application/octet-stream',
  };
  return DraftAttachment(
    path: path,
    name: file.name,
    bytes: file.size,
    contentType: contentType,
    type: type,
  );
}

String _messageTime(DateTime? value) {
  if (value == null) return '';
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

bool _sameDay(DateTime? first, DateTime? second) {
  if (first == null || second == null) return false;
  final a = first.toLocal();
  final b = second.toLocal();
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

bool _messagesAreGrouped(ChatMessage? first, ChatMessage? second) {
  if (first == null || second == null) return false;
  if (first.type == 'SYSTEM' || second.type == 'SYSTEM') return false;
  if (first.status != 'ACTIVE' || second.status != 'ACTIVE') return false;
  if (first.senderId != second.senderId || first.senderId.isEmpty) return false;
  final firstTime = first.sentAt;
  final secondTime = second.sentAt;
  if (firstTime == null || secondTime == null) return false;
  return secondTime.difference(firstTime).abs() <= const Duration(minutes: 5);
}

String _dateLabel(DateTime? value) {
  if (value == null) return 'Unknown date';
  final date = value.toLocal();
  final now = DateTime.now();
  if (_sameDay(date, now)) return 'Today';
  if (_sameDay(date, now.subtract(const Duration(days: 1)))) {
    return 'Yesterday';
  }
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String _cachedTime(DateTime value) {
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')} '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
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

class _RealtimeNotice extends StatelessWidget {
  const _RealtimeNotice({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerHigh,
    child: ListTile(
      dense: true,
      leading: const Icon(Icons.sync_problem_outlined),
      title: Text(message),
      trailing: onRetry == null
          ? null
          : TextButton(onPressed: onRetry, child: const Text('Retry')),
    ),
  );
}
