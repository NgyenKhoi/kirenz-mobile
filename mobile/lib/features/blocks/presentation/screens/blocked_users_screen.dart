import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
          loading: () => const _BlockedSkeleton(),
          error: (error, stack) => _BlockedError(
            message: error.toString(),
            onRetry: () => ref.invalidate(blockedUsersProvider),
          ),
          data: (items) => items.isEmpty
              ? const _BlockedEmpty()
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
        leading: const CircleAvatar(child: Icon(Icons.person_off_outlined)),
        title: const Text(
          'Blocked user',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${record.blockedUserId}\nBlocked ${_date(record.createdAt)}',
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
        title: Text('Unblock ${record.blockedUserId}?'),
        content: const Text(
          'Visibility and interactions will again depend on both users’ privacy settings.',
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

class _BlockedSkeleton extends StatelessWidget {
  const _BlockedSkeleton();
  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.all(16),
    itemCount: 5,
    separatorBuilder: (context, index) => const SizedBox(height: 12),
    itemBuilder: (context, index) => Container(
      height: 92,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
      ),
    ),
  );
}

class _BlockedEmpty extends StatelessWidget {
  const _BlockedEmpty();
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_outlined, size: 48),
          SizedBox(height: 12),
          Text('You have not blocked anyone'),
        ],
      ),
    ),
  );
}

class _BlockedError extends StatelessWidget {
  const _BlockedError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}

String _date(DateTime? value) {
  if (value == null) return 'on an unknown date';
  final local = value.toLocal();
  return '${local.day}/${local.month}/${local.year}';
}
