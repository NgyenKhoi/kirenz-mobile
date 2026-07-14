enum ProfileGender { male, female, other, preferNotToSay }

enum ProfileRole { user, moderator, admin }

class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.coverPhotoUrl,
    required this.bio,
    required this.birthDate,
    required this.gender,
    required this.location,
    required this.website,
    required this.role,
    required this.emailVerified,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: _string(json['id']),
      email: _string(json['email']),
      username: _string(json['username']),
      displayName: _string(json['displayName']),
      avatarUrl: _nullableString(json['avatarUrl']),
      coverPhotoUrl: _nullableString(json['coverPhotoUrl']),
      bio: _nullableString(json['bio']),
      birthDate: _date(json['birthDate']),
      gender: _gender(json['gender']),
      location: _nullableString(json['location']),
      website: _nullableString(json['website']),
      role: _role(json['role']),
      emailVerified: json['emailVerified'] == true,
      createdAt: _dateTime(json['createdAt']),
      updatedAt: _dateTime(json['updatedAt']),
    );
  }

  final String id;
  final String email;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String? coverPhotoUrl;
  final String? bio;
  final DateTime? birthDate;
  final ProfileGender? gender;
  final String? location;
  final String? website;
  final ProfileRole role;
  final bool emailVerified;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

String _string(Object? value) => value?.toString() ?? '';

String? _nullableString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

DateTime? _date(Object? value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  return parsed == null
      ? null
      : DateTime(parsed.year, parsed.month, parsed.day);
}

DateTime? _dateTime(Object? value) {
  return DateTime.tryParse(value?.toString() ?? '');
}

ProfileGender? _gender(Object? value) {
  return switch (value?.toString()) {
    'MALE' => ProfileGender.male,
    'FEMALE' => ProfileGender.female,
    'OTHER' => ProfileGender.other,
    'PREFER_NOT_TO_SAY' => ProfileGender.preferNotToSay,
    _ => null,
  };
}

ProfileRole _role(Object? value) {
  return switch (value?.toString()) {
    'MODERATOR' => ProfileRole.moderator,
    'ADMIN' => ProfileRole.admin,
    _ => ProfileRole.user,
  };
}
