import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/realtime/realtime_transport.dart';
import '../../../../core/realtime/stomp_realtime_transport.dart';
import '../../../../core/storage/token_storage.dart';
import '../../data/repositories/presence_repository.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/realtime_chat.dart';
import '../../domain/entities/chat_message.dart';
import 'conversation_controller.dart';

final realtimeTransportProvider = Provider<RealtimeTransport>((ref) {
  return StompRealtimeTransport();
});

final chatRealtimeControllerProvider =
    StateNotifierProvider<ChatRealtimeController, ChatRealtimeState>((ref) {
      final controller = ChatRealtimeController(
        transport: ref.watch(realtimeTransportProvider),
        tokenStorage: ref.watch(tokenStorageProvider),
        presenceRepository: ref.watch(presenceRepositoryProvider),
        onConversationUpdate: (update) => ref
            .read(conversationControllerProvider.notifier)
            .applyRealtimeUpdate(update),
        reconcileConversations: () =>
            ref.read(conversationControllerProvider.notifier).refresh(),
      );
      return controller;
    });

enum ChatConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  failed,
}

class ChatRealtimeState {
  const ChatRealtimeState({
    this.status = ChatConnectionStatus.disconnected,
    this.presence = const {},
    this.typingByConversation = const {},
    this.failureCount = 0,
    this.operationError,
  });

  final ChatConnectionStatus status;
  final Map<String, UserPresence> presence;
  final Map<String, List<TypingUser>> typingByConversation;
  final int failureCount;
  final String? operationError;

  bool get canSend => status == ChatConnectionStatus.connected;

  ChatRealtimeState copyWith({
    ChatConnectionStatus? status,
    Map<String, UserPresence>? presence,
    Map<String, List<TypingUser>>? typingByConversation,
    int? failureCount,
    String? operationError,
    bool clearOperationError = false,
  }) => ChatRealtimeState(
    status: status ?? this.status,
    presence: presence ?? this.presence,
    typingByConversation: typingByConversation ?? this.typingByConversation,
    failureCount: failureCount ?? this.failureCount,
    operationError: clearOperationError
        ? null
        : operationError ?? this.operationError,
  );
}

class ChatRealtimeController extends StateNotifier<ChatRealtimeState> {
  ChatRealtimeController({
    required RealtimeTransport transport,
    required TokenStorage tokenStorage,
    required PresenceRepository presenceRepository,
    required Future<void> Function(ConversationRealtimeUpdate update)
    onConversationUpdate,
    required Future<void> Function() reconcileConversations,
    Random? random,
  }) : this._(
         transport,
         tokenStorage,
         presenceRepository,
         onConversationUpdate,
         reconcileConversations,
         random ?? Random(),
       );

  ChatRealtimeController._(
    this._transport,
    this._tokenStorage,
    this._presenceRepository,
    this._onConversationUpdate,
    this._reconcileConversations,
    this._random,
  ) : super(const ChatRealtimeState());

  final RealtimeTransport _transport;
  final TokenStorage _tokenStorage;
  final PresenceRepository _presenceRepository;
  final Future<void> Function(ConversationRealtimeUpdate update)
  _onConversationUpdate;
  final Future<void> Function() _reconcileConversations;
  final Random _random;
  final StreamController<Map<String, dynamic>> _messageEvents =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<ConversationRealtimeUpdate> _conversationUpdateEvents =
      StreamController<ConversationRealtimeUpdate>.broadcast();
  final List<RealtimeUnsubscribe> _globalSubscriptions = [];
  final List<RealtimeUnsubscribe> _conversationSubscriptions = [];
  final Map<String, Timer> _remoteTypingTimers = {};
  Timer? _reconnectTimer;
  Timer? _localTypingIdleTimer;
  Conversation? _openConversation;
  String? _accountId;
  String? _locallyTypingConversationId;
  DateTime? _lastTypingPublish;
  Future<void>? _connecting;
  int _generation = 0;
  bool _disposed = false;

  Stream<Map<String, dynamic>> get messageEvents => _messageEvents.stream;
  Stream<ConversationRealtimeUpdate> get conversationUpdateEvents =>
      _conversationUpdateEvents.stream;
  String? get openConversationId => _openConversation?.id;

  Future<void> connect() {
    final active = _connecting;
    if (active != null) return active;
    if (_transport.isConnected &&
        state.status == ChatConnectionStatus.connected) {
      return Future.value();
    }
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
    final accountId = await _tokenStorage.readCurrentUserId();
    if (token == null ||
        token.isEmpty ||
        accountId == null ||
        accountId.isEmpty) {
      await disconnect();
      return;
    }
    if (_accountId != null && _accountId != accountId) {
      await _disconnectTransport(clearAccount: true);
    }
    _accountId = accountId;
    state = state.copyWith(
      status: state.failureCount == 0
          ? ChatConnectionStatus.connecting
          : ChatConnectionStatus.reconnecting,
    );
    try {
      await _transport.connect(
        url: AppConfig.chatRealtimeUrl,
        token: token,
        onDisconnected: _handleDisconnected,
        onError: _handleOperationError,
      );
      if (generation != _generation || _disposed) return;
      _restoreSubscriptions();
      state = state.copyWith(
        status: ChatConnectionStatus.connected,
        failureCount: 0,
        clearOperationError: true,
      );
      await _reconcileAfterConnection();
    } on Object {
      if (generation != _generation || _disposed) return;
      _recordFailure();
      rethrow;
    }
  }

  void _restoreSubscriptions() {
    _cancelSubscriptions(_globalSubscriptions);
    _cancelSubscriptions(_conversationSubscriptions);
    _globalSubscriptions.add(
      _transport.subscribe('/user/queue/messages', _handleConversationUpdate),
    );
    _globalSubscriptions.add(
      _transport.subscribe('/topic/presence', _handlePresenceEvent),
    );
    final conversation = _openConversation;
    if (conversation != null) _subscribeConversation(conversation);
  }

  Future<void> openConversation(Conversation conversation) async {
    if (_openConversation?.id != conversation.id) {
      await _stopLocalTyping();
      _cancelSubscriptions(_conversationSubscriptions);
      _clearRemoteTyping();
    }
    _openConversation = conversation;
    if (_transport.isConnected) _subscribeConversation(conversation);
    await _reconcilePresence(conversation);
  }

  Future<void> closeConversation(String conversationId) async {
    if (_openConversation?.id != conversationId) return;
    await _stopLocalTyping();
    _openConversation = null;
    _cancelSubscriptions(_conversationSubscriptions);
    _clearRemoteTyping();
  }

  void _subscribeConversation(Conversation conversation) {
    _cancelSubscriptions(_conversationSubscriptions);
    _conversationSubscriptions.add(
      _transport.subscribe('/topic/conversation.${conversation.id}', (body) {
        final json = _decode(body);
        if (json != null) _messageEvents.add(json);
      }),
    );
    _conversationSubscriptions.add(
      _transport.subscribe(
        '/topic/conversation.${conversation.id}.typing',
        (body) => _handleTypingEvent(conversation, body),
      ),
    );
  }

  Future<void> updateLocalTyping({
    required String conversationId,
    required String text,
    required bool hasFocus,
  }) async {
    final meaningful = text.trim().isNotEmpty && hasFocus;
    if (!meaningful) {
      await _stopLocalTyping(conversationId);
      return;
    }
    if (!state.canSend || _openConversation?.id != conversationId) return;
    final now = DateTime.now();
    final shouldPublish =
        _locallyTypingConversationId != conversationId ||
        _lastTypingPublish == null ||
        now.difference(_lastTypingPublish!) >= const Duration(seconds: 1);
    if (shouldPublish) {
      _publishTyping(conversationId, true);
      _locallyTypingConversationId = conversationId;
      _lastTypingPublish = now;
    }
    _localTypingIdleTimer?.cancel();
    _localTypingIdleTimer = Timer(const Duration(milliseconds: 1500), () {
      unawaited(_stopLocalTyping(conversationId));
    });
  }

  Future<void> stopTyping(String conversationId) =>
      _stopLocalTyping(conversationId);

  void sendMessage({
    required String conversationId,
    required String content,
    required List<ChatAttachment> attachments,
  }) {
    if (!state.canSend) {
      throw StateError('Realtime connection is unavailable.');
    }
    state = state.copyWith(clearOperationError: true);
    _transport.publish(
      '/app/chat.send',
      jsonEncode({
        'conversationId': conversationId,
        'content': content,
        'attachments': attachments
            .map((attachment) => attachment.toJson())
            .toList(growable: false),
      }),
    );
  }

  Future<void> _stopLocalTyping([String? conversationId]) async {
    _localTypingIdleTimer?.cancel();
    final active = _locallyTypingConversationId;
    if (active == null ||
        (conversationId != null && active != conversationId)) {
      return;
    }
    if (_transport.isConnected) {
      try {
        _publishTyping(active, false);
      } on Object {
        return;
      } finally {
        _locallyTypingConversationId = null;
        _lastTypingPublish = null;
      }
    } else {
      _locallyTypingConversationId = null;
      _lastTypingPublish = null;
    }
  }

  void _publishTyping(String conversationId, bool isTyping) {
    _transport.publish(
      '/app/chat.typing',
      jsonEncode({'conversationId': conversationId, 'isTyping': isTyping}),
    );
  }

  Future<void> onResumed() async {
    if (_accountId == null) return;
    if (!_transport.isConnected) {
      await retry();
      return;
    }
    final conversation = _openConversation;
    if (conversation != null) await _reconcilePresence(conversation);
  }

  Future<void> onBackground() async {
    await _stopLocalTyping();
  }

  Future<void> retry() async {
    state = state.copyWith(failureCount: 0, clearOperationError: true);
    await connect();
  }

  Future<void> disconnect() async {
    _generation++;
    await _stopLocalTyping();
    await _disconnectTransport(clearAccount: true);
    state = const ChatRealtimeState();
  }

  Future<void> _disconnectTransport({required bool clearAccount}) async {
    _reconnectTimer?.cancel();
    _cancelSubscriptions(_globalSubscriptions);
    _cancelSubscriptions(_conversationSubscriptions);
    _clearRemoteTyping();
    await _transport.disconnect();
    if (clearAccount) {
      _accountId = null;
      _openConversation = null;
    }
  }

  void _handleDisconnected() {
    if (_disposed || _accountId == null) return;
    _cancelSubscriptions(_globalSubscriptions);
    _cancelSubscriptions(_conversationSubscriptions);
    unawaited(_stopLocalTyping());
    _recordFailure();
  }

  void clearOperationError() {
    state = state.copyWith(clearOperationError: true);
  }

  void _handleOperationError() {
    if (_disposed) return;
    state = state.copyWith(
      operationError: 'A realtime action was rejected. Refresh and try again.',
    );
  }

  void _recordFailure() {
    final failures = state.failureCount + 1;
    if (failures >= 5) {
      state = state.copyWith(
        status: ChatConnectionStatus.failed,
        failureCount: failures,
      );
      return;
    }
    state = state.copyWith(
      status: ChatConnectionStatus.reconnecting,
      failureCount: failures,
    );
    final baseSeconds = min(1 << (failures - 1), 16);
    final jitter = _random.nextInt(500);
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(
      Duration(seconds: baseSeconds, milliseconds: jitter),
      () => unawaited(connect().catchError((_) {})),
    );
  }

  Future<void> _reconcileAfterConnection() async {
    try {
      await _reconcileConversations();
    } on Object {
      return;
    } finally {
      final conversation = _openConversation;
      if (conversation != null) await _reconcilePresence(conversation);
    }
  }

  Future<void> _reconcilePresence(Conversation conversation) async {
    try {
      final snapshot = await _presenceRepository.getStatuses(
        conversation.participants.map((participant) => participant.userId),
      );
      state = state.copyWith(presence: {...state.presence, ...snapshot});
    } on Object {
      return;
    }
  }

  void _handleConversationUpdate(String body) {
    final json = _decode(body);
    if (json == null) return;
    try {
      final update = ConversationRealtimeUpdate.fromJson(json);
      _conversationUpdateEvents.add(update);
      unawaited(_onConversationUpdate(update));
    } on FormatException {
      unawaited(_reconcileConversations());
    }
  }

  void _handlePresenceEvent(String body) {
    final json = _decode(body);
    if (json == null) return;
    final userId = json['userId']?.toString().trim() ?? '';
    final status = json['status']?.toString().toUpperCase();
    if (userId.isEmpty || (status != 'ONLINE' && status != 'OFFLINE')) {
      final conversation = _openConversation;
      if (conversation != null) unawaited(_reconcilePresence(conversation));
      return;
    }
    final epoch = int.tryParse(json['lastSeen']?.toString() ?? '');
    final presence = UserPresence(
      isOnline: status == 'ONLINE',
      lastSeen: status == 'OFFLINE' && epoch != null
          ? DateTime.fromMillisecondsSinceEpoch(epoch, isUtc: true)
          : null,
    );
    state = state.copyWith(presence: {...state.presence, userId: presence});
  }

  void _handleTypingEvent(Conversation conversation, String body) {
    final json = _decode(body);
    if (json == null || json['isTyping'] is! bool) return;
    final userId = json['userId']?.toString().trim() ?? '';
    if (userId.isEmpty || userId == _accountId) return;
    final key = '${conversation.id}:$userId';
    _remoteTypingTimers.remove(key)?.cancel();
    final current = {
      for (final user
          in state.typingByConversation[conversation.id] ??
              const <TypingUser>[])
        user.userId: user,
    };
    if (json['isTyping'] == false) {
      current.remove(userId);
    } else {
      final name = conversation.participants
          .where((participant) => participant.userId == userId)
          .map((participant) => participant.resolvedName)
          .firstOrNull;
      if (name == null) return;
      current[userId] = TypingUser(userId: userId, name: name);
      _remoteTypingTimers[key] = Timer(const Duration(seconds: 3), () {
        _removeRemoteTyping(conversation.id, userId);
      });
    }
    _setTyping(conversation.id, current.values.toList(growable: false));
  }

  void _removeRemoteTyping(String conversationId, String userId) {
    _remoteTypingTimers.remove('$conversationId:$userId')?.cancel();
    final current = [...?state.typingByConversation[conversationId]]
      ..removeWhere((user) => user.userId == userId);
    _setTyping(conversationId, current);
  }

  void _setTyping(String conversationId, List<TypingUser> users) {
    final next = Map<String, List<TypingUser>>.from(state.typingByConversation);
    users.isEmpty ? next.remove(conversationId) : next[conversationId] = users;
    state = state.copyWith(typingByConversation: next);
  }

  void _clearRemoteTyping() {
    for (final timer in _remoteTypingTimers.values) {
      timer.cancel();
    }
    _remoteTypingTimers.clear();
    state = state.copyWith(typingByConversation: const {});
  }

  void _cancelSubscriptions(List<RealtimeUnsubscribe> subscriptions) {
    for (final unsubscribe in subscriptions) {
      try {
        unsubscribe();
      } on Object {
        continue;
      }
    }
    subscriptions.clear();
  }

  Map<String, dynamic>? _decode(String body) {
    try {
      final value = jsonDecode(body);
      return value is Map ? Map<String, dynamic>.from(value) : null;
    } on FormatException {
      return null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _localTypingIdleTimer?.cancel();
    _cancelSubscriptions(_globalSubscriptions);
    _cancelSubscriptions(_conversationSubscriptions);
    for (final timer in _remoteTypingTimers.values) {
      timer.cancel();
    }
    _remoteTypingTimers.clear();
    unawaited(_transport.disconnect());
    unawaited(_messageEvents.close());
    unawaited(_conversationUpdateEvents.close());
    super.dispose();
  }
}

String typingLabel(List<TypingUser> users) {
  if (users.isEmpty) return '';
  if (users.length == 1) return '${users.first.name} is typing…';
  if (users.length == 2) {
    return '${users[0].name} and ${users[1].name} are typing…';
  }
  return 'Several people are typing…';
}
