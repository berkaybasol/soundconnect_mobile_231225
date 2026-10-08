import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/data/system_health_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/domain/system_health.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/presentation/screens/system_health_screen.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';

import 'support/event_audience_fakes.dart';

AuthSession admin({
  String token = 'one',
  List<String> roles = const ['ROLE_ADMIN'],
  List<String> permissions = const ['ADMIN_PANEL_ACCESS'],
}) => AuthSession.authenticated(
  token: token,
  userId: 'admin-user',
  username: 'admin',
  accountStatus: 'ACTIVE',
  roles: roles,
  permissions: permissions,
  expiresAt: DateTime.utc(2100),
  isAdmin: true,
);

Map<String, Object?> component({
  String status = 'UP',
  String? measuredAt = '2026-10-08T10:00:00Z',
  int? age = 0,
}) => {
  'id': 'database',
  'label': 'Veritabanı',
  'status': status,
  'measuredAt': measuredAt,
  'ageSeconds': age,
  'userImpact': 'Veri işlemleri ölçülüyor.',
  'metrics': {'pending': 2},
};
Map<String, Object?> snapshot({List<Object?>? components}) => {
  'status': 'UP',
  'generatedAt': '2026-10-08T10:00:00Z',
  'refreshIntervalSeconds': 15,
  'staleAfterSeconds': 60,
  'components': components ?? [component()],
};

Map<String, Object?> diagnostic() => {
  'eventId': 'a102d00e-907d-4d4c-99b1-e51b3f30b160',
  'receivedAt': '2026-10-08T10:00:00Z',
  'severity': 'ERROR',
  'source': 'DIAGNOSTICS_CHECK',
  'errorType': 'DiagnosticAcceptanceCheck',
  'environment': 'local',
};

class _Api extends Fake implements ApiClient {
  final pending = <Completer<Object?>>[];
  final contexts = <ApiRequestContext?>[];
  final methods = <ApiHttpMethod>[];
  final recentPending = <Completer<Object?>>[];
  final recentContexts = <ApiRequestContext?>[];
  bool holdRecent = false;
  List<Object?> recent = [];
  @override
  Future<T> request<T>(
    ApiHttpMethod method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    T Function(Object?)? decoder,
    ApiRequestContext? requestContext,
  }) async {
    if (path == '${SystemHealthRepository.path}/mobile-events') {
      expect(method, ApiHttpMethod.get);
      expect(body, isNull);
      expect(query, {'limit': 10});
      recentContexts.add(requestContext);
      if (!holdRecent) return decoder!({'events': recent});
      final value = Completer<Object?>();
      recentPending.add(value);
      return decoder!(await value.future);
    }
    expect(path, SystemHealthRepository.path);
    expect(body, isNull);
    contexts.add(requestContext);
    methods.add(method);
    final value = Completer<Object?>();
    pending.add(value);
    final raw = await value.future;
    return decoder!(raw);
  }
}

void main() {
  test(
    'recent reports reject overflow, unknown error taxonomy and duplicate IDs',
    () {
      expect(
        MobileDiagnosticSummary.listFromJson({
          'events': [diagnostic()],
        }).single.errorType,
        'DiagnosticAcceptanceCheck',
      );
      for (final events in [
        List.generate(11, (_) => diagnostic()),
        [diagnostic(), diagnostic()],
        [
          {...diagnostic(), 'errorType': 'private-server-message'},
        ],
        [
          {...diagnostic(), 'source': 'private-user'},
        ],
      ]) {
        expect(
          () => MobileDiagnosticSummary.listFromJson({'events': events}),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'recent report fetch is bounded passive and loses data on admin permission change',
    () async {
      final sessions = AudienceTestSessions(admin());
      final api = _Api()..holdRecent = true;
      final repo = SystemHealthRepository(api, sessions);
      final result = repo.loadRecentEvents();
      expect(api.recentContexts.single!.expectedToken, 'one');
      expect(
        api.recentContexts.single!.expectedCredentialRevision,
        sessions.credentialRevision,
      );
      sessions.replace(admin(permissions: []));
      api.recentPending.single.complete({
        'events': [diagnostic()],
      });
      expect((await result).error!.code, 'health_access_changed');
      expect(
        (await repo.loadRecentEvents()).error!.code,
        'health_access_changed',
      );
      expect(api.recentPending, hasLength(1));
      sessions.dispose();
    },
  );
  test(
    'permission is required and listener/pending/guest cannot inherit admin health',
    () {
      expect(canViewSystemHealth(admin()), isTrue);
      expect(canViewSystemHealth(admin(permissions: [])), isFalse);
      expect(
        canViewSystemHealth(admin(roles: ['ROLE_LISTENER', 'ROLE_ADMIN'])),
        isFalse,
      );
      expect(canViewSystemHealth(const AuthSession.guest()), isFalse);
    },
  );

  test('unknown and missing/stale measurements never become healthy', () {
    for (final state in ['UNKNOWN', 'NEW_PROVIDER_STATUS']) {
      expect(
        HealthComponent.fromJson(component(status: state)).status,
        HealthStatus.unknown,
      );
    }
    expect(
      HealthComponent.fromJson(component(measuredAt: null, age: null)).status,
      HealthStatus.unknown,
    );
    final up = HealthComponent.fromJson(component(age: 50));
    expect(
      up.effectiveStatus(const Duration(seconds: 11), 60),
      HealthStatus.stale,
    );
    final disabled = HealthComponent.fromJson(
      component(status: 'DISABLED', measuredAt: null, age: null),
    );
    expect(
      disabled.effectiveStatus(const Duration(days: 5), 60),
      HealthStatus.disabled,
    );
  });

  test(
    'payload bounds duplicate components and invalid numeric values fail closed',
    () {
      expect(
        () => SystemHealthSnapshot.fromJson(
          snapshot(components: [component(), component()]),
        ),
        throwsFormatException,
      );
      expect(
        () => SystemHealthSnapshot.fromJson(
          snapshot(components: List.generate(33, (_) => component())),
        ),
        throwsFormatException,
      );
      expect(
        () => SystemHealthSnapshot.fromJson({
          ...snapshot(),
          'refreshIntervalSeconds': 0,
        }),
        throwsFormatException,
      );
      expect(
        () => HealthComponent.fromJson({
          ...component(),
          'metrics': {'pending': double.nan},
        }),
        throwsFormatException,
      );
      expect(
        () => HealthComponent.fromJson({
          ...component(),
          'metrics': {'pending': -1},
        }),
        throwsFormatException,
      );
      final safe = HealthComponent.fromJson({
        ...component(),
        'metrics': {'pending': 2, 'token': 'secret'},
      });
      expect(safe.metrics, {'pending': 2.0});
    },
  );

  test('overall status ages with its oldest component measurement', () {
    final current = SystemHealthSnapshot.fromJson(
      snapshot(components: [component(age: 50)]),
    );
    expect(
      current.effectiveStatus(const Duration(seconds: 10)),
      HealthStatus.up,
    );
    expect(
      current.components.single.effectiveStatus(
        const Duration(seconds: 11),
        60,
      ),
      HealthStatus.stale,
    );
    expect(
      current.effectiveStatus(const Duration(seconds: 11)),
      HealthStatus.stale,
    );
  });

  test(
    'overall status preserves adverse states and never promotes unknown',
    () {
      for (final measurement in [
        component(status: 'UNKNOWN'),
        component(measuredAt: null, age: null),
        component(age: null),
      ]) {
        expect(
          SystemHealthSnapshot.fromJson(
            snapshot(components: [measurement]),
          ).effectiveStatus(Duration.zero),
          HealthStatus.unknown,
        );
      }
      final serverUnknown = SystemHealthSnapshot.fromJson({
        ...snapshot(),
        'status': 'UNKNOWN',
      });
      expect(
        serverUnknown.effectiveStatus(Duration.zero),
        HealthStatus.unknown,
      );
      final serverDown = SystemHealthSnapshot.fromJson({
        ...snapshot(components: [component(age: 50)]),
        'status': 'DOWN',
      });
      expect(
        serverDown.effectiveStatus(const Duration(seconds: 11)),
        HealthStatus.down,
      );
      expect(
        serverDown.effectiveStatus(const Duration(seconds: 61)),
        HealthStatus.stale,
      );
      expect(
        SystemHealthSnapshot.fromJson({
          ...snapshot(
            components: [
              component(status: 'DISABLED', measuredAt: null, age: null),
            ],
          ),
          'status': 'DISABLED',
        }).effectiveStatus(Duration.zero),
        HealthStatus.disabled,
      );
    },
  );

  test(
    'read binds exact token and rejects delayed data after same-account relogin',
    () async {
      final sessions = AudienceTestSessions(admin());
      final api = _Api();
      final repo = SystemHealthRepository(api, sessions);
      final result = repo.load();
      expect(api.contexts.single?.expectedSessionKey, 'admin-user');
      expect(api.contexts.single?.expectedToken, 'one');
      expect(api.methods, [ApiHttpMethod.get]);
      sessions.replace(admin(token: 'two'));
      api.pending.single.complete(snapshot());
      expect((await result).error?.code, 'health_access_changed');
      sessions.dispose();
    },
  );

  test(
    'guest cannot trigger any request and malformed data is not shown',
    () async {
      final sessions = AudienceTestSessions(const AuthSession.guest());
      final api = _Api();
      final repo = SystemHealthRepository(api, sessions);
      expect((await repo.load()).isSuccess, isFalse);
      expect(api.pending, isEmpty);
      sessions.replace(admin());
      final result = repo.load();
      api.pending.single.complete({'status': 'UP'});
      expect((await result).error?.code, 'health_unavailable');
      sessions.dispose();
    },
  );

  testWidgets(
    'passive screen renders measurements and clears them immediately on logout',
    (tester) async {
      final sessions = AudienceTestSessions(admin());
      final api = _Api();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.navy,
          home: SystemHealthScreen(
            repository: SystemHealthRepository(api, sessions),
            sessions: sessions,
          ),
        ),
      );
      expect(api.methods, [ApiHttpMethod.get]);
      api.pending.single.complete(snapshot());
      await tester.pump();
      await tester.pump();
      await tester.scrollUntilVisible(find.text('Veritabanı'), 200);
      expect(find.text('Veritabanı'), findsOneWidget);
      expect(find.text('Bekleyen: 2'), findsOneWidget);
      sessions.replace(const AuthSession.guest());
      await tester.pump();
      expect(find.text('Veritabanı'), findsNothing);
      expect(find.textContaining('yönetim yetkisi gerekli'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      sessions.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('waiting for recent events does not refresh measurement age', (
    tester,
  ) async {
    final sessions = AudienceTestSessions(admin());
    final api = _Api()..holdRecent = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.navy,
        home: SystemHealthScreen(
          repository: SystemHealthRepository(api, sessions),
          sessions: sessions,
        ),
      ),
    );
    api.pending.single.complete(snapshot(components: [component(age: 60)]));
    await tester.pump();
    // Exercise the actual monotonic clock used by the screen, independent of
    // Flutter's fake frame clock and of the device wall clock.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1100)),
    );
    api.recentPending.single.complete({'events': []});
    await tester.pump();
    await tester.pump();
    expect(find.text('Ölçüm eski'), findsWidgets);
    expect(find.text('Normal'), findsNothing);
    await tester.tap(find.byKey(const Key('health-refresh')));
    await tester.pump();
    api.pending.last.complete({'status': 'UP'}); // Malformed refresh fails.
    api.recentPending.last.complete({'events': []});
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('health-error')), findsOneWidget);
    expect(find.text('Ölçüm eski'), findsWidgets);
    expect(find.text('Normal'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    sessions.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'recent mobile reports render safe labels and clear on permission revocation',
    (tester) async {
      final sessions = AudienceTestSessions(admin());
      final api = _Api()..recent = [diagnostic()];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.navy,
          home: SystemHealthScreen(
            repository: SystemHealthRepository(api, sessions),
            sessions: sessions,
          ),
        ),
      );
      api.pending.single.complete(snapshot());
      await tester.pump();
      await tester.pump();
      await tester.scrollUntilVisible(find.text('Deneme raporu · Hata'), 200);
      expect(find.text('Deneme raporu · Hata'), findsOneWidget);
      expect(api.recentContexts, hasLength(1));
      sessions.replace(admin(permissions: []));
      await tester.pump();
      expect(find.text('Deneme raporu · Hata'), findsNothing);
      expect(find.textContaining('yönetim yetkisi gerekli'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      sessions.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('loading is single flight; invisible application stops polling', (
    tester,
  ) async {
    final sessions = AudienceTestSessions(admin());
    final api = _Api();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.navy,
        home: SystemHealthScreen(
          repository: SystemHealthRepository(api, sessions),
          sessions: sessions,
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 30));
    expect(api.pending, hasLength(1));
    api.pending.single.complete(snapshot());
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(minutes: 2));
    expect(api.pending, hasLength(1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(api.pending, hasLength(2));
    await tester.pumpWidget(const SizedBox.shrink());
    api.pending.last.complete(snapshot());
    await tester.pump();
    sessions.dispose();
    expect(tester.takeException(), isNull);
  });
}
