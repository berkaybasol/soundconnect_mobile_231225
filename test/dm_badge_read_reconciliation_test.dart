import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/push/push_coordinator.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/data/dm_realtime_client.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/dm_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/entities/dm_message.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_badge_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_chat_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/cubit/notification_cubit.dart';

import 'support/notification_counter_fakes.dart';
import 'support/event_audience_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final deliverBadge in [false, true]) {
    test('production DM ACK repairs badge, websocket=$deliverBadge', () async {
      final f = _Fixture();
      addTearDown(f.close);
      await f.start();
      await f.openChat();
      expect(f.badge.state.unreadCount, 1);
      final read = f.chat.acknowledgePresentedHistory([counterMessage]);
      await flushCounter();
      f.dm.deliverRead();
      if (deliverBadge) f.realtime.badges.add(0);
      await read;
      expect(f.chat.state.messages.single.readAt, isNotNull);
      expect(f.base.notifications.state.unreadCount, 2);
      expect(f.dm.unread, 0);
      expect(f.push.deliveredCalls, 1);
      expect(f.badge.state.unreadCount, 0);
      expect(f.dm.readCalls, [counterMessage]);
    });
  }

  test('production ACKs proceed while one shared badge count waits', () async {
    final f = _Fixture(messageCount: 3);
    addTearDown(f.close);
    await f.start();
    await f.openChat();
    final held = f.dm.holdCount();
    final ids = f.dm.messages.map((message) => message.messageId).toList();
    final reading = f.chat.acknowledgePresentedHistory(ids);
    await flushCounter();
    f.dm.deliverRead(ids[0]);
    await flushCounter();
    expect(held.snapshot, 2);
    expect(f.dm.readCalls, ids.take(2).toList());
    f.dm.deliverRead(ids[1]);
    await flushCounter();
    expect(f.dm.readCalls, ids);
    f.dm.deliverRead(ids[2]);
    await flushCounter();
    expect(f.dm.counts, [3, 2]);
    held.deliver();
    await reading;
    expect(f.dm.counts, [3, 2, 0]);
    expect(f.dm.maxActiveCounts, 1);
    expect(f.badge.state.unreadCount, 0);
    expect(f.dm.readCalls, ids);
  });

  test('ACK during a resume seed rejects the pre-read snapshot', () async {
    final f = _Fixture();
    addTearDown(f.close);
    await f.start();
    await f.openChat();
    final held = f.dm.holdCount();
    final resume = f.badge.reconcileAfterResume();
    await flushCounter();
    expect(held.snapshot, 1);
    final read = f.chat.acknowledgePresentedHistory([counterMessage]);
    await flushCounter();
    f.dm.deliverRead();
    await flushCounter();
    expect(f.dm.counts, [1, 1]);
    held.deliver();
    await Future.wait([read, resume]);
    expect(f.dm.counts, [1, 1, 0]);
    expect(f.dm.maxActiveCounts, 1);
    expect(f.badge.state.unreadCount, 0);
  });

  test(
    'late pre-ACK WS badge cannot overwrite an accepted post-read count',
    () async {
      final f = _Fixture();
      addTearDown(f.close);
      await f.start();
      await f.openChat();
      // Server's earlier WS count1 is retained while the exact local read commits.
      final read = f.chat.acknowledgePresentedHistory([counterMessage]);
      await flushCounter();
      f.dm.deliverRead();
      await read;
      expect(f.badge.state.unreadCount, 0);
      f.realtime.badges.add(1);
      await flushCounter();
      expect(
        f.badge.state.unreadCount,
        0,
        reason:
            'Unversioned delayed WS is not proof that a new unread was created.',
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(f.badge.state.unreadCount, 0);
      expect(f.dm.counts, [1, 0, 0]);
    },
  );

  test('first local ACK starts an uninitialized badge only once', () async {
    final f = _Fixture();
    addTearDown(f.close);
    await f.start(seedBadge: false);
    await f.openChat();
    final held = f.dm.holdCount();
    final read = f.chat.acknowledgePresentedHistory([counterMessage]);
    await flushCounter();
    f.dm.deliverRead();
    await flushCounter();
    final duplicateStart = f.badge.ensureStarted();
    expect(held.snapshot, 0);
    held.deliver();
    await Future.wait([read, duplicateStart]);
    expect(f.dm.counts, [0]);
    expect(f.badge.state.unreadCount, 0);
    expect(f.badge.state.initialized, isTrue);
  });

  test(
    'post-read WS burst coalesces and still accepts real new unread total',
    () async {
      final f = _Fixture();
      addTearDown(f.close);
      await f.start();
      await f.openChat();
      final read = f.chat.acknowledgePresentedHistory([counterMessage]);
      await flushCounter();
      f.dm.deliverRead();
      await read;
      expect(f.badge.state.unreadCount, 0);
      f.dm.unreadOverride = 4;
      for (var index = 0; index < 40; index++) {
        f.realtime.badges.add(4);
      }
      await flushCounter();
      expect(f.dm.counts, [1, 0]);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(f.dm.counts, [1, 0, 4]);
      expect(f.badge.state.unreadCount, 4);
      expect(f.dm.readCalls, [counterMessage]);
    },
  );

  test(
    'read during initial badge seed shares it and requires a later count',
    () async {
      final f = _Fixture();
      addTearDown(f.close);
      await f.start(seedBadge: false);
      await f.openChat();
      final held = f.dm.holdCount();
      final startup = f.badge.ensureStarted();
      await flushCounter();
      expect(held.snapshot, 1);
      final read = f.chat.acknowledgePresentedHistory([counterMessage]);
      await flushCounter();
      f.dm.deliverRead();
      await flushCounter();
      expect(f.dm.counts, [1]);
      held.deliver();
      await Future.wait([read, startup]);
      expect(f.dm.counts, [1, 0]);
      expect(f.dm.maxActiveCounts, 1);
      expect(f.badge.state.unreadCount, 0);
    },
  );

  for (final failure in ['result', 'throw']) {
    test(
      'badge $failure preserves retry debt without repeating domain ACK',
      () async {
        final f = _Fixture();
        addTearDown(f.close);
        await f.start();
        await f.openChat();
        final held = f.dm.holdCount();
        final read = f.chat.acknowledgePresentedHistory([counterMessage]);
        await flushCounter();
        f.dm.deliverRead();
        await flushCounter();
        if (failure == 'throw') {
          held.throwError();
        } else {
          held.fail();
        }
        await read;
        expect(f.chat.state.messages.single.readAt, isNotNull);
        expect(f.badge.state.unreadCount, 1);
        expect(f.dm.counts, [1, 0]);
        // The already-connected/initialized owner must retain this repair debt.
        await f.badge.ensureStarted();
        expect(f.badge.state.unreadCount, 0);
        expect(f.dm.counts, [1, 0, 0]);
        expect(f.dm.readCalls, [counterMessage]);
      },
    );
  }

  test(
    'synchronous count failure cannot leave a completed flight stuck',
    () async {
      final f = _Fixture();
      addTearDown(f.close);
      await f.start();
      await f.openChat();
      f.dm.throwNextCountSynchronously = true;
      final read = f.chat.acknowledgePresentedHistory([counterMessage]);
      await flushCounter();
      f.dm.deliverRead();
      await read;
      expect(f.dm.counts, [1, 0]);
      expect(f.badge.state.unreadCount, 1);
      await f.badge.ensureStarted();
      expect(f.dm.counts, [1, 0, 0]);
      expect(f.badge.state.unreadCount, 0);
      expect(f.dm.readCalls, [counterMessage]);
    },
  );

  test(
    'count timeout releases read projection; late result cannot win a resume',
    () async {
      final f = _Fixture(timeout: const Duration(milliseconds: 25));
      addTearDown(f.close);
      await f.start();
      await f.openChat();
      final held = f.dm.holdCount();
      final read = f.chat.acknowledgePresentedHistory([counterMessage]);
      await flushCounter();
      f.dm.deliverRead();
      await read;
      expect(f.chat.state.messages.single.readAt, isNotNull);
      expect(f.badge.state.unreadCount, 1);
      f.dm.unreadOverride = 4;
      await f.badge.reconcileAfterResume();
      expect(f.badge.state.unreadCount, 4);
      held.deliver();
      await flushCounter();
      expect(f.badge.state.unreadCount, 4);
      expect(f.dm.readCalls, [counterMessage]);
    },
  );

  test(
    'WS contention alone gets at most one follow-up; resume keeps repair debt',
    () async {
      final f = _Fixture();
      addTearDown(f.close);
      await f.start();
      await f.openChat();
      final first = f.dm.holdCount();
      final second = f.dm.holdCount();
      final read = f.chat.acknowledgePresentedHistory([counterMessage]);
      await flushCounter();
      f.dm.deliverRead();
      await flushCounter();
      for (var count = 2; count < 20; count++) {
        f.realtime.badges.add(count);
      }
      await flushCounter();
      first.deliver();
      await flushCounter();
      expect(second.snapshot, 0);
      for (var count = 20; count < 40; count++) {
        f.realtime.badges.add(count);
      }
      await flushCounter();
      second.deliver();
      await read;
      expect(f.dm.counts, [1, 0, 0]);
      expect(
        f.badge.state.unreadCount,
        1,
        reason:
            'Post-read unversioned frames cannot replace the verified count.',
      );
      await f.badge.reconcileAfterResume();
      expect(f.badge.state.unreadCount, 0);
      expect(f.dm.readCalls, [counterMessage]);
    },
  );

  testWidgets(
    'post-read sustained WS frames cannot postpone the fixed count window',
    (tester) async {
      final f = _Fixture();
      addTearDown(f.close);
      await f.start();
      await f.openChat();
      final read = f.chat.acknowledgePresentedHistory([counterMessage]);
      await tester.pump();
      f.dm.deliverRead();
      await tester.pump();
      await read;
      f.dm.unreadOverride = 2;
      for (var index = 0; index < 4; index++) {
        f.realtime.badges.add(2);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
      }
      // Frames at0/100/200/300ms cannot push the first250ms count to550ms.
      expect(f.dm.counts, [1, 0, 2]);
      expect(f.badge.state.unreadCount, 2);
      // The frame at 300ms starts the next window after the first completed.
      // Drain that window before the widget binding checks pending timers.
      await tester.pump(const Duration(milliseconds: 250));
      expect(f.dm.counts, [1, 0, 2, 2]);
      await tester.pump(const Duration(seconds: 1));
      expect(f.dm.counts, [1, 0, 2, 2]);
    },
  );

  testWidgets('exhausted count flight leaves no trailing WS timer request', (
    tester,
  ) async {
    final f = _Fixture();
    addTearDown(f.close);
    await f.start();
    await f.openChat();
    final first = f.dm.holdCount();
    final second = f.dm.holdCount();
    final read = f.chat.acknowledgePresentedHistory([counterMessage]);
    await tester.pump();
    f.dm.deliverRead();
    await tester.pump();
    f.realtime.badges.add(9);
    await tester.pump();
    first.deliver();
    await tester.pump();
    expect(second.snapshot, 0);
    f.realtime.badges.add(8);
    await tester.pump();
    second.deliver();
    await tester.pump();
    await read;
    expect(f.dm.counts, [1, 0, 0]);
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      f.dm.counts,
      [1, 0, 0],
      reason:
          'Frames already handled by a bounded flight cannot create an orphan third request.',
    );
    await f.badge.reconcileAfterResume();
    expect(f.badge.state.unreadCount, 0);
    expect(f.dm.readCalls, [counterMessage]);
  });

  for (final sameUser in [false, true]) {
    test(
      'retired pending ACK cannot repair new session, sameUser=$sameUser',
      () async {
        final f = _Fixture();
        addTearDown(f.close);
        await f.start();
        await f.openChat();
        final read = f.chat.acknowledgePresentedHistory([counterMessage]);
        await flushCounter();
        f.base.sessions.replace(const AuthSession.guest());
        f.dm.unreadOverride = 7;
        f.base.sessions.replace(
          audienceSession(
            user: sameUser ? counterOwner : counterOtherOwner,
            token: 'replacement-session',
            role: 'ROLE_MUSICIAN',
          ),
        );
        await flushCounter();
        await f.badge.ensureStarted();
        expect(f.badge.state.unreadCount, 7);
        final countsBeforeAck = f.dm.counts.length;
        f.dm.deliverRead();
        await read;
        expect(f.push.deliveredCalls, 0);
        expect(f.dm.counts.length, countsBeforeAck);
        expect(f.badge.state.unreadCount, 7);
      },
    );
  }

  test(
    'logout cancels held count and its late response cannot replace new owner',
    () async {
      final f = _Fixture();
      addTearDown(f.close);
      await f.start();
      await f.openChat();
      final held = f.dm.holdCount();
      final read = f.chat.acknowledgePresentedHistory([counterMessage]);
      await flushCounter();
      f.dm.deliverRead();
      await flushCounter();
      expect(held.snapshot, 0);
      f.base.sessions.replace(const AuthSession.guest());
      await read;
      f.dm.unreadOverride = 8;
      f.base.sessions.replace(
        audienceSession(
          user: counterOtherOwner,
          token: 'new-owner',
          role: 'ROLE_MUSICIAN',
        ),
      );
      await flushCounter();
      await f.badge.ensureStarted();
      expect(f.badge.state.unreadCount, 8);
      held.deliver();
      await flushCounter();
      expect(f.badge.state.unreadCount, 8);
      expect(f.dm.readCalls, [counterMessage]);
    },
  );
}

class _Fixture {
  _Fixture({int messageCount = 1, this.timeout}) {
    if (messageCount > 1) {
      base.repository.rows.clear();
      dm.messages.clear();
      for (var index = 0; index < messageCount; index++) {
        final id = 'dm-read-$index';
        base.repository.rows.add(
          counterNotification('notification-$index', messageId: id),
        );
        dm.messages.add(
          DmMessage(
            messageId: id,
            conversationId: counterConversation,
            senderId: 'counter-sender',
            recipientId: counterOwner,
            content: 'Visible message $index',
            messageType: 'text',
            sentAt: DateTime.utc(2026, 10, 7, 0, 0, index),
            readAt: null,
            deletedAt: null,
          ),
        );
      }
    }
  }
  final base = CounterFixture();
  late final dm = _DmRepository(base.repository);
  final realtime = _Realtime();
  final push = _Push();
  final Duration? timeout;
  late DmBadgeCubit badge;
  late DmChatCubit chat;

  Future<void> start({bool seedBadge = true}) async {
    await serviceLocator.reset();
    setupDependencies();
    await _replace<TokenStore>(_Tokens(base));
    await _replace<AuthSessionManager>(base.sessions);
    await _replace<DmRepository>(dm);
    await _replace<DmRealtimeClient>(realtime);
    await _replace<NotificationCubit>(base.notifications);
    await _replace<PushCoordinator>(push);
    if (timeout != null) {
      await _replace<DmBadgeCubit>(
        DmBadgeCubit(
          dm,
          serviceLocator<TokenStore>(),
          realtimeClient: realtime,
          sessions: base.sessions,
          countReconciliationTimeout: timeout!,
        ),
      );
    }
    // Resolve the actual production factories: the read callback is never copied.
    badge = serviceLocator<DmBadgeCubit>();
    chat = serviceLocator<DmChatCubit>();
    await base.start();
    if (seedBadge) await badge.ensureStarted();
  }

  Future<void> openChat() async {
    chat.requirePresentedHistory();
    chat.setVisible(true);
    await chat.openOrCreateConversation(
      otherUserId: 'counter-sender',
      currentUserId: counterOwner,
    );
    expect(dm.readCalls, isEmpty);
  }

  Future<void> close() async {
    await chat.close();
    await badge.close();
    await realtime.dispose();
    await base.dispose();
    await serviceLocator.reset();
  }
}

Future<void> _replace<T extends Object>(T value) async {
  await serviceLocator.unregister<T>();
  serviceLocator.registerSingleton<T>(value);
}

class _Tokens extends Fake implements TokenStore {
  _Tokens(this.fixture);
  final CounterFixture fixture;
  @override
  Future<String?> readToken() async =>
      'x.${base64Url.encode(utf8.encode(jsonEncode({'sub': fixture.sessions.session.userId})))}.x';
}

class _Realtime extends CounterDmRealtime {
  final badges = StreamController<int>.broadcast();
  @override
  Stream<int> get badgeStream => badges.stream;
  @override
  Future<void> dispose() async {
    await badges.close();
    await super.dispose();
  }
}

class _DmRepository extends CounterDmRepository {
  _DmRepository(super.notifications);
  final counts = <int>[];
  final heldCounts = Queue<HeldCounterResponse>();
  int activeCounts = 0;
  int maxActiveCounts = 0;
  int? unreadOverride;
  bool throwNextCountSynchronously = false;
  int get unread =>
      unreadOverride ??
      notifications.rows
          .where((n) => n.type == 'DM_NEW_MESSAGE' && !n.read)
          .length;
  HeldCounterResponse holdCount() {
    final held = HeldCounterResponse();
    heldCounts.add(held);
    return held;
  }

  @override
  Future<Result<int>> getUnreadCount() {
    if (throwNextCountSynchronously) {
      throwNextCountSynchronously = false;
      counts.add(unread);
      throw StateError('synchronous count transport');
    }
    return _getUnreadCount();
  }

  Future<Result<int>> _getUnreadCount() async {
    final snapshot = unread;
    counts.add(snapshot);
    activeCounts++;
    if (activeCounts > maxActiveCounts) maxActiveCounts = activeCounts;
    try {
      if (heldCounts.isNotEmpty) {
        final held = heldCounts.removeFirst()..snapshot = snapshot;
        return await held.response.future;
      }
      return Result.success(snapshot);
    } finally {
      activeCounts--;
    }
  }
}

class _Push extends Fake implements PushCoordinator {
  int deliveredCalls = 0;
  @override
  Future<void> reconcileDelivered() async {
    deliveredCalls++;
  }

  @override
  void dispose() {}
}
