import 'dart:async';
import 'dart:convert';

import '../../../core/network/network_config.dart';
import '../../../core/realtime/realtime_client_error.dart';
import '../../../core/realtime/stomp_destinations.dart';
import '../../../core/realtime/stomp_realtime_transport.dart';
import '../domain/entities/table_group_message.dart';
import 'models/table_group_message_model.dart';

class TableGroupChatRealtimeClient {
  TableGroupChatRealtimeClient({
    RealtimeTransportFactory? transportFactory,
    Duration connectionTimeout = const Duration(seconds: 6),
  }) : _transportFactory = transportFactory ?? createStompRealtimeTransport,
       _connectionTimeout = connectionTimeout;

  final RealtimeTransportFactory _transportFactory;
  final Duration _connectionTimeout;

  RealtimeTransport? _transport;
  bool _connected = false;
  String? _connectedTableGroupId;
  Future<void>? _connectInFlight;
  Completer<void>? _pendingConnect;
  int _generation = 0;
  int _retainCount = 0;

  final StreamController<TableGroupMessage> _messageController =
      StreamController<TableGroupMessage>.broadcast();
  final StreamController<void> _connectionController =
      StreamController<void>.broadcast();
  final StreamController<RealtimeClientError> _errorController =
      StreamController<RealtimeClientError>.broadcast();

  Stream<TableGroupMessage> get messageStream => _messageController.stream;
  Stream<void> get connectionStream => _connectionController.stream;
  Stream<RealtimeClientError> get errorStream => _errorController.stream;
  bool get isConnected => _connected;
  String? get connectedTableGroupId => _connectedTableGroupId;

  void retain() {
    _retainCount += 1;
  }

  Future<void> release() async {
    if (_retainCount > 0) _retainCount -= 1;
    if (_retainCount == 0) await disconnect();
  }

  Future<void> connect({
    required String tableGroupId,
    required String token,
  }) async {
    if (_connected && _connectedTableGroupId == tableGroupId) return;
    final inFlight = _connectInFlight;
    if (inFlight != null) {
      try {
        await inFlight;
      } catch (_) {
        // A cancelled or failed previous-group handshake must not prevent this
        // caller from establishing the requested group session below.
      }
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
    final generation = _generation + 1;
    await disconnect();
    if (generation != _generation) {
      throw const RealtimeClientError(
        type: RealtimeClientErrorType.disconnected,
        message: 'Table-group realtime connection was cancelled.',
      );
    }
    final completer = Completer<void>();
    _pendingConnect = completer;

    void fail(RealtimeClientError error) {
      if (generation != _generation) return;
      _connected = false;
      _connectedTableGroupId = null;
      _emitError(error);
      if (!completer.isCompleted) completer.completeError(error);
      if (identical(_pendingConnect, completer)) _pendingConnect = null;
    }

    void handleDisconnect() {
      if (generation != _generation) return;
      final wasConnected = _connected;
      _connected = false;
      _connectedTableGroupId = null;
      if (wasConnected) {
        _emitError(
          const RealtimeClientError(
            type: RealtimeClientErrorType.disconnected,
            message: 'Table-group realtime connection was interrupted.',
          ),
        );
      }
      if (!completer.isCompleted) {
        completer.completeError(
          const RealtimeClientError(
            type: RealtimeClientErrorType.disconnected,
            message: 'Table-group realtime disconnected before it was ready.',
          ),
        );
      }
    }

    try {
      final transport = _transportFactory(
        RealtimeTransportConfig(
          url: '${_normalizeWsBaseUrl(NetworkConfig.baseUrl)}/ws',
          token: token,
          onConnect: () {
            if (generation != _generation) return;
            try {
              _connected = true;
              _connectedTableGroupId = tableGroupId;
              _bindSubscriptions(tableGroupId, generation);
              if (!_connectionController.isClosed) {
                _connectionController.add(null);
              }
              if (!completer.isCompleted) completer.complete();
              if (identical(_pendingConnect, completer)) {
                _pendingConnect = null;
              }
            } catch (_) {
              fail(
                const RealtimeClientError(
                  type: RealtimeClientErrorType.connection,
                  message:
                      'Table-group realtime subscriptions could not be created.',
                ),
              );
            }
          },
          onProtocolError: () => fail(
            const RealtimeClientError(
              type: RealtimeClientErrorType.protocol,
              message: 'Table-group realtime protocol error.',
            ),
          ),
          onTransportError: () => fail(
            const RealtimeClientError(
              type: RealtimeClientErrorType.connection,
              message: 'Table-group realtime connection failed.',
            ),
          ),
          onDisconnect: handleDisconnect,
          onSocketDone: handleDisconnect,
        ),
      );
      _transport = transport;
      transport.activate();
    } catch (_) {
      final error = const RealtimeClientError(
        type: RealtimeClientErrorType.connection,
        message: 'Table-group realtime connection could not be started.',
      );
      _emitError(error);
      _cleanupFailedConnection(generation);
      throw error;
    }

    try {
      await completer.future.timeout(_connectionTimeout);
    } on TimeoutException {
      if (!completer.isCompleted) completer.complete();
      if (identical(_pendingConnect, completer)) _pendingConnect = null;
      final error = const RealtimeClientError(
        type: RealtimeClientErrorType.timeout,
        message: 'Table-group realtime connection timed out.',
      );
      _emitError(error);
      _cleanupFailedConnection(generation);
      throw error;
    } catch (_) {
      _cleanupFailedConnection(generation);
      rethrow;
    }
  }

  Future<void> disconnect() async {
    _generation += 1;
    _connected = false;
    _connectedTableGroupId = null;

    final pending = _pendingConnect;
    _pendingConnect = null;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(
        const RealtimeClientError(
          type: RealtimeClientErrorType.disconnected,
          message: 'Table-group realtime connection was cancelled.',
        ),
      );
    }

    final transport = _transport;
    _transport = null;
    transport?.deactivate();
  }

  Future<void> dispose() async {
    await disconnect();
    await _messageController.close();
    await _connectionController.close();
    await _errorController.close();
  }

  void _cleanupFailedConnection(int generation) {
    if (generation != _generation) return;
    _generation += 1;
    _connected = false;
    _connectedTableGroupId = null;
    _pendingConnect = null;
    final transport = _transport;
    _transport = null;
    transport?.deactivate();
  }

  void _bindSubscriptions(String tableGroupId, int generation) {
    final transport = _transport;
    if (transport == null) return;

    bool isCurrentConnection() {
      return generation == _generation &&
          _connected &&
          _connectedTableGroupId == tableGroupId &&
          identical(_transport, transport);
    }

    transport.subscribe(
      destination: StompDestinations.tableGroup(tableGroupId),
      callback: (body) {
        if (!isCurrentConnection()) return;
        _onFrame(body, expectedTableGroupId: tableGroupId);
      },
    );
  }

  void _onFrame(String? body, {required String expectedTableGroupId}) {
    if (body == null || body.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Expected an object.');
      }
      final message = TableGroupMessageModel.fromWireJson(decoded);
      if (message.tableGroupId != expectedTableGroupId) {
        throw const FormatException('Table-group id mismatch.');
      }
      if (!_messageController.isClosed) _messageController.add(message);
    } catch (_) {
      _emitError(
        const RealtimeClientError(
          type: RealtimeClientErrorType.invalidPayload,
          message: 'Table-group realtime delivered an invalid payload.',
        ),
      );
    }
  }

  void _emitError(RealtimeClientError error) {
    if (!_errorController.isClosed) _errorController.add(error);
  }

  String _normalizeWsBaseUrl(String baseUrl) {
    final trimmed = baseUrl.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    return 'http://$trimmed';
  }
}
