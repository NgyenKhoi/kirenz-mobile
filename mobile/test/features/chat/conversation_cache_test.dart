import 'package:flutter_test/flutter_test.dart';
import 'package:kirenz_mobile/core/storage/token_storage.dart';
import 'package:kirenz_mobile/features/chat/data/cache/conversation_cache.dart';
import 'package:kirenz_mobile/features/chat/domain/entities/conversation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test(
    'conversation rows are isolated by authenticated account owner',
    () async {
      final storage = _OwnerTokenStorage('owner-1');
      final cache = SqliteConversationCache(
        storage,
        databaseFactoryFfi,
        inMemoryDatabasePath,
      );
      await cache.write([_conversation('owner-1-conversation')]);

      storage.ownerId = 'owner-2';
      expect(await cache.read(), isNull);
      await cache.write([_conversation('owner-2-conversation')]);

      storage.ownerId = 'owner-1';
      final ownerOne = await cache.read();
      expect(ownerOne!.isCached, isTrue);
      expect(ownerOne.data.single.id, 'owner-1-conversation');
    },
  );
}

Conversation _conversation(String id) => Conversation(
  id: id,
  type: ConversationType.direct,
  name: null,
  participants: const [],
  adminIds: const {},
  currentUserAdmin: false,
  lastMessage: null,
  createdAt: null,
  updatedAt: DateTime.utc(2026, 7, 16),
  unreadCount: 0,
);

class _OwnerTokenStorage implements TokenStorage {
  _OwnerTokenStorage(this.ownerId);

  String? ownerId;

  @override
  Future<String?> readCurrentUserId() async => ownerId;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
