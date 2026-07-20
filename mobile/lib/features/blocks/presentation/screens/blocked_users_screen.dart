import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../domain/entities/block_models.dart';
import '../controllers/block_controller.dart';

class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(blockedUsersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Blocked users')),
      body: SafeArea(
        child: users.when(
          loading: () => const KirenzSkeletonList(itemHeight: 92),
          error: (error, stack) => KirenzStateView(
            icon: Icons.cloud_off_outlined,
            title: 'Could not load blocked users',
            message: error.toString(),
            actionLabel: 'Retry',
            isError: true,
            onAction: () => ref.invalidate(blockedUsersProvider),
          ),
          data: (items) => items.isEmpty
              ? const KirenzStateView(
                  icon: Icons.shield_outlined,
                  title: 'You have not blocked anyone',
                )
              : RefreshIndicator(
                  onRefresh: () async =>
                      ref.refresh(blockedUsersProvider.future),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) =>
                        _BlockedUserTile(record: items[index]),
                  ),
                ),
        ),
      ),
    );
  }
}

class _BlockedUserTile extends ConsumerWidget {
  const _BlockedUserTile({required this.record});
  final BlockRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref
        .watch(blockActionControllerProvider)
        .contains(record.blockedUserId);
    return Card(
      child: ListTile(
        leading: KirenzUserAvatar(
          name: record.resolvedName,
          imageUrl: record.avatarUrl,
          icon: Icons.person_off_outlined,
        ),
        title: Text(
          record.resolvedName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          [
            if (record.username?.trim().isNotEmpty == true)
              '@${record.username!.trim()}',
            'Blocked ${_date(record.createdAt)}',
          ].join('\n'),
        ),
        isThreeLine: true,
        trailing: OutlinedButton(
          onPressed: pending ? null : () => _confirmUnblock(context, ref),
          child: pending
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Unblock'),
        ),
      ),
    );
  }

  Future<void> _confirmUnblock(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Unblock ${record.resolvedName}?'),
        content: const Text(
          'Visibility and interactions will again depend on both users\' privacy settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Unblock'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref
          .read(blockActionControllerProvider.notifier)
          .unblock(record.blockedUserId);
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}

String _date(DateTime? value) {
  if (value == null) return 'on an unknown date';
  final local = value.toLocal();
  return '${local.day}/${local.month}/${local.year}';
}
