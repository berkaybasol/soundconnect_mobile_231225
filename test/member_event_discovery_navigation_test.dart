import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/policy/stage_mode.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_badge_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_badge_state.dart';
import 'package:soundconnect_23_12_25codx/modules/event/presentation/screens/event_discovery_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/profile_public_bottom_bar.dart';
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

  testWidgets('mainstage replaces Nabız with Keşfet and opens a root tab', (
    tester,
  ) async {
    final h = await _mount(tester);
    expect(find.text('Nabız'), findsNothing);
    expect(find.text('Keşfet'), findsOneWidget);
    expect(find.byIcon(Icons.travel_explore_outlined), findsOneWidget);
    await tester.tap(find.text('Keşfet'));
    await tester.pumpAndSettle();
    expect(find.text('Discovery destination'), findsOneWidget);
    expect(h.navigator.currentState!.canPop(), isFalse);
    expect(
      h.routes.where((route) => route.name == AppRoutes.eventDiscovery),
      hasLength(1),
    );
  });

  testWidgets('active Keşfet tab does not replace itself', (tester) async {
    final h = await _mount(tester, currentIndex: 0);
    await tester.tap(find.text('Keşfet'));
    await tester.pumpAndSettle();
    expect(
      h.routes.where((route) => route.name == AppRoutes.eventDiscovery),
      isEmpty,
    );
  });

  testWidgets('navigation veto prevents opening discovery', (tester) async {
    final h = await _mount(tester, before: () => false);
    await tester.tap(find.text('Keşfet'));
    await tester.pumpAndSettle();
    expect(
      h.routes.where((route) => route.name == AppRoutes.eventDiscovery),
      isEmpty,
    );
  });

  testWidgets('late navigation approval cannot replace a newer route', (
    tester,
  ) async {
    final permission = Completer<bool>();
    final h = await _mount(tester, before: () => permission.future);
    await tester.tap(find.text('Keşfet'));
    await tester.pump();
    unawaited(h.navigator.currentState!.pushNamed('/other'));
    await tester.pumpAndSettle();
    permission.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('Newer route'), findsOneWidget);
    expect(
      h.routes.where((route) => route.name == AppRoutes.eventDiscovery),
      isEmpty,
    );
  });

  testWidgets('rapid discovery taps create only one destination', (
    tester,
  ) async {
    final h = await _mount(tester);
    final bar = tester.widget<BottomNavigationBar>(
      find.byType(BottomNavigationBar),
    );
    bar.onTap!(0);
    bar.onTap!(0);
    await tester.pumpAndSettle();
    expect(
      h.routes.where((route) => route.name == AppRoutes.eventDiscovery),
      hasLength(1),
    );
    expect(h.navigator.currentState!.canPop(), isFalse);
  });

  for (final index in [1, 2, 3]) {
    testWidgets('late tab $index approval cannot replace a newer route', (
      tester,
    ) async {
      final permission = Completer<bool>();
      final h = await _mount(tester, before: () => permission.future);
      tester
          .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
          .onTap!(index);
      await tester.pump();
      unawaited(h.navigator.currentState!.pushNamed('/other'));
      await tester.pumpAndSettle();
      permission.complete(true);
      await tester.pumpAndSettle();
      expect(h.routes.map((value) => value.name), ['/other']);
    });
  }

  testWidgets(
    'late discovery approval cannot navigate for a replacement account',
    (tester) async {
      final sessions = AudienceTestSessions(audienceSession());
      GetIt.instance.registerSingleton<AuthSessionManager>(sessions);
      final permission = Completer<bool>();
      final h = await _mount(tester, before: () => permission.future);
      await tester.tap(find.text('Keşfet'));
      await tester.pump();
      sessions.replace(audienceSession(user: 'other'));
      permission.complete(true);
      await tester.pumpAndSettle();
      expect(h.routes, isEmpty);
    },
  );

  testWidgets('late profile token lookup cannot replace a newer route', (
    tester,
  ) async {
    final token = Completer<String?>();
    GetIt.instance.registerSingleton<TokenStore>(_Tokens(token.future));
    final h = await _mount(tester, currentIndex: 0);
    await tester.tap(find.text('Profil'));
    await tester.pump();
    unawaited(h.navigator.currentState!.pushNamed('/other'));
    await tester.pumpAndSettle();
    token.complete('header.eyJyb2xlcyI6WyJST0xFX0xJU1RFTkVSIl19.signature');
    await tester.pumpAndSettle();
    expect(h.routes.map((value) => value.name), ['/other']);
  });

  testWidgets(
    'backstage launcher closes on account replacement and old actions are inert',
    (tester) async {
      final sessions = AudienceTestSessions(
        audienceSession(role: 'ROLE_MUSICIAN'),
      );
      GetIt.instance.registerSingleton<AuthSessionManager>(sessions);
      final h = await _mount(tester, stage: StageMode.backstage);
      await tester.tap(find.text('Git'));
      await tester.pumpAndSettle();
      final tile = tester.widget<InkWell>(
        find
            .ancestor(of: find.text('Keşfet'), matching: find.byType(InkWell))
            .first,
      );
      sessions.replace(audienceSession(user: 'other', role: 'ROLE_MUSICIAN'));
      await tester.pumpAndSettle();
      expect(find.text('Keşfet'), findsNothing);
      tile.onTap!();
      await tester.pumpAndSettle();
      expect(h.routes, isEmpty);
    },
  );

  testWidgets('newer route during launcher exit wins over pending discovery', (
    tester,
  ) async {
    final h = await _mount(tester, stage: StageMode.backstage);
    await tester.tap(find.text('Git'));
    await tester.pumpAndSettle();
    h.navigator.currentState!.pop(AppRoutes.eventDiscovery);
    unawaited(h.navigator.currentState!.pushNamed('/other'));
    await tester.pumpAndSettle();
    expect(h.routes.map((value) => value.name), ['/other']);
  });

  for (final label in ['Overthinking', 'Müzik Birleştirir!', 'Keşfet']) {
    testWidgets('launcher $label double tap cannot pop the underlying route', (
      tester,
    ) async {
      final h = await _mount(tester, stage: StageMode.backstage);
      await tester.tap(find.text('Git'));
      await tester.pumpAndSettle();
      final callback = tester
          .widget<InkWell>(
            find
                .ancestor(of: find.text(label), matching: find.byType(InkWell))
                .first,
          )
          .onTap!;
      callback();
      callback();
      await tester.pumpAndSettle();
      expect(h.routes.length, 1);
      expect(h.navigator.currentState!.canPop(), isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('backstage Git launcher enables discovery and preserves stage', (
    tester,
  ) async {
    final h = await _mount(tester, stage: StageMode.backstage);
    await tester.tap(find.text('Git'));
    await tester.pumpAndSettle();
    expect(find.text('Nabız'), findsNothing);
    expect(find.text('Keşfet'), findsOneWidget);
    await tester.tap(find.text('Keşfet'));
    await tester.pumpAndSettle();
    final route = h.routes.singleWhere(
      (route) => route.name == AppRoutes.eventDiscovery,
    );
    expect(
      (route.arguments! as EventDiscoveryArgs).bottomBarStageMode,
      StageMode.backstage,
    );
    expect(find.text('Discovery destination'), findsOneWidget);
    expect(h.navigator.currentState!.canPop(), isFalse);
  });
}

Future<_Harness> _mount(
  WidgetTester tester, {
  StageMode stage = StageMode.mainstage,
  int currentIndex = 4,
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
        bottomNavigationBar: ProfilePublicBottomBar(
          currentIndex: currentIndex,
          stageMode: stage,
          onBeforeNavigate: before,
        ),
      ),
      onGenerateRoute: (settings) {
        harness.routes.add(settings);
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => Scaffold(
            body: Text(
              settings.name == AppRoutes.eventDiscovery
                  ? 'Discovery destination'
                  : 'Newer route',
            ),
          ),
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

class _Tokens extends Fake implements TokenStore {
  _Tokens(this.pending);
  final Future<String?> pending;
  @override
  Future<String?> readToken() => pending;
}
