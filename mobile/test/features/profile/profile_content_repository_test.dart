import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirenz_mobile/core/errors/api_exception.dart';
import 'package:kirenz_mobile/features/posts/domain/entities/post.dart';
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
