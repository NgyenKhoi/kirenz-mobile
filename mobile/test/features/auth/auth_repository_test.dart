import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirenz_mobile/core/storage/token_storage.dart';
import 'package:kirenz_mobile/features/auth/data/repositories/auth_repository.dart';

void main() {
  test('uses a JWT access token only while safely before expiry', () {
    final now = DateTime.utc(2026, 7, 15, 12);
    final usable = _token(now.add(const Duration(minutes: 2)));
    final nearlyExpired = _token(now.add(const Duration(seconds: 20)));

    expect(isAccessTokenUsable(usable, now: () => now), isTrue);
    expect(isAccessTokenUsable(nearlyExpired, now: () => now), isFalse);
    expect(isAccessTokenUsable('not-a-jwt', now: () => now), isFalse);
  });

  test('omits an empty optional display name from register payload', () {
    final payload = buildRegisterPayload(
      displayName: '   ',
      username: ' user.name ',
      email: ' user@example.com ',
      password: 'password123',
    );

    expect(payload.containsKey('displayName'), isFalse);
    expect(payload['username'], 'user.name');
    expect(payload['email'], 'user@example.com');
  });

  test(
    'expired token plus offline refresh clears the stored session',
    () async {
      final storage = _MemoryTokenStorage(
        accessToken: _token(DateTime.utc(2020)),
        refreshToken: 'refresh-token',
        userId: 'user-1',
      );
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = _OfflineAdapter();
      final repository = AuthRepository(dio, storage);

      expect(await repository.restoreSession(), isNull);
      expect(storage.wasCleared, isTrue);
    },
  );
}

String _token(DateTime expiresAt) {
  final header = base64Url.encode(utf8.encode(jsonEncode({'alg': 'none'})));
  final payload = base64Url.encode(
    utf8.encode(jsonEncode({'exp': expiresAt.millisecondsSinceEpoch ~/ 1000})),
  );
  return '$header.$payload.signature';
}

class _MemoryTokenStorage implements TokenStorage {
  _MemoryTokenStorage({this.accessToken, this.refreshToken, this.userId});

  String? accessToken;
  String? refreshToken;
  String? userId;
  bool wasCleared = false;

  @override
  Future<String?> readAccessToken() async => accessToken;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<String?> readCurrentUserId() async => userId;

  @override
  Future<void> clear() async {
    wasCleared = true;
    accessToken = null;
    refreshToken = null;
    userId = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _OfflineAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) {
    throw DioException.connectionError(
      requestOptions: options,
      reason: 'offline',
    );
  }

  @override
  void close({bool force = false}) {}
}
