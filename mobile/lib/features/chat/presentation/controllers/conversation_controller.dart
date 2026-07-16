import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/conversation_repository.dart';
import '../../domain/entities/conversation.dart';

final conversationControllerProvider =
    AsyncNotifierProvider<ConversationController, List<Conversation>>(
      ConversationController.new,
    );

class ConversationController extends AsyncNotifier<List<Conversation>> {
  final Set<String> _pendingDirect = {};
  bool _creatingGroup = false;

  @override
  Future<List<Conversation>> build() async {
    return _sorted(
      await ref.watch(conversationRepositoryProvider).getConversations(),
    );
  }

  Future<void> refresh() async {
    final previous = state.value;
    state = const AsyncLoading<List<Conversation>>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      final rows = await ref
          .read(conversationRepositoryProvider)
          .getConversations();
      return _sorted(rows);
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

  void _replace(Conversation conversation) {
    final rows = [...?state.value];
    final index = rows.indexWhere((item) => item.id == conversation.id);
    if (index < 0) {
      rows.add(conversation);
    } else {
      rows[index] = conversation;
    }
    state = AsyncData(_sorted(rows));
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
