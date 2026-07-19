import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
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
    final accessToken = await _tokenStorage.readAccessToken();
    final refreshToken = await _tokenStorage.readRefreshToken();
    if (isAccessTokenUsable(accessToken)) {
      try {
        final user = await _getCurrentUser();
        await _tokenStorage.saveSession(
          accessToken: accessToken!,
          refreshToken: refreshToken ?? '',
          userId: user.id,
        );
        return user;
      } on ApiException {
        await _tokenStorage.clear();
        return null;
      }
    }
    if (refreshToken == null || refreshToken.isEmpty) {
      await _tokenStorage.clear();
      return null;
    }

    try {
      final result = await refresh(refreshToken);
      await _saveResult(result);
      final user = await _getCurrentUser();
      await _saveResult(result, userId: user.id);
      return user;
    } on ApiException {
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
    return _finishAuthentication(result);
  }

  Future<AppUser> loginWithGoogle({required String idToken}) async {
    final result = await _postAuthResult(
      '/auth/google',
      data: {'idToken': idToken},
    );
    return _finishAuthentication(result);
  }

  Future<RegisterResult> register({
    required String displayName,
    required String username,
    required String email,
    required String password,
  }) async {
    final response = await _post(
      '/auth/register',
      data: buildRegisterPayload(
        displayName: displayName,
        username: username,
        email: email,
        password: password,
      ),
    );
    final data = _asMap(response['data'] ?? response);
    return RegisterResult(
      email: data['email']?.toString() ?? email,
      otpSent: data['otpSent'] == true,
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
      '/verification/verify-otp',
      data: {'email': email, 'otp': code},
    );
  }

  Future<void> sendOtp({required String email}) async {
    await _post('/verification/send-otp', data: {'email': email});
  }

  Future<void> logout() async {
    await _tokenStorage.clear();
  }

  Future<void> _saveResult(AuthResultDto result, {String? userId}) async {
    if (!result.hasTokens) {
      throw const ApiException(
        'Authentication response did not include tokens.',
      );
    }

    await _tokenStorage.saveSession(
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
      userId: userId ?? _jwtSubject(result.accessToken),
    );
  }

  Future<AppUser> _finishAuthentication(AuthResultDto result) async {
    await _saveResult(result);
    try {
      final user = await _getCurrentUser();
      await _saveResult(result, userId: user.id);
      return user;
    } on Object {
      await _tokenStorage.clear();
      rethrow;
    }
  }

  Future<AppUser> _getCurrentUser() async {
    try {
      final response = await _dio.get<Object?>('/users/me');
      final body = _asMap(response.data);
      final envelope = ApiResponse.fromJson<AppUser>(
        body,
        (value) => AppUser.fromJson(_asMap(value)),
      );
      final user = envelope.data;
      if (!envelope.success || user == null || user.id == 'unknown-user') {
        throw ApiException(
          envelope.message ?? 'Current user response has an invalid shape.',
          kind: ApiFailureKind.parsing,
        );
      }
      return user;
    } on ApiException {
      rethrow;
    } on DioException catch (error) {
      final body = _asMap(error.response?.data);
      throw ApiException(
        body['message']?.toString() ??
            error.message ??
            'Current user request failed.',
        statusCode: error.response?.statusCode,
        kind: apiFailureKindForResponse(
          hasResponse: error.response != null,
          statusCode: error.response?.statusCode,
        ),
      );
    }
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
      final body = _asMap(error.response?.data);
      throw ApiException(
        _errorMessage(error),
        statusCode: error.response?.statusCode,
        fieldErrors: _fieldErrors(body),
      );
    }
  }
}

bool isAccessTokenUsable(String? token, {DateTime Function()? now}) {
  if (token == null || token.isEmpty) return false;
  final parts = token.split('.');
  if (parts.length != 3) return false;
  try {
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    if (payload is! Map) return false;
    final expiry = payload['exp'];
    final expirySeconds = expiry is num
        ? expiry.toInt()
        : int.tryParse(expiry?.toString() ?? '');
    if (expirySeconds == null) return false;
    final current = (now ?? DateTime.now)().add(const Duration(seconds: 30));
    return DateTime.fromMillisecondsSinceEpoch(
      expirySeconds * 1000,
      isUtc: true,
    ).isAfter(current.toUtc());
  } on FormatException {
    return false;
  }
}

String _jwtSubject(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return '';
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    return payload is Map ? payload['sub']?.toString() ?? '' : '';
  } on Object {
    return '';
  }
}

Map<String, dynamic> buildRegisterPayload({
  required String displayName,
  required String username,
  required String email,
  required String password,
}) {
  final normalizedDisplayName = displayName.trim();
  return {
    if (normalizedDisplayName.isNotEmpty) 'displayName': normalizedDisplayName,
    'username': username.trim(),
    'email': email.trim(),
    'password': password,
  };
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

  switch (error.type) {
    case DioExceptionType.connectionError:
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return 'Cannot reach the Kirenz API Gateway at ${AppConfig.apiBaseUrl}. Make sure the backend is running on port 8080. Android emulator should use 10.0.2.2, not localhost.';
    case DioExceptionType.badCertificate:
      return 'The Kirenz API certificate is not trusted by this device.';
    case DioExceptionType.cancel:
      return 'Login request was cancelled.';
    case DioExceptionType.badResponse:
    case DioExceptionType.unknown:
      return error.message ?? 'Network request failed.';
  }
}

Map<String, String> _fieldErrors(Map<String, dynamic> body) {
  final candidates = [
    body['fieldErrors'],
    body['errors'],
    body['validationErrors'],
  ];
  for (final candidate in candidates) {
    if (candidate is Map) {
      return candidate.map((key, value) {
        final message = value is List && value.isNotEmpty ? value.first : value;
        return MapEntry(key.toString(), message?.toString() ?? 'Invalid value');
      });
    }
  }
  return const {};
}

class RegisterResult {
  const RegisterResult({required this.email, required this.otpSent});

  final String email;
  final bool otpSent;
}
