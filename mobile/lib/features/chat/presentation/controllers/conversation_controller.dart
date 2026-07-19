import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/conversation_repository.dart';
import '../../data/cache/conversation_cache.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/realtime_chat.dart';

final conversationControllerProvider =
    AsyncNotifierProvider<ConversationController, List<Conversation>>(
      ConversationController.new,
    );

final conversationCacheStatusProvider = StateProvider<DateTime?>((ref) => null);
final conversationPendingActionsProvider = StateProvider<Set<String>>(
  (ref) => const {},
);

class ConversationController extends AsyncNotifier<List<Conversation>> {
  final Set<String> _pendingDirect = {};
  final Set<String> _pendingConversations = {};
  bool _creatingGroup = false;

  @override
  Future<List<Conversation>> build() async {
    final result = await ref
        .watch(conversationRepositoryProvider)
        .getConversationsCached();
    ref.read(conversationCacheStatusProvider.notifier).state = result.isCached
        ? result.cachedAt
        : null;
    return _sorted(result.data);
  }

  Future<void> refresh() async {
    final previous = state.value;
    state = const AsyncLoading<List<Conversation>>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      final result = await ref
          .read(conversationRepositoryProvider)
          .getConversationsCached();
      ref.read(conversationCacheStatusProvider.notifier).state = result.isCached
          ? result.cachedAt
          : null;
      return _sorted(result.data);
    });
    if (state.hasError && previous != null) {
      state = AsyncValue<List<Conversation>>.error(
        state.error!,
        state.stackTrace!,
      ).copyWithPrevious(AsyncData(previous));
    }
  }

  Future<Conversation> getOrCreateDirect(String userId) async {
    if (_pendingDirect.contains(userId)) {
      throw StateError('Conversation creation is already pending.');
    }
    _pendingDirect.add(userId);
    try {
      final conversation = await ref
          .read(conversationRepositoryProvider)
          .getOrCreateDirect(userId);
      _replace(conversation);
      return conversation;
    } finally {
      _pendingDirect.remove(userId);
    }
  }

  Future<Conversation> createGroup({
    required String name,
    required List<String> participantIds,
  }) async {
    final normalizedName = name.trim();
    final ids = participantIds.toSet().toList(growable: false);
    if (normalizedName.isEmpty) throw ArgumentError('Group name is required.');
    if (ids.length < 2) {
      throw ArgumentError('Select at least two people.');
    }
    if (_creatingGroup) throw StateError('Group creation is already pending.');
    _creatingGroup = true;
    try {
      final conversation = await ref
          .read(conversationRepositoryProvider)
          .createGroup(normalizedName, ids);
      _replace(conversation);
      return conversation;
    } finally {
      _creatingGroup = false;
    }
  }

  Conversation? byId(String conversationId) => state.value
      ?.where((conversation) => conversation.id == conversationId)
      .firstOrNull;

  Future<Conversation> loadById(String conversationId) async {
    final existing = byId(conversationId);
    if (existing != null) return existing;
    final conversation = await ref
        .read(conversationRepositoryProvider)
        .getConversation(conversationId);
    _replace(conversation);
    return conversation;
  }

  Future<void> applyRealtimeUpdate(ConversationRealtimeUpdate update) async {
    final conversation = byId(update.conversationId);
    if (conversation == null) {
      await refresh();
      return;
    }
    _replace(
      conversation.copyWith(
        lastMessage: update.lastMessage,
        clearLastMessage: update.lastMessage == null,
        updatedAt: update.updatedAt,
        unreadCount: update.unreadCount,
      ),
    );
  }

  void markReadLocally(String conversationId) {
    final conversation = byId(conversationId);
    if (conversation == null || conversation.unreadCount == 0) return;
    _replace(conversation.copyWith(unreadCount: 0));
  }

  Future<Conversation> renameGroup(String conversationId, String name) =>
      _mutateConversation(
        'rename:$conversationId',
        () => ref
            .read(conversationRepositoryProvider)
            .renameGroup(conversationId, name),
      );

  Future<Conversation> addMember(String conversationId, String userId) =>
      _mutateConversation(
        'add:$conversationId:$userId',
        () => ref
            .read(conversationRepositoryProvider)
            .addMember(conversationId, userId),
      );

  Future<Conversation> kickMember(String conversationId, String userId) =>
      _mutateConversation(
        'kick:$conversationId:$userId',
        () => ref
            .read(conversationRepositoryProvider)
            .kickMember(conversationId, userId),
      );

  Future<Conversation> makeAdmin(String conversationId, String userId) =>
      _mutateConversation(
        'admin:$conversationId:$userId',
        () => ref
            .read(conversationRepositoryProvider)
            .makeAdmin(conversationId, userId),
      );

  Future<Conversation> updateNickname(
    String conversationId,
    String userId,
    String nickname,
  ) => _mutateConversation(
    'nickname:$conversationId:$userId',
    () => ref
        .read(conversationRepositoryProvider)
        .updateNickname(conversationId, userId, nickname),
  );

  Future<void> leaveGroup(String conversationId) async {
    await _mutateVoid('leave:$conversationId', () async {
      await ref.read(conversationRepositoryProvider).leaveGroup(conversationId);
      _remove(conversationId);
    });
  }

  Future<void> deleteGroup(String conversationId) async {
    await _mutateVoid('delete:$conversationId', () async {
      await ref
          .read(conversationRepositoryProvider)
          .deleteGroup(conversationId);
      _remove(conversationId);
    });
  }

  Future<Conversation> _mutateConversation(
    String key,
    Future<Conversation> Function() request,
  ) => _withConversationPending(key, () async {
    final conversation = await request();
    _replace(conversation);
    return conversation;
  });

  Future<void> _mutateVoid(String key, Future<void> Function() action) =>
      _withConversationPending<void>(key, action);

  Future<T> _withConversationPending<T>(
    String key,
    Future<T> Function() action,
  ) async {
    final conversationId = key.split(':')[1];
    if (!_pendingConversations.add(conversationId)) {
      throw StateError('Another action for this conversation is pending.');
    }
    try {
      return await _withPending(key, action);
    } finally {
      _pendingConversations.remove(conversationId);
    }
  }

  Future<T> _withPending<T>(String key, Future<T> Function() action) async {
    final pending = ref.read(conversationPendingActionsProvider);
    if (pending.contains(key)) {
      throw StateError('This conversation action is already pending.');
    }
    ref.read(conversationPendingActionsProvider.notifier).state = {
      ...pending,
      key,
    };
    try {
      return await action();
    } finally {
      ref.read(conversationPendingActionsProvider.notifier).state = {
        ...ref.read(conversationPendingActionsProvider),
      }..remove(key);
    }
  }

  void _replace(Conversation conversation) {
    final rows = [...?state.value];
    final index = rows.indexWhere((item) => item.id == conversation.id);
    if (index < 0) {
      rows.add(conversation);
    } else {
      rows[index] = conversation;
    }
    state = AsyncData(_sorted(rows));
    unawaited(_writeCache(state.requireValue));
  }

  Future<void> _writeCache(List<Conversation> rows) async {
    try {
      await ref.read(conversationCacheProvider).write(rows);
    } on Object {
      return;
    }
  }

  void _remove(String conversationId) {
    final rows = [...?state.value]
      ..removeWhere((conversation) => conversation.id == conversationId);
    state = AsyncData(_sorted(rows));
    unawaited(_writeCache(state.requireValue));
  }
}

List<Conversation> _sorted(List<Conversation> rows) {
  final result = [...rows];
  result.sort(
    (a, b) => (b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
      a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
    ),
  );
  return result;
}
