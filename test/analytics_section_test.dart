import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/modules/analytics/data/analytics_measurement.dart';
import 'package:soundconnect_23_12_25codx/modules/analytics/data/first_week_measurement.dart';
import 'package:soundconnect_23_12_25codx/modules/analytics/presentation/section_navigation.dart';

class _Transport implements ApiClient {
  final bodies = <Object?>[];
  @override
  Future<T> request<T>(
    ApiHttpMethod method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    T Function(Object?)? decoder,
    ApiRequestContext? requestContext,
  }) async {
    bodies.add(body);
    if (bodies.length == 1) {
      throw ApiException(const AppError(code: 'network', message: 'test'));
    }
    return decoder!({'windowOpen': true});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Sessions implements AuthSessionManager {
  @override
  int get credentialRevision => 1;
  @override
  AuthSession get session => const AuthSession.guest();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FirstWeek implements FirstWeekMeasurement {
  final durations = <(String, DateTime, int)>[];
  bool windowOpen = true;
  Completer<({String action, String profile, DateTime occurredAt})?>? pending;
  @override
  Future<bool> duration(
    String identity,
    DateTime start,
    int milliseconds,
    bool Function() stillActive,
  ) async {
    durations.add((identity, start, milliseconds));
    return windowOpen;
  }

  @override
  Future<({String action, String profile, DateTime occurredAt})?> claim(
    String identity,
  ) async => pending?.future;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'Android without a GA4 worker records only consented member time in SoundConnect',
    (tester) async {
      const channel = MethodChannel('test/soundconnect/no-ga4');
      final calls = <String>[];
      final backend = _FirstWeek();
      var elapsed = Duration.zero;
      final bridge = tester.binding.defaultBinaryMessenger;
      bridge.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        return call.method == 'prepare' ? false : null;
      });
      addTearDown(() => bridge.setMockMethodCallHandler(channel, null));
      final measurement = AnalyticsMeasurement(
        configured: true,
        firstPartyEnabled: true,
        channel: channel,
        firstWeek: backend,
        elapsed: () => elapsed,
      );
      measurement.start('A', 'listener');
      await tester.pump();
      elapsed += const Duration(seconds: 12);
      measurement.suspend();
      await tester.pump();
      expect(backend.durations.single.$1, 'A');
      expect(backend.durations.single.$3, 12000);
      measurement.start('A', 'listener');
      await tester.pump();
      elapsed += const Duration(seconds: 2);
      measurement.stop();
      measurement.start('G', 'guest');
      await tester.pump();
      elapsed += const Duration(seconds: 8);
      measurement.suspend();
      await tester.pump();
      expect(backend.durations, hasLength(1));
      expect(calls, isNot(contains('start')));
      expect(calls, isNot(contains('event')));
    },
  );
  testWidgets(
    'uncertain duration delivery retries the same sample only while its audience is active',
    (tester) async {
      final transport = _Transport();
      final week = FirstWeekMeasurement(transport, _Sessions());
      final start = DateTime.utc(2026, 11, 26);
      final result = week.duration('A', start, 1300, () => true);
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(await result, isTrue);
      expect(transport.bodies.length, 2);
      expect(transport.bodies[0], transport.bodies[1]);
      transport.bodies.clear();
      final revoked = expectLater(
        week.duration('A', start, 2200, () => false),
        throwsA(isA<ApiException>()),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await revoked;
      expect(transport.bodies.length, 1);
    },
  );
  test(
    'each interval belongs to one section and background or withdrawal never backfills it',
    () {
      var milliseconds = 0;
      final epoch = DateTime.utc(2026, 11, 26);
      final totals = <UsageSection, int>{};
      final starts = <DateTime>[];
      final clock = SectionClock(
        (view, start, ms) {
          totals.update(view.section, (n) => n + ms, ifAbsent: () => ms);
          starts.add(start);
        },
        elapsed: () => Duration(milliseconds: milliseconds),
        utcNow: () => epoch.add(Duration(milliseconds: milliseconds)),
      );
      final market = sectionView(UsageSection.marketplace);
      final other = sectionView(UsageSection.other);
      clock.show(market);
      milliseconds += 60000;
      clock.begin();
      milliseconds += 120000;
      clock.show(other); // DM replaces Pazar.
      for (var i = 0; i < 10; i++) {
        milliseconds += 30000;
        clock.flush();
      }
      clock.show(other); // Ayarlar and DM share Diğer.
      milliseconds += 60000;
      clock.end(sendLast: true);
      expect(totals, {
        UsageSection.marketplace: 120000,
        UsageSection.other: 360000,
      });
      expect(starts.first, epoch.add(const Duration(minutes: 1)));
      milliseconds += 600000;
      clock.show(SectionNavigation.profileView(ViewedProfile.studio, false));
      clock.begin();
      for (var i = 0; i < 6; i++) {
        milliseconds += 30000;
        clock.flush();
      }
      clock.show(other); // Reservation starts.
      milliseconds += 120000;
      clock.flush();
      milliseconds += 4500;
      clock.end(sendLast: false);
      expect(totals[UsageSection.profiles], 180000);
      expect(totals[UsageSection.other], 480000);
    },
  );

  testWidgets(
    'visible route, same-section overlays, source-specific detail and replacements',
    (tester) async {
      final visits = <SectionView>[];
      final observer = SectionNavigation(visits.add);
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: key,
          navigatorObservers: [observer],
          home: const SizedBox(),
        ),
      );
      final nav = key.currentState!;
      Route<void> page(RouteSettings settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const SizedBox(),
      );
      nav.push(page(const RouteSettings(name: AppRoutes.eventDiscovery)));
      await tester.pumpAndSettle();
      expect(visits.last.section, UsageSection.discover);
      nav.push(
        page(
          const SectionRouteSettings(
            UsageSection.discover,
            discoveryEvent: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(visits.last.discoveryEvent, isTrue);
      nav.pushReplacement(
        page(const RouteSettings(name: AppRoutes.studioProfile)),
      );
      await tester.pumpAndSettle();
      expect(
        visits.last,
        SectionNavigation.profileView(ViewedProfile.studio, true),
      );
      nav.push(page(const SectionRouteSettings.inherit()));
      await tester.pumpAndSettle();
      expect(
        visits.last,
        SectionNavigation.profileView(ViewedProfile.studio, true),
      );
      nav.push(page(const SectionRouteSettings(UsageSection.other)));
      await tester.pumpAndSettle();
      expect(visits.last.section, UsageSection.other);
      nav.pop();
      await tester.pumpAndSettle();
      expect(visits.last.profile, ViewedProfile.studio);
      // Event detail from a profile is outside discovery.
      nav.push(page(const RouteSettings()));
      await tester.pumpAndSettle();
      expect(visits.last.section, UsageSection.other);
      observer.obscure(true);
      nav.pop();
      await tester.pumpAndSettle();
      expect(visits.last.section, UsageSection.other);
      observer.obscure(false);
      expect(visits.last.profile, ViewedProfile.studio);
    },
  );

  testWidgets(
    'native acknowledgement starts the clock, withdrawal discards, and old claims cannot cross accounts',
    (tester) async {
      const channel = MethodChannel('test/soundconnect/usage');
      var elapsed = Duration.zero;
      final sent = <MethodCall>[];
      final backend = _FirstWeek();
      final measurement = AnalyticsMeasurement(
        configured: true,
        channel: channel,
        firstWeek: backend,
        elapsed: () => elapsed,
        utcNow: () => DateTime.utc(2026, 11, 26).add(elapsed),
      );
      final bridge = tester.binding.defaultBinaryMessenger;
      bridge.setMockMethodCallHandler(channel, (call) async {
        sent.add(call);
        return call.method == 'start' ? true : null;
      });
      addTearDown(() => bridge.setMockMethodCallHandler(channel, null));
      final oldClaim =
          Completer<({String action, String profile, DateTime occurredAt})?>();
      backend.pending = oldClaim;
      measurement.show(sectionView(UsageSection.discover));
      measurement.start('A', 'musician');
      expect(measurement.captureAction(), isNull);
      await tester.pump();
      final old = measurement.captureAction()!;
      elapsed += const Duration(seconds: 12);
      measurement.show(sectionView(UsageSection.marketplace));
      await tester.pump();
      expect(backend.durations.single.$3, 12000);
      elapsed += const Duration(seconds: 9);
      measurement.stop();
      backend.pending = null;
      measurement.start('B', 'listener');
      await tester.pump();
      oldClaim.complete((
        action: 'table_created',
        profile: 'musician',
        occurredAt: DateTime.utc(2026, 11, 26),
      ));
      measurement.meaningfulAction(
        old,
        'table_created',
        DateTime.utc(2026, 11, 26),
      );
      await tester.pump();
      expect(sent.where((e) => e.method == 'event').length, 1);
      final firstTime = DateTime.utc(2026, 11, 26, 2, 32);
      backend.pending =
          Completer<({String action, String profile, DateTime occurredAt})?>()
            ..complete((
              action: 'table_created',
              profile: 'listener',
              occurredAt: firstTime,
            ));
      measurement.claimFirstAction();
      await tester.pump();
      measurement.claimFirstAction();
      await tester.pump();
      final action = sent
          .where(
            (call) =>
                call.method == 'event' &&
                call.arguments['name'] == 'meaningful_action',
          )
          .single;
      expect(action.arguments['identity'], 'B');
      expect(action.arguments['parameters'], {
        'action_type': 'table_created',
        'profile_type': 'listener',
        'occurred_at_ms': firstTime.millisecondsSinceEpoch,
      });
      elapsed += const Duration(seconds: 4);
      backend.windowOpen = false;
      measurement
          .suspend(); // Sends last foreground interval prior to native suspension.
      await tester.pump();
      expect(backend.durations.last.$1, 'B');
      expect(backend.durations.last.$3, 4000);
      elapsed += const Duration(hours: 1);
      measurement.start('B', 'listener');
      await tester.pump();
      elapsed += const Duration(seconds: 5);
      measurement.suspend();
      await tester.pump();
      expect(backend.durations.length, 2);
      measurement.start('G', 'guest');
      await tester.pump();
      expect(measurement.captureAction(), isNull);
      elapsed += const Duration(seconds: 6);
      measurement.suspend();
      await tester.pump();
      expect(backend.durations.length, 2);
      measurement.stop();
      await tester.pump();
    },
  );
}
