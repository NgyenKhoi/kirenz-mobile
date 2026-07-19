import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/network/api_response.dart';
import '../../../../core/network/dio_provider.dart';
import '../../domain/entities/realtime_chat.dart';

final presenceRepositoryProvider = Provider<PresenceRepository>((ref) {
  return PresenceRepository(ref.watch(dioProvider));
});

class PresenceRepository {
  const PresenceRepository(this._dio, {this.batchSize = 50});

  final Dio _dio;
  final int batchSize;

  Future<Map<String, UserPresence>> getStatuses(
    Iterable<String> userIds,
  ) async {
    final unique = userIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final result = <String, UserPresence>{};
    for (var start = 0; start < unique.length; start += batchSize) {
      final end = (start + batchSize).clamp(0, unique.length);
      final batch = unique.sublist(start, end);
      final body = await _request(batch);
      result.addAll(body);
    }
    return result;
  }

  Future<Map<String, UserPresence>> _request(List<String> userIds) async {
    try {
      final response = await _dio.get<Object?>(
        '/presence/status',
        queryParameters: {'userIds': userIds.join(',')},
      );
      final body = _map(response.data);
      final envelope = ApiResponse.fromJson<Map<String, UserPresence>>(
        body,
        _parseSnapshot,
      );
      if (!envelope.success || envelope.data == null) {
        throw ApiException(
          envelope.message ?? 'Presence response has an invalid shape.',
          kind: ApiFailureKind.parsing,
        );
      }
      return envelope.data!;
    } on DioException catch (error) {
      throw ApiException(
        _map(error.response?.data)['message']?.toString() ??
            error.message ??
            'Presence request failed.',
        statusCode: error.response?.statusCode,
        kind: apiFailureKindForResponse(
          hasResponse: error.response != null,
          statusCode: error.response?.statusCode,
        ),
      );
    }
  }
}

Map<String, UserPresence> _parseSnapshot(Object? value) {
  if (value is! Map) {
    throw const ApiException(
      'Presence response has an invalid shape.',
      kind: ApiFailureKind.parsing,
    );
  }
  return value.map((key, raw) {
    if (raw is! Map || raw['isOnline'] is! bool) {
      throw const ApiException(
        'Presence response contains an invalid row.',
        kind: ApiFailureKind.parsing,
      );
    }
    final epoch = int.tryParse(raw['lastSeen']?.toString() ?? '');
    return MapEntry(
      key.toString(),
      UserPresence(
        isOnline: raw['isOnline'] as bool,
        lastSeen: epoch == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(epoch, isUtc: true),
      ),
    );
  });
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
