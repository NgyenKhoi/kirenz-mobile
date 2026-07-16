import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirenz_mobile/features/chat/data/repositories/conversation_repository.dart';
import 'package:kirenz_mobile/features/chat/domain/entities/conversation.dart';
import 'package:kirenz_mobile/features/chat/presentation/controllers/conversation_controller.dart';

void main() {
  test('parses titles and every canonical last-message preview type', () {
    final conversation = Conversation.fromJson({
      'id': 'direct-1',
      'type': 'DIRECT',
      'participants': [
        {'userId': 'me', 'username': 'me'},
        {
          'userId': 'other',
          'username': 'other_user',
          'displayName': 'Other User',
          'nickname': 'Teammate',
        },
      ],
      'lastMessage': {
        'messageId': 'message-1',
        'senderId': 'me',
        'type': 'IMAGE',
      },
      'unreadCount': 2,
    });

    expect(conversation.titleFor('me'), 'Teammate');
    expect(conversation.previewFor('me'), 'You: Sent an image');
    expect(conversation.unreadCount, 2);
  });

  test('direct get-or-create replaces by id without duplicate rows', () async {
    final repository = _ConversationRepository(
      rows: [_conversation('direct-1', updatedAt: 1)],
      direct: _conversation('direct-1', updatedAt: 3),
    );
    final container = ProviderContainer(
      overrides: [conversationRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    await container.read(conversationControllerProvider.future);

    await container
        .read(conversationControllerProvider.notifier)
        .getOrCreateDirect('other');

    final rows = container.read(conversationControllerProvider).requireValue;
    expect(rows, hasLength(1));
    expect(rows.single.updatedAt, DateTime.fromMillisecondsSinceEpoch(3));
  });

  test('coalescing guard blocks a duplicate pending direct request', () async {
    final pending = Completer<Conversation>();
    final repository = _ConversationRepository(
      rows: const [],
      directFuture: pending.future,
    );
    final container = ProviderContainer(
      overrides: [conversationRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    await container.read(conversationControllerProvider.future);
    final controller = container.read(conversationControllerProvider.notifier);
    final first = controller.getOrCreateDirect('other');

    await expectLater(
      controller.getOrCreateDirect('other'),
      throwsA(isA<StateError>()),
    );
    pending.complete(_conversation('direct-1', updatedAt: 2));
    await first;
    expect(repository.directCalls, 1);
  });

  test(
    'group creation validates unique members and preserves canonical row',
    () async {
      final repository = _ConversationRepository(
        rows: const [],
        group: _conversation('group-1', updatedAt: 4, group: true),
      );
      final container = ProviderContainer(
        overrides: [
          conversationRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      await container.read(conversationControllerProvider.future);
      final controller = container.read(
        conversationControllerProvider.notifier,
      );

      await expectLater(
        controller.createGroup(
          name: 'Team',
          participantIds: const ['one', 'one'],
        ),
        throwsArgumentError,
      );
      await controller.createGroup(
        name: ' Team ',
        participantIds: const ['one', 'two'],
      );

      expect(repository.groupName, 'Team');
      expect(repository.groupIds, ['one', 'two']);
      expect(
        container.read(conversationControllerProvider).requireValue.single.id,
        'group-1',
      );
    },
  );
}

Conversation _conversation(
  String id, {
  required int updatedAt,
  bool group = false,
}) => Conversation(
  id: id,
  type: group ? ConversationType.group : ConversationType.direct,
  name: group ? 'Team' : null,
  participants: const [],
  adminIds: const {},
  currentUserAdmin: group,
  lastMessage: null,
  createdAt: null,
  updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAt),
  unreadCount: 0,
);

class _ConversationRepository extends ConversationRepository {
  _ConversationRepository({
    required this.rows,
    this.direct,
    this.directFuture,
    this.group,
  }) : super(Dio());

  final List<Conversation> rows;
  final Conversation? direct;
  final Future<Conversation>? directFuture;
  final Conversation? group;
  int directCalls = 0;
  String? groupName;
  List<String>? groupIds;

  @override
  Future<List<Conversation>> getConversations() async => rows;

  @override
  Future<Conversation> getOrCreateDirect(String userId) {
    directCalls++;
    return directFuture ?? Future.value(direct!);
  }

  @override
  Future<Conversation> createGroup(
    String name,
    List<String> participantIds,
  ) async {
    groupName = name;
    groupIds = participantIds;
    return group!;
  }
}
