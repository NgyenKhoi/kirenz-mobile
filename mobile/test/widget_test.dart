import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirenz_mobile/app/kirenz_app.dart';
import 'package:kirenz_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:kirenz_mobile/features/auth/domain/entities/app_user.dart';
import 'package:kirenz_mobile/features/auth/presentation/controllers/session_controller.dart';
import 'package:kirenz_mobile/features/chat/data/cache/conversation_cache.dart';
import 'package:kirenz_mobile/features/chat/data/repositories/conversation_repository.dart';
import 'package:kirenz_mobile/features/chat/domain/entities/conversation.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('shows login when unauthenticated', (tester) async {
    final container = await _container();

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const KirenzApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('shows home after development sign in', (tester) async {
    final container = await _container();
    container.read(sessionControllerProvider.notifier).signInForDevelopment();

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const KirenzApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsWidgets);
  });

  testWidgets('shell Chat badge sums unread conversations', (tester) async {
    final container = await _container(
      conversationRepository: _ConversationRepository(),
    );
    container.read(sessionControllerProvider.notifier).signInForDevelopment();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const KirenzApp()),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: find.byType(NavigationBar), matching: find.text('5')),
      findsWidgets,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<ProviderContainer> _container({
  ConversationRepository? conversationRepository,
}) async {
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(_TestAuthRepository()),
      if (conversationRepository != null)
        conversationRepositoryProvider.overrideWithValue(
          conversationRepository,
        ),
      if (conversationRepository != null)
        conversationCacheProvider.overrideWithValue(_ConversationCache()),
    ],
  );
  await container.read(sessionControllerProvider.notifier).restoreSession();
  return container;
}

class _ConversationRepository extends ConversationRepository {
  _ConversationRepository() : super(Dio());

  @override
  Future<CachedConversationList> getConversationsCached() async =>
      const CachedConversationList(
        data: [
          Conversation(
            id: 'one',
            type: ConversationType.direct,
            name: null,
            participants: [],
            adminIds: {},
            currentUserAdmin: false,
            lastMessage: null,
            createdAt: null,
            updatedAt: null,
            unreadCount: 2,
          ),
          Conversation(
            id: 'two',
            type: ConversationType.group,
            name: 'Team',
            participants: [],
            adminIds: {},
            currentUserAdmin: false,
            lastMessage: null,
            createdAt: null,
            updatedAt: null,
            unreadCount: 3,
          ),
        ],
        isCached: false,
      );
}

class _ConversationCache implements ConversationCache {
  @override
  Future<void> clear() async {}
  @override
  Future<CachedConversationList?> read() async => null;
  @override
  Future<void> write(List<Conversation> conversations) async {}
}

class _TestAuthRepository implements AuthRepository {
  @override
  Future<AppUser?> restoreSession() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
