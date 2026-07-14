import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/network/api_response.dart';
import '../../../../core/network/dio_provider.dart';
import '../../domain/entities/friend_models.dart';

final friendRepositoryProvider = Provider<FriendRepository>((ref) {
  return FriendRepository(ref.watch(dioProvider));
});

class FriendRepository {
  const FriendRepository(this._dio);

  final Dio _dio;

  Future<List<UserSearchResult>> searchUsers(String query) => _readList(
    () => _dio.get<Object?>(
      '/users/search',
      queryParameters: {'q': query, 'limit': 12},
    ),
    UserSearchResult.fromJson,
  );

  Future<List<FriendRequest>> getIncomingRequests() => _readList(
    () => _dio.get<Object?>('/friends/requests/incoming'),
    FriendRequest.fromJson,
  );

  Future<List<FriendRequest>> getOutgoingRequests() => _readList(
    () => _dio.get<Object?>('/friends/requests/outgoing'),
    FriendRequest.fromJson,
  );

  Future<List<FriendSuggestion>> getSuggestions() => _readList(
    () => _dio.get<Object?>(
      '/friends/suggestions',
      queryParameters: {'limit': 20},
    ),
    FriendSuggestion.fromJson,
  );

  Future<List<Friend>> getFriends({String? userId}) => _readList(
    () => _dio.get<Object?>(
      userId == null ? '/friends' : '/friends/user/$userId',
    ),
    Friend.fromJson,
  );

  Future<RelationshipStatus> getStatus(String userId) async {
    try {
      final response = await _dio.get<Object?>('/friends/status/$userId');
      final body = _asMap(response.data);
      final envelope = ApiResponse.fromJson<RelationshipStatus>(
        body,
        (value) => relationshipStatusFromJson(_asMap(value)['status']),
      );
      if (!envelope.success || envelope.data == null) {
        throw ApiException(envelope.message ?? 'Friend status request failed.');
      }
      return envelope.data!;
    } on ApiException {
      rethrow;
    } on DioException catch (error) {
      throw ApiException(
        _errorMessage(error),
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<void> sendRequest(String userId) => _write(
    () => _dio.post<Object?>('/friends/requests', data: {'receiverId': userId}),
  );

  Future<void> acceptRequest(String requestId) =>
      _write(() => _dio.post<Object?>('/friends/requests/$requestId/accept'));

  Future<void> declineRequest(String requestId) =>
      _write(() => _dio.post<Object?>('/friends/requests/$requestId/decline'));

  Future<void> cancelRequest(String requestId) =>
      _write(() => _dio.delete<Object?>('/friends/requests/$requestId'));

  Future<void> removeFriend(String userId) =>
      _write(() => _dio.delete<Object?>('/friends/$userId'));

  Future<List<T>> _readList<T>(
    Future<Response<Object?>> Function() request,
    T Function(Map<String, dynamic>) parse,
  ) async {
    try {
      final response = await request();
      final body = _asMap(response.data);
      final envelope = ApiResponse.fromJson<List<T>>(
        body,
        (value) => value is List
            ? value.map((item) => parse(_asMap(item))).toList(growable: false)
            : <T>[],
      );
      if (!envelope.success) {
        throw ApiException(envelope.message ?? 'Friend request failed.');
      }
      return envelope.data ?? <T>[];
    } on ApiException {
      rethrow;
    } on DioException catch (error) {
      throw ApiException(
        _errorMessage(error),
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<void> _write(Future<Response<Object?>> Function() request) async {
    try {
      final response = await request();
      final body = _asMap(response.data);
      if (body['success'] != true) {
        throw ApiException(
          body['message']?.toString() ?? 'Friend action failed.',
        );
      }
    } on ApiException {
      rethrow;
    } on DioException catch (error) {
      throw ApiException(
        _errorMessage(error),
        statusCode: error.response?.statusCode,
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
      : error.message ?? 'Friend request failed.';
}
