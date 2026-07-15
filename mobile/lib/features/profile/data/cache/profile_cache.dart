import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../../../../core/storage/token_storage.dart';

final profileCacheProvider = Provider<ProfileCache>((ref) {
  return SqliteProfileCache(ref.watch(tokenStorageProvider));
});

class CachedProfileResource<T> {
  const CachedProfileResource({
    required this.data,
    required this.isCached,
    this.cachedAt,
  });

  final T data;
  final bool isCached;
  final DateTime? cachedAt;
}

class ProfileCacheEntry {
  const ProfileCacheEntry({required this.value, required this.updatedAt});

  final Object? value;
  final DateTime updatedAt;
}

abstract interface class ProfileCache {
  Future<ProfileCacheEntry?> read(String resource, String userId);

  Future<void> write(String resource, String userId, Object? value);

  Future<void> removeUser(String userId);

  Future<void> clear();
}

class SqliteProfileCache implements ProfileCache {
  SqliteProfileCache(
    this._tokenStorage, [
    this._databaseFactoryOverride,
    this.databasePath,
  ]);

  final TokenStorage _tokenStorage;
  final DatabaseFactory? _databaseFactoryOverride;
  final String? databasePath;
  Database? _database;

  DatabaseFactory get _databaseFactory =>
      _databaseFactoryOverride ?? databaseFactory;

  Future<Database> _open() async {
    final existing = _database;
    if (existing != null) return existing;
    final database = await _databaseFactory.openDatabase(
      databasePath ??
          path.join(
            await _databaseFactory.getDatabasesPath(),
            'kirenz_profile_cache.db',
          ),
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (database, version) async {
          await _createTable(database);
        },
        onUpgrade: (database, oldVersion, newVersion) async {
          await database.execute('DROP TABLE IF EXISTS profile_cache');
          await _createTable(database);
        },
      ),
    );
    _database = database;
    return database;
  }

  Future<void> _createTable(Database database) {
    return database.execute('''
          CREATE TABLE profile_cache (
            owner_id TEXT NOT NULL,
            resource TEXT NOT NULL,
            user_id TEXT NOT NULL,
            payload TEXT NOT NULL,
            updated_at INTEGER NOT NULL,
            PRIMARY KEY (owner_id, resource, user_id)
          )
        ''');
  }

  @override
  Future<ProfileCacheEntry?> read(String resource, String userId) async {
    final ownerId = await _tokenStorage.readCurrentUserId();
    if (ownerId == null || ownerId.isEmpty) return null;
    final rows = await (await _open()).query(
      'profile_cache',
      columns: ['payload', 'updated_at'],
      where: 'owner_id = ? AND resource = ? AND user_id = ?',
      whereArgs: [ownerId, resource, userId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    return ProfileCacheEntry(
      value: jsonDecode(row['payload']! as String),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        row['updated_at']! as int,
        isUtc: true,
      ),
    );
  }

  @override
  Future<void> write(String resource, String userId, Object? value) async {
    final ownerId = await _tokenStorage.readCurrentUserId();
    if (ownerId == null || ownerId.isEmpty) return;
    await (await _open()).insert('profile_cache', {
      'owner_id': ownerId,
      'resource': resource,
      'user_id': userId,
      'payload': jsonEncode(value),
      'updated_at': DateTime.now().toUtc().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> removeUser(String userId) async {
    final ownerId = await _tokenStorage.readCurrentUserId();
    if (ownerId == null || ownerId.isEmpty) return;
    await (await _open()).delete(
      'profile_cache',
      where: 'owner_id = ? AND user_id = ?',
      whereArgs: [ownerId, userId],
    );
  }

  @override
  Future<void> clear() async {
    final ownerId = await _tokenStorage.readCurrentUserId();
    if (ownerId == null || ownerId.isEmpty) {
      await (await _open()).delete('profile_cache');
      return;
    }
    await (await _open()).delete(
      'profile_cache',
      where: 'owner_id = ?',
      whereArgs: [ownerId],
    );
  }
}
