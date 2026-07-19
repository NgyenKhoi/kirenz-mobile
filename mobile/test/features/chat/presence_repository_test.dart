import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirenz_mobile/core/errors/api_exception.dart';
import 'package:kirenz_mobile/features/chat/data/repositories/presence_repository.dart';

void main() {
  test(
    'loads presence in bounded batches and parses epoch milliseconds',
    () async {
      final requests = <RequestOptions>[];
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            final ids = options.queryParameters['userIds'].toString().split(
              ',',
            );
            handler.resolve(
              Response<Object?>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'success': true,
                  'data': {
                    for (final id in ids)
                      id: {
                        'isOnline': id == 'user-1',
                        'lastSeen': id == 'user-1' ? null : 1721304000000,
                      },
                  },
                },
              ),
            );
          },
        ),
      );

      final result = await PresenceRepository(
        dio,
        batchSize: 2,
      ).getStatuses(['user-1', 'user-2', 'user-2', 'user-3']);

      expect(requests, hasLength(2));
      expect(requests.first.path, '/presence/status');
      expect(requests.first.queryParameters['userIds'], 'user-1,user-2');
      expect(result['user-1']!.isOnline, isTrue);
      expect(result['user-2']!.lastSeen!.isUtc, isTrue);
    },
  );

  test('rejects the realtime status shape in a REST snapshot', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.resolve(
          Response<Object?>(
            requestOptions: options,
            statusCode: 200,
            data: {
              'success': true,
              'data': {
                'user-1': {'status': 'ONLINE', 'lastSeen': null},
              },
            },
          ),
        ),
      ),
    );

    await expectLater(
      PresenceRepository(dio).getStatuses(['user-1']),
      throwsA(isA<ApiException>()),
    );
  });
}
