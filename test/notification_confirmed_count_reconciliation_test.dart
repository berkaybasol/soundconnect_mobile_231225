import 'dart:async';

import 'package:flutter/material.dart' hide Page;
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/pagination/page.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/entities/dm_message.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_chat_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/dm_chat_route_observer.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/screens/dm_chat_screen.dart';

import 'support/event_audience_fakes.dart';
import 'support/notification_counter_fakes.dart';

Future<void> _scenario(
  Future<void> Function(CounterFixture) body, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final fixture = CounterFixture(timeout: timeout);
  try {
    await fixture.start();
    await body(fixture);
  } finally {
    await fixture.dispose();
  }
}

void main() {
  for (final countFirst in [true, false]) {
    test(
      'external ACK and DELETE countFirst=$countFirst reconcile both commits',
      () => _scenario((f) async {
        final held = f.repository.holdNextCount();
        final read = f.confirmExternal('a');
        expect(f.notifications.state.items.first.read, isTrue);
        await flushCounter();
        expect(held.snapshot, 2);
        if (countFirst) {
          held.deliver();
          await read;
        }
        final deletion = f.notifications.deleteNotification(f.row('b'));
        f.repository.completeDelete('b');
        await flushCounter();
        if (!countFirst) held.deliver();
        await Future.wait([read, deletion]);
        expect(f.repository.unread, 1);
        expect(f.notifications.state.unreadCount, 1);
        expect(f.notifications.state.items.map((n) => n.id), ['a', 'c']);
        expect(f.notifications.state.items.last.read, isFalse);
        expect(f.repository.deleteCalls, ['b']);
        expect(
          f.repository.readCalls,
          isEmpty,
          reason: 'Count repair never sends another domain ACK.',
        );
        expect(f.repository.pages, [0]);
      }),
    );

    test(
      'external ACK and realtime arrival countFirst=$countFirst preserve new unread',
      () => _scenario((f) async {
        final held = f.repository.holdNextCount();
        final read = f.confirmExternal('a');
        await flushCounter();
        if (countFirst) {
          held.deliver();
          await read;
        }
        final arrival = counterNotification('arrival');
        f.repository.rows.insert(0, arrival);
        f.realtime.notifications.add(arrival);
        await flushCounter();
        if (!countFirst) held.deliver();
        await read;
        expect(f.notifications.state.unreadCount, 3);
        expect(f.repository.unread, 3);
        expect(
          f.notifications.state.items.where((n) => !n.read).map((n) => n.id),
          ['arrival', 'b', 'c'],
        );
        expect(f.repository.pages, [0]);
      }),
    );
  }

  for (final dmFirst in [true, false]) {
    for (final otherOperation in ['delete', 'external']) {
      test(
        'presented DM and $otherOperation dmFirst=$dmFirst do not subtract twice',
        () => _scenario((f) async {
          Future<void>? deletion;
          if (otherOperation == 'delete') {
            deletion = f.notifications.deleteNotification(f.row('b'));
            // Establish a newer server snapshot while B's DELETE is outstanding.
            await f.notifications.refresh();
          }
          await f.loadChat();
          final presented = f.chat.acknowledgePresentedHistory([
            counterMessage,
          ]);
          await flushCounter();
          expect(f.dmRepository.readCalls, [counterMessage]);
          expect(
            f.row('a').read,
            isTrue,
            reason: 'The server transaction commits before HTTP delivery.',
          );
          expect(f.notifications.state.items.first.read, isFalse);
          if (dmFirst) {
            f.dmRepository.deliverRead();
            await presented;
            await flushCounter();
          }
          if (otherOperation == 'delete') {
            f.repository.completeDelete('b');
            await deletion;
          } else {
            await f.confirmExternal('b');
          }
          if (!dmFirst) {
            expect(f.notifications.state.unreadCount, 1);
            f.dmRepository.deliverRead();
            await presented;
          }
          await flushCounter();
          expect(f.chat.state.messages.single.readAt, isNotNull);
          expect(
            f.notifications.state.items.where((n) => !n.read).map((n) => n.id),
            ['c'],
          );
          expect(f.notifications.state.unreadCount, 1);
          expect(f.repository.unread, 1);
          expect(f.dmRepository.readCalls, [counterMessage]);
        }),
      );
    }
  }

  for (final offPage in [false, true]) {
    test(
      'DM read offPage=$offPage repairs global count without loading more',
      () async {
        final dm = counterNotification('a', messageId: counterMessage);
        final siblings = List.generate(
          20,
          (i) => counterNotification('sibling-$i'),
        );
        final f = CounterFixture(
          rows: [if (!offPage) dm, ...siblings, if (offPage) dm],
        );
        try {
          await f.start();
          expect(f.notifications.state.items, hasLength(20));
          expect(f.notifications.state.items.any((n) => n.id == 'a'), !offPage);
          expect(f.notifications.state.unreadCount, 21);
          await f.loadChat();
          final shown = f.chat.acknowledgePresentedHistory([counterMessage]);
          f.dmRepository.deliverRead();
          await shown;
          await flushCounter();
          expect(f.notifications.state.unreadCount, 20);
          expect(f.repository.unread, 20);
          expect(f.repository.pages, [0]);
          expect(
            f.repository.rows.where((n) => !n.read).map((n) => n.id),
            siblings.map((n) => n.id),
          );
        } finally {
          await f.dispose();
        }
      },
    );
  }

  test(
    'off-page confirmed DM stays read through stale page refresh and realtime',
    () async {
      final dm = counterNotification('a', messageId: counterMessage);
      final f = CounterFixture(
        rows: [
          ...List.generate(20, (i) => counterNotification('sibling-$i')),
          dm,
        ],
      );
      try {
        await f.start();
        f.repository.commitMessageRead(counterMessage);
        f.notifications.markDmMessageAsReadLocally(counterMessage);
        await flushCounter();
        expect(f.notifications.state.unreadCount, 20);
        f.repository.stalePages[1] = [dm];
        await f.notifications.loadMore();
        expect(
          f.notifications.state.items.singleWhere((n) => n.id == 'a').read,
          isTrue,
        );
        await f.notifications.refresh();
        expect(f.notifications.state.items.any((n) => n.id == 'a'), isFalse);
        f.realtime.notifications.add(dm);
        await flushCounter();
        expect(f.notifications.state.items.first.read, isTrue);
        expect(f.notifications.state.unreadCount, 20);
        expect(f.repository.rows.where((n) => !n.read), hasLength(20));
      } finally {
        await f.dispose();
      }
    },
  );

  test(
    'duplicate read callbacks share pending count without duplicate decrement',
    () => _scenario((f) async {
      final held = f.repository.holdNextCount();
      final first = f.confirmExternal('a');
      final duplicate = f.notifications.applyConfirmedExternalRead(
        f.row('a'),
        f.sessions.session,
      );
      f.notifications.markDmMessageAsReadLocally(counterMessage);
      f.notifications.markDmMessageAsReadLocally(counterMessage);
      await flushCounter();
      expect(f.repository.counts, hasLength(2));
      expect(f.repository.activeCounts, 1);
      held.deliver();
      await Future.wait([first, duplicate]);
      await flushCounter();
      final after = f.repository.counts.length;
      await f.notifications.markDmMessageAsReadLocally(counterMessage);
      expect(
        f.repository.counts.length,
        after,
        reason: 'A confirmed message receipt has already reconciled its count.',
      );
      await f.notifications.applyConfirmedExternalRead(
        f.row('a'),
        f.sessions.session,
      );
      f.notifications.markDmMessageAsReadLocally(counterMessage);
      await flushCounter();
      expect(
        f.repository.counts.length,
        after + 1,
        reason:
            'An external read may refresh count for an already-read row; '
            'the row projection alone is not a successful count snapshot.',
      );
      expect(f.repository.maxActiveCounts, 1);
      expect(f.notifications.state.unreadCount, 2);
    }),
  );

  test(
    'external read repairs count even when refresh already observed a read row',
    () => _scenario((f) async {
      f.repository.commitRead('a');
      final held = f.repository.holdNextCount();
      final refresh = f.notifications.refresh();
      held.fail();
      await refresh;
      expect(f.notifications.state.items.first.read, isTrue);
      expect(f.notifications.state.unreadCount, 3);
      await f.confirmExternal('a');
      expect(f.notifications.state.unreadCount, 2);
      expect(f.repository.readCalls, isEmpty);
    }),
  );

  test(
    'presented message batch continues ACKs while sharing one pending count',
    () => _scenario((f) async {
      final ids = List.generate(3, (index) => 'message-$index');
      f.repository.rows
        ..clear()
        ..addAll([
          ...ids.map(
            (id) => counterNotification('notification-$id', messageId: id),
          ),
          counterNotification('unrelated'),
        ]);
      f.dmRepository.messages
        ..clear()
        ..addAll(
          ids.map(
            (id) => DmMessage(
              messageId: id,
              conversationId: counterConversation,
              senderId: 'counter-sender',
              recipientId: counterOwner,
              content: id,
              messageType: 'text',
              sentAt: DateTime.utc(2026, 10, 7),
              readAt: null,
              deletedAt: null,
            ),
          ),
        );
      await f.notifications.refresh();
      await f.loadChat();
      final startCounts = f.repository.counts.length;
      final held = f.repository.holdNextCount();
      final shown = f.chat.acknowledgePresentedHistory(ids);
      for (var index = 0; index < ids.length; index++) {
        await flushCounter();
        expect(
          f.dmRepository.pendingReads,
          hasLength(1),
          reason:
              'A pending count must not block the next presented message ACK.',
        );
        f.dmRepository.deliverRead(f.dmRepository.pendingReads.keys.single);
      }
      await flushCounter();
      expect(f.dmRepository.readCalls.toSet(), ids.toSet());
      expect(f.dmRepository.readCalls, hasLength(3));
      expect(f.repository.counts.length, startCounts + 1);
      expect(
        f.chat.state.messages.every((message) => message.readAt != null),
        isTrue,
      );
      held.deliver();
      await shown;
      expect(f.repository.counts.length, startCounts + 2);
      expect(f.repository.maxActiveCounts, 1);
      expect(f.notifications.state.unreadCount, 1);
      expect(
        f.notifications.state.items.where((n) => !n.read).single.id,
        'unrelated',
      );
    }),
  );

  test(
    'DM count transport error does not fail or repeat successful message ACK',
    () => _scenario((f) async {
      await f.loadChat();
      final held = f.repository.holdNextCount();
      final shown = f.chat.acknowledgePresentedHistory([counterMessage]);
      f.dmRepository.deliverRead();
      await flushCounter();
      held.throwError();
      await shown;
      expect(f.chat.state.messages.single.readAt, isNotNull);
      expect(f.chat.state.error, isNull);
      expect(f.notifications.state.items.first.read, isTrue);
      expect(f.notifications.state.unreadCount, 3);
      await f.notifications.markDmMessageAsReadLocally(counterMessage);
      expect(f.notifications.state.unreadCount, 2);
      expect(f.dmRepository.readCalls, [counterMessage]);
      expect(f.repository.pages, [0]);
    }),
  );

  test(
    'DM count timeout finishes presentation and existing refresh repairs debt',
    () => _scenario((f) async {
      await f.loadChat();
      final held = f.repository.holdNextCount();
      final shown = f.chat.acknowledgePresentedHistory([counterMessage]);
      f.dmRepository.deliverRead();
      await shown.timeout(const Duration(seconds: 1));
      expect(f.chat.state.messages.single.readAt, isNotNull);
      expect(f.notifications.state.items.first.read, isTrue);
      expect(f.notifications.state.unreadCount, 3);
      held.throwError();
      await flushCounter();
      await f.notifications.refresh();
      expect(f.notifications.state.unreadCount, 2);
      expect(f.dmRepository.readCalls, [counterMessage]);
    }, timeout: const Duration(milliseconds: 15)),
  );

  test(
    'last DM ACK during second count still completes finite message batch',
    () => _scenario((f) async {
      final ids = ['message-a', 'message-b', 'message-c'];
      f.repository.rows
        ..clear()
        ..addAll(
          ids.map(
            (id) => counterNotification('notification-$id', messageId: id),
          ),
        );
      f.dmRepository.messages
        ..clear()
        ..addAll(
          ids.map(
            (id) => DmMessage(
              messageId: id,
              conversationId: counterConversation,
              senderId: 'counter-sender',
              recipientId: counterOwner,
              content: id,
              messageType: 'text',
              sentAt: DateTime.utc(2026, 10, 7),
              readAt: null,
              deletedAt: null,
            ),
          ),
        );
      await f.notifications.refresh();
      await f.loadChat();
      final countBefore = f.repository.counts.length;
      final first = f.repository.holdNextCount();
      final second = f.repository.holdNextCount();
      final shown = f.chat.acknowledgePresentedHistory(ids);
      f.dmRepository.deliverRead(f.dmRepository.pendingReads.keys.single);
      await flushCounter();
      expect(first.snapshot, 2);
      f.dmRepository.deliverRead(f.dmRepository.pendingReads.keys.single);
      await flushCounter();
      first.deliver();
      await flushCounter();
      expect(
        second.snapshot,
        0,
        reason:
            'The next message read commits before its HTTP response is delivered.',
      );
      f.dmRepository.deliverRead(f.dmRepository.pendingReads.keys.single);
      await flushCounter();
      second.deliver();
      await shown;
      expect(
        f.chat.state.messages.every((message) => message.readAt != null),
        isTrue,
      );
      expect(f.notifications.state.items.every((item) => item.read), isTrue);
      expect(f.notifications.state.unreadCount, 0);
      expect(f.repository.unread, 0);
      expect(f.repository.counts.length - countBefore, lessThanOrEqualTo(4));
      expect(f.repository.maxActiveCounts, 1);
      expect(f.dmRepository.readCalls, hasLength(3));
    }),
  );

  test(
    'bulk read and delayed external count finish with the bulk server count',
    () => _scenario((f) async {
      final oldCount = f.repository.holdNextCount();
      final read = f.confirmExternal('a');
      final bulkCount = f.repository.holdNextCount();
      final bulk = f.notifications.markAllAsRead();
      await flushCounter();
      expect(oldCount.snapshot, 2);
      expect(bulkCount.snapshot, 0);
      oldCount.deliver();
      await read;
      bulkCount.deliver();
      await bulk;
      expect(f.notifications.state.items.every((item) => item.read), isTrue);
      expect(f.notifications.state.unreadCount, 0);
      expect(f.repository.unread, 0);
    }),
  );

  test(
    'off-page DM confirmation also protects pending DELETE rollback',
    () => _scenario((f) async {
      final deletion = f.notifications.deleteNotification(f.row('a'));
      f.repository.commitMessageRead(counterMessage);
      f.notifications.markDmMessageAsReadLocally(counterMessage);
      await flushCounter();
      f.repository.failDelete('a');
      await deletion;
      expect(f.notifications.state.items.first.read, isTrue);
      expect(f.notifications.state.unreadCount, 2);
      expect(f.repository.unread, 2);
    }),
  );

  for (final failure in ['result', 'throw']) {
    test(
      'count $failure preserves confirmed read and duplicate retries only count',
      () => _scenario((f) async {
        final held = f.repository.holdNextCount();
        final read = f.confirmExternal('a');
        if (failure == 'result') {
          held.fail();
        } else {
          held.throwError();
        }
        await read;
        expect(f.notifications.state.items.first.read, isTrue);
        expect(
          f.notifications.state.unreadCount,
          3,
          reason: 'Count failure cannot fabricate an authoritative decrement.',
        );
        await f.notifications.applyConfirmedExternalRead(
          f.row('a'),
          f.sessions.session,
        );
        expect(f.notifications.state.unreadCount, 2);
        expect(f.repository.counts, [3, 2, 2]);
        expect(f.repository.readCalls, isEmpty);
        expect(f.repository.pages, [0]);
      }),
    );
  }

  test(
    'count timeout releases caller and late result cannot replace later count',
    () => _scenario((f) async {
      final held = f.repository.holdNextCount();
      await f.confirmExternal('a').timeout(const Duration(seconds: 1));
      expect(f.notifications.state.items.first.read, isTrue);
      expect(f.repository.counts, [3, 2]);
      await f.confirmExternal('b');
      expect(f.notifications.state.unreadCount, 1);
      held.deliver();
      await flushCounter();
      expect(f.notifications.state.unreadCount, 1);
      expect(f.repository.counts, [3, 2, 1]);
      expect(f.repository.readCalls, isEmpty);
    }, timeout: const Duration(milliseconds: 15)),
  );

  test(
    'continuous realtime contention is capped at two snapshots then next ACK repairs debt',
    () => _scenario((f) async {
      final one = f.repository.holdNextCount();
      final two = f.repository.holdNextCount();
      final a = f.confirmExternal('a');
      final arrival = counterNotification('arrival');
      f.repository.rows.insert(0, arrival);
      f.realtime.notifications.add(arrival);
      await flushCounter();
      expect(f.repository.counts, [3, 2]);
      one.deliver();
      await flushCounter();
      expect(two.snapshot, 3);
      final later = counterNotification('later-arrival');
      f.repository.rows.insert(0, later);
      f.realtime.notifications.add(later);
      await flushCounter();
      two.deliver();
      await a;
      await flushCounter();
      expect(f.repository.counts, [3, 2, 3]);
      expect(f.repository.maxActiveCounts, 1);
      expect(f.repository.pages, [0]);
      await f.notifications.applyConfirmedExternalRead(
        f.row('a'),
        f.sessions.session,
      );
      expect(f.notifications.state.unreadCount, 4);
      expect(f.repository.counts, [3, 2, 3, 4]);
      expect(f.repository.deleteCalls, isEmpty);
      expect(f.repository.readCalls, isEmpty);
    }),
  );

  for (final differentUser in [false, true]) {
    test(
      'late count cannot cross ${differentUser ? 'account' : 'token'} boundary',
      () => _scenario((f) async {
        final oldSession = f.sessions.session;
        final oldRow = f.row('a');
        final held = f.repository.holdNextCount();
        final oldRead = f.confirmExternal('a');
        final oldMessageRead = f.notifications.markDmMessageAsReadLocally(
          counterMessage,
        );
        f.repository.rows
          ..clear()
          ..add(
            counterNotification(
              'a',
              messageId: counterMessage,
              owner: differentUser ? counterOtherOwner : counterOwner,
            ),
          );
        f.sessions.replace(
          audienceSession(
            user: differentUser ? counterOtherOwner : counterOwner,
            token: 'replacement-token',
            role: 'ROLE_MUSICIAN',
          ),
        );
        await f.notifications.ensureStarted();
        await Future.wait([
          oldRead,
          oldMessageRead,
        ]).timeout(const Duration(seconds: 1));
        expect(f.notifications.state.unreadCount, 1);
        expect(f.notifications.state.items.single.read, isFalse);
        held.deliver();
        await flushCounter();
        await f.notifications.applyConfirmedExternalRead(oldRow, oldSession);
        expect(f.notifications.state.unreadCount, 1);
        expect(f.notifications.state.items.single.read, isFalse);
        expect(f.repository.counts, [3, 2, 1]);
      }),
    );
  }

  test(
    'DM HTTP completion from old session cannot confirm reused message ID',
    () => _scenario((f) async {
      await f.loadChat();
      final shown = f.chat.acknowledgePresentedHistory([counterMessage]);
      f.repository.rows
        ..clear()
        ..add(counterNotification('a', messageId: counterMessage));
      f.sessions.replace(
        audienceSession(
          user: counterOwner,
          token: 'new-token',
          role: 'ROLE_MUSICIAN',
        ),
      );
      await f.notifications.ensureStarted();
      f.dmRepository.deliverRead();
      await shown;
      await flushCounter();
      expect(f.notifications.state.items.single.read, isFalse);
      expect(f.notifications.state.unreadCount, 1);
      expect(f.repository.counts, [3, 1]);
    }),
  );

  test(
    'close cancels reconciliation immediately and observes late transport error',
    () => _scenario((f) async {
      final held = f.repository.holdNextCount();
      final read = f.confirmExternal('a');
      await f.notifications.close();
      await read.timeout(const Duration(seconds: 1));
      final finalState = f.notifications.state;
      held.throwError();
      await flushCounter();
      expect(f.notifications.state, same(finalState));
      expect(f.repository.counts, [3, 2]);
    }),
  );

  for (final coverHistory in [false, true]) {
    testWidgets(
      'real DmChatScreen presented history cover=$coverHistory reconciles off-page count',
      (tester) async {
        await serviceLocator.reset();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        final f = CounterFixture(
          rows: [
            ...List.generate(20, (i) => counterNotification('sibling-$i')),
            counterNotification('a', messageId: counterMessage),
          ],
        );
        final history = Completer<Result<Page<DmMessage>>>();
        f.dmRepository.heldHistory = history;
        final visibleAtRead = <bool>[];
        f.dmRepository.onRead = (_) => visibleAtRead.add(
          find
              .text(f.dmRepository.messages.single.content)
              .hitTestable()
              .evaluate()
              .isNotEmpty,
        );
        serviceLocator.registerFactory<DmChatCubit>(() => f.chat);
        final navigator = GlobalKey<NavigatorState>();
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          await f.dispose();
          await serviceLocator.reset();
        });
        await f.start();
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigator,
            navigatorObservers: [dmChatRouteObserver],
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              settings: RouteSettings(
                arguments: DmChatScreenArgs(
                  otherUserId: 'counter-sender',
                  otherUsername: 'Sender',
                  currentUserId: counterOwner,
                ),
              ),
              builder: (_) => DmChatScreen(),
            ),
          ),
        );
        await tester.pump();
        expect(f.dmRepository.readCalls, isEmpty);
        expect(f.notifications.state.unreadCount, 21);
        if (coverHistory) {
          unawaited(
            navigator.currentState!.push(
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('Covered')),
              ),
            ),
          );
          await tester.pumpAndSettle();
        }
        history.complete(
          Result.success(Page(items: f.dmRepository.messages, hasNext: false)),
        );
        if (coverHistory) {
          await tester.pumpAndSettle();
          expect(
            f.dmRepository.readCalls,
            isEmpty,
            reason:
                'A page finishing behind another route cannot confirm reads.',
          );
          navigator.currentState!.pop();
        }
        await tester.pumpAndSettle();
        expect(visibleAtRead, [true]);
        expect(f.dmRepository.readCalls, [counterMessage]);
        expect(f.repository.unread, 20);
        expect(
          f.notifications.state.unreadCount,
          21,
          reason: 'Server commit alone is not the HTTP ACK callback.',
        );
        f.dmRepository.deliverRead();
        await tester.pumpAndSettle();
        expect(f.chat.state.messages.single.readAt, isNotNull);
        expect(f.notifications.state.unreadCount, 20);
        expect(f.notifications.state.items, hasLength(20));
        expect(f.notifications.state.items.every((n) => !n.read), isTrue);
        expect(f.repository.pages, [0]);
        expect(f.repository.counts, [21, 20]);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
