import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirenz_mobile/app/theme.dart';
import 'package:kirenz_mobile/features/blocks/domain/entities/block_models.dart';
import 'package:kirenz_mobile/features/friends/domain/entities/friend_models.dart';
import 'package:kirenz_mobile/features/friends/presentation/controllers/friends_controller.dart';
import 'package:kirenz_mobile/features/privacy/domain/entities/privacy_settings.dart';
import 'package:kirenz_mobile/features/profile/data/cache/profile_cache.dart';
import 'package:kirenz_mobile/features/profile/data/repositories/profile_content_repository.dart';
import 'package:kirenz_mobile/features/profile/data/repositories/profile_repository.dart';
import 'package:kirenz_mobile/features/profile/domain/entities/user_profile.dart';
import 'package:kirenz_mobile/features/profile/presentation/controllers/profile_access_controller.dart';
import 'package:kirenz_mobile/features/profile/presentation/screens/profile_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'current-user Profile renders header actions and tabs on a phone',
    (tester) async {
      await _setPhoneViewport(tester);
      await _pumpProfile(
        tester,
        screen: const ProfileScreen(),
        currentUser: _profile,
        theme: KirenzTheme.light,
      );

      expect(find.text('Edit cover'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      for (final scrollable in tester.stateList<ScrollableState>(
        find.byType(Scrollable),
      )) {
        scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
      }
      await tester.pumpAndSettle();
      expect(find.text('Posts'), findsOneWidget);
      expect(find.text('Photos'), findsOneWidget);
      expect(find.text('Friends'), findsOneWidget);
      expect(find.text('No posts yet'), findsOneWidget);
      await tester.tap(find.text('Photos'));
      await tester.pumpAndSettle();
      expect(find.text('No photos yet'), findsOneWidget);
      await tester.tap(find.text('Friends'));
      await tester.pumpAndSettle();
      expect(find.text('No visible friends'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'other-user relationship action renders inside Wrap at large text scale',
    (tester) async {
      await _setPhoneViewport(tester);
      await _pumpProfile(
        tester,
        screen: const ProfileScreen(userId: 'user-2'),
        access: _visibleAccess(RelationshipStatus.none),
        theme: KirenzTheme.dark,
        textScaler: const TextScaler.linear(1.8),
      );

      final action = find.text('Add friend');
      expect(action, findsOneWidget);
      expect(
        find.ancestor(of: action, matching: find.byType(Wrap)),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('restricted Profile renders without layout exceptions', (
    tester,
  ) async {
    await _setPhoneViewport(tester);
    await _pumpProfile(
      tester,
      screen: const ProfileScreen(userId: 'user-2'),
      access: _restrictedAccess,
      theme: KirenzTheme.light,
    );

    expect(find.text('This profile is private'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _setPhoneViewport(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 700);
  addTearDown(tester.view.reset);
}

Future<void> _pumpProfile(
  WidgetTester tester, {
  required ProfileScreen screen,
  required ThemeData theme,
  UserProfile? currentUser,
  ProfileAccess? access,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  final overrides = <Override>[
    profilePostsProvider.overrideWith(
      (ref, userId) async =>
          const CachedProfileResource(data: [], isCached: false),
    ),
    profilePhotosProvider.overrideWith(
      (ref, userId) async =>
          const CachedProfileResource(data: [], isCached: false),
    ),
    friendsProvider.overrideWith((ref, userId) async => const []),
  ];
  if (currentUser != null) {
    overrides.add(
      currentUserProfileProvider.overrideWith(
        () => _CurrentProfileController(currentUser),
      ),
    );
  }
  if (access != null) {
    overrides.add(
      profileAccessProvider.overrideWith((ref, userId) async => access),
    );
  }
  final container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: theme,
        home: MediaQuery(
          data: MediaQueryData(textScaler: textScaler),
          child: screen,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _CurrentProfileController extends CurrentUserProfileController {
  _CurrentProfileController(this.profile);

  final UserProfile profile;

  @override
  Future<UserProfile> build() async => profile;
}

const _profile = UserProfile(
  id: 'user-2',
  email: 'profile@example.com',
  username: 'profile_user',
  displayName: 'Profile User With A Long Display Name',
  avatarUrl: null,
  coverPhotoUrl: null,
  bio: 'A profile used to verify responsive button layout.',
  birthDate: null,
  gender: null,
  location: 'Ho Chi Minh City',
  website: 'https://example.com',
  role: ProfileRole.user,
  emailVerified: true,
  createdAt: null,
  updatedAt: null,
);

ProfileAccess _visibleAccess(RelationshipStatus relationship) => ProfileAccess(
  relationship: relationship,
  privacy: _privacy,
  blockStatus: _unblocked,
  profile: _profile,
);

const _restrictedAccess = ProfileAccess(
  relationship: RelationshipStatus.none,
  privacy: _privatePrivacy,
  blockStatus: _unblocked,
  profile: null,
);

const _privacy = PrivacySettings(
  userId: 'user-2',
  profileVisibility: PrivacyVisibility.public,
  postVisibility: PrivacyVisibility.public,
  allowDirectMessages: true,
  showOnlineStatus: true,
  updatedAt: null,
);

const _privatePrivacy = PrivacySettings(
  userId: 'user-2',
  profileVisibility: PrivacyVisibility.private,
  postVisibility: PrivacyVisibility.private,
  allowDirectMessages: false,
  showOnlineStatus: false,
  updatedAt: null,
);

const _unblocked = BlockStatus(
  viewerId: 'viewer',
  targetUserId: 'user-2',
  blockedByViewer: false,
  blockedViewer: false,
);
