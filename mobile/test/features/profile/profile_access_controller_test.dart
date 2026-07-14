import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirenz_mobile/features/blocks/data/repositories/block_repository.dart';
import 'package:kirenz_mobile/features/blocks/domain/entities/block_models.dart';
import 'package:kirenz_mobile/features/friends/data/repositories/friend_repository.dart';
import 'package:kirenz_mobile/features/friends/domain/entities/friend_models.dart';
import 'package:kirenz_mobile/features/privacy/data/repositories/privacy_repository.dart';
import 'package:kirenz_mobile/features/privacy/domain/entities/privacy_settings.dart';
import 'package:kirenz_mobile/features/profile/data/repositories/profile_repository.dart';
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
}

ProviderContainer _container({
  required _ProfileRepository profileRepository,
  required PrivacyVisibility visibility,
  RelationshipStatus relationship = RelationshipStatus.none,
  bool blockedViewer = false,
}) {
  return ProviderContainer(
    overrides: [
      profileRepositoryProvider.overrideWithValue(profileRepository),
      friendRepositoryProvider.overrideWithValue(
        _FriendRepository(relationship),
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

class _FriendRepository extends FriendRepository {
  _FriendRepository(this.relationship) : super(Dio());
  final RelationshipStatus relationship;
  @override
  Future<RelationshipStatus> getStatus(String userId) async => relationship;
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
  _ProfileRepository() : super(Dio());
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
}
