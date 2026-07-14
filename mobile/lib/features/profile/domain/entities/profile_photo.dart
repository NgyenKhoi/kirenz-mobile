class ProfilePhoto {
  const ProfilePhoto({
    required this.postId,
    required this.url,
    required this.publicId,
    required this.createdAt,
  });

  factory ProfilePhoto.fromJson(Map<String, dynamic> json) {
    return ProfilePhoto(
      postId: json['postId']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      publicId: _nullableString(json['publicId']),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
  }

  final String postId;
  final String url;
  final String? publicId;
  final DateTime? createdAt;
}

String? _nullableString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
