import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirenz_mobile/features/chat/data/cache/conversation_cache.dart';
import 'package:kirenz_mobile/features/chat/data/repositories/conversation_repository.dart';
import 'package:kirenz_mobile/features/chat/domain/entities/conversation.dart';

void main() {
  test('uses canonical conversation and group-management endpoints', () async {
    final requests = <RequestOptions>[];
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          final returnsVoid =
              options.path.endsWith('/leave') ||
              options.method == 'DELETE' &&
                  options.path == '/conversations/group-1';
          handler.resolve(
            Response<Object?>(
              requestOptions: options,
              statusCode: 200,
              data: {
                'success': true,
                'message': 'ok',
                'data': returnsVoid ? null : _conversationJson,
              },
            ),
          );
        },
      ),
    );
    final repository = ConversationRepository(dio);

    await repository.getConversation('group-1');
    await repository.getOrCreateDirect('user-2');
    await repository.createGroup(' Team ', ['user-2', 'user-3', 'user-2']);
    await repository.renameGroup('group-1', 'Renamed');
    await repository.addMember('group-1', 'user-4');
    await repository.kickMember('group-1', 'user-4');
    await repository.makeAdmin('group-1', 'user-3');
    await repository.updateNickname('group-1', 'user-3', 'Friend');
    await repository.leaveGroup('group-1');
    await repository.deleteGroup('group-1');

    expect(requests.map((request) => request.path), [
      '/conversations/group-1',
      '/conversations/direct/user-2',
      '/conversations',
      '/conversations/group-1',
      '/conversations/group-1/participants',
      '/conversations/group-1/participants/user-4',
      '/conversations/group-1/admins/user-3',
      '/conversations/group-1/nicknames/user-3',
      '/conversations/group-1/leave',
      '/conversations/group-1',
    ]);
    expect(requests[2].data, {
      'name': 'Team',
      'type': 'GROUP',
      'participantIds': ['user-2', 'user-3'],
    });
    expect(requests[4].queryParameters, {'userId': 'user-4'});
    expect(requests[7].data, {'nickname': 'Friend'});
    expect(requests[8].method, 'POST');
    expect(requests[9].method, 'DELETE');
  });

  test('rejects a malformed successful conversation list', () async {
    final cache = _MemoryCache([Conversation.fromJson(_conversationJson)]);
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.resolve(
          Response<Object?>(
            requestOptions: options,
            statusCode: 200,
            data: {
              'success': true,
              'data': [_conversationJson, 42],
            },
          ),
        ),
      ),
    );

    await expectLater(
      ConversationRepository(dio, cache).getConversations(),
      throwsException,
    );
    expect(cache.writes, 0);
    expect((await cache.read())!.data.single.id, 'group-1');
  });

  test(
    'void mutation requires a successful envelope before returning',
    () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.resolve(
            Response<Object?>(
              requestOptions: options,
              statusCode: 200,
              data: {'success': false, 'message': 'Cannot leave'},
            ),
          ),
        ),
      );

      await expectLater(
        ConversationRepository(dio).leaveGroup('group-1'),
        throwsException,
      );
    },
  );
}

class _MemoryCache implements ConversationCache {
  _MemoryCache(this.rows);

  final List<Conversation> rows;
  int writes = 0;

  @override
  Future<void> clear() async {}

  @override
  Future<CachedConversationList?> read() async =>
      CachedConversationList(data: rows, isCached: true);

  @override
  Future<void> write(List<Conversation> conversations) async {
    writes++;
  }
}

const _conversationJson = {
  'id': 'group-1',
  'type': 'GROUP',
  'name': 'Team',
  'participants': [],
  'adminIds': [],
  'currentUserAdmin': true,
  'lastMessage': null,
  'createdAt': '2026-07-16T01:00:00Z',
  'updatedAt': '2026-07-16T02:00:00Z',
  'unreadCount': 0,
};
