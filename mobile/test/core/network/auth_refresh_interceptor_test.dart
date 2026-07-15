import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirenz_mobile/core/network/dio_provider.dart';
import 'package:kirenz_mobile/core/storage/token_storage.dart';

void main() {
  test('concurrent 401 responses share one refresh and retry once', () async {
    final storage = _MemoryTokenStorage();
    final adapter = _AuthAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = adapter;
    dio.interceptors.add(
      AuthRefreshInterceptor(
        dio,
        storage,
        () => fail('session must remain active'),
        refreshClient: dio,
      ),
    );

    final responses = await Future.wait([dio.get('/one'), dio.get('/two')]);

    expect(responses.map((response) => response.statusCode), everyElement(200));
    expect(adapter.refreshCalls, 1);
    expect(adapter.protectedCalls, 4);
    expect(storage.accessToken, 'new-access');
  });

  test('refresh completion cannot restore a logged-out session', () async {
    final storage = _MemoryTokenStorage();
    final adapter = _AuthAdapter(gateRefresh: true);
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = adapter;
    dio.interceptors.add(
      AuthRefreshInterceptor(dio, storage, () {}, refreshClient: dio),
    );

    final request = dio.get('/one');
    await adapter.refreshStarted.future;
    await storage.clear();
    adapter.releaseRefresh.complete();

    await expectLater(request, throwsA(isA<DioException>()));
    expect(storage.accessToken, isNull);
    expect(adapter.protectedCalls, 1);
  });
}

class _MemoryTokenStorage implements TokenStorage {
  String? accessToken = 'old-access';
  String? refreshToken = 'refresh-token';
  String? userId = 'user-1';

  @override
  Future<String?> readAccessToken() async => accessToken;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<String?> readCurrentUserId() async => userId;

  @override
  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required String userId,
  }) async {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
    this.userId = userId;
  }

  @override
  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
    userId = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AuthAdapter implements HttpClientAdapter {
  _AuthAdapter({this.gateRefresh = false});

  final bool gateRefresh;
  final Completer<void> refreshStarted = Completer<void>();
  final Completer<void> releaseRefresh = Completer<void>();
  int refreshCalls = 0;
  int protectedCalls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path == '/auth/refresh') {
      refreshCalls++;
      if (!refreshStarted.isCompleted) refreshStarted.complete();
      if (gateRefresh) {
        await releaseRefresh.future;
      } else {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      return _json(200, {
        'success': true,
        'data': {
          'accessToken': 'new-access',
          'refreshToken': 'new-refresh',
          'userId': 'user-1',
        },
      });
    }
    protectedCalls++;
    if (options.headers['Authorization'] == 'Bearer new-access') {
      return _json(200, {'success': true, 'data': options.path});
    }
    return _json(401, {'success': false, 'message': 'Expired'});
  }

  ResponseBody _json(int statusCode, Object body) {
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
