import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/realtime/realtime_client_error.dart';
import 'package:soundconnect_23_12_25codx/core/realtime/stomp_realtime_transport.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/data/table_group_chat_realtime_client.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/domain/entities/table_group_message.dart';

void main() {
  group('TableGroupChatRealtimeClient', () {
    test(
      'reconnects, validates group identity, and reports connection state',
      () async {
        final harness = _TransportHarness(<_Activation>[_Activation.connect]);
        final client = TableGroupChatRealtimeClient(
          transportFactory: harness.create,
        );
        addTearDown(client.dispose);
        var connections = 0;
        final connectionSubscription = client.connectionStream.listen(
          (_) => connections += 1,
        );
        addTearDown(connectionSubscription.cancel);

        await client.connect(tableGroupId: 'group-1', token: 'redacted');
        await Future<void>.delayed(Duration.zero);
        expect(connections, 1);

        final errorFuture = client.errorStream.first;
        harness.latest.deliver(
          '/topic/table-group.group-1',
          _messageJson(tableGroupId: 'other-group'),
        );
        expect(
          (await errorFuture).type,
          RealtimeClientErrorType.invalidPayload,
        );

        final disconnectError = client.errorStream.first;
        harness.latest.config.onSocketDone!.call();
        expect(
          (await disconnectError).type,
          RealtimeClientErrorType.disconnected,
        );
        harness.latest.config.onConnect();
        await Future<void>.delayed(Duration.zero);

        expect(client.isConnected, isTrue);
        expect(client.connectedTableGroupId, 'group-1');
        expect(connections, 2);
      },
    );

    test(
      'drops delayed frames from a previous table-group transport',
      () async {
        final harness = _TransportHarness(<_Activation>[
          _Activation.connect,
          _Activation.connect,
        ]);
        final client = TableGroupChatRealtimeClient(
          transportFactory: harness.create,
        );
        addTearDown(client.dispose);
        final received = <TableGroupMessage>[];
        final subscription = client.messageStream.listen(received.add);
        addTearDown(subscription.cancel);

        await client.connect(tableGroupId: 'group-1', token: 'token-1');
        final oldTransport = harness.latest;
        await client.connect(tableGroupId: 'group-2', token: 'token-2');

        oldTransport.deliver(
          '/topic/table-group.group-1',
          _messageJson(tableGroupId: 'group-1', messageId: 'stale'),
        );
        harness.latest.deliver(
          '/topic/table-group.group-2',
          _messageJson(tableGroupId: 'group-2', messageId: 'current'),
        );
        await Future<void>.delayed(Duration.zero);

        expect(received.map((message) => message.messageId), <String>[
          'current',
        ]);
        expect(received.single.sentAt?.isUtc, isTrue);
        expect(harness.latest.sentDestinations, isEmpty);
      },
    );

    test(
      'intentional disconnect ignores every callback from the old transport',
      () async {
        final harness = _TransportHarness(<_Activation>[_Activation.connect]);
        final client = TableGroupChatRealtimeClient(
          transportFactory: harness.create,
        );
        addTearDown(client.dispose);
        final errors = <RealtimeClientError>[];
        final messages = <TableGroupMessage>[];
        var connectionEvents = 0;
        final errorSubscription = client.errorStream.listen(errors.add);
        final messageSubscription = client.messageStream.listen(messages.add);
        final connectionSubscription = client.connectionStream.listen(
          (_) => connectionEvents += 1,
        );
        addTearDown(errorSubscription.cancel);
        addTearDown(messageSubscription.cancel);
        addTearDown(connectionSubscription.cancel);

        await client.connect(tableGroupId: 'group-1', token: 'token-1');
        await Future<void>.delayed(Duration.zero);
        final oldTransport = harness.latest;

        await client.disconnect();
        expect(oldTransport.deactivated, isTrue);

        oldTransport.config.onConnect();
        oldTransport.config.onProtocolError();
        oldTransport.config.onTransportError();
        oldTransport.config.onDisconnect();
        oldTransport.config.onSocketDone!.call();
        oldTransport.deliver(
          '/topic/table-group.group-1',
          _messageJson(tableGroupId: 'group-1', messageId: 'stale'),
        );
        await Future<void>.delayed(Duration.zero);

        expect(client.isConnected, isFalse);
        expect(client.connectedTableGroupId, isNull);
        expect(connectionEvents, 1);
        expect(errors, isEmpty);
        expect(messages, isEmpty);
        expect(harness.transports, hasLength(1));
        expect(oldTransport.activateCalls, 1);
      },
    );

    test('starts a new group after a pending handshake is cancelled', () async {
      final harness = _TransportHarness(<_Activation>[
        _Activation.none,
        _Activation.connect,
      ]);
      final client = TableGroupChatRealtimeClient(
        transportFactory: harness.create,
      );
      addTearDown(client.dispose);

      final firstConnect = client.connect(
        tableGroupId: 'group-1',
        token: 'token-1',
      );
      final firstFailure = expectLater(
        firstConnect,
        throwsA(isA<RealtimeClientError>()),
      );
      await _eventually(() => harness.transports.length == 1);

      final disconnect = client.disconnect();
      final secondConnect = client.connect(
        tableGroupId: 'group-2',
        token: 'token-2',
      );
      await disconnect;
      await Future.wait<void>(<Future<void>>[firstFailure, secondConnect]);

      expect(client.isConnected, isTrue);
      expect(client.connectedTableGroupId, 'group-2');
      expect(harness.transports, hasLength(2));
    });

    test('screen-scoped clients keep independent group ownership', () async {
      final firstHarness = _TransportHarness(<_Activation>[
        _Activation.connect,
      ]);
      final secondHarness = _TransportHarness(<_Activation>[
        _Activation.connect,
      ]);
      final firstClient = TableGroupChatRealtimeClient(
        transportFactory: firstHarness.create,
      );
      final secondClient = TableGroupChatRealtimeClient(
        transportFactory: secondHarness.create,
      );
      addTearDown(firstClient.dispose);
      addTearDown(secondClient.dispose);

      await firstClient.connect(tableGroupId: 'group-a', token: 'token-a');
      await secondClient.connect(tableGroupId: 'group-b', token: 'token-b');
      await secondClient.disconnect();

      expect(firstClient.isConnected, isTrue);
      expect(firstClient.connectedTableGroupId, 'group-a');
      expect(secondClient.isConnected, isFalse);
    });
  });
}

String _messageJson({
  required String tableGroupId,
  String messageId = 'message-1',
}) {
  return jsonEncode(<String, dynamic>{
    'messageId': messageId,
    'tableGroupId': tableGroupId,
    'senderId': 'sender-1',
    'clientMessageId': 'client-$messageId',
    'content': 'Merhaba',
    'messageType': 'TEXT',
    'sentAt': '2026-07-14T20:00:00Z',
  });
}

enum _Activation { connect, none }

class _TransportHarness {
  _TransportHarness(this.activations);

  final List<_Activation> activations;
  final List<_FakeRealtimeTransport> transports = <_FakeRealtimeTransport>[];

  _FakeRealtimeTransport get latest => transports.last;

  RealtimeTransport create(RealtimeTransportConfig config) {
    final index = transports.length;
    final activation = index < activations.length
        ? activations[index]
        : _Activation.connect;
    final transport = _FakeRealtimeTransport(config, activation);
    transports.add(transport);
    return transport;
  }
}

class _FakeRealtimeTransport implements RealtimeTransport {
  _FakeRealtimeTransport(this.config, this.activation);

  final RealtimeTransportConfig config;
  final _Activation activation;
  final Map<String, RealtimeMessageCallback> subscriptions =
      <String, RealtimeMessageCallback>{};
  final List<String> sentDestinations = <String>[];
  final List<String> sentBodies = <String>[];
  bool deactivated = false;
  int activateCalls = 0;

  @override
  void activate() {
    activateCalls += 1;
    if (activation == _Activation.connect) config.onConnect();
  }

  @override
  void deactivate() {
    deactivated = true;
  }

  void deliver(String destination, String body) {
    final callback = subscriptions[destination];
    if (callback == null) throw StateError('Missing $destination subscription');
    callback(body);
  }

  @override
  void send({required String destination, required String body}) {
    sentDestinations.add(destination);
    sentBodies.add(body);
  }

  @override
  void subscribe({
    required String destination,
    required RealtimeMessageCallback callback,
  }) {
    subscriptions[destination] = callback;
  }
}

Future<void> _eventually(bool Function() predicate) async {
  for (var attempt = 0; attempt < 100; attempt += 1) {
    if (predicate()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(predicate(), isTrue);
}
