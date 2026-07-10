class AppUser {
  const AppUser({
    required this.id,
    required this.displayName,
    required this.email,
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
    );
  }

  final String id;
  final String displayName;
  final String email;
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
