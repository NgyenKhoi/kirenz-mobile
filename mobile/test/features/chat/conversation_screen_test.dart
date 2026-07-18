import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirenz_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:kirenz_mobile/features/auth/domain/entities/app_user.dart';
import 'package:kirenz_mobile/features/auth/presentation/controllers/session_controller.dart';
import 'package:kirenz_mobile/features/chat/data/cache/conversation_cache.dart';
import 'package:kirenz_mobile/features/chat/data/repositories/conversation_repository.dart';
import 'package:kirenz_mobile/features/chat/domain/entities/conversation.dart';
import 'package:kirenz_mobile/features/chat/presentation/screens/conversation_screen.dart';

void main() {
  testWidgets('cold detail route fetches and renders canonical conversation', (
    tester,
  ) async {
    final session = SessionController(_AuthRepository())
      ..signInForDevelopment();
    final repository = _Repository();
    final container = ProviderContainer(
      overrides: [
        sessionControllerProvider.overrideWith((ref) => session),
        conversationRepositoryProvider.overrideWithValue(repository),
        conversationCacheProvider.overrideWithValue(_Cache()),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: ConversationScreen(conversationId: 'cold-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.detailCalls, 1);
    expect(find.text('Cold conversation'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _Repository extends ConversationRepository {
  _Repository() : super(Dio());

  int detailCalls = 0;

  @override
  Future<CachedConversationList> getConversationsCached() async =>
      const CachedConversationList(data: [], isCached: false);

  @override
  Future<Conversation> getConversation(String conversationId) async {
    detailCalls++;
    return _conversation;
  }
}

class _Cache implements ConversationCache {
  @override
  Future<void> clear() async {}
  @override
  Future<CachedConversationList?> read() async => null;
  @override
  Future<void> write(List<Conversation> conversations) async {}
}

class _AuthRepository implements AuthRepository {
  @override
  Future<AppUser?> restoreSession() async => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _conversation = Conversation(
  id: 'cold-1',
  type: ConversationType.group,
  name: 'Cold conversation',
  participants: [],
  adminIds: {},
  currentUserAdmin: false,
  lastMessage: null,
  createdAt: null,
  updatedAt: null,
  unreadCount: 0,
);
