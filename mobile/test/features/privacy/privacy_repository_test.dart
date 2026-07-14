import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirenz_mobile/features/privacy/data/repositories/privacy_repository.dart';
import 'package:kirenz_mobile/features/privacy/domain/entities/privacy_settings.dart';

void main() {
  test('loads and updates canonical privacy settings', () async {
    final requests = <RequestOptions>[];
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          handler.resolve(
            Response<Object?>(
              requestOptions: options,
              statusCode: 200,
              data: {'success': true, 'message': 'ok', 'data': _privacyJson},
            ),
          );
        },
      ),
    );
    final repository = PrivacyRepository(dio);

    final current = await repository.getCurrent();
    await repository.update(current);

    expect(requests.map((item) => item.path), ['/privacy/me', '/privacy/me']);
    expect(requests.last.method, 'PUT');
    expect(requests.last.data, {
      'profileVisibility': 'FRIENDS_ONLY',
      'postVisibility': 'PRIVATE',
      'allowDirectMessages': false,
      'showOnlineStatus': true,
    });
    expect(current.profileVisibility, PrivacyVisibility.friendsOnly);
    expect(current.postVisibility, PrivacyVisibility.private);
  });

  test(
    'rejects unknown privacy enum instead of changing its meaning',
    () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.resolve(
            Response<Object?>(
              requestOptions: options,
              data: {
                'success': true,
                'data': {..._privacyJson, 'profileVisibility': 'FUTURE_VALUE'},
              },
            ),
          ),
        ),
      );

      expect(() => PrivacyRepository(dio).getCurrent(), throwsException);
    },
  );
}

const _privacyJson = {
  'userId': 'user-1',
  'profileVisibility': 'FRIENDS_ONLY',
  'postVisibility': 'PRIVATE',
  'allowDirectMessages': false,
  'showOnlineStatus': true,
  'updatedAt': '2026-07-15T01:00:00Z',
};
