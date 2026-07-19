import '../../../posts/domain/entities/post.dart';

class CommentAuthor {
  const CommentAuthor({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
  });

  factory CommentAuthor.fromJson(Map<String, dynamic> json) => CommentAuthor(
    id: json['id']?.toString() ?? '',
    username: json['username']?.toString(),
    displayName: json['displayName']?.toString(),
    avatarUrl: json['avatarUrl']?.toString(),
  );

  final String id;
  final String? username;
  final String? displayName;
  final String? avatarUrl;

  String get resolvedName => displayName?.trim().isNotEmpty == true
      ? displayName!
      : username?.trim().isNotEmpty == true
      ? username!
      : 'Kirenz User';

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'displayName': displayName,
    'avatarUrl': avatarUrl,
  };
}

class PostComment {
  const PostComment({
    required this.id,
    required this.postId,
    required this.parentCommentId,
    required this.author,
    required this.content,
    required this.taggedUserIds,
    required this.reactionsCount,
    required this.reactionSummary,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PostComment.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString().trim() ?? '';
    final postId = json['postId']?.toString().trim() ?? '';
    if (id.isEmpty || postId.isEmpty || json['author'] is! Map) {
      throw const FormatException('Comment response has an invalid shape.');
    }
    final summary = json['reactionSummary'];
    return PostComment(
      id: id,
      postId: postId,
      parentCommentId: json['parentCommentId']?.toString(),
      author: CommentAuthor.fromJson(
        Map<String, dynamic>.from(json['author'] as Map),
      ),
      content: json['content']?.toString() ?? '',
      taggedUserIds: json['taggedUserIds'] is List
          ? (json['taggedUserIds'] as List)
                .map((item) => item.toString())
                .toList(growable: false)
          : const [],
      reactionsCount: _integer(json['reactionsCount']),
      reactionSummary: summary is Map
          ? PostReactionSummary.fromJson(Map<String, dynamic>.from(summary))
          : const PostReactionSummary(
              totalCount: 0,
              currentUserReaction: null,
              breakdown: {},
            ),
      status: json['status']?.toString() ?? 'ACTIVE',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
    );
  }

  final String id;
  final String postId;
  final String? parentCommentId;
  final CommentAuthor author;
  final String content;
  final List<String> taggedUserIds;
  final int reactionsCount;
  final PostReactionSummary reactionSummary;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  PostComment copyWith({
    PostReactionSummary? reactionSummary,
    int? reactionsCount,
  }) => PostComment(
    id: id,
    postId: postId,
    parentCommentId: parentCommentId,
    author: author,
    content: content,
    taggedUserIds: taggedUserIds,
    reactionsCount: reactionsCount ?? this.reactionsCount,
    reactionSummary: reactionSummary ?? this.reactionSummary,
    status: status,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'postId': postId,
    'parentCommentId': parentCommentId,
    'author': author.toJson(),
    'content': content,
    'taggedUserIds': taggedUserIds,
    'reactionsCount': reactionsCount,
    'reactionSummary': reactionSummary.toJson(),
    'status': status,
    'createdAt': createdAt?.toUtc().toIso8601String(),
    'updatedAt': updatedAt?.toUtc().toIso8601String(),
  };
}

class ReactionUser {
  const ReactionUser({
    required this.userId,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.type,
    required this.reactedAt,
  });

  factory ReactionUser.fromJson(Map<String, dynamic> json) => ReactionUser(
    userId: json['userId']?.toString() ?? '',
    username: json['username']?.toString(),
    displayName: json['displayName']?.toString(),
    avatarUrl: json['avatarUrl']?.toString(),
    type: reactionTypeFromWire(json['type']),
    reactedAt: DateTime.tryParse(json['reactedAt']?.toString() ?? ''),
  );

  final String userId;
  final String? username;
  final String? displayName;
  final String? avatarUrl;
  final ReactionType? type;
  final DateTime? reactedAt;

  String get resolvedName => displayName?.trim().isNotEmpty == true
      ? displayName!
      : username?.trim().isNotEmpty == true
      ? username!
      : 'Kirenz User';
}

ReactionType? reactionTypeFromWire(Object? value) =>
    switch (value?.toString()) {
      'LIKE' => ReactionType.like,
      'LOVE' => ReactionType.love,
      'HAHA' => ReactionType.haha,
      'WOW' => ReactionType.wow,
      'SAD' => ReactionType.sad,
      'ANGRY' => ReactionType.angry,
      _ => null,
    };

int _integer(Object? value) => value is num ? value.toInt() : 0;
