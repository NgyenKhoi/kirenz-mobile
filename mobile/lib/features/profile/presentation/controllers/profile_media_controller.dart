import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/repositories/profile_repository.dart';

enum ProfileMediaTarget { avatar, cover }

enum ProfileMediaStatus { idle, selecting, ready, uploading, failure }

class ProfileMediaState {
  const ProfileMediaState({
    this.status = ProfileMediaStatus.idle,
    this.localPath,
    this.progress = 0,
    this.errorMessage,
  });

  final ProfileMediaStatus status;
  final String? localPath;
  final double progress;
  final String? errorMessage;

  bool get isBusy =>
      status == ProfileMediaStatus.selecting ||
      status == ProfileMediaStatus.uploading;
  bool get canUpload =>
      localPath != null &&
      (status == ProfileMediaStatus.ready ||
          status == ProfileMediaStatus.failure);
}

final profileImageServiceProvider = Provider<ProfileImageService>((ref) {
  return ProfileImageService(ImagePicker(), ImageCropper());
});

final profileMediaControllerProvider = StateNotifierProvider.autoDispose
    .family<ProfileMediaController, ProfileMediaState, ProfileMediaTarget>((
      ref,
      target,
    ) {
      return ProfileMediaController(
        ref,
        target,
        ref.watch(profileImageServiceProvider),
      );
    });

class ProfileMediaController extends StateNotifier<ProfileMediaState> {
  ProfileMediaController(this._ref, this._target, this._imageService)
    : super(const ProfileMediaState());

  final Ref _ref;
  final ProfileMediaTarget _target;
  final ProfileImageService _imageService;

  Future<void> select(ImageSource source) async {
    if (state.isBusy) return;
    state = const ProfileMediaState(status: ProfileMediaStatus.selecting);
    try {
      final path = await _imageService.pickAndCrop(source, _target);
      if (path == null) {
        state = const ProfileMediaState();
        return;
      }
      state = ProfileMediaState(
        status: ProfileMediaStatus.ready,
        localPath: path,
      );
      if (_target == ProfileMediaTarget.avatar) {
        await upload();
      }
    } on PlatformException catch (error) {
      state = ProfileMediaState(
        status: ProfileMediaStatus.failure,
        errorMessage: _platformMessage(error),
      );
    } on ProfileImageException catch (error) {
      state = ProfileMediaState(
        status: ProfileMediaStatus.failure,
        errorMessage: error.message,
      );
    } catch (error) {
      state = ProfileMediaState(
        status: ProfileMediaStatus.failure,
        errorMessage: error.toString(),
      );
    }
  }

  Future<bool> upload() async {
    final path = state.localPath;
    if (path == null || state.isBusy) return false;
    state = ProfileMediaState(
      status: ProfileMediaStatus.uploading,
      localPath: path,
    );
    try {
      final repository = _ref.read(profileRepositoryProvider);
      final updated = _target == ProfileMediaTarget.avatar
          ? await repository.uploadAvatar(path, onSendProgress: _updateProgress)
          : await repository.uploadCover(path, onSendProgress: _updateProgress);
      final current = _ref.read(currentUserProfileProvider).asData?.value;
      final previousUrl = _target == ProfileMediaTarget.avatar
          ? current?.avatarUrl
          : current?.coverPhotoUrl;
      final nextUrl = _target == ProfileMediaTarget.avatar
          ? updated.avatarUrl
          : updated.coverPhotoUrl;
      if (previousUrl != null && previousUrl == nextUrl) {
        await CachedNetworkImage.evictFromCache(previousUrl);
      }
      _ref.read(currentUserProfileProvider.notifier).replace(updated);
      state = const ProfileMediaState();
      return true;
    } catch (error) {
      state = ProfileMediaState(
        status: ProfileMediaStatus.failure,
        localPath: path,
        progress: state.progress,
        errorMessage: error.toString(),
      );
      return false;
    }
  }

  void cancel() {
    if (!state.isBusy) state = const ProfileMediaState();
  }

  void _updateProgress(int sent, int total) {
    if (!mounted || state.status != ProfileMediaStatus.uploading) return;
    state = ProfileMediaState(
      status: ProfileMediaStatus.uploading,
      localPath: state.localPath,
      progress: total <= 0 ? 0 : sent / total,
    );
  }
}

class ProfileImageService {
  const ProfileImageService(this._picker, this._cropper);

  static const maxBytes = 10 * 1024 * 1024;

  final ImagePicker _picker;
  final ImageCropper _cropper;

  Future<String?> pickAndCrop(
    ImageSource source,
    ProfileMediaTarget target,
  ) async {
    final picked = await _picker.pickImage(
      source: source,
      requestFullMetadata: true,
    );
    if (picked == null) return null;
    await _validate(picked);
    final isAvatar = target == ProfileMediaTarget.avatar;
    final cropped = await _cropper.cropImage(
      sourcePath: picked.path,
      maxWidth: isAvatar ? 1024 : 1920,
      maxHeight: isAvatar ? 1024 : 1080,
      aspectRatio: CropAspectRatio(
        ratioX: isAvatar ? 1 : 16,
        ratioY: isAvatar ? 1 : 9,
      ),
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 90,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: isAvatar ? 'Crop profile photo' : 'Crop cover photo',
          lockAspectRatio: true,
          hideBottomControls: true,
          cropStyle: isAvatar ? CropStyle.circle : CropStyle.rectangle,
        ),
        IOSUiSettings(
          title: isAvatar ? 'Crop profile photo' : 'Crop cover photo',
          doneButtonTitle: 'Use photo',
          cancelButtonTitle: 'Cancel',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          cropStyle: isAvatar ? CropStyle.circle : CropStyle.rectangle,
        ),
      ],
    );
    if (cropped == null) return null;
    final output = XFile(cropped.path);
    if (await output.length() > maxBytes) {
      throw const ProfileImageException(
        'The cropped image is larger than 10 MB. Choose a smaller image.',
      );
    }
    return cropped.path;
  }

  Future<void> _validate(XFile file) async {
    final mime = file.mimeType?.toLowerCase();
    final extension = file.name.toLowerCase().split('.').last;
    const extensions = {'jpg', 'jpeg', 'png', 'webp', 'heic', 'heif'};
    if ((mime != null && !mime.startsWith('image/')) ||
        (mime == null && !extensions.contains(extension))) {
      throw const ProfileImageException('Choose a valid image file.');
    }
    if (await file.length() > maxBytes) {
      throw const ProfileImageException(
        'The image is larger than the 10 MB limit.',
      );
    }
  }
}

class ProfileImageException implements Exception {
  const ProfileImageException(this.message);

  final String message;
}

String _platformMessage(PlatformException error) {
  final code = error.code.toLowerCase();
  if (code.contains('permission') || code.contains('denied')) {
    return 'Photo access was denied. Allow access in system settings and try again.';
  }
  if (code.contains('camera')) {
    return 'The camera is unavailable on this device.';
  }
  return error.message ?? 'Could not open the selected image.';
}
