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
import 'package:kirenz_mobile/features/chat/presentation/controllers/conversation_controller.dart';
import 'package:kirenz_mobile/features/chat/presentation/screens/chat_screen.dart';
import 'package:kirenz_mobile/features/friends/domain/entities/friend_models.dart';
import 'package:kirenz_mobile/features/friends/presentation/controllers/friends_controller.dart';

void main() {
  testWidgets('renders timestamp, unread badge and composite group avatar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final session = SessionController(_AuthRepository())
      ..signInForDevelopment();
    final container = ProviderContainer(
      overrides: [
        sessionControllerProvider.overrideWith((ref) => session),
        conversationRepositoryProvider.overrideWithValue(_Repository()),
        conversationCacheProvider.overrideWithValue(_Cache()),
        userSearchProvider.overrideWith(
          (ref, query) async => const [
            UserSearchResult(
              id: 'dev-user',
              username: 'developer',
              displayName: 'Current User',
              avatarUrl: null,
              bio: null,
              relationshipStatus: RelationshipStatus.self,
              allowDirectMessages: true,
            ),
            UserSearchResult(
              id: 'other',
              username: 'other',
              displayName: 'Other User',
              avatarUrl: null,
              bio: null,
              relationshipStatus: RelationshipStatus.friends,
              allowDirectMessages: true,
            ),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ChatScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Team'), findsOneWidget);
    expect(find.text('15/7'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('New message'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ot');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump();
    final sheet = find.byType(BottomSheet);
    expect(
      find.descendant(of: sheet, matching: find.text('Current User')),
      findsNothing,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('Other User')),
      findsOneWidget,
    );
  });

  testWidgets('failed refresh retains rows and exposes an error notice', (
    tester,
  ) async {
    final session = SessionController(_AuthRepository())
      ..signInForDevelopment();
    final repository = _Repository()..fail = false;
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
        child: const MaterialApp(home: ChatScreen()),
      ),
    );
    await tester.pumpAndSettle();
    repository.fail = true;

    await container.read(conversationControllerProvider.notifier).refresh();
    await tester.pump();

    expect(find.text('Team'), findsOneWidget);
    expect(find.text('Could not refresh conversations'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _Repository extends ConversationRepository {
  _Repository() : super(Dio());

  bool fail = false;

  @override
  Future<CachedConversationList> getConversationsCached() async {
    if (fail) throw StateError('offline');
    return CachedConversationList(data: [_group], isCached: false);
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

final _group = Conversation(
  id: 'group-1',
  type: ConversationType.group,
  name: 'Team',
  participants: const [
    ConversationParticipant(
      userId: 'a',
      username: 'alice',
      displayName: 'Alice',
      avatarUrl: null,
      allowDirectMessages: true,
      nickname: null,
      admin: false,
    ),
    ConversationParticipant(
      userId: 'b',
      username: 'bob',
      displayName: 'Bob',
      avatarUrl: null,
      allowDirectMessages: true,
      nickname: null,
      admin: false,
    ),
  ],
  adminIds: const {},
  currentUserAdmin: false,
  lastMessage: null,
  createdAt: null,
  updatedAt: DateTime.utc(2026, 7, 15),
  unreadCount: 3,
);
