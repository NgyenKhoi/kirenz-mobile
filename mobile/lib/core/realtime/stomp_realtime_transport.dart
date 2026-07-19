import 'dart:async';

import 'package:stomp_dart_client/stomp_dart_client.dart';

import 'realtime_transport.dart';

class StompRealtimeTransport implements RealtimeTransport {
  StompClient? _client;
  bool _intentionalDisconnect = false;

  @override
  bool get isConnected => _client?.connected == true;

  @override
  Future<void> connect({
    required String url,
    required String token,
    required void Function() onDisconnected,
    required void Function() onError,
  }) async {
    await disconnect();
    _intentionalDisconnect = false;
    final completer = Completer<void>();
    late final StompClient client;
    client = StompClient(
      config: StompConfig.sockJS(
        url: url,
        reconnectDelay: Duration.zero,
        heartbeatIncoming: const Duration(seconds: 4),
        heartbeatOutgoing: const Duration(seconds: 4),
        connectionTimeout: const Duration(seconds: 15),
        stompConnectHeaders: {'Authorization': 'Bearer $token'},
        onConnect: (_) {
          if (!completer.isCompleted) completer.complete();
        },
        onStompError: (frame) {
          if (!completer.isCompleted) {
            completer.completeError(
              StateError(
                frame.headers['message'] ?? 'STOMP connection failed.',
              ),
            );
          } else {
            onError();
          }
        },
        onWebSocketError: (error) {
          if (!completer.isCompleted) completer.completeError(error);
        },
        onWebSocketDone: () {
          if (!completer.isCompleted) {
            completer.completeError(
              StateError('Realtime connection closed before STOMP connected.'),
            );
          }
          if (!_intentionalDisconnect) onDisconnected();
        },
      ),
    );
    _client = client;
    client.activate();
    try {
      await completer.future.timeout(const Duration(seconds: 16));
    } on Object {
      client.deactivate();
      if (identical(_client, client)) _client = null;
      rethrow;
    }
  }

  @override
  RealtimeUnsubscribe subscribe(
    String destination,
    RealtimeMessageHandler onMessage,
  ) {
    final client = _client;
    if (client == null || !client.connected) {
      throw StateError('Realtime transport is not connected.');
    }
    final unsubscribe = client.subscribe(
      destination: destination,
      callback: (frame) {
        final body = frame.body;
        if (body != null) onMessage(body);
      },
    );
    return () => unsubscribe();
  }

  @override
  void publish(String destination, String body) {
    final client = _client;
    if (client == null || !client.connected) {
      throw StateError('Realtime transport is not connected.');
    }
    client.send(
      destination: destination,
      body: body,
      headers: const {'content-type': 'application/json'},
    );
  }

  @override
  Future<void> disconnect() async {
    _intentionalDisconnect = true;
    _client?.deactivate();
    _client = null;
  }
}
