import 'dart:async';
import 'dart:convert';

import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../../../core/network/network_config.dart';
import '../domain/entities/app_notification.dart';
import 'models/app_notification_model.dart';

class NotificationRealtimeClient {
  StompClient? _client;
  String? _connectedUserId;
  bool _connected = false;
  Future<void>? _connectInFlight;
  int _retainCount = 0;

  final StreamController<AppNotification> _notificationController =
      StreamController<AppNotification>.broadcast();
  final StreamController<int> _badgeController =
      StreamController<int>.broadcast();

  Stream<AppNotification> get notificationStream =>
      _notificationController.stream;
  Stream<int> get badgeStream => _badgeController.stream;
  bool get isConnected => _connected;

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

  Future<void> connect({required String userId, required String token}) async {
    if (_connectedUserId == userId && _connected) return;
    final inFlight = _connectInFlight;
    if (inFlight != null) {
      await inFlight;
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
        onConnect: (frame) {
          _connected = true;
          _connectedUserId = userId;
          _bindSubscriptions(userId);
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        onStompError: (_) {
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        onWebSocketError: (_) {
          if (!completer.isCompleted) {
            completer.complete();
          }
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

  Future<void> disconnect() async {
    _connected = false;
    _connectedUserId = null;
    _client?.deactivate();
    _client = null;
  }

  Future<void> dispose() async {
    await disconnect();
    await _notificationController.close();
    await _badgeController.close();
  }

  void _bindSubscriptions(String userId) {
    final client = _client;
    if (client == null) return;
    client.subscribe(
      destination: '/topic/notifications/$userId',
      callback: _onNotificationFrame,
    );
    client.subscribe(
      destination: '/topic/notifications/$userId/badge',
      callback: _onBadgeFrame,
    );
  }

  void _onNotificationFrame(StompFrame frame) {
    final body = frame.body;
    if (body == null || body.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) return;
      final notification = AppNotificationModel.fromJson(decoded);
      if (notification.id.trim().isEmpty) return;
      _notificationController.add(notification);
    } catch (_) {}
  }

  void _onBadgeFrame(StompFrame frame) {
    final body = frame.body;
    if (body == null || body.trim().isEmpty) return;
    final value = int.tryParse(body.trim());
    if (value != null) {
      _badgeController.add(value);
      return;
    }
    try {
      final decoded = jsonDecode(body);
      if (decoded is num) {
        _badgeController.add(decoded.toInt());
      }
    } catch (_) {}
  }

  String _normalizeWsBaseUrl(String baseUrl) {
    final trimmed = baseUrl.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    return 'http://$trimmed';
  }
}
