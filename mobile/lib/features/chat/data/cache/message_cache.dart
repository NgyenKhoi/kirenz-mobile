import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../../../../core/storage/token_storage.dart';
import '../../domain/entities/chat_message.dart';

final messageCacheProvider = Provider<MessageCache>((ref) {
  return SqliteMessageCache(ref.watch(tokenStorageProvider));
});

class CachedMessages {
  const CachedMessages({required this.messages, required this.cachedAt});

  final List<ChatMessage> messages;
  final DateTime cachedAt;
}

abstract interface class MessageCache {
  Future<CachedMessages?> read(String conversationId);
  Future<void> write(String conversationId, List<ChatMessage> messages);
  Future<void> clear();
}

class SqliteMessageCache implements MessageCache {
  SqliteMessageCache(
    this._tokenStorage, [
    this._databaseFactoryOverride,
    this.databasePath,
  ]);

  final TokenStorage _tokenStorage;
  final DatabaseFactory? _databaseFactoryOverride;
  final String? databasePath;
  Database? _database;

  DatabaseFactory get _factory => _databaseFactoryOverride ?? databaseFactory;

  Future<Database> _open() async {
    final existing = _database;
    if (existing != null) return existing;
    final database = await _factory.openDatabase(
      databasePath ??
          path.join(
            await _factory.getDatabasesPath(),
            'kirenz_message_cache.db',
          ),
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (database, version) => database.execute('''
          CREATE TABLE message_cache (
            owner_id TEXT NOT NULL,
            conversation_id TEXT NOT NULL,
            payload TEXT NOT NULL,
            updated_at INTEGER NOT NULL,
            PRIMARY KEY (owner_id, conversation_id)
          )
        '''),
      ),
    );
    _database = database;
    return database;
  }

  @override
  Future<CachedMessages?> read(String conversationId) async {
    final ownerId = await _tokenStorage.readCurrentUserId();
    if (ownerId == null || ownerId.isEmpty || conversationId.isEmpty) {
      return null;
    }
    final rows = await (await _open()).query(
      'message_cache',
      where: 'owner_id = ? AND conversation_id = ?',
      whereArgs: [ownerId, conversationId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    final decoded = jsonDecode(row['payload']! as String);
    if (decoded is! List) return null;
    final messages = decoded
        .whereType<Map>()
        .map((item) => ChatMessage.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
    return CachedMessages(
      messages: messages,
      cachedAt: DateTime.fromMillisecondsSinceEpoch(
        row['updated_at']! as int,
        isUtc: true,
      ),
    );
  }

  @override
  Future<void> write(String conversationId, List<ChatMessage> messages) async {
    final ownerId = await _tokenStorage.readCurrentUserId();
    if (ownerId == null || ownerId.isEmpty || conversationId.isEmpty) return;
    await (await _open()).insert('message_cache', {
      'owner_id': ownerId,
      'conversation_id': conversationId,
      'payload': jsonEncode(
        messages.map((message) => message.toJson()).toList(growable: false),
      ),
      'updated_at': DateTime.now().toUtc().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> clear() async {
    final ownerId = await _tokenStorage.readCurrentUserId();
    if (ownerId == null || ownerId.isEmpty) {
      await (await _open()).delete('message_cache');
      return;
    }
    await (await _open()).delete(
      'message_cache',
      where: 'owner_id = ?',
      whereArgs: [ownerId],
    );
  }
}
