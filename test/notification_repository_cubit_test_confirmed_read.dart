part of 'notification_repository_cubit_test.dart';

void _registerConfirmedReadTests() {
  group('confirmed read projection', () {
    late _ControlledNotificationRepository repository;
    late _TestNotificationRealtimeClient realtime;
    late AudienceTestSessions sessions;
    late NotificationCubit cubit;
    final exact = _notification('exact');
    final sibling = _notification('sibling');

    Result<pagination.Page<AppNotification>> page(
      List<AppNotification> items, {
      bool hasNext = true,
    }) => Result.success(pagination.Page(items: items, hasNext: hasNext));

    Future<void> frame(AppNotification item) async {
      realtime.emitNotification(item);
      await Future<void>.delayed(Duration.zero);
    }

    Future<void> refreshWith(List<AppNotification> items) async {
      final refresh = cubit.refresh();
      repository.listRequests.last.complete(page(items));
      await refresh;
    }

    setUp(() async {
      repository = _ControlledNotificationRepository()
        ..unreadResult = const Result.success(2);
      realtime = _TestNotificationRealtimeClient();
      sessions = AudienceTestSessions(
        audienceSession(user: 'user-1', role: 'ROLE_MUSICIAN'),
      );
      cubit = NotificationCubit(
        repository,
        _MemoryTokenStore(),
        realtimeClient: realtime,
        sessions: sessions,
      );
      final start = cubit.ensureStarted();
      await _eventually(() => repository.listRequests.isNotEmpty);
      repository.listRequests.single.complete(page([exact, sibling]));
      await start;
    });

    tearDown(() async {
      await cubit.close();
      await realtime.closeStreams();
      sessions.dispose();
    });

    for (final timing in ['during refresh', 'after refresh']) {
      test('bulk read proof survives delayed unread frame $timing', () async {
        repository.unreadResult = const Result.success(0);
        final bulk = cubit.markAllAsRead();
        await _eventually(() => repository.listRequests.length == 2);
        if (timing == 'during refresh') await frame(exact);
        repository.listRequests.last.complete(
          page([exact.copyWith(read: true), sibling.copyWith(read: true)]),
        );
        await bulk;
        if (timing == 'after refresh') await frame(exact);
        expect(cubit.state.items.every((item) => item.read), isTrue);
        expect(cubit.state.unreadCount, 0);
        // A later stale REST projection cannot undo the confirmed bulk result.
        await refreshWith([exact, sibling]);
        expect(cubit.state.items.every((item) => item.read), isTrue);
        expect(cubit.state.unreadCount, 0);
      });
    }

    test('bulk read proof preserves a new arrival during refresh', () async {
      repository.unreadResult = const Result.success(1);
      final bulk = cubit.markAllAsRead();
      await _eventually(() => repository.listRequests.length == 2);
      final fresh = _notification('fresh');
      await frame(exact);
      await frame(fresh);
      repository.listRequests.last.complete(
        page([exact.copyWith(read: true), sibling.copyWith(read: true)]),
      );
      await bulk;
      expect(cubit.state.items.first.id, fresh.id);
      expect(cubit.state.items.first.read, isFalse);
      expect(cubit.state.items.skip(1).every((item) => item.read), isTrue);
      expect(cubit.state.unreadCount, 1);
    });

    test(
      'read page proof protects duplicate and unloaded pagination IDs',
      () async {
        final more = cubit.loadMore();
        final external = _notification('external');
        repository.listRequests.last.complete(
          page([sibling.copyWith(read: true), external.copyWith(read: true)]),
        );
        await more;
        expect(cubit.state.items.map((item) => item.id), [
          'exact',
          'sibling',
          'external',
        ]);
        expect(cubit.state.items.first.read, isFalse);
        expect(cubit.state.items.skip(1).every((item) => item.read), isTrue);
        await refreshWith([exact]);
        await frame(sibling);
        await frame(external);
        expect(
          cubit.state.items
              .where((item) => item.id != exact.id)
              .every((item) => item.read),
          isTrue,
        );
        expect(
          cubit.state.items.singleWhere((item) => item.id == exact.id).read,
          isFalse,
        );
      },
    );

    test(
      'read realtime proof survives a delayed creation projection',
      () async {
        await frame(exact.copyWith(read: true));
        await frame(exact);
        expect(cubit.state.items.first.read, isTrue);
        expect(cubit.state.items.last.read, isFalse);
      },
    );

    test('bulk read page proof is retired on logout and relogin', () async {
      repository.unreadResult = const Result.success(0);
      final bulk = cubit.markAllAsRead();
      await _eventually(() => repository.listRequests.length == 2);
      repository.listRequests.last.complete(
        page([exact.copyWith(read: true), sibling.copyWith(read: true)]),
      );
      await bulk;
      sessions.replace(const AuthSession.guest());
      await _eventually(() => cubit.state.items.isEmpty);
      sessions.replace(audienceSession(user: 'user-1', role: 'ROLE_MUSICIAN'));
      await _eventually(() => repository.listRequests.length == 3);
      repository.unreadResult = const Result.success(2);
      repository.listRequests.last.complete(page([exact, sibling]));
      await _eventually(() => cubit.state.status == NotificationStatus.success);
      expect(cubit.state.items.every((item) => !item.read), isTrue);
      expect(cubit.state.unreadCount, 2);
    });

    test('read page proof survives a pending deletion rollback', () async {
      repository.deleteRequest = Completer<Result<void>>();
      final deletion = cubit.deleteNotification(exact);
      repository.unreadResult = const Result.success(1);
      await refreshWith([exact.copyWith(read: true), sibling]);
      expect(cubit.state.items.single.id, sibling.id);
      repository.deleteRequest!.complete(
        const Result.failure(
          AppError(code: 'delete', message: 'Delete failed'),
        ),
      );
      await deletion;
      expect(cubit.state.items.first.read, isTrue);
      expect(cubit.state.items.last.read, isFalse);
      expect(cubit.state.unreadCount, 1);
    });

    test(
      'another recipient read projection cannot poison current IDs',
      () async {
        final other = _notification(
          exact.id,
          recipientId: 'user-2',
        ).copyWith(read: true);
        await refreshWith([other, sibling]);
        await frame(exact);
        expect(cubit.state.items.first.id, exact.id);
        expect(cubit.state.items.first.read, isFalse);
        expect(cubit.state.items.last.read, isFalse);
      },
    );

    test(
      'loaded ACK survives duplicate frames and preserves new fields',
      () async {
        await cubit.markAsRead(exact);
        final changed = _notification(
          exact.id,
          title: 'Updated title',
          payload: {'revision': 2},
        );
        await frame(changed);
        await frame(changed);
        // Repeated successful ACK of stale input.
        await cubit.markAsRead(exact);
        expect(cubit.state.items.first.read, isTrue);
        expect(cubit.state.items.first.title, 'Updated title');
        expect(cubit.state.items.first.payload, {'revision': 2});
        expect(cubit.state.items.last.read, isFalse);
        expect(cubit.state.unreadCount, 1);
        await frame(_notification('new'));
        await frame(_notification('new'));
        expect(cubit.state.items.map((item) => item.id), [
          'new',
          'exact',
          'sibling',
        ]);
        expect(cubit.state.items.first.read, isFalse);
        expect(cubit.state.unreadCount, 2);
      },
    );

    test('pending and failed ACK never protect an unread frame', () async {
      repository.markReadRequest = Completer<Result<void>>();
      final ack = cubit.markAsRead(exact);
      await frame(exact);
      expect(cubit.state.items.first.read, isFalse);
      repository.markReadRequest!.complete(
        const Result.failure(AppError(code: 'offline', message: 'Offline')),
      );
      await ack;
      await refreshWith([exact, sibling]);
      await frame(exact);
      expect(cubit.state.items.first.read, isFalse);
      expect(cubit.state.unreadCount, 2);
    });

    for (final countSucceeds in [true, false]) {
      test(
        'unloaded ACK protects frames while count is pending/$countSucceeds',
        () async {
          repository.unreadRequest = Completer<Result<int>>();
          final external = _notification('external');
          final ack = cubit.applyConfirmedExternalRead(
            external,
            sessions.session,
          );
          await frame(external);
          await frame(external);
          expect(cubit.state.items.first.read, isTrue);
          expect(cubit.state.items.skip(1).every((item) => !item.read), isTrue);
          expect(cubit.state.unreadCount, 2);
          repository.unreadRequest!.complete(
            countSucceeds
                ? const Result.success(7)
                : const Result.failure(
                    AppError(code: 'offline', message: 'Offline'),
                  ),
          );
          await ack;
          await cubit.applyConfirmedExternalRead(external, sessions.session);
          await frame(external);
          expect(cubit.state.items.first.read, isTrue);
          expect(cubit.state.unreadCount, countSucceeds ? 7 : 2);
        },
      );
    }

    for (final arrival in ['frame', 'loadMore', 'refresh']) {
      test('external ACK survives absent first page then $arrival', () async {
        final external = _notification('external');
        await cubit.applyConfirmedExternalRead(external, sessions.session);
        await refreshWith([sibling]);
        expect(cubit.state.items.single.read, isFalse);
        if (arrival == 'frame') {
          await frame(external);
        } else if (arrival == 'loadMore') {
          final more = cubit.loadMore();
          repository.listRequests.last.complete(
            page([sibling, external, external]),
          );
          await more;
        } else {
          await refreshWith([external, sibling]);
        }
        expect(
          cubit.state.items.singleWhere((item) => item.id == external.id).read,
          isTrue,
        );
        expect(
          cubit.state.items.singleWhere((item) => item.id == sibling.id).read,
          isFalse,
        );
        expect(cubit.state.items, hasLength(2));
        expect(cubit.state.unreadCount, 2);
        await frame(external);
        expect(
          cubit.state.items.singleWhere((item) => item.id == external.id).read,
          isTrue,
        );
        expect(cubit.state.unreadCount, 2);
      });
    }

    test(
      'loaded ACK retains proof when refresh removes its row before completion',
      () async {
        repository.markReadRequest = Completer<Result<void>>();
        final ack = cubit.markAsRead(exact);
        await refreshWith([sibling]);
        repository.markReadRequest!.complete(const Result.success(null));
        await ack;
        await frame(exact);
        expect(cubit.state.items.first.read, isTrue);
        expect(
          cubit.state.unreadCount,
          2,
        ); // No speculative decrement of absent row.
      },
    );

    test(
      'ACK during loadMore protects its late page without changing order',
      () async {
        final more = cubit.loadMore();
        final external = _notification('external');
        await cubit.applyConfirmedExternalRead(external, sessions.session);
        repository.listRequests.last.complete(page([sibling, external]));
        await more;
        expect(cubit.state.items.map((item) => item.id), [
          'exact',
          'sibling',
          'external',
        ]);
        expect(cubit.state.items.last.read, isTrue);
        expect(cubit.state.items.take(2).every((item) => !item.read), isTrue);
        expect(cubit.state.unreadCount, 2);
      },
    );

    test(
      'new authoritative badge wins over external count and protected frames',
      () async {
        repository.unreadRequest = Completer<Result<int>>();
        final external = _notification('external');
        final ack = cubit.applyConfirmedExternalRead(
          external,
          sessions.session,
        );
        realtime.emitBadge(9);
        await frame(external);
        repository.unreadRequest!.complete(const Result.success(2));
        await ack;
        await frame(external);
        expect(cubit.state.items.first.read, isTrue);
        expect(cubit.state.unreadCount, 9);
      },
    );

    test(
      'clear-all keeps a concurrent unknown ACK and still verifies frames through REST',
      () async {
        repository.clearAllRequest = Completer<Result<int>>();
        final clear = cubit.clearAllNotifications();
        final external = _notification('external');
        await cubit.applyConfirmedExternalRead(external, sessions.session);
        repository.clearAllRequest!.complete(const Result.success(2));
        await _eventually(() => repository.listRequests.length == 2);
        repository.unreadResult = const Result.success(0);
        repository.listRequests.last.complete(page([external]));
        await clear;
        expect(cubit.state.items.single.read, isTrue);
        expect(cubit.state.unreadCount, 0);
        await frame(exact); // Known deletion cannot reappear.
        expect(repository.listRequests, hasLength(2));
        await frame(
          external,
        ); // Unknown frames still require server reconciliation.
        expect(repository.listRequests, hasLength(3));
        repository.listRequests.last.complete(page([external]));
        await _eventually(
          () => cubit.state.status == NotificationStatus.success,
        );
        expect(cubit.state.items.single.read, isTrue);
        expect(cubit.state.unreadCount, 0);
      },
    );

    for (final order in ['ARW', 'AWR', 'RAW', 'RWA', 'WAR', 'WRA']) {
      test('ACK/old REST/frame completion order $order', () async {
        repository.markReadRequest = Completer<Result<void>>();
        final ack = cubit.markAsRead(exact);
        final refresh = cubit.refresh();
        for (final step in order.split('')) {
          switch (step) {
            case 'A':
              repository.markReadRequest!.complete(const Result.success(null));
              await ack;
            case 'R':
              repository.listRequests.last.complete(page([exact, sibling]));
              await refresh;
            case 'W':
              await frame(exact);
          }
        }
        expect(cubit.state.items.map((item) => item.id), ['exact', 'sibling']);
        expect(cubit.state.items.first.read, isTrue);
        expect(cubit.state.items.last.read, isFalse);
        expect(cubit.state.unreadCount, 1);
      });
    }

    test(
      'DM exact ACK survives refresh and frame without reading its sibling',
      () async {
        final first = _notification(
          'dm-1',
          type: 'DM_NEW_MESSAGE',
          payload: {'conversationId': 'same', 'messageId': 'one'},
        );
        final second = _notification(
          'dm-2',
          type: 'DM_NEW_MESSAGE',
          payload: {'conversationId': 'same', 'messageId': 'two'},
        );
        await refreshWith([first, second]);
        cubit.markDmMessageAsReadLocally('one');
        repository.unreadResult = const Result.success(1);
        await refreshWith([first, second]);
        await frame(first);
        await frame(second);
        expect(cubit.state.items.first.read, isTrue);
        expect(cubit.state.items.last.read, isFalse);
        expect(cubit.state.unreadCount, 1);
      },
    );

    for (final ackSucceeds in [true, false]) {
      for (final newerBadge in [false, true]) {
        test(
          'delete rollback preserves ACK=$ackSucceeds and newer badge=$newerBadge',
          () async {
            // Put exact last so rollback also proves preservation of position.
            await refreshWith([sibling, exact]);
            repository.markReadRequest = Completer<Result<void>>();
            repository.deleteRequest = Completer<Result<void>>();
            final ack = cubit.markAsRead(exact);
            final deletion = cubit.deleteNotification(exact);
            expect(cubit.state.items.single.id, sibling.id);
            expect(cubit.state.unreadCount, 1);
            repository.markReadRequest!.complete(
              ackSucceeds
                  ? const Result.success(null)
                  : const Result.failure(
                      AppError(code: 'ack', message: 'ACK failed'),
                    ),
            );
            await ack;
            if (newerBadge) {
              realtime.emitBadge(7);
              await Future<void>.delayed(Duration.zero);
            }
            repository.deleteRequest!.complete(
              const Result.failure(
                AppError(code: 'delete', message: 'Delete failed'),
              ),
            );
            await deletion;
            final expectedCount = newerBadge ? 7 : (ackSucceeds ? 1 : 2);
            expect(cubit.state.items.map((item) => item.id), [
              'sibling',
              'exact',
            ]);
            expect(cubit.state.items.last.read, ackSucceeds);
            expect(cubit.state.items.first.read, isFalse);
            expect(cubit.state.unreadCount, expectedCount);
            expect(cubit.state.errorMessage, 'Delete failed');
            await frame(exact);
            expect(cubit.state.items.last.read, ackSucceeds);
            expect(cubit.state.unreadCount, expectedCount);
            repository.unreadResult = Result.success(expectedCount);
            await refreshWith([sibling, exact]);
            expect(cubit.state.items.map((item) => item.id), [
              'sibling',
              'exact',
            ]);
            expect(cubit.state.items.last.read, ackSucceeds);
            expect(cubit.state.items.first.read, isFalse);
            expect(cubit.state.unreadCount, expectedCount);
          },
        );
      }
    }

    test(
      'delete rollback keeps confirmed read alongside a new unread arrival',
      () async {
        repository.markReadRequest = Completer<Result<void>>();
        repository.deleteRequest = Completer<Result<void>>();
        final ack = cubit.markAsRead(exact);
        final deletion = cubit.deleteNotification(exact);
        repository.markReadRequest!.complete(const Result.success(null));
        await ack;
        await frame(_notification('new'));
        await frame(_notification('new'));
        repository.deleteRequest!.complete(
          const Result.failure(
            AppError(code: 'delete', message: 'Delete failed'),
          ),
        );
        await deletion;
        expect(cubit.state.items.map((item) => item.id), [
          'exact',
          'new',
          'sibling',
        ]);
        expect(cubit.state.items.first.read, isTrue);
        expect(cubit.state.items.skip(1).every((item) => !item.read), isTrue);
        expect(cubit.state.unreadCount, 2);
      },
    );

    for (final deleteFinishesFirst in [false, true]) {
      test(
        'successful delete wins over ACK, delete first=$deleteFinishesFirst',
        () async {
          repository.markReadRequest = Completer<Result<void>>();
          repository.deleteRequest = Completer<Result<void>>();
          final ack = cubit.markAsRead(exact);
          final deletion = cubit.deleteNotification(exact);
          if (deleteFinishesFirst) {
            repository.deleteRequest!.complete(const Result.success(null));
            await deletion;
          }
          repository.markReadRequest!.complete(const Result.success(null));
          await ack;
          if (!deleteFinishesFirst) {
            repository.deleteRequest!.complete(const Result.success(null));
            await deletion;
          }
          await frame(exact);
          repository.unreadResult = const Result.success(1);
          await refreshWith([exact, sibling]);
          expect(cubit.state.items.single.id, sibling.id);
          expect(cubit.state.items.single.read, isFalse);
          expect(cubit.state.unreadCount, 1);
        },
      );
    }

    test(
      'clear-all tombstone prevents pending delete rollback after ACK',
      () async {
        repository.markReadRequest = Completer<Result<void>>();
        repository.deleteRequest = Completer<Result<void>>();
        final ack = cubit.markAsRead(exact);
        final deletion = cubit.deleteNotification(exact);
        repository.markReadRequest!.complete(const Result.success(null));
        await ack;
        final clear = cubit.clearAllNotifications();
        await _eventually(() => repository.listRequests.length == 2);
        repository.unreadResult = const Result.success(0);
        repository.listRequests.last.complete(page([]));
        await clear;
        repository.deleteRequest!.complete(
          const Result.failure(
            AppError(code: 'delete', message: 'Delete failed'),
          ),
        );
        await deletion;
        await frame(exact);
        expect(cubit.state.items, isEmpty);
        expect(cubit.state.unreadCount, 0);
        expect(cubit.state.errorMessage, isNull);
      },
    );

    for (final change in ['account', 'token', 'role', 'logout']) {
      test(
        '$change clears proof and fences pending ACK and old audience frames',
        () async {
          await cubit.markAsRead(exact);
          repository.markReadRequest = Completer<Result<void>>();
          repository.deleteRequest = Completer<Result<void>>();
          final ack = cubit.markAsRead(sibling);
          final deletion = cubit.deleteNotification(exact);
          final captured = sessions.session;
          final recipient = change == 'account' ? 'user-2' : 'user-1';
          final replacement = audienceSession(
            user: recipient,
            token: change == 'token' ? 'new-token' : 'token',
            role: change == 'role' ? 'ROLE_VENUE' : 'ROLE_MUSICIAN',
          );
          sessions.replace(
            change == 'logout' ? const AuthSession.guest() : replacement,
          );
          await frame(_notification('old-audience'));
          repository.markReadRequest!.complete(const Result.success(null));
          await ack;
          await cubit.applyConfirmedExternalRead(exact, captured);
          if (change == 'logout') {
            expect(cubit.state.items, isEmpty);
            sessions.replace(replacement);
          }
          await _eventually(() => repository.listRequests.length == 2);
          final newExact = _notification(exact.id, recipientId: recipient);
          final newSibling = _notification(sibling.id, recipientId: recipient);
          repository.listRequests.last.complete(page([newExact, newSibling]));
          await _eventually(
            () => cubit.state.status == NotificationStatus.success,
          );
          await frame(newExact);
          await frame(newSibling);
          repository.deleteRequest!.complete(
            const Result.failure(
              AppError(code: 'delete', message: 'Old delete failed'),
            ),
          );
          await deletion;
          expect(cubit.state.items.map((item) => item.id), [
            'exact',
            'sibling',
          ]);
          expect(cubit.state.items.every((item) => !item.read), isTrue);
          expect(cubit.state.unreadCount, 2);
          expect(cubit.state.errorMessage, isNull);
        },
      );
    }
  });
}
