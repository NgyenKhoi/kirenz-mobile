import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/media_viewer.dart';
import '../../../auth/presentation/controllers/session_controller.dart';
import '../../../feed/presentation/controllers/feed_controller.dart';
import '../../../friends/presentation/controllers/friends_controller.dart';
import '../../../posts/data/repositories/post_repository.dart';
import '../../../posts/domain/entities/post.dart';
import '../../../posts/presentation/widgets/post_card.dart';
import '../../data/repositories/profile_content_repository.dart';
import '../../domain/entities/profile_photo.dart';

class ProfilePostsTab extends ConsumerStatefulWidget {
  const ProfilePostsTab({required this.userId, super.key});

  final String userId;

  @override
  ConsumerState<ProfilePostsTab> createState() => _ProfilePostsTabState();
}

class _ProfilePostsTabState extends ConsumerState<ProfilePostsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final posts = ref.watch(profilePostsProvider(widget.userId));
    return posts.when(
      data: (result) {
        final items = result.data;
        if (items.isEmpty) {
          return Column(
            children: [
              if (result.isCached) _CachedNotice(cachedAt: result.cachedAt),
              Expanded(
                child: _RefreshableState(
                  key: PageStorageKey('profile-posts-${widget.userId}'),
                  icon: Icons.article_outlined,
                  title: 'No posts yet',
                  onRefresh: _refresh,
                ),
              ),
            ],
          );
        }
        return Column(
          children: [
            if (result.isCached) _CachedNotice(cachedAt: result.cachedAt),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.separated(
                  key: PageStorageKey('profile-posts-${widget.userId}'),
                  padding: const EdgeInsets.only(top: 8, bottom: 24),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) =>
                      _UnifiedProfilePostCard(post: items[index]),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => ListView.separated(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        itemCount: 3,
        separatorBuilder: (context, index) => const SizedBox(height: 14),
        itemBuilder: (context, index) => const _PostSkeleton(),
      ),
      error: (error, stackTrace) =>
          _RetryState(message: error.toString(), onRetry: _refresh),
    );
  }

  Future<void> _refresh() async {
    ref.invalidate(profilePostsProvider(widget.userId));
    await ref.read(profilePostsProvider(widget.userId).future);
  }
}

class ProfilePhotosTab extends ConsumerStatefulWidget {
  const ProfilePhotosTab({required this.userId, super.key});

  final String userId;

  @override
  ConsumerState<ProfilePhotosTab> createState() => _ProfilePhotosTabState();
}

class _ProfilePhotosTabState extends ConsumerState<ProfilePhotosTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final photos = ref.watch(profilePhotosProvider(widget.userId));
    return photos.when(
      data: (result) {
        final items = result.data;
        if (items.isEmpty) {
          return Column(
            children: [
              if (result.isCached) _CachedNotice(cachedAt: result.cachedAt),
              Expanded(
                child: _RefreshableState(
                  key: PageStorageKey('profile-photos-${widget.userId}'),
                  icon: Icons.photo_library_outlined,
                  title: 'No photos yet',
                  onRefresh: _refresh,
                ),
              ),
            ],
          );
        }
        final urls = items.map((item) => item.url).toList(growable: false);
        return Column(
          children: [
            if (result.isCached) _CachedNotice(cachedAt: result.cachedAt),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: LayoutBuilder(
                  builder: (context, constraints) => GridView.builder(
                    key: PageStorageKey('profile-photos-${widget.userId}'),
                    padding: const EdgeInsets.all(3),
                    physics: const AlwaysScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _photoColumns(constraints.maxWidth),
                      mainAxisSpacing: 3,
                      crossAxisSpacing: 3,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) => _PhotoTile(
                      photo: items[index],
                      index: index,
                      onTap: () => showMediaViewer(
                        context,
                        urls: urls,
                        initialIndex: index,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => LayoutBuilder(
        builder: (context, constraints) => GridView.builder(
          padding: const EdgeInsets.all(3),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _photoColumns(constraints.maxWidth),
            mainAxisSpacing: 3,
            crossAxisSpacing: 3,
          ),
          itemCount: 12,
          itemBuilder: (context, index) => ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
          ),
        ),
      ),
      error: (error, stackTrace) =>
          _RetryState(message: error.toString(), onRetry: _refresh),
    );
  }

  Future<void> _refresh() async {
    ref.invalidate(profilePhotosProvider(widget.userId));
    await ref.read(profilePhotosProvider(widget.userId).future);
  }
}

class ProfileFriendsTab extends ConsumerStatefulWidget {
  const ProfileFriendsTab({required this.userId, super.key});

  final String userId;

  @override
  ConsumerState<ProfileFriendsTab> createState() => _ProfileFriendsTabState();
}

class _ProfileFriendsTabState extends ConsumerState<ProfileFriendsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final friends = ref.watch(friendsProvider(widget.userId));
    return friends.when(
      loading: () => ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) => Container(
          height: 76,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      error: (error, stackTrace) =>
          _RetryState(message: error.toString(), onRetry: _refresh),
      data: (items) {
        if (items.isEmpty) {
          return _RefreshableState(
            key: PageStorageKey('profile-friends-${widget.userId}'),
            icon: Icons.people_outline,
            title: 'No visible friends',
            onRefresh: _refresh,
          );
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.separated(
            key: PageStorageKey('profile-friends-${widget.userId}'),
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final friend = items[index];
              return ListTile(
                tileColor: Theme.of(context).colorScheme.surfaceContainerLowest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                leading: CircleAvatar(
                  backgroundImage: friend.avatarUrl?.isNotEmpty == true
                      ? CachedNetworkImageProvider(friend.avatarUrl!)
                      : null,
                  child: friend.avatarUrl?.isNotEmpty == true
                      ? null
                      : Text(_initials(friend.resolvedName)),
                ),
                title: Text(
                  friend.resolvedName,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: friend.username?.isNotEmpty == true
                    ? Text('@${friend.username}')
                    : null,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/profile/${friend.friendId}'),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _refresh() async {
    ref.invalidate(friendsProvider(widget.userId));
    await ref.read(friendsProvider(widget.userId).future);
  }
}

class _UnifiedProfilePostCard extends ConsumerWidget {
  const _UnifiedProfilePostCard({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(feedControllerProvider);
    final controller = ref.read(feedControllerProvider.notifier);
    return PostCard(
      post: post,
      currentUserId: ref.watch(sessionControllerProvider).user?.id,
      pending: feed.pendingPostIds.contains(post.id),
      onEdit: (content, privacy, media) => controller.update(
        post: post,
        content: content,
        privacy: privacy,
        media: media,
      ),
      onDelete: () async {
        await controller.delete(post);
      },
      onShare: (caption) => controller.share(post, caption),
      onReact: (reaction) => controller.react(post, reaction),
      onUploadImage: (image, onProgress) => ref
          .read(postRepositoryProvider)
          .uploadImage(
            image,
            onProgress: (sent, total) =>
                onProgress(total <= 0 ? 0 : sent / total),
          ),
    );
  }
}

int _photoColumns(double width) => (width / 132).floor().clamp(3, 6).toInt();

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.photo,
    required this.index,
    required this.onTap,
  });

  final ProfilePhoto photo;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Open profile photo ${index + 1}',
      child: InkWell(
        onTap: onTap,
        child: CachedNetworkImage(
          imageUrl: photo.url,
          fit: BoxFit.cover,
          placeholder: (context, url) => ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
          ),
          errorWidget: (context, url, error) => ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            child: const Icon(Icons.broken_image_outlined),
          ),
        ),
      ),
    );
  }
}

class _PostSkeleton extends StatelessWidget {
  const _PostSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
      ),
    );
  }
}

class _CachedNotice extends StatelessWidget {
  const _CachedNotice({required this.cachedAt});

  final DateTime? cachedAt;

  @override
  Widget build(BuildContext context) {
    final time = cachedAt?.toLocal();
    final suffix = time == null
        ? ''
        : ' from ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
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
                child: Text('Showing saved content$suffix. Pull to retry.'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RefreshableState extends StatelessWidget {
  const _RefreshableState({
    required this.icon,
    required this.title,
    required this.onRefresh,
    super.key,
  });

  final IconData icon;
  final String title;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: 320,
            child: _StaticState(icon: icon, title: title),
          ),
        ],
      ),
    );
  }
}

class _RetryState extends StatelessWidget {
  const _RetryState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        Icon(
          Icons.cloud_off_outlined,
          size: 44,
          color: Theme.of(context).colorScheme.error,
        ),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        FilledButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}

class _StaticState extends StatelessWidget {
  const _StaticState({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44),
            const SizedBox(height: 10),
            Text(title, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

String _initials(String value) {
  final words = value.trim().split(RegExp(r'\s+'));
  if (words.isEmpty || words.first.isEmpty) return 'K';
  return words.take(2).map((word) => word[0].toUpperCase()).join();
}
