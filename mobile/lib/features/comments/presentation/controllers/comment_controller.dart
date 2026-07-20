import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../feed/presentation/controllers/feed_controller.dart';
import '../../../posts/domain/entities/post.dart';
import '../../data/repositories/discussion_repository.dart';
import '../../domain/entities/comment.dart';

final commentControllerProvider = StateNotifierProvider.autoDispose
    .family<CommentController, CommentState, String>((ref, postId) {
      final controller = CommentController(
        postId,
        ref.watch(discussionRepositoryProvider),
        updatePostCount: (delta) => ref
            .read(feedControllerProvider.notifier)
            .updateCommentCount(postId, delta),
      );
      unawaited(controller.load());
      return controller;
    });

class CommentState {
  const CommentState({
    this.comments = const [],
    this.loading = true,
    this.refreshing = false,
    this.draft = '',
    this.replyTarget,
    this.sending = false,
    this.pendingIds = const {},
    this.isCached = false,
    this.cachedAt,
    this.error,
    this.composerError,
  });

  final List<PostComment> comments;
  final bool loading;
  final bool refreshing;
  final String draft;
  final PostComment? replyTarget;
  final bool sending;
  final Set<String> pendingIds;
  final bool isCached;
  final DateTime? cachedAt;
  final String? error;
  final String? composerError;

  CommentState copyWith({
    List<PostComment>? comments,
    bool? loading,
    bool? refreshing,
    String? draft,
    PostComment? replyTarget,
    bool clearReplyTarget = false,
    bool? sending,
    Set<String>? pendingIds,
    bool? isCached,
    DateTime? cachedAt,
    bool clearCachedAt = false,
    String? error,
    bool clearError = false,
    String? composerError,
    bool clearComposerError = false,
  }) => CommentState(
    comments: comments ?? this.comments,
    loading: loading ?? this.loading,
    refreshing: refreshing ?? this.refreshing,
    draft: draft ?? this.draft,
    replyTarget: clearReplyTarget ? null : replyTarget ?? this.replyTarget,
    sending: sending ?? this.sending,
    pendingIds: pendingIds ?? this.pendingIds,
    isCached: isCached ?? this.isCached,
    cachedAt: clearCachedAt ? null : cachedAt ?? this.cachedAt,
    error: clearError ? null : error ?? this.error,
    composerError: clearComposerError
        ? null
        : composerError ?? this.composerError,
  );
}

class CommentController extends StateNotifier<CommentState> {
  CommentController(
    this.postId,
    this._repository, {
    required this.updatePostCount,
  }) : super(const CommentState());

  final String postId;
  final DiscussionRepository _repository;
  final Future<void> Function(int delta) updatePostCount;

  Future<void> load({bool refresh = false}) async {
    state = state.copyWith(
      loading: !refresh && state.comments.isEmpty,
      refreshing: refresh,
      clearError: true,
    );
    try {
      final result = await _repository.getCommentsCached(postId);
      state = state.copyWith(
        comments: result.comments,
        loading: false,
        refreshing: false,
        isCached: result.isCached,
        cachedAt: result.cachedAt,
        clearCachedAt: !result.isCached,
      );
    } on Object catch (error) {
      state = state.copyWith(
        loading: false,
        refreshing: false,
        error: _message(error),
      );
    }
  }

  void updateDraft(String value) =>
      state = state.copyWith(draft: value, clearComposerError: true);

  void replyTo(PostComment comment) =>
      state = state.copyWith(replyTarget: comment, clearComposerError: true);

  void cancelReply() => state = state.copyWith(clearReplyTarget: true);

  Future<bool> send() async {
    if (state.sending || state.draft.trim().isEmpty) return false;
    state = state.copyWith(sending: true, clearComposerError: true);
    try {
      final created = await _repository.createComment(
        postId: postId,
        content: state.draft,
        parentCommentId: state.replyTarget?.id,
      );
      state = state.copyWith(
        comments: [...state.comments, created],
        draft: '',
        sending: false,
        clearReplyTarget: true,
        isCached: false,
        clearCachedAt: true,
      );
      await _cache();
      await updatePostCount(1);
      return true;
    } on Object catch (error) {
      state = state.copyWith(sending: false, composerError: _message(error));
      return false;
    }
  }

  Future<bool> update(PostComment comment, String content) =>
      _mutate(comment.id, () async {
        final updated = await _repository.updateComment(
          postId: postId,
          commentId: comment.id,
          content: content,
        );
        state = state.copyWith(
          comments: state.comments
              .map((item) => item.id == updated.id ? updated : item)
              .toList(growable: false),
        );
        await _cache();
      });

  Future<bool> delete(PostComment comment) => _mutate(comment.id, () async {
    await _repository.deleteComment(postId, comment.id);
    final removedIds = _descendantIds(comment.id)..add(comment.id);
    state = state.copyWith(
      comments: state.comments
          .where((item) => !removedIds.contains(item.id))
          .toList(growable: false),
    );
    await _cache();
    await updatePostCount(-removedIds.length);
  });

  Future<bool> react(PostComment comment, ReactionType? selected) =>
      _mutate(comment.id, () async {
        final current = comment.reactionSummary.currentUserReaction;
        final summary = selected == null || selected == current
            ? await _repository.removeCommentReaction(comment.id)
            : await _repository.reactToComment(
                commentId: comment.id,
                current: current,
                selected: selected,
              );
        state = state.copyWith(
          comments: state.comments
              .map(
                (item) => item.id == comment.id
                    ? item.copyWith(
                        reactionsCount: summary.totalCount,
                        reactionSummary: summary,
                      )
                    : item,
              )
              .toList(growable: false),
        );
        await _cache();
      });

  Future<bool> _mutate(String id, Future<void> Function() action) async {
    if (state.pendingIds.contains(id)) return false;
    state = state.copyWith(
      pendingIds: {...state.pendingIds, id},
      clearError: true,
    );
    try {
      await action();
      return true;
    } on Object catch (error) {
      state = state.copyWith(error: _message(error));
      return false;
    } finally {
      state = state.copyWith(pendingIds: {...state.pendingIds}..remove(id));
    }
  }

  Set<String> _descendantIds(String parentId) {
    final result = <String>{};
    var frontier = <String>{parentId};
    while (frontier.isNotEmpty) {
      final children = state.comments
          .where((item) => frontier.contains(item.parentCommentId))
          .map((item) => item.id)
          .where((id) => !result.contains(id))
          .toSet();
      result.addAll(children);
      frontier = children;
    }
    return result;
  }

  Future<void> _cache() => _repository.cacheComments(postId, state.comments);

  String _message(Object error) =>
      error is ApiException ? error.message : error.toString();
}
