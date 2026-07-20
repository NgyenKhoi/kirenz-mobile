import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirenz_mobile/features/blocks/data/repositories/block_repository.dart';

void main() {
  test('preserves block direction and uses canonical endpoints', () async {
    final paths = <String>[];
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          paths.add('${options.method} ${options.path}');
          final data = options.path.contains('/status/')
              ? {
                  'viewerId': 'viewer-1',
                  'targetUserId': 'user-2',
                  'blockedByViewer': false,
                  'blockedViewer': true,
                }
              : options.path == '/blocks' && options.method == 'GET'
              ? [
                  {
                    'id': 'block-1',
                    'blockedUserId': 'user-2',
                    'createdAt': '2026-07-15T01:00:00Z',
                    'blockedUser': {
                      'id': 'user-2',
                      'username': 'mai',
                      'displayName': 'Mai Nguyen',
                      'avatarUrl': 'https://example.test/mai.jpg',
                    },
                  },
                ]
              : null;
          handler.resolve(
            Response<Object?>(
              requestOptions: options,
              statusCode: 200,
              data: {'success': true, 'message': 'ok', 'data': data},
            ),
          );
        },
      ),
    );
    final repository = BlockRepository(dio);

    final status = await repository.getStatus('user-2');
    final blocked = await repository.listBlockedUsers();
    await repository.block('user-2');
    await repository.unblock('user-2');

    expect(status.blockedByViewer, isFalse);
    expect(status.blockedViewer, isTrue);
    expect(blocked.single.blockedUserId, 'user-2');
    expect(blocked.single.resolvedName, 'Mai Nguyen');
    expect(blocked.single.username, 'mai');
    expect(blocked.single.avatarUrl, 'https://example.test/mai.jpg');
    expect(paths, [
      'GET /blocks/status/user-2',
      'GET /blocks',
      'POST /blocks/user-2',
      'DELETE /blocks/user-2',
    ]);
  });
}
