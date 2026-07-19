import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/errors/api_exception.dart';
import '../../../../core/realtime/realtime_transport.dart';
import '../../../../core/realtime/stomp_realtime_transport.dart';
import '../../../../core/storage/token_storage.dart';
import '../../data/repositories/notification_repository.dart';
import '../../domain/entities/social_notification.dart';

final notificationRealtimeTransportProvider = Provider<RealtimeTransport>((
  ref,
) {
  return StompRealtimeTransport();
});

final notificationControllerProvider =
    StateNotifierProvider<NotificationController, NotificationState>((ref) {
      final controller = NotificationController(
        ref.watch(notificationRepositoryProvider),
        ref.watch(tokenStorageProvider),
        ref.watch(notificationRealtimeTransportProvider),
      );
      unawaited(controller.start());
      return controller;
    });

enum NotificationConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  failed,
}

class NotificationState {
  const NotificationState({
    this.items = const [],
    this.unreadCount = 0,
    this.listLoading = true,
    this.countLoading = true,
    this.refreshing = false,
    this.isCached = false,
    this.cachedAt,
    this.pendingIds = const {},
    this.markingAll = false,
    this.listError,
    this.countError,
    this.actionError,
    this.connectionStatus = NotificationConnectionStatus.disconnected,
    this.banner,
    this.bannerSequence = 0,
  });

  final List<SocialNotification> items;
  final int unreadCount;
  final bool listLoading;
  final bool countLoading;
  final bool refreshing;
  final bool isCached;
  final DateTime? cachedAt;
  final Set<String> pendingIds;
  final bool markingAll;
  final String? listError;
  final String? countError;
  final String? actionError;
  final NotificationConnectionStatus connectionStatus;
  final SocialNotification? banner;
  final int bannerSequence;

  NotificationState copyWith({
    List<SocialNotification>? items,
    int? unreadCount,
    bool? listLoading,
    bool? countLoading,
    bool? refreshing,
    bool? isCached,
    DateTime? cachedAt,
    bool clearCachedAt = false,
    Set<String>? pendingIds,
    bool? markingAll,
    String? listError,
    bool clearListError = false,
    String? countError,
    bool clearCountError = false,
    String? actionError,
    bool clearActionError = false,
    NotificationConnectionStatus? connectionStatus,
    SocialNotification? banner,
    bool clearBanner = false,
    int? bannerSequence,
  }) => NotificationState(
    items: items ?? this.items,
    unreadCount: unreadCount ?? this.unreadCount,
    listLoading: listLoading ?? this.listLoading,
    countLoading: countLoading ?? this.countLoading,
    refreshing: refreshing ?? this.refreshing,
    isCached: isCached ?? this.isCached,
    cachedAt: clearCachedAt ? null : cachedAt ?? this.cachedAt,
    pendingIds: pendingIds ?? this.pendingIds,
    markingAll: markingAll ?? this.markingAll,
    listError: clearListError ? null : listError ?? this.listError,
    countError: clearCountError ? null : countError ?? this.countError,
    actionError: clearActionError ? null : actionError ?? this.actionError,
    connectionStatus: connectionStatus ?? this.connectionStatus,
    banner: clearBanner ? null : banner ?? this.banner,
    bannerSequence: bannerSequence ?? this.bannerSequence,
  );
}

class NotificationController extends StateNotifier<NotificationState> {
  NotificationController(
    this._repository,
    this._tokenStorage,
    this._transport, {
    Random? random,
  }) : _random = random ?? Random(),
       super(const NotificationState());

  final NotificationRepository _repository;
  final TokenStorage _tokenStorage;
  final RealtimeTransport _transport;
  final Random _random;
  final List<RealtimeUnsubscribe> _subscriptions = [];
  Timer? _reconnectTimer;
  Timer? _bannerTimer;
  Future<void>? _connecting;
  int _generation = 0;
  int _failureCount = 0;
  bool _disposed = false;

  Future<void> start() async {
    await refresh();
    await connect();
  }

  Future<void> refresh() async {
    state = state.copyWith(
      refreshing: state.items.isNotEmpty,
      listLoading: state.items.isEmpty,
      countLoading: true,
      clearListError: true,
      clearCountError: true,
      clearActionError: true,
    );
    await Future.wait([_loadList(), _loadCount()]);
    if (!_disposed) state = state.copyWith(refreshing: false);
  }

  Future<void> _loadList() async {
    try {
      final result = await _repository.getNotifications();
      if (_disposed) return;
      state = state.copyWith(
        items: _merge(const [], result.items),
        unreadCount: result.isCached
            ? result.items.where((item) => !item.isRead).length
            : state.unreadCount,
        listLoading: false,
        isCached: result.isCached,
        cachedAt: result.cachedAt,
        clearCachedAt: !result.isCached,
      );
    } on Object catch (error) {
      if (_disposed) return;
      state = state.copyWith(listLoading: false, listError: _message(error));
    }
  }

  Future<void> _loadCount() async {
    try {
      final count = await _repository.getUnreadCount();
      if (_disposed) return;
      state = state.copyWith(
        unreadCount: count,
        countLoading: false,
        clearCountError: true,
      );
    } on Object catch (error) {
      if (_disposed) return;
      state = state.copyWith(countLoading: false, countError: _message(error));
    }
  }

  Future<bool> markRead(SocialNotification notification) async {
    if (notification.isRead || state.pendingIds.contains(notification.id)) {
      return true;
    }
    final snapshot = state.items;
    final countSnapshot = state.unreadCount;
    state = state.copyWith(
      items: state.items
          .map(
            (item) =>
                item.id == notification.id ? item.copyWith(isRead: true) : item,
          )
          .toList(growable: false),
      unreadCount: max(0, state.unreadCount - 1),
      pendingIds: {...state.pendingIds, notification.id},
      clearActionError: true,
    );
    try {
      final canonical = await _repository.markRead(notification.id);
      state = state.copyWith(items: _merge(state.items, [canonical]));
      await _repository.cache(state.items);
      unawaited(_loadCount());
      return true;
    } on Object catch (error) {
      state = state.copyWith(
        items: snapshot,
        unreadCount: countSnapshot,
        actionError: _message(error),
      );
      return false;
    } finally {
      state = state.copyWith(
        pendingIds: {...state.pendingIds}..remove(notification.id),
      );
    }
  }

  Future<bool> markAllRead() async {
    if (state.markingAll || state.unreadCount == 0) return false;
    final snapshot = state.items;
    final countSnapshot = state.unreadCount;
    state = state.copyWith(
      items: state.items
          .map((item) => item.copyWith(isRead: true))
          .toList(growable: false),
      unreadCount: 0,
      markingAll: true,
      clearActionError: true,
    );
    try {
      await _repository.markAllRead();
      await _repository.cache(state.items);
      await _loadCount();
      return true;
    } on Object catch (error) {
      state = state.copyWith(
        items: snapshot,
        unreadCount: countSnapshot,
        actionError: _message(error),
      );
      return false;
    } finally {
      state = state.copyWith(markingAll: false);
    }
  }

  Future<void> connect() {
    final active = _connecting;
    if (active != null) return active;
    if (_transport.isConnected) return Future.value();
    final operation = _connect();
    _connecting = operation;
    operation.whenComplete(() {
      if (identical(_connecting, operation)) _connecting = null;
    });
    return operation;
  }

  Future<void> _connect() async {
    final generation = ++_generation;
    _reconnectTimer?.cancel();
    final token = await _tokenStorage.readAccessToken();
    if (token == null || token.isEmpty || _disposed) return;
    state = state.copyWith(
      connectionStatus: _failureCount == 0
          ? NotificationConnectionStatus.connecting
          : NotificationConnectionStatus.reconnecting,
    );
    try {
      await _transport.connect(
        url: AppConfig.notificationRealtimeUrl,
        token: token,
        onDisconnected: _handleDisconnected,
        onError: _handleDisconnected,
      );
      if (_disposed || generation != _generation) return;
      _restoreSubscriptions();
      _failureCount = 0;
      state = state.copyWith(
        connectionStatus: NotificationConnectionStatus.connected,
      );
      await refresh();
    } on Object {
      if (_disposed || generation != _generation) return;
      _scheduleReconnect();
    }
  }

  void _restoreSubscriptions() {
    _clearSubscriptions();
    _subscriptions.add(
      _transport.subscribe('/user/queue/notifications', (body) {
        try {
          final decoded = jsonDecode(body);
          if (decoded is! Map) return;
          _applyRealtimeRow(
            SocialNotification.fromJson(Map<String, dynamic>.from(decoded)),
          );
        } on Object {
          return;
        }
      }),
    );
    _subscriptions.add(
      _transport.subscribe('/user/queue/notifications/unread-count', (body) {
        try {
          final decoded = jsonDecode(body);
          if (decoded is Map) {
            final count = int.tryParse(decoded['count']?.toString() ?? '');
            if (count != null) {
              state = state.copyWith(unreadCount: max(0, count));
            }
          }
        } on Object {
          return;
        }
      }),
    );
  }

  void _applyRealtimeRow(SocialNotification incoming) {
    if (incoming.id.isEmpty ||
        incoming.type == SocialNotificationType.unsupported) {
      return;
    }
    final existing = state.items
        .where((item) => item.id == incoming.id)
        .firstOrNull;
    final canonical = existing?.isRead == true && !incoming.isRead
        ? incoming.copyWith(isRead: true)
        : incoming;
    state = state.copyWith(items: _merge(state.items, [canonical]));
    unawaited(_repository.cache(state.items));
    if (existing == null) {
      _bannerTimer?.cancel();
      state = state.copyWith(
        banner: canonical,
        bannerSequence: state.bannerSequence + 1,
      );
      _bannerTimer = Timer(const Duration(seconds: 5), dismissBanner);
    }
  }

  void dismissBanner() {
    _bannerTimer?.cancel();
    if (state.banner != null) state = state.copyWith(clearBanner: true);
  }

  void _handleDisconnected() {
    if (_disposed) return;
    _clearSubscriptions();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _failureCount++;
    if (_failureCount >= 8) {
      state = state.copyWith(
        connectionStatus: NotificationConnectionStatus.failed,
      );
      return;
    }
    state = state.copyWith(
      connectionStatus: NotificationConnectionStatus.reconnecting,
    );
    final base = min(30, 1 << min(_failureCount, 5));
    final delay = Duration(seconds: base, milliseconds: _random.nextInt(700));
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, connect);
  }

  Future<void> onResumed() async {
    await refresh();
    await connect();
  }

  Future<void> onBackground() async {
    _generation++;
    _reconnectTimer?.cancel();
    _clearSubscriptions();
    await _transport.disconnect();
    if (!_disposed) {
      state = state.copyWith(
        connectionStatus: NotificationConnectionStatus.disconnected,
      );
    }
  }

  Future<void> disconnect() => onBackground();

  void _clearSubscriptions() {
    for (final unsubscribe in _subscriptions) {
      unsubscribe();
    }
    _subscriptions.clear();
  }

  List<SocialNotification> _merge(
    List<SocialNotification> current,
    List<SocialNotification> incoming,
  ) {
    final byId = {for (final item in current) item.id: item};
    for (final item in incoming) {
      final existing = byId[item.id];
      byId[item.id] = existing?.isRead == true && !item.isRead
          ? item.copyWith(isRead: true)
          : item;
    }
    final items = byId.values.toList();
    items.sort(
      (left, right) =>
          (right.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
            left.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
          ),
    );
    return items;
  }

  String _message(Object error) =>
      error is ApiException ? error.message : error.toString();

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _reconnectTimer?.cancel();
    _bannerTimer?.cancel();
    _clearSubscriptions();
    unawaited(_transport.disconnect());
    super.dispose();
  }
}
