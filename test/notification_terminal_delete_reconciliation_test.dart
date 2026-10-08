import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/pagination/page.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/data/notification_realtime_client.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/domain/entities/app_notification.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/domain/notification_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/cubit/notification_cubit.dart';

import 'support/event_audience_fakes.dart';

const _owner = '22222222-2222-4222-8222-222222222222';
const _offline = AppError(code: 'offline', message: 'Offline');
AppNotification _item(int index) => AppNotification(
  id: 'notice-$index',
  recipientId: _owner,
  type: 'SOCIAL_NEW_FOLLOWER',
  title: 'Notice $index',
  message: '',
  read: false,
  createdAt: DateTime.utc(2026, 10, 7).subtract(Duration(seconds: index)),
  payload: const {},
);
Future<void> _flush() => Future<void>.delayed(Duration.zero);

class _Tokens extends Fake implements TokenStore {}

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
  Future<void> disconnect() async {}
  @override
  Future<void> dispose() async {
    await frames.close();
    await badges.close();
    await super.dispose();
  }
}

// Stateful production page/size contract; deletes change the offset before
// subsequent snapshots. Deferred responses exercise real Cubit interleavings.
class _Repository extends Fake implements NotificationRepository {
  _Repository(int total) : rows = List.generate(total, (i) => _item(i + 1));
  final List<AppNotification> rows;
  final requestedPages = <int>[];
  final deleteCalls = <String>[];
  final pendingDeletes = <String, Completer<Result<void>>>{};
  bool deferDeletes = false, failCount = false;
  int countRequests = 0;
  Completer<Result<Page<AppNotification>>>? nextPage;
  Completer<Result<int>>? nextCount;
  Result<Page<AppNotification>> page(int page, [int size = 20]) =>
      Result.success(
        Page(
          items: rows.skip(page * size).take(size).toList(),
          hasNext: (page + 1) * size < rows.length,
        ),
      );
  @override
  Future<Result<Page<AppNotification>>> listNotifications({
    int page = 0,
    int size = 20,
  }) async {
    requestedPages.add(page);
    final pending = nextPage;
    nextPage = null;
    return pending == null ? this.page(page, size) : pending.future;
  }

  @override
  Future<Result<int>> getUnreadCount() async {
    countRequests++;
    final pending = nextCount;
    nextCount = null;
    return pending != null
        ? pending.future
        : failCount
        ? const Result.failure(_offline)
        : Result.success(rows.where((n) => !n.read).length);
  }

  @override
  Future<Result<void>> deleteNotification({
    required String notificationId,
  }) async {
    deleteCalls.add(notificationId);
    if (deferDeletes) {
      return (pendingDeletes[notificationId] = Completer<Result<void>>())
          .future;
    }
    rows.removeWhere((n) => n.id == notificationId);
    return const Result.success(null);
  }

  void completeDelete(String id, {bool success = true}) {
    if (success) rows.removeWhere((n) => n.id == id);
    pendingDeletes
        .remove(id)!
        .complete(
          success ? const Result.success(null) : const Result.failure(_offline),
        );
  }
}

void main() {
  for (final total in [21, 41]) {
    for (final mode in [
      'late-success',
      'success-before-pagination',
      'last-row-success',
      'failure',
      'explicit-refresh-recovery',
    ]) {
      test(
        'fully loaded inbox then pending DELETE + refresh total=$total mode=$mode',
        () async {
          final repo = _Repository(total);
          final rt = _Realtime();
          final ss = AudienceTestSessions(
            audienceSession(user: _owner, role: 'ROLE_MUSICIAN'),
          );
          final c = NotificationCubit(
            repo,
            _Tokens(),
            realtimeClient: rt,
            sessions: ss,
          );
          try {
            await c.ensureStarted();
            while (c.state.hasNext) {
              await c.loadMore();
            }
            expect(c.state.items.length, total);
            expect(c.state.hasNext, isFalse);
            final item = mode == 'last-row-success'
                ? c.state.items.last
                : c.state.items.first;
            repo.deferDeletes = true;
            final deleting = c.deleteNotification(item);
            await c.refresh();
            expect(c.state.hasNext, isTrue);
            expect(c.state.items.length, mode == 'last-row-success' ? 20 : 19);
            if (mode != 'failure') {
              repo.rows.removeWhere((n) => n.id == item.id);
            }
            if (mode == 'success-before-pagination') {
              repo.completeDelete(item.id);
              await deleting;
            }
            while (c.state.hasNext) {
              await c.loadMore();
            }
            if (mode != 'success-before-pagination') {
              repo.completeDelete(item.id, success: mode != 'failure');
              await deleting;
            }
            await c.loadMore();
            debugPrint(
              'OBS total=$total mode=$mode ids=${c.state.items.map((n) => n.id).toList()} count=${c.state.unreadCount} hasNext=${c.state.hasNext} requestedPages=${repo.requestedPages}',
            );
            if (mode == 'explicit-refresh-recovery') {
              await c.refresh();
              while (c.state.hasNext) {
                await c.loadMore();
              }
            }
            expect(c.state.unreadCount, repo.rows.length);
            expect(
              c.state.items.map((n) => n.id).toList(),
              repo.rows.map((n) => n.id).toList(),
            );
            expect(repo.deleteCalls, [item.id]);
          } finally {
            await c.close();
            await rt.dispose();
            ss.dispose();
          }
        },
      );
    }
  }
  for (final total in [21, 41]) {
    test(
      'terminal DELETE without refresh does not reopen paging total=$total',
      () async {
        await _withLoaded(total, (repo, c, s, rt) async {
          final before = repo.requestedPages.length;
          await c.deleteNotification(c.state.items.first);
          expect(c.state.hasNext, isFalse);
          await c.loadMore();
          expect(repo.requestedPages.length, before);
          expect(c.state.items.map((n) => n.id), repo.rows.map((n) => n.id));
        });
      },
    );
    test(
      'failed refresh cannot invent a pending DELETE pagination gap total=$total',
      () async {
        await _withLoaded(total, (repo, c, s, rt) async {
          repo.deferDeletes = true;
          final item = c.state.items.first;
          final operation = c.deleteNotification(item);
          repo.nextPage = Completer<Result<Page<AppNotification>>>()
            ..complete(const Result.failure(_offline));
          await c.refresh();
          final before = repo.requestedPages.length;
          repo.completeDelete(item.id);
          await operation;
          expect(c.state.hasNext, isFalse);
          await c.loadMore();
          expect(repo.requestedPages.length, before);
          expect(c.state.items.map((n) => n.id), repo.rows.map((n) => n.id));
          expect(c.state.unreadCount, total - 1);
        });
      },
    );
  }
  for (final previousPartialRefresh in [false, true]) {
    test(
      'accepted terminal refresh retires pending DELETE gap partialBefore=$previousPartialRefresh',
      () async {
        await _withLoaded(21, (repo, c, s, rt) async {
          repo.deferDeletes = true;
          final item = c.state.items.first;
          final operation = c.deleteNotification(item);
          if (previousPartialRefresh) await c.refresh();
          repo.rows.removeWhere((n) => n.id == item.id);
          await c.refresh();
          expect(c.state.hasNext, isFalse);
          final before = repo.requestedPages.length;
          repo.completeDelete(item.id);
          await operation;
          await c.loadMore();
          expect(repo.requestedPages.length, before);
          expect(c.state.items.map((n) => n.id), repo.rows.map((n) => n.id));
          expect(c.state.unreadCount, 20);
        });
      },
    );
  }
  for (final successFirst in [false, true]) {
    for (final secondSucceeds in [false, true]) {
      test(
        'terminal refresh repairs overlapping DELETEs firstA=$successFirst successB=$secondSucceeds',
        () async {
          await _withLoaded(41, (repo, c, s, rt) async {
            repo.deferDeletes = true;
            final a = c.deleteNotification(c.state.items.first);
            final b = c.deleteNotification(c.state.items.first);
            await c.refresh();
            repo.rows.removeWhere(
              (n) =>
                  n.id == 'notice-1' || (secondSucceeds && n.id == 'notice-2'),
            );
            await _drain(c);
            final order = successFirst
                ? ['notice-1', 'notice-2']
                : ['notice-2', 'notice-1'];
            for (final id in order) {
              repo.completeDelete(
                id,
                success: id == 'notice-1' || secondSucceeds,
              );
              await (id == 'notice-1' ? a : b);
            }
            await _drain(c);
            expect(c.state.items.map((n) => n.id), repo.rows.map((n) => n.id));
            expect(c.state.unreadCount, repo.rows.length);
            expect(repo.deleteCalls, ['notice-1', 'notice-2']);
          });
        },
      );
    }
  }
  for (final pageBeforeCommit in [false, true]) {
    test(
      'terminal refresh with in-flight page and successful DELETE snapshotBefore=$pageBeforeCommit',
      () async {
        await _withLoaded(41, (repo, c, s, rt) async {
          repo.deferDeletes = true;
          final operation = c.deleteNotification(c.state.items.first);
          await c.refresh();
          final previousPage = repo.page(1);
          repo.rows.removeWhere((n) => n.id == 'notice-1');
          final page = Completer<Result<Page<AppNotification>>>();
          repo.nextPage = page;
          final loading = c.loadMore();
          repo.completeDelete('notice-1');
          await operation;
          page.complete(pageBeforeCommit ? previousPage : repo.page(1));
          await loading;
          await _drain(c);
          expect(c.state.items.map((n) => n.id), repo.rows.map((n) => n.id));
          expect(c.state.unreadCount, 40);
          expect(repo.deleteCalls, ['notice-1']);
        });
      },
    );
  }
  test(
    'pending terminal DELETE cannot reopen replacement session pagination',
    () async {
      await _withLoaded(41, (repo, c, s, rt) async {
        repo.deferDeletes = true;
        final operation = c.deleteNotification(c.state.items.first);
        await c.refresh();
        repo.rows.removeWhere((n) => n.id == 'notice-1');
        await _drain(c);
        const replacement = '33333333-3333-4333-8333-333333333333';
        repo.rows
          ..clear()
          ..add(
            AppNotification(
              id: 'new-session-row',
              recipientId: replacement,
              type: 'SOCIAL_NEW_FOLLOWER',
              title: 'Replacement',
              message: '',
              read: false,
              createdAt: DateTime.utc(2026, 10, 7),
              payload: const {},
            ),
          );
        s.replace(
          audienceSession(
            user: replacement,
            role: 'ROLE_MUSICIAN',
            token: 'new-token',
          ),
        );
        await _flush();
        await _flush();
        await _flush();
        expect(c.state.items.single.id, 'new-session-row');
        final before = repo.requestedPages.length;
        repo.completeDelete('notice-1');
        await operation;
        expect(c.state.items.single.id, 'new-session-row');
        expect(c.state.hasNext, isFalse);
        expect(c.state.unreadCount, 1);
        await c.loadMore();
        expect(repo.requestedPages.length, before);
      });
    },
  );
}

Future<void> _drain(NotificationCubit c) async {
  for (var i = 0; c.state.hasNext && i < 20; i++) {
    await c.loadMore();
  }
  expect(c.state.hasNext, isFalse);
}

Future<void> _withLoaded(
  int total,
  Future<void> Function(
    _Repository,
    NotificationCubit,
    AudienceTestSessions,
    _Realtime,
  )
  body,
) async {
  final repo = _Repository(total), rt = _Realtime();
  final s = AudienceTestSessions(
    audienceSession(user: _owner, role: 'ROLE_MUSICIAN'),
  );
  final c = NotificationCubit(repo, _Tokens(), realtimeClient: rt, sessions: s);
  try {
    await c.ensureStarted();
    await _drain(c);
    expect(c.state.items.length, total);
    await body(repo, c, s, rt);
  } finally {
    await c.close();
    await rt.dispose();
    s.dispose();
  }
}
