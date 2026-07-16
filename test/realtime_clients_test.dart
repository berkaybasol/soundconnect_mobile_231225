import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/realtime/realtime_client_error.dart';
import 'package:soundconnect_23_12_25codx/core/realtime/stomp_realtime_transport.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/data/dm_realtime_client.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/data/notification_realtime_client.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/data/table_group_chat_realtime_client.dart';

void main() {
  group('realtime connection failures', () {
    test('DM connect throws and emits a typed transport error', () async {
      final harness = _TransportHarness(_Activation.transportError);
      final client = DmRealtimeClient(transportFactory: harness.create);
      addTearDown(client.dispose);
      final streamedError = client.errorStream.first;

      await expectLater(
        client.connect(userId: 'u1', token: 'redacted'),
        throwsA(
          isA<RealtimeClientError>().having(
            (error) => error.type,
            'type',
            RealtimeClientErrorType.connection,
          ),
        ),
      );
      expect((await streamedError).type, RealtimeClientErrorType.connection);
      expect(client.isConnected, isFalse);
    });

    test('notification connect throws and emits a protocol error', () async {
      final harness = _TransportHarness(_Activation.protocolError);
      final client = NotificationRealtimeClient(
        transportFactory: harness.create,
      );
      addTearDown(client.dispose);
      final streamedError = client.errorStream.first;

      await expectLater(
        client.connect(userId: 'u1', token: 'redacted'),
        throwsA(
          isA<RealtimeClientError>().having(
            (error) => error.type,
            'type',
            RealtimeClientErrorType.protocol,
          ),
        ),
      );
      expect((await streamedError).type, RealtimeClientErrorType.protocol);
    });

    test('table-group connect times out instead of succeeding', () async {
      final harness = _TransportHarness(_Activation.none);
      final client = TableGroupChatRealtimeClient(
        transportFactory: harness.create,
        connectionTimeout: const Duration(milliseconds: 1),
      );
      addTearDown(client.dispose);
      final streamedError = client.errorStream.first;

      await expectLater(
        client.connect(tableGroupId: 'g1', token: 'redacted'),
        throwsA(
          isA<RealtimeClientError>().having(
            (error) => error.type,
            'type',
            RealtimeClientErrorType.timeout,
          ),
        ),
      );
      expect((await streamedError).type, RealtimeClientErrorType.timeout);
      expect(harness.transport?.deactivated, isTrue);
    });
  });

  group('realtime success contracts', () {
    test(
      'DM connects once, subscribes, decodes frames, and balances retains',
      () async {
        final harness = _TransportHarness(_Activation.connect);
        final client = DmRealtimeClient(transportFactory: harness.create);
        addTearDown(client.dispose);

        await Future.wait<void>(<Future<void>>[
          client.connect(userId: 'user-1', token: 'secret-token'),
          client.connect(userId: 'user-1', token: 'secret-token'),
        ]);

        expect(harness.createCalls, 1);
        expect(harness.transport?.config.token, 'secret-token');
        expect(harness.transport?.config.url, endsWith('/ws'));
        expect(harness.transport?.subscriptions.keys, <String>{
          '/topic/dm/user-1',
          '/topic/dm/user-1/badge',
        });

        final message = client.messageStream.first;
        final badge = client.badgeStream.first;
        harness.transport!.deliver(
          '/topic/dm/user-1',
          jsonEncode(<String, dynamic>{
            'messageId': 'message-1',
            'conversationId': 'conversation-1',
            'senderId': 'sender-1',
            'recipientId': 'user-1',
            'content': 'hello',
            'messageType': 'text',
            'sentAt': '2026-07-13T20:00:00Z',
          }),
        );
        harness.transport!.deliver('/topic/dm/user-1/badge', '7');

        expect((await message).messageId, 'message-1');
        expect((await badge), 7);

        client.retain();
        client.retain();
        await client.release();
        expect(client.isConnected, isTrue);
        await client.release();
        expect(client.isConnected, isFalse);
        expect(harness.transport?.deactivated, isTrue);
      },
    );

    test(
      'notification subscribes and decodes notification and numeric badge',
      () async {
        final harness = _TransportHarness(_Activation.connect);
        final client = NotificationRealtimeClient(
          transportFactory: harness.create,
        );
        addTearDown(client.dispose);

        await client.connect(userId: 'user-2', token: 'token-2');
        await client.connect(userId: 'user-2', token: 'token-2');
        expect(harness.createCalls, 1);
        expect(harness.transport?.subscriptions.keys, <String>{
          '/topic/notifications/user-2',
          '/topic/notifications/user-2/badge',
        });

        final notification = client.notificationStream.first;
        final badge = client.badgeStream.first;
        harness.transport!.deliver(
          '/topic/notifications/user-2',
          jsonEncode(<String, dynamic>{
            'id': 'notification-1',
            'recipientId': 'user-2',
            'type': 'DM_MESSAGE',
            'title': 'New message',
            'message': 'Ada sent a message',
            'read': false,
            'createdAt': '2026-07-13T20:00:00Z',
            'payload': <String, dynamic>{'conversationId': 'conversation-1'},
          }),
        );
        harness.transport!.deliver('/topic/notifications/user-2/badge', '8.9');

        expect((await notification).id, 'notification-1');
        expect((await badge), 8);
      },
    );

    test(
      'table group decodes chat and sends the canonical application frame',
      () async {
        final harness = _TransportHarness(_Activation.connect);
        final client = TableGroupChatRealtimeClient(
          transportFactory: harness.create,
        );
        addTearDown(client.dispose);

        await client.connect(tableGroupId: 'group-1', token: 'token-3');
        await client.connect(tableGroupId: 'group-1', token: 'token-3');
        expect(harness.createCalls, 1);
        expect(client.connectedTableGroupId, 'group-1');
        expect(harness.transport?.subscriptions.keys, <String>{
          '/topic/table_group/group-1',
        });

        final message = client.messageStream.first;
        harness.transport!.deliver(
          '/topic/table_group/group-1',
          jsonEncode(<String, dynamic>{
            'messageId': 'group-message-1',
            'tableGroupId': 'group-1',
            'senderId': 'sender-1',
            'content': 'Merhaba',
            'messageType': 'TEXT',
            'sentAt': '2026-07-13T20:00:00Z',
          }),
        );
        expect((await message).content, 'Merhaba');

        client.send(
          tableGroupId: 'group-1',
          content: '  Keep exact spacing  ',
          messageType: 'SYSTEM',
        );
        expect(harness.transport?.sentFrames, hasLength(1));
        expect(
          harness.transport?.sentFrames.single.destination,
          '/app/table-group/group-1/chat',
        );
        expect(
          jsonDecode(harness.transport!.sentFrames.single.body),
          <String, dynamic>{
            'content': '  Keep exact spacing  ',
            'messageType': 'SYSTEM',
          },
        );

        await client.disconnect();
        client.send(tableGroupId: 'group-1', content: 'ignored');
        expect(harness.transport?.sentFrames, hasLength(1));
      },
    );
  });

  group('realtime payload validation', () {
    test('DM exposes invalid message payloads', () async {
      final harness = _TransportHarness(_Activation.connect);
      final client = DmRealtimeClient(transportFactory: harness.create);
      addTearDown(client.dispose);
      await client.connect(userId: 'u1', token: 'redacted');
      final error = client.errorStream.first;

      harness.transport!.deliver('/topic/dm/u1', '{invalid');

      expect((await error).type, RealtimeClientErrorType.invalidPayload);
    });

    test('notification exposes invalid badge payloads', () async {
      final harness = _TransportHarness(_Activation.connect);
      final client = NotificationRealtimeClient(
        transportFactory: harness.create,
      );
      addTearDown(client.dispose);
      await client.connect(userId: 'u1', token: 'redacted');
      final error = client.errorStream.first;

      harness.transport!.deliver(
        '/topic/notifications/u1/badge',
        'not-a-badge',
      );

      expect((await error).type, RealtimeClientErrorType.invalidPayload);
    });

    test('table-group exposes invalid message payloads', () async {
      final harness = _TransportHarness(_Activation.connect);
      final client = TableGroupChatRealtimeClient(
        transportFactory: harness.create,
      );
      addTearDown(client.dispose);
      await client.connect(tableGroupId: 'g1', token: 'redacted');
      final error = client.errorStream.first;

      harness.transport!.deliver('/topic/table_group/g1', '[]');

      expect((await error).type, RealtimeClientErrorType.invalidPayload);
    });
  });
}

enum _Activation { connect, transportError, protocolError, none }

class _TransportHarness {
  _TransportHarness(this.activation);

  final _Activation activation;
  _FakeRealtimeTransport? transport;
  int createCalls = 0;

  RealtimeTransport create(RealtimeTransportConfig config) {
    createCalls += 1;
    return transport = _FakeRealtimeTransport(config, activation);
  }
}

class _FakeRealtimeTransport implements RealtimeTransport {
  _FakeRealtimeTransport(this.config, this.activation);

  final RealtimeTransportConfig config;
  final _Activation activation;
  final Map<String, RealtimeMessageCallback> subscriptions =
      <String, RealtimeMessageCallback>{};
  bool deactivated = false;
  final List<_SentFrame> sentFrames = <_SentFrame>[];

  @override
  void activate() {
    switch (activation) {
      case _Activation.connect:
        config.onConnect();
        return;
      case _Activation.transportError:
        config.onTransportError();
        return;
      case _Activation.protocolError:
        config.onProtocolError();
        return;
      case _Activation.none:
        return;
    }
  }

  @override
  void deactivate() {
    deactivated = true;
  }

  void deliver(String destination, String body) {
    final callback = subscriptions[destination];
    if (callback == null) {
      throw StateError('Missing subscription: $destination');
    }
    callback(body);
  }

  @override
  void send({required String destination, required String body}) {
    sentFrames.add(_SentFrame(destination, body));
  }

  @override
  void subscribe({
    required String destination,
    required RealtimeMessageCallback callback,
  }) {
    subscriptions[destination] = callback;
  }
}

class _SentFrame {
  const _SentFrame(this.destination, this.body);

  final String destination;
  final String body;
}
