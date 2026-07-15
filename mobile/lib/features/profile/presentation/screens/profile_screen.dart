import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../auth/presentation/controllers/session_controller.dart';
import '../../../blocks/presentation/controllers/block_controller.dart';
import '../../../friends/domain/entities/friend_models.dart';
import '../../../friends/presentation/controllers/friends_controller.dart';
import '../../data/repositories/profile_repository.dart';
import '../../domain/entities/user_profile.dart';
import '../controllers/profile_access_controller.dart';
import '../controllers/profile_media_controller.dart';
import '../widgets/profile_content_tabs.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({this.userId, super.key});

  final String? userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCurrentUser = userId == null;
    final currentProfile = isCurrentUser
        ? ref.watch(currentUserProfileProvider)
        : null;
    final access = isCurrentUser
        ? null
        : ref.watch(profileAccessProvider(userId!));

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
            if (!isCurrentUser && access?.value != null)
              _ProfileActionsMenu(
                userId: userId!,
                displayName: access!.value!.profile?.displayName,
                access: access.value!,
              ),
          ],
        ),
        body: SafeArea(
          child: isCurrentUser
              ? currentProfile!.when(
                  data: (user) => _ProfileContent(
                    user: user,
                    isCurrentUser: true,
                    relationship: RelationshipStatus.self,
                    onRefresh: () => _refresh(ref, true),
                  ),
                  loading: () => const _ProfileLoading(),
                  error: (error, stackTrace) => _ProfileError(
                    message: error.toString(),
                    onRetry: () => _invalidate(ref, true),
                  ),
                )
              : access!.when(
                  data: (value) => value.profile == null
                      ? _RestrictedProfile(userId: userId!, access: value)
                      : _ProfileContent(
                          user: value.profile!,
                          isCurrentUser: false,
                          relationship: value.relationship,
                          onRefresh: () => _refresh(ref, false),
                        ),
                  loading: () => const _ProfileLoading(),
                  error: (error, stackTrace) => _ProfileError(
                    message: error.toString(),
                    onRetry: () => _invalidate(ref, false),
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
      await ref.read(profileAccessProvider(userId!).future);
    }
  }

  void _invalidate(WidgetRef ref, bool isCurrentUser) {
    if (isCurrentUser) {
      ref.invalidate(currentUserProfileProvider);
    } else {
      ref.invalidate(profileAccessProvider(userId!));
    }
  }
}

class _ProfileContent extends ConsumerWidget {
  const _ProfileContent({
    required this.user,
    required this.isCurrentUser,
    required this.relationship,
    required this.onRefresh,
  });

  final UserProfile user;
  final bool isCurrentUser;
  final RelationshipStatus relationship;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cached = ref.watch(profileCacheStatusProvider(user.id));
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
                  if (cached != null)
                    _ProfileCachedNotice(updatedAt: cached.updatedAt),
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
                      relationship: relationship,
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

class _ProfileCachedNotice extends StatelessWidget {
  const _ProfileCachedNotice({required this.updatedAt});

  final DateTime updatedAt;

  @override
  Widget build(BuildContext context) {
    final time = updatedAt.toLocal();
    return Semantics(
      liveRegion: true,
      child: Material(
        color: Theme.of(context).colorScheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.cloud_off_outlined, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Showing saved profile from ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}. Pull to retry.',
                ),
              ),
            ],
          ),
        ),
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
  const _ProfileDetails({
    required this.user,
    required this.isCurrentUser,
    required this.relationship,
  });

  final UserProfile user;
  final bool isCurrentUser;
  final RelationshipStatus relationship;

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
        if (!isCurrentUser) ...[
          const SizedBox(height: 16),
          _RelationshipActions(
            userId: user.id,
            displayName: user.displayName,
            relationship: relationship,
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
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 5),
        Flexible(child: Text(label)),
      ],
    );
  }
}

class _RelationshipActions extends ConsumerWidget {
  const _RelationshipActions({
    required this.userId,
    required this.relationship,
    this.displayName,
  });

  final String userId;
  final RelationshipStatus relationship;
  final String? displayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(friendActionControllerProvider).contains(userId);
    final actions = ref.read(friendActionControllerProvider.notifier);
    Future<void> run(Future<void> Function() action) =>
        _showProfileActionError(context, action);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: switch (relationship) {
        RelationshipStatus.none => [
          FilledButton.icon(
            onPressed: pending
                ? null
                : () => run(() => actions.sendRequest(userId)),
            icon: const Icon(Icons.person_add_outlined),
            label: const Text('Add friend'),
          ),
        ],
        RelationshipStatus.outgoingRequest => [
          OutlinedButton.icon(
            onPressed: pending
                ? null
                : () => run(() => actions.cancelRequestForUser(userId)),
            icon: const Icon(Icons.person_remove_outlined),
            label: const Text('Cancel request'),
          ),
        ],
        RelationshipStatus.incomingRequest => [
          FilledButton.icon(
            onPressed: pending
                ? null
                : () => run(() => actions.acceptRequestForUser(userId)),
            icon: const Icon(Icons.check),
            label: const Text('Accept'),
          ),
          OutlinedButton(
            onPressed: pending
                ? null
                : () => run(() => actions.declineRequestForUser(userId)),
            child: const Text('Decline'),
          ),
        ],
        RelationshipStatus.friends => [
          OutlinedButton.icon(
            onPressed: pending
                ? null
                : () => _confirmRemoveFriend(context, ref, userId, displayName),
            icon: const Icon(Icons.people_outline),
            label: const Text('Friends'),
          ),
        ],
        RelationshipStatus.blocked => [const Chip(label: Text('Blocked'))],
        RelationshipStatus.blockedByTarget => [
          const Chip(label: Text('Unavailable')),
        ],
        RelationshipStatus.unsupported => [
          const Chip(label: Text('Unavailable')),
        ],
        RelationshipStatus.self => <Widget>[],
      },
    );
  }
}

class _RestrictedProfile extends ConsumerWidget {
  const _RestrictedProfile({required this.userId, required this.access});

  final String userId;
  final ProfileAccess access;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(blockActionControllerProvider).contains(userId);
    if (access.blockedByViewer) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.block_outlined, size: 52),
              const SizedBox(height: 12),
              Text(
                'You blocked this user',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Unblock to let visibility and interactions follow privacy settings again.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: pending
                    ? null
                    : () => _confirmProfileUnblock(context, ref, userId, null),
                child: const Text('Unblock'),
              ),
            ],
          ),
        ),
      );
    }
    if (access.blockedViewer) {
      return const _UnavailableProfile(
        icon: Icons.person_off_outlined,
        title: 'Profile unavailable',
        message: 'You cannot view or interact with this profile.',
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 52),
            const SizedBox(height: 12),
            Text(
              'This profile is private',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Profile details are visible according to this user’s privacy settings.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            _RelationshipActions(
              userId: userId,
              relationship: access.relationship,
            ),
          ],
        ),
      ),
    );
  }
}

class _UnavailableProfile extends StatelessWidget {
  const _UnavailableProfile({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class _ProfileActionsMenu extends ConsumerWidget {
  const _ProfileActionsMenu({
    required this.userId,
    required this.displayName,
    required this.access,
  });
  final String userId;
  final String? displayName;
  final ProfileAccess access;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (access.blockedViewer) return const SizedBox.shrink();
    final pending = ref.watch(blockActionControllerProvider).contains(userId);
    return PopupMenuButton<_ProfileMenuAction>(
      tooltip: 'User actions',
      enabled: !pending,
      onSelected: (action) {
        if (action == _ProfileMenuAction.block) {
          _confirmProfileBlock(context, ref, userId, displayName);
        } else {
          _confirmProfileUnblock(context, ref, userId, displayName);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: access.blockedByViewer
              ? _ProfileMenuAction.unblock
              : _ProfileMenuAction.block,
          child: Row(
            children: [
              Icon(
                access.blockedByViewer
                    ? Icons.lock_open_outlined
                    : Icons.block_outlined,
              ),
              const SizedBox(width: 12),
              Text(access.blockedByViewer ? 'Unblock' : 'Block'),
            ],
          ),
        ),
      ],
    );
  }
}

enum _ProfileMenuAction { block, unblock }

Future<void> _confirmRemoveFriend(
  BuildContext context,
  WidgetRef ref,
  String userId,
  String? displayName,
) async {
  final name = displayName?.trim().isNotEmpty == true ? displayName! : userId;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Remove $name?'),
      content: const Text('You will no longer be friends.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Keep friend'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Remove'),
        ),
      ],
    ),
  );
  if (confirmed == true && context.mounted) {
    await _showProfileActionError(
      context,
      () => ref
          .read(friendActionControllerProvider.notifier)
          .removeFriend(userId),
    );
  }
}

Future<void> _confirmProfileBlock(
  BuildContext context,
  WidgetRef ref,
  String userId,
  String? displayName,
) async {
  final name = displayName?.trim().isNotEmpty == true ? displayName! : userId;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Block $name?'),
      content: Text(
        '$name will no longer be able to find, view, or interact with you. Shared group conversations may still remain visible.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Block'),
        ),
      ],
    ),
  );
  if (confirmed == true && context.mounted) {
    await _showProfileActionError(
      context,
      () => ref.read(blockActionControllerProvider.notifier).block(userId),
    );
  }
}

Future<void> _confirmProfileUnblock(
  BuildContext context,
  WidgetRef ref,
  String userId,
  String? displayName,
) async {
  final name = displayName?.trim().isNotEmpty == true ? displayName! : userId;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Unblock $name?'),
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
  if (confirmed == true && context.mounted) {
    await _showProfileActionError(
      context,
      () => ref.read(blockActionControllerProvider.notifier).unblock(userId),
    );
  }
}

Future<void> _showProfileActionError(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } on Object catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
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
