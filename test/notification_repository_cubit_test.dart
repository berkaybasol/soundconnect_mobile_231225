import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/core/pagination/page.dart'
    as pagination;
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/collab_route_args.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/data/models/app_notification_model.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/data/notification_endpoints.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/data/notification_realtime_client.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/data/notification_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/domain/entities/app_notification.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/domain/notification_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/cubit/notification_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/cubit/notification_state.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/screens/notification_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/profile_route_args.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/studio_profile_screen.dart';

void main() {
  test(
    'Collab notification actions select the intended management surface',
    () {
      CollabDiscoveryRouteArgs args(
        String action, {
        String? applicationId,
        String? jobId,
      }) => CollabDiscoveryRouteArgs.fromNotificationPayload(<String, dynamic>{
        'action': action,
        'listingId': 'listing-1',
        if (applicationId != null) 'applicationId': applicationId,
        if (jobId != null) 'jobId': jobId,
      });

      expect(
        args('APPLICATION_RECEIVED', applicationId: 'application-1').target,
        CollabDeepLinkTarget.incomingApplications,
      );
      expect(
        args('APPLICATION_REJECTED', applicationId: 'application-1').target,
        CollabDeepLinkTarget.myApplications,
      );
      expect(
        args('APPLICATION_ACCEPTED', jobId: 'job-1').target,
        CollabDeepLinkTarget.jobs,
      );
      expect(
        args('JOB_COMPLETION_REQUESTED', jobId: 'job-1').target,
        CollabDeepLinkTarget.jobs,
      );
      expect(args('REPORT_RESOLVED').target, CollabDeepLinkTarget.discovery);
    },
  );

  group('AppNotificationModel', () {
    test('parses values and safely converts loosely typed payload maps', () {
      final model = AppNotificationModel.fromJson(<String, dynamic>{
        'id': 9,
        'recipientId': 'user-1',
        'type': 'DM_MESSAGE',
        'message': 'Hello',
        'read': true,
        'createdAt': '2026-07-13T11:30:00Z',
        'payload': <Object?, Object?>{'conversationId': 12},
      });

      expect(model.id, '9');
      expect(model.title, 'Bildirim');
      expect(model.read, isTrue);
      expect(model.createdAt, DateTime.utc(2026, 7, 13, 11, 30));
      expect(model.payload, <String, dynamic>{'conversationId': 12});
    });

    test('uses safe defaults for malformed dates and payloads', () {
      final model = AppNotificationModel.fromJson(<String, dynamic>{
        'read': 'true',
        'createdAt': 'bad-date',
        'payload': <Object?>[],
      });

      expect(model.read, isFalse);
      expect(model.createdAt, isNull);
      expect(model.payload, isEmpty);
    });
  });

  group('NotificationRepositoryImpl', () {
    test('decodes a page and sends stable pagination and sort query', () async {
      final apiClient = _NotificationApiClientFake((path, query) async {
        expect(path, NotificationEndpoints.list);
        return <String, dynamic>{
          'number': 3,
          'last': false,
          'content': <Object?>[
            <String, dynamic>{'id': 'n-1', 'title': 'One'},
            'ignored',
          ],
        };
      });
      final repository = NotificationRepositoryImpl(apiClient);

      final result = await repository.listNotifications(page: 3, size: 7);

      expect(result.data?.items.single.id, 'n-1');
      expect(result.data?.hasNext, isTrue);
      expect(result.data?.nextCursor, '4');
      expect(apiClient.lastQuery, <String, dynamic>{
        'page': 3,
        'size': 7,
        'sort': 'createdAt,desc',
      });
    });

    test(
      'decodes numeric counters and missing counter values as zero',
      () async {
        var call = 0;
        final repository = NotificationRepositoryImpl(
          _NotificationApiClientFake((_, __) async {
            call += 1;
            return call == 1
                ? <String, dynamic>{'unread': 8.9}
                : <String, dynamic>{};
          }),
        );

        final first = await repository.getUnreadCount();
        final second = await repository.getUnreadCount();

        expect(first.data, 8);
        expect(second.data, 0);
      },
    );

    test('preserves typed errors and maps unexpected failures', () async {
      const typed = AppError(code: '401', message: 'Unauthorized');
      final typedRepository = NotificationRepositoryImpl(
        _NotificationApiClientFake((_, __) => throw ApiException(typed)),
      );
      final unknownRepository = NotificationRepositoryImpl(
        _NotificationApiClientFake((_, __) => throw StateError('bad payload')),
      );

      final typedResult = await typedRepository.getRecentNotifications();
      final unknownResult = await unknownRepository.getUnreadCount();

      expect(typedResult.error, same(typed));
      expect(unknownResult.error?.code, 'notification_unread_unknown');
    });
  });

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

  testWidgets('notification target opens before mark-as-read completes', (
    tester,
  ) async {
    final notification = _notification(
      'collab-pending-read',
      type: 'COLLAB_APPLICATION_RECEIVED',
      payload: const <String, dynamic>{
        'module': 'COLLAB',
        'action': 'APPLICATION_RECEIVED',
        'listingId': 'listing-1',
      },
    );
    final repository = _NotificationRepositoryFake(
      pages: <int, Result<pagination.Page<AppNotification>>>{
        0: Result.success(
          pagination.Page<AppNotification>(
            items: <AppNotification>[notification],
            hasNext: false,
          ),
        ),
      },
    )..markReadRequest = Completer<Result<void>>();
    final realtime = _TestNotificationRealtimeClient();
    final cubit = NotificationCubit(
      repository,
      _MemoryTokenStore(),
      realtimeClient: realtime,
    );
    addTearDown(() async {
      if (!(repository.markReadRequest?.isCompleted ?? true)) {
        repository.markReadRequest!.complete(const Result.success(null));
      }
      await cubit.close();
      await realtime.closeStreams();
    });
    RouteSettings? pushedSettings;

    await tester.pumpWidget(
      BlocProvider<NotificationCubit>.value(
        value: cubit,
        child: MaterialApp(
          home: const NotificationScreen(),
          onGenerateRoute: (settings) {
            pushedSettings = settings;
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const SizedBox.shrink(),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('collab-pending-read'));
    await tester.pump();

    expect(pushedSettings?.name, AppRoutes.collabDiscovery);
    expect(repository.markReadRequest!.isCompleted, isFalse);
    repository.markReadRequest!.complete(const Result.success(null));
    await tester.pump();
  });

  testWidgets(
    'customer cancellation notification opens the Studio owner calendar',
    (tester) async {
      final notification = _notification(
        'cancelled-by-customer',
        type: 'STUDIO_RESERVATION_CANCELLED_BY_CUSTOMER',
        payload: <String, dynamic>{
          'module': 'STUDIO',
          'action': 'CANCELLED_BY_CUSTOMER',
          'roomId': 'room-1',
          'studioProfileId': 'studio-1',
          'reservationId': 'reservation-1',
          'localDate': '2026-08-03',
          'zoneId': 'Europe/Istanbul',
        },
      );
      final repository = _NotificationRepositoryFake(
        pages: <int, Result<pagination.Page<AppNotification>>>{
          0: Result.success(
            pagination.Page<AppNotification>(
              items: <AppNotification>[notification],
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
      RouteSettings? pushedSettings;

      await tester.pumpWidget(
        BlocProvider<NotificationCubit>.value(
          value: cubit,
          child: MaterialApp(
            home: const NotificationScreen(),
            onGenerateRoute: (settings) {
              pushedSettings = settings;
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => const SizedBox.shrink(),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('cancelled-by-customer'));
      await tester.pumpAndSettle();

      expect(pushedSettings?.name, AppRoutes.studioReservationCalendar);
      final args = pushedSettings?.arguments as StudioReservationCalendarArgs;
      expect(args.ownerMode, isTrue);
      expect(args.roomId, 'room-1');
      expect(args.studioProfileId, 'studio-1');
      expect(args.reservationId, 'reservation-1');
      expect(args.reservationDate, DateTime(2026, 8, 3));
    },
  );

  testWidgets(
    'archived-room cancellation opens the Studio profile instead of a dead room',
    (tester) async {
      final notification = _notification(
        'archived-room',
        type: 'STUDIO_RESERVATION_CANCELLED_BY_STUDIO',
        payload: <String, dynamic>{
          'module': 'STUDIO',
          'action': 'CANCELLED_BY_STUDIO_ROOM_ARCHIVED',
          'roomId': 'archived-room-1',
          'studioProfileId': 'studio-1',
          'reservationId': 'reservation-1',
        },
      );
      final repository = _NotificationRepositoryFake(
        pages: <int, Result<pagination.Page<AppNotification>>>{
          0: Result.success(
            pagination.Page<AppNotification>(
              items: <AppNotification>[notification],
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
      RouteSettings? pushedSettings;

      await tester.pumpWidget(
        BlocProvider<NotificationCubit>.value(
          value: cubit,
          child: MaterialApp(
            home: const NotificationScreen(),
            onGenerateRoute: (settings) {
              pushedSettings = settings;
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => const SizedBox.shrink(),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('archived-room'));
      await tester.pumpAndSettle();

      expect(pushedSettings?.name, AppRoutes.studioPublicProfile);
      final args = pushedSettings?.arguments as PublicProfileArgs;
      expect(args.profileId, 'studio-1');
    },
  );

  testWidgets('Collab review notification preserves its deep-link ids', (
    tester,
  ) async {
    final notification = _notification(
      'collab-review',
      type: 'COLLAB_REVIEW_RECEIVED',
      payload: <String, dynamic>{
        'module': 'COLLAB',
        'action': 'REVIEW_RECEIVED',
        'listingId': 'listing-1',
        'jobId': 'job-1',
        'reviewId': 'review-1',
      },
    );
    final repository = _NotificationRepositoryFake(
      pages: <int, Result<pagination.Page<AppNotification>>>{
        0: Result.success(
          pagination.Page<AppNotification>(
            items: <AppNotification>[notification],
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
    RouteSettings? pushedSettings;

    await tester.pumpWidget(
      BlocProvider<NotificationCubit>.value(
        value: cubit,
        child: MaterialApp(
          home: const NotificationScreen(),
          onGenerateRoute: (settings) {
            pushedSettings = settings;
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const SizedBox.shrink(),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('collab-review'));
    await tester.pumpAndSettle();

    expect(pushedSettings?.name, AppRoutes.collabDiscovery);
    final args = pushedSettings?.arguments as CollabDiscoveryRouteArgs;
    expect(args.target, CollabDeepLinkTarget.reviews);
    expect(args.initialListingId, 'listing-1');
    expect(args.jobId, 'job-1');
    expect(args.reviewId, 'review-1');
  });
}

AppNotification _notification(
  String id, {
  String recipientId = 'user-1',
  String type = 'GENERAL',
  bool read = false,
  Map<String, dynamic> payload = const <String, dynamic>{},
}) {
  return AppNotification(
    id: id,
    recipientId: recipientId,
    type: type,
    title: id,
    message: 'Message',
    read: read,
    createdAt: null,
    payload: payload,
  );
}

class _NotificationApiClientFake extends ApiClient {
  _NotificationApiClientFake(this.handler);

  final Future<Object?> Function(String path, Map<String, dynamic>? query)
  handler;
  Map<String, dynamic>? lastQuery;

  @override
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    T Function(Object? json)? decoder,
  }) async {
    lastQuery = query;
    final payload = await handler(path, query);
    return decoder == null ? payload as T : decoder(payload);
  }

  @override
  Future<T> delete<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) => throw UnimplementedError();

  @override
  Future<T> patch<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) => throw UnimplementedError();

  @override
  Future<T> post<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) => throw UnimplementedError();

  @override
  Future<T> put<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) => throw UnimplementedError();
}

class _NotificationRepositoryFake implements NotificationRepository {
  _NotificationRepositoryFake({
    required this.pages,
    this.unread = const Result.success(0),
  });

  final Map<int, Result<pagination.Page<AppNotification>>> pages;
  final Result<int> unread;
  final List<int> requestedPages = <int>[];
  Result<void> deleteResult = const Result.success(null);
  Completer<Result<void>>? markReadRequest;

  @override
  Future<Result<pagination.Page<AppNotification>>> listNotifications({
    int page = 0,
    int size = 20,
  }) async {
    requestedPages.add(page);
    return pages[page] ??
        const Result.success(
          pagination.Page<AppNotification>(items: [], hasNext: false),
        );
  }

  @override
  Future<Result<int>> getUnreadCount() async => unread;

  @override
  Future<Result<void>> deleteNotification({
    required String notificationId,
  }) async => deleteResult;

  @override
  Future<Result<int>> clearAllNotifications() async => const Result.success(0);

  @override
  Future<Result<List<AppNotification>>> getRecentNotifications() async =>
      const Result.success(<AppNotification>[]);

  @override
  Future<Result<int>> markAllAsRead() async => const Result.success(0);

  @override
  Future<Result<void>> markAsRead({required String notificationId}) async {
    return markReadRequest?.future ?? const Result.success(null);
  }
}

class _ControlledNotificationRepository implements NotificationRepository {
  final List<Completer<Result<pagination.Page<AppNotification>>>> listRequests =
      <Completer<Result<pagination.Page<AppNotification>>>>[];
  Result<int> unreadResult = const Result.success(0);
  Completer<Result<int>>? unreadRequest;
  int unreadCalls = 0;
  Completer<Result<int>>? markAllRequest;
  Completer<Result<int>>? clearAllRequest;

  @override
  Future<Result<pagination.Page<AppNotification>>> listNotifications({
    int page = 0,
    int size = 20,
  }) {
    final request = Completer<Result<pagination.Page<AppNotification>>>();
    listRequests.add(request);
    return request.future;
  }

  @override
  Future<Result<int>> getUnreadCount() async {
    unreadCalls += 1;
    return unreadRequest?.future ?? unreadResult;
  }

  @override
  Future<Result<int>> clearAllNotifications() async =>
      clearAllRequest?.future ?? const Result.success(0);

  @override
  Future<Result<void>> deleteNotification({
    required String notificationId,
  }) async => const Result.success(null);

  @override
  Future<Result<List<AppNotification>>> getRecentNotifications() async =>
      const Result.success(<AppNotification>[]);

  @override
  Future<Result<int>> markAllAsRead() async =>
      markAllRequest?.future ?? const Result.success(0);

  @override
  Future<Result<void>> markAsRead({required String notificationId}) async =>
      const Result.success(null);
}

class _TestNotificationRealtimeClient extends NotificationRealtimeClient {
  final StreamController<AppNotification> _notificationController =
      StreamController<AppNotification>.broadcast();
  final StreamController<int> _badgeController =
      StreamController<int>.broadcast();
  final StreamController<void> _connectionController =
      StreamController<void>.broadcast();
  bool _connected = false;

  @override
  Stream<AppNotification> get notificationStream =>
      _notificationController.stream;

  @override
  Stream<int> get badgeStream => _badgeController.stream;

  @override
  Stream<void> get connectionStream => _connectionController.stream;

  @override
  bool get isConnected => _connected;

  @override
  void retain() {}

  @override
  Future<void> release() async {}

  @override
  Future<void> connect({required String userId, required String token}) async {
    _connected = true;
    _connectionController.add(null);
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
  }

  void emitNotification(AppNotification notification) {
    _notificationController.add(notification);
  }

  void emitBadge(int count) {
    _badgeController.add(count);
  }

  Future<void> closeStreams() async {
    await super.dispose();
    await _notificationController.close();
    await _badgeController.close();
    await _connectionController.close();
  }
}

class _MemoryTokenStore implements TokenStore {
  String? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<String?> readToken() async => value;

  @override
  Future<void> writeToken(String token) async => value = token;
}

String _jwt(String subject) {
  String encode(Map<String, dynamic> value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${encode(const <String, dynamic>{'alg': 'none'})}.'
      '${encode(<String, dynamic>{'sub': subject})}.signature';
}

Future<void> _eventually(bool Function() predicate) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (predicate()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(predicate(), isTrue);
}
