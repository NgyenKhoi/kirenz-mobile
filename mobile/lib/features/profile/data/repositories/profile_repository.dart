import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/network/api_response.dart';
import '../../../../core/network/dio_provider.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/controllers/session_controller.dart';
import '../../domain/entities/user_profile.dart';
import '../cache/profile_cache.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(
    ref.watch(dioProvider),
    ref.watch(profileCacheProvider),
  );
});

final profileCacheStatusProvider =
    StateProvider.family<ProfileCacheEntry?, String>((ref, userId) => null);

final currentUserProfileProvider =
    AsyncNotifierProvider<CurrentUserProfileController, UserProfile>(
      CurrentUserProfileController.new,
    );

class CurrentUserProfileController extends AsyncNotifier<UserProfile> {
  @override
  Future<UserProfile> build() async {
    final sessionUser = ref.watch(sessionControllerProvider).user;
    try {
      final result = await ref
          .watch(profileRepositoryProvider)
          .getCurrentUserCached();
      ref
          .read(profileCacheStatusProvider(result.data.id).notifier)
          .state = result.isCached && result.cachedAt != null
          ? ProfileCacheEntry(value: null, updatedAt: result.cachedAt!)
          : null;
      return result.data;
    } on ApiException {
      if (sessionUser?.id == 'dev-user') {
        return UserProfile(
          id: sessionUser!.id,
          email: sessionUser.email,
          username: 'developer',
          displayName: sessionUser.displayName,
          avatarUrl: null,
          coverPhotoUrl: null,
          bio: null,
          birthDate: null,
          gender: null,
          location: null,
          website: null,
          role: ProfileRole.user,
          emailVerified: true,
          createdAt: null,
          updatedAt: null,
        );
      }
      rethrow;
    }
  }

  void replace(UserProfile profile) {
    state = AsyncData(profile);
    ref
        .read(sessionControllerProvider.notifier)
        .updateCurrentUser(
          AppUser(
            id: profile.id,
            email: profile.email,
            username: profile.username,
            displayName: profile.displayName,
            avatarUrl: profile.avatarUrl,
          ),
        );
  }
}

final userProfileProvider = FutureProvider.family<UserProfile, String>((
  ref,
  userId,
) async {
  final result = await ref
      .watch(profileRepositoryProvider)
      .getUserCached(userId);
  ref
      .read(profileCacheStatusProvider(userId).notifier)
      .state = result.isCached && result.cachedAt != null
      ? ProfileCacheEntry(value: null, updatedAt: result.cachedAt!)
      : null;
  return result.data;
});

class ProfileUpdate {
  const ProfileUpdate({
    required this.displayName,
    this.bio,
    this.birthDate,
    this.gender,
    this.location,
    this.website,
  });

  final String displayName;
  final String? bio;
  final DateTime? birthDate;
  final ProfileGender? gender;
  final String? location;
  final String? website;

  Map<String, dynamic> toJson() {
    return {
      'displayName': displayName,
      'bio': bio,
      'birthDate': birthDate == null
          ? null
          : '${birthDate!.year.toString().padLeft(4, '0')}-${birthDate!.month.toString().padLeft(2, '0')}-${birthDate!.day.toString().padLeft(2, '0')}',
      'gender': switch (gender) {
        ProfileGender.male => 'MALE',
        ProfileGender.female => 'FEMALE',
        ProfileGender.other => 'OTHER',
        ProfileGender.preferNotToSay => 'PREFER_NOT_TO_SAY',
        null => null,
      },
      'location': location,
      'website': website,
    };
  }
}

class ProfileRepository {
  const ProfileRepository(this._dio, [this._cache]);

  final Dio _dio;
  final ProfileCache? _cache;

  Future<UserProfile> getCurrentUser() async {
    return (await getCurrentUserCached()).data;
  }

  Future<CachedProfileResource<UserProfile>> getCurrentUserCached() {
    return _readProfileCached(
      () => _dio.get<Object?>('/users/me'),
      userId: 'me',
    );
  }

  Future<UserProfile> getUser(String userId) async {
    return (await getUserCached(userId)).data;
  }

  Future<CachedProfileResource<UserProfile>> getUserCached(String userId) {
    return _readProfileCached(
      () => _dio.get<Object?>('/users/$userId'),
      userId: userId,
    );
  }

  Future<UserProfile> updateCurrentUser(ProfileUpdate update) {
    return _readProfileNetwork(
      () => _dio.patch<Object?>('/users/me', data: update.toJson()),
      onData: (data) => _writeCache('me', data),
    );
  }

  Future<UserProfile> uploadAvatar(
    String filePath, {
    ProgressCallback? onSendProgress,
  }) {
    return _upload(
      '/users/me/avatar',
      filePath,
      onSendProgress: onSendProgress,
    );
  }

  Future<UserProfile> uploadCover(
    String filePath, {
    ProgressCallback? onSendProgress,
  }) {
    return _upload('/users/me/cover', filePath, onSendProgress: onSendProgress);
  }

  Future<UserProfile> _upload(
    String path,
    String filePath, {
    ProgressCallback? onSendProgress,
  }) async {
    final file = await MultipartFile.fromFile(filePath);
    return _readProfileNetwork(
      () => _dio.post<Object?>(
        path,
        data: FormData.fromMap({'file': file}),
        options: Options(contentType: 'multipart/form-data'),
        onSendProgress: onSendProgress,
      ),
      onData: (data) => _writeCache('me', data),
    );
  }

  Future<CachedProfileResource<UserProfile>> _readProfileCached(
    Future<Response<Object?>> Function() request, {
    required String userId,
  }) async {
    try {
      final profile = await _readProfileNetwork(
        request,
        onData: (data) => _writeCache(userId, data),
      );
      return CachedProfileResource(data: profile, isCached: false);
    } on ApiException catch (error) {
      final canUseCache =
          error.statusCode == null || (error.statusCode ?? 0) >= 500;
      final cached = canUseCache ? await _readCache(userId) : null;
      if (cached?.value is Map) {
        final profile = UserProfile.fromJson(_asMap(cached!.value));
        if (profile.id.isNotEmpty) {
          return CachedProfileResource(
            data: profile,
            isCached: true,
            cachedAt: cached.updatedAt,
          );
        }
      }
      rethrow;
    }
  }

  Future<void> _writeCache(String userId, Object? data) async {
    try {
      await _cache?.write('profile', userId, data);
    } on Object {
      return;
    }
  }

  Future<ProfileCacheEntry?> _readCache(String userId) async {
    try {
      return await _cache?.read('profile', userId);
    } on Object {
      return null;
    }
  }

  Future<UserProfile> _readProfileNetwork(
    Future<Response<Object?>> Function() request, {
    Future<void>? Function(Object? data)? onData,
  }) async {
    try {
      final response = await request();
      final body = _asMap(response.data);
      final envelope = ApiResponse.fromJson<UserProfile>(
        body,
        (value) => UserProfile.fromJson(_asMap(value)),
      );
      if (body.containsKey('success') && !envelope.success) {
        throw ApiException(envelope.message ?? 'Profile request failed.');
      }
      final profile = envelope.data;
      if (profile == null || profile.id.isEmpty) {
        throw const ApiException('Profile response did not include a user.');
      }
      await onData?.call(body['data']);
      return profile;
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
  return error.message ?? 'Profile request failed.';
}
