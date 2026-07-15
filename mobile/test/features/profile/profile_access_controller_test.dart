import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirenz_mobile/core/errors/api_exception.dart';
import 'package:kirenz_mobile/features/blocks/data/repositories/block_repository.dart';
import 'package:kirenz_mobile/features/blocks/domain/entities/block_models.dart';
import 'package:kirenz_mobile/features/friends/data/repositories/friend_repository.dart';
import 'package:kirenz_mobile/features/friends/domain/entities/friend_models.dart';
import 'package:kirenz_mobile/features/privacy/data/repositories/privacy_repository.dart';
import 'package:kirenz_mobile/features/privacy/domain/entities/privacy_settings.dart';
import 'package:kirenz_mobile/features/profile/data/repositories/profile_repository.dart';
import 'package:kirenz_mobile/features/profile/data/cache/profile_cache.dart';
import 'package:kirenz_mobile/features/profile/domain/entities/user_profile.dart';
import 'package:kirenz_mobile/features/profile/presentation/controllers/profile_access_controller.dart';

void main() {
  test('does not fetch profile hidden by privacy', () async {
    final profileRepository = _ProfileRepository();
    final container = _container(
      profileRepository: profileRepository,
      visibility: PrivacyVisibility.private,
    );
    addTearDown(container.dispose);

    final access = await container.read(profileAccessProvider('user-2').future);

    expect(access.isRestricted, isTrue);
    expect(profileRepository.requests, 0);
  });

  test('does not fetch profile when target blocked viewer', () async {
    final profileRepository = _ProfileRepository();
    final container = _container(
      profileRepository: profileRepository,
      visibility: PrivacyVisibility.public,
      blockedViewer: true,
    );
    addTearDown(container.dispose);

    final access = await container.read(profileAccessProvider('user-2').future);

    expect(access.blockedViewer, isTrue);
    expect(profileRepository.requests, 0);
  });

  test('fetches profile only after access checks allow it', () async {
    final profileRepository = _ProfileRepository();
    final container = _container(
      profileRepository: profileRepository,
      visibility: PrivacyVisibility.friendsOnly,
      relationship: RelationshipStatus.friends,
    );
    addTearDown(container.dispose);

    final access = await container.read(profileAccessProvider('user-2').future);

    expect(access.profile?.id, 'user-2');
    expect(profileRepository.requests, 1);
  });

  test(
    'unknown access failure fails closed without reading stale cache',
    () async {
      final cache = _MemoryCache(
        entry: ProfileCacheEntry(
          value: {'canView': true},
          updatedAt: DateTime.utc(2026, 7, 15),
        ),
      );
      final container = _container(
        profileRepository: _ProfileRepository(),
        visibility: PrivacyVisibility.public,
        friendError: StateError('malformed relationship payload'),
        cache: cache,
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(profileAccessProvider('user-2').future),
        throwsStateError,
      );
      expect(cache.reads, 0);
    },
  );

  test(
    'known offline failure uses a previously authorized access snapshot',
    () async {
      final cache = _MemoryCache(
        entry: ProfileCacheEntry(
          value: {
            'relationship': 'friends',
            'profileVisibility': 'friendsOnly',
            'postVisibility': 'friendsOnly',
            'allowDirectMessages': true,
            'showOnlineStatus': true,
            'blockedByViewer': false,
            'blockedViewer': false,
            'canView': true,
          },
          updatedAt: DateTime.utc(2026, 7, 15),
        ),
      );
      final container = _container(
        profileRepository: _ProfileRepository(cached: true),
        visibility: PrivacyVisibility.public,
        friendError: const ApiException(
          'Network unavailable.',
          kind: ApiFailureKind.transport,
        ),
        cache: cache,
      );
      addTearDown(container.dispose);

      final access = await container.read(
        profileAccessProvider('user-2').future,
      );

      expect(access.profile?.id, 'user-2');
      expect(cache.reads, 1);
      expect(container.read(profileCacheStatusProvider('user-2')), isNotNull);
    },
  );

  test(
    'application access failure fails closed without reading stale cache',
    () async {
      final cache = _MemoryCache(
        entry: ProfileCacheEntry(
          value: {'canView': true},
          updatedAt: DateTime.utc(2026, 7, 15),
        ),
      );
      final container = _container(
        profileRepository: _ProfileRepository(),
        visibility: PrivacyVisibility.public,
        friendError: const ApiException('Invalid relationship response.'),
        cache: cache,
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(profileAccessProvider('user-2').future),
        throwsA(isA<ApiException>()),
      );
      expect(cache.reads, 0);
    },
  );
}

ProviderContainer _container({
  required _ProfileRepository profileRepository,
  required PrivacyVisibility visibility,
  RelationshipStatus relationship = RelationshipStatus.none,
  bool blockedViewer = false,
  Object? friendError,
  _MemoryCache? cache,
}) {
  return ProviderContainer(
    overrides: [
      profileRepositoryProvider.overrideWithValue(profileRepository),
      profileCacheProvider.overrideWithValue(cache ?? _MemoryCache()),
      friendRepositoryProvider.overrideWithValue(
        _FriendRepository(relationship, error: friendError),
      ),
      privacyRepositoryProvider.overrideWithValue(
        _PrivacyRepository(visibility),
      ),
      blockRepositoryProvider.overrideWithValue(
        _BlockRepository(blockedViewer),
      ),
    ],
  );
}

class _MemoryCache implements ProfileCache {
  _MemoryCache({this.entry});

  final ProfileCacheEntry? entry;
  int reads = 0;

  @override
  Future<ProfileCacheEntry?> read(String resource, String userId) async {
    reads++;
    return entry;
  }

  @override
  Future<void> write(String resource, String userId, Object? value) async {}

  @override
  Future<void> clear() async {}

  @override
  Future<void> removeUser(String userId) async {}
}

class _FriendRepository extends FriendRepository {
  _FriendRepository(this.relationship, {this.error}) : super(Dio());
  final RelationshipStatus relationship;
  final Object? error;
  @override
  Future<RelationshipStatus> getStatus(String userId) async {
    if (error != null) throw error!;
    return relationship;
  }
}

class _PrivacyRepository extends PrivacyRepository {
  _PrivacyRepository(this.visibility) : super(Dio());
  final PrivacyVisibility visibility;
  @override
  Future<PrivacySettings> getForUser(String userId) async => PrivacySettings(
    userId: userId,
    profileVisibility: visibility,
    postVisibility: PrivacyVisibility.public,
    allowDirectMessages: true,
    showOnlineStatus: true,
    updatedAt: null,
  );
}

class _BlockRepository extends BlockRepository {
  _BlockRepository(this.blockedViewer) : super(Dio());
  final bool blockedViewer;
  @override
  Future<BlockStatus> getStatus(String userId) async => BlockStatus(
    viewerId: 'viewer-1',
    targetUserId: userId,
    blockedByViewer: false,
    blockedViewer: blockedViewer,
  );
}

class _ProfileRepository extends ProfileRepository {
  _ProfileRepository({this.cached = false}) : super(Dio());
  final bool cached;
  int requests = 0;
  @override
  Future<UserProfile> getUser(String userId) async {
    requests += 1;
    return UserProfile(
      id: userId,
      email: 'person@example.com',
      username: 'person',
      displayName: 'Person',
      avatarUrl: null,
      coverPhotoUrl: null,
      bio: null,
      birthDate: null,
      gender: null,
      location: null,
      website: null,
      role: ProfileRole.user,
      emailVerified: true,
      createdAt: null,
      updatedAt: null,
    );
  }

  @override
  Future<CachedProfileResource<UserProfile>> getUserCached(
    String userId,
  ) async {
    return CachedProfileResource(
      data: await getUser(userId),
      isCached: cached,
      cachedAt: cached ? DateTime.utc(2026, 7, 15) : null,
    );
  }
}
