import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kirenz_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:kirenz_mobile/features/auth/domain/entities/app_user.dart';
import 'package:kirenz_mobile/features/auth/presentation/controllers/session_controller.dart';
import 'package:kirenz_mobile/features/chat/data/cache/conversation_cache.dart';
import 'package:kirenz_mobile/features/chat/data/repositories/conversation_repository.dart';
import 'package:kirenz_mobile/features/chat/domain/entities/conversation.dart';
import 'package:kirenz_mobile/features/chat/presentation/screens/group_settings_screen.dart';
import 'package:kirenz_mobile/features/friends/domain/entities/friend_models.dart';
import 'package:kirenz_mobile/features/friends/presentation/controllers/friends_controller.dart';

void main() {
  testWidgets('admin sees management actions and member rows', (tester) async {
    await _pump(tester, admin: true);

    expect(find.text('Add member'), findsOneWidget);
    expect(find.text('Rename group'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Delete group'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Delete group'), findsOneWidget);
    expect(find.text('Leave group'), findsOneWidget);
    expect(find.text('Other User'), findsOneWidget);
    expect(find.text('OU'), findsOneWidget);
    expect(find.text('TU'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('add member debounces search and excludes existing users', (
    tester,
  ) async {
    await _pump(tester, admin: true);

    await tester.tap(find.text('Add member'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ne');
    await tester.pump(const Duration(milliseconds: 449));
    expect(find.text('New User'), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    final sheet = find.byType(BottomSheet);
    expect(
      find.descendant(of: sheet, matching: find.text('New User')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('Other User')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('rename Save is disabled until the trimmed name changes', (
    tester,
  ) async {
    await _pump(tester, admin: true);
    await tester.tap(find.text('Rename group'));
    await tester.pumpAndSettle();

    FilledButton save() =>
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'));
    expect(save().onPressed, isNull);
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(save().onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'New team');
    await tester.pump();
    expect(save().onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('non-admin only sees member-safe group actions', (tester) async {
    await _pump(tester, admin: false);

    expect(find.text('Add member'), findsNothing);
    expect(find.text('Rename group'), findsNothing);
    expect(find.text('Delete group'), findsNothing);
    expect(find.text('Leave group'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('member row opens that member profile', (tester) async {
    final repository = _Repository(_group(true));
    final session = SessionController(_AuthRepository())
      ..signInForDevelopment();
    final container = ProviderContainer(
      overrides: [
        conversationRepositoryProvider.overrideWithValue(repository),
        sessionControllerProvider.overrideWith((ref) => session),
        conversationCacheProvider.overrideWithValue(_MemoryCache()),
      ],
    );
    addTearDown(container.dispose);
    final router = GoRouter(
      initialLocation: '/chat/group-1/settings',
      routes: [
        GoRoute(
          path: '/chat/:id/settings',
          builder: (_, state) =>
              GroupSettingsScreen(conversationId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/profile/:id',
          builder: (_, state) =>
              Scaffold(body: Text('Profile ${state.pathParameters['id']}')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Other User'));
    await tester.pumpAndSettle();
    expect(find.text('Profile other'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(WidgetTester tester, {required bool admin}) async {
  tester.view.physicalSize = const Size(320, 700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repository = _Repository(_group(admin));
  final session = SessionController(_AuthRepository());
  session.signInForDevelopment();
  final container = ProviderContainer(
    overrides: [
      conversationRepositoryProvider.overrideWithValue(repository),
      sessionControllerProvider.overrideWith((ref) => session),
      conversationCacheProvider.overrideWithValue(_MemoryCache()),
      userSearchProvider.overrideWith(
        (ref, query) async => const [
          UserSearchResult(
            id: 'dev-user',
            username: 'developer',
            displayName: 'Developer',
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
          UserSearchResult(
            id: 'new-user',
            username: 'new_user',
            displayName: 'New User',
            avatarUrl: null,
            bio: null,
            relationshipStatus: RelationshipStatus.none,
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
      child: const MaterialApp(
        home: GroupSettingsScreen(conversationId: 'group-1'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Conversation _group(bool admin) => Conversation(
  id: 'group-1',
  type: ConversationType.group,
  name: 'Team',
  participants: const [
    ConversationParticipant(
      userId: 'dev-user',
      username: 'developer',
      displayName: 'Developer',
      avatarUrl: null,
      allowDirectMessages: true,
      nickname: null,
      admin: true,
    ),
    ConversationParticipant(
      userId: 'other',
      username: 'other',
      displayName: 'Other User',
      avatarUrl: null,
      allowDirectMessages: true,
      nickname: null,
      admin: false,
    ),
    ConversationParticipant(
      userId: 'third',
      username: 'third',
      displayName: 'Third User',
      avatarUrl: null,
      allowDirectMessages: true,
      nickname: null,
      admin: false,
    ),
  ],
  adminIds: admin ? const {'dev-user'} : const {'other'},
  currentUserAdmin: admin,
  lastMessage: null,
  createdAt: null,
  updatedAt: DateTime.utc(2026, 7, 16),
  unreadCount: 0,
);

class _Repository extends ConversationRepository {
  _Repository(this.group) : super(Dio());

  final Conversation group;

  @override
  Future<CachedConversationList> getConversationsCached() async =>
      CachedConversationList(data: [group], isCached: false);
}

class _MemoryCache implements ConversationCache {
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
