import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/network/api_response.dart';
import '../../../../core/network/dio_provider.dart';
import '../../domain/entities/privacy_settings.dart';

final privacyRepositoryProvider = Provider<PrivacyRepository>((ref) {
  return PrivacyRepository(ref.watch(dioProvider));
});

class PrivacyRepository {
  const PrivacyRepository(this._dio);
  final Dio _dio;

  Future<PrivacySettings> getCurrent() =>
      _read(() => _dio.get<Object?>('/privacy/me'));

  Future<PrivacySettings> getForUser(String userId) =>
      _read(() => _dio.get<Object?>('/privacy/user/$userId'));

  Future<PrivacySettings> update(PrivacySettings settings) => _read(
    () => _dio.put<Object?>('/privacy/me', data: settings.toUpdateJson()),
  );

  Future<PrivacySettings> _read(
    Future<Response<Object?>> Function() request,
  ) async {
    try {
      final response = await request();
      final body = _asMap(response.data);
      final envelope = ApiResponse.fromJson<PrivacySettings>(
        body,
        (value) => PrivacySettings.fromJson(_asMap(value)),
      );
      if (!envelope.success || envelope.data == null) {
        throw ApiException(envelope.message ?? 'Privacy request failed.');
      }
      return envelope.data!;
    } on ApiException {
      rethrow;
    } on DioException catch (error) {
      throw ApiException(
        _errorMessage(error),
        statusCode: error.response?.statusCode,
      );
    } on FormatException catch (error) {
      throw ApiException(error.message);
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
      : error.message ?? 'Privacy request failed.';
}
