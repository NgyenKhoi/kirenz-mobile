enum PrivacyVisibility { public, friendsOnly, private }

PrivacyVisibility privacyVisibilityFromJson(Object? value) {
  return switch (value?.toString()) {
    'PUBLIC' => PrivacyVisibility.public,
    'FRIENDS_ONLY' => PrivacyVisibility.friendsOnly,
    'PRIVATE' => PrivacyVisibility.private,
    _ => throw FormatException('Unsupported privacy visibility: $value'),
  };
}

String privacyVisibilityToJson(PrivacyVisibility value) {
  return switch (value) {
    PrivacyVisibility.public => 'PUBLIC',
    PrivacyVisibility.friendsOnly => 'FRIENDS_ONLY',
    PrivacyVisibility.private => 'PRIVATE',
  };
}

class PrivacySettings {
  const PrivacySettings({
    required this.userId,
    required this.profileVisibility,
    required this.postVisibility,
    required this.allowDirectMessages,
    required this.showOnlineStatus,
    required this.updatedAt,
  });

  factory PrivacySettings.fromJson(Map<String, dynamic> json) =>
      PrivacySettings(
        userId: json['userId']?.toString() ?? '',
        profileVisibility: privacyVisibilityFromJson(json['profileVisibility']),
        postVisibility: privacyVisibilityFromJson(json['postVisibility']),
        allowDirectMessages: json['allowDirectMessages'] == true,
        showOnlineStatus: json['showOnlineStatus'] == true,
        updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
      );

  final String userId;
  final PrivacyVisibility profileVisibility;
  final PrivacyVisibility postVisibility;
  final bool allowDirectMessages;
  final bool showOnlineStatus;
  final DateTime? updatedAt;

  Map<String, dynamic> toUpdateJson() => {
    'profileVisibility': privacyVisibilityToJson(profileVisibility),
    'postVisibility': privacyVisibilityToJson(postVisibility),
    'allowDirectMessages': allowDirectMessages,
    'showOnlineStatus': showOnlineStatus,
  };
}
