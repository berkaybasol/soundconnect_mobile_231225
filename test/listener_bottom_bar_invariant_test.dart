import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/policy/stage_mode.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_badge_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_badge_state.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/profile_public_bottom_bar.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/presentation/screens/table_group_route_args.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';

import 'support/event_audience_fakes.dart';

void main() {
  setUp(() {
    GetIt.instance.registerSingleton<DmBadgeCubit>(
      _Badge(),
      dispose: (badge) => badge.close(),
    );
  });
  tearDown(() async => GetIt.instance.reset());

  const destinations = <String, String>{
    'Keşfet': AppRoutes.eventDiscovery,
    'Overthinking': AppRoutes.overthinkingFeed,
    'Müzik Birleştirir!': AppRoutes.tableGroupList,
    'Mesajlar': AppRoutes.dmConversations,
    'Profil': AppRoutes.listenerProfile,
  };

  for (final explicitBackstage in [false, true]) {
    for (final destination in destinations.entries) {
      testWidgets(
        'listener ${explicitBackstage ? 'explicit backstage' : 'default public profile'} bar opens ${destination.key} as mainstage',
        (tester) async {
          _registerSession(audienceSession());
          final harness = await _mount(
            tester,
            requestedStage: explicitBackstage ? StageMode.backstage : null,
          );

          _expectMainstage(tester);
          await tester.tap(find.text(destination.key));
          await tester.pumpAndSettle();

          expect(harness.routes.map((route) => route.name), [
            destination.value,
          ]);
          expect(harness.navigator.currentState!.canPop(), isFalse);
          if (destination.value == AppRoutes.tableGroupList) {
            expect(
              (harness.routes.single.arguments! as TableGroupListArgs)
                  .bottomBarStageMode,
              StageMode.mainstage,
            );
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final role in [' listener ', ' role_listener ']) {
    testWidgets('listener role alias $role cannot select backstage', (
      tester,
    ) async {
      _registerSession(audienceSession(role: role));
      await _mount(tester, requestedStage: StageMode.backstage);
      _expectMainstage(tester);
    });
  }

  for (final entry in <String, AuthSession?>{
    'missing session manager': null,
    'guest': const AuthSession.guest(),
    'unknown role': audienceSession(role: 'ROLE_UNKNOWN'),
    'empty roles': audienceSession(roles: const []),
    'inactive backstage account': audienceSession(
      role: 'ROLE_MUSICIAN',
      status: 'PASSIVE',
    ),
    'pending backstage account': audienceSession(
      role: 'ROLE_VENUE',
      status: 'PENDING_VENUE_REQUEST',
    ),
  }.entries) {
    testWidgets('${entry.key} cannot render a backstage navigation bar', (
      tester,
    ) async {
      if (entry.value != null) _registerSession(entry.value!);
      await _mount(tester, requestedStage: StageMode.backstage);
      _expectMainstage(tester);
    });
  }

  for (final role in ['ROLE_MUSICIAN', ' venue ', 'ROLE_STUDIO']) {
    testWidgets('$role retains its authorized backstage navigation', (
      tester,
    ) async {
      _registerSession(audienceSession(role: role));
      final harness = await _mount(tester);
      _expectBackstage(tester);

      await tester.tap(find.text('Akış'));
      await tester.pumpAndSettle();
      expect(harness.routes.single.name, AppRoutes.backstageProfilesHome);
    });
  }

  testWidgets('explicit mainstage remains mainstage for a musician', (
    tester,
  ) async {
    _registerSession(audienceSession(role: 'ROLE_MUSICIAN'));
    await _mount(tester, requestedStage: StageMode.mainstage);
    _expectMainstage(tester);
  });

  testWidgets('clamped Overthinking keeps index one and allows the table tab', (
    tester,
  ) async {
    _registerSession(audienceSession());
    final harness = await _mount(
      tester,
      requestedStage: StageMode.backstage,
      currentIndex: 2,
      mainstageCurrentIndex: 1,
    );
    _expectMainstage(tester);
    expect(
      tester
          .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
          .currentIndex,
      1,
    );

    await tester.tap(find.text('Overthinking'));
    await tester.pumpAndSettle();
    expect(harness.routes, isEmpty);

    await tester.tap(find.text('Müzik Birleştirir!'));
    await tester.pumpAndSettle();
    expect(harness.routes.single.name, AppRoutes.tableGroupList);
    expect(
      (harness.routes.single.arguments! as TableGroupListArgs)
          .bottomBarStageMode,
      StageMode.mainstage,
    );
  });

  testWidgets('mixed professional account preserves backstage permission', (
    tester,
  ) async {
    _registerSession(
      audienceSession(roles: const ['ROLE_LISTENER', 'ROLE_MUSICIAN']),
    );
    await _mount(tester);
    _expectBackstage(tester);
  });

  testWidgets(
    'account replacement immediately invalidates old backstage callbacks and rebuilds listener tabs',
    (tester) async {
      final sessions = _registerSession(
        audienceSession(user: 'musician', role: 'ROLE_MUSICIAN'),
      );
      final harness = await _mount(tester);
      _expectBackstage(tester);
      final oldTap = tester
          .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
          .onTap!;

      sessions.replace(audienceSession(user: 'listener'));
      // A pointer event can still reach the old frame before the rebuild.
      for (var index = 0; index < 5; index++) {
        oldTap(index);
      }
      await tester.pumpAndSettle();

      _expectMainstage(tester);
      expect(harness.routes, isEmpty);
      expect(
        find.text('Konumuna göre canlı müzik etkinliklerini bul'),
        findsNothing,
      );

      oldTap(0);
      await tester.pumpAndSettle();
      expect(harness.routes, isEmpty);

      await tester.tap(find.text('Keşfet'));
      await tester.pumpAndSettle();
      expect(harness.routes.single.name, AppRoutes.eventDiscovery);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('pending backstage navigation cannot survive a listener login', (
    tester,
  ) async {
    final sessions = _registerSession(
      audienceSession(user: 'musician', role: 'ROLE_MUSICIAN'),
    );
    final permission = Completer<bool>();
    final harness = await _mount(tester, before: () => permission.future);
    await tester.tap(find.text('Akış'));
    await tester.pump();

    sessions.replace(audienceSession());
    permission.complete(true);
    await tester.pumpAndSettle();

    _expectMainstage(tester);
    expect(harness.routes, isEmpty);
  });

  testWidgets('logout removes backstage tabs without waiting for a new route', (
    tester,
  ) async {
    final sessions = _registerSession(audienceSession(role: 'ROLE_MUSICIAN'));
    await _mount(tester);
    _expectBackstage(tester);

    sessions.replace(const AuthSession.guest());
    await tester.pumpAndSettle();

    _expectMainstage(tester);
  });

  testWidgets('listener profile destination ignores a stale musician token', (
    tester,
  ) async {
    _registerSession(audienceSession());
    final tokens = _StaleMusicianTokens();
    GetIt.instance.registerSingleton<TokenStore>(tokens);
    final harness = await _mount(tester);

    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();

    expect(harness.routes.single.name, AppRoutes.listenerProfile);
    expect(tokens.reads, 0);
  });
}

AudienceTestSessions _registerSession(AuthSession initial) {
  final sessions = AudienceTestSessions(initial);
  GetIt.instance.registerSingleton<AuthSessionManager>(
    sessions,
    dispose: (_) => sessions.dispose(),
  );
  return sessions;
}

void _expectMainstage(WidgetTester tester) {
  final bar = tester.widget<BottomNavigationBar>(
    find.byType(BottomNavigationBar),
  );
  expect(bar.items.map((item) => item.label), [
    'Keşfet',
    'Overthinking',
    'Müzik Birleştirir!',
    'Mesajlar',
    'Profil',
  ]);
  expect(find.text('Akış'), findsNothing);
  expect(find.text('Collab'), findsNothing);
  expect(find.text('Git'), findsNothing);
}

void _expectBackstage(WidgetTester tester) {
  final bar = tester.widget<BottomNavigationBar>(
    find.byType(BottomNavigationBar),
  );
  expect(bar.items.map((item) => item.label), [
    'Akış',
    'Collab',
    'Git',
    'Mesajlar',
    'Profil',
  ]);
}

Future<_Harness> _mount(
  WidgetTester tester, {
  StageMode? requestedStage,
  int currentIndex = 4,
  int? mainstageCurrentIndex,
  FutureOr<bool> Function()? before,
}) async {
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final harness = _Harness();
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.navy,
      navigatorKey: harness.navigator,
      home: Scaffold(
        bottomNavigationBar: requestedStage == null
            ? ProfilePublicBottomBar(
                currentIndex: currentIndex,
                mainstageCurrentIndex: mainstageCurrentIndex,
                profileTapAlwaysOpensOwnProfile: true,
                onBeforeNavigate: before,
              )
            : ProfilePublicBottomBar(
                stageMode: requestedStage,
                currentIndex: currentIndex,
                mainstageCurrentIndex: mainstageCurrentIndex,
                profileTapAlwaysOpensOwnProfile: true,
                onBeforeNavigate: before,
              ),
      ),
      onGenerateRoute: (settings) {
        harness.routes.add(settings);
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => Scaffold(body: Text('Destination ${settings.name}')),
        );
      },
    ),
  );
  await tester.pumpAndSettle();
  return harness;
}

class _Harness {
  final navigator = GlobalKey<NavigatorState>();
  final routes = <RouteSettings>[];
}

class _Badge extends Cubit<DmBadgeState> implements DmBadgeCubit {
  _Badge() : super(const DmBadgeState.initial());
  @override
  Future<void> ensureStarted() async {}
  @override
  Future<void> stop() async {}
}

class _StaleMusicianTokens extends Fake implements TokenStore {
  int reads = 0;
  @override
  Future<String?> readToken() async {
    reads++;
    return 'header.eyJyb2xlcyI6WyJST0xFX01VU0lDSUFOIl19.signature';
  }
}
