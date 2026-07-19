import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../chat/domain/entities/realtime_chat.dart';
import '../../domain/entities/social_notification.dart';

final localNotificationServiceProvider = Provider<LocalNotificationService>((
  ref,
) {
  final service = LocalNotificationService();
  ref.onDispose(service.dispose);
  return service;
});

enum LocalNotificationPermission {
  notDetermined,
  provisional,
  authorized,
  deniedOrRestricted,
  unavailable,
}

class LocalNotificationService {
  static const _permissionRequestedKey =
      'kirenz.notification_permission_requested';
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<String> _routes = StreamController.broadcast();
  bool _initialized = false;
  String? _pendingRoute;

  Stream<String> get routes => _routes.stream;
  String? takePendingRoute() {
    final route = _pendingRoute;
    _pendingRoute = null;
    return route;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
        requestProvisionalPermission: false,
      ),
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        final route = response.payload;
        if (route != null && route.startsWith('/')) _routes.add(route);
      },
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    final launchRoute = launch?.notificationResponse?.payload;
    if (launch?.didNotificationLaunchApp == true &&
        launchRoute != null &&
        launchRoute.startsWith('/')) {
      _pendingRoute = launchRoute;
    }
    _initialized = true;
  }

  Future<LocalNotificationPermission> permissionStatus() async {
    if (kIsWeb) return LocalNotificationPermission.unavailable;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      final enabled = await android.areNotificationsEnabled();
      if (enabled == true) return LocalNotificationPermission.authorized;
      final requested =
          (await SharedPreferences.getInstance()).getBool(
            _permissionRequestedKey,
          ) ??
          false;
      return requested
          ? LocalNotificationPermission.deniedOrRestricted
          : LocalNotificationPermission.notDetermined;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      final options = await ios.checkPermissions();
      if (options == null) return LocalNotificationPermission.notDetermined;
      if (options.isProvisionalEnabled) {
        return LocalNotificationPermission.provisional;
      }
      if (options.isEnabled) return LocalNotificationPermission.authorized;
      final requested =
          (await SharedPreferences.getInstance()).getBool(
            _permissionRequestedKey,
          ) ??
          false;
      return requested
          ? LocalNotificationPermission.deniedOrRestricted
          : LocalNotificationPermission.notDetermined;
    }
    return LocalNotificationPermission.unavailable;
  }

  Future<LocalNotificationPermission> requestPermission() async {
    await initialize();
    await (await SharedPreferences.getInstance()).setBool(
      _permissionRequestedKey,
      true,
    );
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      await android.requestNotificationsPermission();
      return permissionStatus();
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      await ios.requestPermissions(alert: true, badge: true, sound: true);
      return permissionStatus();
    }
    return LocalNotificationPermission.unavailable;
  }

  Future<void> showSocial(SocialNotification notification, String route) async {
    await initialize();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'kirenz_social_v1',
        'Kirenz social alerts',
        channelDescription:
            'Friend, post, comment, mention, and birthday alerts',
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.social,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        threadIdentifier: 'kirenz-social',
      ),
    );
    await _plugin.show(
      id: _stableId(notification.id),
      title: notification.actorName,
      body: notification.message,
      notificationDetails: details,
      payload: route,
    );
  }

  Future<void> showChat(ConversationRealtimeUpdate update) async {
    final message = update.lastMessage;
    if (message == null || message.messageId.isEmpty) return;
    await initialize();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'kirenz_chat_v1',
        'Kirenz chat alerts',
        channelDescription: 'New direct and group chat messages',
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.message,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: false,
        presentSound: true,
        threadIdentifier: 'kirenz-chat',
      ),
    );
    await _plugin.show(
      id: _stableId('chat:${message.messageId}'),
      title: message.senderName,
      body: _chatPreview(message.type, message.content),
      notificationDetails: details,
      payload: '/chat/${update.conversationId}',
    );
  }

  String _chatPreview(String type, String content) => switch (type) {
    'IMAGE' => 'Sent an image',
    'VIDEO' => 'Sent a video',
    'FILE' => 'Sent a file',
    _ => content.trim().isEmpty ? 'New message' : content.trim(),
  };

  int _stableId(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }

  void dispose() => _routes.close();
}
