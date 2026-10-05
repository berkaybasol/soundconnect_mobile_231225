import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/push/push_provider.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/core/pagination/page.dart';
import 'package:soundconnect_23_12_25codx/core/realtime/realtime_client_error.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/dm_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_badge_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/entities/city.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/location_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/data/notification_target_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/data/notification_realtime_client.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/domain/entities/app_notification.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/domain/entities/table_notification_target.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/domain/notification_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/cubit/notification_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/notification_target_read.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/notification_direct_open.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/screens/table_notification_open_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/screens/notification_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/domain/entities/table_group.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/domain/entities/table_group_participant.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/domain/entities/table_group_message.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/domain/table_group_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/domain/table_group_game_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/data/table_group_chat_realtime_client.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/presentation/screens/table_group_detail_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/presentation/screens/table_group_list_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/presentation/cubit/table_group_list_cubit.dart';
import 'support/event_audience_fakes.dart';
import 'support/recording_api_client.dart';

const recipient = '10000000-0000-0000-0000-000000000001';
const applicant = '20000000-0000-0000-0000-000000000001';
const tableId = '30000000-0000-0000-0000-000000000001';
const cycleId = '40000000-0000-0000-0000-000000000001';
const notificationId = '50000000-0000-0000-0000-000000000001';
const siblingId = '50000000-0000-0000-0000-000000000002';
const fail = AppError(code: 'unavailable', message: 'Temporary failure');
AppNotification item(
  String id, {
  String type = 'TABLE_JOIN_REQUEST_REJECTED',
}) => AppNotification(
  id: id,
  recipientId: recipient,
  type: type,
  title: 'Masa bildirimi',
  message: '',
  read: false,
  createdAt: DateTime.utc(2026, 9, 30),
  payload: const {'tableGroupId': 'untrusted'},
);
Map<String, dynamic> targetJson({
  String type = 'TABLE_JOIN_REQUEST_REJECTED',
  String kind = 'RESULT',
  String id = notificationId,
  String? reason,
}) => {
  'notificationId': id,
  'recipientId': recipient,
  'type': type,
  'tableGroupId': tableId,
  'kind': kind,
  'event': TableNotificationTarget.actions[type],
  'occurredAt': '2026-09-30T10:00:00Z',
  'description': 'Güncel görev masası',
  'tableStatus': type == 'TABLE_CANCELLED'
      ? 'CANCELLED'
      : type == 'TABLE_EXPIRED'
      ? 'INACTIVE'
      : 'ACTIVE',
  'participantStatus': kind == 'PENDING_APPLICATION'
      ? 'PENDING'
      : kind == 'CHAT' || type == 'TABLE_CANCELLED' || type == 'TABLE_EXPIRED'
      ? 'ACCEPTED'
      : 'REJECTED',
  'subjectId': kind == 'PENDING_APPLICATION' ? applicant : recipient,
  'applicationId': cycleId,
  'sameApplication': true,
  'reason': reason,
  'read': false,
};

void main() {
  late AudienceTestSessions sessions;
  late NotificationCubit cubit;
  late _Inbox inbox;
  late RecordingApiClient api;
  late NotificationTargetRepository targets;
  late Map<String, dynamic> response;
  late GlobalKey<NavigatorState> nav;
  late BuildContext inboxContext;
  late _Routes routes;
  late List<String> acks;
  Completer<Object?>? pendingGet, pendingAck, pendingChat;
  bool failGet = false, failAck = false, failChat = false, failDetail = false;
  var reconciliations = 0;
  setUp(() async {
    await serviceLocator.reset();
    sessions = AudienceTestSessions(
      audienceSession(user: recipient, role: 'ROLE_LISTENER'),
    );
    inbox = _Inbox();
    acks = [];
    response = targetJson();
    nav = GlobalKey<NavigatorState>();
    routes = _Routes();
    failGet = false;
    failAck = false;
    failChat = false;
    failDetail = false;
    pendingGet = null;
    pendingAck = null;
    pendingChat = null;
    reconciliations = 0;
    api = RecordingApiClient((request) async {
      if (request.path.endsWith('/read')) {
        acks.add(request.path.split('/').reversed.elementAt(1));
        if (pendingAck != null) await pendingAck!.future;
        if (failAck) throw ApiException(fail);
        inbox.items = inbox.items
            .map((i) => i.id == acks.last ? i.copyWith(read: true) : i)
            .toList();
        return null;
      }
      if (request.path.endsWith('/table-target')) {
        if (pendingGet != null) return await pendingGet!.future;
        if (failGet) throw ApiException(fail);
        return response;
      }
      if (request.path.endsWith('/chat/messages')) {
        if (pendingChat != null) await pendingChat!.future;
        if (failChat) throw ApiException(fail);
        return {'content': <Object>[], 'last': true};
      }
      if (request.path.contains('/approve/') ||
          request.path.contains('/reject/')) {
        return null;
      }
      throw StateError('Unexpected request ${request.path}');
    });
    targets = NotificationTargetRepository(api, sessions);
    cubit = NotificationCubit(
      inbox,
      _Tokens(),
      sessions: sessions,
      realtimeClient: _Realtime(),
      onDeliveryStateChanged: () async {
        reconciliations++;
      },
    );
    serviceLocator
      ..registerSingleton<AuthSessionManager>(sessions)
      ..registerSingleton<NotificationTargetRepository>(targets)
      ..registerSingleton<NotificationCubit>(cubit)
      ..registerSingleton<TokenStore>(_Tokens())
      ..registerSingleton<TableGroupRepository>(
        _TableFeed(() => response, unavailable: () => failDetail),
      )
      ..registerSingleton<TableGroupGameRepository>(_Games())
      ..registerSingleton<DmBadgeCubit>(_DmBadge(), dispose: (c) => c.close())
      ..registerFactory<TableGroupListCubit>(
        () => TableGroupListCubit(
          tableGroupRepository: _TableFeed(() => response),
          locationRepository: _Locations(),
        ),
      );
    await cubit.ensureStarted();
  });
  tearDown(() async {
    await serviceLocator.reset();
    await cubit.close();
    sessions.dispose();
  });
  Future<void> settle(WidgetTester t) async {
    // The real list's create button deliberately repeats its pulse animation.
    // Allow a bounded set of real frames without waiting for it to stop.
    if (find.byType(TableGroupListScreen).evaluate().isNotEmpty) {
      for (var i = 0; i < 12; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
    } else {
      await t.pumpAndSettle();
    }
  }

  Future<void> mount(
    WidgetTester t, {
    bool paused = false,
    bool realInbox = false,
  }) async {
    t.view.physicalSize = const Size(420, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pumpWidget(
      MaterialApp(
        navigatorKey: nav,
        navigatorObservers: [notificationTargetRouteObserver, routes],
        home: const Scaffold(body: Text('Home')),
      ),
    );
    unawaited(
      nav.currentState!.push<void>(
        MaterialPageRoute(
          builder: (context) {
            inboxContext = context;
            if (realInbox) {
              return BlocProvider.value(
                value: cubit,
                child: const NotificationScreen(),
              );
            }
            return const Scaffold(body: Text('Inbox'));
          },
        ),
      ),
    );
    await settle(t);
    if (paused) {
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    }
  }

  Future<void> open(
    WidgetTester t, {
    AppNotification? selected,
    bool native = false,
  }) async {
    unawaited(
      NotificationDirectOpen.start(
        inboxContext,
        identity: (selected ?? inbox.items.first).id,
        builder: (_) => native
            ? TableNotificationOpenScreen.native(
                target: PushTarget(
                  notificationId: (selected ?? inbox.items.first).id,
                  recipientId: (selected ?? inbox.items.first).recipientId,
                  type: (selected ?? inbox.items.first).type,
                ),
              )
            : TableNotificationOpenScreen(
                notification: selected ?? inbox.items.first,
              ),
      ),
    );
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await t.pump();
  }

  int gets() =>
      api.requests.where((r) => r.path.endsWith('/table-target')).length;
  void unread() {
    expect(cubit.state.items.every((i) => !i.read), isTrue);
    expect(cubit.state.unreadCount, 2);
    expect(reconciliations, 0);
  }

  void onlyTarget() {
    expect(cubit.state.items.first.read, isTrue);
    expect(cubit.state.items.last.read, isFalse);
    expect(cubit.state.unreadCount, 1);
    expect(reconciliations, 1);
  }

  for (final boundary in ['none', 'inactive', 'cover']) {
    testWidgets(
      'terminal pre-mount caller control $boundary releases same-ID opening',
      (t) async {
        response['tableStatus'] = 'CANCELLED';
        pendingGet = Completer<Object?>();
        await mount(t);
        var firstDone = false;
        final first = NotificationDirectOpen.start(
          inboxContext,
          identity: notificationId,
          builder: (_) =>
              TableNotificationOpenScreen(notification: item(notificationId)),
        );
        unawaited(first.then((_) => firstDone = true));
        await t.pump();
        expect(gets(), 1);
        expect(acks, isEmpty);
        // Flush the complete successful GET continuation, but do not build the
        // state scheduled by _closedTarget's setState yet.
        pendingGet!.complete(response);
        await t.idle();
        expect(find.byType(NotificationTerminalFeedback), findsNothing);
        expect(firstDone, isFalse);
        if (boundary == 'inactive') {
          // Unlike paused, inactive still permits real production frames.
          t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        } else if (boundary == 'cover') {
          unawaited(
            nav.currentState!.push(
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('Pre-mount cover')),
              ),
            ),
          );
        }
        await settle(t);
        if (boundary != 'none') {
          expect(acks, isEmpty);
          expect(find.text('Bu masa kapatıldı.'), findsNothing);
          if (boundary == 'inactive') {
            t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
          } else {
            nav.currentState!.pop();
          }
          await settle(t);
        }
        expect(find.text('Inbox'), findsOneWidget);
        expect(routes.stack.length, 2);
        // Recovery may present a terminal result or explicit retry. Either must
        // release the row; an invisible pending future cannot own it forever.
        final duplicate = NotificationDirectOpen.start(
          inboxContext,
          identity: notificationId,
          builder: (_) =>
              TableNotificationOpenScreen(notification: item(notificationId)),
        );
        final reusedPendingFlight = identical(first, duplicate) && !firstDone;
        expect(
          reusedPendingFlight,
          isFalse,
          reason:
              'Returning from $boundary must not retain an invisible '
              'same-ID flight that permanently disables the inbox row.',
        );
        await settle(t);
        await t.pumpWidget(const SizedBox());
      },
    );
  }
  for (final boundary in ['none', 'inactive', 'cover']) {
    testWidgets(
      'terminal pre-mount $boundary presents once and releases real inbox row',
      (t) async {
        response['tableStatus'] = 'CANCELLED';
        pendingGet = Completer<Object?>();
        await mount(t, realInbox: true);
        final row = find
            .descendant(
              of: find.byKey(const ValueKey(notificationId)),
              matching: find.byType(InkWell),
            )
            .first;
        await t.tap(row);
        await t.pump();
        expect(gets(), 1);
        expect(t.widget<InkWell>(row).onTap, isNull);
        pendingGet!.complete(response);
        // Resolve the foreground GET without drawing the first presenter.
        await t.idle();
        expect(find.byType(NotificationTerminalFeedback), findsNothing);
        expect(acks, isEmpty);
        if (boundary == 'inactive') {
          t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        } else if (boundary == 'cover') {
          unawaited(
            nav.currentState!.push(
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('Pre-mount cover')),
              ),
            ),
          );
        }
        await settle(t);
        if (boundary != 'none') {
          expect(acks, isEmpty);
          expect(find.text('Bu masa kapatıldı.'), findsNothing);
          unread();
          if (boundary == 'inactive') {
            expect(t.widget<InkWell>(row).onTap, isNull);
            t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
          } else {
            nav.currentState!.pop();
          }
          await settle(t);
        }
        expect(find.byType(NotificationScreen), findsOneWidget);
        expect(find.text('Bu masa kapatıldı.'), findsOneWidget);
        expect(routes.stack.length, 2);
        expect(gets(), 1);
        expect(acks, [notificationId]);
        onlyTarget();
        expect(t.widget<InkWell>(row).onTap, isNotNull);
        pendingGet = Completer<Object?>();
        await t.tap(row);
        await t.pump();
        await t.tap(row);
        await t.pump();
        expect(gets(), 2, reason: 'Released row starts one new flight');
        expect(acks, [notificationId]);
        await t.pumpWidget(const SizedBox());
        pendingGet!.complete(response);
        await t.pump();
        expect(acks, [notificationId]);
      },
    );
  }

  for (final loss in ['logout', 'switch', 'relogin', 'pop', 'dispose']) {
    testWidgets(
      'terminal pre-mount inactive fences $loss and releases future',
      (t) async {
        response['tableStatus'] = 'CANCELLED';
        pendingGet = Completer<Object?>();
        await mount(t);
        var done = false;
        final first = NotificationDirectOpen.start(
          inboxContext,
          identity: notificationId,
          builder: (_) =>
              TableNotificationOpenScreen(notification: inbox.items.first),
        );
        unawaited(first.then((_) => done = true));
        await t.pump();
        pendingGet!.complete(response);
        await t.idle();
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        await settle(t);
        expect(done, isFalse);
        expect(acks, isEmpty);
        if (loss == 'pop') nav.currentState!.pop();
        if (loss == 'dispose') await t.pumpWidget(const SizedBox());
        if (['logout', 'switch', 'relogin'].contains(loss)) {
          await t.runAsync(() async {
            sessions.replace(
              loss == 'logout'
                  ? AuthSession.guest()
                  : audienceSession(
                      user: loss == 'switch' ? applicant : recipient,
                      token: 'replacement',
                    ),
            );
            await cubit.stop();
          });
        }
        await settle(t);
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await settle(t);
        expect(done, isTrue);
        expect(gets(), 1);
        expect(acks, isEmpty);
        expect(find.text('Bu masa kapatıldı.'), findsNothing);
        await t.pumpWidget(const SizedBox());
      },
    );
  }

  for (final type in PushTarget.tableTypes) {
    for (final reason
        in type == 'TABLE_CANCELLED'
            ? ['OWNER_CANCELLED', 'OWNER_JOINED_ANOTHER_TABLE']
            : <String?>[null]) {
      testWidgets(
        'native TABLE $type $reason fresh terminal target and exact read',
        (t) async {
          response = targetJson(type: type, reason: reason);
          await mount(t);
          await open(
            t,
            native: true,
            selected: item(notificationId, type: type),
          );
          await settle(t);
          expect(gets(), 1);
          expect(acks, [notificationId]);
          onlyTarget();
          expect(find.text('Masa bildirimi'), findsNothing);
          if (response['tableStatus'] == 'ACTIVE') {
            nav.currentState!.pop();
            await settle(t);
          } else {
            expect(routes.stack.length, 2);
          }
          expect(find.text('Inbox'), findsOneWidget);
        },
      );
    }
  }
  testWidgets('native TABLE target failure then explicit fresh retry', (
    t,
  ) async {
    failGet = true;
    await mount(t);
    await open(t, native: true);
    await settle(t);
    unread();
    expect(gets(), 1);
    failGet = false;
    await t.tap(find.text('Tekrar dene'));
    await settle(t);
    expect(gets(), 2);
    expect(acks, [notificationId]);
    onlyTarget();
  });
  testWidgets('native TABLE ACK-only retry never repeats target GET', (
    t,
  ) async {
    failAck = true;
    await mount(t);
    await open(t, native: true);
    await settle(t);
    unread();
    expect(gets(), 1);
    expect(acks, [notificationId]);
    failAck = false;
    await t.tap(find.text('Tekrar dene'));
    await settle(t);
    expect(gets(), 1);
    expect(acks, [notificationId, notificationId]);
    onlyTarget();
  });
  testWidgets(
    'native TABLE hidden result needs explicit fresh retry and keeps sibling unread',
    (t) async {
      pendingGet = Completer<Object?>();
      await mount(t);
      await open(t, native: true);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      pendingGet!.complete(response);
      await t.pump();
      unread();
      pendingGet = null;
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(t);
      expect(gets(), 1);
      unread();
      await t.tap(find.text('Tekrar dene'));
      await settle(t);
      expect(gets(), 2);
      expect(acks, [notificationId]);
      onlyTarget();
    },
  );

  for (final boundary in ['background', 'cover']) {
    for (final failed in [false, true]) {
      testWidgets(
        'resume recovery $boundary ${failed ? "failure" : "success"}: visible retry completes future and resolves fresh once',
        (t) async {
          pendingGet = Completer<Object?>();
          await mount(t);
          var done = false;
          unawaited(
            NotificationDirectOpen.start(
              inboxContext,
              identity: notificationId,
              builder: (_) =>
                  TableNotificationOpenScreen(notification: inbox.items.first),
            ).then((_) => done = true),
          );
          await t.pump();
          await t.pump(const Duration(milliseconds: 400));
          expect(gets(), 1);
          if (boundary == 'background') {
            t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
          } else {
            unawaited(
              nav.currentState!.push(
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(body: Text('Cover')),
                ),
              ),
            );
            await settle(t);
          }
          if (failed) {
            pendingGet!.completeError(ApiException(fail));
          } else {
            pendingGet!.complete(response);
          }
          await settle(t);
          expect(acks, isEmpty);
          expect(find.byType(TableGroupDetailScreen), findsNothing);
          expect(find.text('Tekrar dene'), findsNothing);
          expect(done, isFalse);
          if (boundary == 'background') {
            t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
          } else {
            nav.currentState!.pop();
          }
          await settle(t);
          final observed = [
            find.text('Bu masa şu anda açılamıyor.').evaluate().isNotEmpty,
            find.text('Tekrar dene').evaluate().isNotEmpty,
            done,
          ];
          debugPrint(
            'RESUME boundary=$boundary failed=$failed GET=${gets()} ACK=${acks.length} feedback/retry/done=$observed',
          );
          if (observed.any((v) => !v)) {
            await t.pumpWidget(const SizedBox());
            expect(observed, [true, true, true]);
            return;
          }
          expect(gets(), 1);
          unread();
          // Repeated lifecycle callbacks must not enqueue messages or auto-fetch.
          t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
          t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
          await settle(t);
          expect(find.byType(SnackBar), findsOneWidget);
          expect(gets(), 1);
          expect(acks, isEmpty);
          pendingGet = Completer<Object?>();
          await t.tap(find.text('Tekrar dene'));
          await t.pump();
          expect(gets(), 2);
          unread();
          // Only the explicit retry's changed fresh response may drive the target.
          response = {...response, 'description': 'Fresh retry table'};
          pendingGet!.complete(response);
          await settle(t);
          expect(gets(), 2);
          expect(find.byType(TableGroupDetailScreen), findsOneWidget);
          expect(
            t
                .widget<TableGroupDetailScreen>(
                  find.byType(TableGroupDetailScreen),
                )
                .args
                .notificationResult!
                .description,
            'Fresh retry table',
          );
          expect(acks, [notificationId]);
          onlyTarget();
          expect(routes.stack.length, 3);
          nav.currentState!.pop();
          await settle(t);
          expect(find.text('Inbox'), findsOneWidget);
          expect(routes.stack.length, 2);
          await t.pumpWidget(const SizedBox());
        },
      );
    }
  }

  for (final action in ['row', 'retry then row', 'row then retry']) {
    testWidgets(
      'real inbox resume recovery releases row: $action is one fresh flight',
      (t) async {
        pendingGet = Completer<Object?>();
        await mount(t, realInbox: true);
        final row = find
            .descendant(
              of: find.byKey(const ValueKey(notificationId)),
              matching: find.byType(InkWell),
            )
            .first;
        await t.tap(row);
        await t.pump();
        await t.pump(const Duration(milliseconds: 400));
        await t.tap(row);
        await t.pump();
        expect(gets(), 1);
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        pendingGet!.complete(response);
        await settle(t);
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await settle(t);
        expect(find.text('Tekrar dene'), findsOneWidget);
        unread();
        final retry = t
            .widget<SnackBarAction>(find.byType(SnackBarAction))
            .onPressed;
        pendingGet = Completer<Object?>();
        if (action == 'retry then row') {
          retry();
          await t.pump();
        }
        await t.tap(row);
        await t.pump();
        if (action == 'row then retry') retry();
        await t.pump(const Duration(milliseconds: 400));
        expect(
          gets(),
          2,
          reason:
              'The row is selectable; row plus retry shares one fresh resolver',
        );
        expect(acks, isEmpty);
        pendingGet!.complete(response);
        await settle(t);
        expect(gets(), 2);
        expect(find.byType(TableGroupDetailScreen), findsOneWidget);
        expect(routes.stack.length, 3);
        expect(acks, [notificationId]);
        onlyTarget();
        nav.currentState!.pop();
        await settle(t);
        expect(find.byType(NotificationScreen), findsOneWidget);
        expect(find.text('Tekrar dene'), findsNothing);
        await t.pumpWidget(const SizedBox());
      },
    );
  }

  for (final loss in ['logout', 'switch', 'relogin', 'pop', 'dispose']) {
    for (final completedBeforeLoss in [false, true]) {
      testWidgets(
        'resume recovery discards $loss with completion before loss=$completedBeforeLoss',
        (t) async {
          pendingGet = Completer<Object?>();
          await mount(t);
          var done = false;
          unawaited(
            NotificationDirectOpen.start(
              inboxContext,
              identity: notificationId,
              builder: (_) =>
                  TableNotificationOpenScreen(notification: inbox.items.first),
            ).then((_) => done = true),
          );
          await t.pump();
          await t.pump(const Duration(milliseconds: 400));
          t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
          if (completedBeforeLoss) {
            pendingGet!.completeError(ApiException(fail));
            await settle(t);
          }
          if (loss == 'pop') nav.currentState!.pop();
          if (loss == 'dispose') await t.pumpWidget(const SizedBox());
          if (['logout', 'switch', 'relogin'].contains(loss)) {
            await t.runAsync(() async {
              sessions.replace(
                loss == 'logout'
                    ? AuthSession.guest()
                    : audienceSession(
                        user: loss == 'switch' ? applicant : recipient,
                        token: 'replacement',
                      ),
              );
              await cubit.stop();
            });
          }
          await settle(t);
          if (!completedBeforeLoss) {
            pendingGet!.complete(response);
            await settle(t);
          }
          t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
          await settle(t);
          expect(done, isTrue);
          expect(gets(), 1);
          expect(acks, isEmpty);
          expect(find.text('Tekrar dene'), findsNothing);
          expect(find.text('Bu masa şu anda açılamıyor.'), findsNothing);
          expect(find.byType(TableGroupDetailScreen), findsNothing);
          await t.pumpWidget(const SizedBox());
        },
      );
    }
  }

  for (final oldFailed in [false, true]) {
    testWidgets(
      'replacing a pending TABLE selection fences late ${oldFailed ? "failure" : "success"}',
      (t) async {
        final old = Completer<Object?>();
        pendingGet = old;
        await mount(t, realInbox: true);
        Finder row(String id) => find
            .descendant(
              of: find.byKey(ValueKey(id)),
              matching: find.byType(InkWell),
            )
            .first;
        await t.tap(row(notificationId));
        await t.pump();
        await t.pump(const Duration(milliseconds: 400));
        pendingGet = Completer<Object?>();
        await t.tap(row(siblingId));
        await t.pump();
        await t.pump(const Duration(milliseconds: 400));
        expect(gets(), 2);
        if (oldFailed) {
          old.completeError(ApiException(fail));
        } else {
          old.complete(response);
        }
        await settle(t);
        expect(acks, isEmpty);
        expect(find.text('Tekrar dene'), findsNothing);
        expect(find.byType(TableGroupDetailScreen), findsNothing);
        response = targetJson(id: siblingId);
        pendingGet!.complete(response);
        await settle(t);
        expect(acks, [siblingId]);
        expect(cubit.state.items.first.read, isFalse);
        expect(cubit.state.items.last.read, isTrue);
        expect(cubit.state.unreadCount, 1);
        expect(routes.stack.length, 3);
        await t.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('resolving keeps inbox visible and duplicate tap adds no route', (
    t,
  ) async {
    pendingGet = Completer<Object?>();
    await mount(t);
    await open(t);
    await open(t);
    expect(gets(), 1);
    expect(find.text('Inbox'), findsOneWidget);
    expect(find.text('Masa bildirimi'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(routes.stack.length, 2);
    unread();
    pendingGet!.complete(response);
    await settle(t);
    expect(routes.stack.length, 3);
    expect(find.byType(TableGroupDetailScreen), findsOneWidget);
    onlyTarget();
    await t.pumpWidget(const SizedBox());
  });

  for (final entry in TableNotificationTarget.actions.entries) {
    for (final reason
        in entry.key == 'TABLE_CANCELLED'
            ? ['OWNER_CANCELLED', 'OWNER_JOINED_ANOTHER_TABLE']
            : [null]) {
      testWidgets(
        '${entry.key}/$reason uses active detail or closed origin feedback then exact read',
        (t) async {
          inbox.items = [
            item(notificationId, type: entry.key),
            item(siblingId),
          ];
          await cubit.refresh();
          response = targetJson(type: entry.key, reason: reason);
          await mount(t);
          await open(t);
          await settle(t);
          final closed = response['tableStatus'] != 'ACTIVE';
          expect(
            find.byType(TableGroupDetailScreen),
            closed ? findsNothing : findsOneWidget,
          );
          expect(find.byType(SnackBar), findsOneWidget);
          expect(find.text('Masa bildirimi'), findsNothing);
          expect(find.textContaining('Olay tarihi:'), findsNothing);
          expect(find.textContaining('güncel durumu:'), findsNothing);
          expect(
            api.requests.where((r) => r.path.endsWith('/chat/messages')),
            isEmpty,
          );
          expect(acks, [notificationId]);
          onlyTarget();
          expect(
            api.requests.every(
              (r) =>
                  r.requestContext?.expectedSessionKey == recipient &&
                  r.requestContext?.expectedToken == 'token',
            ),
            isTrue,
          );
          expect(routes.stack.length, closed ? 2 : 3);
          if (!closed) {
            nav.currentState!.pop();
            await settle(t);
          }
          expect(find.text('Inbox'), findsOneWidget);
          expect(routes.stack.length, 2);
          await t.pumpWidget(const SizedBox());
        },
      );
    }
  }
  for (final field in [
    'notificationId',
    'recipientId',
    'type',
    'tableGroupId',
    'subjectId',
    'event',
    'kind',
    'tableStatus',
    'participantStatus',
    'applicationId',
    'occurredAt',
    'sameApplication',
    'read',
  ]) {
    test('$field malformed or mismatched cannot resolve', () async {
      response[field] = 'invalid';
      final result = await targets.resolveTable(
        inbox.items.first,
        sessions.session,
      );
      expect(result.isSuccess, isFalse);
      expect(acks, isEmpty);
    });
  }
  testWidgets(
    'closed inaccessible result stays on origin with exact small message',
    (t) async {
      response['tableStatus'] = 'CANCELLED';
      await mount(t);
      await open(t);
      await settle(t);
      expect(find.byType(TableGroupListScreen), findsNothing);
      expect(find.byType(TableGroupDetailScreen), findsNothing);
      expect(find.text('Bu masa kapatıldı.'), findsOneWidget);
      onlyTarget();
      expect(routes.stack.length, 2);
      expect(find.text('Inbox'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    },
  );

  for (final native in [false, true]) {
    for (final status in ['CANCELLED', 'INACTIVE']) {
      testWidgets(
        'closed participant result $status native=$native has no extra Back',
        (t) async {
          response = targetJson(type: 'TABLE_PARTICIPANT_LEFT')
            ..['tableStatus'] = status;
          await mount(t);
          await open(
            t,
            native: native,
            selected: item(notificationId, type: 'TABLE_PARTICIPANT_LEFT'),
          );
          await settle(t);
          expect(find.text('Inbox'), findsOneWidget);
          expect(find.byType(TableGroupDetailScreen), findsNothing);
          expect(find.byType(TableGroupListScreen), findsNothing);
          expect(
            find.text(
              status == 'CANCELLED'
                  ? 'Bu masa kapatıldı.'
                  : 'Bu masanın süresi doldu.',
            ),
            findsOneWidget,
          );
          expect(routes.stack.length, 2);
          expect(gets(), 1);
          expect(acks, [notificationId]);
          onlyTarget();
          nav.currentState!.pop();
          await settle(t);
          expect(find.text('Home'), findsOneWidget);
          await t.pumpWidget(const SizedBox());
        },
      );
    }
  }

  testWidgets('closed origin ACK retry does not fetch the table again', (
    t,
  ) async {
    response['tableStatus'] = 'CANCELLED';
    failAck = true;
    await mount(t);
    await open(t);
    await settle(t);
    expect(find.text('Inbox'), findsOneWidget);
    expect(find.text('Okundu bilgisi kaydedilemedi.'), findsOneWidget);
    expect(acks, [notificationId]);
    unread();
    failAck = false;
    await t.tap(find.text('Tekrar dene'));
    await settle(t);
    expect(gets(), 1);
    expect(acks, [notificationId, notificationId]);
    expect(routes.stack.length, 2);
    onlyTarget();
    await t.pumpWidget(const SizedBox());
  });

  for (final boundary in [
    'none',
    'cover',
    'background',
    'session',
    'replace',
  ]) {
    testWidgets(
      'closed origin queued message waits for paint and fences $boundary',
      (t) async {
        response['tableStatus'] = 'CANCELLED';
        await mount(t);
        final messenger = ScaffoldMessenger.of(inboxContext);
        messenger.showSnackBar(
          const SnackBar(content: Text('Önceki işlem mesajı'), persist: true),
        );
        await settle(t);
        await open(t);
        await settle(t);
        expect(find.text('Önceki işlem mesajı'), findsOneWidget);
        expect(find.text('Bu masa kapatıldı.'), findsNothing);
        expect(acks, isEmpty);
        if (boundary == 'cover') {
          unawaited(
            nav.currentState!.push(
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('Cover')),
              ),
            ),
          );
        } else if (boundary == 'background') {
          t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        } else if (boundary == 'session') {
          await t.runAsync(() async {
            sessions.replace(audienceSession(user: applicant));
            await Future<void>.delayed(Duration.zero);
          });
        } else if (boundary == 'replace') {
          unawaited(
            nav.currentState!.pushReplacement(
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('Replacement')),
              ),
            ),
          );
        }
        await settle(t);
        messenger.hideCurrentSnackBar();
        await settle(t);
        if (boundary == 'none') {
          expect(find.text('Bu masa kapatıldı.'), findsOneWidget);
          onlyTarget();
        } else {
          expect(acks, isEmpty);
        }
        await t.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'detail race falls back without read and fresh retry replaces failed route',
    (t) async {
      failDetail = true;
      await mount(t);
      await open(t);
      await settle(t);
      expect(find.byType(TableGroupListScreen), findsOneWidget);
      expect(find.text('Bu masa şu anda açılamıyor.'), findsOneWidget);
      expect(find.text('Başvurun kabul edilmedi.'), findsNothing);
      expect(acks, isEmpty);
      unread();
      expect(routes.stack.length, 3);
      failDetail = false;
      await t.tap(find.text('Tekrar dene'));
      await settle(t);
      expect(gets(), 2);
      expect(find.byType(TableGroupListScreen), findsNothing);
      expect(find.byType(TableGroupDetailScreen), findsOneWidget);
      expect(routes.stack.length, 3);
      onlyTarget();
      nav.currentState!.pop();
      await settle(t);
      expect(find.text('Inbox'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'target GET failure needs explicit retry, resume/rebuild do not retry',
    (t) async {
      failGet = true;
      await mount(t);
      await open(t);
      await settle(t);
      unread();
      expect(acks, isEmpty);
      expect(gets(), 1);
      expect(find.text('Inbox'), findsOneWidget);
      expect(find.text('Bu masa şu anda açılamıyor.'), findsOneWidget);
      expect(routes.stack.length, 2);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(t);
      expect(gets(), 1);
      failGet = false;
      await t.tap(find.text('Tekrar dene'));
      await settle(t);
      expect(gets(), 2);
      onlyTarget();
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets('first open waits for foreground', (t) async {
    await mount(t, paused: true);
    await open(t);
    expect(gets(), 0);
    unread();
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(t);
    expect(gets(), 1);
    onlyTarget();
    await t.pumpWidget(const SizedBox());
  });

  testWidgets(
    'queued terminal message is not read until its real content paints',
    (t) async {
      final selected = inbox.items.first;
      final target = TableNotificationTarget.fromJson(response, selected);
      final ready = ValueNotifier(false);
      late BuildContext productContext;
      await mount(t);
      final route = MaterialPageRoute<void>(
        builder: (_) => ValueListenableBuilder<bool>(
          valueListenable: ready,
          builder: (_, visible, _) => NotificationTerminalFeedback(
            message: 'Başvurun kabul edilmedi.',
            contentIdentity: target,
            ready: visible,
            child: Scaffold(
              body: Builder(
                builder: (context) {
                  productContext = context;
                  return const Text('Mevcut masa listesi');
                },
              ),
            ),
          ),
        ),
      );
      NotificationTargetRead.table(
        notification: selected,
        cubit: cubit,
        sessions: sessions,
        repository: targets,
        content: target,
      ).attach(route);
      unawaited(nav.currentState!.push(route));
      await settle(t);
      ScaffoldMessenger.of(productContext).showSnackBar(
        const SnackBar(content: Text('Önceki işlem mesajı'), persist: true),
      );
      await settle(t);
      ready.value = true;
      await settle(t);
      expect(find.text('Önceki işlem mesajı'), findsOneWidget);
      expect(find.text('Başvurun kabul edilmedi.'), findsNothing);
      expect(acks, isEmpty);
      unread();
      ScaffoldMessenger.of(productContext).hideCurrentSnackBar();
      await settle(t);
      expect(find.text('Başvurun kabul edilmedi.'), findsOneWidget);
      onlyTarget();
      await t.pumpWidget(const SizedBox());
      ready.dispose();
    },
  );

  for (final boundary in ['cover', 'background', 'session']) {
    testWidgets('terminal before paint after $boundary cannot acknowledge', (
      t,
    ) async {
      final target = TableNotificationTarget.fromJson(
        response,
        inbox.items.first,
      );
      final ready = ValueNotifier(false);
      await mount(t);
      final route = MaterialPageRoute<void>(
        builder: (_) => ValueListenableBuilder<bool>(
          valueListenable: ready,
          builder: (_, visible, _) => NotificationTerminalFeedback(
            message: 'Başvurun kabul edilmedi.',
            contentIdentity: target,
            ready: visible,
            child: const Scaffold(body: Text('Mevcut masa listesi')),
          ),
        ),
      );
      NotificationTargetRead.table(
        notification: target.notification,
        cubit: cubit,
        sessions: sessions,
        repository: targets,
        content: target,
      ).attach(route);
      unawaited(nav.currentState!.push(route));
      await settle(t);
      if (boundary == 'cover') {
        unawaited(
          nav.currentState!.push(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Başka sayfa')),
            ),
          ),
        );
        await settle(t);
      } else if (boundary == 'background') {
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      } else {
        await t.runAsync(() async {
          sessions.replace(audienceSession(user: applicant));
          await cubit.stop();
        });
      }
      ready.value = true;
      await settle(t);
      expect(acks, isEmpty);
      expect(find.text('Başvurun kabul edilmedi.'), findsNothing);
      await t.pumpWidget(const SizedBox());
      ready.dispose();
    });
  }
  for (final boundary in [
    'cover',
    'pop',
    'switch',
    'logout',
    'relogin',
    'background',
  ]) {
    testWidgets('late target GET after $boundary never reads', (t) async {
      pendingGet = Completer<Object?>();
      await mount(t);
      await open(t);
      if (boundary == 'cover') {
        unawaited(
          nav.currentState!.push(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Cover')),
            ),
          ),
        );
      }
      if (boundary == 'pop') nav.currentState!.pop();
      if (['switch', 'relogin', 'logout'].contains(boundary)) {
        await t.runAsync(() async {
          if (boundary == 'switch') {
            sessions.replace(audienceSession(user: applicant));
          }
          if (boundary == 'relogin') {
            sessions.replace(audienceSession(user: recipient, token: 'new'));
          }
          if (boundary == 'logout') sessions.replace(AuthSession.guest());
          await cubit.stop();
        });
      }
      if (boundary == 'background') {
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      }
      pendingGet!.complete(response);
      await settle(t);
      expect(acks, isEmpty);
      if (boundary == 'background') {
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await settle(t);
        expect(gets(), 1);
        expect(acks, isEmpty);
      }
      await t.pumpWidget(const SizedBox());
    });
  }
  testWidgets(
    'ACK failure keeps result, explicit double retry single flight, no target GET or optimistic count',
    (t) async {
      failAck = true;
      await mount(t);
      await open(t);
      await settle(t);
      unread();
      expect(acks, [notificationId]);
      expect(find.byType(TableGroupDetailScreen), findsOneWidget);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(t);
      expect(acks.length, 1);
      failAck = false;
      pendingAck = Completer<Object?>();
      await t.tap(find.text('Tekrar dene'));
      await t.pump();
      await t.tap(find.text('Tekrar dene'));
      await t.pump();
      expect(acks.length, 2);
      expect(gets(), 1);
      unread();
      pendingAck!.complete(null);
      await settle(t);
      onlyTarget();
      expect(gets(), 1);
      await t.pumpWidget(const SizedBox());
    },
  );
  for (final closed in [false, true]) {
    testWidgets(
      'late ACK after cover closed=$closed does not project; explicit recovery on return',
      (t) async {
        if (closed) response['tableStatus'] = 'CANCELLED';
        pendingAck = Completer<Object?>();
        await mount(t);
        await open(t);
        await settle(t);
        expect(acks.length, 1);
        unawaited(
          nav.currentState!.push(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Cover')),
            ),
          ),
        );
        await settle(t);
        pendingAck!.complete(null);
        await settle(t);
        unread();
        nav.currentState!.pop();
        await settle(t);
        expect(acks.length, 1);
        await t.tap(find.text('Tekrar dene'));
        await settle(t);
        onlyTarget();
        expect(gets(), 1);
        await t.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets('second notification on same table has a new exact ticket', (
    t,
  ) async {
    await mount(t);
    await open(t);
    await settle(t);
    onlyTarget();
    nav.currentState!.pop();
    await settle(t);
    response = targetJson(id: siblingId);
    await open(t, selected: inbox.items.last);
    await settle(t);
    expect(acks, [notificationId, siblingId]);
    expect(cubit.state.unreadCount, 0);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
    'legacy or different cycle historical result does not show new pending actions',
    (t) async {
      response = targetJson(type: 'TABLE_JOIN_REQUEST_RECEIVED')
        ..['sameApplication'] = false
        ..['applicationId'] = null
        ..['participantStatus'] = 'PENDING';
      inbox.items = [
        item(notificationId, type: 'TABLE_JOIN_REQUEST_RECEIVED'),
        item(siblingId),
      ];
      await cubit.refresh();
      await mount(t);
      await open(t);
      await settle(t);
      expect(find.byType(TableGroupDetailScreen), findsOneWidget);
      expect(
        find.text('Bu bildirim önceki masa başvurusuna ait.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('table-exact-application-$cycleId')),
        findsNothing,
      );
      expect(
        api.requests.where((r) => r.path.endsWith('/chat/messages')),
        isEmpty,
      );
      onlyTarget();
      await t.pumpWidget(const SizedBox());
    },
  );

  Future<void> detail(
    WidgetTester t, {
    required bool pending,
    bool wrongCycle = false,
  }) async {
    response = targetJson(
      type: pending
          ? 'TABLE_JOIN_REQUEST_RECEIVED'
          : 'TABLE_JOIN_REQUEST_APPROVED',
      kind: pending ? 'PENDING_APPLICATION' : 'CHAT',
    );
    inbox.items = [
      item(notificationId, type: response['type'] as String),
      item(siblingId),
    ];
    await cubit.refresh();
    final target = TableNotificationTarget.fromJson(
      response,
      inbox.items.first,
    );
    final group = TableGroup(
      id: tableId,
      ownerId: pending ? recipient : applicant,
      ownerUsername: 'Owner',
      ownerProfileImageUrl: null,
      venueId: null,
      venueName: null,
      description: 'Görev masası',
      maxPersonCount: 6,
      genderPrefs: const [],
      ageMin: 18,
      ageMax: 99,
      meetingAt: DateTime.utc(2030),
      expiresAt: DateTime.utc(2030, 1, 2),
      status: 'ACTIVE',
      participants: [
        TableGroupParticipant(
          userId: pending ? recipient : applicant,
          joinedAt: DateTime.utc(2026),
          status: TableGroupParticipantStatus.accepted,
          joinNote: null,
          username: 'Owner',
          profilePictureUrl: null,
        ),
        TableGroupParticipant(
          userId: pending ? applicant : recipient,
          applicationId: wrongCycle ? siblingId : cycleId,
          joinedAt: DateTime.utc(2026),
          status: pending
              ? TableGroupParticipantStatus.pending
              : TableGroupParticipantStatus.accepted,
          joinNote: null,
          username: 'Exact applicant',
          profilePictureUrl: null,
        ),
        if (pending)
          TableGroupParticipant(
            userId: siblingId,
            applicationId: siblingId,
            joinedAt: DateTime.utc(2027),
            status: TableGroupParticipantStatus.pending,
            joinNote: null,
            username: 'Other applicant',
            profilePictureUrl: null,
          ),
      ],
      city: const TableGroupLocation(id: 'city', name: 'City'),
      district: null,
      neighborhood: null,
    );
    await mount(t);
    final route = MaterialPageRoute<void>(
      builder: (_) => TableGroupDetailScreen(
        args: TableGroupDetailArgs(
          tableGroupId: tableId,
          notificationTarget: target,
        ),
        repository: _Tables(group),
        gameRepository: _Games(),
        tokenStore: _Tokens(),
        sessions: sessions,
        realtimeClient: _ChatRealtime(),
        now: () => DateTime.utc(2026, 9, 30),
      ),
    );
    NotificationTargetRead.table(
      notification: target.notification,
      cubit: cubit,
      sessions: sessions,
      repository: targets,
      content: target,
    ).attach(route);
    unawaited(nav.currentState!.push(route));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await t.pump();
  }

  testWidgets(
    'approved chat error stays unread and performs no chat read; explicit recovery',
    (t) async {
      failChat = true;
      await detail(t, pending: false);
      await settle(t);
      expect(acks, isEmpty);
      unread();
      expect(api.requests.where((r) => r.query?['markRead'] == true), isEmpty);
      failChat = false;
      await t.tap(find.text('Tekrar dene'));
      await settle(t);
      expect(acks, [notificationId]);
      onlyTarget();
      expect(api.requests.where((r) => r.query?['markRead'] == true).length, 1);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'clipped exact application stays unread until scrolled fully into its panel',
    (t) async {
      final selected = item(
        notificationId,
        type: 'TABLE_JOIN_REQUEST_RECEIVED',
      );
      final target = TableNotificationTarget.fromJson(
        targetJson(type: selected.type, kind: 'PENDING_APPLICATION'),
        selected,
      );
      final scroll = ScrollController();
      await mount(t);
      final route = MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: 180,
              child: SingleChildScrollView(
                controller: scroll,
                child: Column(
                  children: [
                    const SizedBox(
                      height: 200,
                      child: Text('Other applicant only'),
                    ),
                    NotificationTargetReady(
                      requireVisibleBounds: true,
                      contentIdentity: target,
                      child: const SizedBox(
                        height: 100,
                        child: Text('Exact applicant'),
                      ),
                    ),
                    const SizedBox(height: 200),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      NotificationTargetRead.table(
        notification: target.notification,
        cubit: cubit,
        sessions: sessions,
        repository: targets,
        content: target,
      ).attach(route);
      unawaited(nav.currentState!.push(route));
      await settle(t);
      expect(acks, isEmpty);
      unread();
      scroll.jumpTo(60);
      await settle(t);
      expect(acks, isEmpty);
      unread(); // only part of exact row is visible
      scroll.jumpTo(200);
      await settle(t);
      expect(acks, [notificationId]);
      onlyTarget();
      await t.pumpWidget(const SizedBox());
      scroll.dispose();
    },
  );
  testWidgets(
    'owner exact request is visible before read; another newer row is insufficient',
    (t) async {
      pendingChat = Completer<Object?>();
      await detail(t, pending: true);
      expect(acks, isEmpty);
      unread();
      pendingChat!.complete(null);
      await settle(t);
      expect(find.text('Exact applicant'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('table-exact-application-$cycleId')),
        findsOneWidget,
      );
      expect(acks, [notificationId]);
      onlyTarget();
      await t.pumpWidget(const SizedBox());
    },
  );
  for (final pending in [true, false]) {
    testWidgets(
      'same user different cycle cannot open ${pending ? 'request' : 'chat'} or read',
      (t) async {
        await detail(t, pending: pending, wrongCycle: true);
        await settle(t);
        expect(acks, isEmpty);
        unread();
        expect(
          api.requests.where((r) => r.path.endsWith('/chat/messages')),
          isEmpty,
        );
        await t.pumpWidget(const SizedBox());
      },
    );
  }
  test('decision carries captured exact cycle and captured token', () async {
    final selected = item(notificationId, type: 'TABLE_JOIN_REQUEST_RECEIVED');
    final target = TableNotificationTarget.fromJson(
      targetJson(type: selected.type, kind: 'PENDING_APPLICATION'),
      selected,
    );
    expect(
      (await targets.decideTableApplication(
        target,
        sessions.session,
        approve: true,
      )).isSuccess,
      isTrue,
    );
    expect(api.lastRequest.query, {'applicationId': cycleId});
    expect(api.lastRequest.requestContext?.expectedToken, 'token');
    expect(acks, isEmpty);
  });
}

class _Inbox extends Fake implements NotificationRepository {
  List<AppNotification> items = [item(notificationId), item(siblingId)];
  @override
  Future<Result<Page<AppNotification>>> listNotifications({
    int page = 0,
    int size = 20,
  }) async => Result.success(Page(items: items, hasNext: false));
  @override
  Future<Result<int>> getUnreadCount() async =>
      Result.success(items.where((i) => !i.read).length);
}

class _Tokens extends Fake implements TokenStore {
  @override
  Future<String?> readToken() async =>
      'x.${base64Url.encode(utf8.encode(jsonEncode({'sub': recipient, 'userId': recipient, 'exp': 4102444800})))}.x';
}

class _Realtime extends NotificationRealtimeClient {
  @override
  Stream<AppNotification> get notificationStream => const Stream.empty();
  @override
  Stream<int> get badgeStream => const Stream.empty();
  @override
  Stream<void> get connectionStream => const Stream.empty();
  @override
  bool get isConnected => true;
  @override
  Future<void> connect({required String userId, required String token}) async {}
  @override
  Future<void> disconnect() async {}
}

class _Tables extends Fake implements TableGroupRepository {
  _Tables(this.group);
  final TableGroup group;
  @override
  Future<Result<TableGroup>> getDetail(String id) async =>
      Result.success(group);
}

class _Games extends Fake implements TableGroupGameRepository {
  @override
  Future<Result<TableGroupMessage?>> getActiveGame({
    required String tableGroupId,
  }) async => const Result.success(null);
}

class _ChatRealtime extends TableGroupChatRealtimeClient {
  @override
  Stream<TableGroupMessage> get messageStream => const Stream.empty();
  @override
  Stream<void> get connectionStream => const Stream.empty();
  @override
  Stream<RealtimeClientError> get errorStream => const Stream.empty();
  @override
  bool get isConnected => true;
  @override
  String? get connectedTableGroupId => tableId;
  @override
  Future<void> connect({
    required String tableGroupId,
    required String token,
  }) async {}
  @override
  Future<void> disconnect() async {}
}

class _TableFeed extends Fake implements TableGroupRepository {
  _TableFeed(this.target, {this.unavailable});
  final Map<String, dynamic> Function() target;
  final bool Function()? unavailable;

  @override
  Future<Result<TableGroup>> getDetail(String id) async {
    if (unavailable?.call() == true) return const Result.failure(fail);
    final value = target();
    final owner =
        const {
          'JOIN_REQUEST_RECEIVED',
          'PARTICIPANT_LEFT',
        }.contains(value['event'])
        ? recipient
        : applicant;
    return Result.success(
      TableGroup(
        id: id,
        ownerId: owner,
        ownerUsername: 'Owner',
        ownerProfileImageUrl: null,
        venueId: null,
        venueName: null,
        description: 'Güncel görev masası',
        maxPersonCount: 6,
        genderPrefs: const [],
        ageMin: 18,
        ageMax: 99,
        meetingAt: DateTime.utc(2030),
        expiresAt: DateTime.utc(2030, 1, 2),
        status: value['tableStatus'] as String,
        participants: [
          TableGroupParticipant(
            userId: owner,
            status: TableGroupParticipantStatus.accepted,
            joinedAt: DateTime.utc(2026),
            joinNote: null,
            username: 'Owner',
            profilePictureUrl: null,
          ),
        ],
        city: const TableGroupLocation(id: 'city', name: 'City'),
        district: null,
        neighborhood: null,
      ),
    );
  }

  @override
  Future<Result<Page<TableGroup>>> listActiveTableGroups({
    required String? cityId,
    String? districtId,
    String? neighborhoodId,
    int page = 0,
    int size = 20,
  }) async => const Result.success(Page(items: [], hasNext: false));
}

class _Locations extends Fake implements LocationRepository {
  @override
  Future<Result<List<City>>> getCities() async => const Result.success([]);
}

class _DmRepository extends Fake implements DmRepository {}

class _DmBadge extends DmBadgeCubit {
  _DmBadge() : super(_DmRepository(), _Tokens());

  @override
  Future<void> ensureStarted() async {}
}

class _Routes extends NavigatorObserver {
  final List<Route<dynamic>> stack = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      stack.add(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      stack.remove(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = stack.indexOf(oldRoute!);
    if (index != -1 && newRoute != null) stack[index] = newRoute;
  }
}
