enum RelationshipStatus {
  self,
  friends,
  outgoingRequest,
  incomingRequest,
  blocked,
  blockedByTarget,
  none,
  unsupported,
}

RelationshipStatus relationshipStatusFromJson(Object? value) {
  return switch (value?.toString()) {
    'SELF' => RelationshipStatus.self,
    'FRIENDS' => RelationshipStatus.friends,
    'OUTGOING_REQUEST' => RelationshipStatus.outgoingRequest,
    'INCOMING_REQUEST' => RelationshipStatus.incomingRequest,
    'BLOCKED' => RelationshipStatus.blocked,
    'BLOCKED_BY_TARGET' => RelationshipStatus.blockedByTarget,
    'NONE' => RelationshipStatus.none,
    _ => RelationshipStatus.unsupported,
  };
}

class FriendRequest {
  const FriendRequest({
    required this.id,
    required this.requesterId,
    required this.receiverId,
    required this.status,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.bio,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> json) => FriendRequest(
    id: json['id']?.toString() ?? '',
    requesterId: json['requesterId']?.toString() ?? '',
    receiverId: json['receiverId']?.toString() ?? '',
    status: json['status']?.toString() ?? '',
    username: json['username']?.toString(),
    displayName: json['displayName']?.toString(),
    avatarUrl: json['avatarUrl']?.toString(),
    bio: json['bio']?.toString(),
  );

  final String id;
  final String requesterId;
  final String receiverId;
  final String status;
  final String? username;
  final String? displayName;
  final String? avatarUrl;
  final String? bio;

  String get userId => requesterId;
  String get resolvedName => _resolvedName(displayName, username);
}

class Friend {
  const Friend({
    required this.friendshipId,
    required this.friendId,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.bio,
  });

  factory Friend.fromJson(Map<String, dynamic> json) => Friend(
    friendshipId: json['friendshipId']?.toString() ?? '',
    friendId: json['friendId']?.toString() ?? '',
    username: json['username']?.toString(),
    displayName: json['displayName']?.toString(),
    avatarUrl: json['avatarUrl']?.toString(),
    bio: json['bio']?.toString(),
  );

  final String friendshipId;
  final String friendId;
  final String? username;
  final String? displayName;
  final String? avatarUrl;
  final String? bio;

  String get resolvedName => _resolvedName(displayName, username);
}

class FriendSuggestion {
  const FriendSuggestion({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.bio,
    required this.mutualFriendCount,
  });

  factory FriendSuggestion.fromJson(Map<String, dynamic> json) =>
      FriendSuggestion(
        id: json['id']?.toString() ?? '',
        username: json['username']?.toString(),
        displayName: json['displayName']?.toString(),
        avatarUrl: json['avatarUrl']?.toString(),
        bio: json['bio']?.toString(),
        mutualFriendCount:
            int.tryParse(json['mutualFriendCount']?.toString() ?? '') ?? 0,
      );

  final String id;
  final String? username;
  final String? displayName;
  final String? avatarUrl;
  final String? bio;
  final int mutualFriendCount;

  String get resolvedName => _resolvedName(displayName, username);
}

class UserSearchResult {
  const UserSearchResult({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.bio,
    required this.relationshipStatus,
  });

  factory UserSearchResult.fromJson(Map<String, dynamic> json) =>
      UserSearchResult(
        id: json['id']?.toString() ?? '',
        username: json['username']?.toString() ?? '',
        displayName: json['displayName']?.toString(),
        avatarUrl: json['avatarUrl']?.toString(),
        bio: json['bio']?.toString(),
        relationshipStatus: relationshipStatusFromJson(
          json['relationshipStatus'],
        ),
      );

  final String id;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final String? bio;
  final RelationshipStatus relationshipStatus;

  String get resolvedName => _resolvedName(displayName, username);
}

String _resolvedName(String? displayName, String? username) {
  if (displayName != null && displayName.trim().isNotEmpty) return displayName;
  if (username != null && username.trim().isNotEmpty) return username;
  return 'Kirenz user';
}
