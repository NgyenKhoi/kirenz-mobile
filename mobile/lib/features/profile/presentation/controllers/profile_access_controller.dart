import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../blocks/domain/entities/block_models.dart';
import '../../../blocks/presentation/controllers/block_controller.dart';
import '../../../friends/domain/entities/friend_models.dart';
import '../../../friends/presentation/controllers/friends_controller.dart';
import '../../../privacy/domain/entities/privacy_settings.dart';
import '../../../privacy/presentation/controllers/privacy_controller.dart';
import '../../data/repositories/profile_repository.dart';
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
  final results = await Future.wait<Object>([
    ref.watch(friendStatusProvider(userId).future),
    ref.watch(userPrivacyProvider(userId).future),
    ref.watch(blockStatusProvider(userId).future),
  ]);
  final relationship = results[0] as RelationshipStatus;
  final privacy = results[1] as PrivacySettings;
  final blockStatus = results[2] as BlockStatus;
  final canView =
      !blockStatus.blockedByViewer &&
      !blockStatus.blockedViewer &&
      (privacy.profileVisibility == PrivacyVisibility.public ||
          privacy.profileVisibility == PrivacyVisibility.friendsOnly &&
              relationship == RelationshipStatus.friends);
  final profile = canView
      ? await ref.watch(profileRepositoryProvider).getUser(userId)
      : null;
  return ProfileAccess(
    relationship: relationship,
    privacy: privacy,
    blockStatus: blockStatus,
    profile: profile,
  );
});
