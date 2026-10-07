import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/domain/entities/app_notification.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/cubit/notification_cubit.dart';

import 'support/event_audience_fakes.dart';
import 'support/notification_counter_fakes.dart';

AppNotification _row(int index, {String owner = counterOwner}) =>
    counterNotification(
      '00000000-0000-4000-8000-${index.toString().padLeft(12, '0')}',
      owner: owner,
    );
Future<void> _settle(WidgetTester tester) async {
  // Drain delivery before advancing the fixed window; machine load cannot
  // consume the gap between a queued frame and its timer starting.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

class _Realtime extends CounterRealtime {
  final badges = StreamController<int>.broadcast();
  @override
  Stream<int> get badgeStream => badges.stream;
  @override
  Future<void> dispose() async {
    await badges.close();
    await super.dispose();
  }
}

class _Fixture {
  _Fixture({int rows = 21, Duration timeout = const Duration(seconds: 15)}) {
    repository = CounterRepository([for (var i = 0; i < rows; i++) _row(i)]);
    cubit = NotificationCubit(
      repository,
      CounterTokens(),
      realtimeClient: realtime,
      sessions: sessions,
      countReconciliationTimeout: timeout,
    );
  }
  final realtime = _Realtime();
  final sessions = AudienceTestSessions(
    audienceSession(user: counterOwner, role: 'ROLE_MUSICIAN'),
  );
  late final CounterRepository repository;
  late final NotificationCubit cubit;
  Future<void> start() => cubit.ensureStarted();
  Future<void> close() async {
    await cubit.close();
    await realtime.dispose();
    sessions.dispose();
  }
}

void main() {
  testWidgets(
    'late off-page creation after settled badge cannot double count',
    (tester) async {
      final f = _Fixture();
      addTearDown(f.close);
      await f.start();
      f.realtime.badges.add(21);
      await _settle(tester);
      expect(f.repository.counts, [21, 21]);
      f.realtime.notifications.add(f.repository.rows.last);
      await _settle(tester);
      expect(f.cubit.state.unreadCount, 21);
      expect(f.repository.counts, [21, 21, 21]);
      expect(f.repository.pages, [0, 0]);
      expect(f.cubit.state.items, hasLength(21));
      expect(f.repository.readCalls, isEmpty);
      expect(f.repository.deleteCalls, isEmpty);
    },
  );

  testWidgets('count-only repair preserves all loaded deep pages', (
    tester,
  ) async {
    final f = _Fixture(rows: 61);
    addTearDown(f.close);
    await f.start();
    await f.cubit.loadMore();
    final loaded = f.cubit.state.items.map((n) => n.id).toList();
    f.realtime.notifications.add(f.repository.rows.last);
    await _settle(tester);
    expect(f.cubit.state.unreadCount, 61);
    expect(f.cubit.state.items.map((n) => n.id), [
      f.repository.rows.last.id,
      ...loaded,
    ]);
    expect(f.cubit.state.page, 1);
    expect(f.cubit.state.hasNext, isTrue);
    expect(f.repository.pages, [0, 1]);
  });

  testWidgets('burst of unknown frames shares one bounded count snapshot', (
    tester,
  ) async {
    final f = _Fixture(rows: 45);
    addTearDown(f.close);
    await f.start();
    for (final row in f.repository.rows.skip(20)) {
      f.realtime.notifications.add(row);
    }
    await _settle(tester);
    expect(f.cubit.state.unreadCount, 45);
    expect(f.repository.counts, [45, 45]);
    expect(f.repository.maxActiveCounts, 1);
    expect(f.repository.pages, [0]);
    await _settle(tester);
    expect(f.repository.counts, [
      45,
      45,
    ], reason: 'No count polling after a settled burst.');
  });

  testWidgets(
    'normal subsequent badge coalesces scheduled unknown-frame repair',
    (tester) async {
      final f = _Fixture();
      addTearDown(f.close);
      await f.start();
      f.realtime.notifications.add(f.repository.rows.last);
      f.realtime.badges.add(21);
      await _settle(tester);
      expect(f.cubit.state.unreadCount, 21);
      expect(f.repository.counts, [21, 21]);
    },
  );

  for (final kind in ['known', 'read', 'foreign', 'deleted']) {
    testWidgets('$kind frame does not open a new count request', (
      tester,
    ) async {
      final f = _Fixture();
      addTearDown(f.close);
      await f.start();
      AppNotification frame;
      switch (kind) {
        case 'known':
          frame = f.repository.rows.first;
        case 'read':
          frame = _row(99).copyWith(read: true);
        case 'foreign':
          frame = _row(99, owner: counterOtherOwner);
        default:
          frame = f.repository.rows.first;
          final deletion = f.cubit.deleteNotification(frame);
          f.repository.completeDelete(frame.id);
          await deletion;
      }
      final countsBefore = f.repository.counts.length;
      final unreadBefore = f.cubit.state.unreadCount;
      f.realtime.notifications.add(frame);
      await _settle(tester);
      expect(f.repository.counts, hasLength(countsBefore));
      expect(f.cubit.state.unreadCount, unreadBefore);
    });
  }

  testWidgets('successful external ACK consumes the pending arrival window', (
    tester,
  ) async {
    final f = _Fixture();
    addTearDown(f.close);
    await f.start();
    f.realtime.notifications.add(f.repository.rows.last);
    await tester.pump();
    final first = f.repository.rows.first;
    f.repository.commitRead(first.id);
    await f.cubit.applyConfirmedExternalRead(first, f.sessions.session);
    await _settle(tester);
    expect(f.repository.counts, [21, 20]);
    expect(f.cubit.state.unreadCount, 20);
    expect(f.repository.pages, [0]);
  });

  testWidgets(
    'successful delete during held arrival count takes post-delete snapshot',
    (tester) async {
      final f = _Fixture();
      addTearDown(f.close);
      await f.start();
      final held = f.repository.holdNextCount();
      f.realtime.notifications.add(f.repository.rows.last);
      await _settle(tester);
      expect(held.snapshot, 21);
      final first = f.repository.rows.first;
      final deletion = f.cubit.deleteNotification(first);
      f.repository.completeDelete(first.id);
      await tester.pump();
      held.deliver();
      await deletion;
      await tester.pump();
      expect(f.cubit.state.unreadCount, 20);
      expect(f.repository.counts, [21, 21, 20]);
      expect(f.repository.deleteCalls, [first.id]);
      expect(f.cubit.state.items.any((n) => n.id == first.id), isFalse);
    },
  );

  testWidgets(
    'failed optimistic delete is already included in accepted arrival count',
    (tester) async {
      final f = _Fixture();
      addTearDown(f.close);
      await f.start();
      final first = f.repository.rows.first;
      final deletion = f.cubit.deleteNotification(first);
      f.realtime.notifications.add(f.repository.rows.last);
      await _settle(tester);
      expect(f.cubit.state.unreadCount, 21);
      f.repository.failDelete(first.id);
      await deletion;
      expect(f.cubit.state.unreadCount, 21);
      expect(f.cubit.state.items.any((n) => n.id == first.id), isTrue);
    },
  );

  for (final failure in ['error', 'throw', 'timeout']) {
    testWidgets(
      '$failure leaves recoverable debt without polling or late overwrite',
      (tester) async {
        final f = _Fixture(timeout: const Duration(milliseconds: 30));
        addTearDown(f.close);
        await f.start();
        final held = f.repository.holdNextCount();
        f.realtime.notifications.add(f.repository.rows.last);
        await _settle(tester);
        expect(held.snapshot, 21);
        if (failure == 'error') held.fail();
        if (failure == 'throw') held.throwError();
        await _settle(tester);
        expect(f.repository.counts, [21, 21]);
        f.repository.rows.insert(0, _row(99));
        await f.cubit.refresh();
        expect(f.cubit.state.unreadCount, 22);
        if (failure == 'timeout') held.deliver();
        await _settle(tester);
        expect(f.cubit.state.unreadCount, 22);
        expect(f.repository.counts, [21, 21, 22]);
      },
    );
  }

  for (final afterCountStarts in [false, true]) {
    test(
      'session switch cancels arrival repair started=$afterCountStarts',
      () async {
        final f = _Fixture();
        addTearDown(f.close);
        await f.start();
        final held = afterCountStarts ? f.repository.holdNextCount() : null;
        f.realtime.notifications.add(f.repository.rows.last);
        // Deliver the frame before waiting for the product's timer window.
        await flushCounter();
        if (afterCountStarts) {
          await Future<void>.delayed(const Duration(milliseconds: 300));
          expect(held!.snapshot, 21);
        }
        f.repository.rows
          ..clear()
          ..add(_row(99, owner: counterOtherOwner));
        f.sessions.replace(
          audienceSession(user: counterOtherOwner, role: 'ROLE_MUSICIAN'),
        );
        await f.cubit.ensureStarted();
        held?.deliver();
        await Future<void>.delayed(const Duration(milliseconds: 300));
        expect(f.cubit.state.unreadCount, 1);
        expect(f.cubit.state.items.single.recipientId, counterOtherOwner);
        expect(f.repository.counts, afterCountStarts ? [21, 21, 1] : [21, 1]);
      },
    );
  }

  test('close retires a pending arrival timer without new requests', () async {
    final f = _Fixture();
    await f.start();
    f.realtime.notifications.add(f.repository.rows.last);
    await flushCounter();
    await f.close();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(f.repository.counts, [21]);
  });
}
