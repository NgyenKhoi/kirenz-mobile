import 'post.dart';

enum PostImageStatus { local, uploading, uploaded, failed }

class PostDraftImage {
  const PostDraftImage({
    required this.path,
    required this.name,
    required this.bytes,
    required this.contentType,
    this.status = PostImageStatus.local,
    this.progress = 0,
    this.uploaded,
    this.error,
  });

  final String path;
  final String name;
  final int bytes;
  final String contentType;
  final PostImageStatus status;
  final double progress;
  final PostMedia? uploaded;
  final String? error;

  PostDraftImage copyWith({
    PostImageStatus? status,
    double? progress,
    PostMedia? uploaded,
    String? error,
    bool clearError = false,
  }) => PostDraftImage(
    path: path,
    name: name,
    bytes: bytes,
    contentType: contentType,
    status: status ?? this.status,
    progress: progress ?? this.progress,
    uploaded: uploaded ?? this.uploaded,
    error: clearError ? null : error ?? this.error,
  );
}
