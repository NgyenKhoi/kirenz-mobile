import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/controllers/session_controller.dart';
import '../../../chat/domain/entities/realtime_chat.dart';
import '../../../chat/presentation/controllers/chat_realtime_controller.dart';
import '../controllers/notification_controller.dart';
import '../notification_routing.dart';

class ForegroundNotificationLayer extends ConsumerStatefulWidget {
  const ForegroundNotificationLayer({
    required this.child,
    required this.router,
    required this.enabled,
    super.key,
  });

  final Widget child;
  final GoRouter router;
  final bool enabled;

  @override
  ConsumerState<ForegroundNotificationLayer> createState() =>
      _ForegroundNotificationLayerState();
}

class _ForegroundNotificationLayerState
    extends ConsumerState<ForegroundNotificationLayer> {
  StreamSubscription<ConversationRealtimeUpdate>? _chatSubscription;
  Timer? _chatTimer;
  ConversationRealtimeUpdate? _chatBanner;
  final _seenChatMessageIds = <String>{};
  int _handledSequence = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.enabled && _chatSubscription == null) _initializeChat();
  }

  @override
  void didUpdateWidget(covariant ForegroundNotificationLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !oldWidget.enabled) {
      _initializeChat();
    }
    if (!widget.enabled && oldWidget.enabled) {
      _chatSubscription?.cancel();
      _chatSubscription = null;
      _chatTimer?.cancel();
      _chatBanner = null;
    }
  }

  void _initializeChat() {
    _chatSubscription ??= ref
        .read(chatRealtimeControllerProvider.notifier)
        .conversationUpdateEvents
        .listen(_handleChatUpdate);
  }

  void _handleChatUpdate(ConversationRealtimeUpdate update) {
    final message = update.lastMessage;
    final currentUserId = ref.read(sessionControllerProvider).user?.id;
    if (!mounted ||
        message == null ||
        message.messageId.isEmpty ||
        message.senderId == currentUserId ||
        !_seenChatMessageIds.add(message.messageId)) {
      return;
    }
    if (_seenChatMessageIds.length > 200) {
      _seenChatMessageIds.remove(_seenChatMessageIds.first);
    }
    final route = '/chat/${update.conversationId}';
    final currentUri = widget.router.routeInformationProvider.value.uri;
    final currentPath = currentUri.path;
    final openConversationId = ref
        .read(chatRealtimeControllerProvider.notifier)
        .openConversationId;
    if (currentPath == route || openConversationId == update.conversationId) {
      return;
    }
    _chatTimer?.cancel();
    setState(() => _chatBanner = update);
    _chatTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _chatBanner = null);
    });
  }

  @override
  void dispose() {
    _chatSubscription?.cancel();
    _chatTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final state = ref.watch(notificationControllerProvider);
    final notification = state.banner;
    final route = notification == null
        ? null
        : socialNotificationRoute(notification);
    final currentUri = widget.router.routeInformationProvider.value.uri;
    final currentPath = currentUri.path;
    final socialSuppressed =
        notification != null &&
        (currentPath == '/notifications' ||
            (route != null && currentUri.toString() == route));
    if (notification != null && state.bannerSequence != _handledSequence) {
      _handledSequence = state.bannerSequence;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (socialSuppressed || route == null) {
          ref.read(notificationControllerProvider.notifier).dismissBanner();
        }
      });
    }
    return Stack(
      children: [
        widget.child,
        if (notification != null && route != null && !socialSuppressed)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 12,
            right: 12,
            child: SafeArea(
              top: false,
              child: Dismissible(
                key: ValueKey('notification-banner-${notification.id}'),
                direction: DismissDirection.horizontal,
                onDismissed: (_) => ref
                    .read(notificationControllerProvider.notifier)
                    .dismissBanner(),
                child: Material(
                  elevation: 8,
                  color: Theme.of(context).colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(20),
                  clipBehavior: Clip.antiAlias,
                  child: Semantics(
                    liveRegion: true,
                    button: true,
                    label:
                        'New alert from ${notification.actorName}. ${notification.message}',
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          notification.actorName.trim().isEmpty
                              ? 'K'
                              : notification.actorName.trim()[0].toUpperCase(),
                        ),
                      ),
                      title: Text(
                        notification.actorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        notification.message,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        tooltip: 'Dismiss alert',
                        onPressed: () => ref
                            .read(notificationControllerProvider.notifier)
                            .dismissBanner(),
                        icon: const Icon(Icons.close),
                      ),
                      onTap: () {
                        ref
                            .read(notificationControllerProvider.notifier)
                            .dismissBanner();
                        widget.router.push(route);
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        if ((notification == null || socialSuppressed) && _chatBanner != null)
          _ChatBanner(
            update: _chatBanner!,
            onDismiss: () {
              _chatTimer?.cancel();
              setState(() => _chatBanner = null);
            },
            onTap: () {
              final conversationId = _chatBanner!.conversationId;
              _chatTimer?.cancel();
              setState(() => _chatBanner = null);
              widget.router.push('/chat/$conversationId');
            },
          ),
      ],
    );
  }
}

class _ChatBanner extends StatelessWidget {
  const _ChatBanner({
    required this.update,
    required this.onDismiss,
    required this.onTap,
  });

  final ConversationRealtimeUpdate update;
  final VoidCallback onDismiss;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final message = update.lastMessage!;
    final preview = switch (message.type) {
      'IMAGE' => 'Sent an image',
      'VIDEO' => 'Sent a video',
      'FILE' => 'Sent a file',
      _ => message.content.trim().isEmpty ? 'New message' : message.content,
    };
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 8,
      left: 12,
      right: 12,
      child: SafeArea(
        top: false,
        child: Dismissible(
          key: ValueKey('chat-banner-${message.messageId}'),
          direction: DismissDirection.horizontal,
          onDismissed: (_) => onDismiss(),
          child: Material(
            elevation: 8,
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: Semantics(
              liveRegion: true,
              button: true,
              label: 'New message from ${message.senderName}. $preview',
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.chat_bubble_outline),
                ),
                title: Text(
                  message.senderName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  tooltip: 'Dismiss message alert',
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close),
                ),
                onTap: onTap,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
