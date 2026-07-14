class AppUser {
  const AppUser({
    required this.id,
    required this.displayName,
    required this.email,
    this.username = '',
    this.avatarUrl,
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
    );
  }

  final String id;
  final String displayName;
  final String email;
  final String username;
  final String? avatarUrl;

  AppUser copyWith({
    String? displayName,
    String? email,
    String? username,
    String? avatarUrl,
  }) {
    return AppUser(
      id: id,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
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
