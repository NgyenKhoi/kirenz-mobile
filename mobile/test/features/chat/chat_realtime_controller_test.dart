import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirenz_mobile/core/realtime/realtime_transport.dart';
import 'package:kirenz_mobile/core/storage/token_storage.dart';
import 'package:kirenz_mobile/features/chat/data/repositories/presence_repository.dart';
import 'package:kirenz_mobile/features/chat/domain/entities/conversation.dart';
import 'package:kirenz_mobile/features/chat/domain/entities/realtime_chat.dart';
import 'package:kirenz_mobile/features/chat/presentation/controllers/chat_realtime_controller.dart';

void main() {
  test('connects once, subscribes once, and restores open topics', () async {
    final transport = _FakeTransport();
    final controller = _controller(transport);

    await Future.wait([controller.connect(), controller.connect()]);
    await controller.openConversation(_conversation);

    expect(transport.connectCalls, 1);
    expect(transport.destinations, {
      '/user/queue/messages',
      '/topic/presence',
      '/topic/conversation.conversation-1',
      '/topic/conversation.conversation-1.typing',
    });
    expect(controller.state.status, ChatConnectionStatus.connected);
    expect(controller.state.presence['other-user']!.isOnline, isTrue);

    await controller.disconnect();
    expect(transport.destinations, isEmpty);
    expect(controller.state.presence, isEmpty);
    controller.dispose();
  });

  test('normalizes presence, typing, and conversation queue events', () async {
    final transport = _FakeTransport();
    final updates = <ConversationRealtimeUpdate>[];
    final controller = _controller(transport, updates: updates);
    await controller.connect();
    await controller.openConversation(_conversation);

    transport.emit(
      '/topic/presence',
      jsonEncode({
        'userId': 'other-user',
        'status': 'OFFLINE',
        'lastSeen': 1721304000000,
      }),
    );
    transport.emit(
      '/topic/conversation.conversation-1.typing',
      jsonEncode({'userId': 'other-user', 'isTyping': true}),
    );
    transport.emit(
      '/user/queue/messages',
      jsonEncode({
        'conversationId': 'conversation-1',
        'lastMessage': {
          'messageId': 'message-1',
          'content': 'Hello',
          'senderId': 'other-user',
          'senderName': 'Other User',
          'type': 'TEXT',
          'sentAt': '2026-07-19T08:00:00Z',
        },
        'unreadCount': 3,
        'updatedAt': '2026-07-19T08:00:00Z',
      }),
    );
    await Future<void>.delayed(Duration.zero);

    expect(controller.state.presence['other-user']!.isOnline, isFalse);
    expect(
      typingLabel(controller.state.typingByConversation['conversation-1']!),
      'Other User is typing…',
    );
    expect(updates.single.unreadCount, 3);

    transport.emit(
      '/topic/conversation.conversation-1.typing',
      jsonEncode({'userId': 'other-user', 'isTyping': false}),
    );
    expect(controller.state.typingByConversation, isEmpty);
    controller.dispose();
  });

  test('publishes bounded local typing start and explicit stop', () async {
    final transport = _FakeTransport();
    final controller = _controller(transport);
    await controller.connect();
    await controller.openConversation(_conversation);

    await controller.updateLocalTyping(
      conversationId: 'conversation-1',
      text: 'H',
      hasFocus: true,
    );
    await controller.updateLocalTyping(
      conversationId: 'conversation-1',
      text: 'Hello',
      hasFocus: true,
    );
    await controller.stopTyping('conversation-1');

    expect(transport.publications, hasLength(2));
    expect(jsonDecode(transport.publications.first.body), {
      'conversationId': 'conversation-1',
      'isTyping': true,
    });
    expect(jsonDecode(transport.publications.last.body), {
      'conversationId': 'conversation-1',
      'isTyping': false,
    });
    controller.dispose();
  });
}

ChatRealtimeController _controller(
  _FakeTransport transport, {
  List<ConversationRealtimeUpdate>? updates,
}) => ChatRealtimeController(
  transport: transport,
  tokenStorage: _MemoryTokenStorage(),
  presenceRepository: _FakePresenceRepository(),
  onConversationUpdate: (update) async => updates?.add(update),
  reconcileConversations: () async {},
);

class _FakeTransport implements RealtimeTransport {
  final Map<String, RealtimeMessageHandler> _subscriptions = {};
  final List<_Publication> publications = [];
  int connectCalls = 0;

  @override
  bool isConnected = false;

  Set<String> get destinations => _subscriptions.keys.toSet();

  @override
  Future<void> connect({
    required String url,
    required String token,
    required void Function() onDisconnected,
    required void Function() onError,
  }) async {
    connectCalls++;
    isConnected = true;
  }

  @override
  Future<void> disconnect() async {
    isConnected = false;
    _subscriptions.clear();
  }

  @override
  void publish(String destination, String body) {
    publications.add(_Publication(destination, body));
  }

  @override
  RealtimeUnsubscribe subscribe(
    String destination,
    RealtimeMessageHandler onMessage,
  ) {
    _subscriptions[destination] = onMessage;
    return () {
      if (identical(_subscriptions[destination], onMessage)) {
        _subscriptions.remove(destination);
      }
    };
  }

  void emit(String destination, String body) {
    _subscriptions[destination]?.call(body);
  }
}

class _Publication {
  const _Publication(this.destination, this.body);

  final String destination;
  final String body;
}

class _MemoryTokenStorage extends TokenStorage {
  _MemoryTokenStorage() : super(const FlutterSecureStorage());

  @override
  Future<String?> readAccessToken() async => 'access-token';

  @override
  Future<String?> readCurrentUserId() async => 'current-user';
}

class _FakePresenceRepository extends PresenceRepository {
  _FakePresenceRepository() : super(Dio());

  @override
  Future<Map<String, UserPresence>> getStatuses(
    Iterable<String> userIds,
  ) async {
    return {
      for (final id in userIds) id: UserPresence(isOnline: id == 'other-user'),
    };
  }
}

const _conversation = Conversation(
  id: 'conversation-1',
  type: ConversationType.direct,
  name: null,
  participants: [
    ConversationParticipant(
      userId: 'current-user',
      username: 'current',
      displayName: 'Current User',
      avatarUrl: null,
      allowDirectMessages: true,
      nickname: null,
      admin: false,
    ),
    ConversationParticipant(
      userId: 'other-user',
      username: 'other',
      displayName: 'Other User',
      avatarUrl: null,
      allowDirectMessages: true,
      nickname: null,
      admin: false,
    ),
  ],
  adminIds: {},
  currentUserAdmin: false,
  lastMessage: null,
  createdAt: null,
  updatedAt: null,
  unreadCount: 0,
);
