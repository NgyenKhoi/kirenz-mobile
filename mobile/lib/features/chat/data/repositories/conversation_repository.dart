import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/network/api_response.dart';
import '../../../../core/network/dio_provider.dart';
import '../../domain/entities/conversation.dart';
import '../cache/conversation_cache.dart';

final conversationRepositoryProvider = Provider<ConversationRepository>((ref) {
  return ConversationRepository(
    ref.watch(dioProvider),
    ref.watch(conversationCacheProvider),
  );
});

class ConversationRepository {
  const ConversationRepository(this._dio, [this._cache]);

  final Dio _dio;
  final ConversationCache? _cache;

  Future<List<Conversation>> getConversations() async {
    return (await getConversationsCached()).data;
  }

  Future<CachedConversationList> getConversationsCached() async {
    try {
      final response = await _request(
        () => _dio.get<Object?>('/conversations'),
      );
      final envelope = ApiResponse.fromJson<List<Conversation>>(response, (
        value,
      ) {
        if (value is! List) {
          throw const ApiException(
            'Conversation list response has an invalid shape.',
            kind: ApiFailureKind.parsing,
          );
        }
        return value
            .map((item) {
              if (item is! Map) {
                throw const ApiException(
                  'Conversation list contains an invalid row.',
                  kind: ApiFailureKind.parsing,
                );
              }
              final json = Map<String, dynamic>.from(item);
              final id = json['id']?.toString().trim() ?? '';
              final type = json['type']?.toString();
              if (id.isEmpty || (type != 'DIRECT' && type != 'GROUP')) {
                throw const ApiException(
                  'Conversation list contains an invalid row.',
                  kind: ApiFailureKind.parsing,
                );
              }
              return Conversation.fromJson(json);
            })
            .toList(growable: false);
      });
      if (!envelope.success) throw ApiException(_message(envelope));
      final rows = envelope.data;
      if (rows == null) {
        throw const ApiException(
          'Conversation list response has an invalid shape.',
          kind: ApiFailureKind.parsing,
        );
      }
      await _safeWrite(rows);
      return CachedConversationList(data: rows, isCached: false);
    } on ApiException catch (error) {
      final canUseCache =
          error.kind == ApiFailureKind.transport ||
          error.kind == ApiFailureKind.server;
      final cached = canUseCache ? await _safeRead() : null;
      if (cached != null) return cached;
      rethrow;
    }
  }

  Future<Conversation> getConversation(String conversationId) =>
      _conversation(() => _dio.get<Object?>('/conversations/$conversationId'));

  Future<Conversation> getOrCreateDirect(String userId) =>
      _conversation(() => _dio.post<Object?>('/conversations/direct/$userId'));

  Future<Conversation> createGroup(String name, List<String> participantIds) =>
      _conversation(
        () => _dio.post<Object?>(
          '/conversations',
          data: {
            'name': name.trim(),
            'type': 'GROUP',
            'participantIds': participantIds.toSet().toList(growable: false),
          },
        ),
      );

  Future<Conversation> renameGroup(String conversationId, String name) =>
      _conversation(
        () => _dio.patch<Object?>(
          '/conversations/$conversationId',
          data: {'name': name.trim()},
        ),
      );

  Future<Conversation> addMember(String conversationId, String userId) =>
      _conversation(
        () => _dio.post<Object?>(
          '/conversations/$conversationId/participants',
          queryParameters: {'userId': userId},
        ),
      );

  Future<Conversation> kickMember(String conversationId, String userId) =>
      _conversation(
        () => _dio.delete<Object?>(
          '/conversations/$conversationId/participants/$userId',
        ),
      );

  Future<Conversation> makeAdmin(String conversationId, String userId) =>
      _conversation(
        () =>
            _dio.post<Object?>('/conversations/$conversationId/admins/$userId'),
      );

  Future<Conversation> updateNickname(
    String conversationId,
    String userId,
    String nickname,
  ) => _conversation(
    () => _dio.patch<Object?>(
      '/conversations/$conversationId/nicknames/$userId',
      data: {'nickname': nickname.trim()},
    ),
  );

  Future<void> leaveGroup(String conversationId) =>
      _void(() => _dio.post<Object?>('/conversations/$conversationId/leave'));

  Future<void> deleteGroup(String conversationId) =>
      _void(() => _dio.delete<Object?>('/conversations/$conversationId'));

  Future<Conversation> _conversation(
    Future<Response<Object?>> Function() request,
  ) async {
    final body = await _request(request);
    final envelope = ApiResponse.fromJson<Conversation>(
      body,
      (value) => Conversation.fromJson(_map(value)),
    );
    if (!envelope.success ||
        envelope.data == null ||
        envelope.data!.id.isEmpty) {
      throw ApiException(_message(envelope));
    }
    return envelope.data!;
  }

  Future<Map<String, dynamic>> _request(
    Future<Response<Object?>> Function() request,
  ) async {
    try {
      return _map((await request()).data);
    } on DioException catch (error) {
      throw ApiException(
        _map(error.response?.data)['message']?.toString() ??
            error.message ??
            'Conversation request failed.',
        statusCode: error.response?.statusCode,
        kind: apiFailureKindForResponse(
          hasResponse: error.response != null,
          statusCode: error.response?.statusCode,
        ),
      );
    }
  }

  Future<void> _void(Future<Response<Object?>> Function() request) async {
    final body = await _request(request);
    if (body['success'] != true) {
      throw ApiException(
        body['message']?.toString() ?? 'Conversation action failed.',
      );
    }
  }

  Future<CachedConversationList?> _safeRead() async {
    try {
      return await _cache?.read();
    } on Object {
      return null;
    }
  }

  Future<void> _safeWrite(List<Conversation> rows) async {
    try {
      await _cache?.write(rows);
    } on Object {
      return;
    }
  }
}

String _message(ApiResponse<Object?> envelope) =>
    envelope.message ?? 'Conversation request failed.';

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
