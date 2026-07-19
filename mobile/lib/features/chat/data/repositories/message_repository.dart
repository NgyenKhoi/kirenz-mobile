import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/network/api_response.dart';
import '../../../../core/network/dio_provider.dart';
import '../../domain/entities/chat_message.dart';
import '../cache/message_cache.dart';

final messageRepositoryProvider = Provider<MessageRepository>((ref) {
  return MessageRepository(
    ref.watch(dioProvider),
    ref.watch(messageCacheProvider),
  );
});

class MessageHistoryPage {
  const MessageHistoryPage({
    required this.messages,
    required this.isCached,
    this.cachedAt,
  });

  final List<ChatMessage> messages;
  final bool isCached;
  final DateTime? cachedAt;
}

class MessageRepository {
  const MessageRepository(this._dio, [this._cache]);

  final Dio _dio;
  final MessageCache? _cache;

  Future<List<ChatMessage>> getHistory(
    String conversationId, {
    required int page,
    int size = 50,
  }) async =>
      (await getHistoryCached(conversationId, page: page, size: size)).messages;

  Future<MessageHistoryPage> getHistoryCached(
    String conversationId, {
    required int page,
    int size = 50,
  }) async {
    try {
      final body = await _request(
        () => _dio.get<Object?>(
          '/messages/$conversationId',
          queryParameters: {'page': page, 'size': size},
        ),
      );
      final envelope = ApiResponse.fromJson<List<ChatMessage>>(body, (value) {
        if (value is! List) {
          throw const ApiException(
            'Message history response has an invalid shape.',
            kind: ApiFailureKind.parsing,
          );
        }
        return value
            .map((item) {
              if (item is! Map) {
                throw const ApiException(
                  'Message history contains an invalid row.',
                  kind: ApiFailureKind.parsing,
                );
              }
              return ChatMessage.fromJson(Map<String, dynamic>.from(item));
            })
            .toList(growable: false);
      });
      if (!envelope.success || envelope.data == null) {
        throw ApiException(
          envelope.message ?? 'Message history request failed.',
        );
      }
      return MessageHistoryPage(messages: envelope.data!, isCached: false);
    } on ApiException catch (error) {
      final canUseCache =
          page == 0 &&
          (error.kind == ApiFailureKind.transport ||
              error.kind == ApiFailureKind.server);
      final cached = canUseCache ? await _safeRead(conversationId) : null;
      if (cached == null) rethrow;
      return MessageHistoryPage(
        messages: cached.messages.reversed.toList(growable: false),
        isCached: true,
        cachedAt: cached.cachedAt,
      );
    }
  }

  Future<void> cacheSnapshot(
    String conversationId,
    List<ChatMessage> messages,
  ) async {
    try {
      await _cache?.write(conversationId, messages);
    } on Object {
      return;
    }
  }

  Future<void> markRead(String conversationId) async {
    final body = await _request(
      () => _dio.post<Object?>('/messages/$conversationId/read'),
    );
    if (body['success'] != true) {
      throw ApiException(body['message']?.toString() ?? 'Mark read failed.');
    }
  }

  Future<ChatAttachment> upload(
    DraftAttachment file, {
    ProgressCallback? onProgress,
  }) async {
    final multipart = await MultipartFile.fromFile(
      file.path,
      filename: file.name,
      contentType: DioMediaType.parse(file.contentType),
    );
    final body = await _request(
      () => _dio.post<Object?>(
        '/media/chat',
        data: FormData.fromMap({'file': multipart}),
        onSendProgress: onProgress,
      ),
    );
    final envelope = ApiResponse.fromJson<ChatAttachment>(body, (value) {
      final json = _map(value);
      final url = json['url']?.toString() ?? '';
      final type = json['type']?.toString().toUpperCase() ?? '';
      if (url.isEmpty || !const {'IMAGE', 'VIDEO', 'FILE'}.contains(type)) {
        throw const ApiException(
          'Media upload response has an invalid shape.',
          kind: ApiFailureKind.parsing,
        );
      }
      return ChatAttachment(
        type: type,
        url: url,
        cloudinaryPublicId: json['publicId']?.toString() ?? '',
        metadata: {
          'width': json['width'],
          'height': json['height'],
          'format': json['format'],
          'bytes': json['bytes'] ?? file.bytes,
          'name': file.name,
          'contentType': file.contentType,
        }..removeWhere((key, value) => value == null),
      );
    });
    if (!envelope.success || envelope.data == null) {
      throw ApiException(envelope.message ?? 'Media upload failed.');
    }
    return envelope.data!;
  }

  Future<Map<String, dynamic>> _request(
    Future<Response<Object?>> Function() request,
  ) async {
    try {
      return _map((await request()).data);
    } on ApiException {
      rethrow;
    } on DioException catch (error) {
      throw ApiException(
        _map(error.response?.data)['message']?.toString() ??
            error.message ??
            'Message request failed.',
        statusCode: error.response?.statusCode,
        kind: apiFailureKindForResponse(
          hasResponse: error.response != null,
          statusCode: error.response?.statusCode,
        ),
      );
    }
  }

  Future<CachedMessages?> _safeRead(String conversationId) async {
    try {
      return await _cache?.read(conversationId);
    } on Object {
      return null;
    }
  }
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
