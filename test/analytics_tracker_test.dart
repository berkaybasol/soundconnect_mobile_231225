import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_store.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/analytics/data/analytics_tracker.dart';
import 'package:soundconnect_23_12_25codx/modules/analytics/domain/analytics_collection_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/analytics/domain/analytics_observation.dart';

const _eventId = '10000000-0000-4000-8000-000000000001';
const _venueId = '20000000-0000-4000-8000-000000000001';
const _storedInstallId = '30000000-0000-4000-8000-000000000001';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('records only explicit calls and persists installation once', (
    tester,
  ) async {
    final fixture = await _Fixture.create();
    await tester.pump();
    await fixture.tracker.flush();
    expect(fixture.repository.calls, isEmpty);
    final installationId = fixture.preferences.getString(
      AnalyticsTracker.installationKey,
    );
    expect(isAnalyticsUuid(installationId!), isTrue);
    fixture.tracker.recordEventImpression(_eventId);
    await tester.pump();
    await fixture.tracker.flush();
    final call = fixture.repository.calls.single;
    expect(call.clientId, installationId);
    expect(call.userId, isNull);
    expect(
      call.observations.single.type,
      AnalyticsObservationType.eventImpression,
    );
    expect(call.observations.single.observedAt.isUtc, isTrue);
    expect(_storedRows(fixture.preferences), isEmpty);
    await fixture.close();
  });

  testWidgets('detail and attributed venue views retain exact entity context', (
    tester,
  ) async {
    final fixture = await _Fixture.create();
    fixture.tracker.recordEventDetailView(_eventId);
    fixture.tracker.recordVenueProfileView(_venueId, sourceEventId: _eventId);
    await tester.pump();
    await fixture.tracker.flush();
    final observations = fixture.repository.calls.single.observations;
    expect(observations.map((value) => value.type), [
      AnalyticsObservationType.eventDetailView,
      AnalyticsObservationType.venueProfileView,
    ]);
    expect(observations.last.venueId, _venueId);
    expect(observations.last.sourceEventId, _eventId);
    await fixture.close();
  });

  testWidgets(
    'short duplicate suppression is bounded and detail proof refreshes',
    (tester) async {
      var now = DateTime.utc(2026, 9, 8, 12);
      final fixture = await _Fixture.create(clock: () => now);
      for (var i = 0; i < 20; i++) {
        fixture.tracker.recordEventDetailView(_eventId);
      }
      await tester.pump();
      await fixture.tracker.flush();
      expect(fixture.repository.calls.single.observations, hasLength(1));
      now = now.add(const Duration(seconds: 29));
      fixture.tracker.recordEventDetailView(_eventId);
      await tester.pump();
      await fixture.tracker.flush();
      expect(fixture.repository.calls, hasLength(1));
      now = now.add(const Duration(seconds: 1));
      fixture.tracker.recordEventDetailView(_eventId);
      await tester.pump();
      await fixture.tracker.flush();
      expect(fixture.repository.calls, hasLength(2));
      expect(fixture.repository.calls.last.observations.single.observedAt, now);
      await fixture.close();
    },
  );

  testWidgets('new Istanbul day is not suppressed by previous day exposure', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 9, 8, 20, 59, 59);
    final fixture = await _Fixture.create(clock: () => now);
    fixture.tracker.recordEventImpression(_eventId);
    await tester.pump();
    await fixture.tracker.flush();
    now = now.add(const Duration(seconds: 1));
    fixture.tracker.recordEventImpression(_eventId);
    await tester.pump();
    await fixture.tracker.flush();
    expect(fixture.repository.calls, hasLength(2));
    await fixture.close();
  });

  testWidgets('concurrent initialization reuses one persisted installation ID', (
    tester,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final firstManager = _Manager();
    final secondManager = _Manager();
    final firstRepository = _Repository();
    final secondRepository = _Repository();
    var generated = 0;
    String createId() =>
        '40000000-0000-4000-8000-${(++generated).toString().padLeft(12, '0')}';
    final first = AnalyticsTracker(
      repository: firstRepository,
      sessionManager: firstManager,
      preferencesLoader: () async => preferences,
      createId: createId,
    );
    final second = AnalyticsTracker(
      repository: secondRepository,
      sessionManager: secondManager,
      preferencesLoader: () async => preferences,
      createId: createId,
    );
    await tester.pump();
    expect(generated, 1);
    first.recordEventImpression(_eventId);
    second.recordEventDetailView(_eventId);
    await tester.pump();
    await Future.wait([first.flush(), second.flush()]);
    expect(
      firstRepository.calls.single.clientId,
      secondRepository.calls.single.clientId,
    );
    await first.dispose();
    await second.dispose();
    firstManager.dispose();
    secondManager.dispose();
  });

  testWidgets('same observation IDs and times survive unknown outcome retry', (
    tester,
  ) async {
    final fixture = await _Fixture.create();
    fixture.repository.errorCode = 'network';
    fixture.tracker.recordEventDetailView(_eventId);
    await tester.pump();
    await fixture.tracker.flush();
    final first = fixture.repository.calls.single.observations.single;
    expect(_storedRows(fixture.preferences), hasLength(1));
    fixture.repository.errorCode = null;
    await fixture.tracker.flush();
    final retried = fixture.repository.calls.last.observations.single;
    expect(retried.toJson(), first.toJson());
    expect(_storedRows(fixture.preferences), isEmpty);
    await fixture.close();
  });

  testWidgets('partial acknowledgement only removes matching sent rows', (
    tester,
  ) async {
    final fixture = await _Fixture.create();
    fixture.repository.acknowledgeOnlyFirst = true;
    fixture.tracker.recordEventImpression(_eventId);
    fixture.tracker.recordEventDetailView(_eventId);
    await tester.pump();
    await fixture.tracker.flush();
    expect(_storedRows(fixture.preferences), hasLength(1));
    final retained = fixture.repository.calls.first.observations.last.id;
    await fixture.tracker.flush();
    expect(fixture.repository.calls.last.observations.single.id, retained);
    expect(_storedRows(fixture.preferences), isEmpty);
    await fixture.close();
  });

  testWidgets(
    '401 and malformed requests are dropped rather than retried forever',
    (tester) async {
      for (final code in [
        '401',
        '400',
        '9910',
        '9911',
        '9914',
        'analytics_invalid',
        'api_session_fence',
      ]) {
        final fixture = await _Fixture.create();
        fixture.repository.errorCode = code;
        fixture.tracker.recordEventImpression(_eventId);
        await tester.pump();
        await fixture.tracker.flush();
        expect(_storedRows(fixture.preferences), isEmpty, reason: code);
        await fixture.close();
      }
    },
  );

  testWidgets('retries 429 and 503 with bounded delay and half-open recovery', (
    tester,
  ) async {
    final fixture = await _Fixture.create();
    fixture.repository.errorCode = '429';
    fixture.tracker.recordEventImpression(_eventId);
    await tester.pump();
    await fixture.tracker.flush();
    expect(fixture.repository.calls, hasLength(1));
    await tester.pump(const Duration(seconds: 5));
    expect(fixture.repository.calls, hasLength(1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(fixture.repository.calls, hasLength(2));
    fixture.repository.errorCode = '503';
    for (final seconds in [12, 24, 48, 96]) {
      await tester.pump(Duration(seconds: seconds));
      await tester.pump();
    }
    expect(fixture.repository.calls, hasLength(6));
    await tester.pump(const Duration(seconds: 299));
    expect(fixture.repository.calls, hasLength(6));
    fixture.repository.errorCode = null;
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(fixture.repository.calls, hasLength(7));
    expect(_storedRows(fixture.preferences), isEmpty);
    await fixture.close();
  });

  testWidgets('concurrent flush callers never duplicate the in-flight batch', (
    tester,
  ) async {
    final fixture = await _Fixture.create();
    fixture.repository.barrier = Completer<Result<List<String>>>();
    fixture.tracker.recordEventImpression(_eventId);
    await tester.pump();
    final first = fixture.tracker.flush();
    final second = fixture.tracker.flush();
    await tester.pump();
    expect(fixture.repository.calls, hasLength(1));
    fixture.repository.barrier!.complete(
      Result.success([fixture.repository.calls.single.observations.single.id]),
    );
    await Future.wait([first, second]);
    await fixture.close();
  });

  testWidgets('server Retry-After wins over local delay and explicit flush', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 9, 8, 12);
    final fixture = await _Fixture.create(clock: () => now);
    fixture.repository.errorCode = '9912';
    fixture.repository.retryAfter = const Duration(minutes: 2);
    fixture.tracker.recordEventImpression(_eventId);
    await tester.pump();
    await fixture.tracker.flush();
    expect(fixture.repository.calls, hasLength(1));
    await fixture.tracker.flush();
    expect(fixture.repository.calls, hasLength(1));
    now = now.add(const Duration(seconds: 119));
    await tester.pump(const Duration(seconds: 119));
    expect(fixture.repository.calls, hasLength(1));
    fixture.repository.errorCode = null;
    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(fixture.repository.calls, hasLength(2));
    expect(_storedRows(fixture.preferences), isEmpty);
    await fixture.close();
  });

  testWidgets(
    'storage writes coalesce and late old snapshot cannot restore account A',
    (tester) async {
      final preferences = _SlowPreferences();
      final manager = _Manager(_user('A'));
      final repository = _Repository();
      final tracker = AnalyticsTracker(
        repository: repository,
        sessionManager: manager,
        preferencesLoader: () async => preferences,
      );
      await tester.pump();
      final writesBefore = preferences.queueWrites;
      preferences.barrier = Completer<void>();
      tracker.recordEventImpression(_eventId);
      await tester.pump();
      for (var i = 0; i < 100; i++) {
        tracker.recordEventImpression(
          '10000000-0000-4000-8000-${i.toString().padLeft(12, '0')}',
        );
      }
      manager.change(_user('B'));
      tracker.recordVenueProfileView(_venueId);
      await tester.pump();
      expect(preferences.queueWrites - writesBefore, 1);
      preferences.barrier!.complete();
      await tester.pump();
      expect(preferences.queueWrites - writesBefore, 2);
      final rows = _storedRows(preferences);
      expect(rows, hasLength(1));
      expect((rows.single as Map)['type'], 'VENUE_PROFILE_VIEW');
      expect((rows.single as Map)['venueId'], _venueId);
      expect(repository.calls, isEmpty);
      await tracker.dispose();
      manager.dispose();
    },
  );

  testWidgets(
    'disposal during upload retains replayable queue without late mutation',
    (tester) async {
      final fixture = await _Fixture.create();
      fixture.repository.barrier = Completer<Result<List<String>>>();
      fixture.tracker.recordEventImpression(_eventId);
      await tester.pump();
      final upload = fixture.tracker.flush();
      await tester.pump();
      final observationId =
          fixture.repository.calls.single.observations.single.id;
      await fixture.close();
      fixture.repository.barrier!.complete(Result.success([observationId]));
      await upload;
      expect(
        (_storedRows(fixture.preferences).single as Map)['id'],
        observationId,
      );
    },
  );

  testWidgets('queued guest observations cannot migrate to a login', (
    tester,
  ) async {
    final fixture = await _Fixture.create();
    fixture.tracker.recordEventImpression(_eventId);
    await tester.pump();
    fixture.manager.change(_user('account-B'));
    await tester.pump();
    await fixture.tracker.flush();
    expect(fixture.repository.calls, isEmpty);
    expect(_storedRows(fixture.preferences), isEmpty);
    fixture.tracker.recordEventDetailView(_eventId);
    await tester.pump();
    await fixture.tracker.flush();
    expect(fixture.repository.calls.single.userId, 'account-B');
    expect(
      fixture.preferences.getString(AnalyticsTracker.queueKey),
      isNot(contains('token')),
    );
    expect(
      fixture.preferences.getString(AnalyticsTracker.queueKey),
      isNot(contains('account-B')),
    );
    await fixture.close();
  });

  testWidgets(
    'same eligible account token refresh preserves queue and in-flight receipt',
    (tester) async {
      final fixture = await _Fixture.create(session: _user('A'));
      fixture.tracker.recordEventImpression(_eventId);
      await tester.pump();
      final originalId = (_storedRows(fixture.preferences).single as Map)['id'];
      fixture.manager.change(_user('A', token: 'refreshed-token-A'));
      await tester.pump();
      expect(
        (_storedRows(fixture.preferences).single as Map)['id'],
        originalId,
      );
      fixture.repository.barrier = Completer<Result<List<String>>>();
      final upload = fixture.tracker.flush();
      await tester.pump();
      fixture.manager.change(_user('A', token: 'another-refreshed-token-A'));
      fixture.repository.barrier!.complete(
        Result.success([originalId as String]),
      );
      await upload;
      expect(fixture.repository.calls.single.userId, 'A');
      expect(
        fixture.repository.calls.single.observations.single.id,
        originalId,
      );
      expect(_storedRows(fixture.preferences), isEmpty);
      await fixture.close();
    },
  );

  testWidgets(
    'logout and same-account eligibility changes clear pending observations',
    (tester) async {
      for (final next in [
        const AuthSession.guest(),
        _user('A', active: false),
        _user('A', admin: true),
      ]) {
        final fixture = await _Fixture.create(session: _user('A'));
        fixture.tracker.recordEventImpression(_eventId);
        await tester.pump();
        fixture.manager.change(next);
        await tester.pump();
        await fixture.tracker.flush();
        expect(_storedRows(fixture.preferences), isEmpty);
        expect(fixture.repository.calls, isEmpty);
        await fixture.close();
      }
    },
  );

  testWidgets('late account A acknowledgement cannot remove account B rows', (
    tester,
  ) async {
    final fixture = await _Fixture.create(session: _user('A'));
    fixture.repository.barrier = Completer<Result<List<String>>>();
    fixture.tracker.recordEventImpression(_eventId);
    await tester.pump();
    final pending = fixture.tracker.flush();
    await tester.pump();
    final oldId = fixture.repository.calls.single.observations.single.id;
    fixture.manager.change(_user('B'));
    fixture.tracker.recordEventDetailView(_eventId);
    await tester.pump();
    fixture.repository.barrier!.complete(Result.success([oldId]));
    await pending;
    expect(_storedRows(fixture.preferences), hasLength(1));
    fixture.repository.barrier = null;
    await fixture.tracker.flush();
    expect(fixture.repository.calls.last.userId, 'B');
    expect(fixture.repository.calls.last.observations.single.id, isNot(oldId));
    await fixture.close();
  });

  testWidgets(
    'account switch during storage initialization discards old capture',
    (tester) async {
      final preferences = await SharedPreferences.getInstance();
      final loaded = Completer<SharedPreferences>();
      final manager = _Manager();
      final repository = _Repository();
      final tracker = AnalyticsTracker(
        repository: repository,
        sessionManager: manager,
        preferencesLoader: () => loaded.future,
      );
      tracker.recordEventImpression(_eventId);
      manager.change(_user('new-account'));
      loaded.complete(preferences);
      await tester.pump();
      await tracker.flush();
      expect(repository.calls, isEmpty);
      expect(_storedRows(preferences), isEmpty);
      await tracker.dispose();
      manager.dispose();
    },
  );

  testWidgets('durable queue resumes same identity with original IDs', (
    tester,
  ) async {
    final fixture = await _Fixture.create();
    fixture.repository.errorCode = 'network';
    fixture.tracker.recordEventImpression(_eventId);
    await tester.pump();
    await fixture.tracker.flush();
    final prior = fixture.repository.calls.single;
    await fixture.close();
    final resumed = await _Fixture.create();
    await tester.pump();
    await resumed.tracker.flush();
    expect(resumed.repository.calls.single.clientId, prior.clientId);
    expect(
      resumed.repository.calls.single.observations.single.toJson(),
      prior.observations.single.toJson(),
    );
    await resumed.close();
  });

  testWidgets('restart under another identity discards durable queue', (
    tester,
  ) async {
    final fixture = await _Fixture.create(session: _user('A'));
    fixture.repository.errorCode = 'network';
    fixture.tracker.recordEventImpression(_eventId);
    await tester.pump();
    await fixture.tracker.flush();
    await fixture.close();
    final resumed = await _Fixture.create(session: _user('B'));
    await tester.pump();
    await resumed.tracker.flush();
    expect(resumed.repository.calls, isEmpty);
    expect(_storedRows(resumed.preferences), isEmpty);
    await resumed.close();
  });

  testWidgets('queue is bounded at 128 and each batch at 20', (tester) async {
    final fixture = await _Fixture.create();
    fixture.repository.barrier = Completer<Result<List<String>>>();
    for (var i = 0; i < 160; i++) {
      fixture.tracker.recordEventImpression(
        '10000000-0000-4000-8000-${i.toString().padLeft(12, '0')}',
      );
    }
    await tester.pump();
    await tester.pump();
    expect(fixture.repository.calls, hasLength(1));
    expect(fixture.repository.calls.single.observations, hasLength(20));
    expect(_storedRows(fixture.preferences), hasLength(128));
    fixture.repository.barrier!.complete(
      const Result.failure(AppError(code: 'network', message: 'offline')),
    );
    await tester.pump();
    await fixture.close();
  });

  testWidgets(
    'expired, future, corrupt and oversized stored rows are dropped',
    (tester) async {
      final now = DateTime.utc(2026, 9, 8);
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        AnalyticsTracker.installationKey,
        _storedInstallId,
      );
      Map<String, Object> row(DateTime date) => AnalyticsObservation(
        id: '40000000-0000-4000-8000-000000000001',
        type: AnalyticsObservationType.eventImpression,
        eventId: _eventId,
        observedAt: date,
      ).toJson();
      for (final rows in [
        [
          row(now.subtract(const Duration(hours: 25))),
          row(now.add(const Duration(minutes: 1))),
          {'bad': true},
        ],
        List.filled(129, row(now)),
      ]) {
        await preferences.setString(
          AnalyticsTracker.queueKey,
          jsonEncode({'scope': 'guest', 'observations': rows}),
        );
        final fixture = await _Fixture.create(clock: () => now);
        await tester.pump();
        await fixture.tracker.flush();
        expect(fixture.repository.calls, isEmpty);
        expect(_storedRows(fixture.preferences), isEmpty);
        await fixture.close();
      }
    },
  );

  testWidgets('admin, inactive, invalid IDs and background do not observe', (
    tester,
  ) async {
    for (final session in [
      _user('admin', admin: true),
      _user('inactive', active: false),
    ]) {
      final fixture = await _Fixture.create(session: session);
      fixture.tracker.recordEventImpression(_eventId);
      await tester.pump();
      await fixture.tracker.flush();
      expect(fixture.repository.calls, isEmpty);
      await fixture.close();
    }
    final fixture = await _Fixture.create();
    fixture.tracker.recordEventImpression('invalid');
    fixture.tracker.didChangeAppLifecycleState(AppLifecycleState.paused);
    fixture.tracker.recordEventImpression(_eventId);
    await tester.pump();
    fixture.tracker.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await fixture.tracker.flush();
    expect(fixture.repository.calls, isEmpty);
    await fixture.close();
  });

  testWidgets('storage failure and thrown network error never escape to UI', (
    tester,
  ) async {
    final manager = _Manager();
    final repository = _Repository();
    final tracker = AnalyticsTracker(
      repository: repository,
      sessionManager: manager,
      preferencesLoader: () async => throw StateError('unavailable'),
    );
    tracker.recordEventImpression(_eventId);
    await tester.pump();
    await tracker.flush();
    expect(repository.calls, isEmpty);
    await tracker.dispose();
    manager.dispose();
    final fixture = await _Fixture.create();
    fixture.repository.throwError = true;
    fixture.tracker.recordEventImpression(_eventId);
    await tester.pump();
    await fixture.tracker.flush();
    expect(_storedRows(fixture.preferences), hasLength(1));
    await fixture.close();
  });
}

List<dynamic> _storedRows(SharedPreferences preferences) =>
    (jsonDecode(preferences.getString(AnalyticsTracker.queueKey)!)
            as Map)['observations']
        as List;

AuthSession _user(
  String id, {
  bool admin = false,
  bool active = true,
  String? token,
}) => AuthSession.authenticated(
  token: token ?? 'token-$id',
  userId: id,
  username: id,
  accountStatus: active ? 'ACTIVE' : 'SUSPENDED',
  roles: const ['ROLE_LISTENER'],
  permissions: const [],
  expiresAt: DateTime.utc(2030),
  isAdmin: admin,
);

class _Fixture {
  _Fixture(this.preferences, this.manager, this.repository, this.tracker);
  final SharedPreferences preferences;
  final _Manager manager;
  final _Repository repository;
  final AnalyticsTracker tracker;

  static Future<_Fixture> create({
    AuthSession? session,
    DateTime Function()? clock,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final manager = _Manager(session);
    final repository = _Repository();
    final tracker = AnalyticsTracker(
      repository: repository,
      sessionManager: manager,
      preferencesLoader: () async => preferences,
      clock: clock,
      random: () => 0,
    );
    return _Fixture(preferences, manager, repository, tracker);
  }

  Future<void> close() async {
    await tracker.dispose();
    manager.dispose();
  }
}

class _Call {
  _Call(this.clientId, this.observations, this.userId);
  final String clientId;
  final List<AnalyticsObservation> observations;
  final String? userId;
}

class _Repository implements AnalyticsCollectionRepository {
  final List<_Call> calls = [];
  String? errorCode;
  Duration? retryAfter;
  bool throwError = false;
  bool acknowledgeOnlyFirst = false;
  Completer<Result<List<String>>>? barrier;

  @override
  Future<Result<List<String>>> collect({
    required String clientId,
    required List<AnalyticsObservation> observations,
    required String? expectedUserId,
  }) async {
    calls.add(_Call(clientId, observations, expectedUserId));
    if (barrier != null) return barrier!.future;
    if (throwError) throw StateError('transport failed');
    if (errorCode != null) {
      return Result.failure(
        AppError(code: errorCode!, message: 'failure', retryAfter: retryAfter),
      );
    }
    return Result.success(
      (acknowledgeOnlyFirst ? observations.take(1) : observations)
          .map((value) => value.id)
          .toList(),
    );
  }
}

class _Manager extends AuthSessionManager {
  _Manager([AuthSession? initial])
    : current = initial ?? const AuthSession.guest(),
      super(tokenStore: _TokenStore(), sessionStore: _SessionStore());
  AuthSession current;
  @override
  AuthSession get session => current;
  void change(AuthSession next) {
    current = next;
    notifyListeners();
  }
}

class _TokenStore implements TokenStore {
  @override
  Future<void> clear() async {}
  @override
  Future<String?> readToken() async => null;
  @override
  Future<void> writeToken(String token) async {}
}

class _SessionStore implements AuthSessionStore {
  @override
  Future<void> clear() async {}
  @override
  Future<AuthSessionMetadata?> read() async => null;
  @override
  Future<void> write(AuthSessionMetadata metadata) async {}
}

class _SlowPreferences implements SharedPreferences {
  final Map<String, String> values = {
    AnalyticsTracker.installationKey: _storedInstallId,
  };
  Completer<void>? barrier;
  int queueWrites = 0;
  @override
  String? getString(String key) => values[key];
  @override
  Future<bool> setString(String key, String value) async {
    if (key == AnalyticsTracker.queueKey) {
      queueWrites++;
      await barrier?.future;
    }
    values[key] = value;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
