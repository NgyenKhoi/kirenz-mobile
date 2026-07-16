import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/network/api_response.dart';
import '../../../../core/network/dio_provider.dart';
import '../../domain/entities/conversation.dart';

final conversationRepositoryProvider = Provider<ConversationRepository>((ref) {
  return ConversationRepository(ref.watch(dioProvider));
});

class ConversationRepository {
  const ConversationRepository(this._dio);

  final Dio _dio;

  Future<List<Conversation>> getConversations() async {
    final response = await _request(() => _dio.get<Object?>('/conversations'));
    final envelope = ApiResponse.fromJson<List<Conversation>>(
      response,
      (value) => value is List
          ? value
                .map((item) => Conversation.fromJson(_map(item)))
                .where((item) => item.id.isNotEmpty)
                .toList(growable: false)
          : const [],
    );
    if (!envelope.success) throw ApiException(_message(envelope));
    return envelope.data ?? const [];
  }

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
}

String _message(ApiResponse<Object?> envelope) =>
    envelope.message ?? 'Conversation request failed.';

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
