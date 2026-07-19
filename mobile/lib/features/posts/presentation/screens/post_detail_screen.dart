import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/controllers/session_controller.dart';
import '../../../feed/presentation/controllers/feed_controller.dart';
import '../../../comments/presentation/widgets/discussion_section.dart';
import '../../../comments/data/repositories/discussion_repository.dart';
import '../../data/repositories/post_repository.dart';
import '../../domain/entities/post.dart';
import '../widgets/post_card.dart';

class PostDetailScreen extends ConsumerStatefulWidget {
  const PostDetailScreen({required this.postId, super.key});

  final String postId;

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  Post? _post;
  Object? _error;
  bool _loading = true;
  bool _pending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final cached = ref
        .read(feedControllerProvider)
        .posts
        .where((post) => post.id == widget.postId)
        .firstOrNull;
    if (cached != null && mounted) {
      setState(() {
        _post = cached;
        _loading = false;
      });
    }
    try {
      final canonical = await ref
          .read(postRepositoryProvider)
          .getById(widget.postId);
      if (mounted) {
        setState(() {
          _post = canonical;
          _loading = false;
          _error = null;
        });
      }
      await ref
          .read(feedControllerProvider.notifier)
          .reconcileCanonical(canonical);
    } on Object catch (error) {
      if (mounted && _post == null) {
        setState(() {
          _loading = false;
          _error = error;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final projected = ref
        .watch(feedControllerProvider)
        .posts
        .where((item) => item.id == widget.postId)
        .firstOrNull;
    final post = projected ?? _post;
    final userId = ref.watch(sessionControllerProvider).user?.id;
    return Scaffold(
      appBar: AppBar(title: const Text('Post')),
      bottomNavigationBar: post == null
          ? null
          : CommentComposer(postId: post.id),
      body: _loading && post == null
          ? const Center(child: CircularProgressIndicator())
          : post == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.visibility_off_outlined, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      _error?.toString() ?? 'This post is unavailable.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    FilledButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  PostCard(
                    post: post,
                    currentUserId: userId,
                    pending: _pending,
                    isDetail: true,
                    onEdit: (content, privacy, media) => _run(() async {
                      final updated = await ref
                          .read(postRepositoryProvider)
                          .update(
                            postId: post.id,
                            content: content,
                            privacy: privacy,
                            media: media,
                          );
                      setState(() => _post = updated);
                      await ref
                          .read(feedControllerProvider.notifier)
                          .reconcileCanonical(updated);
                    }),
                    onDelete: () async {
                      await _run(() async {
                        await ref.read(postRepositoryProvider).delete(post.id);
                        await ref
                            .read(feedControllerProvider.notifier)
                            .removeCanonical(post.id);
                        if (!mounted) return;
                        this.context.pop();
                      });
                    },
                    onShare: (caption) => _run(() async {
                      final shared = await ref
                          .read(postRepositoryProvider)
                          .share(post.id, caption);
                      await ref
                          .read(feedControllerProvider.notifier)
                          .insertCreated(shared);
                    }),
                    onReact: _reactPost,
                    onUploadImage: (image, onProgress) => ref
                        .read(postRepositoryProvider)
                        .uploadImage(
                          image,
                          onProgress: (sent, total) =>
                              onProgress(total <= 0 ? 0 : sent / total),
                        ),
                  ),
                  const SizedBox(height: 18),
                  DiscussionSection(postId: post.id, currentUserId: userId),
                ],
              ),
            ),
    );
  }

  Future<bool> _run(Future<void> Function() action) async {
    if (_pending) return false;
    setState(() => _pending = true);
    try {
      await action();
      return true;
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
      return false;
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  Future<bool> _reactPost(ReactionType selected) => _run(() async {
    final post = _post!;
    final current = post.reactionSummary.currentUserReaction;
    final repository = ref.read(discussionRepositoryProvider);
    final summary = selected == current
        ? await repository.removePostReaction(post.id)
        : await repository.reactToPost(
            postId: post.id,
            current: current,
            selected: selected,
          );
    final updated = post.copyWith(
      reactionsCount: summary.totalCount,
      reactionSummary: summary,
    );
    if (mounted) setState(() => _post = updated);
    await ref
        .read(feedControllerProvider.notifier)
        .updatePostReaction(post.id, summary);
  });
}
