import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../posts/data/repositories/post_repository.dart';
import '../../../posts/domain/entities/post.dart';
import '../../../profile/data/repositories/profile_content_repository.dart';
import '../../../comments/data/repositories/discussion_repository.dart';

final feedControllerProvider = StateNotifierProvider<FeedController, FeedState>(
  (ref) {
    final controller = FeedController(
      ref.watch(postRepositoryProvider),
      ref.watch(discussionRepositoryProvider),
      onProjectionChanged: () {
        ref.invalidate(profilePostsProvider);
        ref.invalidate(profilePhotosProvider);
      },
    );
    unawaited(controller.load());
    return controller;
  },
);

class FeedState {
  const FeedState({
    this.posts = const [],
    this.loading = true,
    this.refreshing = false,
    this.isCached = false,
    this.cachedAt,
    this.pendingPostIds = const {},
    this.error,
    this.message,
  });

  final List<Post> posts;
  final bool loading;
  final bool refreshing;
  final bool isCached;
  final DateTime? cachedAt;
  final Set<String> pendingPostIds;
  final String? error;
  final String? message;

  FeedState copyWith({
    List<Post>? posts,
    bool? loading,
    bool? refreshing,
    bool? isCached,
    DateTime? cachedAt,
    bool clearCachedAt = false,
    Set<String>? pendingPostIds,
    String? error,
    bool clearError = false,
    String? message,
    bool clearMessage = false,
  }) => FeedState(
    posts: posts ?? this.posts,
    loading: loading ?? this.loading,
    refreshing: refreshing ?? this.refreshing,
    isCached: isCached ?? this.isCached,
    cachedAt: clearCachedAt ? null : cachedAt ?? this.cachedAt,
    pendingPostIds: pendingPostIds ?? this.pendingPostIds,
    error: clearError ? null : error ?? this.error,
    message: clearMessage ? null : message ?? this.message,
  );
}

class FeedController extends StateNotifier<FeedState> {
  FeedController(
    this._repository,
    this._discussion, {
    required this.onProjectionChanged,
  }) : super(const FeedState());

  final PostRepository _repository;
  final DiscussionRepository _discussion;
  final void Function() onProjectionChanged;
  int _loadGeneration = 0;

  Future<void> load({bool refresh = false}) async {
    final generation = ++_loadGeneration;
    state = state.copyWith(
      loading: !refresh && state.posts.isEmpty,
      refreshing: refresh,
      clearError: true,
      clearMessage: refresh,
    );
    try {
      final result = await _repository.getFeed();
      if (generation != _loadGeneration) return;
      state = state.copyWith(
        posts: _dedupe(result.posts),
        loading: false,
        refreshing: false,
        isCached: result.isCached,
        cachedAt: result.cachedAt,
        clearCachedAt: !result.isCached,
      );
    } on Object catch (error) {
      if (generation != _loadGeneration) return;
      state = state.copyWith(
        loading: false,
        refreshing: false,
        error: _message(error),
      );
    }
  }

  Future<void> insertCreated(Post post) async {
    state = state.copyWith(
      posts: _dedupe([post, ...state.posts]),
      isCached: false,
      clearCachedAt: true,
      message: 'Post created successfully.',
      clearError: true,
    );
    await _persistAndInvalidate();
  }

  Future<void> reconcileCanonical(Post post) async {
    if (!state.posts.any((item) => item.id == post.id)) {
      onProjectionChanged();
      return;
    }
    state = state.copyWith(
      posts: state.posts
          .map((item) => item.id == post.id ? post : item)
          .toList(growable: false),
      isCached: false,
      clearCachedAt: true,
    );
    await _persistAndInvalidate();
  }

  Future<void> removeCanonical(String postId) async {
    state = state.copyWith(
      posts: state.posts.where((item) => item.id != postId).toList(),
    );
    await _persistAndInvalidate();
  }

  Future<void> updatePostReaction(
    String postId,
    PostReactionSummary summary,
  ) async {
    final existing = state.posts.where((post) => post.id == postId).firstOrNull;
    if (existing == null) {
      onProjectionChanged();
      return;
    }
    await reconcileCanonical(
      existing.copyWith(
        reactionsCount: summary.totalCount,
        reactionSummary: summary,
      ),
    );
  }

  Future<void> updateCommentCount(String postId, int delta) async {
    final existing = state.posts.where((post) => post.id == postId).firstOrNull;
    if (existing == null) {
      onProjectionChanged();
      return;
    }
    await reconcileCanonical(
      existing.copyWith(
        commentsCount: (existing.commentsCount + delta).clamp(0, 1 << 31),
      ),
    );
  }

  Future<bool> update({
    required Post post,
    required String content,
    required PostPrivacy privacy,
    required List<PostMedia> media,
  }) => _mutate(post.id, () async {
    final updated = await _repository.update(
      postId: post.id,
      content: content,
      privacy: privacy,
      media: media,
    );
    _replace(updated, message: 'Post updated successfully.');
  });

  Future<bool> delete(Post post) => _mutate(post.id, () async {
    await _repository.delete(post.id);
    state = state.copyWith(
      posts: state.posts.where((item) => item.id != post.id).toList(),
      message: 'Post deleted successfully.',
      clearError: true,
    );
  });

  Future<bool> share(Post post, String caption) => _mutate(post.id, () async {
    final shared = await _repository.share(post.id, caption);
    state = state.copyWith(
      posts: _dedupe([shared, ...state.posts]),
      message: 'Post shared successfully.',
      clearError: true,
    );
  });

  Future<bool> react(Post post, ReactionType selected) =>
      _mutate(post.id, () async {
        final current = post.reactionSummary.currentUserReaction;
        final summary = selected == current
            ? await _discussion.removePostReaction(post.id)
            : await _discussion.reactToPost(
                postId: post.id,
                current: current,
                selected: selected,
              );
        _replace(
          post.copyWith(
            reactionsCount: summary.totalCount,
            reactionSummary: summary,
          ),
          message: 'Reaction updated.',
        );
      });

  Future<bool> _mutate(String postId, Future<void> Function() action) async {
    if (state.pendingPostIds.contains(postId)) return false;
    state = state.copyWith(
      pendingPostIds: {...state.pendingPostIds, postId},
      clearError: true,
      clearMessage: true,
    );
    try {
      await action();
      await _persistAndInvalidate();
      return true;
    } on Object catch (error) {
      state = state.copyWith(error: _message(error));
      return false;
    } finally {
      state = state.copyWith(
        pendingPostIds: {...state.pendingPostIds}..remove(postId),
      );
    }
  }

  void _replace(Post post, {required String message}) {
    state = state.copyWith(
      posts: state.posts
          .map((item) => item.id == post.id ? post : item)
          .toList(growable: false),
      message: message,
      clearError: true,
    );
  }

  Future<void> _persistAndInvalidate() async {
    await _repository.cachePosts(state.posts);
    onProjectionChanged();
  }

  List<Post> _dedupe(Iterable<Post> posts) {
    final byId = <String, Post>{};
    for (final post in posts) {
      if (post.id.isNotEmpty) byId[post.id] = post;
    }
    return byId.values.toList(growable: false);
  }

  String _message(Object error) =>
      error is ApiException ? error.message : error.toString();
}
