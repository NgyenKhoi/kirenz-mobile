import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/privacy_settings.dart';
import '../controllers/privacy_controller.dart';

class PrivacyScreen extends ConsumerStatefulWidget {
  const PrivacyScreen({super.key});

  @override
  ConsumerState<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends ConsumerState<PrivacyScreen> {
  PrivacySettings? _draft;
  PrivacySettings? _canonical;

  bool get _isDirty {
    final draft = _draft;
    final canonical = _canonical;
    return draft != null &&
        canonical != null &&
        (draft.profileVisibility != canonical.profileVisibility ||
            draft.postVisibility != canonical.postVisibility ||
            draft.allowDirectMessages != canonical.allowDirectMessages ||
            draft.showOnlineStatus != canonical.showOnlineStatus);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(currentPrivacyProvider);
    final value = state.value;
    if (_draft == null && value != null) {
      _draft = value;
      _canonical = value;
    }
    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && await _confirmDiscard()) {
          if (context.mounted) {
            setState(() => _draft = _canonical);
            context.pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Privacy'),
          actions: [
            TextButton(
              onPressed: _draft == null || !_isDirty || state.isLoading
                  ? null
                  : _save,
              child: state.isLoading
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
        body: SafeArea(child: _body(state)),
      ),
    );
  }

  Widget _body(AsyncValue<PrivacySettings> state) {
    final draft = _draft;
    if (draft == null) {
      return state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _PrivacyError(
          message: error.toString(),
          onRetry: () => ref.invalidate(currentPrivacyProvider),
        ),
        data: (_) => const SizedBox.shrink(),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (state.hasError) ...[
          Material(
            color: Theme.of(context).colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                state.error.toString(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Text(
          'Visibility',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<PrivacyVisibility>(
          initialValue: draft.profileVisibility,
          decoration: const InputDecoration(
            labelText: 'Profile visibility',
            prefixIcon: Icon(Icons.person_outline),
          ),
          items: PrivacyVisibility.values
              .map(
                (value) => DropdownMenuItem(
                  value: value,
                  child: Text(_visibilityLabel(value)),
                ),
              )
              .toList(),
          onChanged: state.isLoading
              ? null
              : (value) => _update(profileVisibility: value),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<PrivacyVisibility>(
          initialValue: draft.postVisibility,
          decoration: const InputDecoration(
            labelText: 'Default post visibility',
            prefixIcon: Icon(Icons.article_outlined),
          ),
          items: PrivacyVisibility.values
              .map(
                (value) => DropdownMenuItem(
                  value: value,
                  child: Text(_visibilityLabel(value)),
                ),
              )
              .toList(),
          onChanged: state.isLoading
              ? null
              : (value) => _update(postVisibility: value),
        ),
        const SizedBox(height: 24),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                value: draft.allowDirectMessages,
                onChanged: state.isLoading
                    ? null
                    : (value) => _update(allowDirectMessages: value),
                secondary: const Icon(Icons.chat_bubble_outline),
                title: const Text('Allow direct messages'),
                subtitle: const Text(
                  'Allow other users to start a direct conversation',
                ),
              ),
              Divider(
                height: 1,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              SwitchListTile(
                value: draft.showOnlineStatus,
                onChanged: state.isLoading
                    ? null
                    : (value) => _update(showOnlineStatus: value),
                secondary: const Icon(Icons.circle_outlined),
                title: const Text('Show online status'),
                subtitle: const Text('Let others see when you are online'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Card(
          child: ListTile(
            leading: const Icon(Icons.block_outlined),
            title: const Text('Blocked users'),
            subtitle: const Text('Review and unblock users'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/blocked-users'),
          ),
        ),
      ],
    );
  }

  void _update({
    PrivacyVisibility? profileVisibility,
    PrivacyVisibility? postVisibility,
    bool? allowDirectMessages,
    bool? showOnlineStatus,
  }) {
    final draft = _draft!;
    setState(() {
      _draft = PrivacySettings(
        userId: draft.userId,
        profileVisibility: profileVisibility ?? draft.profileVisibility,
        postVisibility: postVisibility ?? draft.postVisibility,
        allowDirectMessages: allowDirectMessages ?? draft.allowDirectMessages,
        showOnlineStatus: showOnlineStatus ?? draft.showOnlineStatus,
        updatedAt: draft.updatedAt,
      );
    });
  }

  Future<void> _save() async {
    final saved = await ref.read(currentPrivacyProvider.notifier).save(_draft!);
    if (!mounted || !saved) return;
    final canonical = ref.read(currentPrivacyProvider).value!;
    setState(() {
      _draft = canonical;
      _canonical = canonical;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Privacy settings saved')));
  }

  Future<bool> _confirmDiscard() async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Discard changes?'),
            content: const Text('Your privacy changes have not been saved.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Keep editing'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Discard'),
              ),
            ],
          ),
        ) ??
        false;
  }
}

class _PrivacyError extends StatelessWidget {
  const _PrivacyError({required this.message, required this.onRetry});
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
            Icons.shield_outlined,
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

String _visibilityLabel(PrivacyVisibility value) => switch (value) {
  PrivacyVisibility.public => 'Public',
  PrivacyVisibility.friendsOnly => 'Friends only',
  PrivacyVisibility.private => 'Private',
};
