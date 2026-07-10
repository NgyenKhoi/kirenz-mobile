import '../../domain/entities/app_user.dart';

class AuthResultDto {
  const AuthResultDto({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  factory AuthResultDto.fromJson(Object? value) {
    final json = value is Map<String, dynamic> ? value : <String, dynamic>{};
    final userJson = _findUserJson(json);
    final fallbackUserId = _readString(json, ['userId', 'id', 'uuid']);
    final fallbackEmail = _readString(json, ['email']);

    return AuthResultDto(
      accessToken: _readString(json, ['accessToken', 'access_token', 'token']),
      refreshToken: _readString(json, ['refreshToken', 'refresh_token']),
      user: AppUser.fromJson({
        ...userJson,
        if (!userJson.containsKey('id') && fallbackUserId.isNotEmpty)
          'id': fallbackUserId,
        if (!userJson.containsKey('email') && fallbackEmail.isNotEmpty)
          'email': fallbackEmail,
      }),
    );
  }

  final String accessToken;
  final String refreshToken;
  final AppUser user;

  bool get hasTokens => accessToken.isNotEmpty && refreshToken.isNotEmpty;
}

Map<String, dynamic> _findUserJson(Map<String, dynamic> json) {
  for (final key in ['user', 'profile', 'account']) {
    final value = json[key];
    if (value is Map<String, dynamic>) {
      return value;
    }
  }

  return json;
}

String _readString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value != null && value.toString().isNotEmpty) {
      return value.toString();
    }
  }

  return '';
}
