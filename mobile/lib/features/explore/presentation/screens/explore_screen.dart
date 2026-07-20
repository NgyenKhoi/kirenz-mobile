import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/controllers/session_controller.dart';
import '../../../feed/presentation/controllers/feed_controller.dart';
import '../../../friends/domain/entities/friend_models.dart';
import '../../../friends/presentation/controllers/friends_controller.dart';
import '../../../posts/data/repositories/post_repository.dart';
import '../../../posts/presentation/widgets/post_card.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../../shared/widgets/content_frame.dart';
import '../controllers/explore_controller.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({this.initialQuery, super.key});

  final String? initialQuery;

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _applyInitialQuery();
  }

  @override
  void didUpdateWidget(covariant ExploreScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialQuery != oldWidget.initialQuery) _applyInitialQuery();
  }

  void _applyInitialQuery() {
    final value = widget.initialQuery?.trim() ?? '';
    if (value.isEmpty) return;
    _search.text = value;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref
            .read(exploreControllerProvider.notifier)
            .setQuery(value, debounce: false);
      }
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final explore = ref.watch(exploreControllerProvider);
    final feed = ref.watch(feedControllerProvider);
    final session = ref.watch(sessionControllerProvider);
    final exploreController = ref.read(exploreControllerProvider.notifier);
    final feedController = ref.read(feedControllerProvider.notifier);
    if (_search.text != explore.query) {
      _search.value = TextEditingValue(
        text: explore.query,
        selection: TextSelection.collapsed(offset: explore.query.length),
      );
    }
    final trending = trendingExploreHashtags(feed.posts);
    final related = relatedExplorePosts(feed.posts, explore.submittedQuery);
    return Scaffold(
      appBar: AppBar(title: const Text('Explore')),
      body: KirenzContentFrame(
        child: RefreshIndicator(
        onRefresh: () async {
          await feedController.load(refresh: true);
          if (explore.hasValidQuery) await exploreController.refreshPeople();
        },
        child: CustomScrollView(
          key: const PageStorageKey('explore-scroll'),
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              sliver: SliverToBoxAdapter(
                child: SearchBar(
                  controller: _search,
                  hintText: 'Search people, posts, or #hashtags',
                  leading: const Icon(Icons.search),
                  trailing: [
                    if (explore.query.isNotEmpty)
                      IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _search.clear();
                          exploreController.setQuery('', debounce: false);
                        },
                        icon: const Icon(Icons.close),
                      ),
                  ],
                  textInputAction: TextInputAction.search,
                  onChanged: exploreController.setQuery,
                  onSubmitted: (_) => exploreController.submit(),
                ),
              ),
            ),
            if (feed.isCached)
              SliverToBoxAdapter(
                child: _ExploreNotice(
                  message: 'Showing saved posts while offline.',
                  action: 'Refresh',
                  onAction: () => feedController.load(refresh: true),
                ),
              ),
            if (feed.error != null && feed.posts.isNotEmpty)
              SliverToBoxAdapter(
                child: _ExploreNotice(
                  message: feed.error!,
                  action: 'Retry',
                  error: true,
                  onAction: () => feedController.load(refresh: true),
                ),
              ),
            if (feed.loading && feed.posts.isEmpty)
              const SliverPadding(
                padding: EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(
                  child: SizedBox(
                    height: 360,
                    child: KirenzSkeletonList(itemCount: 3, itemHeight: 104),
                  ),
                ),
              )
            else if (feed.error != null && feed.posts.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: KirenzStateView(
                  icon: Icons.cloud_off_outlined,
                  title: 'Could not load Explore',
                  message: feed.error!,
                  actionLabel: 'Retry',
                  isError: true,
                  onAction: feedController.load,
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: _TrendingSection(
                    hashtags: trending,
                    onSelected: (tag) {
                      final query = '#$tag';
                      _search.text = query;
                      exploreController.setQuery(query, debounce: false);
                    },
                  ),
                ),
              ),
              if (!explore.hasValidQuery)
                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 32),
                  sliver: SliverToBoxAdapter(
                    child: Card(
                      child: KirenzStateView(
                        icon: Icons.manage_search_outlined,
                        title: 'Discover Kirenz',
                        message:
                            'Enter at least two characters to find people and related posts.',
                      ),
                    ),
                  ),
                )
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      'People',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
                _PeopleResults(
                  state: explore,
                  onRetry: exploreController.refreshPeople,
                  onActionComplete: exploreController.refreshPeople,
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 22, 16, 8),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      'Related posts',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
                if (related.isEmpty)
                  const SliverPadding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 32),
                    sliver: SliverToBoxAdapter(
                      child: _ExploreState(
                        icon: Icons.article_outlined,
                        title: 'No related posts',
                        message: 'Try another word or hashtag.',
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    sliver: SliverList.separated(
                      itemCount: related.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final post = related[index];
                        return PostCard(
                          key: ValueKey('explore-${post.id}'),
                          post: post,
                          currentUserId: session.user?.id,
                          pending: feed.pendingPostIds.contains(post.id),
                          onEdit: (content, privacy, media) =>
                              feedController.update(
                                post: post,
                                content: content,
                                privacy: privacy,
                                media: media,
                              ),
                          onDelete: () async {
                            await feedController.delete(post);
                          },
                          onShare: (caption) =>
                              feedController.share(post, caption),
                          onReact: (reaction) =>
                              feedController.react(post, reaction),
                          onUploadImage: (image, onProgress) => ref
                              .read(postRepositoryProvider)
                              .uploadImage(
                                image,
                                onProgress: (sent, total) =>
                                    onProgress(total <= 0 ? 0 : sent / total),
                              ),
                        );
                      },
                    ),
                  ),
              ],
            ],
          ],
        ),
      ),
      ),
    );
  }
}

class _TrendingSection extends StatelessWidget {
  const _TrendingSection({required this.hashtags, required this.onSelected});

  final List<MapEntry<String, int>> hashtags;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Trending hashtags', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 10),
      if (hashtags.isEmpty)
        const Text('No hashtags yet. Pull to refresh when posts are available.')
      else
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in hashtags)
              ActionChip(
                tooltip: 'Search #${entry.key}',
                label: Text('#${entry.key} · ${entry.value}'),
                onPressed: () => onSelected(entry.key),
              ),
          ],
        ),
    ],
  );
}

class _PeopleResults extends ConsumerWidget {
  const _PeopleResults({
    required this.state,
    required this.onRetry,
    required this.onActionComplete,
  });

  final ExploreState state;
  final Future<void> Function() onRetry;
  final Future<void> Function() onActionComplete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.peopleLoading) {
      return const SliverToBoxAdapter(child: LinearProgressIndicator());
    }
    if (state.peopleError != null) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverToBoxAdapter(
          child: _ExploreState(
            icon: Icons.person_search_outlined,
            title: 'People search failed',
            message: state.peopleError!,
            action: 'Retry',
            onAction: onRetry,
          ),
        ),
      );
    }
    if (state.people.isEmpty) {
      return const SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverToBoxAdapter(
          child: _ExploreState(
            icon: Icons.person_off_outlined,
            title: 'No people found',
            message: 'Try a different name or username.',
          ),
        ),
      );
    }
    final pending = ref.watch(friendActionControllerProvider);
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList.separated(
        itemCount: state.people.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
        final user = state.people[index];
        return Card(
          child: ListTile(
            leading: KirenzUserAvatar(
              name: user.resolvedName,
              imageUrl: user.avatarUrl,
            ),
          title: Text(user.resolvedName),
          subtitle: Text(
            [
              if (user.username.isNotEmpty) '@${user.username}',
              if (user.bio?.trim().isNotEmpty == true) user.bio!.trim(),
            ].join(' · '),
          ),
            onTap: () => context.push(
            user.relationshipStatus == RelationshipStatus.self
                ? '/profile/me'
                : '/profile/${user.id}',
          ),
            trailing: _RelationshipAction(
            user: user,
            pending: pending.contains(user.id),
            onComplete: onActionComplete,
            ),
          ),
        );
        },
      ),
    );
  }
}

class _RelationshipAction extends ConsumerWidget {
  const _RelationshipAction({
    required this.user,
    required this.pending,
    required this.onComplete,
  });

  final UserSearchResult user;
  final bool pending;
  final Future<void> Function() onComplete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (user.relationshipStatus == RelationshipStatus.self) {
      return const Text('You');
    }
    if (user.relationshipStatus == RelationshipStatus.blockedByTarget) {
      return const Text('Unavailable');
    }
    if (user.relationshipStatus == RelationshipStatus.blocked) {
      return const Text('Blocked');
    }
    if (user.relationshipStatus == RelationshipStatus.unsupported) {
      return const Text('Unavailable');
    }
    final controller = ref.read(friendActionControllerProvider.notifier);
    Future<void> run(Future<void> Function() action) async {
      try {
        await action();
        await onComplete();
      } on Object catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error.toString())));
        }
      }
    }

    if (pending) {
      return const SizedBox.square(
        dimension: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return switch (user.relationshipStatus) {
      RelationshipStatus.none => FilledButton.tonal(
        onPressed: () => run(() => controller.sendRequest(user.id)),
        child: const Text('Add'),
      ),
      RelationshipStatus.outgoingRequest => TextButton(
        onPressed: () => run(() => controller.cancelRequestForUser(user.id)),
        child: const Text('Cancel'),
      ),
      RelationshipStatus.incomingRequest => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: () =>
                run(() => controller.declineRequestForUser(user.id)),
            child: const Text('Decline'),
          ),
          FilledButton.tonal(
            onPressed: () =>
                run(() => controller.acceptRequestForUser(user.id)),
            child: const Text('Accept'),
          ),
        ],
      ),
      RelationshipStatus.friends => TextButton(
        onPressed: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Remove ${user.resolvedName}?'),
              content: const Text('They will be removed from your friends.'),
              actions: [
                TextButton(
                  onPressed: () => context.pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => context.pop(true),
                  child: const Text('Remove'),
                ),
              ],
            ),
          );
          if (confirmed == true) {
            await run(() => controller.removeFriend(user.id));
          }
        },
        child: const Text('Friends'),
      ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _ExploreNotice extends StatelessWidget {
  const _ExploreNotice({
    required this.message,
    this.action,
    this.onAction,
    this.error = false,
  });

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
        leading: Icon(error ? Icons.error_outline : Icons.cloud_off_outlined),
        title: Text(message),
        trailing: onAction == null
            ? null
            : TextButton(onPressed: onAction, child: Text(action!)),
      ),
    ),
  );
}

class _ExploreState extends StatelessWidget {
  const _ExploreState({
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
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42),
          const SizedBox(height: 10),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(message, textAlign: TextAlign.center),
          if (onAction != null) ...[
            const SizedBox(height: 12),
            FilledButton(onPressed: onAction, child: Text(action!)),
          ],
        ],
      ),
    ),
  );
}
