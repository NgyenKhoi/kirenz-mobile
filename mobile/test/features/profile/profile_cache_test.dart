import 'package:flutter_test/flutter_test.dart';
import 'package:kirenz_mobile/core/storage/token_storage.dart';
import 'package:kirenz_mobile/features/profile/data/cache/profile_cache.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('SQLite rows are isolated by authenticated account owner', () async {
    final storage = _OwnerTokenStorage('owner-1');
    final cache = SqliteProfileCache(
      storage,
      databaseFactoryFfi,
      inMemoryDatabasePath,
    );
    await cache.write('profile', 'me', {'id': 'owner-1'});

    storage.ownerId = 'owner-2';
    expect(await cache.read('profile', 'me'), isNull);
    await cache.write('profile', 'me', {'id': 'owner-2'});

    storage.ownerId = 'owner-1';
    expect((await cache.read('profile', 'me'))!.value, {'id': 'owner-1'});
  });
}

class _OwnerTokenStorage implements TokenStorage {
  _OwnerTokenStorage(this.ownerId);

  String? ownerId;

  @override
  Future<String?> readCurrentUserId() async => ownerId;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
