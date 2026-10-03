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

enum _Mutation { read, readAll, delete, clearAll }

void main() {
  late AudienceTestSessions sessions;
  late _Repository repository;
  late _Realtime realtime;
  late NotificationCubit cubit;
  late Future<void> Function() comparison;
  var comparisons = 0;

  setUp(() async {
    sessions = AudienceTestSessions(audienceSession(user: 'account'));
    repository = _Repository();
    realtime = _Realtime();
    comparisons = 0;
    comparison = () async {};
    cubit = NotificationCubit(
      repository,
      _Tokens(),
      sessions: sessions,
      realtimeClient: realtime,
      onDeliveryStateChanged: () {
        comparisons++;
        return comparison();
      },
    );
    await cubit.ensureStarted();
  });

  tearDown(() async {
    await cubit.close();
    await realtime.dispose();
    sessions.dispose();
  });

  Future<void> mutate(_Mutation mutation) => switch (mutation) {
    _Mutation.read => cubit.markAsRead(cubit.state.items.single),
    _Mutation.readAll => cubit.markAllAsRead(),
    _Mutation.delete => cubit.deleteNotification(cubit.state.items.single),
    _Mutation.clearAll => cubit.clearAllNotifications(),
  };

  for (final mutation in _Mutation.values) {
    test('$mutation compares OS delivery only after server success', () async {
      repository.pendingMutation = Completer<Result<void>>();
      final pending = mutate(mutation);
      await repository.mutationStarted.future;
      expect(comparisons, 0);
      repository.pendingMutation!.complete(const Result.success(null));
      await pending;
      expect(comparisons, 1);
      expect(cubit.state.errorMessage, isNull);
      if (mutation == _Mutation.delete || mutation == _Mutation.clearAll) {
        expect(cubit.state.items, isEmpty);
      } else {
        expect(cubit.state.items.single.read, isTrue);
      }
    });

    test('$mutation failure preserves OS tray without comparison', () async {
      repository.failMutation = true;
      await mutate(mutation);
      expect(comparisons, 0);
      expect(cubit.state.items.single.read, isFalse);
      expect(cubit.state.errorMessage, 'Mutation failed');
    });

    for (final logout in [true, false]) {
      test(
        '$mutation late success after ${logout ? 'logout' : 'account switch'} cannot compare',
        () async {
          repository.pendingMutation = Completer<Result<void>>();
          final pending = mutate(mutation);
          await repository.mutationStarted.future;
          sessions.replace(
            logout
                ? const AuthSession.guest()
                : audienceSession(
                    user: 'replacement',
                    token: 'replacement-token',
                  ),
          );
          repository.pendingMutation!.complete(const Result.success(null));
          await pending;
          expect(comparisons, 0);
        },
      );
    }
  }

  for (final mutation in [_Mutation.readAll, _Mutation.clearAll]) {
    test(
      '$mutation comparison does not wait for a stalled inbox refresh',
      () async {
        repository.pendingPage = Completer<Result<Page<AppNotification>>>();
        final pending = mutate(mutation);
        await repository.mutationStarted.future;
        await Future<void>.delayed(Duration.zero);
        expect(comparisons, 1);
        repository.pendingPage!.complete(
          Result.success(Page(items: repository.items, hasNext: false)),
        );
        await pending;
      },
    );
  }

  test(
    'stalled OS comparison does not block a successful inbox mutation',
    () async {
      final comparisonGate = Completer<void>();
      comparison = () => comparisonGate.future;
      await mutate(_Mutation.read);
      expect(comparisons, 1);
      expect(cubit.state.items.single.read, isTrue);
      comparisonGate.complete();
    },
  );

  for (final asynchronous in [true, false]) {
    test(
      '${asynchronous ? 'async' : 'sync'} comparison error does not turn server success into UI failure',
      () async {
        comparison = asynchronous
            ? () async => throw StateError('comparison unavailable')
            : () => throw StateError('comparison unavailable');
        await mutate(_Mutation.read);
        await Future<void>.delayed(Duration.zero);
        expect(comparisons, 1);
        expect(cubit.state.items.single.read, isTrue);
        expect(cubit.state.errorMessage, isNull);
      },
    );
  }

  test(
    'confirmed read still compares when concurrent DM ACK already updated the row',
    () async {
      repository.pendingMutation = Completer<Result<void>>();
      final pending = mutate(_Mutation.read);
      await repository.mutationStarted.future;
      cubit.markDmMessageAsReadLocally('message');
      expect(cubit.state.items.single.read, isTrue);
      repository.pendingMutation!.complete(const Result.success(null));
      await pending;
      expect(comparisons, 1);
    },
  );

  test(
    'external ACK for an unloaded notification reconciles OS and authoritative count without marking other rows',
    () async {
      repository.externalCount = 8;
      await cubit.applyConfirmedExternalRead(
        _item(id: 'unloaded'),
        sessions.session,
      );
      expect(comparisons, 1);
      expect(cubit.state.unreadCount, 8);
      expect(cubit.state.items.single.read, isFalse);
      expect(repository.mutations, 0);
    },
  );
  test(
    'external ACK compares immediately while its count refresh is pending',
    () async {
      repository.pendingCount = Completer<Result<int>>();
      final pending = cubit.applyConfirmedExternalRead(
        _item(id: 'unloaded'),
        sessions.session,
      );
      expect(comparisons, 1);
      repository.pendingCount!.complete(const Result.success(4));
      await pending;
      expect(cubit.state.unreadCount, 4);
    },
  );
  test(
    'external ACK count cannot overwrite replacement account state',
    () async {
      repository.pendingCount = Completer<Result<int>>();
      final captured = sessions.session;
      final pending = cubit.applyConfirmedExternalRead(
        _item(id: 'unloaded'),
        captured,
      );
      sessions.replace(const AuthSession.guest());
      repository.pendingCount!.complete(const Result.success(99));
      await pending;
      expect(cubit.state.unreadCount, 0);
      await cubit.applyConfirmedExternalRead(_item(id: 'unloaded'), captured);
      expect(comparisons, 1);
    },
  );
  test(
    'external ACK failure to refresh count preserves unrelated row state',
    () async {
      repository.pendingCount = Completer<Result<int>>()
        ..complete(
          const Result.failure(AppError(code: 'offline', message: 'Offline')),
        );
      await cubit.applyConfirmedExternalRead(
        _item(id: 'unloaded'),
        sessions.session,
      );
      expect(cubit.state.unreadCount, 1);
      expect(cubit.state.items.single.read, isFalse);
      expect(comparisons, 1);
    },
  );

  test(
    'local projection and no-op mutations do not compare OS delivery',
    () async {
      cubit.markDmMessageAsReadLocally('message');
      await cubit.markAsRead(cubit.state.items.single);
      await cubit.deleteNotification(_item(id: 'absent'));
      expect(comparisons, 0);
      expect(repository.mutations, 0);
      await cubit.clearAllNotifications();
      expect(comparisons, 1);
      await cubit.clearAllNotifications();
      expect(comparisons, 1);
    },
  );
}

AppNotification _item({String id = 'notification'}) => AppNotification(
  id: id,
  recipientId: 'account',
  type: 'DM_NEW_MESSAGE',
  title: 'Fixture',
  message: 'Fixture',
  read: false,
  createdAt: DateTime.utc(2026, 9, 23),
  payload: const {'messageId': 'message', 'conversationId': 'conversation'},
);

class _Repository extends Fake implements NotificationRepository {
  List<AppNotification> items = [_item()];
  int mutations = 0;
  bool failMutation = false;
  Completer<Result<int>>? pendingCount;
  int? externalCount;
  final mutationStarted = Completer<void>();
  Completer<Result<void>>? pendingMutation;
  Completer<Result<Page<AppNotification>>>? pendingPage;

  Future<Result<void>> _commit(void Function() apply) async {
    mutations++;
    if (!mutationStarted.isCompleted) mutationStarted.complete();
    final result =
        await (pendingMutation?.future ??
            Future.value(
              failMutation
                  ? const Result<void>.failure(
                      AppError(code: 'failed', message: 'Mutation failed'),
                    )
                  : const Result<void>.success(null),
            ));
    if (result.isSuccess) apply();
    return result;
  }

  @override
  Future<Result<Page<AppNotification>>> listNotifications({
    int page = 0,
    int size = 20,
  }) async =>
      pendingPage?.future ?? Result.success(Page(items: items, hasNext: false));

  @override
  Future<Result<int>> getUnreadCount() async =>
      pendingCount?.future ??
      Result.success(externalCount ?? items.where((item) => !item.read).length);

  @override
  Future<Result<void>> markAsRead({required String notificationId}) =>
      _commit(() {
        items = items
            .map(
              (item) =>
                  item.id == notificationId ? item.copyWith(read: true) : item,
            )
            .toList();
      });

  @override
  Future<Result<int>> markAllAsRead() async {
    final count = items.where((item) => !item.read).length;
    final result = await _commit(() {
      items = items.map((item) => item.copyWith(read: true)).toList();
    });
    return result.isSuccess
        ? Result.success(count)
        : Result.failure(result.error!);
  }

  @override
  Future<Result<void>> deleteNotification({required String notificationId}) =>
      _commit(() => items.removeWhere((item) => item.id == notificationId));

  @override
  Future<Result<int>> clearAllNotifications() async {
    final count = items.length;
    final result = await _commit(items.clear);
    return result.isSuccess
        ? Result.success(count)
        : Result.failure(result.error!);
  }
}

class _Tokens extends Fake implements TokenStore {
  @override
  Future<String?> readToken() async => null;
}

class _Realtime extends NotificationRealtimeClient {
  @override
  bool get isConnected => true;
  @override
  Future<void> connect({required String userId, required String token}) async {}
  @override
  Future<void> disconnect() async {}
}
