import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../auth/presentation/controllers/session_controller.dart';
import '../../data/repositories/profile_repository.dart';
import '../../domain/entities/user_profile.dart';
import '../controllers/profile_media_controller.dart';
import '../widgets/profile_content_tabs.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({this.userId, super.key});

  final String? userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCurrentUser = userId == null;
    final profile = isCurrentUser
        ? ref.watch(currentUserProfileProvider)
        : ref.watch(userProfileProvider(userId!));

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(isCurrentUser ? 'Profile' : 'User profile'),
          actions: [
            if (isCurrentUser)
              IconButton(
                tooltip: 'Privacy',
                onPressed: () => context.push('/privacy'),
                icon: const Icon(Icons.shield_outlined),
              ),
            if (isCurrentUser)
              IconButton(
                tooltip: 'Logout',
                onPressed: () =>
                    ref.read(sessionControllerProvider.notifier).signOut(),
                icon: const Icon(Icons.logout),
              ),
          ],
        ),
        body: SafeArea(
          child: profile.when(
            data: (user) => _ProfileContent(
              user: user,
              isCurrentUser: isCurrentUser,
              onRefresh: () => _refresh(ref, isCurrentUser),
            ),
            loading: () => const _ProfileLoading(),
            error: (error, stackTrace) => _ProfileError(
              message: error.toString(),
              onRetry: () => _invalidate(ref, isCurrentUser),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _refresh(WidgetRef ref, bool isCurrentUser) async {
    _invalidate(ref, isCurrentUser);
    if (isCurrentUser) {
      await ref.read(currentUserProfileProvider.future);
    } else {
      await ref.read(userProfileProvider(userId!).future);
    }
  }

  void _invalidate(WidgetRef ref, bool isCurrentUser) {
    if (isCurrentUser) {
      ref.invalidate(currentUserProfileProvider);
    } else {
      ref.invalidate(userProfileProvider(userId!));
    }
  }
}

class _ProfileContent extends ConsumerWidget {
  const _ProfileContent({
    required this.user,
    required this.isCurrentUser,
    required this.onRefresh,
  });

  final UserProfile user;
  final bool isCurrentUser;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatarMedia = isCurrentUser
        ? ref.watch(profileMediaControllerProvider(ProfileMediaTarget.avatar))
        : const ProfileMediaState();
    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverToBoxAdapter(
          child: RefreshIndicator(
            onRefresh: onRefresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  _ProfileHeader(
                    user: user,
                    isCurrentUser: isCurrentUser,
                    avatarMedia: avatarMedia,
                    onEditAvatar: () => _showAvatarActions(context, ref, user),
                    onEditCover: () => context.push('/profile/me/cover'),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    child: _ProfileDetails(
                      user: user,
                      isCurrentUser: isCurrentUser,
                    ),
                  ),
                  if (isCurrentUser && avatarMedia.errorMessage != null)
                    _AvatarFailure(
                      state: avatarMedia,
                      onRetry: avatarMedia.canUpload
                          ? () => ref
                                .read(
                                  profileMediaControllerProvider(
                                    ProfileMediaTarget.avatar,
                                  ).notifier,
                                )
                                .upload()
                          : () => _showAvatarActions(context, ref, user),
                      onCancel: () => ref
                          .read(
                            profileMediaControllerProvider(
                              ProfileMediaTarget.avatar,
                            ).notifier,
                          )
                          .cancel(),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SliverPersistentHeader(
          pinned: true,
          delegate: _ProfileTabsDelegate(),
        ),
      ],
      body: TabBarView(
        children: [
          ProfilePostsTab(userId: user.id),
          ProfilePhotosTab(userId: user.id),
          ProfileFriendsTab(userId: user.id),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.user,
    required this.isCurrentUser,
    required this.avatarMedia,
    required this.onEditAvatar,
    required this.onEditCover,
  });

  final UserProfile user;
  final bool isCurrentUser;
  final ProfileMediaState avatarMedia;
  final VoidCallback onEditAvatar;
  final VoidCallback onEditCover;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: 244,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            bottom: 52,
            child: _NetworkImageSurface(
              url: user.coverPhotoUrl,
              fallback: Container(
                color: colors.primaryContainer,
                alignment: Alignment.center,
                child: Icon(
                  Icons.panorama_outlined,
                  size: 52,
                  color: colors.onPrimaryContainer,
                ),
              ),
            ),
          ),
          if (isCurrentUser)
            Positioned(
              right: 12,
              top: 12,
              child: FilledButton.tonalIcon(
                onPressed: onEditCover,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Edit cover'),
              ),
            ),
          Positioned(
            left: 20,
            bottom: 0,
            child: Container(
              width: 112,
              height: 112,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: colors.surface,
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child:
                    avatarMedia.status == ProfileMediaStatus.uploading &&
                        avatarMedia.localPath != null
                    ? Image.file(
                        File(avatarMedia.localPath!),
                        fit: BoxFit.cover,
                      )
                    : _NetworkImageSurface(
                        url: user.avatarUrl,
                        fallback: ColoredBox(
                          color: colors.secondaryContainer,
                          child: Center(
                            child: Text(
                              _initials(user.displayName),
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    color: colors.onSecondaryContainer,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ),
          if (isCurrentUser)
            Positioned(
              left: 94,
              bottom: 2,
              child: IconButton.filled(
                tooltip: 'Change profile photo',
                onPressed: avatarMedia.isBusy ? null : onEditAvatar,
                icon: avatarMedia.status == ProfileMediaStatus.selecting
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.camera_alt_outlined),
              ),
            ),
          if (avatarMedia.status == ProfileMediaStatus.uploading)
            Positioned(
              left: 24,
              bottom: 4,
              child: SizedBox.square(
                dimension: 104,
                child: CircularProgressIndicator(
                  strokeWidth: 5,
                  value: avatarMedia.progress == 0
                      ? null
                      : avatarMedia.progress,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AvatarFailure extends StatelessWidget {
  const _AvatarFailure({
    required this.state,
    required this.onRetry,
    required this.onCancel,
  });

  final ProfileMediaState state;
  final VoidCallback onRetry;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Material(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                state.errorMessage!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: onCancel, child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: onRetry, child: const Text('Retry')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NetworkImageSurface extends StatelessWidget {
  const _NetworkImageSurface({required this.url, required this.fallback});

  final String? url;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    final value = url;
    if (value == null || value.isEmpty) return fallback;
    return CachedNetworkImage(
      imageUrl: value,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      placeholder: (context, url) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        child: const Center(child: CircularProgressIndicator()),
      ),
      errorWidget: (context, url, error) => fallback,
    );
  }
}

class _ProfileDetails extends StatelessWidget {
  const _ProfileDetails({required this.user, required this.isCurrentUser});

  final UserProfile user;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (user.username.isNotEmpty)
                    Text(
                      '@${user.username}',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            if (isCurrentUser)
              OutlinedButton.icon(
                onPressed: () => context.push('/profile/edit'),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit'),
              ),
          ],
        ),
        if (user.bio != null) ...[const SizedBox(height: 14), Text(user.bio!)],
        if (user.location != null || user.website != null) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              if (user.location != null)
                _Detail(
                  icon: Icons.location_on_outlined,
                  label: user.location!,
                ),
              if (user.website != null)
                _Detail(icon: Icons.link, label: user.website!),
            ],
          ),
        ],
      ],
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icon, size: 18), const SizedBox(width: 5), Text(label)],
    );
  }
}

class _ProfileTabsDelegate extends SliverPersistentHeaderDelegate {
  const _ProfileTabsDelegate();

  @override
  double get minExtent => 48;

  @override
  double get maxExtent => 48;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: const TabBar(
        tabs: [
          Tab(text: 'Posts'),
          Tab(text: 'Photos'),
          Tab(text: 'Friends'),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _ProfileTabsDelegate oldDelegate) => false;
}

class _ProfileLoading extends StatelessWidget {
  const _ProfileLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _ProfileError extends StatelessWidget {
  const _ProfileError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

Future<void> _showAvatarActions(
  BuildContext context,
  WidgetRef ref,
  UserProfile user,
) async {
  final action = await showModalBottomSheet<_AvatarAction>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: const Text('Take photo'),
            onTap: () => context.pop(_AvatarAction.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from library'),
            onTap: () => context.pop(_AvatarAction.library),
          ),
          if (user.avatarUrl != null)
            ListTile(
              leading: const Icon(Icons.visibility_outlined),
              title: const Text('View current photo'),
              onTap: () => context.pop(_AvatarAction.view),
            ),
        ],
      ),
    ),
  );
  if (!context.mounted || action == null) return;
  if (action == _AvatarAction.view) {
    await _viewAvatar(context, user.avatarUrl!);
    return;
  }
  await ref
      .read(profileMediaControllerProvider(ProfileMediaTarget.avatar).notifier)
      .select(
        action == _AvatarAction.camera
            ? ImageSource.camera
            : ImageSource.gallery,
      );
}

Future<void> _viewAvatar(BuildContext context, String url) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black,
    builder: (context) => Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain),
            ),
          ),
          SafeArea(
            child: IconButton.filled(
              tooltip: 'Close',
              onPressed: () => context.pop(),
              icon: const Icon(Icons.close),
            ),
          ),
        ],
      ),
    ),
  );
}

enum _AvatarAction { camera, library, view }

String _initials(String value) {
  final words = value.trim().split(RegExp(r'\s+'));
  if (words.isEmpty || words.first.isEmpty) return 'K';
  return words.take(2).map((word) => word[0].toUpperCase()).join();
}
