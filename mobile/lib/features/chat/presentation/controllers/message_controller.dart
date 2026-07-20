import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/api_exception.dart';
import '../../data/repositories/message_repository.dart';
import '../../domain/entities/chat_message.dart';
import 'chat_realtime_controller.dart';
import 'conversation_controller.dart';

final messageControllerProvider = StateNotifierProvider.autoDispose
    .family<MessageController, MessageState, String>((ref, conversationId) {
      final controller = MessageController(
        conversationId: conversationId,
        repository: ref.watch(messageRepositoryProvider),
        realtime: ref.watch(chatRealtimeControllerProvider.notifier),
        realtimeMessages: ref
            .watch(chatRealtimeControllerProvider.notifier)
            .messageEvents,
        markConversationRead: () => ref
            .read(conversationControllerProvider.notifier)
            .markReadLocally(conversationId),
      );
      ref.listen<ChatRealtimeState>(chatRealtimeControllerProvider, (
        previous,
        next,
      ) {
        final reconnected =
            previous != null &&
            previous.status != ChatConnectionStatus.connected &&
            next.status == ChatConnectionStatus.connected;
        if (reconnected) unawaited(controller.reconcileLatest());
      });
      unawaited(controller.loadInitial());
      return controller;
    });

class MessageState {
  const MessageState({
    this.messages = const [],
    this.draftText = '',
    this.attachments = const [],
    this.loading = true,
    this.loadingOlder = false,
    this.hasMore = true,
    this.publishing = false,
    this.newMessageCount = 0,
    this.isCached = false,
    this.cachedAt,
    this.error,
    this.attachmentError,
  });

  final List<ChatMessage> messages;
  final String draftText;
  final List<DraftAttachment> attachments;
  final bool loading;
  final bool loadingOlder;
  final bool hasMore;
  final bool publishing;
  final int newMessageCount;
  final bool isCached;
  final DateTime? cachedAt;
  final String? error;
  final String? attachmentError;

  bool get attachmentsReady => attachments.every(
    (attachment) => attachment.status == DraftAttachmentStatus.uploaded,
  );

  bool get canPublish =>
      !publishing &&
      attachmentsReady &&
      (draftText.trim().isNotEmpty || attachments.isNotEmpty);

  MessageState copyWith({
    List<ChatMessage>? messages,
    String? draftText,
    List<DraftAttachment>? attachments,
    bool? loading,
    bool? loadingOlder,
    bool? hasMore,
    bool? publishing,
    int? newMessageCount,
    bool? isCached,
    DateTime? cachedAt,
    bool clearCachedAt = false,
    String? error,
    bool clearError = false,
    String? attachmentError,
    bool clearAttachmentError = false,
  }) => MessageState(
    messages: messages ?? this.messages,
    draftText: draftText ?? this.draftText,
    attachments: attachments ?? this.attachments,
    loading: loading ?? this.loading,
    loadingOlder: loadingOlder ?? this.loadingOlder,
    hasMore: hasMore ?? this.hasMore,
    publishing: publishing ?? this.publishing,
    newMessageCount: newMessageCount ?? this.newMessageCount,
    isCached: isCached ?? this.isCached,
    cachedAt: clearCachedAt ? null : cachedAt ?? this.cachedAt,
    error: clearError ? null : error ?? this.error,
    attachmentError: clearAttachmentError
        ? null
        : attachmentError ?? this.attachmentError,
  );
}

class MessageController extends StateNotifier<MessageState> {
  MessageController({
    required String conversationId,
    required MessageRepository repository,
    required ChatRealtimeController realtime,
    required Stream<Map<String, dynamic>> realtimeMessages,
    required void Function() markConversationRead,
  }) : this._(
         conversationId,
         repository,
         realtime,
         realtimeMessages,
         markConversationRead,
       );

  MessageController._(
    this.conversationId,
    this._repository,
    this._realtime,
    Stream<Map<String, dynamic>> realtimeMessages,
    this._markConversationRead,
  ) : super(const MessageState()) {
    _subscription = realtimeMessages.listen(_handleRealtimeMessage);
  }

  static const pageSize = 50;

  final String conversationId;
  final MessageRepository _repository;
  final ChatRealtimeController _realtime;
  final void Function() _markConversationRead;
  late final StreamSubscription<Map<String, dynamic>> _subscription;
  int _nextPage = 0;

  Future<void> loadInitial() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final result = await _repository.getHistoryCached(
        conversationId,
        page: 0,
        size: pageSize,
      );
      final page = result.messages;
      _nextPage = 1;
      state = state.copyWith(
        messages: _merge(const [], page.reversed),
        loading: false,
        hasMore: !result.isCached && page.length == pageSize,
        isCached: result.isCached,
        cachedAt: result.cachedAt,
        clearCachedAt: !result.isCached,
        clearError: true,
      );
      if (!result.isCached) {
        await _cacheSnapshot();
        await _markRead();
      }
    } on Object catch (error) {
      state = state.copyWith(loading: false, error: _message(error));
    }
  }

  Future<void> loadOlder() async {
    if (state.loading || state.loadingOlder || !state.hasMore) return;
    state = state.copyWith(loadingOlder: true, clearError: true);
    try {
      final result = await _repository.getHistoryCached(
        conversationId,
        page: _nextPage,
        size: pageSize,
      );
      final page = result.messages;
      _nextPage++;
      state = state.copyWith(
        messages: _merge(page.reversed, state.messages),
        loadingOlder: false,
        hasMore: page.length == pageSize,
        isCached: false,
        clearCachedAt: true,
      );
      await _cacheSnapshot();
    } on Object catch (error) {
      state = state.copyWith(loadingOlder: false, error: _message(error));
    }
  }

  Future<void> reconcileLatest() async {
    if (state.loading) return;
    try {
      final result = await _repository.getHistoryCached(
        conversationId,
        page: 0,
        size: pageSize,
      );
      if (result.isCached) return;
      final page = result.messages;
      state = state.copyWith(
        messages: _merge(state.messages, page.reversed),
        hasMore: page.length == pageSize || state.hasMore,
        isCached: false,
        clearCachedAt: true,
        clearError: true,
      );
      await _cacheSnapshot();
      await _markRead();
    } on Object catch (error) {
      if (state.messages.isEmpty) {
        state = state.copyWith(error: _message(error));
      }
    }
  }

  void updateDraft(String value, {required bool hasFocus}) {
    state = state.copyWith(draftText: value, clearError: true);
    unawaited(
      _realtime.updateLocalTyping(
        conversationId: conversationId,
        text: value,
        hasFocus: hasFocus,
      ),
    );
  }

  Future<void> stopTyping() => _realtime.stopTyping(conversationId);

  void addAttachments(Iterable<DraftAttachment> files) {
    final next = [...state.attachments];
    final errors = <String>[];
    for (final file in files) {
      if (next.any((item) => item.path == file.path)) continue;
      final imageCount = next.where((item) => item.type == 'IMAGE').length;
      if (file.type == 'IMAGE' && imageCount >= 10) {
        errors.add('You can attach up to 10 images.');
        continue;
      }
      final maxBytes = file.type == 'VIDEO'
          ? 500 * 1024 * 1024
          : 50 * 1024 * 1024;
      if (file.bytes <= 0 || file.bytes > maxBytes) {
        errors.add(
          '${file.name} exceeds the ${file.type == 'VIDEO' ? 500 : 50} MB limit.',
        );
        continue;
      }
      next.add(file);
    }
    state = state.copyWith(
      attachments: next,
      attachmentError: errors.isEmpty ? null : errors.join('\n'),
      clearAttachmentError: errors.isEmpty,
    );
    for (final file in next.where(
      (item) => item.status == DraftAttachmentStatus.local,
    )) {
      unawaited(uploadAttachment(file.path));
    }
  }

  void reportAttachmentError(String message) {
    state = state.copyWith(attachmentError: message);
  }

  Future<void> uploadAttachment(String path) async {
    final file = state.attachments
        .where((item) => item.path == path)
        .firstOrNull;
    if (file == null || file.status == DraftAttachmentStatus.uploading) return;
    _replaceAttachment(
      path,
      file.copyWith(
        status: DraftAttachmentStatus.uploading,
        progress: 0,
        clearError: true,
      ),
    );
    try {
      final uploaded = await _repository.upload(
        file,
        onProgress: (sent, total) {
          if (total <= 0) return;
          final current = state.attachments
              .where((item) => item.path == path)
              .firstOrNull;
          if (current == null ||
              current.status != DraftAttachmentStatus.uploading) {
            return;
          }
          _replaceAttachment(path, current.copyWith(progress: sent / total));
        },
      );
      final current = state.attachments
          .where((item) => item.path == path)
          .firstOrNull;
      if (current != null) {
        _replaceAttachment(
          path,
          current.copyWith(
            status: DraftAttachmentStatus.uploaded,
            progress: 1,
            uploaded: uploaded,
            clearError: true,
          ),
        );
      }
    } on Object catch (error) {
      final current = state.attachments
          .where((item) => item.path == path)
          .firstOrNull;
      if (current != null) {
        _replaceAttachment(
          path,
          current.copyWith(
            status: DraftAttachmentStatus.failed,
            error: _message(error),
          ),
        );
      }
    }
  }

  void removeAttachment(String path) {
    state = state.copyWith(
      attachments: [...state.attachments]
        ..removeWhere((item) => item.path == path),
      clearAttachmentError: true,
    );
  }

  Future<bool> publish() async {
    if (!state.canPublish) return false;
    state = state.copyWith(publishing: true, clearError: true);
    try {
      await stopTyping();
      _realtime.sendMessage(
        conversationId: conversationId,
        content: state.draftText,
        attachments: state.attachments
            .map((item) => item.uploaded!)
            .toList(growable: false),
      );
      state = state.copyWith(
        draftText: '',
        attachments: const [],
        publishing: false,
      );
      return true;
    } on Object catch (error) {
      state = state.copyWith(publishing: false, error: _message(error));
      return false;
    }
  }

  void clearNewMessageCount() {
    if (state.newMessageCount > 0) {
      state = state.copyWith(newMessageCount: 0);
    }
  }

  void _handleRealtimeMessage(Map<String, dynamic> json) {
    try {
      final message = ChatMessage.fromJson(json);
      if (message.conversationId != conversationId) return;
      final existed = state.messages.any((item) => item.id == message.id);
      state = state.copyWith(
        messages: _merge(state.messages, [message]),
        newMessageCount: existed
            ? state.newMessageCount
            : state.newMessageCount + 1,
      );
      unawaited(_cacheSnapshot());
      unawaited(_markRead());
    } on FormatException {
      return;
    }
  }

  Future<void> _markRead() async {
    try {
      await _repository.markRead(conversationId);
      _markConversationRead();
    } on Object {
      return;
    }
  }

  Future<void> _cacheSnapshot() =>
      _repository.cacheSnapshot(conversationId, state.messages);

  void _replaceAttachment(String path, DraftAttachment replacement) {
    state = state.copyWith(
      attachments: state.attachments
          .map((item) => item.path == path ? replacement : item)
          .toList(growable: false),
    );
  }

  List<ChatMessage> _merge(
    Iterable<ChatMessage> first,
    Iterable<ChatMessage> second,
  ) {
    final byId = <String, ChatMessage>{};
    for (final message in [...first, ...second]) {
      byId[message.id] = message;
    }
    final result = byId.values.toList();
    result.sort(
      (a, b) => (a.sentAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
        b.sentAt ?? DateTime.fromMillisecondsSinceEpoch(0),
      ),
    );
    return result;
  }

  String _message(Object error) =>
      error is ApiException ? error.message : error.toString();

  @override
  void dispose() {
    unawaited(stopTyping());
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
