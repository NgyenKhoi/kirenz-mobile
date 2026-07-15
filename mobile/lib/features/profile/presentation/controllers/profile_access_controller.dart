import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../blocks/domain/entities/block_models.dart';
import '../../../blocks/presentation/controllers/block_controller.dart';
import '../../../friends/domain/entities/friend_models.dart';
import '../../../friends/presentation/controllers/friends_controller.dart';
import '../../../privacy/domain/entities/privacy_settings.dart';
import '../../../privacy/presentation/controllers/privacy_controller.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/cache/profile_cache.dart';
import '../../domain/entities/user_profile.dart';

class ProfileAccess {
  const ProfileAccess({
    required this.relationship,
    required this.privacy,
    required this.blockStatus,
    required this.profile,
  });

  final RelationshipStatus relationship;
  final PrivacySettings privacy;
  final BlockStatus blockStatus;
  final UserProfile? profile;

  bool get isRestricted => profile == null;
  bool get blockedByViewer => blockStatus.blockedByViewer;
  bool get blockedViewer => blockStatus.blockedViewer;
}

final profileAccessProvider = FutureProvider.family<ProfileAccess, String>((
  ref,
  userId,
) async {
  final cache = ref.watch(profileCacheProvider);
  List<Object> results;
  try {
    results = await Future.wait<Object>([
      ref.watch(friendStatusProvider(userId).future),
      ref.watch(userPrivacyProvider(userId).future),
      ref.watch(blockStatusProvider(userId).future),
    ]);
  } on Object catch (error) {
    final canUseCache =
        error is ApiException &&
        (error.kind == ApiFailureKind.transport ||
            error.kind == ApiFailureKind.server);
    final cached = canUseCache
        ? await _safeCacheRead(cache, 'access', userId)
        : null;
    if (cached?.value is Map) {
      return _cachedAccess(
        ref,
        userId,
        Map<String, dynamic>.from(cached!.value! as Map),
        cached.updatedAt,
      );
    }
    rethrow;
  }
  final relationship = results[0] as RelationshipStatus;
  final privacy = results[1] as PrivacySettings;
  final blockStatus = results[2] as BlockStatus;
  final canView =
      !blockStatus.blockedByViewer &&
      !blockStatus.blockedViewer &&
      (privacy.profileVisibility == PrivacyVisibility.public ||
          privacy.profileVisibility == PrivacyVisibility.friendsOnly &&
              relationship == RelationshipStatus.friends);
  UserProfile? profile;
  if (canView) {
    final result = await ref
        .watch(profileRepositoryProvider)
        .getUserCached(userId);
    profile = result.data;
    ref
        .read(profileCacheStatusProvider(userId).notifier)
        .state = result.isCached && result.cachedAt != null
        ? ProfileCacheEntry(value: null, updatedAt: result.cachedAt!)
        : null;
  }
  final access = ProfileAccess(
    relationship: relationship,
    privacy: privacy,
    blockStatus: blockStatus,
    profile: profile,
  );
  await _safeCacheWrite(cache, 'access', userId, {
    'relationship': relationship.name,
    'profileVisibility': privacy.profileVisibility.name,
    'postVisibility': privacy.postVisibility.name,
    'allowDirectMessages': privacy.allowDirectMessages,
    'showOnlineStatus': privacy.showOnlineStatus,
    'blockedByViewer': blockStatus.blockedByViewer,
    'blockedViewer': blockStatus.blockedViewer,
    'canView': canView,
  });
  return access;
});

Future<ProfileCacheEntry?> _safeCacheRead(
  ProfileCache cache,
  String resource,
  String userId,
) async {
  try {
    return await cache.read(resource, userId);
  } on Object {
    return null;
  }
}

Future<void> _safeCacheWrite(
  ProfileCache cache,
  String resource,
  String userId,
  Object? value,
) async {
  try {
    await cache.write(resource, userId, value);
  } on Object {
    return;
  }
}

Future<ProfileAccess> _cachedAccess(
  Ref ref,
  String userId,
  Map<String, dynamic> json,
  DateTime cachedAt,
) async {
  final relationship = RelationshipStatus.values.firstWhere(
    (value) => value.name == json['relationship'],
    orElse: () => RelationshipStatus.unsupported,
  );
  final profileVisibility = PrivacyVisibility.values.firstWhere(
    (value) => value.name == json['profileVisibility'],
    orElse: () => PrivacyVisibility.private,
  );
  final postVisibility = PrivacyVisibility.values.firstWhere(
    (value) => value.name == json['postVisibility'],
    orElse: () => PrivacyVisibility.private,
  );
  final privacy = PrivacySettings(
    userId: userId,
    profileVisibility: profileVisibility,
    postVisibility: postVisibility,
    allowDirectMessages: json['allowDirectMessages'] == true,
    showOnlineStatus: json['showOnlineStatus'] == true,
    updatedAt: cachedAt,
  );
  final blockStatus = BlockStatus(
    viewerId: '',
    targetUserId: userId,
    blockedByViewer: json['blockedByViewer'] == true,
    blockedViewer: json['blockedViewer'] == true,
  );
  UserProfile? profile;
  if (json['canView'] == true &&
      !blockStatus.blockedByViewer &&
      !blockStatus.blockedViewer) {
    final result = await ref
        .read(profileRepositoryProvider)
        .getUserCached(userId);
    if (!result.isCached) {
      throw const ApiException('Saved profile is unavailable offline.');
    }
    profile = result.data;
    ref.read(profileCacheStatusProvider(userId).notifier).state =
        ProfileCacheEntry(value: null, updatedAt: cachedAt);
  }
  return ProfileAccess(
    relationship: relationship,
    privacy: privacy,
    blockStatus: blockStatus,
    profile: profile,
  );
}
