import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/network/api_response.dart';
import '../../../../core/network/dio_provider.dart';
import '../../../profile/data/cache/profile_cache.dart';
import '../../domain/entities/social_notification.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(
    ref.watch(dioProvider),
    ref.watch(profileCacheProvider),
  );
});

class NotificationListResult {
  const NotificationListResult({
    required this.items,
    required this.isCached,
    this.cachedAt,
  });

  final List<SocialNotification> items;
  final bool isCached;
  final DateTime? cachedAt;
}

class NotificationRepository {
  const NotificationRepository(this._dio, this._cache);

  final Dio _dio;
  final ProfileCache _cache;

  Future<NotificationListResult> getNotifications() async {
    try {
      final body = await _request(() => _dio.get<Object?>('/notifications'));
      final envelope = ApiResponse.fromJson<List<SocialNotification>>(
        body,
        (value) => value is List
            ? value
                  .whereType<Map>()
                  .map(
                    (item) => SocialNotification.fromJson(
                      Map<String, dynamic>.from(item),
                    ),
                  )
                  .where(
                    (item) =>
                        item.id.isNotEmpty &&
                        item.type != SocialNotificationType.unsupported,
                  )
                  .toList(growable: false)
            : throw const ApiException(
                'Notification list has an invalid shape.',
                kind: ApiFailureKind.parsing,
              ),
      );
      if (!envelope.success || envelope.data == null) {
        throw ApiException(envelope.message ?? 'Could not load alerts.');
      }
      final items = _sort(envelope.data!);
      await cache(items);
      return NotificationListResult(items: items, isCached: false);
    } on ApiException catch (error) {
      if (error.kind != ApiFailureKind.transport &&
          error.kind != ApiFailureKind.server) {
        rethrow;
      }
      final cached = await _readCache();
      if (cached == null || cached.value is! List) rethrow;
      return NotificationListResult(
        items: _sort(
          (cached.value! as List)
              .whereType<Map>()
              .map(
                (item) => SocialNotification.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .where((item) => item.id.isNotEmpty)
              .toList(growable: false),
        ),
        isCached: true,
        cachedAt: cached.updatedAt,
      );
    }
  }

  Future<int> getUnreadCount() async {
    final body = await _request(
      () => _dio.get<Object?>('/notifications/unread-count'),
    );
    final envelope = ApiResponse.fromJson<int>(body, (value) {
      if (value is num) return value.toInt();
      throw const ApiException(
        'Unread count has an invalid shape.',
        kind: ApiFailureKind.parsing,
      );
    });
    if (!envelope.success || envelope.data == null) {
      throw ApiException(envelope.message ?? 'Could not load unread count.');
    }
    return envelope.data!.clamp(0, 1 << 31);
  }

  Future<SocialNotification> markRead(String id) async {
    final body = await _request(
      () => _dio.patch<Object?>('/notifications/$id/read'),
    );
    final envelope = ApiResponse.fromJson<SocialNotification>(
      body,
      (value) => SocialNotification.fromJson(_map(value)),
    );
    if (!envelope.success || envelope.data?.id.isEmpty != false) {
      throw ApiException(envelope.message ?? 'Could not mark alert as read.');
    }
    return envelope.data!;
  }

  Future<void> markAllRead() async {
    final body = await _request(
      () => _dio.patch<Object?>('/notifications/read-all'),
    );
    if (body['success'] != true) {
      throw ApiException(
        body['message']?.toString() ?? 'Could not mark all read.',
      );
    }
  }

  Future<void> cache(List<SocialNotification> items) async {
    try {
      await _cache.write(
        'notifications',
        'current',
        items.map((item) => item.toJson()).toList(growable: false),
      );
    } on Object {
      return;
    }
  }

  Future<ProfileCacheEntry?> _readCache() async {
    try {
      return await _cache.read('notifications', 'current');
    } on Object {
      return null;
    }
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
            'Notification request failed.',
        statusCode: error.response?.statusCode,
        kind: apiFailureKindForResponse(
          hasResponse: error.response != null,
          statusCode: error.response?.statusCode,
        ),
      );
    }
  }

  List<SocialNotification> _sort(List<SocialNotification> items) => [...items]
    ..sort(
      (left, right) =>
          (right.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
            left.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
          ),
    );
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
