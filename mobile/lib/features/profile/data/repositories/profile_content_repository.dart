import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/network/api_response.dart';
import '../../../../core/network/dio_provider.dart';
import '../../../posts/domain/entities/post.dart';
import '../../domain/entities/profile_photo.dart';

final profileContentRepositoryProvider = Provider<ProfileContentRepository>((
  ref,
) {
  return ProfileContentRepository(ref.watch(dioProvider));
});

final profilePostsProvider = FutureProvider.family<List<Post>, String>((
  ref,
  userId,
) {
  return ref.watch(profileContentRepositoryProvider).getPosts(userId);
});

final profilePhotosProvider = FutureProvider.family<List<ProfilePhoto>, String>(
  (ref, userId) {
    return ref.watch(profileContentRepositoryProvider).getPhotos(userId);
  },
);

class ProfileContentRepository {
  const ProfileContentRepository(this._dio);

  final Dio _dio;

  Future<List<Post>> getPosts(String userId) {
    return _readList(
      () => _dio.get<Object?>('/posts/user/$userId'),
      (value) => Post.fromJson(_asMap(value)),
      isValid: (post) => post.id.isNotEmpty,
    );
  }

  Future<List<ProfilePhoto>> getPhotos(String userId) {
    return _readList(
      () => _dio.get<Object?>('/posts/user/$userId/images'),
      (value) => ProfilePhoto.fromJson(_asMap(value)),
      isValid: (photo) => photo.postId.isNotEmpty && photo.url.isNotEmpty,
    );
  }

  Future<List<T>> _readList<T>(
    Future<Response<Object?>> Function() request,
    T Function(Object? value) parse, {
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
      return envelope.data ?? const [];
    } on ApiException {
      rethrow;
    } on DioException catch (error) {
      throw ApiException(
        _errorMessage(error),
        statusCode: error.response?.statusCode,
      );
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
