part of 'notification_repository_cubit_test.dart';

void _registerNotificationCubitTests() {
  group('NotificationCubit', () {
    test('refreshes and paginates while preserving server order', () async {
      final repository = _NotificationRepositoryFake(
        pages: <int, Result<pagination.Page<AppNotification>>>{
          0: Result.success(
            pagination.Page<AppNotification>(
              items: <AppNotification>[_notification('n-1')],
              hasNext: true,
            ),
          ),
          1: Result.success(
            pagination.Page<AppNotification>(
              items: <AppNotification>[_notification('n-2')],
              hasNext: false,
            ),
          ),
        },
        unread: const Result.success(4),
      );
      final realtime = NotificationRealtimeClient();
      final cubit = NotificationCubit(
        repository,
        _MemoryTokenStore(),
        realtimeClient: realtime,
      );
      addTearDown(() async {
        await cubit.close();
        await realtime.dispose();
      });

      await cubit.refresh();
      await cubit.loadMore();

      expect(cubit.state.status, NotificationStatus.success);
      expect(cubit.state.items.map((item) => item.id), <String>['n-1', 'n-2']);
      expect(cubit.state.unreadCount, 4);
      expect(cubit.state.page, 1);
      expect(cubit.state.hasNext, isFalse);
      expect(repository.requestedPages, <int>[0, 1]);
    });

    test('deduplicates shifted offset pages by notification id', () async {
      final repository = _NotificationRepositoryFake(
        pages: <int, Result<pagination.Page<AppNotification>>>{
          0: Result.success(
            pagination.Page<AppNotification>(
              items: <AppNotification>[
                _notification('n-1'),
                _notification('n-2'),
              ],
              hasNext: true,
            ),
          ),
          1: Result.success(
            pagination.Page<AppNotification>(
              items: <AppNotification>[
                _notification('n-2'),
                _notification('n-3'),
                _notification('n-3'),
              ],
              hasNext: false,
            ),
          ),
        },
      );
      final realtime = NotificationRealtimeClient();
      final cubit = NotificationCubit(
        repository,
        _MemoryTokenStore(),
        realtimeClient: realtime,
      );
      addTearDown(() async {
        await cubit.close();
        await realtime.dispose();
      });

      await cubit.refresh();
      await cubit.loadMore();

      expect(cubit.state.items.map((item) => item.id), <String>[
        'n-1',
        'n-2',
        'n-3',
      ]);
      expect(cubit.state.page, 1);
      expect(cubit.state.hasNext, isFalse);
    });

    test('keeps loaded data when a later page fails', () async {
      const error = AppError(code: 'offline', message: 'Offline');
      final repository = _NotificationRepositoryFake(
        pages: <int, Result<pagination.Page<AppNotification>>>{
          0: Result.success(
            pagination.Page<AppNotification>(
              items: <AppNotification>[_notification('n-1')],
              hasNext: true,
            ),
          ),
          1: const Result.failure(error),
        },
      );
      final realtime = NotificationRealtimeClient();
      final cubit = NotificationCubit(
        repository,
        _MemoryTokenStore(),
        realtimeClient: realtime,
      );
      addTearDown(() async {
        await cubit.close();
        await realtime.dispose();
      });

      await cubit.refresh();
      await cubit.loadMore();

      expect(cubit.state.status, NotificationStatus.success);
      expect(cubit.state.items.single.id, 'n-1');
      expect(cubit.state.page, 0);
      expect(cubit.state.errorMessage, 'Offline');
    });

    test(
      'marks only matching DM notifications and keeps the remaining unread',
      () async {
        final repository = _NotificationRepositoryFake(
          pages: <int, Result<pagination.Page<AppNotification>>>{
            0: Result.success(
              pagination.Page<AppNotification>(
                items: <AppNotification>[
                  _notification(
                    'dm-1',
                    type: 'DM_MESSAGE',
                    payload: <String, dynamic>{'conversationId': 'c-1'},
                  ),
                  _notification(
                    'dm-2',
                    type: 'OTHER',
                    payload: <String, dynamic>{
                      'module': 'DM',
                      'conversationId': 'c-1',
                    },
                  ),
                  _notification(
                    'other',
                    payload: <String, dynamic>{'conversationId': 'c-2'},
                  ),
                ],
                hasNext: false,
              ),
            ),
          },
          unread: const Result.success(1),
        );
        final realtime = NotificationRealtimeClient();
        final cubit = NotificationCubit(
          repository,
          _MemoryTokenStore(),
          realtimeClient: realtime,
        );
        addTearDown(() async {
          await cubit.close();
          await realtime.dispose();
        });
        await cubit.refresh();

        cubit.markDmConversationAsReadLocally(' c-1 ');

        expect(cubit.state.items[0].read, isTrue);
        expect(cubit.state.items[1].read, isTrue);
        expect(cubit.state.items[2].read, isFalse);
        expect(cubit.state.unreadCount, 1);
      },
    );

    test(
      'successful delete adjusts unread count but failed delete does not',
      () async {
        const error = AppError(code: 'delete_failed', message: 'Delete failed');
        final first = _notification('n-1');
        final second = _notification('n-2');
        final repository = _NotificationRepositoryFake(
          pages: <int, Result<pagination.Page<AppNotification>>>{
            0: Result.success(
              pagination.Page<AppNotification>(
                items: <AppNotification>[first, second],
                hasNext: false,
              ),
            ),
          },
          unread: const Result.success(2),
        );
        final realtime = NotificationRealtimeClient();
        final cubit = NotificationCubit(
          repository,
          _MemoryTokenStore(),
          realtimeClient: realtime,
        );
        addTearDown(() async {
          await cubit.close();
          await realtime.dispose();
        });
        await cubit.refresh();

        await cubit.deleteNotification(first);
        repository.deleteResult = const Result.failure(error);
        await cubit.deleteNotification(second);

        expect(cubit.state.items.map((item) => item.id), <String>['n-2']);
        expect(cubit.state.unreadCount, 1);
        expect(cubit.state.errorMessage, 'Delete failed');
      },
    );

    test(
      'a newer refresh response cannot be overwritten by an older one',
      () async {
        final repository = _ControlledNotificationRepository();
        final realtime = _TestNotificationRealtimeClient();
        final cubit = NotificationCubit(
          repository,
          _MemoryTokenStore(),
          realtimeClient: realtime,
        );
        addTearDown(() async {
          await cubit.close();
          await realtime.closeStreams();
        });

        final olderRefresh = cubit.refresh();
        await _eventually(() => repository.listRequests.length == 1);
        final newerRefresh = cubit.refresh();
        await _eventually(() => repository.listRequests.length == 2);
        repository.listRequests[1].complete(
          Result.success(
            pagination.Page<AppNotification>(
              items: <AppNotification>[_notification('newer')],
              hasNext: false,
            ),
          ),
        );
        await newerRefresh;
        repository.listRequests[0].complete(
          Result.success(
            pagination.Page<AppNotification>(
              items: <AppNotification>[_notification('older')],
              hasNext: false,
            ),
          ),
        );
        await olderRefresh;

        expect(cubit.state.items.single.id, 'newer');
      },
    );

    test(
      'refresh preserves a realtime item received while REST is pending',
      () async {
        final repository = _ControlledNotificationRepository();
        final realtime = _TestNotificationRealtimeClient();
        final tokenStore = _MemoryTokenStore()..value = _jwt('user-1');
        final cubit = NotificationCubit(
          repository,
          tokenStore,
          realtimeClient: realtime,
        );
        addTearDown(() async {
          await cubit.close();
          await realtime.closeStreams();
        });

        final start = cubit.ensureStarted();
        await _eventually(() => repository.listRequests.length == 1);
        realtime.emitNotification(_notification('realtime'));
        await Future<void>.delayed(Duration.zero);
        repository.listRequests.single.complete(
          Result.success(
            pagination.Page<AppNotification>(
              items: <AppNotification>[_notification('server')],
              hasNext: false,
            ),
          ),
        );
        await start;

        expect(cubit.state.items.map((item) => item.id), <String>[
          'realtime',
          'server',
        ]);
        expect(cubit.state.unreadCount, 2);
      },
    );

    test(
      'refresh never reports fewer unread items than its server page',
      () async {
        final repository = _ControlledNotificationRepository()
          ..unreadRequest = Completer<Result<int>>();
        final realtime = _TestNotificationRealtimeClient();
        final cubit = NotificationCubit(
          repository,
          _MemoryTokenStore()..value = _jwt('user-1'),
          realtimeClient: realtime,
        );
        addTearDown(() async {
          await cubit.close();
          await realtime.closeStreams();
        });

        final start = cubit.ensureStarted();
        await _eventually(() => repository.listRequests.length == 1);
        repository.listRequests.single.complete(
          Result.success(
            pagination.Page<AppNotification>(
              items: <AppNotification>[_notification('committed-unread')],
              hasNext: false,
            ),
          ),
        );
        await _eventually(() => repository.unreadCalls == 1);
        repository.unreadRequest!.complete(const Result.success(0));
        await start;

        expect(cubit.state.items.single.id, 'committed-unread');
        expect(cubit.state.unreadCount, 1);
      },
    );

    test(
      'badge arriving during unread REST wins over its stale response',
      () async {
        final repository = _ControlledNotificationRepository()
          ..unreadRequest = Completer<Result<int>>();
        final realtime = _TestNotificationRealtimeClient();
        final cubit = NotificationCubit(
          repository,
          _MemoryTokenStore()..value = _jwt('user-1'),
          realtimeClient: realtime,
        );
        addTearDown(() async {
          await cubit.close();
          await realtime.closeStreams();
        });

        final start = cubit.ensureStarted();
        await _eventually(() => repository.listRequests.length == 1);
        repository.listRequests.single.complete(
          Result.success(
            pagination.Page<AppNotification>(
              items: <AppNotification>[_notification('now-read', read: true)],
              hasNext: false,
            ),
          ),
        );
        await _eventually(() => repository.unreadCalls == 1);
        realtime.emitBadge(0);
        await Future<void>.delayed(Duration.zero);
        repository.unreadRequest!.complete(const Result.success(1));
        await start;

        expect(cubit.state.items.single.read, isTrue);
        expect(cubit.state.unreadCount, 0);
      },
    );

    test('a mutation finishing after stop cannot revive user data', () async {
      final notification = _notification('n-1');
      final repository = _NotificationRepositoryFake(
        pages: <int, Result<pagination.Page<AppNotification>>>{
          0: Result.success(
            pagination.Page<AppNotification>(
              items: <AppNotification>[notification],
              hasNext: false,
            ),
          ),
        },
        unread: const Result.success(1),
      );
      final realtime = _TestNotificationRealtimeClient();
      final cubit = NotificationCubit(
        repository,
        _MemoryTokenStore(),
        realtimeClient: realtime,
      );
      addTearDown(() async {
        await cubit.close();
        await realtime.closeStreams();
      });
      await cubit.refresh();
      repository.markReadRequest = Completer<Result<void>>();

      final mark = cubit.markAsRead(notification);
      await cubit.stop();
      repository.markReadRequest!.complete(const Result.success(null));
      await mark;

      expect(cubit.state.initialized, isFalse);
      expect(cubit.state.items, isEmpty);
      expect(cubit.state.unreadCount, 0);
    });

    test(
      'a mutation from the previous active user cannot alter the new user',
      () async {
        final firstUserItem = _notification('shared-id');
        final secondUserItem = _notification('shared-id');
        final repository = _NotificationRepositoryFake(
          pages: <int, Result<pagination.Page<AppNotification>>>{
            0: Result.success(
              pagination.Page<AppNotification>(
                items: <AppNotification>[firstUserItem],
                hasNext: false,
              ),
            ),
          },
          unread: const Result.success(1),
        );
        final tokenStore = _MemoryTokenStore()..value = _jwt('user-1');
        final realtime = _TestNotificationRealtimeClient();
        final cubit = NotificationCubit(
          repository,
          tokenStore,
          realtimeClient: realtime,
        );
        addTearDown(() async {
          await cubit.close();
          await realtime.closeStreams();
        });
        await cubit.ensureStarted();
        repository.markReadRequest = Completer<Result<void>>();
        final oldMutation = cubit.markAsRead(firstUserItem);

        repository.pages[0] = Result.success(
          pagination.Page<AppNotification>(
            items: <AppNotification>[secondUserItem],
            hasNext: false,
          ),
        );
        tokenStore.value = _jwt('user-2');
        await cubit.ensureStarted();
        repository.markReadRequest!.complete(const Result.success(null));
        await oldMutation;
        realtime.emitNotification(
          _notification('wrong-recipient', recipientId: 'user-1'),
        );
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.items.single.id, 'shared-id');
        expect(cubit.state.items.single.read, isFalse);
        expect(cubit.state.unreadCount, 1);
      },
    );

    test(
      'an in-flight refresh from the previous user never emits into the new session',
      () async {
        final firstUserItem = _notification(
          'user-a-item',
          recipientId: 'user-a',
        );
        final secondUserItem = _notification(
          'user-b-item',
          recipientId: 'user-b',
        );
        final repository = _ControlledNotificationRepository()
          ..unreadResult = const Result.success(1);
        final tokenStore = _MemoryTokenStore()..value = _jwt('user-a');
        final realtime = _TestNotificationRealtimeClient();
        final cubit = NotificationCubit(
          repository,
          tokenStore,
          realtimeClient: realtime,
        );
        var recordPostSwitchStates = false;
        var leakedFirstUserState = false;
        final stateSubscription = cubit.stream.listen((state) {
          if (!recordPostSwitchStates) return;
          if (state.unreadCount == 91 ||
              state.items.any((item) => item.id == firstUserItem.id)) {
            leakedFirstUserState = true;
          }
        });
        addTearDown(() async {
          await stateSubscription.cancel();
          await cubit.close();
          await realtime.closeStreams();
        });

        final initialStart = cubit.ensureStarted();
        await _eventually(() => repository.listRequests.length == 1);
        repository.listRequests.single.complete(
          Result.success(
            pagination.Page<AppNotification>(
              items: <AppNotification>[firstUserItem],
              hasNext: false,
            ),
          ),
        );
        await initialStart;

        repository.unreadResult = const Result.success(91);
        realtime.emitBadge(91);
        await _eventually(() => repository.listRequests.length == 2);

        tokenStore.value = _jwt('user-b');
        final switchUser = cubit.ensureStarted();
        await _eventually(
          () => cubit.state.items.isEmpty && cubit.state.unreadCount == 0,
        );
        recordPostSwitchStates = true;
        repository.unreadResult = const Result.success(2);
        repository.listRequests[1].complete(
          Result.success(
            pagination.Page<AppNotification>(
              items: <AppNotification>[firstUserItem],
              hasNext: false,
            ),
          ),
        );
        await _eventually(() => repository.listRequests.length == 3);
        repository.listRequests[2].complete(
          Result.success(
            pagination.Page<AppNotification>(
              items: <AppNotification>[secondUserItem],
              hasNext: false,
            ),
          ),
        );
        await switchUser;

        expect(leakedFirstUserState, isFalse);
        expect(cubit.state.items.single.id, 'user-b-item');
        expect(cubit.state.unreadCount, 2);
      },
    );

    test(
      'badge frames reconcile item state without a notification frame',
      () async {
        final original = _notification('n-1');
        final repository = _ControlledNotificationRepository();
        final realtime = _TestNotificationRealtimeClient();
        final cubit = NotificationCubit(
          repository,
          _MemoryTokenStore()..value = _jwt('user-1'),
          realtimeClient: realtime,
        );
        addTearDown(() async {
          await cubit.close();
          await realtime.closeStreams();
        });

        final start = cubit.ensureStarted();
        await _eventually(() => repository.listRequests.length == 1);
        repository.listRequests.single.complete(
          Result.success(
            pagination.Page<AppNotification>(
              items: <AppNotification>[original],
              hasNext: false,
            ),
          ),
        );
        await start;

        realtime.emitBadge(0);
        await _eventually(() => repository.listRequests.length == 2);
        repository.listRequests[1].complete(
          Result.success(
            pagination.Page<AppNotification>(
              items: <AppNotification>[original.copyWith(read: true)],
              hasNext: false,
            ),
          ),
        );
        await _eventually(() => cubit.state.items.single.read);

        expect(cubit.state.unreadCount, 0);
      },
    );

    test(
      'badge arriving during reconciliation queues one follow-up refresh',
      () async {
        final original = _notification('n-1');
        final repository = _ControlledNotificationRepository();
        final realtime = _TestNotificationRealtimeClient();
        final cubit = NotificationCubit(
          repository,
          _MemoryTokenStore()..value = _jwt('user-1'),
          realtimeClient: realtime,
        );
        addTearDown(() async {
          await cubit.close();
          await realtime.closeStreams();
        });

        final start = cubit.ensureStarted();
        await _eventually(() => repository.listRequests.length == 1);
        repository.listRequests.single.complete(
          Result.success(
            pagination.Page<AppNotification>(
              items: <AppNotification>[original],
              hasNext: false,
            ),
          ),
        );
        await start;

        realtime.emitBadge(1);
        await _eventually(() => repository.listRequests.length == 2);
        realtime.emitBadge(0);
        await Future<void>.delayed(const Duration(milliseconds: 300));
        expect(repository.listRequests, hasLength(2));

        repository.listRequests[1].complete(
          Result.success(
            pagination.Page<AppNotification>(
              items: <AppNotification>[original],
              hasNext: false,
            ),
          ),
        );
        await _eventually(() => repository.listRequests.length == 3);
        repository.listRequests[2].complete(
          Result.success(
            pagination.Page<AppNotification>(items: const [], hasNext: false),
          ),
        );
        await _eventually(() => cubit.state.items.isEmpty);

        expect(repository.listRequests, hasLength(3));
        expect(cubit.state.unreadCount, 0);
      },
    );

    test(
      'mark-all refresh keeps a notification arriving in flight unread',
      () async {
        final old = _notification('old');
        final fresh = _notification('fresh');
        final repository = _ControlledNotificationRepository()
          ..markAllRequest = Completer<Result<int>>();
        final realtime = _TestNotificationRealtimeClient();
        final cubit = NotificationCubit(
          repository,
          _MemoryTokenStore()..value = _jwt('user-1'),
          realtimeClient: realtime,
        );
        addTearDown(() async {
          await cubit.close();
          await realtime.closeStreams();
        });

        final start = cubit.ensureStarted();
        await _eventually(() => repository.listRequests.length == 1);
        repository.listRequests.single.complete(
          Result.success(
            pagination.Page<AppNotification>(
              items: <AppNotification>[old],
              hasNext: false,
            ),
          ),
        );
        await start;

        final markAll = cubit.markAllAsRead();
        realtime.emitNotification(fresh);
        await Future<void>.delayed(Duration.zero);
        repository.unreadResult = const Result.success(1);
        repository.markAllRequest!.complete(const Result.success(1));
        await _eventually(() => repository.listRequests.length == 2);
        repository.listRequests[1].complete(
          Result.success(
            pagination.Page<AppNotification>(
              items: <AppNotification>[fresh, old.copyWith(read: true)],
              hasNext: false,
            ),
          ),
        );
        await markAll;

        expect(cubit.state.items.first.id, 'fresh');
        expect(cubit.state.items.first.read, isFalse);
        expect(cubit.state.items.last.read, isTrue);
        expect(cubit.state.unreadCount, 1);
      },
    );

    test('clear-all refresh keeps a notification arriving in flight', () async {
      final old = _notification('old');
      final fresh = _notification('fresh');
      final repository = _ControlledNotificationRepository()
        ..clearAllRequest = Completer<Result<int>>();
      final realtime = _TestNotificationRealtimeClient();
      final cubit = NotificationCubit(
        repository,
        _MemoryTokenStore()..value = _jwt('user-1'),
        realtimeClient: realtime,
      );
      addTearDown(() async {
        await cubit.close();
        await realtime.closeStreams();
      });

      final start = cubit.ensureStarted();
      await _eventually(() => repository.listRequests.length == 1);
      repository.listRequests.single.complete(
        Result.success(
          pagination.Page<AppNotification>(
            items: <AppNotification>[old],
            hasNext: false,
          ),
        ),
      );
      await start;

      final clearAll = cubit.clearAllNotifications();
      realtime.emitNotification(fresh);
      await Future<void>.delayed(Duration.zero);
      repository.unreadResult = const Result.success(1);
      repository.clearAllRequest!.complete(const Result.success(1));
      await _eventually(() => repository.listRequests.length == 2);
      repository.listRequests[1].complete(
        Result.success(
          pagination.Page<AppNotification>(
            items: <AppNotification>[fresh],
            hasNext: false,
          ),
        ),
      );
      await clearAll;

      expect(cubit.state.items.single.id, 'fresh');
      expect(cubit.state.items.single.read, isFalse);
      expect(cubit.state.unreadCount, 1);
    });
  });
}
