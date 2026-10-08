import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/studio_profile_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/studio/domain/entities/studio_room.dart';
import 'package:soundconnect_23_12_25codx/modules/studio/domain/entities/studio_reservation.dart';
import 'package:soundconnect_23_12_25codx/modules/studio/domain/entities/studio_page.dart';
import 'package:soundconnect_23_12_25codx/modules/studio/domain/studio_room_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/notification_direct_open.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/notification_target_read.dart';
import 'dart:async';

import 'package:flutter/material.dart' hide Page;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/core/pagination/page.dart';
import 'package:soundconnect_23_12_25codx/core/push/push_provider.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/data/notification_realtime_client.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/data/notification_target_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/domain/entities/app_notification.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/domain/entities/studio_reservation_notification_target.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/domain/notification_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/cubit/notification_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/screens/notification_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/screens/studio_reservation_notification_open_screen.dart';

import 'support/event_audience_fakes.dart';

const _user = '70000000-0000-4000-8000-000000000001';
const _other = '70000000-0000-4000-8000-000000000002';
const _id = '50000000-0000-4000-8000-000000000001';
const _sibling = '50000000-0000-4000-8000-000000000002';
const _reservation = '60000000-0000-4000-8000-000000000001';
const _type = 'STUDIO_RESERVATION_APPROVED';
const _target = PushTarget(
  notificationId: _id,
  recipientId: _user,
  type: _type,
);
const _private = 'private diagnostic must never be displayed';
const _detailKey = ValueKey('studio-reservation-$_reservation');

void main() {
  late _Fixture f;
  setUp(() async {
    await serviceLocator.reset();
    f = _Fixture();
  });
  tearDown(() async {
    await f.dispose();
    await serviceLocator.reset();
  });

  for (final type in PushTarget.studioTypes) {
    test(
      '$type exact target is read-only and token/recipient fenced',
      () async {
        final target = PushTarget.parse({
          'notificationId': _id,
          'recipientId': _user,
          'type': type,
        });
        expect(target?.isStudio, isTrue);
        expect(
          PushTarget.parse({
            'notificationId': _id,
            'recipientId': _user,
            'type': type,
            'conversationId': _reservation,
          }),
          isNull,
        );
        f.api.response = _dto(type: type);
        final result = await f.repository.resolveStudio(
          target!,
          f.sessions.session,
        );
        expect(result.isSuccess, isTrue);
        expect(result.data!.reservationId, _reservation);
        expect(
          f.api.calls.single.path,
          '/api/v1/user/notifications/$_id/studio-reservation',
        );
        expect(
          f.api.calls.single.context?.expectedToken,
          f.sessions.session.token,
        );
        expect(f.api.calls.single.context?.expectedSessionKey, _user);
        expect(f.api.calls.single.method, ApiHttpMethod.get);
        expect(f.api.ackIds, isEmpty);
      },
    );
  }

  for (final change in <String, Object>{
    'notificationId': _sibling,
    'recipientId': _other,
    'type': 'STUDIO_RESERVATION_REJECTED',
    'ownerMode': true,
    'status': 'UNKNOWN',
    'roomId': 'invalid',
    'roomArchived': 'true',
    'completed': 'false',
    'startsAt': '2026-09-24T08:00:00',
    'localDate': '2026-02-31',
    'localStartTime': '28:00',
  }.entries) {
    test('rejects mismatched or malformed ${change.key} without ACK', () async {
      f.api.response = _dto()..[change.key] = change.value;
      expect(
        (await f.repository.resolveStudio(
          _target,
          f.sessions.session,
        )).isSuccess,
        isFalse,
      );
      expect(f.api.ackIds, isEmpty);
    });
  }

  test(
    'studio target is unavailable to listener, guest and application-only sessions',
    () async {
      for (final session in [
        const AuthSession.guest(),
        audienceSession(user: _user, role: 'ROLE_LISTENER'),
        _scopedSession(application: true),
      ]) {
        f.sessions.replace(session);
        expect(
          (await f.repository.resolveStudio(_target, session)).isSuccess,
          isFalse,
        );
      }
      expect(f.api.calls, isEmpty);
    },
  );

  testWidgets(
    'resolver and room lookup cannot ACK before actual exact row is visible',
    (tester) async {
      final resolved = Completer<Object?>();
      final room = Completer<Result<StudioRoom>>();
      f.api.pending = resolved;
      f.rooms.roomPending = room;
      await f.mount(tester);
      expect(find.text('Original'), findsOneWidget);
      f.expectNoMutations();
      resolved.complete(_dto());
      for (var frame = 0; frame < 6; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(StudioReservationCalendarScreen), findsOneWidget);
      expect(find.byKey(_detailKey), findsNothing);
      f.expectNoMutations();
      room.complete(Result.success(f.rooms.room));
      await tester.idle();
      f.expectNoMutations();
      await tester.pumpAndSettle();
      expect(find.byKey(_detailKey), findsOneWidget);
      expect(f.rooms.roomIds, [_roomId]);
      expect(f.rooms.customerDates, [DateTime(2026, 9, 24)]);
      expect(f.api.ackIds, [_id]);
      expect(f.cubit.state.unreadCount, 1);
      expect(
        f.cubit.state.items.singleWhere((r) => r.id == _sibling).read,
        isFalse,
      );
      expect(
        find.byType(StudioReservationNotificationOpenScreen),
        findsNothing,
      );
      expect(find.text('Stüdyo rezervasyonu'), findsNothing);
      f.navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('Original'), findsOneWidget);
      expect(find.byType(StudioReservationCalendarScreen), findsNothing);
    },
  );

  for (final type in PushTarget.studioTypes) {
    testWidgets(
      '$type opens exact existing room/calendar with no report route',
      (tester) async {
        f.api.response = _dto(type: type);
        await f.mount(
          tester,
          target: PushTarget(
            notificationId: _id,
            recipientId: _user,
            type: type,
          ),
        );
        await tester.pumpAndSettle();
        final calendar = tester.widget<StudioReservationCalendarScreen>(
          find.byType(StudioReservationCalendarScreen),
        );
        expect(calendar.args.roomId, _roomId);
        expect(calendar.args.reservationId, _reservation);
        expect(
          calendar.args.ownerMode,
          StudioReservationNotificationTarget.ownerTypes.contains(type),
        );
        expect(find.byKey(_detailKey), findsOneWidget);
        expect(f.api.ackIds, [_id]);
        expect(find.text('Görünüm'), findsNothing);
        expect(find.text('Saat dilimi'), findsNothing);
      },
    );
  }

  testWidgets(
    'owner historical notification keeps exact day and actionable selected reservation',
    (tester) async {
      f.rooms.today = DateTime(2026, 10, 1);
      f.api.response = _dto(type: 'STUDIO_RESERVATION_CREATED');
      await f.mount(
        tester,
        target: const PushTarget(
          notificationId: _id,
          recipientId: _user,
          type: 'STUDIO_RESERVATION_CREATED',
        ),
      );
      await tester.pumpAndSettle();
      expect(f.rooms.ownerDates, [DateTime(2026, 9, 24)]);
      expect(find.text('Seçili rezervasyon'), findsOneWidget);
      expect(find.byKey(_detailKey), findsOneWidget);
      expect(f.api.ackIds, [_id]);
    },
  );

  testWidgets(
    'past customer result stays on real room calendar and reads only visible short message',
    (tester) async {
      f.rooms.today = DateTime(2026, 10, 1);
      f.api.response = _dto()..['completed'] = true;
      await f.mount(tester);
      await tester.pumpAndSettle();
      expect(f.rooms.customerDates, [DateTime(2026, 10, 1)]);
      expect(find.byType(StudioReservationCalendarScreen), findsOneWidget);
      expect(find.byKey(_detailKey), findsNothing);
      expect(find.text('Bu rezervasyonun zamanı geçti.'), findsOneWidget);
      expect(f.api.ackIds, [_id]);
    },
  );

  for (final status in [
    StudioReservationStatus.rejectedByStudio,
    StudioReservationStatus.cancelledByStudio,
    StudioReservationStatus.cancelledByCustomer,
    StudioReservationStatus.expired,
  ]) {
    testWidgets(
      'terminal $status shows ordinary calendar and small result with exact ACK',
      (tester) async {
        f.rooms.status = status;
        await f.mount(tester);
        await tester.pumpAndSettle();
        expect(find.byType(StudioReservationCalendarScreen), findsOneWidget);
        expect(find.byKey(_detailKey), findsOneWidget);
        final row = find.descendant(
          of: find.byKey(_detailKey),
          matching: find.byType(ListTile),
        );
        expect(tester.widget<ListTile>(row).onTap, isNull);
        expect(
          find.descendant(
            of: row,
            matching: find.textContaining(_terminalLabel(status)),
          ),
          findsOneWidget,
        );
        expect(find.byType(SnackBar), findsOneWidget);
        expect(f.api.ackIds, [_id]);
        expect(find.text('İptal et'), findsNothing);
      },
    );
  }

  for (final action in [
    'approve',
    'reject',
    'owner-cancel',
    'customer-cancel-pending',
    'customer-cancel-confirmed',
  ]) {
    testWidgets(
      'selected reservation follows fresh domain state after normal $action',
      (tester) async {
        final customer = action.startsWith('customer');
        f.rooms.status =
            action == 'owner-cancel' || action == 'customer-cancel-confirmed'
            ? StudioReservationStatus.confirmed
            : StudioReservationStatus.pendingApproval;
        f.rooms.requesterId = '';
        final type = customer ? _type : 'STUDIO_RESERVATION_CREATED';
        f.api.response = _dto(type: type);
        await f.mount(
          tester,
          target: PushTarget(
            notificationId: _id,
            recipientId: _user,
            type: type,
          ),
        );
        await tester.pumpAndSettle();
        final row = find.descendant(
          of: find.byKey(_detailKey),
          matching: find.byType(ListTile),
        );
        expect(f.api.ackIds, [_id]);
        final initialLoads = customer
            ? f.rooms.customerDates.length
            : f.rooms.ownerDates.length;
        if (customer) {
          await tester.tap(
            find.descendant(of: row, matching: find.text('İptal et')),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Rezervasyonu İptal Et'));
        } else {
          expect(tester.widget<ListTile>(row).onTap, isNotNull);
          await tester.tap(row);
          await tester.pumpAndSettle();
          final actionLabel = action == 'approve'
              ? 'Rezervasyonu Onayla'
              : action == 'reject'
              ? 'Talebi Reddet'
              : 'Rezervasyonu İptal Et';
          await tester.tap(find.text(actionLabel));
          await tester.pumpAndSettle();
          if (action != 'approve') await tester.tap(find.text(actionLabel));
        }
        await tester.pumpAndSettle();
        final expectedStatus = switch (action) {
          'approve' => StudioReservationStatus.confirmed,
          'reject' => StudioReservationStatus.rejectedByStudio,
          'owner-cancel' => StudioReservationStatus.cancelledByStudio,
          _ => StudioReservationStatus.cancelledByCustomer,
        };
        expect(f.rooms.status, expectedStatus);
        expect(f.rooms.mutations, [customer ? 'customer-cancel' : action]);
        expect(
          customer ? f.rooms.customerDates.length : f.rooms.ownerDates.length,
          initialLoads + 1,
        );
        expect(find.byKey(_detailKey), findsOneWidget);
        expect(
          find.descendant(
            of: row,
            matching: find.textContaining('Onay Bekliyor'),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: row,
            matching: find.textContaining(
              expectedStatus.isConfirmed
                  ? 'Onaylı'
                  : _terminalLabel(expectedStatus),
            ),
          ),
          findsOneWidget,
        );
        expect(
          tester.widget<ListTile>(row).onTap,
          expectedStatus.isConfirmed ? isNotNull : isNull,
        );
        expect(
          find.descendant(of: row, matching: find.text('İptal et')),
          findsNothing,
        );
        if (expectedStatus.isConfirmed) {
          await tester.tap(row);
          await tester.pumpAndSettle();
          expect(find.text('Rezervasyonu Onayla'), findsNothing);
          expect(find.text('Talebi Reddet'), findsNothing);
          expect(find.text('Rezervasyonu İptal Et'), findsOneWidget);
          f.navigator.currentState!.pop();
          await tester.pumpAndSettle();
        } else {
          await tester.tap(row);
          await tester.pumpAndSettle();
          expect(find.text('Rezervasyon Bilgileri'), findsNothing);
        }
        expect(f.api.ackIds, [_id]);
        expect(
          f.cubit.state.items.singleWhere((item) => item.id == _sibling).read,
          isFalse,
        );
        f.navigator.currentState!.pop();
        await tester.pumpAndSettle();
        expect(find.text('Original'), findsOneWidget);
      },
    );
  }

  testWidgets(
    'wrong reservation list cannot read exact notification; explicit retry reloads only domain',
    (tester) async {
      f.rooms.reservationId = _sibling;
      await f.mount(tester);
      await tester.pumpAndSettle();
      expect(find.byKey(_detailKey), findsNothing);
      expect(
        find.text('Bu rezervasyon şu anda görüntülenemiyor.'),
        findsOneWidget,
      );
      f.expectNoMutations();
      f.rooms.reservationId = _reservation;
      await tester.tap(find.text('Tekrar dene'));
      await tester.pumpAndSettle();
      expect(find.byKey(_detailKey), findsOneWidget);
      expect(f.api.ackIds, [_id]);
      expect(f.api.calls.where((c) => c.method == ApiHttpMethod.get).length, 1);
    },
  );

  testWidgets(
    'target failure leaves origin visible, no route/read, double retry single flight',
    (tester) async {
      f.api.failure = StateError(_private);
      await f.mount(tester);
      await tester.pumpAndSettle();
      expect(find.text('Original'), findsOneWidget);
      expect(find.byType(StudioReservationCalendarScreen), findsNothing);
      expect(find.text(_private), findsNothing);
      f.expectNoMutations();
      f.api.failure = null;
      final pending = Completer<Object?>();
      f.api.pending = pending;
      await tester.tap(find.text('Tekrar dene'));
      await tester.tap(find.text('Tekrar dene'));
      await tester.pump();
      expect(f.api.calls.length, 2);
      pending.complete(_dto());
      await tester.pumpAndSettle();
      expect(f.api.ackIds, [_id]);
    },
  );

  for (final change in [
    'logout',
    'account',
    'token',
    'inactive',
    'listener',
    'onboarding',
    'application',
  ]) {
    testWidgets('late resolver after $change cannot navigate or ACK', (
      tester,
    ) async {
      final pending = Completer<Object?>();
      f.api.pending = pending;
      await f.mount(tester);
      f.sessions.replace(switch (change) {
        'logout' => const AuthSession.guest(),
        'account' => audienceSession(user: _other, role: 'ROLE_MUSICIAN'),
        'token' => audienceSession(
          user: _user,
          role: 'ROLE_MUSICIAN',
          token: 'replacement',
        ),
        'inactive' => audienceSession(
          user: _user,
          role: 'ROLE_MUSICIAN',
          status: 'INACTIVE',
        ),
        'listener' => audienceSession(user: _user, role: 'ROLE_LISTENER'),
        'onboarding' => _scopedSession(onboarding: true),
        _ => _scopedSession(application: true),
      });
      pending.complete(_dto());
      await tester.pumpAndSettle();
      expect(find.byType(StudioReservationCalendarScreen), findsNothing);
      expect(find.text('Original'), findsOneWidget);
      f.expectNoMutations();
    });
  }

  testWidgets(
    'captured destination removes private calendar after token replacement',
    (tester) async {
      await f.mount(tester);
      await tester.pumpAndSettle();
      expect(find.byKey(_detailKey), findsOneWidget);
      f.sessions.replace(
        audienceSession(
          user: _user,
          role: 'ROLE_MUSICIAN',
          token: 'replacement',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(_detailKey), findsNothing);
      expect(find.byType(StudioReservationCalendarScreen), findsNothing);
      expect(find.text('Original'), findsOneWidget);
    },
  );

  for (final hidden in ['covered', 'background', 'popped']) {
    testWidgets('late lookup while $hidden cannot navigate or ACK', (
      tester,
    ) async {
      final pending = Completer<Object?>();
      f.api.pending = pending;
      await f.mount(tester, nestedOrigin: true);
      if (hidden == 'covered') {
        unawaited(
          f.navigator.currentState!.push(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Cover')),
            ),
          ),
        );
      } else if (hidden == 'background') {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      } else {
        f.navigator.currentState!.pop();
      }
      pending.complete(_dto());
      await tester.pumpAndSettle();
      expect(find.byType(StudioReservationCalendarScreen), findsNothing);
      f.expectNoMutations();
      if (hidden == 'popped') return;
      if (hidden == 'covered') {
        f.navigator.currentState!.pop();
      } else {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      }
      await tester.pumpAndSettle();
      f.expectNoMutations();
      f.api.pending = null;
      await tester.tap(find.text('Tekrar dene'));
      await tester.pumpAndSettle();
      expect(f.api.ackIds, [_id]);
    });
  }

  testWidgets('inactive start defers lookup until foreground', (tester) async {
    await f.mount(tester, lifecycle: AppLifecycleState.inactive);
    expect(f.api.calls, isEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(f.api.ackIds, [_id]);
  });

  testWidgets('ACK-only retry keeps calendar, GET count and unread sibling', (
    tester,
  ) async {
    f.api.ackFailure = StateError(_private);
    await f.mount(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(_detailKey), findsOneWidget);
    expect(find.text('Okundu bilgisi kaydedilemedi.'), findsOneWidget);
    expect(f.cubit.state.unreadCount, 2);
    final domainReads = f.rooms.customerDates.length;
    f.api.ackFailure = null;
    await tester.tap(find.text('Tekrar dene'));
    await tester.pumpAndSettle();
    expect(f.api.ackIds, [_id, _id]);
    expect(f.api.calls.where((c) => c.method == ApiHttpMethod.get).length, 1);
    expect(f.rooms.customerDates.length, domainReads);
    expect(f.cubit.state.unreadCount, 1);
    expect(f.reconciliations, 1);
  });

  testWidgets('late ACK from replaced token cannot reconcile local read', (
    tester,
  ) async {
    f.api.ackPending = Completer<void>();
    await f.mount(tester);
    await tester.pumpAndSettle();
    expect(f.api.ackIds, [_id]);
    f.sessions.replace(
      audienceSession(user: _user, role: 'ROLE_MUSICIAN', token: 'replacement'),
    );
    f.api.ackPending!.complete();
    await tester.pumpAndSettle();
    expect(f.reconciliations, 0);
    expect(find.byType(StudioReservationCalendarScreen), findsNothing);
  });

  testWidgets(
    'inbox failed tap stays on inbox; explicit read-all remains separate',
    (tester) async {
      f.api.failure = StateError(_private);
      await f.mount(tester, inbox: true);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Studio unread fixture'));
      await tester.pumpAndSettle();
      expect(find.byType(NotificationScreen), findsOneWidget);
      expect(find.text('Tekrar dene'), findsOneWidget);
      f.expectNoMutations();
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tümünü oku'));
      await tester.pumpAndSettle();
      expect(f.notifications.mutations, ['read-all']);
    },
  );
}

Map<String, dynamic> _dto({String type = _type}) => {
  'notificationId': _id,
  'recipientId': _user,
  'type': type,
  'reservationId': _reservation,
  'roomId': '60000000-0000-4000-8000-000000000002',
  'studioProfileId': '60000000-0000-4000-8000-000000000003',
  'studioName': 'Current studio',
  'roomName': 'Current room',
  'ownerMode': StudioReservationNotificationTarget.ownerTypes.contains(type),
  'status': 'CONFIRMED',
  'roomArchived': false,
  'completed': false,
  'startsAt': '2026-09-24T08:00:00Z',
  'endsAt': '2026-09-24T09:00:00Z',
  'zoneId': 'Europe/Istanbul',
  'localDate': '2026-09-24',
  'localEndDate': '2026-09-24',
  'localStartTime': '11:00:00',
  'localEndTime': '12:00:00',
};

class _Fixture {
  final sessions = AudienceTestSessions(
    audienceSession(user: _user, role: 'ROLE_MUSICIAN'),
  );
  final notifications = _Notifications();
  final rooms = _Rooms();
  final realtime = _Realtime();
  final navigator = GlobalKey<NavigatorState>();
  late final api = _Api(notifications);
  late final repository = NotificationTargetRepository(api, sessions);
  int reconciliations = 0;
  bool disposed = false;
  late final cubit = NotificationCubit(
    notifications,
    _Tokens(),
    sessions: sessions,
    realtimeClient: realtime,
    onDeliveryStateChanged: () async => reconciliations++,
  );

  Future<void> mount(
    WidgetTester tester, {
    bool inbox = false,
    bool nestedOrigin = false,
    PushTarget target = _target,
    AppLifecycleState lifecycle = AppLifecycleState.resumed,
  }) async {
    tester.binding.handleAppLifecycleStateChanged(lifecycle);
    serviceLocator.registerSingleton<AuthSessionManager>(sessions);
    serviceLocator.registerSingleton<NotificationTargetRepository>(repository);
    serviceLocator.registerSingleton<NotificationCubit>(cubit);
    serviceLocator.registerSingleton<StudioRoomRepository>(rooms);
    await cubit.ensureStarted();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [notificationTargetRouteObserver],
        home: const Scaffold(body: Text('Original')),
      ),
    );
    if (inbox || nestedOrigin) {
      unawaited(
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => inbox
                ? BlocProvider.value(
                    value: cubit,
                    child: const NotificationScreen(),
                  )
                : const Scaffold(body: Text('Nested origin')),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }
    if (!inbox) {
      final context =
          notificationTargetRouteObserver.currentRoute!.subtreeContext!;
      unawaited(
        NotificationDirectOpen.start(
          context,
          identity: target.notificationId,
          builder: (_) =>
              StudioReservationNotificationOpenScreen(target: target),
        ),
      );
    }
    await tester.pump();
    addTearDown(() async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await dispose();
    });
  }

  void expectNoMutations() {
    expect(api.ackIds, isEmpty);
    expect(notifications.mutations, isEmpty);
    expect(reconciliations, 0);
  }

  Future<void> dispose() async {
    if (disposed) return;
    disposed = true;
    await cubit.close();
    await realtime.dispose();
    sessions.dispose();
  }
}

typedef _Call = ({
  ApiHttpMethod method,
  String path,
  ApiRequestContext? context,
});

class _Api extends Fake implements ApiClient {
  _Api(this.notifications);
  final _Notifications notifications;
  Object? response = _dto(), failure, ackFailure;
  Completer<Object?>? pending;
  Completer<void>? ackPending;
  final calls = <_Call>[], ackIds = <String>[];
  @override
  Future<T> request<T>(
    ApiHttpMethod method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    T Function(Object?)? decoder,
    ApiRequestContext? requestContext,
  }) async {
    calls.add((method: method, path: path, context: requestContext));
    if (method == ApiHttpMethod.post) {
      ackIds.add(path.split('/')[5]);
      if (ackFailure != null) throw ackFailure!;
      await ackPending?.future;
      await notifications.markAsRead(notificationId: path.split('/')[5]);
      return null as T;
    }
    if (failure != null) throw failure!;
    final value = await (pending?.future ?? Future.value(response));
    return decoder == null ? value as T : decoder(value);
  }
}

class _Notifications extends Fake implements NotificationRepository {
  final mutations = <String>[];
  List<AppNotification> items = [
    _row(_id, _type, 'Studio unread fixture'),
    _row(_sibling, 'SOCIAL_NEW_FOLLOWER', 'Unread sibling'),
  ];
  @override
  Future<Result<Page<AppNotification>>> listNotifications({
    int page = 0,
    int size = 20,
  }) async => Result.success(Page(items: List.of(items), hasNext: false));
  @override
  Future<Result<int>> getUnreadCount() async =>
      Result.success(items.where((row) => !row.read).length);
  @override
  Future<Result<void>> markAsRead({required String notificationId}) async {
    mutations.add('read:$notificationId');
    items = [
      for (final row in items)
        row.id == notificationId ? row.copyWith(read: true) : row,
    ];
    return const Result.success(null);
  }

  @override
  Future<Result<int>> markAllAsRead() async {
    mutations.add('read-all');
    items = [for (final row in items) row.copyWith(read: true)];
    return const Result.success(2);
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

AppNotification _row(String id, String type, String title) => AppNotification(
  id: id,
  recipientId: _user,
  type: type,
  title: title,
  message: '',
  read: false,
  createdAt: DateTime.utc(2026, 9, 24),
  payload: const {'module': 'STUDIO'},
);
AuthSession _scopedSession({
  bool application = false,
  bool onboarding = false,
}) => AuthSession.authenticated(
  token: 'token',
  userId: _user,
  username: 'fixture',
  accountStatus: application ? 'PENDING' : 'ACTIVE',
  roles: const ['ROLE_MUSICIAN'],
  permissions: const [],
  expiresAt: DateTime.utc(2100),
  isAdmin: false,
  sessionScope: application ? 'VENUE_APPLICATION' : null,
  applicationId: application ? _reservation : null,
  requiresListenerProfileChoice: onboarding,
);

const _roomId = '60000000-0000-4000-8000-000000000002';
const _studioId = '60000000-0000-4000-8000-000000000003';

String _terminalLabel(StudioReservationStatus status) => switch (status) {
  StudioReservationStatus.rejectedByStudio => 'Reddedildi',
  StudioReservationStatus.cancelledByCustomer => 'Müşteri İptal Etti',
  StudioReservationStatus.cancelledByStudio => 'Stüdyo İptal Etti',
  StudioReservationStatus.expired => 'Süresi Doldu',
  _ => throw StateError('Expected a terminal status'),
};

class _Rooms extends Fake implements StudioRoomRepository {
  DateTime today = DateTime(2026, 9, 24);
  StudioReservationStatus status = StudioReservationStatus.confirmed;
  String reservationId = _reservation;
  String requesterId = _user;
  final mutations = <String>[];
  Completer<Result<StudioRoom>>? roomPending;
  final roomIds = <String>[],
      customerDates = <DateTime>[],
      ownerDates = <DateTime>[];
  StudioRoom get room => StudioRoom(
    id: _roomId,
    studioProfileId: _studioId,
    slotIndex: 2,
    name: 'Current room',
    shortDescription: '',
    capacity: 3,
    hourlyPriceMinor: 10000,
    currency: 'TRY',
    reservationApprovalRequired: true,
    features: const [],
    photos: const [],
    todayLocalDate: today,
    todayReservationCount: 1,
    todayOccupiedHours: 1,
    todayAvailableHours: 13,
    todayAvailabilityStatus: StudioRoomAvailabilityStatus.partiallyAvailable,
    version: 1,
  );
  StudioReservation get reservation => StudioReservation(
    id: reservationId,
    clientRequestId: _reservation,
    roomId: _roomId,
    studioProfileId: _studioId,
    roomName: 'Current room',
    requesterId: requesterId,
    requesterUsername: 'Reservation customer',
    startsAt: DateTime.utc(2026, 9, 24, 8),
    endsAt: DateTime.utc(2026, 9, 24, 9),
    zoneId: 'Europe/Istanbul',
    status: status,
    completed: today.isAfter(DateTime(2026, 9, 24)),
    approvalRequired: true,
    hourlyPriceMinor: 10000,
    totalPriceMinor: 10000,
    currency: 'TRY',
    version: 1,
    localDate: '2026-09-24',
    localStartTime: '11:00',
    localEndTime: '12:00',
  );
  @override
  Future<Result<StudioReservation>> approveReservation({
    required String roomId,
    required String reservationId,
    required int expectedVersion,
  }) async {
    expect(roomId, _roomId);
    expect(reservationId, _reservation);
    mutations.add('approve');
    status = StudioReservationStatus.confirmed;
    return Result.success(reservation);
  }

  @override
  Future<Result<StudioReservation>> rejectReservation({
    required String roomId,
    required String reservationId,
    required int expectedVersion,
  }) async {
    expect(roomId, _roomId);
    expect(reservationId, _reservation);
    mutations.add('reject');
    status = StudioReservationStatus.rejectedByStudio;
    return Result.success(reservation);
  }

  @override
  Future<Result<StudioReservation>> cancelOwnerReservation({
    required String roomId,
    required String reservationId,
    required int expectedVersion,
  }) async {
    expect(roomId, _roomId);
    expect(reservationId, _reservation);
    mutations.add('owner-cancel');
    status = StudioReservationStatus.cancelledByStudio;
    return Result.success(reservation);
  }

  @override
  Future<Result<StudioReservation>> cancelCustomerReservation({
    required String reservationId,
    required int expectedVersion,
  }) async {
    expect(reservationId, _reservation);
    mutations.add('customer-cancel');
    status = StudioReservationStatus.cancelledByCustomer;
    return Result.success(reservation);
  }

  @override
  Future<Result<StudioRoom>> getOwnerRoom(String id) async {
    roomIds.add(id);
    return roomPending?.future ?? Result.success(room);
  }

  @override
  Future<Result<StudioRoom>> getPublicRoom(String profileId, String id) async {
    expect(profileId, _studioId);
    roomIds.add(id);
    return roomPending?.future ?? Result.success(room);
  }

  @override
  Future<Result<StudioRoomAvailability>> getPublicAvailability({
    required String studioProfileId,
    required String roomId,
    required DateTime from,
    required DateTime to,
  }) async => Result.success(
    StudioRoomAvailability(
      studioProfileId: studioProfileId,
      roomId: roomId,
      zoneId: 'Europe/Istanbul',
      openingHour: 9,
      closingHour: 23,
      todayLocalDate: today,
      currentLocalTime: '09:00',
      latestBookableLocalDateTime: today.add(const Duration(days: 365)),
      from: from,
      to: to,
      unavailable: const [],
    ),
  );
  @override
  Future<Result<StudioPage<StudioReservation>>>
  listCustomerReservationsForRoomDate({
    required String roomId,
    required DateTime date,
    int page = 0,
    int size = 100,
  }) async {
    expect(roomId, _roomId);
    customerDates.add(date);
    return Result.success(
      _page(date == DateTime(2026, 9, 24) ? [reservation] : []),
    );
  }

  @override
  Future<Result<StudioRoomSchedule>> getOwnerSchedule({
    required String roomId,
    required DateTime from,
    required DateTime to,
    int page = 0,
    int size = 100,
  }) async {
    expect(roomId, _roomId);
    ownerDates.add(from);
    return Result.success(
      StudioRoomSchedule(
        room: room,
        zoneId: 'Europe/Istanbul',
        todayLocalDate: today,
        currentLocalTime: '09:00',
        latestBookableLocalDateTime: today.add(const Duration(days: 365)),
        from: from,
        to: to,
        reservations: _page([reservation]),
        occupancies: const [],
      ),
    );
  }

  StudioPage<StudioReservation> _page(List<StudioReservation> items) =>
      StudioPage(
        items: items,
        pageIndex: 0,
        pageSize: 100,
        totalItems: items.length,
        totalPages: 1,
        isFirst: true,
        isLast: true,
      );
}
