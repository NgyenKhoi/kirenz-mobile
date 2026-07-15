import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/network/api_response.dart';
import '../../../../core/network/dio_provider.dart';
import '../../../posts/domain/entities/post.dart';
import '../cache/profile_cache.dart';
import '../../domain/entities/profile_photo.dart';

final profileContentRepositoryProvider = Provider<ProfileContentRepository>((
  ref,
) {
  return ProfileContentRepository(
    ref.watch(dioProvider),
    ref.watch(profileCacheProvider),
  );
});

final profilePostsProvider =
    FutureProvider.family<CachedProfileResource<List<Post>>, String>((
      ref,
      userId,
    ) {
      return ref.watch(profileContentRepositoryProvider).getPostsCached(userId);
    });

final profilePhotosProvider =
    FutureProvider.family<CachedProfileResource<List<ProfilePhoto>>, String>((
      ref,
      userId,
    ) {
      return ref
          .watch(profileContentRepositoryProvider)
          .getPhotosCached(userId);
    });

class ProfileContentRepository {
  const ProfileContentRepository(this._dio, [this._cache]);

  final Dio _dio;
  final ProfileCache? _cache;

  Future<List<Post>> getPosts(String userId) async {
    return (await getPostsCached(userId)).data;
  }

  Future<CachedProfileResource<List<Post>>> getPostsCached(String userId) {
    return _readCachedList(
      () => _dio.get<Object?>('/posts/user/$userId'),
      (value) => Post.fromJson(_asMap(value)),
      resource: 'posts',
      userId: userId,
      isValid: (post) => post.id.isNotEmpty,
    );
  }

  Future<List<ProfilePhoto>> getPhotos(String userId) async {
    return (await getPhotosCached(userId)).data;
  }

  Future<CachedProfileResource<List<ProfilePhoto>>> getPhotosCached(
    String userId,
  ) {
    return _readCachedList(
      () => _dio.get<Object?>('/posts/user/$userId/images'),
      (value) => ProfilePhoto.fromJson(_asMap(value)),
      resource: 'photos',
      userId: userId,
      isValid: (photo) => photo.postId.isNotEmpty && photo.url.isNotEmpty,
    );
  }

  Future<CachedProfileResource<List<T>>> _readCachedList<T>(
    Future<Response<Object?>> Function() request,
    T Function(Object? value) parse, {
    required String resource,
    required String userId,
    required bool Function(T value) isValid,
  }) async {
    try {
      final response = await request();
      final body = _asMap(response.data);
      final envelope = ApiResponse.fromJson<List<T>>(body, (value) {
        if (value is! List) {
          throw const ApiException('List response has an invalid shape.');
        }
        return value.map(parse).where(isValid).toList(growable: false);
      });
      if (!envelope.success) {
        throw ApiException(
          envelope.message ?? 'Profile content request failed.',
        );
      }
      final items = envelope.data ?? const [];
      await _writeCache(resource, userId, body['data'] ?? const []);
      return CachedProfileResource(data: items, isCached: false);
    } on ApiException {
      rethrow;
    } on DioException catch (error) {
      final canUseCache =
          error.response?.statusCode == null ||
          (error.response?.statusCode ?? 0) >= 500;
      final cached = canUseCache ? await _readCache(resource, userId) : null;
      if (cached != null && cached.value is List) {
        final items = (cached.value! as List)
            .map(parse)
            .where(isValid)
            .toList(growable: false);
        return CachedProfileResource(
          data: items,
          isCached: true,
          cachedAt: cached.updatedAt,
        );
      }
      throw ApiException(
        _errorMessage(error),
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<void> _writeCache(
    String resource,
    String userId,
    Object? value,
  ) async {
    try {
      await _cache?.write(resource, userId, value);
    } on Object {
      return;
    }
  }

  Future<ProfileCacheEntry?> _readCache(String resource, String userId) async {
    try {
      return await _cache?.read(resource, userId);
    } on Object {
      return null;
    }
  }
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

String _errorMessage(DioException error) {
  final body = _asMap(error.response?.data);
  final message = body['message']?.toString();
  if (message != null && message.isNotEmpty) return message;
  return error.message ?? 'Profile content request failed.';
}
