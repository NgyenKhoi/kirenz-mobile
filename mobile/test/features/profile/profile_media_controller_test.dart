import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kirenz_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:kirenz_mobile/features/auth/domain/entities/app_user.dart';
import 'package:kirenz_mobile/features/auth/presentation/controllers/session_controller.dart';
import 'package:kirenz_mobile/features/profile/data/repositories/profile_repository.dart';
import 'package:kirenz_mobile/features/profile/domain/entities/user_profile.dart';
import 'package:kirenz_mobile/features/profile/presentation/controllers/profile_media_controller.dart';

void main() {
  test(
    'avatar selection uploads immediately and replaces canonical profile',
    () async {
      final repository = _ProfileRepository();
      final container = _container(repository);
      await container.read(sessionControllerProvider.notifier).restoreSession();
      await container.read(currentUserProfileProvider.future);

      await container
          .read(
            profileMediaControllerProvider(ProfileMediaTarget.avatar).notifier,
          )
          .select(ImageSource.gallery);

      expect(repository.avatarUploads, 1);
      expect(
        container.read(currentUserProfileProvider).requireValue.avatarUrl,
        'https://example.com/new-avatar.jpg',
      );
      expect(
        container
            .read(profileMediaControllerProvider(ProfileMediaTarget.avatar))
            .status,
        ProfileMediaStatus.idle,
      );
    },
  );

  test('cover selection waits for explicit save', () async {
    final repository = _ProfileRepository();
    final container = _container(repository);

    await container
        .read(profileMediaControllerProvider(ProfileMediaTarget.cover).notifier)
        .select(ImageSource.camera);

    final state = container.read(
      profileMediaControllerProvider(ProfileMediaTarget.cover),
    );
    expect(state.status, ProfileMediaStatus.ready);
    expect(state.localPath, 'cropped.jpg');
    expect(repository.coverUploads, 0);
  });

  test('failed upload keeps crop available for retry or cancel', () async {
    final repository = _ProfileRepository(failAvatar: true);
    final container = _container(repository);
    await container.read(sessionControllerProvider.notifier).restoreSession();
    await container.read(currentUserProfileProvider.future);

    await container
        .read(
          profileMediaControllerProvider(ProfileMediaTarget.avatar).notifier,
        )
        .select(ImageSource.gallery);

    final state = container.read(
      profileMediaControllerProvider(ProfileMediaTarget.avatar),
    );
    expect(state.status, ProfileMediaStatus.failure);
    expect(state.localPath, 'cropped.jpg');
    expect(state.canUpload, isTrue);
  });
}

ProviderContainer _container(_ProfileRepository repository) {
  return ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(_AuthRepository()),
      profileRepositoryProvider.overrideWithValue(repository),
      profileImageServiceProvider.overrideWithValue(_ImageService()),
    ],
  );
}

class _ImageService extends ProfileImageService {
  _ImageService() : super(ImagePicker(), ImageCropper());

  @override
  Future<String?> pickAndCrop(
    ImageSource source,
    ProfileMediaTarget target,
  ) async {
    return 'cropped.jpg';
  }
}

class _ProfileRepository extends ProfileRepository {
  _ProfileRepository({this.failAvatar = false}) : super(Dio());

  final bool failAvatar;
  int avatarUploads = 0;
  int coverUploads = 0;

  @override
  Future<UserProfile> getCurrentUser() async => _profile();

  @override
  Future<UserProfile> uploadAvatar(
    String filePath, {
    ProgressCallback? onSendProgress,
  }) async {
    avatarUploads += 1;
    onSendProgress?.call(10, 10);
    if (failAvatar) throw Exception('Upload failed');
    return _profile(avatarUrl: 'https://example.com/new-avatar.jpg');
  }

  @override
  Future<UserProfile> uploadCover(
    String filePath, {
    ProgressCallback? onSendProgress,
  }) async {
    coverUploads += 1;
    return _profile(coverUrl: 'https://example.com/new-cover.jpg');
  }
}

class _AuthRepository implements AuthRepository {
  @override
  Future<AppUser?> restoreSession() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

UserProfile _profile({String? avatarUrl, String? coverUrl}) {
  return UserProfile(
    id: 'user-1',
    email: 'person@example.com',
    username: 'person',
    displayName: 'Person',
    avatarUrl: avatarUrl,
    coverPhotoUrl: coverUrl,
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
