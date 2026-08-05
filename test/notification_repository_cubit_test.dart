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
      'marks only matching DM notifications locally and clamps badge',
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
        expect(cubit.state.unreadCount, 0);
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
}

AppNotification _notification(
  String id, {
  String type = 'GENERAL',
  bool read = false,
  Map<String, dynamic> payload = const <String, dynamic>{},
}) {
  return AppNotification(
    id: id,
    recipientId: 'user-1',
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
  Future<Result<void>> markAsRead({required String notificationId}) async =>
      const Result.success(null);
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
