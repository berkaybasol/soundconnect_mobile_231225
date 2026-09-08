import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/pagination/page.dart'
    as pagination;
import 'package:soundconnect_23_12_25codx/modules/notification/data/notification_realtime_client.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/domain/entities/app_notification.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/domain/notification_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/cubit/notification_cubit.dart';

void main() {
  late _Repository repository;
  late _Realtime realtime;
  late NotificationCubit cubit;
  setUp(() async {
    repository = _Repository();
    realtime = _Realtime();
    cubit = NotificationCubit(repository, _Tokens(), realtimeClient: realtime);
    await cubit.ensureStarted();
  });
  tearDown(() async {
    await cubit.close();
    await realtime.dispose();
  });

  test(
    'clear-all tombstones known IDs against late frame resurrection',
    () async {
      await cubit.clearAllNotifications();
      realtime.notifications.add(_item('known'));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.items, isEmpty);
      expect(cubit.state.unreadCount, 0);
    },
  );

  test(
    'unknown delayed deleted frame is verified by REST and never inserted',
    () async {
      await cubit.clearAllNotifications();
      final reads = repository.reads;
      realtime.notifications.add(_item('old-off-page'));
      await Future<void>.delayed(Duration.zero);
      expect(repository.reads, greaterThan(reads));
      expect(cubit.state.items, isEmpty);
      expect(cubit.state.unreadCount, 0);
    },
  );

  test(
    'legitimate notification created after clear is restored by verification',
    () async {
      await cubit.clearAllNotifications();
      repository.items = [_item('new')];
      realtime.notifications.add(_item('new'));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.items.map((item) => item.id), ['new']);
      expect(cubit.state.unreadCount, 1);
    },
  );

  test(
    'new frame during verification queues another authoritative refresh',
    () async {
      await cubit.clearAllNotifications();
      final pending = Completer<Result<pagination.Page<AppNotification>>>();
      repository.pendingRead = pending;
      realtime.notifications.add(_item('old-off-page'));
      await Future<void>.delayed(Duration.zero);
      realtime.notifications.add(_item('new'));
      await Future<void>.delayed(Duration.zero);
      repository.pendingRead = null;
      repository.items = [_item('new')];
      pending.complete(
        const Result.success(pagination.Page(items: [], hasNext: false)),
      );
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.items.map((item) => item.id), ['new']);
    },
  );

  test(
    'a failed earlier individual delete cannot roll back successful clear-all',
    () async {
      repository.items = [_item('known'), _item('second')];
      await cubit.refresh();
      repository.pendingDelete = Completer<Result<void>>();
      final deletion = cubit.deleteNotification(cubit.state.items.first);
      await cubit.clearAllNotifications();
      repository.pendingDelete!.complete(
        const Result.failure(AppError(code: 'offline', message: 'Failed')),
      );
      await deletion;
      expect(cubit.state.items, isEmpty);
    },
  );

  test(
    'clear-all double delivery dispatches once and failure keeps visible data',
    () async {
      repository.pendingClear = Completer<Result<int>>();
      final first = cubit.clearAllNotifications();
      await cubit.clearAllNotifications();
      expect(repository.clears, 1);
      repository.pendingClear!.complete(
        const Result.failure(AppError(code: 'offline', message: 'Failed')),
      );
      await first;
      expect(cubit.state.items.single.id, 'known');
      realtime.notifications.add(_item('new'));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.items.map((item) => item.id), ['new', 'known']);
    },
  );
}

AppNotification _item(String id) => AppNotification(
  id: id,
  recipientId: 'account',
  type: 'BAND',
  title: 'Title',
  message: 'Message',
  read: false,
  createdAt: DateTime.utc(2026, 9),
  payload: const {},
);

class _Repository extends Fake implements NotificationRepository {
  List<AppNotification> items = [_item('known')];
  int reads = 0;
  int clears = 0;
  Completer<Result<pagination.Page<AppNotification>>>? pendingRead;
  Completer<Result<int>>? pendingClear;
  Completer<Result<void>>? pendingDelete;
  @override
  Future<Result<pagination.Page<AppNotification>>> listNotifications({
    int page = 0,
    int size = 20,
  }) async {
    reads++;
    return pendingRead?.future ??
        Result.success(pagination.Page(items: List.of(items), hasNext: false));
  }

  @override
  Future<Result<int>> getUnreadCount() async => Result.success(items.length);
  @override
  Future<Result<int>> clearAllNotifications() async {
    clears++;
    if (pendingClear != null) return pendingClear!.future;
    final deletedCount = items.length;
    items = [];
    return Result.success(deletedCount);
  }

  @override
  Future<Result<void>> deleteNotification({
    required String notificationId,
  }) async => pendingDelete?.future ?? const Result.success(null);
}

class _Tokens extends Fake implements TokenStore {
  @override
  Future<String?> readToken() async =>
      'e30.${base64Url.encode(utf8.encode('{"userId":"account"}'))}.signature';
}

class _Realtime extends NotificationRealtimeClient {
  final notifications = StreamController<AppNotification>.broadcast(sync: true);
  @override
  Stream<AppNotification> get notificationStream => notifications.stream;
  @override
  bool get isConnected => true;
  @override
  Future<void> connect({required String userId, required String token}) async {}
  @override
  Future<void> disconnect() async {}
  @override
  Future<void> dispose() async {
    await notifications.close();
    await super.dispose();
  }
}
