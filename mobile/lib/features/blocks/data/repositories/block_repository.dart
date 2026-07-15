import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/network/api_response.dart';
import '../../../../core/network/dio_provider.dart';
import '../../domain/entities/block_models.dart';

final blockRepositoryProvider = Provider<BlockRepository>((ref) {
  return BlockRepository(ref.watch(dioProvider));
});

class BlockRepository {
  const BlockRepository(this._dio);
  final Dio _dio;

  Future<List<BlockRecord>> listBlockedUsers() =>
      _readList(() => _dio.get<Object?>('/blocks'));

  Future<BlockStatus> getStatus(String userId) =>
      _readStatus(() => _dio.get<Object?>('/blocks/status/$userId'));

  Future<void> block(String userId) =>
      _write(() => _dio.post<Object?>('/blocks/$userId'));

  Future<void> unblock(String userId) =>
      _write(() => _dio.delete<Object?>('/blocks/$userId'));

  Future<List<BlockRecord>> _readList(
    Future<Response<Object?>> Function() request,
  ) async {
    return _request(() async {
      final body = _asMap((await request()).data);
      final envelope = ApiResponse.fromJson<List<BlockRecord>>(
        body,
        (value) => value is List
            ? value
                  .map((item) => BlockRecord.fromJson(_asMap(item)))
                  .toList(growable: false)
            : <BlockRecord>[],
      );
      if (!envelope.success) {
        throw ApiException(envelope.message ?? 'Block request failed.');
      }
      return envelope.data ?? <BlockRecord>[];
    });
  }

  Future<BlockStatus> _readStatus(
    Future<Response<Object?>> Function() request,
  ) async {
    return _request(() async {
      final body = _asMap((await request()).data);
      final envelope = ApiResponse.fromJson<BlockStatus>(
        body,
        (value) => BlockStatus.fromJson(_asMap(value)),
      );
      if (!envelope.success || envelope.data == null) {
        throw ApiException(envelope.message ?? 'Block request failed.');
      }
      return envelope.data!;
    });
  }

  Future<void> _write(Future<Response<Object?>> Function() request) {
    return _request(() async {
      final body = _asMap((await request()).data);
      if (body['success'] != true) {
        throw ApiException(
          body['message']?.toString() ?? 'Block action failed.',
        );
      }
    });
  }

  Future<T> _request<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on ApiException {
      rethrow;
    } on DioException catch (error) {
      throw ApiException(
        _errorMessage(error),
        statusCode: error.response?.statusCode,
        kind: apiFailureKindForResponse(
          hasResponse: error.response != null,
          statusCode: error.response?.statusCode,
        ),
      );
    }
  }
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

String _errorMessage(DioException error) {
  final message = _asMap(error.response?.data)['message']?.toString();
  return message?.isNotEmpty == true
      ? message!
      : error.message ?? 'Block request failed.';
}
