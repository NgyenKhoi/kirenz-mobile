typedef RealtimeMessageHandler = void Function(String body);
typedef RealtimeUnsubscribe = void Function();

abstract class RealtimeTransport {
  bool get isConnected;

  Future<void> connect({
    required String url,
    required String token,
    required void Function() onDisconnected,
    required void Function() onError,
  });

  RealtimeUnsubscribe subscribe(
    String destination,
    RealtimeMessageHandler onMessage,
  );

  void publish(String destination, String body);

  Future<void> disconnect();
}
