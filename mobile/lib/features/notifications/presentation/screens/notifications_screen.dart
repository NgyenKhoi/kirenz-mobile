import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/services/local_notification_service.dart';
import '../../domain/entities/social_notification.dart';
import '../controllers/notification_controller.dart';
import '../notification_routing.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../../shared/widgets/content_frame.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationControllerProvider);
    final controller = ref.read(notificationControllerProvider.notifier);
    final today = state.items.where(_isToday).toList(growable: false);
    final earlier = state.items.where((item) => !_isToday(item)).toList();
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Alerts'),
            if (state.unreadCount > 0) ...[
              const SizedBox(width: 8),
              Badge(
                label: Text(
                  state.unreadCount > 99 ? '99+' : '${state.unreadCount}',
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Device notification settings',
            onPressed: () => _showPermissionSheet(context, ref),
            icon: const Icon(Icons.notifications_active_outlined),
          ),
          if (state.unreadCount > 0)
            TextButton(
              onPressed: state.markingAll ? null : controller.markAllRead,
              child: state.markingAll
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Mark all read'),
            ),
        ],
      ),
      body: KirenzContentFrame(
        child: RefreshIndicator(
        onRefresh: controller.refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (state.isCached)
              SliverToBoxAdapter(
                child: _Notice(
                  icon: Icons.cloud_off_outlined,
                  message: state.cachedAt == null
                      ? 'Showing saved alerts while offline.'
                      : 'Showing saved alerts from ${_absoluteTime(state.cachedAt!)}.',
                  action: 'Refresh',
                  onAction: controller.refresh,
                ),
              ),
            if (state.connectionStatus == NotificationConnectionStatus.failed ||
                state.connectionStatus ==
                    NotificationConnectionStatus.reconnecting)
              _connectionNotice(state, controller),
            if (state.countError != null)
              SliverToBoxAdapter(
                child: _Notice(
                  icon: Icons.sync_problem_outlined,
                  message: 'Unread count unavailable. ${state.countError!}',
                  action: 'Retry',
                  error: true,
                  onAction: controller.refresh,
                ),
              ),
            if (state.actionError != null)
              SliverToBoxAdapter(
                child: _Notice(
                  icon: Icons.error_outline,
                  message: state.actionError!,
                  action: 'Refresh',
                  error: true,
                  onAction: controller.refresh,
                ),
              ),
            if (state.listLoading && state.items.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList.list(
                  children: const [
                    _NotificationSkeleton(),
                    SizedBox(height: 10),
                    _NotificationSkeleton(),
                    SizedBox(height: 10),
                    _NotificationSkeleton(),
                  ],
                ),
              )
            else if (state.listError != null && state.items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: KirenzStateView(
                  icon: Icons.cloud_off_outlined,
                  title: 'Could not load alerts',
                  message: state.listError!,
                  actionLabel: 'Retry',
                  isError: true,
                  onAction: controller.refresh,
                ),
              )
            else if (state.items.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: KirenzStateView(
                  icon: Icons.notifications_none,
                  title: 'You are all caught up',
                  message: 'Friend and social activity will appear here.',
                ),
              )
            else ...[
              if (today.isNotEmpty) ...[
                const _SectionHeader('Today'),
                _NotificationList(items: today),
              ],
              if (earlier.isNotEmpty) ...[
                const _SectionHeader('Earlier'),
                _NotificationList(items: earlier),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ],
        ),
      ),
      ),
    );
  }

  SliverToBoxAdapter _connectionNotice(
    NotificationState state,
    NotificationController controller,
  ) => SliverToBoxAdapter(
    child: _Notice(
      icon: state.connectionStatus == NotificationConnectionStatus.failed
          ? Icons.wifi_off_outlined
          : Icons.sync,
      message: state.connectionStatus == NotificationConnectionStatus.failed
          ? 'Live alerts are unavailable.'
          : 'Reconnecting live alerts...',
      action: state.connectionStatus == NotificationConnectionStatus.failed
          ? 'Retry'
          : null,
      onAction: state.connectionStatus == NotificationConnectionStatus.failed
          ? controller.connect
          : null,
    ),
  );
}

class _NotificationList extends ConsumerWidget {
  const _NotificationList({required this.items});

  final List<SocialNotification> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationControllerProvider);
    return SliverList.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 84),
      itemBuilder: (context, index) {
        final item = items[index];
        return _NotificationRow(
          notification: item,
          pending: state.pendingIds.contains(item.id),
          onTap: () => _openNotification(context, ref, item),
        );
      },
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.notification,
    required this.pending,
    required this.onTap,
  });

  final SocialNotification notification;
  final bool pending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label:
        '${notification.isRead ? 'Read' : 'Unread'} alert from ${notification.actorName}. ${notification.message}. ${_relativeTime(notification.createdAt)}',
    child: Material(
      color: notification.isRead
          ? Colors.transparent
          : Theme.of(
              context,
            ).colorScheme.primaryContainer.withValues(alpha: .3),
      child: InkWell(
        onTap: pending ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  KirenzUserAvatar(
                    name: notification.actorName,
                    imageUrl: notification.actorAvatar,
                  ),
                  Positioned(
                    right: -5,
                    bottom: -3,
                    child: CircleAvatar(
                      radius: 11,
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      child: Icon(
                        _typeIcon(notification.type),
                        size: 14,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: notification.actorName,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          TextSpan(text: ' ${notification.message}'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _relativeTime(notification.createdAt),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    if (pending) ...[
                      const SizedBox(height: 6),
                      const LinearProgressIndicator(),
                    ],
                  ],
                ),
              ),
              if (!notification.isRead)
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 8),
                  child: Semantics(
                    label: 'Unread',
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> _openNotification(
  BuildContext context,
  WidgetRef ref,
  SocialNotification notification,
) async {
  final route = socialNotificationRoute(notification);
  final success = await ref
      .read(notificationControllerProvider.notifier)
      .markRead(notification);
  if (!context.mounted) return;
  if (!success) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'The alert could not be marked read. Opening its target.',
        ),
      ),
    );
  }
  if (route == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('This alert target is unavailable.')),
    );
    return;
  }
  context.push(route);
}

Future<void> _showPermissionSheet(BuildContext context, WidgetRef ref) async {
  final service = ref.read(localNotificationServiceProvider);
  var status = await service.permissionStatus();
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.notifications_active_outlined, size: 44),
            const SizedBox(height: 12),
            Text(
              'Device notifications',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(_permissionMessage(status), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            if (status == LocalNotificationPermission.notDetermined)
              FilledButton(
                onPressed: () async {
                  final next = await service.requestPermission();
                  if (context.mounted) setState(() => status = next);
                },
                child: const Text('Allow notifications'),
              )
            else if (status == LocalNotificationPermission.deniedOrRestricted)
              const Text(
                'Open the Kirenz app entry in your device Settings to enable notifications. In-app alerts and badges continue to work.',
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    ),
  );
}

String _permissionMessage(
  LocalNotificationPermission status,
) => switch (status) {
  LocalNotificationPermission.authorized =>
    'Kirenz may show social alerts in the system notification tray.',
  LocalNotificationPermission.provisional =>
    'Quiet provisional notifications are enabled. You can change this in system Settings.',
  LocalNotificationPermission.notDetermined =>
    'Allow Kirenz to show social activity while the app is open. This is optional.',
  LocalNotificationPermission.deniedOrRestricted =>
    'System notifications are disabled or restricted.',
  LocalNotificationPermission.unavailable =>
    'System notifications are unavailable on this platform.',
};

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.message,
    this.action,
    this.onAction,
    this.error = false,
  });

  final IconData icon;
  final String message;
  final String? action;
  final VoidCallback? onAction;
  final bool error;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    child: Material(
      color: error
          ? Theme.of(context).colorScheme.errorContainer
          : Theme.of(context).colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(16),
      child: ListTile(
        dense: true,
        leading: Icon(icon),
        title: Text(message),
        trailing: onAction == null
            ? null
            : TextButton(onPressed: onAction, child: Text(action!)),
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52),
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          if (onAction != null) ...[
            const SizedBox(height: 18),
            FilledButton(onPressed: onAction, child: Text(action!)),
          ],
        ],
      ),
    ),
  );
}

class _NotificationSkeleton extends StatelessWidget {
  const _NotificationSkeleton();

  @override
  Widget build(BuildContext context) => Container(
    height: 82,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(18),
    ),
  );
}

bool _isToday(SocialNotification notification) {
  final created = notification.createdAt?.toLocal();
  if (created == null) return false;
  final now = DateTime.now();
  return created.year == now.year &&
      created.month == now.month &&
      created.day == now.day;
}

IconData _typeIcon(SocialNotificationType type) => switch (type) {
  SocialNotificationType.friendRequest ||
  SocialNotificationType.friendAccept => Icons.person_add_alt_1,
  SocialNotificationType.postLike => Icons.favorite,
  SocialNotificationType.postComment ||
  SocialNotificationType.commentReply => Icons.chat_bubble,
  SocialNotificationType.postMention ||
  SocialNotificationType.commentMention => Icons.alternate_email,
  SocialNotificationType.birthday => Icons.cake,
  SocialNotificationType.welcome => Icons.celebration,
  SocialNotificationType.unsupported => Icons.notifications,
};

String _relativeTime(DateTime? value) {
  if (value == null) return 'Recently';
  final difference = DateTime.now().difference(value.toLocal());
  if (difference.isNegative || difference.inMinutes < 1) return 'Just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
  if (difference.inHours < 24) return '${difference.inHours}h ago';
  if (difference.inDays < 7) return '${difference.inDays}d ago';
  return _absoluteTime(value);
}

String _absoluteTime(DateTime value) {
  final local = value.toLocal();
  return '${local.day}/${local.month}/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

