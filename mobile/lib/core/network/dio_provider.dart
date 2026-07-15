import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../storage/token_storage.dart';

final sessionExpirationProvider = StateProvider<int>((ref) => 0);

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(createBaseOptions());
  dio.interceptors.add(
    AuthRefreshInterceptor(dio, ref.watch(tokenStorageProvider), () {
      ref.read(sessionExpirationProvider.notifier).state++;
    }),
  );
  return dio;
});

class AuthRefreshInterceptor extends Interceptor {
  AuthRefreshInterceptor(
    this._dio,
    this._tokenStorage,
    this._onSessionExpired, {
    Dio? refreshClient,
  }) : _refreshClient = refreshClient ?? Dio(createBaseOptions());

  final Dio _dio;
  final Dio _refreshClient;
  final TokenStorage _tokenStorage;
  final void Function() _onSessionExpired;
  Future<_RefreshTokens>? _refreshing;
  bool _sessionExpired = false;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra['skipAuth'] != true) {
      final token = await _tokenStorage.readAccessToken();
      if (token != null && token.isNotEmpty) {
        _sessionExpired = false;
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final request = err.requestOptions;
    final shouldRefresh =
        err.response?.statusCode == 401 &&
        request.extra['skipAuth'] != true &&
        request.extra['retriedAfterRefresh'] != true;
    if (!shouldRefresh) {
      handler.next(err);
      return;
    }

    final refreshToken = await _tokenStorage.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      await _expireSession();
      handler.next(err);
      return;
    }

    try {
      final refreshed = await _singleFlightRefresh(refreshToken);
      final activeRefreshToken = await _tokenStorage.readRefreshToken();
      if (activeRefreshToken != refreshToken) {
        handler.next(err);
        return;
      }
      final currentUserId = await _tokenStorage.readCurrentUserId();
      await _tokenStorage.saveSession(
        accessToken: refreshed.accessToken,
        refreshToken: refreshed.refreshToken,
        userId: refreshed.userId.isEmpty
            ? currentUserId ?? ''
            : refreshed.userId,
      );
      _sessionExpired = false;
      final retryOptions = request.copyWith(
        headers: {
          ...request.headers,
          'Authorization': 'Bearer ${refreshed.accessToken}',
        },
        extra: {...request.extra, 'retriedAfterRefresh': true},
      );
      handler.resolve(await _dio.fetch<Object?>(retryOptions));
    } on Object {
      final activeRefreshToken = await _tokenStorage.readRefreshToken();
      if (activeRefreshToken == refreshToken) {
        await _expireSession();
      }
      handler.next(err);
    }
  }

  Future<_RefreshTokens> _singleFlightRefresh(String refreshToken) {
    final active = _refreshing;
    if (active != null) return active;
    final refresh = _refreshTokens(refreshToken);
    _refreshing = refresh;
    refresh.whenComplete(() {
      if (identical(_refreshing, refresh)) _refreshing = null;
    });
    return refresh;
  }

  Future<_RefreshTokens> _refreshTokens(String refreshToken) async {
    final response = await _refreshClient.post<Object?>(
      '/auth/refresh',
      data: {'refreshToken': refreshToken},
      options: Options(extra: {'skipAuth': true}),
    );
    final body = _asMap(response.data);
    final data = _asMap(body['data'] ?? body);
    final tokens = _RefreshTokens(
      accessToken: _readString(data, ['accessToken', 'access_token', 'token']),
      refreshToken: _readString(data, ['refreshToken', 'refresh_token']),
      userId: _readString(data, ['userId', 'id', 'uuid']),
    );
    if (tokens.accessToken.isEmpty || tokens.refreshToken.isEmpty) {
      throw StateError('Refresh response did not include tokens.');
    }
    return tokens;
  }

  Future<void> _expireSession() async {
    if (_sessionExpired) return;
    _sessionExpired = true;
    await _tokenStorage.clear();
    _onSessionExpired();
  }
}

BaseOptions createBaseOptions() {
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
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

String _readString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value != null && value.toString().isNotEmpty) return value.toString();
  }
  return '';
}
