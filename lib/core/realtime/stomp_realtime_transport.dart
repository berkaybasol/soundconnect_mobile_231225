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
    this.onSocketDone,
  });

  final String url;
  final String token;
  final void Function() onConnect;
  final void Function() onProtocolError;
  final void Function() onTransportError;
  final void Function() onDisconnect;
  final void Function()? onSocketDone;
}

abstract interface class RealtimeTransport {
  void activate();
  void deactivate();

  void subscribe({
    required String destination,
    required RealtimeMessageCallback callback,
    void Function()? onReceipt,
  });

  void send({required String destination, required String body});
}

RealtimeTransport createStompRealtimeTransport(RealtimeTransportConfig config) {
  return StompRealtimeTransport(config);
}

class StompRealtimeTransport implements RealtimeTransport {
  StompRealtimeTransport(RealtimeTransportConfig config) {
    _client = StompClient(
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
        onConnect: (_) {
          _pendingReceipts.clear();
          config.onConnect();
        },
        onUnhandledReceipt: (frame) =>
            _pendingReceipts.remove(frame.headers['receipt-id'])?.call(),
        onStompError: (_) => config.onProtocolError(),
        onWebSocketError: (_) => config.onTransportError(),
        onWebSocketDone: config.onSocketDone ?? config.onDisconnect,
        onDisconnect: (_) => config.onDisconnect(),
      ),
    );
  }

  late final StompClient _client;
  final _pendingReceipts = <String, void Function()>{};
  int _subscriptionReceipt = 0;

  @override
  void activate() => _client.activate();

  @override
  void deactivate() {
    _pendingReceipts.clear();
    _client.deactivate();
  }

  @override
  void subscribe({
    required String destination,
    required RealtimeMessageCallback callback,
    void Function()? onReceipt,
  }) {
    final receipt = onReceipt == null
        ? null
        : 'subscribe-${++_subscriptionReceipt}';
    if (onReceipt != null) _pendingReceipts[receipt!] = onReceipt;
    _client.subscribe(
      destination: destination,
      headers: {if (receipt != null) 'receipt': receipt},
      callback: (frame) => callback(frame.body),
    );
  }

  @override
  void send({required String destination, required String body}) {
    _client.send(destination: destination, body: body);
  }
}
