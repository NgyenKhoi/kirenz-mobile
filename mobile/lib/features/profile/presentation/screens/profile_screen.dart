import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/controllers/session_controller.dart';
import '../../data/repositories/profile_repository.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({this.userId, super.key});

  final String? userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCurrentUser = userId == null;
    final profile = isCurrentUser
        ? ref.watch(currentUserProfileProvider)
        : ref.watch(userProfileProvider(userId!));

    return Scaffold(
      appBar: AppBar(
        title: Text(isCurrentUser ? 'Profile' : 'User profile'),
        actions: [
          if (isCurrentUser) ...[
            IconButton(
              tooltip: 'Privacy',
              onPressed: () => context.push('/privacy'),
              icon: const Icon(Icons.shield_outlined),
            ),
            IconButton(
              tooltip: 'Logout',
              onPressed: () {
                ref.read(sessionControllerProvider.notifier).signOut();
              },
              icon: const Icon(Icons.logout),
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            if (isCurrentUser) {
              ref.invalidate(currentUserProfileProvider);
              await ref.read(currentUserProfileProvider.future);
              return;
            }

            ref.invalidate(userProfileProvider(userId!));
            await ref.read(userProfileProvider(userId!).future);
          },
          child: profile.when(
            data: (user) => _ProfileContent(
              user: user,
              isCurrentUser: isCurrentUser,
            ),
            loading: () => const _ProfileLoading(),
            error: (error, stackTrace) => _ProfileError(
              message: error.toString(),
              onRetry: () {
                if (isCurrentUser) {
                  ref.invalidate(currentUserProfileProvider);
                } else {
                  ref.invalidate(userProfileProvider(userId!));
                }
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({required this.user, required this.isCurrentUser});

  final AppUser user;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  child: Text(_initials(user.displayName)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      if (user.email.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          user.email,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (isCurrentUser) ...[
          _ProfileActionTile(
            icon: Icons.edit_outlined,
            title: 'Edit profile',
            onTap: () => context.push('/profile/edit'),
          ),
          const SizedBox(height: 12),
          const _ProfileActionTile(
            icon: Icons.image_outlined,
            title: 'Avatar upload',
          ),
          const SizedBox(height: 12),
          const _ProfileActionTile(
            icon: Icons.panorama_outlined,
            title: 'Cover photo upload',
          ),
          const SizedBox(height: 12),
          const _ProfileActionTile(
            icon: Icons.photo_library_outlined,
            title: 'Photos and friends tabs',
          ),
        ] else ...[
          const _ProfileActionTile(
            icon: Icons.person_add_alt_1_outlined,
            title: 'Friend actions',
          ),
          const SizedBox(height: 12),
          const _ProfileActionTile(
            icon: Icons.block_outlined,
            title: 'Block user',
          ),
          const SizedBox(height: 12),
          const _ProfileActionTile(
            icon: Icons.people_outline,
            title: 'Mutual friends',
          ),
        ],
      ],
    );
  }
}

class _ProfileActionTile extends StatelessWidget {
  const _ProfileActionTile({required this.icon, required this.title, this.onTap});

  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      tileColor: Theme.of(context).colorScheme.surfaceContainerLow,
      leading: Icon(icon),
      title: Text(title),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _ProfileLoading extends StatelessWidget {
  const _ProfileLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: const [
        SizedBox(height: 160),
        Center(child: CircularProgressIndicator()),
      ],
    );
  }
}

class _ProfileError extends StatelessWidget {
  const _ProfileError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 120),
        Icon(
          Icons.error_outline,
          size: 48,
          color: Theme.of(context).colorScheme.error,
        ),
        const SizedBox(height: 16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}

String _initials(String value) {
  final words = value.trim().split(RegExp(r'\s+'));
  if (words.isEmpty || words.first.isEmpty) {
    return 'K';
  }

  return words.take(2).map((word) => word[0].toUpperCase()).join();
}
