import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../../../../core/storage/token_storage.dart';
import '../../domain/entities/conversation.dart';

final conversationCacheProvider = Provider<ConversationCache>((ref) {
  return SqliteConversationCache(ref.watch(tokenStorageProvider));
});

class CachedConversationList {
  const CachedConversationList({
    required this.data,
    required this.isCached,
    this.cachedAt,
  });

  final List<Conversation> data;
  final bool isCached;
  final DateTime? cachedAt;
}

abstract interface class ConversationCache {
  Future<CachedConversationList?> read();
  Future<void> write(List<Conversation> conversations);
  Future<void> clear();
}

class SqliteConversationCache implements ConversationCache {
  SqliteConversationCache(
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
            'kirenz_conversation_cache.db',
          ),
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (database, version) => database.execute('''
          CREATE TABLE conversation_cache (
            owner_id TEXT PRIMARY KEY,
            payload TEXT NOT NULL,
            updated_at INTEGER NOT NULL
          )
        '''),
      ),
    );
    _database = database;
    return database;
  }

  @override
  Future<CachedConversationList?> read() async {
    final ownerId = await _tokenStorage.readCurrentUserId();
    if (ownerId == null || ownerId.isEmpty) return null;
    final rows = await (await _open()).query(
      'conversation_cache',
      where: 'owner_id = ?',
      whereArgs: [ownerId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    final value = jsonDecode(row['payload']! as String);
    final conversations = value is List
        ? value
              .map((item) => Conversation.fromJson(_map(item)))
              .where((item) => item.id.isNotEmpty)
              .toList(growable: false)
        : <Conversation>[];
    return CachedConversationList(
      data: conversations,
      isCached: true,
      cachedAt: DateTime.fromMillisecondsSinceEpoch(
        row['updated_at']! as int,
        isUtc: true,
      ),
    );
  }

  @override
  Future<void> write(List<Conversation> conversations) async {
    final ownerId = await _tokenStorage.readCurrentUserId();
    if (ownerId == null || ownerId.isEmpty) return;
    await (await _open()).insert('conversation_cache', {
      'owner_id': ownerId,
      'payload': jsonEncode(
        conversations.map((item) => item.toJson()).toList(growable: false),
      ),
      'updated_at': DateTime.now().toUtc().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> clear() async {
    final ownerId = await _tokenStorage.readCurrentUserId();
    if (ownerId == null || ownerId.isEmpty) {
      await (await _open()).delete('conversation_cache');
      return;
    }
    await (await _open()).delete(
      'conversation_cache',
      where: 'owner_id = ?',
      whereArgs: [ownerId],
    );
  }
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
