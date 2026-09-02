import 'dart:async';
import 'dart:convert';

import '../../../core/network/network_config.dart';
import '../../../core/realtime/realtime_client_error.dart';
import '../../../core/realtime/stomp_destinations.dart';
import '../../../core/realtime/stomp_realtime_transport.dart';
import '../domain/entities/app_notification.dart';
import 'models/app_notification_model.dart';

class NotificationRealtimeClient {
  NotificationRealtimeClient({
    RealtimeTransportFactory? transportFactory,
    Duration connectionTimeout = const Duration(seconds: 6),
  }) : _transportFactory = transportFactory ?? createStompRealtimeTransport,
       _connectionTimeout = connectionTimeout;

  final RealtimeTransportFactory _transportFactory;
  final Duration _connectionTimeout;

  RealtimeTransport? _transport;
  String? _connectedUserId;
  bool _connected = false;
  Future<void>? _connectInFlight;
  Completer<void>? _pendingConnect;
  int _generation = 0;
  int _retainCount = 0;

  final StreamController<AppNotification> _notificationController =
      StreamController<AppNotification>.broadcast();
  final StreamController<int> _badgeController =
      StreamController<int>.broadcast();
  final StreamController<void> _connectionController =
      StreamController<void>.broadcast();
  final StreamController<RealtimeClientError> _errorController =
      StreamController<RealtimeClientError>.broadcast();

  Stream<AppNotification> get notificationStream =>
      _notificationController.stream;
  Stream<int> get badgeStream => _badgeController.stream;
  Stream<void> get connectionStream => _connectionController.stream;
  Stream<RealtimeClientError> get errorStream => _errorController.stream;
  bool get isConnected => _connected;

  void retain() {
    _retainCount += 1;
  }

  Future<void> release() async {
    if (_retainCount > 0) _retainCount -= 1;
    if (_retainCount == 0) await disconnect();
  }

  Future<void> connect({required String userId, required String token}) async {
    if (_connectedUserId == userId && _connected) return;
    final inFlight = _connectInFlight;
    if (inFlight != null) {
      try {
        await inFlight;
      } catch (_) {
        // A cancelled/failed previous-user handshake must not prevent this
        // caller from establishing the newly requested session below.
      }
      if (_connectedUserId == userId && _connected) return;
    }

    final connectFuture = _connectInternal(userId: userId, token: token);
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
    required String userId,
    required String token,
  }) async {
    final generation = _generation + 1;
    await disconnect();
    if (generation != _generation) {
      throw const RealtimeClientError(
        type: RealtimeClientErrorType.disconnected,
        message: 'Notification realtime connection was cancelled.',
      );
    }
    final completer = Completer<void>();
    _pendingConnect = completer;

    void fail(RealtimeClientError error) {
      if (generation != _generation) return;
      _connected = false;
      _connectedUserId = null;
      _emitError(error);
      if (!completer.isCompleted) completer.completeError(error);
      if (identical(_pendingConnect, completer)) _pendingConnect = null;
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
              _connectedUserId = userId;
              _bindSubscriptions(userId, generation);
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
                      'Notification realtime subscriptions could not be created.',
                ),
              );
            }
          },
          onProtocolError: () => fail(
            const RealtimeClientError(
              type: RealtimeClientErrorType.protocol,
              message: 'Notification realtime protocol error.',
            ),
          ),
          onTransportError: () => fail(
            const RealtimeClientError(
              type: RealtimeClientErrorType.connection,
              message: 'Notification realtime connection failed.',
            ),
          ),
          onDisconnect: () {
            if (generation != _generation) return;
            final wasConnected = _connected;
            _connected = false;
            _connectedUserId = null;
            if (wasConnected) {
              _emitError(
                const RealtimeClientError(
                  type: RealtimeClientErrorType.disconnected,
                  message: 'Notification realtime connection was interrupted.',
                ),
              );
            }
            if (!completer.isCompleted) {
              completer.completeError(
                const RealtimeClientError(
                  type: RealtimeClientErrorType.disconnected,
                  message:
                      'Notification realtime disconnected before it was ready.',
                ),
              );
            }
          },
        ),
      );
      _transport = transport;
      transport.activate();
    } catch (_) {
      final error = const RealtimeClientError(
        type: RealtimeClientErrorType.connection,
        message: 'Notification realtime connection could not be started.',
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
        message: 'Notification realtime connection timed out.',
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
    _connectedUserId = null;

    final pending = _pendingConnect;
    _pendingConnect = null;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(
        const RealtimeClientError(
          type: RealtimeClientErrorType.disconnected,
          message: 'Notification realtime connection was cancelled.',
        ),
      );
    }

    final transport = _transport;
    _transport = null;
    transport?.deactivate();
  }

  Future<void> dispose() async {
    await disconnect();
    await _notificationController.close();
    await _badgeController.close();
    await _connectionController.close();
    await _errorController.close();
  }

  void _cleanupFailedConnection(int generation) {
    if (generation != _generation) return;
    _generation += 1;
    _connected = false;
    _connectedUserId = null;
    _pendingConnect = null;
    final transport = _transport;
    _transport = null;
    transport?.deactivate();
  }

  void _bindSubscriptions(String userId, int generation) {
    final transport = _transport;
    if (transport == null) return;

    bool isCurrentConnection() {
      return generation == _generation &&
          _connected &&
          _connectedUserId == userId &&
          identical(_transport, transport);
    }

    transport.subscribe(
      destination: StompDestinations.notifications(userId),
      callback: (body) {
        if (!isCurrentConnection()) return;
        _onNotificationFrame(body, expectedUserId: userId);
      },
    );
    transport.subscribe(
      destination: StompDestinations.notificationsBadge(userId),
      callback: (body) {
        if (!isCurrentConnection()) return;
        _onBadgeFrame(body);
      },
    );
  }

  void _onNotificationFrame(String? body, {required String expectedUserId}) {
    if (body == null || body.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Expected an object.');
      }
      final notification = AppNotificationModel.fromJson(decoded);
      if (notification.id.trim().isEmpty) {
        throw const FormatException('Missing notification id.');
      }
      if (notification.recipientId.trim() != expectedUserId) {
        throw const FormatException('Notification recipient mismatch.');
      }
      _notificationController.add(notification);
    } catch (_) {
      _emitError(
        const RealtimeClientError(
          type: RealtimeClientErrorType.invalidPayload,
          message: 'Notification realtime delivered an invalid payload.',
        ),
      );
    }
  }

  void _onBadgeFrame(String? body) {
    if (body == null || body.trim().isEmpty) return;
    final value = int.tryParse(body.trim());
    if (value != null) {
      _badgeController.add(value);
      return;
    }
    try {
      final decoded = jsonDecode(body);
      if (decoded is! num) throw const FormatException('Expected a number.');
      _badgeController.add(decoded.toInt());
    } catch (_) {
      _emitError(
        const RealtimeClientError(
          type: RealtimeClientErrorType.invalidPayload,
          message: 'Notification realtime delivered an invalid badge payload.',
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
