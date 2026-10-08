import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
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
const _other = '33333333-3333-4333-8333-333333333333';
const _offline = AppError(code: 'offline', message: 'Offline');
AppNotification _item(int index, {bool read = false, String owner = _owner}) =>
    AppNotification(
      id: '11111111-1111-4111-8111-${index.toString().padLeft(12, '0')}',
      recipientId: owner,
      type: 'SOCIAL_NEW_FOLLOWER',
      title: 'Follower $index',
      message: 'Followed you',
      read: read,
      createdAt: DateTime.utc(2026, 10, 6).subtract(Duration(seconds: index)),
      payload: const {},
    );
Future<void> _flush() => Future<void>.delayed(Duration.zero);

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

  for (final loaded in [false, true]) {
    for (final badgeFirst in [false, true]) {
      test(
        'bulk page2 loaded=$loaded badgeFirst=$badgeFirst stays read',
        () async {
          if (loaded) {
            await cubit.loadMore();
            expect(cubit.state.items.length, 21);
          }
          await cubit.markAllAsRead();
          expect(cubit.state.items.length, 20);
          expect(cubit.state.items.every((n) => n.read), isTrue);
          expect(cubit.state.unreadCount, 0);
          if (badgeFirst) {
            realtime.badges.add(0);
            // Let the async stream listener arm its debounce before starting
            // the wall-clock wait, including on a busy build/test host.
            await _flush();
            await Future<void>.delayed(const Duration(milliseconds: 300));
          }
          realtime.frames.add(_item(21));
          if (!badgeFirst) realtime.badges.add(0);
          await _flush();
          await Future<void>.delayed(const Duration(milliseconds: 300));
          expect(cubit.state.items.every((n) => n.read), isTrue);
          expect(cubit.state.unreadCount, 0);
          await cubit.loadMore();
          expect(cubit.state.items.length, 21);
          expect(cubit.state.items.last.read, isTrue);
          // Read proof avoids another request or page reset for repeated old IDs.
          final calls = repository.listCalls;
          realtime.frames.add(_item(21));
          await _flush();
          expect(repository.listCalls, calls);
          expect(cubit.state.items.length, 21);
          expect(cubit.state.page, 1);
          expect(cubit.state.items.last.read, isTrue);
        },
      );
    }
  }

  test(
    'bulk proof protects first page and a genuine new event remains unread',
    () async {
      await cubit.markAllAsRead();
      final calls = repository.listCalls;
      realtime.frames.add(_item(1));
      await _flush();
      expect(repository.listCalls, calls);
      expect(cubit.state.items.first.read, isTrue);
      repository.newArrival = true;
      realtime.frames.add(_item(0));
      await _flush();
      expect(cubit.state.items.first.id, _item(0).id);
      expect(cubit.state.items.first.read, isFalse);
      expect(cubit.state.items.skip(1).every((n) => n.read), isTrue);
      expect(cubit.state.unreadCount, 1);
    },
  );

  test(
    'failed bulk never infers read or turns on successful-bulk verification',
    () async {
      repository.failBulk = true;
      await cubit.markAllAsRead();
      final calls = repository.listCalls;
      realtime.frames.add(_item(21));
      await _flush();
      expect(repository.listCalls, calls);
      expect(cubit.state.items.first.read, isFalse);
      expect(cubit.state.items.every((n) => !n.read), isTrue);
    },
  );

  test(
    'failed verification preserves state and a later genuine arrival recovers',
    () async {
      await cubit.markAllAsRead();
      repository.failList = true;
      realtime.frames.add(_item(21));
      await _flush();
      expect(cubit.state.items.length, 20);
      expect(cubit.state.items.every((n) => n.read), isTrue);
      expect(cubit.state.unreadCount, 0);
      expect(cubit.state.errorMessage, 'Offline');
      repository.failList = false;
      repository.newArrival = true;
      realtime.frames.add(_item(0));
      await _flush();
      expect(cubit.state.items.first.id, _item(0).id);
      expect(cubit.state.items.first.read, isFalse);
      expect(cubit.state.unreadCount, 1);
    },
  );

  test(
    'bulk success fences frames even when its first refresh fails',
    () async {
      repository.failList = true;
      await cubit.markAllAsRead();
      expect(cubit.state.items.every((n) => !n.read), isTrue);
      expect(repository.allRead, isTrue);
      repository.failList = false;
      realtime.frames.add(_item(21));
      await _flush();
      expect(cubit.state.items.length, 20);
      expect(cubit.state.items.every((n) => n.read), isTrue);
      expect(cubit.state.unreadCount, 0);
    },
  );

  test(
    'burst queues one follow-up and preserves an arrival during verification',
    () async {
      await cubit.markAllAsRead();
      final pending = Completer<Result<Page<AppNotification>>>();
      repository.nextPage = pending;
      final calls = repository.listCalls;
      realtime.frames.add(_item(21));
      await _flush();
      expect(repository.listCalls, calls + 1);
      final beforeArrival = repository.page(0, 20);
      repository.newArrival = true;
      for (var i = 0; i < 100; i++) {
        realtime.frames.add(_item(21));
      }
      realtime.frames.add(_item(0));
      await _flush();
      expect(repository.listCalls, calls + 1);
      expect(repository.maxActive, 1);
      pending.complete(Result.success(beforeArrival));
      await _flush();
      expect(repository.listCalls, calls + 2);
      expect(repository.maxActive, 1);
      expect(repository.requestedSizes.every((size) => size == 20), isTrue);
      expect(cubit.state.items.first.id, _item(0).id);
      expect(cubit.state.items.first.read, isFalse);
      expect(cubit.state.items.skip(1).every((n) => n.read), isTrue);
      expect(cubit.state.unreadCount, 1);
    },
  );

  test(
    'wrong recipient never triggers verification or changes the inbox',
    () async {
      await cubit.markAllAsRead();
      final calls = repository.listCalls;
      realtime.frames.add(_item(0, owner: _other));
      await _flush();
      expect(repository.listCalls, calls);
      expect(
        cubit.state.items.every((n) => n.recipientId == _owner && n.read),
        isTrue,
      );
      expect(cubit.state.unreadCount, 0);
    },
  );

  test(
    'bulk success retires an older gap page even if follow-up fails',
    () async {
      final pending = Completer<Result<Page<AppNotification>>>();
      repository.preBulkArrival = true;
      final beforeBulk = repository.page(0, 20);
      repository.nextPage = pending;
      realtime.connections.add(null);
      await _flush();
      final previousItems = cubit.state.items;
      final previousCount = cubit.state.unreadCount;
      repository.failList = true;
      final bulk = cubit.markAllAsRead();
      await _flush();
      expect(repository.allRead, isTrue);
      pending.complete(Result.success(beforeBulk));
      await bulk;
      // Failure may retain the last established view, but must not publish a
      // pre-mutation snapshot as a new unread arrival after successful bulk read.
      expect(
        cubit.state.items.map((item) => item.id),
        previousItems.map((item) => item.id),
      );
      expect(cubit.state.unreadCount, previousCount);
      expect(cubit.state.errorMessage, 'Offline');
      repository.failList = false;
      realtime.frames.add(_item(0));
      await _flush();
      expect(cubit.state.items.first.read, isTrue);
      expect(cubit.state.unreadCount, 0);
    },
  );

  for (final switchKind in ['account', 'logout', 'role']) {
    test(
      '$switchKind retires verification and fences its pending response',
      () async {
        await cubit.markAllAsRead();
        final pending = Completer<Result<Page<AppNotification>>>();
        repository.nextPage = pending;
        final oldPage = repository.page(0, 20);
        realtime.frames.add(_item(21));
        await _flush();
        repository.owner = switchKind == 'account' ? _other : _owner;
        repository.allRead = false;
        sessions.replace(
          switchKind == 'logout'
              ? const AuthSession.guest()
              : audienceSession(
                  user: repository.owner,
                  role: switchKind == 'role'
                      ? 'ROLE_LISTENER'
                      : 'ROLE_MUSICIAN',
                ),
        );
        await _flush();
        if (switchKind == 'logout') {
          expect(cubit.state.items, isEmpty);
          sessions.replace(
            audienceSession(user: _owner, role: 'ROLE_MUSICIAN'),
          );
          await _flush();
        }
        expect(cubit.state.items.every((n) => !n.read), isTrue);
        pending.complete(Result.success(oldPage));
        await _flush();
        expect(
          cubit.state.items.every(
            (n) => n.recipientId == repository.owner && !n.read,
          ),
          isTrue,
        );
        final calls = repository.listCalls;
        realtime.frames.add(_item(21, owner: repository.owner));
        await _flush();
        expect(repository.listCalls, calls);
        expect(cubit.state.items.first.id, _item(21).id);
      },
    );
  }

  test(
    'clear during pending verification wins over stale page and deletion rollback',
    () async {
      await cubit.markAllAsRead();
      final deletion = Completer<Result<void>>();
      repository.nextDelete = deletion;
      final deleting = cubit.deleteNotification(cubit.state.items.first);
      final pending = Completer<Result<Page<AppNotification>>>();
      repository.nextPage = pending;
      final oldPage = repository.page(0, 20);
      realtime.frames.add(_item(21));
      await _flush();
      await cubit.clearAllNotifications();
      pending.complete(Result.success(oldPage));
      deletion.complete(const Result.failure(_offline));
      await deleting;
      await _flush();
      expect(cubit.state.items, isEmpty);
      expect(cubit.state.unreadCount, 0);
      realtime.frames.add(_item(21));
      await _flush();
      expect(cubit.state.items, isEmpty);
      expect(cubit.state.unreadCount, 0);
    },
  );
}

class _Repository extends Fake implements NotificationRepository {
  bool allRead = false,
      newArrival = false,
      failBulk = false,
      failList = false,
      cleared = false;
  String owner = _owner;
  bool preBulkArrival = false;
  int listCalls = 0, active = 0, maxActive = 0;
  final requestedSizes = <int>[];
  Completer<Result<Page<AppNotification>>>? nextPage;
  Completer<Result<void>>? nextDelete;
  final deletedIds = <String>{};
  List<AppNotification> get rows => [
    if (preBulkArrival) _item(0, read: allRead, owner: owner),
    if (newArrival) _item(0, owner: owner),
    if (!cleared)
      for (var i = 1; i <= 21; i++) _item(i, read: allRead, owner: owner),
  ].where((n) => !deletedIds.contains(n.id)).toList();
  Page<AppNotification> page(int index, int size) => Page(
    items: rows.skip(index * size).take(size).toList(),
    hasNext: (index + 1) * size < rows.length,
  );
  @override
  Future<Result<Page<AppNotification>>> listNotifications({
    int page = 0,
    int size = 20,
  }) async {
    listCalls++;
    requestedSizes.add(size);
    active++;
    if (active > maxActive) maxActive = active;
    final pending = nextPage;
    nextPage = null;
    try {
      if (pending != null) return await pending.future;
      if (failList) return const Result.failure(_offline);
      return Result.success(this.page(page, size));
    } finally {
      active--;
    }
  }

  @override
  Future<Result<int>> getUnreadCount() async =>
      Result.success(rows.where((n) => !n.read).length);
  @override
  Future<Result<int>> markAllAsRead() async {
    if (failBulk) return const Result.failure(_offline);
    allRead = true;
    return const Result.success(21);
  }

  @override
  Future<Result<int>> clearAllNotifications() async {
    cleared = true;
    return const Result.success(21);
  }

  @override
  Future<Result<void>> deleteNotification({
    required String notificationId,
  }) async {
    if (nextDelete != null) return nextDelete!.future;
    deletedIds.add(notificationId);
    return const Result.success(null);
  }
}

class _Realtime extends NotificationRealtimeClient {
  final frames = StreamController<AppNotification>.broadcast();
  final badges = StreamController<int>.broadcast();
  final connections = StreamController<void>.broadcast();
  @override
  Stream<AppNotification> get notificationStream => frames.stream;
  @override
  Stream<int> get badgeStream => badges.stream;
  @override
  Stream<void> get connectionStream => connections.stream;
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
    await connections.close();
    await super.dispose();
  }
}

class _Tokens extends Fake implements TokenStore {}
