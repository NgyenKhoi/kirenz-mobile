import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/network/api_response.dart';
import '../../../../core/network/dio_provider.dart';
import '../../../posts/domain/entities/post.dart';
import '../../../profile/data/cache/profile_cache.dart';
import '../../domain/entities/comment.dart';

final discussionRepositoryProvider = Provider<DiscussionRepository>((ref) {
  return DiscussionRepository(
    ref.watch(dioProvider),
    ref.watch(profileCacheProvider),
  );
});

class CachedCommentList {
  const CachedCommentList({
    required this.comments,
    required this.isCached,
    this.cachedAt,
  });

  final List<PostComment> comments;
  final bool isCached;
  final DateTime? cachedAt;
}

class DiscussionRepository {
  const DiscussionRepository(this._dio, [this._cache]);

  final Dio _dio;
  final ProfileCache? _cache;

  Future<List<PostComment>> getComments(String postId) async =>
      (await getCommentsCached(postId)).comments;

  Future<CachedCommentList> getCommentsCached(String postId) async {
    try {
      final body = await _request(
        () => _dio.get<Object?>('/posts/$postId/comments'),
      );
      final envelope = ApiResponse.fromJson<List<PostComment>>(body, (value) {
        if (value is! List) {
          throw const ApiException(
            'Comment list response has an invalid shape.',
            kind: ApiFailureKind.parsing,
          );
        }
        return value
            .whereType<Map>()
            .map(
              (item) => PostComment.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList(growable: false);
      });
      if (!envelope.success || envelope.data == null) {
        throw ApiException(envelope.message ?? 'Could not load comments.');
      }
      await cacheComments(postId, envelope.data!);
      return CachedCommentList(comments: envelope.data!, isCached: false);
    } on ApiException catch (error) {
      final canFallback =
          error.kind == ApiFailureKind.transport ||
          error.kind == ApiFailureKind.server;
      final cached = canFallback
          ? await _cache?.read('comments', postId)
          : null;
      if (cached == null || cached.value is! List) rethrow;
      return CachedCommentList(
        comments: (cached.value! as List)
            .whereType<Map>()
            .map(
              (item) => PostComment.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList(growable: false),
        isCached: true,
        cachedAt: cached.updatedAt,
      );
    }
  }

  Future<void> cacheComments(String postId, List<PostComment> comments) async {
    try {
      await _cache?.write(
        'comments',
        postId,
        comments.map((comment) => comment.toJson()).toList(growable: false),
      );
    } on Object {
      return;
    }
  }

  Future<PostComment> createComment({
    required String postId,
    required String content,
    String? parentCommentId,
  }) => _comment(
    () => _dio.post<Object?>(
      '/posts/$postId/comments',
      data: {'content': content, 'parentCommentId': parentCommentId},
    ),
  );

  Future<PostComment> updateComment({
    required String postId,
    required String commentId,
    required String content,
  }) => _comment(
    () => _dio.patch<Object?>(
      '/posts/$postId/comments/$commentId',
      data: {'content': content},
    ),
  );

  Future<void> deleteComment(String postId, String commentId) async {
    final body = await _request(
      () => _dio.delete<Object?>('/posts/$postId/comments/$commentId'),
    );
    if (body['success'] != true) {
      throw ApiException(body['message']?.toString() ?? 'Delete failed.');
    }
  }

  Future<PostReactionSummary> reactToPost({
    required String postId,
    required ReactionType? current,
    required ReactionType selected,
  }) => _reaction(
    () => _dio.request<Object?>(
      '/posts/$postId/reactions',
      data: {'type': selected.wireName},
      options: Options(method: current == null ? 'POST' : 'PATCH'),
    ),
  );

  Future<PostReactionSummary> removePostReaction(String postId) =>
      _reaction(() => _dio.delete<Object?>('/posts/$postId/reactions/me'));

  Future<PostReactionSummary> reactToComment({
    required String commentId,
    required ReactionType? current,
    required ReactionType selected,
  }) => _reaction(
    () => _dio.request<Object?>(
      '/comments/$commentId/reactions',
      data: {'type': selected.wireName},
      options: Options(method: current == null ? 'POST' : 'PATCH'),
    ),
  );

  Future<PostReactionSummary> removeCommentReaction(String commentId) =>
      _reaction(
        () => _dio.delete<Object?>('/comments/$commentId/reactions/me'),
      );

  Future<List<ReactionUser>> getReactionUsers({
    required String targetId,
    required bool comment,
  }) async {
    final path = comment
        ? '/comments/$targetId/reactions'
        : '/posts/$targetId/reactions';
    final body = await _request(() => _dio.get<Object?>(path));
    final envelope = ApiResponse.fromJson<List<ReactionUser>>(body, (value) {
      if (value is! List) {
        throw const ApiException(
          'Reaction users response has an invalid shape.',
          kind: ApiFailureKind.parsing,
        );
      }
      return value
          .whereType<Map>()
          .map((item) => ReactionUser.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    });
    if (!envelope.success || envelope.data == null) {
      throw ApiException(envelope.message ?? 'Could not load reactions.');
    }
    return envelope.data!;
  }

  Future<PostComment> _comment(
    Future<Response<Object?>> Function() request,
  ) async {
    final body = await _request(request);
    final envelope = ApiResponse.fromJson<PostComment>(
      body,
      (value) => PostComment.fromJson(_map(value)),
    );
    if (!envelope.success || envelope.data == null) {
      throw ApiException(envelope.message ?? 'Comment request failed.');
    }
    return envelope.data!;
  }

  Future<PostReactionSummary> _reaction(
    Future<Response<Object?>> Function() request,
  ) async {
    final body = await _request(request);
    final envelope = ApiResponse.fromJson<PostReactionSummary>(
      body,
      (value) => PostReactionSummary.fromJson(_map(value)),
    );
    if (!envelope.success || envelope.data == null) {
      throw ApiException(envelope.message ?? 'Reaction request failed.');
    }
    return envelope.data!;
  }

  Future<Map<String, dynamic>> _request(
    Future<Response<Object?>> Function() request,
  ) async {
    try {
      return _map((await request()).data);
    } on ApiException {
      rethrow;
    } on DioException catch (error) {
      throw ApiException(
        _map(error.response?.data)['message']?.toString() ??
            error.message ??
            'Discussion request failed.',
        statusCode: error.response?.statusCode,
        kind: apiFailureKindForResponse(
          hasResponse: error.response != null,
          statusCode: error.response?.statusCode,
        ),
      );
    }
  }
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
