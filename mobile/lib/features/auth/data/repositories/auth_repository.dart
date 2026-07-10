import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/network/api_response.dart';
import '../../../../core/network/dio_provider.dart';
import '../../../../core/storage/token_storage.dart';
import '../../domain/entities/app_user.dart';
import '../dto/auth_result_dto.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(dioProvider),
    ref.watch(tokenStorageProvider),
  );
});

class AuthRepository {
  const AuthRepository(this._dio, this._tokenStorage);

  final Dio _dio;
  final TokenStorage _tokenStorage;

  Future<AppUser?> restoreSession() async {
    final refreshToken = await _tokenStorage.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      return null;
    }

    try {
      final result = await refresh(refreshToken);
      await _saveResult(result);
      return result.user;
    } on ApiException catch (error) {
      if (error.statusCode == null) {
        return _storedUserFallback();
      }

      await _tokenStorage.clear();
      return null;
    }
  }

  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    final result = await _postAuthResult(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    await _saveResult(result);
    return result.user;
  }

  Future<void> register({
    required String displayName,
    required String email,
    required String password,
  }) async {
    await _post(
      '/auth/register',
      data: {
        'displayName': displayName,
        'fullName': displayName,
        'email': email,
        'password': password,
      },
    );
  }

  Future<AuthResultDto> refresh(String refreshToken) async {
    return _postAuthResult(
      '/auth/refresh',
      data: {'refreshToken': refreshToken},
    );
  }

  Future<void> verifyOtp({required String email, required String code}) async {
    await _post(
      '/verification/verify',
      data: {'email': email, 'code': code, 'otp': code},
    );
  }

  Future<void> logout() async {
    await _tokenStorage.clear();
  }

  Future<void> _saveResult(AuthResultDto result) async {
    if (!result.hasTokens) {
      throw const ApiException(
        'Authentication response did not include tokens.',
      );
    }

    await _tokenStorage.saveSession(
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
      userId: result.user.id,
    );
  }

  Future<AppUser?> _storedUserFallback() async {
    final userId = await _tokenStorage.readCurrentUserId();
    if (userId == null || userId.isEmpty) {
      return null;
    }

    return AppUser(id: userId, displayName: 'Kirenz User', email: '');
  }

  Future<AuthResultDto> _postAuthResult(
    String path, {
    required Map<String, dynamic> data,
  }) async {
    final response = await _post(path, data: data);
    final parsed = ApiResponse.fromJson<AuthResultDto>(
      response,
      AuthResultDto.fromJson,
    ).data;

    return parsed ?? AuthResultDto.fromJson(response['data'] ?? response);
  }

  Future<Map<String, dynamic>> _post(
    String path, {
    required Map<String, dynamic> data,
  }) async {
    try {
      final response = await _dio.post<Object?>(
        path,
        data: data,
        options: Options(extra: {'skipAuth': true}),
      );
      final body = _asMap(response.data);
      final apiResponse = ApiResponse.fromJson<Object?>(body, (value) => value);

      if (body.containsKey('success') && !apiResponse.success) {
        throw ApiException(apiResponse.message ?? 'Request failed.');
      }

      return body;
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

  return error.message ?? 'Network request failed.';
}
