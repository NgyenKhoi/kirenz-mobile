import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../storage/token_storage.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(_baseOptions());
  final tokenStorage = ref.watch(tokenStorageProvider);

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final skipAuth = options.extra['skipAuth'] == true;

        if (!skipAuth) {
          final token = await tokenStorage.readAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        }

        handler.next(options);
      },
      onError: (error, handler) async {
        final request = error.requestOptions;
        final skipAuth = request.extra['skipAuth'] == true;
        final alreadyRetried = request.extra['retriedAfterRefresh'] == true;

        if (skipAuth || alreadyRetried || error.response?.statusCode != 401) {
          handler.next(error);
          return;
        }

        final refreshToken = await tokenStorage.readRefreshToken();
        if (refreshToken == null || refreshToken.isEmpty) {
          handler.next(error);
          return;
        }

        try {
          final refreshed = await _refreshTokens(refreshToken);
          final accessToken = refreshed.accessToken;
          final newRefreshToken = refreshed.refreshToken;
          final currentUserId = await tokenStorage.readCurrentUserId();
          final userId = refreshed.userId.isEmpty
              ? currentUserId ?? ''
              : refreshed.userId;

          if (accessToken.isEmpty || newRefreshToken.isEmpty) {
            handler.next(error);
            return;
          }

          await tokenStorage.saveSession(
            accessToken: accessToken,
            refreshToken: newRefreshToken,
            userId: userId,
          );

          final retryOptions = request.copyWith(
            headers: {
              ...request.headers,
              'Authorization': 'Bearer $accessToken',
            },
            extra: {...request.extra, 'retriedAfterRefresh': true},
          );

          final response = await dio.fetch<Object?>(retryOptions);
          handler.resolve(response);
        } on Object {
          await tokenStorage.clear();
          handler.next(error);
        }
      },
    ),
  );

  return dio;
});

BaseOptions _baseOptions() {
  return BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
    headers: const {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    },
  );
}

Future<_RefreshTokens> _refreshTokens(String refreshToken) async {
  final client = Dio(_baseOptions());
  final response = await client.post<Object?>(
    '/auth/refresh',
    data: {'refreshToken': refreshToken},
    options: Options(extra: {'skipAuth': true}),
  );
  final body = _asMap(response.data);
  final data = _asMap(body['data'] ?? body);

  return _RefreshTokens(
    accessToken: _readString(data, ['accessToken', 'access_token', 'token']),
    refreshToken: _readString(data, ['refreshToken', 'refresh_token']),
    userId: _readString(data, ['userId', 'id', 'uuid']),
  );
}

class _RefreshTokens {
  const _RefreshTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
  });

  final String accessToken;
  final String refreshToken;
  final String userId;
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

String _readString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value != null && value.toString().isNotEmpty) {
      return value.toString();
    }
  }

  return '';
}
