import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/api_exception.dart';
import '../../data/repositories/post_repository.dart';
import '../../domain/entities/post.dart';
import '../../domain/entities/post_draft.dart';

final postComposerControllerProvider =
    StateNotifierProvider<PostComposerController, PostComposerState>(
      (ref) => PostComposerController(ref.watch(postRepositoryProvider)),
    );

class PostComposerState {
  const PostComposerState({
    this.content = '',
    this.privacy = PostPrivacy.public,
    this.images = const [],
    this.taggedUserIds = const {},
    this.submitting = false,
    this.error,
  });

  final String content;
  final PostPrivacy privacy;
  final List<PostDraftImage> images;
  final Set<String> taggedUserIds;
  final bool submitting;
  final String? error;

  bool get canSubmit =>
      !submitting &&
      (content.trim().isNotEmpty || images.isNotEmpty) &&
      images.every((image) => image.status != PostImageStatus.uploading);

  PostComposerState copyWith({
    String? content,
    PostPrivacy? privacy,
    List<PostDraftImage>? images,
    Set<String>? taggedUserIds,
    bool? submitting,
    String? error,
    bool clearError = false,
  }) => PostComposerState(
    content: content ?? this.content,
    privacy: privacy ?? this.privacy,
    images: images ?? this.images,
    taggedUserIds: taggedUserIds ?? this.taggedUserIds,
    submitting: submitting ?? this.submitting,
    error: clearError ? null : error ?? this.error,
  );
}

class PostComposerController extends StateNotifier<PostComposerState> {
  PostComposerController(this._repository) : super(const PostComposerState());

  final PostRepository _repository;

  void updateContent(String value) =>
      state = state.copyWith(content: value, clearError: true);

  void updatePrivacy(PostPrivacy value) =>
      state = state.copyWith(privacy: value, clearError: true);

  void toggleTaggedUser(String userId) {
    final next = {...state.taggedUserIds};
    next.contains(userId) ? next.remove(userId) : next.add(userId);
    state = state.copyWith(taggedUserIds: next, clearError: true);
  }

  void addImages(Iterable<PostDraftImage> selected) {
    final next = [...state.images];
    final errors = <String>[];
    for (final image in selected) {
      if (next.any((item) => item.path == image.path)) continue;
      if (next.length >= 10) {
        errors.add('You can add up to 10 images.');
        break;
      }
      if (image.bytes <= 0 || image.bytes > 10 * 1024 * 1024) {
        errors.add('${image.name} exceeds the 10 MB image limit.');
        continue;
      }
      if (!image.contentType.startsWith('image/')) {
        errors.add('${image.name} is not a supported image.');
        continue;
      }
      next.add(image);
    }
    state = state.copyWith(
      images: next,
      error: errors.isEmpty ? null : errors.join('\n'),
      clearError: errors.isEmpty,
    );
  }

  void removeImage(String path) {
    state = state.copyWith(
      images: state.images.where((image) => image.path != path).toList(),
      clearError: true,
    );
  }

  Future<Post?> submit() async {
    if (!state.canSubmit) return null;
    state = state.copyWith(submitting: true, clearError: true);
    try {
      for (final image in [...state.images]) {
        if (image.status == PostImageStatus.uploaded) continue;
        await _upload(image.path);
      }
      if (state.images.any(
        (image) => image.status != PostImageStatus.uploaded,
      )) {
        state = state.copyWith(
          submitting: false,
          error: 'Retry or remove failed images before posting.',
        );
        return null;
      }
      final post = await _repository.create(
        content: state.content,
        privacy: state.privacy,
        media: state.images.map((image) => image.uploaded!).toList(),
        taggedUserIds: state.taggedUserIds.toList(growable: false),
      );
      state = const PostComposerState();
      return post;
    } on Object catch (error) {
      state = state.copyWith(submitting: false, error: _message(error));
      return null;
    }
  }

  Future<void> retryImage(String path) => _upload(path);

  Future<void> _upload(String path) async {
    final image = state.images.where((item) => item.path == path).firstOrNull;
    if (image == null || image.status == PostImageStatus.uploading) return;
    _replace(
      path,
      image.copyWith(
        status: PostImageStatus.uploading,
        progress: 0,
        clearError: true,
      ),
    );
    try {
      final uploaded = await _repository.uploadImage(
        image,
        onProgress: (sent, total) {
          if (total <= 0) return;
          final current = state.images
              .where((item) => item.path == path)
              .firstOrNull;
          if (current?.status == PostImageStatus.uploading) {
            _replace(path, current!.copyWith(progress: sent / total));
          }
        },
      );
      final current = state.images
          .where((item) => item.path == path)
          .firstOrNull;
      if (current != null) {
        _replace(
          path,
          current.copyWith(
            status: PostImageStatus.uploaded,
            progress: 1,
            uploaded: uploaded,
            clearError: true,
          ),
        );
      }
    } on Object catch (error) {
      final current = state.images
          .where((item) => item.path == path)
          .firstOrNull;
      if (current != null) {
        _replace(
          path,
          current.copyWith(
            status: PostImageStatus.failed,
            error: _message(error),
          ),
        );
      }
    }
  }

  void _replace(String path, PostDraftImage replacement) {
    state = state.copyWith(
      images: state.images
          .map((image) => image.path == path ? replacement : image)
          .toList(growable: false),
    );
  }

  String _message(Object error) =>
      error is ApiException ? error.message : error.toString();
}
