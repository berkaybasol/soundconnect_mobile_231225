import 'dart:async';
import 'dart:convert';

import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../../../core/network/network_config.dart';
import '../domain/entities/table_group_message.dart';
import 'models/table_group_message_model.dart';

class TableGroupChatRealtimeClient {
  StompClient? _client;
  bool _connected = false;
  String? _connectedTableGroupId;
  Future<void>? _connectInFlight;
  int _retainCount = 0;

  final StreamController<TableGroupMessage> _messageController =
      StreamController<TableGroupMessage>.broadcast();

  Stream<TableGroupMessage> get messageStream => _messageController.stream;
  bool get isConnected => _connected;
  String? get connectedTableGroupId => _connectedTableGroupId;

  void retain() {
    _retainCount += 1;
  }

  Future<void> release() async {
    if (_retainCount > 0) {
      _retainCount -= 1;
    }
    if (_retainCount == 0) {
      await disconnect();
    }
  }

  Future<void> connect({
    required String tableGroupId,
    required String token,
  }) async {
    if (_connected && _connectedTableGroupId == tableGroupId) return;
    final inFlight = _connectInFlight;
    if (inFlight != null) {
      await inFlight;
      if (_connected && _connectedTableGroupId == tableGroupId) return;
    }
    final connectFuture = _connectInternal(
      tableGroupId: tableGroupId,
      token: token,
    );
    _connectInFlight = connectFuture;
    try {
      await connectFuture;
    } finally {
      if (identical(_connectInFlight, connectFuture)) {
        _connectInFlight = null;
      }
    }
  }

  Future<void> _connectInternal({
    required String tableGroupId,
    required String token,
  }) async {
    await disconnect();

    final wsBase = _normalizeWsBaseUrl(NetworkConfig.baseUrl);
    final sockJsUrl = '$wsBase/ws';
    final completer = Completer<void>();
    _client = StompClient(
      config: StompConfig.sockJS(
        url: sockJsUrl,
        reconnectDelay: const Duration(seconds: 4),
        heartbeatIncoming: const Duration(seconds: 10),
        heartbeatOutgoing: const Duration(seconds: 10),
        webSocketConnectHeaders: <String, String>{
          'Authorization': 'Bearer $token',
        },
        stompConnectHeaders: <String, String>{'Authorization': 'Bearer $token'},
        onConnect: (_) {
          _connected = true;
          _connectedTableGroupId = tableGroupId;
          _bindSubscriptions(tableGroupId);
          if (!completer.isCompleted) completer.complete();
        },
        onStompError: (_) {
          if (!completer.isCompleted) completer.complete();
        },
        onWebSocketError: (_) {
          if (!completer.isCompleted) completer.complete();
        },
        onDisconnect: (_) {
          _connected = false;
        },
      ),
    );
    _client?.activate();
    try {
      await completer.future.timeout(
        const Duration(seconds: 6),
        onTimeout: () {},
      );
    } catch (_) {}
  }

  void send({
    required String tableGroupId,
    required String content,
    String messageType = 'TEXT',
  }) {
    final client = _client;
    if (!_connected || client == null) return;
    client.send(
      destination: '/app/table-group/$tableGroupId/chat',
      body: jsonEncode(<String, dynamic>{
        'content': content,
        'messageType': messageType,
      }),
    );
  }

  void _bindSubscriptions(String tableGroupId) {
    final client = _client;
    if (client == null) return;
    client.subscribe(
      destination: '/topic/table_group/$tableGroupId',
      callback: _onFrame,
    );
    // Backward-compat: keep the older hyphenated channel if some envs still use it.
    client.subscribe(
      destination: '/topic/table-group/$tableGroupId',
      callback: _onFrame,
    );
  }

  void _onFrame(StompFrame frame) {
    final body = frame.body;
    if (body == null || body.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) return;
      final message = TableGroupMessageModel.fromJson(decoded);
      _messageController.add(message);
    } catch (_) {}
  }

  Future<void> disconnect() async {
    _connected = false;
    _connectedTableGroupId = null;
    _client?.deactivate();
    _client = null;
  }

  Future<void> dispose() async {
    await disconnect();
    await _messageController.close();
  }

  String _normalizeWsBaseUrl(String baseUrl) {
    final trimmed = baseUrl.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    return 'http://$trimmed';
  }
}
