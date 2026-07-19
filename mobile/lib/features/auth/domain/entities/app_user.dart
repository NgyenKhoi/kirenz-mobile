class AppUser {
  const AppUser({
    required this.id,
    required this.displayName,
    required this.email,
    this.username = '',
    this.avatarUrl,
    this.role = 'USER',
    this.emailVerified = true,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final id = _stringValue(json, ['id', 'userId', 'uuid']);
    final displayName = _stringValue(json, [
      'displayName',
      'fullName',
      'name',
      'username',
      'email',
    ]);
    final email = _stringValue(json, ['email']);

    return AppUser(
      id: id.isEmpty ? 'unknown-user' : id,
      displayName: displayName.isEmpty ? email : displayName,
      email: email,
      username: _stringValue(json, ['username']),
      avatarUrl: _nullableStringValue(json, ['avatarUrl']),
      role: _stringValue(json, ['role']).isEmpty
          ? 'USER'
          : _stringValue(json, ['role']).toUpperCase(),
      emailVerified: json['emailVerified'] != false,
    );
  }

  final String id;
  final String displayName;
  final String email;
  final String username;
  final String? avatarUrl;
  final String role;
  final bool emailVerified;

  AppUser copyWith({
    String? displayName,
    String? email,
    String? username,
    String? avatarUrl,
    String? role,
    bool? emailVerified,
  }) {
    return AppUser(
      id: id,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      emailVerified: emailVerified ?? this.emailVerified,
    );
  }
}

String? _nullableStringValue(Map<String, dynamic> json, List<String> keys) {
  final value = _stringValue(json, keys);
  return value.isEmpty ? null : value;
}

String _stringValue(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value != null && value.toString().isNotEmpty) {
      return value.toString();
    }
  }

  return '';
}
