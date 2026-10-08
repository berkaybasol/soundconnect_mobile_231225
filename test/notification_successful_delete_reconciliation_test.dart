import 'dart:async';

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
  late _Repository repository;
  late _Realtime realtime;
  late AudienceTestSessions sessions;
  late NotificationCubit cubit;
  Future<void> start(int total) async {
    repository = _Repository(total);
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
  }

  tearDown(() async {
    await cubit.close();
    await realtime.dispose();
    sessions.dispose();
  });
  Future<void> drain() async {
    for (var limit = 0; cubit.state.hasNext && limit < 20; limit++) {
      await cubit.loadMore();
    }
    expect(cubit.state.hasNext, isFalse);
    expect(
      cubit.state.items.map((n) => n.id),
      repository.rows.map((n) => n.id),
    );
  }

  for (final loadedPages in [1, 2, 4]) {
    for (final deleteCount in [1, 20, if (loadedPages > 1) 21]) {
      test(
        '$loadedPages loaded pages retain rows and reach boundary after $deleteCount successes without WS',
        () async {
          await start(loadedPages * 20 + 21);
          for (var p = 1; p < loadedPages; p++) {
            await cubit.loadMore();
          }
          final before = cubit.state.items.toList();
          final pagesBefore = repository.requestedPages.length;
          final countsBefore = repository.countRequests;
          for (final item in before.take(deleteCount)) {
            await cubit.deleteNotification(item);
          }
          expect(
            cubit.state.items.map((n) => n.id),
            before.skip(deleteCount).map((n) => n.id),
            reason: 'Success must retain the loaded prefix and scroll context.',
          );
          expect(repository.requestedPages.length, pagesBefore);
          expect(
            repository.countRequests,
            countsBefore,
            reason: 'A valid optimistic count needs no redundant REST request.',
          );
          await drain();
          expect(cubit.state.unreadCount, repository.rows.length);
        },
      );
    }
  }

  for (final snapshotBeforeDelete in [false, true]) {
    test(
      'in-flight next page is repaired when its snapshot precedes DELETE=$snapshotBeforeDelete',
      () async {
        await start(61);
        final page = Completer<Result<Page<AppNotification>>>();
        repository.nextPage = page;
        final before = repository.page(1);
        final more = cubit.loadMore();
        await cubit.deleteNotification(cubit.state.items.first);
        page.complete(snapshotBeforeDelete ? before : repository.page(1));
        await more;
        expect(cubit.state.items.any((n) => n.id == 'notice-21'), isTrue);
        await drain();
      },
    );
  }

  test(
    'deleting from a completely loaded inbox keeps terminal state and loaded rows',
    () async {
      await start(41);
      await drain();
      final pagesBefore = repository.requestedPages.length;
      final countsBefore = repository.countRequests;
      await cubit.deleteNotification(cubit.state.items[30]);
      expect(cubit.state.hasNext, isFalse);
      expect(
        cubit.state.items.map((n) => n.id),
        repository.rows.map((n) => n.id),
      );
      await cubit.loadMore();
      expect(repository.requestedPages.length, pagesBefore);
      expect(repository.countRequests, countsBefore);
      expect(cubit.state.unreadCount, 40);
    },
  );

  test(
    'failed boundary GET preserves successful DELETE and next-page retry',
    () async {
      await start(21);
      await cubit.deleteNotification(cubit.state.items.first);
      final pending = Completer<Result<Page<AppNotification>>>();
      repository.nextPage = pending;
      final more = cubit.loadMore();
      pending.complete(const Result.failure(_offline));
      await more;
      expect(cubit.state.items.any((n) => n.id == 'notice-1'), isFalse);
      expect(cubit.state.hasNext, isTrue);
      expect(repository.deleteCalls, ['notice-1']);
      await drain();
      expect(cubit.state.unreadCount, 20);
    },
  );

  test(
    'repair boundary anchors an overlapping failed DELETE in server order',
    () async {
      await start(61);
      repository.deferDeletes = true;
      final a = cubit.deleteNotification(cubit.state.items.first);
      repository.rows.removeWhere((n) => n.id == 'notice-1');
      await cubit.loadMore();
      final b = cubit.deleteNotification(
        cubit.state.items.singleWhere((n) => n.id == 'notice-22'),
      );
      repository.completeDelete('notice-1');
      await a;
      await cubit.loadMore();
      repository.completeDelete('notice-22', success: false);
      await b;
      await drain();
      expect(cubit.state.unreadCount, 60);
    },
  );

  test(
    'duplicate overlap after a new WS insertion continues to new rows in one loadMore',
    () async {
      await start(61);
      await cubit.loadMore();
      final fresh = _item(0);
      repository.rows.insert(0, fresh);
      realtime.frames.add(fresh);
      await _flush();
      await cubit.deleteNotification(cubit.state.items[1]);
      await cubit.loadMore();
      expect(cubit.state.items.any((n) => n.id == 'notice-41'), isTrue);
      await drain();
    },
  );

  for (final total in [21, 61]) {
    for (final refreshBeforePage in [false, true]) {
      test(
        'server commit before next page, late DELETE response total=$total refresh=$refreshBeforePage',
        () async {
          await start(total);
          if (refreshBeforePage && total > 21) {
            await cubit.loadMore();
          }
          repository.deferDeletes = true;
          final deletion = cubit.deleteNotification(cubit.state.items.first);
          if (refreshBeforePage) {
            await cubit.refresh();
          }
          // Server commits before answering, while the DELETE HTTP response is
          // still in flight. The next page already sees the shifted DB offsets.
          repository.rows.removeWhere((n) => n.id == 'notice-1');
          await cubit.loadMore();
          repository.completeDelete('notice-1');
          await deletion;
          expect(
            cubit.state.hasNext,
            isTrue,
            reason:
                'A terminal page accepted during DELETE must permit repair.',
          );
          await drain();
          expect(cubit.state.unreadCount, repository.rows.length);
        },
      );
    }
  }

  test(
    'late successful response preserves one-gesture page progress beyond repaired loaded pages',
    () async {
      await start(101);
      repository.deferDeletes = true;
      final deletion = cubit.deleteNotification(cubit.state.items.first);
      repository.rows.removeWhere((n) => n.id == 'notice-1');
      await cubit.loadMore();
      await cubit.loadMore();
      repository.completeDelete('notice-1');
      await deletion;
      await cubit.loadMore();
      expect(cubit.state.items.any((n) => n.id == 'notice-21'), isTrue);
      // The loaded later pages contain duplicates after the rewind. A single
      // user's next scroll must reach new content without another scroll event.
      await cubit.loadMore();
      expect(cubit.state.items.any((n) => n.id == 'notice-62'), isTrue);
      await drain();
    },
  );

  for (final success in [false, true]) {
    test(
      'pre-commit refresh followed by DELETE success=$success retains authoritative count',
      () async {
        await start(2);
        repository.deferDeletes = true;
        final deletion = cubit.deleteNotification(cubit.state.items.first);
        await cubit.refresh();
        repository.completeDelete('notice-1', success: success);
        await deletion;
        expect(cubit.state.items.length, repository.rows.length);
        expect(cubit.state.unreadCount, repository.rows.length);
      },
    );
  }

  for (final order in [true, false]) {
    test(
      'two successful deletes after pre-commit refresh order firstA=$order',
      () async {
        await start(41);
        repository.deferDeletes = true;
        final a = cubit.deleteNotification(cubit.state.items.first);
        final b = cubit.deleteNotification(cubit.state.items.first);
        await cubit.refresh();
        repository.completeDelete(order ? 'notice-1' : 'notice-2');
        await (order ? a : b);
        repository.completeDelete(order ? 'notice-2' : 'notice-1');
        await (order ? b : a);
        expect(cubit.state.unreadCount, 39);
        await drain();
      },
    );
    test(
      'overlapping success/failure after refresh response order successFirst=$order',
      () async {
        await start(41);
        repository.deferDeletes = true;
        final a = cubit.deleteNotification(cubit.state.items[0]);
        final b = cubit.deleteNotification(cubit.state.items[0]);
        await cubit.refresh();
        if (order) {
          repository.completeDelete('notice-1');
          await a;
          repository.completeDelete('notice-2', success: false);
          await b;
        } else {
          repository.completeDelete('notice-2', success: false);
          await b;
          repository.completeDelete('notice-1');
          await a;
        }
        expect(cubit.state.unreadCount, 40);
        await drain();
      },
    );
  }

  test(
    'pre-commit refresh completing after successful DELETE cannot restore its count',
    () async {
      await start(21);
      final pending = Completer<Result<Page<AppNotification>>>();
      final oldPage = repository.page(0);
      repository.nextPage = pending;
      final refresh = cubit.refresh();
      await cubit.deleteNotification(cubit.state.items.first);
      pending.complete(oldPage);
      await refresh;
      expect(cubit.state.unreadCount, 20);
      await drain();
    },
  );

  test('newer REST count fences a pending DELETE count result', () async {
    await start(2);
    repository.deferDeletes = true;
    final deletion = cubit.deleteNotification(cubit.state.items.first);
    await cubit.refresh();
    final pending = Completer<Result<int>>();
    repository.nextCount = pending;
    repository.completeDelete('notice-1');
    await _flush();
    expect(
      repository.nextCount,
      isNull,
      reason: 'The successful DELETE must start its own count reconciliation.',
    );
    repository.rows[0] = repository.rows[0].copyWith(read: true);
    await cubit.refresh();
    pending.complete(const Result.success(1));
    await deletion;
    expect(cubit.state.unreadCount, 0);
    expect(cubit.state.items.single.read, isTrue);
  });

  test(
    'local mutation during DELETE count query is reconciled without double DELETE',
    () async {
      await start(2);
      repository.deferDeletes = true;
      final a = cubit.deleteNotification(cubit.state.items.first);
      await cubit.refresh();
      final pending = Completer<Result<int>>();
      repository.nextCount = pending;
      repository.completeDelete('notice-1');
      await _flush();
      final b = cubit.deleteNotification(cubit.state.items.first);
      repository.completeDelete('notice-2', success: false);
      await b;
      pending.complete(const Result.success(1));
      await a;
      expect(cubit.state.unreadCount, 1);
      expect(repository.deleteCalls, ['notice-1', 'notice-2']);
    },
  );

  test(
    'realtime arrival after count snapshot triggers a fresh count, retaining rows',
    () async {
      await start(2);
      repository.deferDeletes = true;
      final a = cubit.deleteNotification(cubit.state.items.first);
      await cubit.refresh();
      final pending = Completer<Result<int>>();
      repository.nextCount = pending;
      repository.completeDelete('notice-1');
      await _flush();
      final fresh = _item(0);
      repository.rows.insert(0, fresh);
      realtime.frames.add(fresh);
      await _flush();
      pending.complete(const Result.success(1));
      await a;
      expect(cubit.state.unreadCount, 2);
      expect(cubit.state.items.map((n) => n.id), ['notice-0', 'notice-2']);
    },
  );

  test(
    'failed count follow-up never rolls back or repeats a successful DELETE',
    () async {
      await start(21);
      repository.deferDeletes = true;
      final a = cubit.deleteNotification(cubit.state.items.first);
      await cubit.refresh();
      repository.failCount = true;
      repository.completeDelete('notice-1');
      await a;
      expect(cubit.state.items.any((n) => n.id == 'notice-1'), isFalse);
      expect(repository.deleteCalls, ['notice-1']);
      repository.failCount = false;
      await cubit.refresh();
      expect(cubit.state.unreadCount, 20);
      await drain();
    },
  );

  test(
    'account change fences the pending count and retires the old pagination compensation',
    () async {
      await start(21);
      repository.deferDeletes = true;
      final a = cubit.deleteNotification(cubit.state.items.first);
      await cubit.refresh();
      final pending = Completer<Result<int>>();
      repository.nextCount = pending;
      repository.completeDelete('notice-1');
      await _flush();
      expect(
        repository.nextCount,
        isNull,
        reason: 'The held count belongs to the originating deletion session.',
      );
      sessions.replace(
        audienceSession(
          user: 'replacement',
          role: 'ROLE_MUSICIAN',
          token: 'replacement',
        ),
      );
      await _flush();
      await _flush();
      pending.complete(const Result.success(999));
      await a;
      expect(cubit.state.items, isEmpty);
      expect(cubit.state.unreadCount, isNot(999));
    },
  );
}
