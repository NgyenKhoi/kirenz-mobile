import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirenz_mobile/features/friends/data/repositories/friend_repository.dart';

void main() {
  test('reads incoming requests from ApiResponse data', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.resolve(
          Response<Object?>(
            requestOptions: options,
            statusCode: 200,
            data: {
              'success': true,
              'message': 'Incoming friend requests retrieved successfully',
              'data': [
                {
                  'id': 'request-1',
                  'requesterId': 'web-user',
                  'receiverId': 'mobile-user',
                  'status': 'PENDING',
                  'username': 'web_sender',
                  'displayName': 'Web Sender',
                },
              ],
            },
          ),
        ),
      ),
    );

    final requests = await FriendRepository(dio).getIncomingRequests();

    expect(requests, hasLength(1));
    expect(requests.single.id, 'request-1');
    expect(requests.single.requesterId, 'web-user');
    expect(requests.single.resolvedName, 'Web Sender');
  });
}
