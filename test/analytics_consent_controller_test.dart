import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_store.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/modules/analytics/data/analytics_consent_controller.dart';
import 'package:soundconnect_23_12_25codx/modules/analytics/data/analytics_consent_store.dart';
import 'package:soundconnect_23_12_25codx/modules/analytics/data/analytics_measurement.dart';
import 'package:soundconnect_23_12_25codx/modules/analytics/data/analytics_live_activity.dart';
import 'package:soundconnect_23_12_25codx/modules/analytics/data/analytics_tracker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Sessions sessions;
  late _Api api;
  late _Measurement measurement;
  late AnalyticsConsentController controller;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({
      AnalyticsTracker.installationKey: 'legacy-id',
      AnalyticsTracker.queueKey: 'legacy-queue',
    });
    sessions = _Sessions();
    api = _Api();
    measurement = _Measurement();
    controller = AnalyticsConsentController(
      sessions,
      AnalyticsConsentStore(api, environment: 'staging'),
      measurement,
      liveActivity: AnalyticsLiveActivity(api, sessions),
    );
  });
  tearDown(() {
    controller.dispose();
    sessions.dispose();
  });
  test(
    'new member notice requires a fresh grant and preserves earlier guest and member refusals',
    () async {
      final legacy = {
        ..._response('GRANTED', 5),
        'policyVersion': '2026-11-26',
      };
      expect(
        AnalyticsPreference.decode(legacy).choice,
        ConsentChoice.undecided,
      );
      expect(AnalyticsPreference.decode(legacy).identity, isNull);
      final denied = {..._response('DENIED', 6), 'policyVersion': '2026-11-26'};
      expect(AnalyticsPreference.decode(denied).choice, ConsentChoice.denied);
      expect(
        AnalyticsPreference.decode(_response('DENIED', 6)).choice,
        ConsentChoice.denied,
      );
      expect(AnalyticsPreference.decode(_response('GRANTED', 7)).identity, _id);
      final store = AnalyticsConsentStore(api, environment: 'staging');
      FlutterSecureStorage.setMockInitialValues({
        'analytics_guest_2026-11-26_staging': _id,
      });
      expect((await store.guest()).choice, ConsentChoice.undecided);
      expect((await store.guest()).guestLiveId, isNull);
      final legacyR2 = {
        ..._response('GRANTED', 7),
        'policyVersion': '2026-11-26-r2',
      };
      expect(
        AnalyticsPreference.decode(legacyR2).choice,
        ConsentChoice.undecided,
      );
      expect(
        AnalyticsPreference.decode({
          ..._response('DENIED', 7),
          'policyVersion': '2026-11-26-r2',
        }).choice,
        ConsentChoice.denied,
      );
      FlutterSecureStorage.setMockInitialValues({
        'analytics_guest_2026-11-26_staging': 'denied',
      });
      expect((await store.guest()).choice, ConsentChoice.denied);
    },
  );
  test(
    'guest decisions stay on device and accounts never inherit them',
    () async {
      await controller.start();
      expect(controller.choice, ConsentChoice.undecided);
      expect(measurement.starts, isEmpty);
      expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
      await controller.choose(false);
      expect(controller.choice, ConsentChoice.denied);
      expect(measurement.starts, isEmpty);
      await controller.choose(true);
      final guestId = measurement.active;
      expect(guestId, isNotNull);
      expect(api.calls, isEmpty);
      final guestRevision = controller.subjectRevision;
      sessions.login('a');
      expect(measurement.active, isNull);
      await Future<void>.delayed(Duration.zero);
      expect(controller.choice, ConsentChoice.undecided);
      await expectLater(
        controller.choose(true, expectedSubject: guestRevision),
        throwsStateError,
      );
      await controller.choose(true);
      expect(measurement.active, _id);
      expect(api.calls.last.expectedSessionKey, 'a');
      expect(api.calls.last.expectedToken, 't-a');
      sessions.change(const AuthSession.guest());
      await Future<void>.delayed(Duration.zero);
      expect(measurement.active, guestId);
      expect(measurement.starts, [guestId, _id, guestId]);
    },
  );
  test(
    'an old member read cannot turn on analytics after an account switch',
    () async {
      sessions.login('a');
      final gate = Completer<Map<String, Object?>>();
      api.readGate = gate;
      final first = controller.start();
      await Future<void>.delayed(Duration.zero);
      sessions.login('b');
      await Future<void>.delayed(Duration.zero);
      gate.complete(_response('GRANTED', 1));
      await first;
      expect(controller.choice, ConsentChoice.undecided);
      expect(measurement.starts, isEmpty);
      expect(api.calls.map((c) => c.expectedSessionKey), ['a', 'b']);
    },
  );
  testWidgets(
    'guest needs a fresh choice, keeps separate IDs, and only sends during a granted foreground',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({
        'analytics_guest_2026-11-26_staging': _id,
      });
      await controller.start();
      await tester.pump(const Duration(minutes: 2));
      expect(api.live, isEmpty);
      await controller.choose(true);
      final first = api.live.single;
      final liveId = first.body['installationId'];
      expect(first.path, '/api/v1/analytics/live-activity/guest');
      expect(
        first.body.keys,
        unorderedEquals(['installationId', 'policyVersion']),
      );
      expect(first.body['policyVersion'], '2026-11-26-r3');
      expect(first.context.requireGuestSession, isTrue);
      expect(first.context.expectedToken, isNull);
      expect(liveId, isA<String>());
      expect(liveId, isNot(measurement.active));
      expect(measurement.active, isNot(_id));
      final stored = await AnalyticsConsentStore(
        api,
        environment: 'staging',
      ).guest();
      expect(stored.choice, ConsentChoice.granted);
      expect(stored.guestLiveId, liveId);
      await tester.pump(const Duration(seconds: 60));
      await tester.pump();
      expect(controller.error, isNull);
      expect(api.live.length, 2);
      expect(api.live.last.body['installationId'], liveId);
      controller.setForeground(false);
      await tester.pump(const Duration(minutes: 6));
      expect(api.live.length, 2);
      controller.setForeground(true);
      await tester.pump();
      expect(api.live.length, 3);
      await controller.choose(false);
      await tester.pump(const Duration(minutes: 1));
      expect(api.live.length, 3);
      await controller.choose(true);
      expect(api.live.last.body['installationId'], isNot(liveId));
      expect(api.live.last.body['installationId'], isNot(measurement.active));
      await controller.choose(false);
    },
  );
  testWidgets(
    'member activity uses the current credential and drops an outstanding send on withdrawal',
    (tester) async {
      sessions.login('a');
      await controller.start();
      expect(api.live, isEmpty);
      api.liveGate = Completer<void>();
      await controller.choose(true);
      final first = api.live.single;
      expect(first.path, '/api/v1/analytics/live-activity/member');
      expect(first.context.expectedSessionKey, 'a');
      expect(first.context.expectedToken, 't-a');
      expect(first.context.expectedCredentialRevision, sessions.revision);
      expect(first.body, {
        'analyticsUserId': _id,
        'policyVersion': AnalyticsPreference.policy,
      });
      var cancelled = false;
      first.context.cancelOn!.then((_) => cancelled = true);
      await tester.pump(const Duration(seconds: 60));
      expect(api.live.length, 1);
      await controller.choose(false);
      expect(cancelled, isTrue);
      api.liveGate!.complete();
      await tester.pump(const Duration(minutes: 2));
      expect(api.live.length, 1);
    },
  );
  testWidgets(
    'a slow preference read from before background cannot start a live visit after resume',
    (tester) async {
      sessions.login('a');
      final stale = api.readGate = Completer<Map<String, Object?>>();
      final started = controller.start();
      await tester.pump();
      controller.setForeground(false);
      controller.setForeground(true);
      await tester.pump();
      stale.complete(_response('GRANTED', 1));
      await started;
      expect(controller.choice, ConsentChoice.undecided);
      expect(api.live, isEmpty);
    },
  );
  testWidgets(
    'foreground member learns a remote withdrawal on the next minute check',
    (tester) async {
      sessions.login('a');
      api.current = _response('GRANTED', 1);
      await controller.start();
      expect(measurement.active, _id);
      api.current = _response('DENIED', 2);
      await tester.pump(const Duration(seconds: 59));
      expect(measurement.active, _id);
      await tester.pump(const Duration(seconds: 1));
      expect(controller.choice, ConsentChoice.denied);
      expect(measurement.active, isNull);
    },
  );
  testWidgets(
    'failed withdrawal blocks locally until a revision-fenced denial reaches server',
    (tester) async {
      sessions.login('a');
      api.current = _response('GRANTED', 1);
      await controller.start();
      expect(measurement.active, _id);
      api.offline = true;
      final withdrawing = controller.choose(false);
      expect(measurement.active, isNull);
      await expectLater(withdrawing, throwsStateError);
      expect(controller.choice, ConsentChoice.denied);
      final initialCalls = api.calls.length;
      await tester.pump(const Duration(seconds: 2));
      expect(api.calls.length, initialCalls + 1);
      api.offline = false;
      await tester.pump(const Duration(seconds: 4));
      expect(api.current['decision'], 'GRANTED');
      await tester.pump(const Duration(seconds: 1));
      expect(api.current['decision'], 'DENIED');
      expect(measurement.starts, [_id]);
      expect(controller.error, isNull);
    },
  );
  testWidgets(
    'offline restart recovers a persisted denial, without retrying in the background',
    (tester) async {
      sessions.login('a');
      await AnalyticsConsentStore(
        api,
        environment: 'staging',
      ).setPendingDenial('a', 1);
      api.current = _response('GRANTED', 1);
      api.offline = true;
      await controller.start();
      expect(controller.choice, ConsentChoice.denied);
      controller.setForeground(false);
      final before = api.calls.length;
      await tester.pump(const Duration(minutes: 2));
      expect(api.calls.length, before);
      api.offline = false;
      controller.setForeground(true);
      await tester.pump();
      expect(api.current['decision'], 'DENIED');
      expect(measurement.starts, isEmpty);
    },
  );
  testWidgets(
    'a newer remote decision stops automatic denial retries and leaves collection off',
    (tester) async {
      sessions.login('a');
      api.current = _response('GRANTED', 1);
      await controller.start();
      api.offline = true;
      await expectLater(controller.choose(false), throwsStateError);
      api.current = _response('GRANTED', 3);
      api.offline = false;
      await tester.pump(const Duration(seconds: 2));
      final afterConflict = api.calls.length;
      await tester.pump(const Duration(minutes: 2));
      expect(api.calls.length, afterConflict);
      expect(api.current['revision'], 3);
      expect(controller.choice, ConsentChoice.denied);
      expect(measurement.active, isNull);
    },
  );
  test('revocation preempts a slow read and ignores its late grant', () async {
    sessions.login('a');
    api.current = _response('GRANTED', 1);
    await controller.start();
    final stale = Completer<Map<String, Object?>>();
    api.readGate = stale;
    final reading = controller.refresh();
    await Future<void>.delayed(Duration.zero);
    expect(controller.busy, isFalse);
    final withdrawing = controller.choose(false);
    expect(measurement.active, isNull);
    await withdrawing;
    stale.complete(_response('GRANTED', 1));
    await reading;
    expect(controller.choice, ConsentChoice.denied);
    expect(measurement.starts, [_id]);
  });
  test(
    'old policy or malformed granted identity cannot enable collection',
    () async {
      sessions.login('a');
      api.current = {..._response('GRANTED', 1), 'policyVersion': 'old'};
      await controller.start();
      expect(measurement.starts, isEmpty);
      expect(controller.error, isNotNull);
      api.current = {..._response('GRANTED', 1), 'analyticsUserId': null};
      await controller.refresh();
      expect(measurement.starts, isEmpty);
      expect(controller.error, isNotNull);
    },
  );
}

const _id = 'b6ba83b1-68ac-4d48-b042-998ab49ae8a7';
Map<String, Object?> _response(String decision, int revision) => {
  'decision': decision,
  'analyticsUserId': decision == 'GRANTED' ? _id : null,
  'policyVersion': AnalyticsPreference.policy,
  'revision': revision,
};

class _Api extends Fake implements ApiClient {
  Map<String, Object?> current = _response('UNDECIDED', 0);
  final calls = <ApiRequestContext>[];
  bool offline = false;
  Completer<Map<String, Object?>>? readGate;
  Completer<void>? liveGate;
  final live =
      <({String path, Map<String, dynamic> body, ApiRequestContext context})>[];
  @override
  Future<T> request<T>(
    ApiHttpMethod method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    T Function(Object?)? decoder,
    ApiRequestContext? requestContext,
  }) async {
    if (path.startsWith('/api/v1/analytics/live-activity/')) {
      if (method != ApiHttpMethod.post) {
        throw StateError('Unexpected live activity transport method');
      }
      live.add((
        path: path,
        body: body as Map<String, dynamic>,
        context: requestContext!,
      ));
      if (liveGate != null) await liveGate!.future;
      return decoder!(null);
    }
    calls.add(requestContext!);
    if (offline) throw StateError('offline');
    if (method == ApiHttpMethod.put) {
      final data = body as Map;
      if (data['expectedRevision'] != current['revision']) {
        throw StateError('stale revision');
      }
      current = _response(
        data['decision'] as String,
        (current['revision'] as int) + 1,
      );
    }
    final gate = readGate;
    readGate = null;
    return decoder!(gate == null ? current : await gate.future);
  }
}

class _Sessions extends AuthSessionManager {
  _Sessions() : super(tokenStore: _Tokens(), sessionStore: _Metadata());
  AuthSession current = const AuthSession.guest();
  int revision = 0;
  @override
  int get credentialRevision => revision;
  @override
  AuthSession get session => current;
  void change(AuthSession next) {
    current = next;
    revision++;
    notifyListeners();
  }

  void login(String id) => change(
    AuthSession.authenticated(
      token: 't-$id',
      userId: id,
      username: null,
      accountStatus: 'ACTIVE',
      roles: const ['ROLE_MUSICIAN'],
      permissions: const [],
      expiresAt: DateTime.utc(2030),
      isAdmin: false,
    ),
  );
}

class _Tokens extends Fake implements TokenStore {}

class _Metadata extends Fake implements AuthSessionStore {}

class _Measurement extends AnalyticsMeasurement {
  String? active;
  final starts = <String>[];
  @override
  void start(String id, String role) {
    active = id;
    starts.add(id);
  }

  @override
  void stop() {
    active = null;
  }
}
