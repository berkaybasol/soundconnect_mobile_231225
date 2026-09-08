import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_router.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/navigation/profile_route_gate.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/navigation/profile_route_resolver.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/band_profile_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/profile_route_args.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/gradient_outline_button.dart';

void main() {
  late _SessionManager manager;

  setUp(() {
    manager = _SessionManager(_session());
    serviceLocator.registerSingleton<AuthSessionManager>(manager);
  });

  tearDown(() async {
    await serviceLocator.reset();
    manager.dispose();
  });

  for (final entry in <String, ProfileRouteKind>{
    AppRoutes.musicianPublicProfile: ProfileRouteKind.musician,
    AppRoutes.bandPublicProfile: ProfileRouteKind.band,
    AppRoutes.venuePublicProfile: ProfileRouteKind.venue,
    AppRoutes.studioPublicProfile: ProfileRouteKind.studio,
    AppRoutes.listenerPublicProfile: ProfileRouteKind.listener,
  }.entries) {
    testWidgets(
      'AppRouter ${entry.key} constructs central gate and canonical arguments',
      (tester) async {
        await tester.pumpWidget(const MaterialApp(home: Scaffold()));
        final input = entry.value == ProfileRouteKind.band
            ? BandProfileScreenArgs(bandId: ' target ', openEditMode: true)
            : const PublicProfileArgs(
                profileId: ' target ',
                viewerUserId: 'spoof',
              );
        final route =
            AppRouter.onGenerateRoute(
                  RouteSettings(name: entry.key, arguments: input),
                )
                as MaterialPageRoute<dynamic>;
        final page = route.builder(tester.element(find.byType(Scaffold)));
        expect(page, isA<ProfileRouteGate>());
        final gate = page as ProfileRouteGate;
        expect(gate.target.kind, entry.value);
        expect(gate.target.id, 'target');
        expect(route.settings.name, entry.key);
        final args = route.settings.arguments;
        if (entry.value == ProfileRouteKind.band) {
          expect((args as BandProfileScreenArgs).bandId, 'target');
          expect(args.viewMode, BandProfileViewMode.public);
          expect(args.openEditMode, isFalse);
        } else if (entry.value == ProfileRouteKind.venue) {
          expect((args as VenuePublicProfileArgs).venueId, 'target');
          expect(args.viewerUserId, isNull);
        } else {
          expect((args as PublicProfileArgs).profileId, 'target');
          expect(args.viewerUserId, isNull);
        }
      },
    );
  }

  for (final viewer in <String, (AuthSession, String)>{
    'guest': (const AuthSession.guest(), AppRoutes.login),
    'pending venue': (
      _session(status: 'PENDING_VENUE_REQUEST', roles: const ['ROLE_VENUE']),
      AppRoutes.venuePending,
    ),
    'pending studio': (
      _session(status: 'PENDING_STUDIO_REQUEST', roles: const ['ROLE_STUDIO']),
      AppRoutes.studioPending,
    ),
    'suspended': (_session(status: 'SUSPENDED'), AppRoutes.login),
  }.entries) {
    testWidgets('listener public route retains ${viewer.key} access guard', (
      tester,
    ) async {
      manager.change(viewer.value.$1);
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      final route =
          AppRouter.onGenerateRoute(
                const RouteSettings(
                  name: AppRoutes.listenerPublicProfile,
                  arguments: PublicProfileArgs(profileId: 'target'),
                ),
              )
              as MaterialPageRoute<dynamic>;
      expect(route.settings.name, viewer.value.$2);
      expect(
        route.builder(tester.element(find.byType(Scaffold))),
        isNot(isA<ProfileRouteGate>()),
      );
    });
  }

  testWidgets(
    'own route never flashes public content while identity resolves',
    (tester) async {
      final harness = await _Harness.open(tester);
      expect(harness.resolver.targets.single.id, 'target');
      expect(harness.publicBuilds, 0);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      harness.resolver.complete(const ProfileRouteDestination('/owner'));
      await tester.pumpAndSettle();

      expect(find.text('Owner destination'), findsOneWidget);
      expect(harness.publicBuilds, 0);
      expect(harness.ownerRoutes, hasLength(1));
      expect(find.byType(ProfileRouteGate), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('owner route replaces only gate and Back preserves origin', (
    tester,
  ) async {
    final harness = await _Harness.open(tester);
    final args = Object();
    harness.resolver.complete(
      ProfileRouteDestination('/owner', arguments: args),
    );
    await tester.pumpAndSettle();
    expect(harness.ownerRoutes.single.arguments, same(args));

    harness.navigator.currentState!.pop();
    await tester.pumpAndSettle();

    expect(find.text('Origin page'), findsOneWidget);
    expect(find.byType(ProfileRouteGate), findsNothing);
    expect(find.text('Public destination'), findsNothing);
    expect(harness.navigator.currentState!.canPop(), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'verified other user renders public page without owner navigation',
    (tester) async {
      final harness = await _Harness.open(tester);
      harness.resolver.complete(null);
      await tester.pumpAndSettle();
      expect(find.text('Public destination'), findsOneWidget);
      expect(harness.publicBuilds, greaterThanOrEqualTo(1));
      expect(harness.ownerRoutes, isEmpty);
      expect(harness.resolver.targets, hasLength(1));
      harness.navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('Origin page'), findsOneWidget);
    },
  );

  for (final viewer in <String, AuthSession>{
    'guest': const AuthSession.guest(),
    'different role': _session(roles: const ['ROLE_LISTENER']),
    'missing viewer ID': _session(userId: ''),
  }.entries) {
    testWidgets('${viewer.key} renders public without an ownership lookup', (
      tester,
    ) async {
      manager.change(viewer.value);
      final harness = await _Harness.open(tester);
      await tester.pumpAndSettle();
      expect(find.text('Public destination'), findsOneWidget);
      expect(harness.resolver.targets, isEmpty);
      expect(harness.ownerRoutes, isEmpty);
    });
  }

  testWidgets(
    'suspended musician is redirected without rendering public content',
    (tester) async {
      manager.change(_session(status: 'SUSPENDED'));
      final harness = await _Harness.open(tester);
      await tester.pumpAndSettle();
      expect(harness.ownerRoutes.single.name, AppRoutes.login);
      expect(harness.resolver.targets, isEmpty);
      expect(harness.publicBuilds, 0);
    },
  );

  testWidgets('absent auth manager is safe guest mode', (tester) async {
    await serviceLocator.unregister<AuthSessionManager>();
    final harness = await _Harness.open(tester);
    await tester.pumpAndSettle();
    expect(find.text('Public destination'), findsOneWidget);
    expect(harness.resolver.targets, isEmpty);
  });

  testWidgets('missing target fails without public content or a retry loop', (
    tester,
  ) async {
    final harness = await _Harness.open(
      tester,
      initialTarget: const ProfileRouteTarget(
        kind: ProfileRouteKind.musician,
        id: '',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Profil bağlantısı geçersiz.'), findsOneWidget);
    expect(find.text('Tekrar dene'), findsNothing);
    expect(harness.publicBuilds, 0);
    expect(harness.resolver.targets, isEmpty);
  });

  testWidgets('failed identity lookup fails closed and supports one retry', (
    tester,
  ) async {
    final harness = await _Harness.open(tester);
    harness.resolver.fail(StateError('unavailable'));
    await tester.pumpAndSettle();
    expect(find.text('Profil açılamadı. Lütfen tekrar dene.'), findsOneWidget);
    expect(harness.publicBuilds, 0);

    final retry = tester
        .widget<GradientOutlineButton>(find.byType(GradientOutlineButton))
        .onPressed!;
    retry();
    retry();
    await tester.pump();
    expect(harness.resolver.targets, hasLength(2));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    harness.resolver.complete(const ProfileRouteDestination('/owner'));
    await tester.pumpAndSettle();
    expect(harness.ownerRoutes, hasLength(1));
    expect(harness.publicBuilds, 0);
  });

  testWidgets('timeout offers retry and ignores original late owner result', (
    tester,
  ) async {
    final harness = await _Harness.open(tester);
    await tester.pump(const Duration(seconds: 16));
    await tester.pumpAndSettle();
    expect(find.text('Tekrar dene'), findsOneWidget);
    expect(harness.publicBuilds, 0);

    await tester.tap(find.text('Tekrar dene'));
    await tester.pump();
    harness.resolver.complete(null, index: 1);
    await tester.pumpAndSettle();
    harness.resolver.complete(
      const ProfileRouteDestination('/owner'),
      index: 0,
    );
    await tester.pumpAndSettle();

    expect(find.text('Public destination'), findsOneWidget);
    expect(harness.ownerRoutes, isEmpty);
  });

  for (final change in <String, AuthSession>{
    'account': _session(userId: 'another-account'),
    'token': _session(token: 'new-token'),
    'status': _session(status: 'SUSPENDED'),
    'role': _session(roles: const ['ROLE_LISTENER']),
    'logout': const AuthSession.guest(),
  }.entries) {
    for (final oldResultIsOwner in [true, false]) {
      testWidgets(
        'session ${change.key} discards pending ${oldResultIsOwner ? 'owner' : 'public'} result',
        (tester) async {
          final harness = await _Harness.open(tester);
          manager.change(change.value);
          harness.resolver.complete(
            oldResultIsOwner ? const ProfileRouteDestination('/owner') : null,
          );
          await tester.pumpAndSettle();

          expect(harness.ownerRoutes, isEmpty);
          expect(harness.publicBuilds, 0);
          expect(find.text('Tekrar dene'), findsOneWidget);
          expect(find.byType(CircularProgressIndicator), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('session retry resolves only the current authenticated account', (
    tester,
  ) async {
    final harness = await _Harness.open(tester);
    manager.change(_session(userId: 'new-viewer', token: 'new-token'));
    await tester.pump();
    await tester.tap(find.text('Tekrar dene'));
    await tester.pump();
    expect(harness.resolver.sessions.map((session) => session.userId), [
      'viewer',
      'new-viewer',
    ]);
    harness.resolver.complete(null, index: 1);
    await tester.pumpAndSettle();
    harness.resolver.complete(
      const ProfileRouteDestination('/owner'),
      index: 0,
    );
    await tester.pumpAndSettle();
    expect(find.text('Public destination'), findsOneWidget);
    expect(harness.ownerRoutes, isEmpty);
  });

  testWidgets('session change removes a previously rendered public page', (
    tester,
  ) async {
    final harness = await _Harness.open(tester);
    harness.resolver.complete(null);
    await tester.pumpAndSettle();
    expect(find.text('Public destination'), findsOneWidget);
    manager.change(_session(token: 'replacement-token'));
    await tester.pumpAndSettle();
    expect(find.text('Public destination'), findsNothing);
    expect(find.text('Tekrar dene'), findsOneWidget);
  });

  for (final change in <String, (AuthSession, String)>{
    'logout': (const AuthSession.guest(), AppRoutes.login),
    'pending venue': (
      _session(status: 'PENDING_VENUE_REQUEST', roles: const ['ROLE_VENUE']),
      AppRoutes.venuePending,
    ),
    'pending studio': (
      _session(status: 'PENDING_STUDIO_REQUEST', roles: const ['ROLE_STUDIO']),
      AppRoutes.studioPending,
    ),
    'listener onboarding': (
      _session(roles: const ['ROLE_LISTENER'], requiresListenerChoice: true),
      AppRoutes.listenerProfileChoice,
    ),
  }.entries) {
    testWidgets('listener retry after ${change.key} reapplies access guard', (
      tester,
    ) async {
      manager.change(_session(roles: const ['ROLE_LISTENER']));
      final harness = await _Harness.open(
        tester,
        initialTarget: const ProfileRouteTarget(
          kind: ProfileRouteKind.listener,
          id: 'listener-target',
        ),
      );
      harness.resolver.complete(null);
      await tester.pumpAndSettle();
      expect(find.text('Public destination'), findsOneWidget);
      final priorPublicBuilds = harness.publicBuilds;

      manager.change(change.value.$1);
      await tester.pumpAndSettle();
      expect(find.text('Public destination'), findsNothing);
      await tester.tap(find.text('Tekrar dene'));
      await tester.pumpAndSettle();

      expect(harness.ownerRoutes, hasLength(1));
      expect(harness.ownerRoutes.single.name, change.value.$2);
      expect(harness.publicBuilds, priorPublicBuilds);
      expect(harness.resolver.targets, hasLength(1));
      expect(find.byType(ProfileRouteGate), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final newTarget in [
    const ProfileRouteTarget(
      kind: ProfileRouteKind.musician,
      id: 'replacement',
    ),
    const ProfileRouteTarget(kind: ProfileRouteKind.band, id: 'target'),
  ]) {
    testWidgets(
      'target change ${newTarget.kind}/${newTarget.id} fences old result',
      (tester) async {
        final harness = await _Harness.open(tester);
        harness.target.value = newTarget;
        await tester.pump();
        expect(harness.resolver.targets, hasLength(2));
        expect(harness.resolver.targets.last, same(newTarget));
        harness.resolver.complete(null, index: 1);
        await tester.pumpAndSettle();
        harness.resolver.complete(
          const ProfileRouteDestination('/owner'),
          index: 0,
        );
        await tester.pumpAndSettle();
        expect(find.text('Public destination'), findsOneWidget);
        expect(harness.ownerRoutes, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'same target rebuild does not duplicate pending identity lookup',
    (tester) async {
      final harness = await _Harness.open(tester);
      harness.target.value = const ProfileRouteTarget(
        kind: ProfileRouteKind.musician,
        id: 'target',
      );
      await tester.pump();
      expect(harness.resolver.targets, hasLength(1));
      harness.resolver.complete(null);
      await tester.pumpAndSettle();
    },
  );

  testWidgets('covered gate ignores late lookup and is retryable on return', (
    tester,
  ) async {
    final harness = await _Harness.open(tester);
    unawaited(
      harness.navigator.currentState!.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Covering page')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    harness.resolver.complete(const ProfileRouteDestination('/owner'));
    await tester.pumpAndSettle();
    expect(find.text('Covering page'), findsOneWidget);
    expect(harness.ownerRoutes, isEmpty);
    expect(harness.publicBuilds, 0);

    harness.navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('Tekrar dene'), findsOneWidget);
    await tester.tap(find.text('Tekrar dene'));
    await tester.pump();
    harness.resolver.complete(null);
    await tester.pumpAndSettle();
    expect(find.text('Public destination'), findsOneWidget);
  });

  testWidgets('closed gate ignores late owner result', (tester) async {
    final harness = await _Harness.open(tester);
    harness.navigator.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    harness.resolver.complete(const ProfileRouteDestination('/owner'));
    await tester.pumpAndSettle();
    expect(find.text('Origin page'), findsOneWidget);
    expect(harness.ownerRoutes, isEmpty);
    expect(harness.publicBuilds, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'covering after lookup but before navigation offers retry on return',
    (tester) async {
      final harness = await _Harness.open(tester);
      harness.resolver.complete(const ProfileRouteDestination('/owner'));
      await tester.idle();
      unawaited(
        harness.navigator.currentState!.push<void>(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Covering page')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(harness.ownerRoutes, isEmpty);
      expect(find.text('Covering page'), findsOneWidget);
      harness.navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('Tekrar dene'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(harness.publicBuilds, 0);
    },
  );

  testWidgets(
    'account change between lookup and navigation fences owner replacement',
    (tester) async {
      final harness = await _Harness.open(tester);
      harness.resolver.complete(const ProfileRouteDestination('/owner'));
      await tester.idle();
      manager.change(_session(userId: 'new-account'));
      await tester.pumpAndSettle();
      expect(harness.ownerRoutes, isEmpty);
      expect(find.text('Tekrar dene'), findsOneWidget);
      expect(harness.publicBuilds, 0);
    },
  );

  testWidgets('captured retry callback is inert after gate disposal', (
    tester,
  ) async {
    final harness = await _Harness.open(tester);
    harness.resolver.fail(StateError('unavailable'));
    await tester.pumpAndSettle();
    final retry = tester
        .widget<GradientOutlineButton>(find.byType(GradientOutlineButton))
        .onPressed!;
    harness.navigator.currentState!.pop();
    await tester.pumpAndSettle();
    retry();
    await tester.pumpAndSettle();
    expect(harness.resolver.targets, hasLength(1));
    expect(find.text('Origin page'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'captured retry callback cannot start a lookup behind another page',
    (tester) async {
      final harness = await _Harness.open(tester);
      harness.resolver.fail(StateError('unavailable'));
      await tester.pumpAndSettle();
      final retry = tester
          .widget<GradientOutlineButton>(find.byType(GradientOutlineButton))
          .onPressed!;
      unawaited(
        harness.navigator.currentState!.push<void>(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Covering page')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      retry();
      await tester.pumpAndSettle();
      expect(harness.resolver.targets, hasLength(1));
      expect(find.text('Covering page'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _Harness {
  final navigator = GlobalKey<NavigatorState>();
  final _Resolver resolver = _Resolver();
  final ValueNotifier<ProfileRouteTarget> target;
  final List<RouteSettings> ownerRoutes = [];
  int publicBuilds = 0;

  _Harness(ProfileRouteTarget initialTarget)
    : target = ValueNotifier(initialTarget);

  static Future<_Harness> open(
    WidgetTester tester, {
    ProfileRouteTarget initialTarget = const ProfileRouteTarget(
      kind: ProfileRouteKind.musician,
      id: 'target',
    ),
  }) async {
    final harness = _Harness(initialTarget);
    addTearDown(harness.target.dispose);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: harness.navigator,
        onGenerateRoute: (settings) {
          harness.ownerRoutes.add(settings);
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const Scaffold(body: Text('Owner destination')),
          );
        },
        home: Scaffold(
          body: Column(
            children: [
              const Text('Origin page'),
              TextButton(
                onPressed: () {
                  unawaited(
                    harness.navigator.currentState!.push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            ValueListenableBuilder<ProfileRouteTarget>(
                              valueListenable: harness.target,
                              builder: (_, target, _) => ProfileRouteGate(
                                target: target,
                                resolver: harness.resolver,
                                publicBuilder: (_) {
                                  harness.publicBuilds++;
                                  return const Scaffold(
                                    body: Text('Public destination'),
                                  );
                                },
                              ),
                            ),
                      ),
                    ),
                  );
                },
                child: const Text('Open profile'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open profile'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    return harness;
  }
}

class _Resolver extends ProfileRouteResolver {
  final List<ProfileRouteTarget> targets = [];
  final List<AuthSession> sessions = [];
  final List<Completer<ProfileRouteDestination?>> pending = [];

  @override
  Future<ProfileRouteDestination?> resolve(
    ProfileRouteTarget target,
    AuthSession session,
  ) {
    targets.add(target);
    sessions.add(session);
    final completion = Completer<ProfileRouteDestination?>();
    pending.add(completion);
    return completion.future;
  }

  void complete(ProfileRouteDestination? destination, {int? index}) {
    pending[index ?? pending.length - 1].complete(destination);
  }

  void fail(Object error) => pending.last.completeError(error);
}

class _SessionManager extends ChangeNotifier implements AuthSessionManager {
  AuthSession current;
  _SessionManager(this.current);

  @override
  AuthSession get session => current;

  void change(AuthSession value) {
    current = value;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

AuthSession _session({
  String token = 'token',
  String userId = 'viewer',
  String status = 'ACTIVE',
  List<String> roles = const ['ROLE_MUSICIAN'],
  bool requiresListenerChoice = false,
}) => AuthSession.authenticated(
  token: token,
  userId: userId,
  username: 'aedrum',
  accountStatus: status,
  roles: roles,
  permissions: const [],
  expiresAt: DateTime.utc(2100),
  isAdmin: false,
  requiresListenerProfileChoice: requiresListenerChoice,
);
