import 'support/notification_direct_test_host.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/core/push/push_device_api.dart';
import 'package:soundconnect_23_12_25codx/core/push/push_provider.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/data/notification_target_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/domain/entities/app_notification.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/cubit/notification_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/notification_target_read.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/screens/notification_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/screens/venue_notification_open_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/venue_owner_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/venue_profile_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/profile_route_args.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'support/event_audience_fakes.dart';

const _id = 'd013d478-b9b3-41af-83b4-b620e5032b29';
const _user = '17f98910-28e7-46b9-af68-6217f678b707';
const _venue = '83a94c29-b031-4d30-9794-df14f2a35bce';
const _type = 'ARTIST_VENUE_LINK_APPLICATION_REQUEST';
PushTarget _target([String type = _type]) =>
    PushTarget(notificationId: _id, recipientId: _user, type: type);
Map<String, dynamic> _dto([String type = _type]) => {
  'id': _id,
  'recipientId': _user,
  'type': type,
  'title': 'Fixture',
  'message': '',
  'read': false,
  'payload': {
    'module': type.startsWith('ARTIST_VENUE')
        ? 'ARTIST_VENUE'
        : 'EVENT_PERFORMER',
    'action': 'REQUEST_CREATED',
    'requestByType': 'ARTIST',
    'venueId': _venue,
  },
};

void main() {
  late AudienceTestSessions sessions;
  late _Api api;
  late NotificationTargetRepository repository;
  setUp(() {
    sessions = AudienceTestSessions(
      audienceSession(user: _user, role: 'ROLE_VENUE'),
    );
    api = _Api();
    repository = NotificationTargetRepository(api, sessions);
  });
  tearDown(() async {
    sessions.dispose();
    await serviceLocator.reset();
  });

  for (final type in PushTarget.venueTypes) {
    test(
      '$type parses minimal native target and resolves exact session-fenced DTO',
      () async {
        final target = PushTarget.parse({
          'notificationId': _id,
          'recipientId': _user,
          'type': type,
        });
        expect(target?.isVenue, isTrue);
        api.response = _dto(type);
        final result = await repository.resolve(target!, sessions.session);
        expect(result.isSuccess, isTrue);
        expect(api.calls.single.path, '/api/v1/user/notifications/$_id');
        expect(api.calls.single.context?.expectedSessionKey, _user);
        expect(api.calls.single.context?.expectedToken, sessions.session.token);
        expect(api.calls.single.method, ApiHttpMethod.get);
        expect(
          PushTarget.parse({
            'notificationId': _id,
            'recipientId': _user,
            'type': type,
            'conversationId': _venue,
          }),
          isNull,
        );
      },
    );
  }
  for (final module in ['EVENT_PERFORMER', 'EVENT_PLAN']) {
    test(
      'event source $module accepted; unknown source cannot route',
      () async {
        api.response = _dto('EVENT_PERFORMER_REJECTED')
          ..['payload'] = {'module': module, 'planId': _venue};
        expect(
          (await repository.resolve(
            _target('EVENT_PERFORMER_REJECTED'),
            sessions.session,
          )).isSuccess,
          isTrue,
        );
      },
    );
  }
  for (final wrong in [
    {'id': _venue},
    {'recipientId': _venue},
    {'type': 'EVENT_PERFORMER_APPROVED'},
    {
      'payload': {'module': 'EVENT_VENUE'},
    },
    {
      'payload': {'module': 'EVENT_PLAN'},
    },
  ]) {
    test('rejects mismatched authoritative notification $wrong', () async {
      api.response = _dto()..addAll(wrong);
      expect(
        (await repository.resolve(_target(), sessions.session)).isSuccess,
        isFalse,
      );
    });
  }
  for (final badSession in [
    const AuthSession.guest(),
    audienceSession(user: _user, role: 'ROLE_LISTENER'),
    audienceSession(
      user: _user,
      role: 'ROLE_VENUE',
      status: 'PENDING_VENUE_REQUEST',
    ),
    audienceSession(user: _venue, role: 'ROLE_VENUE'),
  ]) {
    test(
      'unusable or other recipient is rejected before network ${badSession.roles}/${badSession.userId}',
      () async {
        sessions.replace(badSession);
        expect(
          (await repository.resolve(_target(), sessions.session)).isSuccess,
          isFalse,
        );
        expect(api.calls, isEmpty);
      },
    );
  }
  test('enum-only venue types never resolve; DM remains separate', () async {
    for (final type in [
      'EVENT_VENUE_APPROVED',
      'EVENT_PERFORMER_ADDED',
      'DM_NEW_MESSAGE',
    ]) {
      expect(
        (await repository.resolve(_target(type), sessions.session)).isSuccess,
        isFalse,
      );
    }
    expect(api.calls, isEmpty);
  });
  test('GET is read-only; one explicit ACK uses same captured token', () async {
    final captured = sessions.session;
    final item = (await repository.resolve(_target(), captured)).data!;
    expect(api.calls.length, 1);
    expect((await repository.acknowledge(item, captured)).isSuccess, isTrue);
    expect(api.calls.last.path, '/api/v1/user/notifications/$_id/read');
    expect(api.calls.last.context?.expectedToken, captured.token);
  });
  test(
    'late lookup after same-account token replacement is discarded and cannot ACK',
    () async {
      final captured = sessions.session;
      final pending = Completer<Object?>();
      api.pending = pending;
      final resolving = repository.resolve(_target(), captured);
      sessions.replace(
        audienceSession(
          user: _user,
          token: 'replacement-token',
          role: 'ROLE_VENUE',
        ),
      );
      pending.complete(_dto());
      expect(
        (await resolving).error?.code,
        'notification_target_session_changed',
      );
      expect(api.calls.length, 1);
    },
  );
  test(
    'typed missing/authorization error is preserved without leaking raw UI data',
    () async {
      api.failure = ApiException(
        const AppError(code: 'NOTIFICATION_NOT_FOUND', message: 'Unavailable'),
      );
      expect(
        (await repository.resolve(_target(), sessions.session)).error?.code,
        'NOTIFICATION_NOT_FOUND',
      );
    },
  );
  test(
    'new Android capability preserves disabled category preferences on save',
    () async {
      final devices = HttpPushDeviceApi(api);
      await devices.register(
        session: sessions.session,
        installationId: _venue,
        clientRevision: 9,
        token: 'fixture',
        platform: 'ANDROID',
        permission: PushPermission.authorized,
      );
      expect(
        (api.calls.single.body as Map)['presentationVersion'],
        'ANDROID_NATIVE_V11',
      );
      await devices.savePreferences(
        sessions.session,
        const PushPreferences(
          enabled: true,
          disabledCategories: {'EVENT', 'ARTIST_VENUE'},
        ),
      );
      expect(
        (api.calls.last.body as Map)['disabledCategories'],
        unorderedEquals(['EVENT', 'ARTIST_VENUE']),
      );
    },
  );

  Future<(_Cubit, _Venues)> mount(
    WidgetTester tester, {
    GlobalKey<NavigatorState>? navigator,
    void Function(_Venues)? prepare,
    PushTarget? target,
  }) async {
    await serviceLocator.reset();
    final cubit = _Cubit();
    final venues = _Venues();
    prepare?.call(venues);
    serviceLocator.registerSingleton<AuthSessionManager>(sessions);
    serviceLocator.registerSingleton<NotificationTargetRepository>(repository);
    serviceLocator.registerSingleton<NotificationCubit>(cubit);
    serviceLocator.registerSingleton<VenueProfileRepository>(venues);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [notificationTargetRouteObserver],
        home: NotificationDirectTestHost(
          opener: VenueNotificationOpenScreen(target: target ?? _target()),
        ),
        onGenerateRoute: (settings) {
          final envelope = settings.arguments as NotificationReadArguments;
          final args = envelope.arguments as VenueProfileArgs?;
          return envelope.ticket.attach(
            MaterialPageRoute<void>(
              settings: RouteSettings(name: settings.name, arguments: args),
              builder: (_) => NotificationTargetReady(
                child: Scaffold(
                  body: Text('opened:${settings.name}:${args?.venueId}'),
                ),
              ),
            ),
          );
        },
      ),
    );
    return (cubit, venues);
  }

  testWidgets(
    'native target opens verified venue directly and ACKs only itself; no inbox mount',
    (tester) async {
      final (cubit, venues) = await mount(tester);
      await tester.pumpAndSettle();
      expect(
        find.text('opened:${AppRoutes.venueProfile}:$_venue'),
        findsOneWidget,
      );
      expect(find.byType(NotificationScreen), findsNothing);
      expect(venues.reads, [_venue]);
      expect(
        api.calls
            .where((call) => call.method == ApiHttpMethod.post)
            .map((call) => call.path),
        ['/api/v1/user/notifications/$_id/read'],
      );
      expect(cubit.applied, [_id]);
    },
  );
  testWidgets(
    'foreign current venue ownership fails closed without single ACK',
    (tester) async {
      await mount(tester, prepare: (venues) => venues.owner = _venue);
      await tester.pumpAndSettle();
      expect(
        find.byType(VenueNotificationOpenScreen, skipOffstage: false),
        findsOneWidget,
      );
      expect(find.text('Tekrar dene'), findsOneWidget);
      expect(
        api.calls.where((call) => call.method == ApiHttpMethod.post),
        isEmpty,
      );
    },
  );
  for (final action in ['ACCEPT', 'REJECT']) {
    testWidgets('venue-origin connection $action opens exact owned venue', (
      tester,
    ) async {
      final type = 'ARTIST_VENUE_LINK_APPLICATION_$action';
      api.response = _dto(type)
        ..['payload'] = {
          'module': 'ARTIST_VENUE',
          'action': 'REQUEST_${action == 'ACCEPT' ? 'ACCEPTED' : 'REJECTED'}',
          'requestByType': 'VENUE',
          'venueId': _venue,
        };
      final (cubit, _) = await mount(tester, target: _target(type));
      await tester.pumpAndSettle();
      expect(
        find.text('opened:${AppRoutes.venueProfile}:$_venue'),
        findsOneWidget,
      );
      expect(cubit.applied, [_id]);
    });
  }
  testWidgets(
    'same-account token changes while owner preflight is pending never ACK',
    (tester) async {
      final (_, venues) = await mount(
        tester,
        prepare: (v) => v.pending = Completer<Result<VenueOwnerProfile>>(),
      );
      sessions.replace(
        audienceSession(user: _user, token: 'new', role: 'ROLE_VENUE'),
      );
      venues.pending!.complete(Result.success(_profile(_user)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        api.calls.where((call) => call.method == ApiHttpMethod.post),
        isEmpty,
      );
    },
  );
  testWidgets('lookup failure shows retry; no inbox or read-all fallback', (
    tester,
  ) async {
    api.failure = StateError('offline');
    await mount(tester);
    await tester.pumpAndSettle();
    expect(find.text('Tekrar dene'), findsOneWidget);
    expect(find.byType(NotificationScreen), findsNothing);
    expect(api.calls.length, 1);
  });
  testWidgets(
    'origin change during owner lookup discards late navigation and ACK',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      final (_, venues) = await mount(
        tester,
        navigator: navigator,
        prepare: (venues) =>
            venues.pending = Completer<Result<VenueOwnerProfile>>(),
      );
      await tester.pump();
      unawaited(
        navigator.currentState!.push(
          MaterialPageRoute<void>(builder: (_) => const Text('other route')),
        ),
      );
      venues.pending!.complete(Result.success(_profile(_user)));
      await tester.pumpAndSettle();
      expect(find.text('other route'), findsOneWidget);
      expect(
        api.calls.where((call) => call.method == ApiHttpMethod.post),
        isEmpty,
      );
    },
  );
}

typedef _Call = ({
  ApiHttpMethod method,
  String path,
  Object? body,
  ApiRequestContext? context,
});

class _Api extends Fake implements ApiClient {
  Object? response = _dto();
  Object? failure;
  Completer<Object?>? pending;
  final calls = <_Call>[];
  @override
  Future<T> request<T>(
    ApiHttpMethod method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    T Function(Object?)? decoder,
    ApiRequestContext? requestContext,
  }) async {
    calls.add((
      method: method,
      path: path,
      body: body,
      context: requestContext,
    ));
    if (failure != null) throw failure!;
    final value = method == ApiHttpMethod.get
        ? await (pending?.future ?? Future.value(response))
        : null;
    return decoder == null ? value as T : decoder(value);
  }
}

class _Cubit extends Fake implements NotificationCubit {
  final applied = <String>[];
  @override
  bool get isClosed => false;
  @override
  Future<void> applyConfirmedExternalRead(
    AppNotification notification,
    AuthSession session,
  ) async {
    applied.add(notification.id);
  }
}

class _Venues extends Fake implements VenueProfileRepository {
  String owner = _user;
  final reads = <String?>[];
  Completer<Result<VenueOwnerProfile>>? pending;
  @override
  Future<Result<VenueOwnerProfile>> getMyVenueProfileDetail({
    String? venueId,
  }) async {
    reads.add(venueId);
    return pending?.future ?? Result.success(_profile(owner));
  }
}

VenueOwnerProfile _profile(String owner) => VenueOwnerProfile(
  venueProfileId: _id,
  venueId: _venue,
  ownerUserId: owner,
  venueName: 'Fixture',
  bio: null,
  profilePictureUrl: null,
  instagramUrl: null,
  youtubeUrl: null,
  websiteUrl: null,
  address: null,
  phone: null,
  website: null,
  description: null,
  musicStartTime: null,
  cityId: null,
  cityName: null,
  districtId: null,
  districtName: null,
  neighborhoodId: null,
  neighborhoodName: null,
  status: 'ACTIVE',
  activeMusicians: [],
  activeBands: [],
  weeklyEvents: [],
);
