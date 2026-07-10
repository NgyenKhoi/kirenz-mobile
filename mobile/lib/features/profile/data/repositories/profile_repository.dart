import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/network/api_response.dart';
import '../../../../core/network/dio_provider.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/controllers/session_controller.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(dioProvider));
});

final currentUserProfileProvider = FutureProvider<AppUser>((ref) async {
  final sessionUser = ref.watch(sessionControllerProvider).user;

  try {
    return await ref.watch(profileRepositoryProvider).getCurrentUser();
  } on ApiException {
    if (sessionUser != null) {
      return sessionUser;
    }

    rethrow;
  }
});

class ProfileRepository {
  const ProfileRepository(this._dio);

  final Dio _dio;

  Future<AppUser> getCurrentUser() async {
    return _readUser(() => _dio.get<Object?>('/users/me'));
  }

  Future<AppUser> updateCurrentUser({required String displayName}) async {
    return _readUser(
      () => _dio.patch<Object?>(
        '/users/me',
        data: {'displayName': displayName, 'fullName': displayName},
      ),
    );
  }

  Future<AppUser> _readUser(Future<Response<Object?>> Function() request) async {
    try {
      final response = await request();
      final body = _asMap(response.data);
      final parsed = ApiResponse.fromJson<AppUser>(
        body,
        (value) => AppUser.fromJson(_asMap(value)),
      ).data;

      return parsed ?? AppUser.fromJson(_asMap(body['data'] ?? body));
    } on DioException catch (error) {
      throw ApiException(
        _errorMessage(error),
        statusCode: error.response?.statusCode,
      );
    }
  }
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }

  return <String, dynamic>{};
}

String _errorMessage(DioException error) {
  final body = _asMap(error.response?.data);
  final message = body['message']?.toString();
  if (message != null && message.isNotEmpty) {
    return message;
  }

  return error.message ?? 'Profile request failed.';
}