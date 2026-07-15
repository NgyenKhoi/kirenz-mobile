import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirenz_mobile/core/errors/api_exception.dart';
import 'package:kirenz_mobile/features/posts/domain/entities/post.dart';
import 'package:kirenz_mobile/features/profile/data/cache/profile_cache.dart';
import 'package:kirenz_mobile/features/profile/data/repositories/profile_content_repository.dart';

void main() {
  test(
    'loads canonical user posts and photos from their exact paths',
    () async {
      final requestedPaths = <String>[];
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requestedPaths.add(options.path);
            final data = options.path.endsWith('/images')
                ? [_photoJson]
                : [_postJson];
            handler.resolve(
              Response<Object?>(
                requestOptions: options,
                statusCode: 200,
                data: {'success': true, 'message': 'ok', 'data': data},
              ),
            );
          },
        ),
      );
      final repository = ProfileContentRepository(dio);

      final posts = await repository.getPosts('user-1');
      final photos = await repository.getPhotos('user-1');

      expect(requestedPaths, [
        '/posts/user/user-1',
        '/posts/user/user-1/images',
      ]);
      expect(posts.single.id, 'post-1');
      expect(posts.single.privacy, PostPrivacy.friends);
      expect(posts.single.reactionSummary.breakdown[ReactionType.love], 2);
      expect(photos.single.postId, 'post-1');
      expect(photos.single.url, 'https://example.com/photo.jpg');
    },
  );

  test('rejects a non-list canonical data shape', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.resolve(
          Response<Object?>(
            requestOptions: options,
            statusCode: 200,
            data: {
              'success': true,
              'message': 'ok',
              'data': {'id': 'not-a-list'},
            },
          ),
        ),
      ),
    );

    expect(
      () => ProfileContentRepository(dio).getPhotos('user-1'),
      throwsA(isA<ApiException>()),
    );
  });

  test(
    'returns timestamped cached posts when the network is offline',
    () async {
      final cache = _MemoryProfileCache();
      final online = Dio();
      online.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.resolve(
            Response<Object?>(
              requestOptions: options,
              statusCode: 200,
              data: {
                'success': true,
                'message': 'ok',
                'data': [_postJson],
              },
            ),
          ),
        ),
      );
      await ProfileContentRepository(online, cache).getPostsCached('user-1');

      final offline = Dio();
      offline.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.reject(
            DioException.connectionError(
              requestOptions: options,
              reason: 'offline',
            ),
          ),
        ),
      );
      final result = await ProfileContentRepository(
        offline,
        cache,
      ).getPostsCached('user-1');

      expect(result.isCached, isTrue);
      expect(result.cachedAt, cache.updatedAt);
      expect(result.data.single.id, 'post-1');
    },
  );

  test('cached photos reconcile to a canonical empty refresh', () async {
    final cache = _MemoryProfileCache();
    await cache.write('photos', 'user-1', [_photoJson]);
    final offline = Dio();
    offline.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.reject(
          DioException.connectionError(
            requestOptions: options,
            reason: 'offline',
          ),
        ),
      ),
    );
    final stale = await ProfileContentRepository(
      offline,
      cache,
    ).getPhotosCached('user-1');
    expect(stale.isCached, isTrue);

    final online = Dio();
    online.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.resolve(
          Response<Object?>(
            requestOptions: options,
            statusCode: 200,
            data: {'success': true, 'data': <Object>[]},
          ),
        ),
      ),
    );
    final refreshed = await ProfileContentRepository(
      online,
      cache,
    ).getPhotosCached('user-1');
    expect(refreshed.isCached, isFalse);
    expect(refreshed.data, isEmpty);
    expect((await cache.read('photos', 'user-1'))!.value, isEmpty);
  });

  test('does not expose cached posts after a 404 response', () async {
    final cache = _MemoryProfileCache();
    await cache.write('posts', 'user-1', [_postJson]);
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.reject(
          DioException.badResponse(
            statusCode: 404,
            requestOptions: options,
            response: Response<Object?>(
              requestOptions: options,
              statusCode: 404,
            ),
          ),
        ),
      ),
    );
    expect(
      () => ProfileContentRepository(dio, cache).getPostsCached('user-1'),
      throwsA(isA<ApiException>()),
    );
  });
}

class _MemoryProfileCache implements ProfileCache {
  final values = <String, Object?>{};
  final DateTime updatedAt = DateTime.utc(2026, 7, 15, 12);

  @override
  Future<ProfileCacheEntry?> read(String resource, String userId) async {
    final value = values['$resource:$userId'];
    return value == null
        ? null
        : ProfileCacheEntry(value: value, updatedAt: updatedAt);
  }

  @override
  Future<void> write(String resource, String userId, Object? value) async {
    values['$resource:$userId'] = value;
  }

  @override
  Future<void> clear() async => values.clear();

  @override
  Future<void> removeUser(String userId) async {
    values.removeWhere((key, value) => key.endsWith(':$userId'));
  }
}

const _photoJson = {
  'postId': 'post-1',
  'url': 'https://example.com/photo.jpg',
  'publicId': 'photo-1',
  'createdAt': '2026-07-14T10:00:00Z',
};

const _postJson = {
  'id': 'post-1',
  'slug': 'post-one',
  'author': {
    'id': 'user-1',
    'username': 'person',
    'displayName': 'Person',
    'avatarUrl': null,
  },
  'content': 'Hello',
  'privacy': 'FRIENDS',
  'originalPostId': null,
  'sharedPost': null,
  'media': [
    {
      'type': 'IMAGE',
      'url': 'https://example.com/photo.jpg',
      'publicId': 'photo-1',
    },
  ],
  'taggedUserIds': <String>[],
  'taggedUsers': <Object>[],
  'reactionsCount': 2,
  'reactionSummary': {
    'totalCount': 2,
    'currentUserReaction': 'LOVE',
    'breakdown': {'LOVE': 2},
  },
  'commentsCount': 1,
  'status': 'ACTIVE',
  'createdAt': '2026-07-14T10:00:00Z',
  'updatedAt': '2026-07-14T10:00:00Z',
};
