import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/network/api_response.dart';
import '../../../../core/network/dio_provider.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/controllers/session_controller.dart';
import '../../domain/entities/user_profile.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(dioProvider));
});

final currentUserProfileProvider =
    AsyncNotifierProvider<CurrentUserProfileController, UserProfile>(
      CurrentUserProfileController.new,
    );

class CurrentUserProfileController extends AsyncNotifier<UserProfile> {
  @override
  Future<UserProfile> build() async {
    final sessionUser = ref.watch(sessionControllerProvider).user;
    try {
      return await ref.watch(profileRepositoryProvider).getCurrentUser();
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
  return ref.watch(profileRepositoryProvider).getUser(userId);
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
  const ProfileRepository(this._dio);

  final Dio _dio;

  Future<UserProfile> getCurrentUser() {
    return _readProfile(() => _dio.get<Object?>('/users/me'));
  }

  Future<UserProfile> getUser(String userId) {
    return _readProfile(() => _dio.get<Object?>('/users/$userId'));
  }

  Future<UserProfile> updateCurrentUser(ProfileUpdate update) {
    return _readProfile(
      () => _dio.patch<Object?>('/users/me', data: update.toJson()),
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
    return _readProfile(
      () => _dio.post<Object?>(
        path,
        data: FormData.fromMap({'file': file}),
        options: Options(contentType: 'multipart/form-data'),
        onSendProgress: onSendProgress,
      ),
    );
  }

  Future<UserProfile> _readProfile(
    Future<Response<Object?>> Function() request,
  ) async {
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
