enum PostPrivacy { public, friends, onlyMe }

enum PostStatus { active, inactive, deleted }

enum PostMediaType { image, video, file }

enum ReactionType { like, love, haha, wow, sad, angry }

class PostAuthor {
  const PostAuthor({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
  });

  factory PostAuthor.fromJson(Map<String, dynamic> json) {
    return PostAuthor(
      id: _string(json['id']),
      username: _nullableString(json['username']),
      displayName: _nullableString(json['displayName']),
      avatarUrl: _nullableString(json['avatarUrl']),
    );
  }

  final String id;
  final String? username;
  final String? displayName;
  final String? avatarUrl;

  String get resolvedName => displayName ?? username ?? 'Kirenz User';

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'displayName': displayName,
    'avatarUrl': avatarUrl,
  };
}

class PostMedia {
  const PostMedia({
    required this.type,
    required this.url,
    required this.publicId,
  });

  factory PostMedia.fromJson(Map<String, dynamic> json) {
    return PostMedia(
      type: _mediaType(json['type']),
      url: _string(json['url']),
      publicId: _nullableString(json['publicId']),
    );
  }

  final PostMediaType type;
  final String url;
  final String? publicId;

  Map<String, dynamic> toJson() => {
    'type': type.wireName,
    'url': url,
    'publicId': publicId,
  };
}

class SharedPost {
  const SharedPost({
    required this.id,
    required this.author,
    required this.content,
    required this.privacy,
    required this.media,
    required this.available,
    required this.createdAt,
  });

  factory SharedPost.fromJson(Map<String, dynamic> json) {
    return SharedPost(
      id: _string(json['id']),
      author: json['author'] is Map
          ? PostAuthor.fromJson(_map(json['author']))
          : null,
      content: _nullableString(json['content']),
      privacy: _privacy(json['privacy']),
      media: _list(json['media'])
          .map((item) => PostMedia.fromJson(_map(item)))
          .where((item) => item.url.isNotEmpty)
          .toList(growable: false),
      available: json['available'] == true,
      createdAt: _dateTime(json['createdAt']),
    );
  }

  final String id;
  final PostAuthor? author;
  final String? content;
  final PostPrivacy? privacy;
  final List<PostMedia> media;
  final bool available;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'author': author?.toJson(),
    'content': content,
    'privacy': privacy?.wireName,
    'media': media.map((item) => item.toJson()).toList(growable: false),
    'available': available,
    'createdAt': createdAt?.toUtc().toIso8601String(),
  };
}

class PostReactionSummary {
  const PostReactionSummary({
    required this.totalCount,
    required this.currentUserReaction,
    required this.breakdown,
  });

  factory PostReactionSummary.fromJson(Map<String, dynamic> json) {
    final breakdown = <ReactionType, int>{};
    for (final entry in _map(json['breakdown']).entries) {
      final type = _reactionType(entry.key);
      final count = entry.value;
      if (type != null && count is num) breakdown[type] = count.toInt();
    }
    return PostReactionSummary(
      totalCount: _integer(json['totalCount']),
      currentUserReaction: _reactionType(json['currentUserReaction']),
      breakdown: Map.unmodifiable(breakdown),
    );
  }

  final int totalCount;
  final ReactionType? currentUserReaction;
  final Map<ReactionType, int> breakdown;

  Map<String, dynamic> toJson() => {
    'totalCount': totalCount,
    'currentUserReaction': currentUserReaction?.wireName,
    'breakdown': {
      for (final entry in breakdown.entries) entry.key.wireName: entry.value,
    },
  };
}

class Post {
  const Post({
    required this.id,
    required this.slug,
    required this.author,
    required this.content,
    required this.privacy,
    required this.originalPostId,
    required this.sharedPost,
    required this.media,
    required this.taggedUserIds,
    required this.taggedUsers,
    required this.reactionsCount,
    required this.reactionSummary,
    required this.commentsCount,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: _string(json['id']),
      slug: _string(json['slug']),
      author: PostAuthor.fromJson(_map(json['author'])),
      content: _string(json['content']),
      privacy: _privacy(json['privacy']) ?? PostPrivacy.public,
      originalPostId: _nullableString(json['originalPostId']),
      sharedPost: json['sharedPost'] is Map
          ? SharedPost.fromJson(_map(json['sharedPost']))
          : null,
      media: _list(json['media'])
          .map((item) => PostMedia.fromJson(_map(item)))
          .where((item) => item.url.isNotEmpty)
          .toList(growable: false),
      taggedUserIds: _list(
        json['taggedUserIds'],
      ).map(_string).where((id) => id.isNotEmpty).toList(growable: false),
      taggedUsers: _list(json['taggedUsers'])
          .map((item) => PostAuthor.fromJson(_map(item)))
          .where((author) => author.id.isNotEmpty)
          .toList(growable: false),
      reactionsCount: _integer(json['reactionsCount']),
      reactionSummary: json['reactionSummary'] is Map
          ? PostReactionSummary.fromJson(_map(json['reactionSummary']))
          : const PostReactionSummary(
              totalCount: 0,
              currentUserReaction: null,
              breakdown: {},
            ),
      commentsCount: _integer(json['commentsCount']),
      status: _status(json['status']),
      createdAt: _dateTime(json['createdAt']),
      updatedAt: _dateTime(json['updatedAt']),
    );
  }

  final String id;
  final String slug;
  final PostAuthor author;
  final String content;
  final PostPrivacy privacy;
  final String? originalPostId;
  final SharedPost? sharedPost;
  final List<PostMedia> media;
  final List<String> taggedUserIds;
  final List<PostAuthor> taggedUsers;
  final int reactionsCount;
  final PostReactionSummary reactionSummary;
  final int commentsCount;
  final PostStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Post copyWith({
    int? reactionsCount,
    PostReactionSummary? reactionSummary,
    int? commentsCount,
  }) => Post(
    id: id,
    slug: slug,
    author: author,
    content: content,
    privacy: privacy,
    originalPostId: originalPostId,
    sharedPost: sharedPost,
    media: media,
    taggedUserIds: taggedUserIds,
    taggedUsers: taggedUsers,
    reactionsCount: reactionsCount ?? this.reactionsCount,
    reactionSummary: reactionSummary ?? this.reactionSummary,
    commentsCount: commentsCount ?? this.commentsCount,
    status: status,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'slug': slug,
    'author': author.toJson(),
    'content': content,
    'privacy': privacy.wireName,
    'originalPostId': originalPostId,
    'sharedPost': sharedPost?.toJson(),
    'media': media.map((item) => item.toJson()).toList(growable: false),
    'taggedUserIds': taggedUserIds,
    'taggedUsers': taggedUsers
        .map((item) => item.toJson())
        .toList(growable: false),
    'reactionsCount': reactionsCount,
    'reactionSummary': reactionSummary.toJson(),
    'commentsCount': commentsCount,
    'status': status.wireName,
    'createdAt': createdAt?.toUtc().toIso8601String(),
    'updatedAt': updatedAt?.toUtc().toIso8601String(),
  };
}

extension PostPrivacyWire on PostPrivacy {
  String get wireName => switch (this) {
    PostPrivacy.public => 'PUBLIC',
    PostPrivacy.friends => 'FRIENDS',
    PostPrivacy.onlyMe => 'ONLY_ME',
  };
}

extension PostStatusWire on PostStatus {
  String get wireName => switch (this) {
    PostStatus.active => 'ACTIVE',
    PostStatus.inactive => 'INACTIVE',
    PostStatus.deleted => 'DELETED',
  };
}

extension PostMediaTypeWire on PostMediaType {
  String get wireName => switch (this) {
    PostMediaType.image => 'IMAGE',
    PostMediaType.video => 'VIDEO',
    PostMediaType.file => 'FILE',
  };
}

extension ReactionTypeWire on ReactionType {
  String get wireName => name.toUpperCase();
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

List<Object?> _list(Object? value) {
  return value is List ? List<Object?>.from(value) : const [];
}

String _string(Object? value) => value?.toString() ?? '';

String? _nullableString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

int _integer(Object? value) => value is num ? value.toInt() : 0;

DateTime? _dateTime(Object? value) {
  return DateTime.tryParse(value?.toString() ?? '');
}

PostPrivacy? _privacy(Object? value) {
  return switch (value?.toString()) {
    'PUBLIC' => PostPrivacy.public,
    'FRIENDS' => PostPrivacy.friends,
    'ONLY_ME' => PostPrivacy.onlyMe,
    _ => null,
  };
}

PostStatus _status(Object? value) {
  return switch (value?.toString()) {
    'INACTIVE' => PostStatus.inactive,
    'DELETED' => PostStatus.deleted,
    _ => PostStatus.active,
  };
}

PostMediaType _mediaType(Object? value) {
  return switch (value?.toString()) {
    'VIDEO' => PostMediaType.video,
    'FILE' => PostMediaType.file,
    _ => PostMediaType.image,
  };
}

ReactionType? _reactionType(Object? value) {
  return switch (value?.toString()) {
    'LIKE' => ReactionType.like,
    'LOVE' => ReactionType.love,
    'HAHA' => ReactionType.haha,
    'WOW' => ReactionType.wow,
    'SAD' => ReactionType.sad,
    'ANGRY' => ReactionType.angry,
    _ => null,
  };
}
