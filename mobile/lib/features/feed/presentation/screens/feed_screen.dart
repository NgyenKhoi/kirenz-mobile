import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../auth/presentation/controllers/session_controller.dart';
import '../../../friends/presentation/controllers/friends_controller.dart';
import '../../../posts/domain/entities/post.dart';
import '../../../posts/domain/entities/post_draft.dart';
import '../../../posts/data/repositories/post_repository.dart';
import '../../../posts/presentation/controllers/post_composer_controller.dart';
import '../../../posts/presentation/widgets/post_card.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../../shared/widgets/content_frame.dart';
import '../controllers/feed_controller.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(feedControllerProvider);
    final session = ref.watch(sessionControllerProvider);
    final controller = ref.read(feedControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'MOMENTS',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Create post',
        onPressed: () => _openComposer(context, ref),
        child: const Icon(Icons.edit_outlined),
      ),
      body: KirenzContentFrame(
        child: RefreshIndicator(
        onRefresh: () => controller.load(refresh: true),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
              sliver: SliverToBoxAdapter(
                child: _CreateEntry(
                  avatarUrl: session.user?.avatarUrl,
                  name: session.user?.displayName ?? 'there',
                  onTap: () => _openComposer(context, ref),
                ),
              ),
            ),
            if (state.isCached)
              SliverToBoxAdapter(
                child: _FeedNotice(
                  message: 'Showing saved posts while offline.',
                  action: 'Refresh',
                  onAction: () => controller.load(refresh: true),
                ),
              ),
            if (state.error != null && state.posts.isNotEmpty)
              SliverToBoxAdapter(
                child: _FeedNotice(
                  message: state.error!,
                  action: 'Retry',
                  error: true,
                  onAction: () => controller.load(refresh: true),
                ),
              ),
            if (state.message != null)
              SliverToBoxAdapter(child: _FeedNotice(message: state.message!)),
            if (state.loading && state.posts.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList.list(
                  children: const [
                    _PostSkeleton(),
                    SizedBox(height: 16),
                    _PostSkeleton(),
                    SizedBox(height: 16),
                    _PostSkeleton(),
                  ],
                ),
              )
            else if (state.error != null && state.posts.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: KirenzStateView(
                  icon: Icons.cloud_off_outlined,
                  title: 'Could not load posts',
                  message: state.error!,
                  actionLabel: 'Retry',
                  isError: true,
                  onAction: controller.load,
                ),
              )
            else if (state.posts.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _FeedEmpty(
                  icon: Icons.auto_awesome_outlined,
                  title: 'Your first moment starts here',
                  message: 'Create a post or discover people to follow.',
                  action: 'Create post',
                  onAction: () => _openComposer(context, ref),
                  secondaryAction: () => context.go('/explore'),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.only(top: 4, bottom: 24),
                sliver: SliverList.separated(
                  itemCount: state.posts.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final post = state.posts[index];
                    return PostCard(
                      key: ValueKey(post.id),
                      post: post,
                      currentUserId: session.user?.id,
                      pending: state.pendingPostIds.contains(post.id),
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
                  },
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }

  Future<void> _openComposer(BuildContext context, WidgetRef ref) async {
    final post = await showModalBottomSheet<Post>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const _PostComposerSheet(),
    );
    if (post != null) {
      await ref.read(feedControllerProvider.notifier).insertCreated(post);
    }
  }
}

class _CreateEntry extends StatelessWidget {
  const _CreateEntry({
    required this.avatarUrl,
    required this.name,
    required this.onTap,
  });

  final String? avatarUrl;
  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          KirenzUserAvatar(name: name, imageUrl: avatarUrl),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton(
              onPressed: onTap,
              child: const Align(
                alignment: Alignment.centerLeft,
                child: Text('Share a moment...'),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Add photos',
            onPressed: onTap,
            icon: const Icon(Icons.photo_outlined),
          ),
        ],
      ),
    ),
  );
}

class _PostComposerSheet extends ConsumerStatefulWidget {
  const _PostComposerSheet();

  @override
  ConsumerState<_PostComposerSheet> createState() => _PostComposerSheetState();
}

class _PostComposerSheetState extends ConsumerState<_PostComposerSheet> {
  final _content = TextEditingController();
  final _tagSearch = TextEditingController();
  String _tagQuery = '';

  @override
  void dispose() {
    _content.dispose();
    _tagSearch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(postComposerControllerProvider);
    final controller = ref.read(postComposerControllerProvider.notifier);
    final friends = ref.watch(friendsProvider(null));
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .88,
        child: Column(
          children: [
            AppBar(
              automaticallyImplyLeading: false,
              title: const Text('Create post'),
              leading: IconButton(
                tooltip: 'Close',
                onPressed: state.submitting ? null : () => context.pop(),
                icon: const Icon(Icons.close),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: FilledButton(
                    onPressed: state.canSubmit ? _confirmAndSubmit : null,
                    child: state.submitting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Post'),
                  ),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextField(
                    controller: _content,
                    minLines: 4,
                    maxLines: 10,
                    autofocus: true,
                    onChanged: controller.updateContent,
                    decoration: const InputDecoration(
                      hintText: "What's making you smile?",
                      border: InputBorder.none,
                    ),
                  ),
                  DropdownButtonFormField<PostPrivacy>(
                    initialValue: state.privacy,
                    decoration: const InputDecoration(
                      labelText: 'Who can see this?',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: PostPrivacy.public,
                        child: Text('Public'),
                      ),
                      DropdownMenuItem(
                        value: PostPrivacy.friends,
                        child: Text('Friends'),
                      ),
                      DropdownMenuItem(
                        value: PostPrivacy.onlyMe,
                        child: Text('Only me'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) controller.updatePrivacy(value);
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: state.submitting ? null : _pickImages,
                          icon: const Icon(Icons.photo_library_outlined),
                          label: Text(
                            state.images.isEmpty
                                ? 'Add photos'
                                : '${state.images.length}/10 photos',
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (state.images.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 6,
                            mainAxisSpacing: 6,
                          ),
                      itemCount: state.images.length,
                      itemBuilder: (context, index) {
                        final image = state.images[index];
                        return _DraftImageTile(
                          image: image,
                          onRemove: () => controller.removeImage(image.path),
                          onRetry: () => controller.retryImage(image.path),
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                  friends.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (_, _) => const Text(
                      'Friend tagging is temporarily unavailable.',
                    ),
                    data: (items) {
                      final query = _tagQuery.trim().toLowerCase();
                      final visible = query.isEmpty
                          ? items
                          : items
                                .where(
                                  (friend) =>
                                      friend.resolvedName
                                          .toLowerCase()
                                          .contains(query) ||
                                      (friend.username ?? '')
                                          .toLowerCase()
                                          .contains(query),
                                )
                                .toList(growable: false);
                      final selected = items
                          .where(
                            (friend) =>
                                state.taggedUserIds.contains(friend.friendId),
                          )
                          .toList(growable: false);
                      return ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: Text(
                          state.taggedUserIds.isEmpty
                              ? 'Tag friends'
                              : '${state.taggedUserIds.length} friends tagged',
                        ),
                        children: [
                          if (selected.isNotEmpty)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: selected
                                    .map(
                                      (friend) => InputChip(
                                        label: Text(friend.resolvedName),
                                        onDeleted: state.submitting
                                            ? null
                                            : () => controller.toggleTaggedUser(
                                                friend.friendId,
                                              ),
                                      ),
                                    )
                                    .toList(growable: false),
                              ),
                            ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _tagSearch,
                            enabled: !state.submitting,
                            onChanged: (value) =>
                                setState(() => _tagQuery = value),
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search),
                              hintText: 'Search friends',
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (visible.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('No matching friends'),
                            )
                          else
                            ...visible.map(
                              (friend) => CheckboxListTile(
                                value: state.taggedUserIds.contains(
                                  friend.friendId,
                                ),
                                title: Text(friend.resolvedName),
                                subtitle: friend.username?.isNotEmpty == true
                                    ? Text('@${friend.username}')
                                    : null,
                                onChanged: state.submitting
                                    ? null
                                    : (_) => controller.toggleTaggedUser(
                                        friend.friendId,
                                      ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  if (state.error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      state.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImages() async {
    final selected = await ImagePicker().pickMultiImage(imageQuality: 92);
    if (!mounted || selected.isEmpty) return;
    final images = <PostDraftImage>[];
    for (final file in selected) {
      final extension = file.name.split('.').last.toLowerCase();
      final contentType = switch (extension) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'gif' => 'image/gif',
        'webp' => 'image/webp',
        'heic' => 'image/heic',
        _ => 'application/octet-stream',
      };
      images.add(
        PostDraftImage(
          path: file.path,
          name: file.name,
          bytes: await file.length(),
          contentType: contentType,
        ),
      );
    }
    if (mounted) {
      ref.read(postComposerControllerProvider.notifier).addImages(images);
    }
  }

  Future<void> _confirmAndSubmit() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share this moment?'),
        content: const Text('Your post will use the selected privacy setting.'),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => context.pop(true),
            child: const Text('Post'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final post = await ref
        .read(postComposerControllerProvider.notifier)
        .submit();
    if (post != null && mounted) context.pop(post);
  }
}

class _DraftImageTile extends StatelessWidget {
  const _DraftImageTile({
    required this.image,
    required this.onRemove,
    required this.onRetry,
  });

  final PostDraftImage image;
  final VoidCallback onRemove;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: Stack(
      fit: StackFit.expand,
      children: [
        Image.file(File(image.path), fit: BoxFit.cover),
        if (image.status == PostImageStatus.uploading)
          ColoredBox(
            color: Colors.black45,
            child: Center(
              child: CircularProgressIndicator(value: image.progress),
            ),
          ),
        if (image.status == PostImageStatus.failed)
          Material(
            color: Theme.of(context).colorScheme.errorContainer,
            child: InkWell(
              onTap: onRetry,
              child: const Center(child: Text('Retry')),
            ),
          ),
        Positioned(
          right: 0,
          top: 0,
          child: IconButton.filled(
            tooltip: 'Remove image',
            onPressed: onRemove,
            icon: const Icon(Icons.close, size: 18),
          ),
        ),
      ],
    ),
  );
}

class _PostSkeleton extends StatelessWidget {
  const _PostSkeleton();

  @override
  Widget build(BuildContext context) => Container(
    height: 280,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(28),
    ),
  );
}

class _FeedNotice extends StatelessWidget {
  const _FeedNotice({
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
          : Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(16),
      child: ListTile(
        dense: true,
        title: Text(message),
        trailing: onAction == null
            ? null
            : TextButton(onPressed: onAction, child: Text(action!)),
      ),
    ),
  );
}

class _FeedEmpty extends StatelessWidget {
  const _FeedEmpty({
    required this.icon,
    required this.title,
    required this.message,
    required this.action,
    required this.onAction,
    this.secondaryAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String action;
  final VoidCallback onAction;
  final VoidCallback? secondaryAction;

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
          const SizedBox(height: 18),
          FilledButton(onPressed: onAction, child: Text(action)),
          if (secondaryAction != null)
            TextButton(
              onPressed: secondaryAction,
              child: const Text('Explore'),
            ),
        ],
      ),
    ),
  );
}
