import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/modules/event_audience/presentation/event_audience_profile_draft.dart';

import 'support/event_audience_fakes.dart';

void main() {
  testWidgets('share opens own profile with a draft, never a publish command', (
    tester,
  ) async {
    final session = audienceSession();
    final h = await _mount(tester, session);
    unawaited(h.open(eventId: '  $audienceEventId  '));
    await tester.pumpAndSettle();
    expect(find.text('Own profile'), findsOneWidget);
    final route = h.routes.single;
    expect(route.name, AppRoutes.listenerProfile);
    final args = route.arguments! as EventAudienceProfileDraftArgs;
    expect(args.eventId, audienceEventId);
    expect(args.expectedSession, same(session));
    // No repository is registered: navigation does not perform a publication.
    expect(tester.takeException(), isNull);
  });

  testWidgets('rapid taps push once and allow a new draft after returning', (
    tester,
  ) async {
    final h = await _mount(tester, audienceSession());
    unawaited(h.open());
    unawaited(h.open());
    await tester.pumpAndSettle();
    expect(h.routes, hasLength(1));
    h.navigator.currentState!.pop();
    await tester.pumpAndSettle();
    unawaited(h.open());
    await tester.pumpAndSettle();
    expect(h.routes, hasLength(2));
  });

  for (final entry in <String, AuthSession>{
    'guest': const AuthSession.guest(),
    'musician': audienceSession(role: 'ROLE_MUSICIAN'),
    'venue': audienceSession(role: 'ROLE_VENUE'),
    'inactive': audienceSession(status: 'INACTIVE'),
    'admin': audienceSession(isAdmin: true),
    'mixed business listener': audienceSession(
      roles: ['ROLE_LISTENER', 'ROLE_VENUE'],
    ),
  }.entries) {
    testWidgets('${entry.key} cannot open a listener publication draft', (
      tester,
    ) async {
      final h = await _mount(tester, entry.value);
      await h.open();
      await tester.pumpAndSettle();
      expect(h.routes, isEmpty);
    });
  }

  testWidgets('a stale callback cannot act on a replacement account or token', (
    tester,
  ) async {
    final original = audienceSession();
    final h = await _mount(tester, original);
    for (final next in [
      audienceSession(user: 'another-listener'),
      audienceSession(token: 'renewed-token'),
      const AuthSession.guest(),
    ]) {
      h.sessions.replace(next);
      await h.open();
      await tester.pumpAndSettle();
      expect(h.routes, isEmpty);
    }
  });

  testWidgets('empty event ids and obscured or disposed contexts do not push', (
    tester,
  ) async {
    final h = await _mount(tester, audienceSession());
    await h.open(eventId: '   ');
    expect(h.routes, isEmpty);
    unawaited(h.navigator.currentState!.pushNamed('/newer'));
    await tester.pumpAndSettle();
    await h.open();
    expect(h.routes, hasLength(1));
    expect(h.routes.single.name, '/newer');
    await tester.pumpWidget(const SizedBox.shrink());
    await h.open();
    expect(h.routes, hasLength(1));
    expect(tester.takeException(), isNull);
  });
}

Future<_Harness> _mount(WidgetTester tester, AuthSession session) async {
  final h = _Harness(session);
  addTearDown(h.sessions.dispose);
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: h.navigator,
      home: Scaffold(
        body: Builder(
          builder: (context) {
            h.context = context;
            return const Text('Event detail');
          },
        ),
      ),
      onGenerateRoute: (settings) {
        h.routes.add(settings);
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => Scaffold(
            body: Text(
              settings.name == AppRoutes.listenerProfile
                  ? 'Own profile'
                  : 'Newer route',
            ),
          ),
        );
      },
    ),
  );
  await tester.pumpAndSettle();
  return h;
}

class _Harness {
  _Harness(this.expected) : sessions = AudienceTestSessions(expected);
  final AuthSession expected;
  final AudienceTestSessions sessions;
  final navigator = GlobalKey<NavigatorState>();
  final routes = <RouteSettings>[];
  late BuildContext context;

  Future<void> open({String eventId = audienceEventId}) =>
      openEventAudienceProfileDraft(
        context,
        eventId: eventId,
        expectedSession: expected,
        sessions: sessions,
      );
}
