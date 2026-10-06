import 'dart:async';

import 'package:flutter/material.dart' hide Page;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/pagination/page.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/data/notification_realtime_client.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/domain/entities/app_notification.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/domain/notification_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/cubit/notification_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/screens/notification_screen.dart';
import 'support/event_audience_fakes.dart';

const _offline = AppError(code: 'offline', message: 'Offline');
const _owner = '22222222-2222-4222-8222-222222222222';
AppNotification _item(String id, {String type = 'SOCIAL_NEW_FOLLOWER'}) =>
    AppNotification(
      id: id,
      recipientId: _owner,
      type: type,
      title: id,
      message: '',
      read: false,
      createdAt: DateTime.utc(2026, 10, 6),
      payload: {if (type == 'DM_NEW_MESSAGE') 'messageId': id},
    );
Future<void> _flush() => Future<void>.delayed(Duration.zero);

AppNotification _orderedItem(String id, DateTime? createdAt) => AppNotification(
  id: id,
  recipientId: _owner,
  type: 'SOCIAL_NEW_FOLLOWER',
  title: id,
  message: '',
  read: false,
  createdAt: createdAt,
  payload: const {},
);

void main() {
  late _Repository repository;
  late _Realtime realtime;
  late AudienceTestSessions sessions;
  late NotificationCubit cubit;
  setUp(() async {
    repository = _Repository();
    realtime = _Realtime();
    sessions = AudienceTestSessions(
      audienceSession(user: _owner, role: 'ROLE_MUSICIAN'),
    );
    cubit = NotificationCubit(
      repository,
      _Tokens(),
      realtimeClient: realtime,
      sessions: sessions,
    );
    await cubit.ensureStarted();
  });
  tearDown(() async {
    await cubit.close();
    await realtime.dispose();
    sessions.dispose();
  });

  for (final timestamps in ['distinct', 'equal', 'missing']) {
    for (final arrival in ['none', 'realtime', 'next-page']) {
      for (final order in [
        ['a', 'b'],
        ['b', 'a'],
      ]) {
        test(
          'failed top-row deletes restore display order timestamps=$timestamps arrival=$arrival completion=$order',
          () async {
            DateTime? createdAt(int minute) => timestamps == 'missing'
                ? null
                : DateTime.utc(
                    2026,
                    10,
                    6,
                    12,
                    timestamps == 'equal' ? 0 : minute,
                  );
            repository.rows
              ..clear()
              ..addAll([
                _orderedItem('a', createdAt(4)),
                _orderedItem('b', createdAt(3)),
                _orderedItem('c', createdAt(2)),
                _orderedItem('d', createdAt(1)),
              ]);
            if (arrival == 'next-page') {
              repository.nextPageRows = [_orderedItem('older', createdAt(0))];
            }
            await cubit.refresh();
            final a = cubit.deleteNotification(cubit.state.items.first);
            final b = cubit.deleteNotification(cubit.state.items.first);
            expect(cubit.state.items.map((n) => n.id), ['c', 'd']);
            if (arrival == 'realtime') {
              final fresh = _orderedItem('new', createdAt(5));
              repository.rows.insert(0, fresh);
              realtime.frames.add(fresh);
              await _flush();
            } else if (arrival == 'next-page') {
              await cubit.loadMore();
            }
            for (final id in order) {
              repository.completeDelete(id, success: false);
              await (id == 'a' ? a : b);
            }
            expect(cubit.state.items.map((n) => n.id), [
              if (arrival == 'realtime') 'new',
              'a',
              'b',
              'c',
              'd',
              if (arrival == 'next-page') 'older',
            ]);
          },
        );
      }
    }
  }

  test('off-page pending deletion returns in its loaded page order', () async {
    repository.nextPageRows = [_item('c'), _item('d')];
    await cubit.refresh();
    await cubit.loadMore();
    final deletion = cubit.deleteNotification(cubit.state.items.last);
    await cubit.refresh();
    await cubit.loadMore();
    repository.completeDelete('d', success: false);
    await deletion;
    expect(cubit.state.items.map((n) => n.id), ['a', 'b', 'c', 'd']);
  });

  test(
    'off-page failed deletion is ordered when its page loads later',
    () async {
      repository.nextPageRows = [_item('c'), _item('d')];
      await cubit.refresh();
      await cubit.loadMore();
      final deletion = cubit.deleteNotification(cubit.state.items.last);
      await cubit.refresh();
      repository.completeDelete('d', success: false);
      await deletion;
      expect(cubit.state.items.map((n) => n.id), ['a', 'b', 'd']);
      await cubit.loadMore();
      expect(cubit.state.items.map((n) => n.id), ['a', 'b', 'c', 'd']);
    },
  );

  for (final failBeforePage in [false, true]) {
    for (final splitPage in [false, true]) {
      for (final newRealtime in [false, true]) {
        for (final order in [
          ['c', 'd'],
          ['d', 'c'],
        ]) {
          test(
            'off-page concurrent rollbacks preserve page and realtime order failBeforePage=$failBeforePage split=$splitPage realtime=$newRealtime completion=$order',
            () async {
              repository.nextPageRows = [_item('c'), _item('d')];
              await cubit.refresh();
              await cubit.loadMore();
              final c = cubit.deleteNotification(cubit.state.items[2]);
              final d = cubit.deleteNotification(cubit.state.items[2]);
              await cubit.refresh();
              if (newRealtime) {
                final fresh = _item('new');
                repository.rows.insert(0, fresh);
                realtime.frames.add(fresh);
                await _flush();
              }
              if (splitPage) {
                repository.nextPageRows = [_item('c')];
                repository.secondNextPageRows = [_item('d')];
              }
              if (!failBeforePage) await cubit.loadMore();
              for (final id in order) {
                repository.completeDelete(id, success: false);
                await (id == 'c' ? c : d);
              }
              if (failBeforePage) await cubit.loadMore();
              final expected = [if (newRealtime) 'new', 'a', 'b', 'c', 'd'];
              expect(cubit.state.items.map((n) => n.id), expected);
              if (splitPage) {
                await cubit.loadMore();
                expect(cubit.state.items.map((n) => n.id), expected);
              }
            },
          );
        }
      }
    }
  }

  for (final order in [
    ['a', 'b'],
    ['b', 'a'],
  ]) {
    for (final arrival in ['realtime', 'next-page']) {
      test(
        'all visible rows hidden preserve $arrival order on failed deletes completion=$order',
        () async {
          if (arrival == 'next-page') {
            repository.nextPageRows = [_orderedItem('older', null)];
            await cubit.refresh();
          }
          final a = cubit.deleteNotification(cubit.state.items.first);
          final b = cubit.deleteNotification(cubit.state.items.first);
          expect(cubit.state.items, isEmpty);
          if (arrival == 'realtime') {
            final fresh = _orderedItem('new', null);
            repository.rows.insert(0, fresh);
            realtime.frames.add(fresh);
            await _flush();
          } else {
            await cubit.loadMore();
          }
          for (final id in order) {
            repository.completeDelete(id, success: false);
            await (id == 'a' ? a : b);
          }
          expect(cubit.state.items.map((n) => n.id), [
            if (arrival == 'realtime') 'new',
            'a',
            'b',
            if (arrival == 'next-page') 'older',
          ]);
        },
      );
    }
    test(
      'failed deletes follow accepted server order after refresh completion=$order',
      () async {
        repository.rows.addAll([_item('c'), _item('d')]);
        await cubit.refresh();
        final a = cubit.deleteNotification(cubit.state.items.first);
        final b = cubit.deleteNotification(cubit.state.items.first);
        repository.rows
          ..clear()
          ..addAll([_item('d'), _item('b'), _item('c'), _item('a')]);
        await cubit.refresh();
        expect(cubit.state.items.map((n) => n.id), ['d', 'c']);
        for (final id in order) {
          repository.completeDelete(id, success: false);
          await (id == 'a' ? a : b);
        }
        expect(cubit.state.items.map((n) => n.id), ['d', 'b', 'c', 'a']);
      },
    );
  }

  for (final order in [
    ['a', 'b'],
    ['b', 'a'],
  ]) {
    for (final successIds in [
      <String>{},
      {'a'},
      {'b'},
      {'a', 'b'},
    ]) {
      test(
        'overlapping deletes success=$successIds completion=$order keep exact count',
        () async {
          final a = cubit.deleteNotification(repository.rows[0]);
          final b = cubit.deleteNotification(repository.rows[1]);
          expect(cubit.state.unreadCount, 0);
          for (final id in order) {
            repository.completeDelete(id, success: successIds.contains(id));
            await (id == 'a' ? a : b);
          }
          expect(
            cubit.state.items.map((n) => n.id).toSet(),
            {'a', 'b'}.difference(successIds),
          );
          expect(cubit.state.unreadCount, 2 - successIds.length);
        },
      );
    }
  }

  test('duplicate deletion shares one optimistic contribution', () async {
    final item = repository.rows.first;
    final first = cubit.deleteNotification(item);
    await cubit.deleteNotification(item);
    expect(repository.deletes.length, 1);
    expect(cubit.state.unreadCount, 1);
    repository.completeDelete('a', success: false);
    await first;
    expect(cubit.state.unreadCount, 2);
  });

  for (final source in ['websocket', 'rest', 'failed-rest']) {
    test('delete rollbacks respect $source count authority', () async {
      final a = cubit.deleteNotification(repository.rows[0]);
      final b = cubit.deleteNotification(repository.rows[1]);
      if (source == 'websocket') {
        realtime.badges.add(2);
        await _flush();
      } else {
        repository.failCount = source == 'failed-rest';
        await cubit.refresh();
      }
      repository.completeDelete('a', success: false);
      await a;
      repository.completeDelete('b', success: false);
      await b;
      expect(cubit.state.items.length, 2);
      expect(cubit.state.unreadCount, 2);
    });
  }

  test(
    'new realtime arrival does not suppress deletion rollback deltas',
    () async {
      final a = cubit.deleteNotification(repository.rows[0]);
      final b = cubit.deleteNotification(repository.rows[1]);
      final fresh = _item('c');
      repository.rows.add(fresh);
      realtime.frames.add(fresh);
      await _flush();
      repository.completeDelete('b', success: false);
      await b;
      repository.completeDelete('a', success: false);
      await a;
      expect(cubit.state.items.map((n) => n.id).toSet(), {'a', 'b', 'c'});
      expect(cubit.state.unreadCount, 3);
    },
  );

  for (final source in ['ack', 'dm-ack']) {
    test(
      'unrelated $source and failed deletion keep both count deltas',
      () async {
        repository.rows[1] = _item('b', type: 'DM_NEW_MESSAGE');
        await cubit.refresh();
        final a = cubit.deleteNotification(repository.rows[0]);
        if (source == 'ack') {
          final b = cubit.markAsRead(repository.rows[1]);
          repository.completeRead('b');
          await b;
        } else {
          cubit.markDmMessageAsReadLocally('b');
        }
        repository.completeDelete('a', success: false);
        await a;
        expect(cubit.state.items.singleWhere((n) => n.id == 'a').read, isFalse);
        expect(cubit.state.items.singleWhere((n) => n.id == 'b').read, isTrue);
        expect(cubit.state.unreadCount, 1);
      },
    );
  }

  test(
    'ACK of hidden deleted row survives rollback without restoring unread',
    () async {
      final item = repository.rows.first;
      final deletion = cubit.deleteNotification(item);
      final ack = cubit.markAsRead(item);
      repository.completeRead('a');
      await ack;
      repository.completeDelete('a', success: false);
      await deletion;
      expect(cubit.state.items.singleWhere((n) => n.id == 'a').read, isTrue);
      expect(cubit.state.unreadCount, 1);
    },
  );

  for (final mutation in ['clear', 'read-all']) {
    test(
      'successful $mutation wins over overlapping deletion failures',
      () async {
        final a = cubit.deleteNotification(repository.rows[0]);
        // Keep one visible row so the user's existing clear action remains enabled.
        if (mutation == 'clear') {
          await cubit.clearAllNotifications();
        } else {
          await cubit.markAllAsRead();
        }
        repository.completeDelete('a', success: false);
        await a;
        if (mutation == 'clear') {
          expect(cubit.state.items, isEmpty);
        } else {
          expect(cubit.state.items.length, 2);
          expect(cubit.state.items.every((n) => n.read), isTrue);
        }
        expect(cubit.state.unreadCount, 0);
      },
    );
  }

  test(
    'pending rollbacks cannot restore an old audience after account change',
    () async {
      final a = cubit.deleteNotification(repository.rows[0]);
      final b = cubit.deleteNotification(repository.rows[1]);
      sessions.replace(
        audienceSession(
          user: 'replacement',
          role: 'ROLE_MUSICIAN',
          token: 'replacement',
        ),
      );
      await _flush();
      repository.completeDelete('a', success: false);
      await a;
      repository.completeDelete('b', success: false);
      await b;
      expect(cubit.state.items, isEmpty);
    },
  );

  test('parallel exact ACKs retain each local decrement', () async {
    final a = cubit.markAsRead(repository.rows[0]);
    final b = cubit.markAsRead(repository.rows[1]);
    repository.completeRead('b');
    await b;
    repository.completeRead('a');
    await a;
    expect(cubit.state.items.every((n) => n.read), isTrue);
    expect(cubit.state.unreadCount, 0);
  });

  test('newer server count supersedes pending exact ACK deltas', () async {
    final a = cubit.markAsRead(repository.rows[0]);
    final b = cubit.markAsRead(repository.rows[1]);
    realtime.badges.add(7);
    await _flush();
    repository.completeRead('b');
    await b;
    repository.completeRead('a');
    await a;
    expect(cubit.state.unreadCount, 7);
  });

  test(
    'newer REST count fences an older external ACK count response',
    () async {
      final pending = Completer<Result<int>>();
      repository.nextCount = pending;
      final external = cubit.applyConfirmedExternalRead(
        _item('off-page'),
        sessions.session,
      );
      await _flush();
      await cubit.refresh();
      pending.complete(const Result.success(99));
      await external;
      expect(cubit.state.unreadCount, 2);
    },
  );

  testWidgets(
    'two swipes and failed DELETEs preserve badge before and after refresh',
    (tester) async {
      await tester.pumpWidget(
        BlocProvider<NotificationCubit>.value(
          value: cubit,
          child: const MaterialApp(home: NotificationScreen()),
        ),
      );
      await tester.pumpAndSettle();
      Finder tile(String id) => find.byWidgetPredicate(
        (w) => w is Dismissible && w.key == ValueKey(id),
      );
      for (final id in ['a', 'b']) {
        await tester.drag(tile(id), const Offset(-600, 0));
        await tester.pumpAndSettle();
      }
      expect(repository.deletes.keys, containsAll(['a', 'b']));
      expect(cubit.state.unreadCount, 0);
      repository.completeDelete('a', success: false);
      await tester.pumpAndSettle();
      repository.completeDelete('b', success: false);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 10));
      expect(tile('a'), findsOneWidget);
      expect(tile('b'), findsOneWidget);
      expect(cubit.state.unreadCount, 2);
      expect(
        tester.getTopLeft(tile('a')).dy,
        lessThan(tester.getTopLeft(tile('b')).dy),
      );
      await cubit.refresh();
      await tester.pumpAndSettle();
      expect(cubit.state.unreadCount, 2);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

class _Tokens extends Fake implements TokenStore {}

class _Repository extends Fake implements NotificationRepository {
  final rows = [_item('a'), _item('b')];
  List<AppNotification> nextPageRows = [];
  List<AppNotification> secondNextPageRows = [];
  final deletes = <String, Completer<Result<void>>>{};
  final reads = <String, Completer<Result<void>>>{};
  bool failCount = false;
  Completer<Result<int>>? nextCount;
  @override
  Future<Result<Page<AppNotification>>> listNotifications({
    int page = 0,
    int size = 20,
  }) async => Result.success(
    Page(
      items: switch (page) {
        0 => rows.toList(),
        1 => nextPageRows.toList(),
        _ => secondNextPageRows.toList(),
      },
      hasNext: page == 0
          ? nextPageRows.isNotEmpty
          : page == 1 && secondNextPageRows.isNotEmpty,
    ),
  );
  @override
  Future<Result<int>> getUnreadCount() async {
    final pending = nextCount;
    nextCount = null;
    if (pending != null) return pending.future;
    return failCount
        ? const Result.failure(_offline)
        : Result.success(rows.where((n) => !n.read).length);
  }

  @override
  Future<Result<void>> deleteNotification({required String notificationId}) =>
      (deletes[notificationId] = Completer<Result<void>>()).future;
  void completeDelete(String id, {required bool success}) {
    if (success) rows.removeWhere((n) => n.id == id);
    deletes[id]!.complete(
      success ? const Result.success(null) : const Result.failure(_offline),
    );
  }

  @override
  Future<Result<void>> markAsRead({required String notificationId}) =>
      (reads[notificationId] = Completer<Result<void>>()).future;
  void completeRead(String id) {
    final index = rows.indexWhere((n) => n.id == id);
    if (index >= 0) rows[index] = rows[index].copyWith(read: true);
    reads[id]!.complete(const Result.success(null));
  }

  @override
  Future<Result<int>> clearAllNotifications() async {
    final count = rows.length;
    rows.clear();
    return Result.success(count);
  }

  @override
  Future<Result<int>> markAllAsRead() async {
    for (var i = 0; i < rows.length; i++) {
      rows[i] = rows[i].copyWith(read: true);
    }
    return Result.success(rows.length);
  }
}

class _Realtime extends NotificationRealtimeClient {
  final frames = StreamController<AppNotification>.broadcast();
  final badges = StreamController<int>.broadcast();
  @override
  Stream<AppNotification> get notificationStream => frames.stream;
  @override
  Stream<int> get badgeStream => badges.stream;
  @override
  bool get isConnected => true;
  @override
  Future<void> connect({required String userId, required String token}) async {}
  @override
  Future<void> disconnect() async {}
  @override
  Future<void> dispose() async {
    await frames.close();
    await badges.close();
    await super.dispose();
  }
}
