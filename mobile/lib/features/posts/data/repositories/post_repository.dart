import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/network/api_response.dart';
import '../../../../core/network/dio_provider.dart';
import '../../../profile/data/cache/profile_cache.dart';
import '../../domain/entities/post.dart';
import '../../domain/entities/post_draft.dart';

final postRepositoryProvider = Provider<PostRepository>((ref) {
  return PostRepository(
    ref.watch(dioProvider),
    ref.watch(profileCacheProvider),
  );
});

class CachedFeed {
  const CachedFeed({
    required this.posts,
    required this.isCached,
    this.cachedAt,
  });

  final List<Post> posts;
  final bool isCached;
  final DateTime? cachedAt;
}

class PostRepository {
  const PostRepository(this._dio, [this._cache]);

  final Dio _dio;
  final ProfileCache? _cache;

  Future<CachedFeed> getFeed() async {
    try {
      final body = await _request(() => _dio.get<Object?>('/posts'));
      final posts = _postList(body);
      await _safeWrite(posts);
      return CachedFeed(posts: posts, isCached: false);
    } on ApiException catch (error) {
      final fallbackAllowed =
          error.kind == ApiFailureKind.transport ||
          error.kind == ApiFailureKind.server;
      final cached = fallbackAllowed ? await _safeRead() : null;
      if (cached == null || cached.value is! List) rethrow;
      return CachedFeed(
        posts: (cached.value! as List)
            .whereType<Map>()
            .map((item) => Post.fromJson(Map<String, dynamic>.from(item)))
            .where((post) => post.id.isNotEmpty)
            .toList(growable: false),
        isCached: true,
        cachedAt: cached.updatedAt,
      );
    }
  }

  Future<Post> getById(String postId) =>
      _post(() => _dio.get<Object?>('/posts/$postId'));

  Future<Post> create({
    required String content,
    required PostPrivacy privacy,
    required List<PostMedia> media,
    required List<String> taggedUserIds,
  }) => _post(
    () => _dio.post<Object?>(
      '/posts',
      data: {
        'content': content,
        'media': media.map((item) => item.toJson()).toList(growable: false),
        'privacy': privacy.wireName,
        'taggedUserIds': taggedUserIds,
      },
    ),
  );

  Future<Post> update({
    required String postId,
    required String content,
    required PostPrivacy privacy,
    required List<PostMedia> media,
  }) => _post(
    () => _dio.patch<Object?>(
      '/posts/$postId',
      data: {
        'content': content,
        'media': media.map((item) => item.toJson()).toList(growable: false),
        'privacy': privacy.wireName,
      },
    ),
  );

  Future<Post> share(String postId, String caption) => _post(
    () =>
        _dio.post<Object?>('/posts/$postId/shares', data: {'caption': caption}),
  );

  Future<void> delete(String postId) async {
    final body = await _request(() => _dio.delete<Object?>('/posts/$postId'));
    if (body['success'] != true) {
      throw ApiException(body['message']?.toString() ?? 'Delete post failed.');
    }
  }

  Future<PostMedia> uploadImage(
    PostDraftImage image, {
    ProgressCallback? onProgress,
  }) async {
    final multipart = await MultipartFile.fromFile(
      image.path,
      filename: image.name,
      contentType: DioMediaType.parse(image.contentType),
    );
    final body = await _request(
      () => _dio.post<Object?>(
        '/media/posts',
        data: FormData.fromMap({'file': multipart}),
        onSendProgress: onProgress,
      ),
    );
    final envelope = ApiResponse.fromJson<PostMedia>(body, (value) {
      final json = _map(value);
      if (json['type']?.toString() != 'IMAGE' ||
          json['url']?.toString().trim().isEmpty != false) {
        throw const ApiException(
          'Post image upload response has an invalid shape.',
          kind: ApiFailureKind.parsing,
        );
      }
      return PostMedia.fromJson(json);
    });
    if (!envelope.success || envelope.data == null) {
      throw ApiException(envelope.message ?? 'Post image upload failed.');
    }
    return envelope.data!;
  }

  Future<void> cachePosts(List<Post> posts) => _safeWrite(posts);

  Future<Post> _post(Future<Response<Object?>> Function() request) async {
    final body = await _request(request);
    final envelope = ApiResponse.fromJson<Post>(
      body,
      (value) => Post.fromJson(_map(value)),
    );
    if (!envelope.success || envelope.data?.id.isEmpty != false) {
      throw ApiException(envelope.message ?? 'Post request failed.');
    }
    return envelope.data!;
  }

  List<Post> _postList(Map<String, dynamic> body) {
    final envelope = ApiResponse.fromJson<List<Post>>(body, (value) {
      if (value is! List) {
        throw const ApiException(
          'Feed response has an invalid shape.',
          kind: ApiFailureKind.parsing,
        );
      }
      return value
          .whereType<Map>()
          .map((item) => Post.fromJson(Map<String, dynamic>.from(item)))
          .where((post) => post.id.isNotEmpty)
          .toList(growable: false);
    });
    if (!envelope.success || envelope.data == null) {
      throw ApiException(envelope.message ?? 'Feed request failed.');
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
            'Post request failed.',
        statusCode: error.response?.statusCode,
        kind: apiFailureKindForResponse(
          hasResponse: error.response != null,
          statusCode: error.response?.statusCode,
        ),
      );
    }
  }

  Future<void> _safeWrite(List<Post> posts) async {
    try {
      await _cache?.write(
        'feed',
        'current',
        posts.map((post) => post.toJson()).toList(growable: false),
      );
    } on Object {
      return;
    }
  }

  Future<ProfileCacheEntry?> _safeRead() async {
    try {
      return await _cache?.read('feed', 'current');
    } on Object {
      return null;
    }
  }
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
