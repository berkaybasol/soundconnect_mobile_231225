import 'package:stomp_dart_client/stomp_dart_client.dart';

typedef RealtimeMessageCallback = void Function(String? body);
typedef RealtimeTransportFactory =
    RealtimeTransport Function(RealtimeTransportConfig config);

class RealtimeTransportConfig {
  const RealtimeTransportConfig({
    required this.url,
    required this.token,
    required this.onConnect,
    required this.onProtocolError,
    required this.onTransportError,
    required this.onDisconnect,
  });

  final String url;
  final String token;
  final void Function() onConnect;
  final void Function() onProtocolError;
  final void Function() onTransportError;
  final void Function() onDisconnect;
}

abstract interface class RealtimeTransport {
  void activate();
  void deactivate();

  void subscribe({
    required String destination,
    required RealtimeMessageCallback callback,
  });

  void send({required String destination, required String body});
}

RealtimeTransport createStompRealtimeTransport(RealtimeTransportConfig config) {
  return StompRealtimeTransport(config);
}

class StompRealtimeTransport implements RealtimeTransport {
  StompRealtimeTransport(RealtimeTransportConfig config)
    : _client = StompClient(
        config: StompConfig.sockJS(
          url: config.url,
          reconnectDelay: const Duration(seconds: 4),
          heartbeatIncoming: const Duration(seconds: 10),
          heartbeatOutgoing: const Duration(seconds: 10),
          webSocketConnectHeaders: <String, String>{
            'Authorization': 'Bearer ${config.token}',
          },
          stompConnectHeaders: <String, String>{
            'Authorization': 'Bearer ${config.token}',
          },
          onConnect: (_) => config.onConnect(),
          onStompError: (_) => config.onProtocolError(),
          onWebSocketError: (_) => config.onTransportError(),
          onDisconnect: (_) => config.onDisconnect(),
        ),
      );

  final StompClient _client;

  @override
  void activate() => _client.activate();

  @override
  void deactivate() => _client.deactivate();

  @override
  void subscribe({
    required String destination,
    required RealtimeMessageCallback callback,
  }) {
    _client.subscribe(
      destination: destination,
      callback: (frame) => callback(frame.body),
    );
  }

  @override
  void send({required String destination, required String body}) {
    _client.send(destination: destination, body: body);
  }
}
