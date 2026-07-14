import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/media_viewer.dart';
import '../../../friends/presentation/controllers/friends_controller.dart';
import '../../../posts/domain/entities/post.dart';
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
      data: (items) {
        if (items.isEmpty) {
          return _RefreshableState(
            key: PageStorageKey('profile-posts-${widget.userId}'),
            icon: Icons.article_outlined,
            title: 'No posts yet',
            onRefresh: _refresh,
          );
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.separated(
            key: PageStorageKey('profile-posts-${widget.userId}'),
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 14),
            itemBuilder: (context, index) =>
                _ProfilePostCard(post: items[index]),
          ),
        );
      },
      loading: () => ListView.separated(
        padding: const EdgeInsets.all(16),
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
      data: (items) {
        if (items.isEmpty) {
          return _RefreshableState(
            key: PageStorageKey('profile-photos-${widget.userId}'),
            icon: Icons.photo_library_outlined,
            title: 'No photos yet',
            onRefresh: _refresh,
          );
        }
        final urls = items.map((item) => item.url).toList(growable: false);
        return RefreshIndicator(
          onRefresh: _refresh,
          child: GridView.builder(
            key: PageStorageKey('profile-photos-${widget.userId}'),
            padding: const EdgeInsets.all(3),
            physics: const AlwaysScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 3,
              crossAxisSpacing: 3,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) => _PhotoTile(
              photo: items[index],
              index: index,
              onTap: () =>
                  showMediaViewer(context, urls: urls, initialIndex: index),
            ),
          ),
        );
      },
      loading: () => GridView.builder(
        padding: const EdgeInsets.all(3),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 3,
          crossAxisSpacing: 3,
        ),
        itemCount: 12,
        itemBuilder: (context, index) => ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
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

class _ProfilePostCard extends StatelessWidget {
  const _ProfilePostCard({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final imageUrls = post.media
        .where((item) => item.type == PostMediaType.image)
        .map((item) => item.url)
        .toList(growable: false);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: post.author.avatarUrl == null
                      ? null
                      : CachedNetworkImageProvider(post.author.avatarUrl!),
                  child: post.author.avatarUrl == null
                      ? Text(_initials(post.author.resolvedName))
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.author.resolvedName,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '${_relativeTime(post.createdAt)} · ${_privacyLabel(post.privacy)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (post.content.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(post.content),
            ],
            if (post.sharedPost != null) ...[
              const SizedBox(height: 14),
              _SharedPostBlock(post: post.sharedPost!),
            ],
            if (imageUrls.isNotEmpty) ...[
              const SizedBox(height: 14),
              _PostImageGrid(urls: imageUrls),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.favorite_border, size: 18),
                const SizedBox(width: 5),
                Text('${post.reactionsCount}'),
                const SizedBox(width: 20),
                const Icon(Icons.chat_bubble_outline, size: 18),
                const SizedBox(width: 5),
                Text('${post.commentsCount}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SharedPostBlock extends StatelessWidget {
  const _SharedPostBlock({required this.post});

  final SharedPost post;

  @override
  Widget build(BuildContext context) {
    if (!post.available) {
      return const _StaticState(
        icon: Icons.visibility_off_outlined,
        title: 'Shared post unavailable',
        compact: true,
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              post.author?.resolvedName ?? 'Kirenz User',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            if (post.content != null) ...[
              const SizedBox(height: 8),
              Text(post.content!),
            ],
          ],
        ),
      ),
    );
  }
}

class _PostImageGrid extends StatelessWidget {
  const _PostImageGrid({required this.urls});

  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    if (urls.length == 1) {
      return AspectRatio(
        aspectRatio: 4 / 3,
        child: _PostImageTile(
          url: urls.first,
          onTap: () => showMediaViewer(context, urls: urls, initialIndex: 0),
        ),
      );
    }
    final visible = urls.take(4).toList(growable: false);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 3,
        crossAxisSpacing: 3,
      ),
      itemCount: visible.length,
      itemBuilder: (context, index) => Stack(
        fit: StackFit.expand,
        children: [
          _PostImageTile(
            url: visible[index],
            onTap: () =>
                showMediaViewer(context, urls: urls, initialIndex: index),
          ),
          if (index == 3 && urls.length > 4)
            IgnorePointer(
              child: ColoredBox(
                color: const Color(0x88000000),
                child: Center(
                  child: Text(
                    '+${urls.length - 4}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PostImageTile extends StatelessWidget {
  const _PostImageTile({required this.url, required this.onTap});

  final String url;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Open post photo',
      child: InkWell(
        onTap: onTap,
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          errorWidget: (context, url, error) => ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            child: const Icon(Icons.broken_image_outlined),
          ),
        ),
      ),
    );
  }
}

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
  const _StaticState({
    required this.icon,
    required this.title,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: compact ? 28 : 44),
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

String _relativeTime(DateTime? value) {
  if (value == null) return 'Unknown time';
  final difference = DateTime.now().difference(value.toLocal());
  if (difference.inMinutes < 1) return 'Just now';
  if (difference.inHours < 1) return '${difference.inMinutes}m';
  if (difference.inDays < 1) return '${difference.inHours}h';
  if (difference.inDays < 7) return '${difference.inDays}d';
  return '${value.toLocal().day}/${value.toLocal().month}/${value.toLocal().year}';
}

String _privacyLabel(PostPrivacy privacy) {
  return switch (privacy) {
    PostPrivacy.public => 'Public',
    PostPrivacy.friends => 'Friends',
    PostPrivacy.onlyMe => 'Only me',
  };
}
