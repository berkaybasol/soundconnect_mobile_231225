import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/core/push/push_provider.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/data/custom_notification_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/data/notification_target_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/domain/entities/app_notification.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/cubit/notification_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/notification_direct_open.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/notification_target_read.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/screens/custom_notification_open_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/screens/notification_screen.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/engagement_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_page.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/weekly_event_detail_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/venue_event_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/venue_event_detail.dart';

import 'support/event_audience_fakes.dart';
import 'support/notification_counter_fakes.dart';
import 'support/recording_api_client.dart';

part 'custom_notification_open_matrix_cases.dart';

const _notice = '50000000-0000-4000-8000-000000000001';
const _sibling = '50000000-0000-4000-8000-000000000002';
const _entity = '60000000-0000-4000-8000-000000000001';
const _target = PushTarget(
  notificationId: _notice,
  recipientId: counterOwner,
  type: 'ADMIN_BROADCAST',
);
const _failure = AppError(
  code: 'NETWORK',
  message: 'private transport diagnostic',
);

Map<String, dynamic> _destination({
  String kind = 'EVENTS',
  bool available = true,
}) => {
  'notificationId': _notice,
  'recipientId': counterOwner,
  'type': 'ADMIN_BROADCAST',
  'read': false,
  'state': available ? 'AVAILABLE' : 'UNAVAILABLE',
  'target': {
    'kind': available ? kind : 'HOME',
    if (const {'PROFILE', 'EVENT', 'CONTENT'}.contains(kind) && available)
      'targetId': _entity,
  },
};

void main() {
  setUp(() async => serviceLocator.reset());
  tearDown(() async => serviceLocator.reset());
  _registerProfileTargetMatrix();

  test(
    'fresh exact row and target use captured request context without ACK',
    () async {
      final h = _Harness();
      addTearDown(h.dispose);
      final result = await h.repository.resolve(_target, h.sessions.session);
      expect(result.isSuccess, isTrue);
      expect(result.data?.kind, 'EVENTS');
      expect(h.api.requests.map((r) => r.path), [
        '/api/v1/user/notifications/$_notice',
        '/api/v1/user/notifications/$_notice/custom-target',
      ]);
      for (final r in h.api.requests) {
        expect(r.method, RecordedHttpMethod.get);
        expect(r.requestContext?.expectedSessionKey, counterOwner);
        expect(r.requestContext?.expectedToken, h.sessions.session.token);
      }
      expect(h.acks, isEmpty);
    },
  );

  for (final invalid in [
    const PushTarget(
      notificationId: 'broken',
      recipientId: counterOwner,
      type: 'ADMIN_BROADCAST',
    ),
    const PushTarget(
      notificationId: _notice,
      recipientId: counterOtherOwner,
      type: 'ADMIN_BROADCAST',
    ),
    const PushTarget(
      notificationId: _notice,
      recipientId: counterOwner,
      type: 'ADMIN_UNKNOWN',
    ),
    const PushTarget(
      notificationId: _notice,
      recipientId: counterOwner,
      type: 'ADMIN_BROADCAST',
      conversationId: _entity,
    ),
  ]) {
    test(
      'invalid raw selection is rejected before HTTP ${invalid.notificationId}/${invalid.type}/${invalid.recipientId}/${invalid.conversationId}',
      () async {
        final h = _Harness();
        addTearDown(h.dispose);
        expect(
          (await h.repository.resolve(invalid, h.sessions.session)).isSuccess,
          isFalse,
        );
        expect(h.api.requests, isEmpty);
      },
    );
  }

  for (final phase in ['exact', 'target']) {
    for (final replacement in ['logout', 'same-user', 'other-user']) {
      test('captured session rejects late $phase after $replacement', () async {
        final h = _Harness();
        addTearDown(h.dispose);
        final pending = Completer<Object?>();
        final saved = phase == 'exact' ? h.exact() : h.destination();
        if (phase == 'exact') {
          h.exact = () => pending.future;
        } else {
          h.destination = () => pending.future;
        }
        final future = h.repository.resolve(_target, h.sessions.session);
        await Future<void>.delayed(Duration.zero);
        h.sessions.replace(
          replacement == 'logout'
              ? const AuthSession.guest()
              : audienceSession(
                  user: replacement == 'other-user'
                      ? counterOtherOwner
                      : counterOwner,
                  token: 'replacement',
                ),
        );
        pending.complete(saved);
        expect(
          (await future).error?.code,
          NotificationTargetRepository.stale.code,
        );
        expect(h.gets, phase == 'exact' ? 1 : 2);
        expect(h.acks, isEmpty);
      });
    }
  }

  test('foreign or malformed exact row cannot request a target', () async {
    final h = _Harness();
    addTearDown(h.dispose);
    final original = h.exact() as Map<String, dynamic>;
    for (final patch in [
      {'id': _sibling},
      {'recipientId': counterOtherOwner},
      {'type': 'SOCIAL_LIKE'},
      {'read': 'false'},
      {'payload': 'invalid'},
    ]) {
      h.api.requests.clear();
      h.exact = () => {...original, ...patch};
      expect(
        (await h.repository.resolve(_target, h.sessions.session)).isSuccess,
        isFalse,
        reason: '$patch',
      );
      expect(h.gets, 1);
    }
  });

  test(
    'unknown malformed foreign and noncanonical terminal targets fail closed',
    () async {
      final h = _Harness();
      addTearDown(h.dispose);
      final valid = _destination();
      final invalid = <Map<String, dynamic>>[
        {...valid, 'notificationId': _sibling},
        {...valid, 'recipientId': counterOtherOwner},
        {...valid, 'type': 'SYSTEM'},
        {...valid, 'read': 'false'},
        {...valid, 'state': 'MISSING'},
        {
          ...valid,
          'target': {'kind': 'URL', 'targetId': 'https://untrusted.invalid'},
        },
        {
          ...valid,
          'target': {'kind': 'HOME', 'targetId': _entity},
        },
        {
          ...valid,
          'target': {'kind': 'PROFILE', 'targetId': 'invalid'},
        },
        {
          ...valid,
          'target': {'kind': 'EVENT', 'targetId': _entity},
          'event': {'id': _sibling},
        },
        {
          ...valid,
          'target': {'kind': 'CONTENT', 'targetId': _entity},
          'media': {'id': _entity, 'kind': 'UNKNOWN'},
        },
        {
          ..._destination(available: false),
          'target': {'kind': 'PROFILE', 'targetId': _entity},
        },
        {
          ..._destination(available: false),
          'event': {'id': _entity},
        },
      ];
      for (final json in invalid) {
        h.destination = () => json;
        expect(
          (await h.repository.resolve(_target, h.sessions.session)).isSuccess,
          isFalse,
          reason: '$json',
        );
      }
      expect(h.acks, isEmpty);
    },
  );

  testWidgets(
    'module starts loading, wrong kind cannot read, exact ready paint ACKs only selected row',
    (t) async {
      final h = _Harness();
      await h.mount(t);
      await t.pumpAndSettle();
      expect(
        find.text('Destination ${AppRoutes.eventDiscovery}'),
        findsOneWidget,
      );
      expect(h.gets, 2);
      expect(h.acks, isEmpty);
      h.presenterKind = 'TABLES';
      h.ready.value = true;
      await t.pumpAndSettle();
      expect(h.acks, isEmpty);
      h.presenterKind = 'EVENTS';
      h.ready.value = false;
      h.ready.value = true;
      await t.pumpAndSettle();
      expect(h.acks, [_notice]);
      h.expectOnlySelectedRead();
    },
  );

  testWidgets(
    'available destination ACK retry is deliberate and never repeats target GET',
    (t) async {
      final h = _Harness()..ackFailures = 1;
      h.ready.value = true;
      await h.mount(t);
      await t.pumpAndSettle();
      expect(h.acks, [_notice]);
      expect(h.gets, 2);
      expect(h.cubit.state.unreadCount, 2);
      expect(find.text('Tekrar dene'), findsOneWidget);
      await t.pump(const Duration(seconds: 8));
      await t.pumpAndSettle();
      expect(h.acks, [_notice]);
      await t.tap(find.text('Tekrar dene'));
      await t.pumpAndSettle();
      expect(h.acks, [_notice, _notice]);
      expect(h.gets, 2);
      h.expectOnlySelectedRead();
    },
  );

  testWidgets(
    'exact terminal stays on original product and uses ACK-only retry',
    (t) async {
      final h = _Harness()..ackFailures = 1;
      h.destination = () => _destination(available: false);
      await h.mount(t);
      await t.pumpAndSettle();
      expect(find.text('Original product'), findsOneWidget);
      expect(find.text('Tekrar dene'), findsOneWidget);
      expect(h.routeNames, isEmpty);
      expect(h.acks, [_notice]);
      await t.tap(find.text('Tekrar dene'));
      await t.pumpAndSettle();
      expect(h.gets, 2);
      expect(h.acks, [_notice, _notice]);
      h.expectOnlySelectedRead();
    },
  );

  for (final failure in ['offline', 'malformed']) {
    testWidgets(
      '$failure target keeps unread and small explicit retry on origin',
      (t) async {
        final h = _Harness()
          ..destination = () {
            if (failure == 'offline') throw ApiException(_failure);
            return {'state': 'UNAVAILABLE'};
          };
        await h.mount(t);
        await t.pumpAndSettle();
        expect(h.acks, isEmpty);
        expect(h.routeNames, isEmpty);
        expect(find.text('Original product'), findsOneWidget);
        expect(find.text('private transport diagnostic'), findsNothing);
        expect(find.text('Tekrar dene'), findsOneWidget);
        h.destination = () => _destination();
        h.ready.value = true;
        await t.tap(find.text('Tekrar dene'));
        await t.pumpAndSettle();
        expect(h.gets, 4);
        expect(h.acks, [_notice]);
        h.expectOnlySelectedRead();
      },
    );
  }

  for (final hidden in ['paused', 'covered', 'session', 'disposed']) {
    testWidgets(
      'late target while $hidden never opens or ACKs; retry is explicit',
      (t) async {
        final pending = Completer<Object?>();
        final h = _Harness()..destination = () => pending.future;
        h.ready.value = true;
        await h.mount(t);
        await t.pumpAndSettle();
        expect(h.gets, 2);
        if (hidden == 'paused') {
          t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        }
        if (hidden == 'covered') {
          unawaited(
            h.navigator.currentState!.push(
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('Cover')),
              ),
            ),
          );
        }
        if (hidden == 'session') {
          h.sessions.replace(
            // A replacement object with the same credentials is still a new
            // capture. Token-changing races are covered at both HTTP phases.
            audienceSession(user: counterOwner, role: 'ROLE_MUSICIAN'),
          );
        }
        if (hidden == 'disposed') await t.pumpWidget(const SizedBox.shrink());
        pending.complete(_destination());
        await t.pumpAndSettle();
        expect(h.acks, isEmpty);
        expect(h.routeNames, isEmpty);
        if (hidden == 'paused') {
          t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        }
        if (hidden == 'covered') h.navigator.currentState!.pop();
        await t.pumpAndSettle();
        expect(h.gets, 2);
        expect(h.acks, isEmpty);
        if (hidden == 'paused' || hidden == 'covered') {
          expect(find.text('Tekrar dene'), findsOneWidget);
          h.destination = () => _destination();
          await t.tap(find.text('Tekrar dene'));
          await t.pumpAndSettle();
          expect(h.gets, 4);
          expect(h.acks, [_notice]);
        } else {
          expect(find.text('Tekrar dene'), findsNothing);
        }
      },
    );
  }
}

class _Harness {
  _Harness({String role = 'MUSICIAN'})
    : sessions = AudienceTestSessions(
        audienceSession(user: counterOwner, role: 'ROLE_$role'),
      ) {
    rows = CounterRepository([
      const AppNotification(
        id: _notice,
        recipientId: counterOwner,
        type: 'ADMIN_BROADCAST',
        title: 'Owned custom',
        message: 'Fresh copy',
        read: false,
        createdAt: null,
        payload: {},
      ),
      counterNotification(_sibling),
    ]);
    cubit = NotificationCubit(
      rows,
      CounterTokens(),
      sessions: sessions,
      realtimeClient: realtime,
    );
    exact = () => {
      'id': _notice,
      'recipientId': counterOwner,
      'type': 'ADMIN_BROADCAST',
      'read': false,
      'payload': <String, dynamic>{},
    };
    api = RecordingApiClient((request) async {
      if (request.path.endsWith('/read')) {
        acks.add(request.path.split('/').reversed.elementAt(1));
        if (ackFailures-- > 0) throw ApiException(_failure);
        rows.commitRead(_notice);
        return null;
      }
      return request.path.endsWith('/custom-target')
          ? await destination()
          : await exact();
    });
    repository = CustomNotificationRepository(api, sessions);
  }
  final AudienceTestSessions sessions;
  final realtime = _Realtime();
  late final CounterRepository rows;
  late final NotificationCubit cubit;
  late final RecordingApiClient api;
  late final CustomNotificationRepository repository;
  late FutureOr<Object?> Function() exact;
  FutureOr<Object?> Function() destination = () => _destination();
  final navigator = GlobalKey<NavigatorState>();
  final ready = ValueNotifier(false);
  String presenterKind = 'EVENTS';
  final routeNames = <String?>[];
  final acks = <String>[];
  int ackFailures = 0;
  int get gets =>
      api.requests.where((r) => r.method == RecordedHttpMethod.get).length;

  Future<void> mount(WidgetTester t, {bool inbox = false}) async {
    serviceLocator
      ..registerSingleton<AuthSessionManager>(sessions)
      ..registerSingleton<NotificationCubit>(cubit)
      ..registerSingleton<CustomNotificationRepository>(repository)
      ..registerSingleton<NotificationTargetRepository>(
        NotificationTargetRepository(api, sessions),
      );
    addTearDown(() async {
      await t.pumpWidget(const SizedBox.shrink());
      await dispose();
    });
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await cubit.ensureStarted();
    await t.pumpWidget(
      BlocProvider<NotificationCubit>.value(
        value: cubit,
        child: MaterialApp(
          navigatorKey: navigator,
          navigatorObservers: [notificationTargetRouteObserver],
          home: inbox
              ? const NotificationScreen()
              : const Scaffold(body: Text('Original product')),
          onGenerateRoute: (settings) {
            routeNames.add(settings.name);
            final route = MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => Scaffold(
                body: ValueListenableBuilder<bool>(
                  valueListenable: ready,
                  builder: (_, loaded, _) => NotificationTargetReady(
                    ready: loaded,
                    customModuleKinds: {presenterKind},
                    child: SizedBox(
                      width: 300,
                      height: 200,
                      child: Text('Destination ${settings.name}'),
                    ),
                  ),
                ),
              ),
            );
            final args = settings.arguments;
            return args is NotificationReadArguments
                ? args.ticket.attach(route)
                : route;
          },
        ),
      ),
    );
    await t.pump();
    if (inbox) {
      await t.pumpAndSettle();
      await t.tap(find.text('Owned custom'));
      return;
    }
    final parsed = PushTarget.parseNativeMetadata({
      'notificationId': _notice,
      'recipientId': counterOwner,
      'type': 'ADMIN_BROADCAST',
    });
    expect(parsed, isNotNull);
    unawaited(
      NotificationDirectOpen.start(
        navigator.currentContext!,
        identity: _notice,
        builder: (_) => CustomNotificationOpenScreen(target: parsed!),
      ),
    );
  }

  void expectOnlySelectedRead() {
    expect(cubit.state.unreadCount, 1);
    expect(cubit.state.items.singleWhere((n) => n.id == _notice).read, isTrue);
    expect(
      cubit.state.items.singleWhere((n) => n.id == _sibling).read,
      isFalse,
    );
  }

  Future<void> dispose() async {
    await cubit.close();
    await realtime.dispose();
    sessions.dispose();
    ready.dispose();
  }
}

class _Realtime extends CounterRealtime {
  @override
  Future<void> connect({required String userId, required String token}) async {}
}
