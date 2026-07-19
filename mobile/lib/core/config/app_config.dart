class AppConfig {
  const AppConfig._();

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080/api',
  );

  static const chatWebSocketPath = '/ws/chat';
  static const notificationWebSocketPath = '/ws/notifications';

  static String get chatRealtimeUrl => _gatewayUrl(chatWebSocketPath);

  static String get notificationRealtimeUrl =>
      _gatewayUrl(notificationWebSocketPath);

  static const googleClientId = String.fromEnvironment('GOOGLE_CLIENT_ID');
  static const googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );

  static String _gatewayUrl(String path) {
    final base = Uri.parse(apiBaseUrl);
    final segments = [...base.pathSegments];
    if (segments.isNotEmpty && segments.last == 'api') segments.removeLast();
    return base
        .replace(pathSegments: [...segments, ...Uri.parse(path).pathSegments])
        .toString();
  }
}
