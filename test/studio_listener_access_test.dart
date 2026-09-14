import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_router.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/dm_user_profile_resolver.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/entities/dm_profile_target.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_badge_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_badge_state.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_item.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_user_summary.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/presentation/widgets/comment_author_identity.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/presentation/screens/overthinking_profile_link.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/studio_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/navigation/profile_route_gate.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/navigation/profile_route_resolver.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/profile_route_args.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/studio_listener_info_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/studio_profile_screen.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';

import 'support/event_audience_fakes.dart';

void main() {
  late AudienceTestSessions sessions;
  setUp(() {
    sessions = AudienceTestSessions(audienceSession());
    serviceLocator.registerSingleton<AuthSessionManager>(sessions);
    serviceLocator.registerSingleton<DmBadgeCubit>(
      _Badge(),
      dispose: (value) => value.close(),
    );
    // Deliberately register no studio repositories or Cubits. Any access fails.
  });
  tearDown(() async {
    await serviceLocator.reset();
    sessions.dispose();
  });

  for (final route in [
    AppRoutes.studioPublicProfile,
    AppRoutes.studioProfile,
    AppRoutes.studioReservationCalendar,
  ]) {
    testWidgets('$route shows explanation before loading any studio data', (
      tester,
    ) async {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.navy,
          navigatorKey: navigator,
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: const Scaffold(body: Text('Previous page')),
        ),
      );
      final entry = sessions.session;
      navigator.currentState!.pushNamed(
        route,
        arguments: const PublicProfileArgs(profileId: 'studio'),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('studio-listener-info')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(
        find.byKey(const Key('studio-listener-return')),
      );
      await tester.tap(find.byKey(const Key('studio-listener-return')));
      await tester.pumpAndSettle();
      expect(find.text('Previous page'), findsOneWidget);
      expect(identical(sessions.session, entry), isTrue);
    });
  }

  for (final entry in <String, Widget>{
    'public': const StudioPublicProfileScreen(),
    'owner': const StudioProfileScreen(openContactEditor: true),
    'management snapshot': const StudioManagementPanelScreen(profile: _studio),
    'contact snapshot': StudioProfileContactEditorSheet(
      profile: _studio,
      onSave: (_) =>
          throw StateError('Listener must not save a studio profile'),
    ),
    'calendar': const StudioReservationCalendarScreen(
      args: StudioReservationCalendarArgs(
        roomId: 'room',
        studioProfileId: 'studio',
        ownerMode: false,
      ),
    ),
    'public gate': ProfileRouteGate(
      target: ProfileRouteTarget.fromArguments(
        ProfileRouteKind.studio,
        const PublicProfileArgs(profileId: 'studio'),
      ),
      publicBuilder: (_) => throw StateError('Studio data must not be built'),
    ),
  }.entries) {
    testWidgets(
      'direct ${entry.key} entry blocks before providers are created',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(theme: AppTheme.navy, home: entry.value),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('studio-listener-info')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'current studio subtree is disposed on listener role and account changes',
    (tester) async {
      sessions.replace(audienceSession(role: 'MUSICIAN'));
      var builds = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.navy,
          home: StudioListenerAccessGate(
            builder: (_) {
              builds++;
              return const Scaffold(body: Text('Professional content'));
            },
          ),
        ),
      );
      expect(find.text('Professional content'), findsOneWidget);
      sessions.replace(audienceSession());
      await tester.pumpAndSettle();
      expect(find.text('Professional content'), findsNothing);
      expect(find.byKey(const Key('studio-listener-info')), findsOneWidget);
      sessions.replace(audienceSession(user: 'another-listener'));
      await tester.pumpAndSettle();
      expect(builds, 1);
      expect(find.byKey(const Key('studio-listener-info')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'root entry return CTA preserves login and uses the account start route',
    (tester) async {
      final destinations = <String?>[];
      final entry = sessions.session;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.navy,
          home: const StudioListenerInfoScreen(),
          onGenerateRoute: (settings) {
            destinations.add(settings.name);
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const Scaffold(body: Text('Listener profile')),
            );
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('studio-listener-return')),
      );
      await tester.tap(find.byKey(const Key('studio-listener-return')));
      await tester.pumpAndSettle();
      expect(destinations, [AppRoutes.listenerProfile]);
      expect(identical(sessions.session, entry), isTrue);
      expect(find.text('Listener profile'), findsOneWidget);
    },
  );

  for (final surface in ['Overthinking', 'comment']) {
    testWidgets(
      '$surface restricted userId opens explanation without profile identity',
      (tester) async {
        final resolver = _RestrictedResolver();
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.navy,
            onGenerateRoute: AppRouter.onGenerateRoute,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    if (surface == 'Overthinking') {
                      await openOverthinkingUserProfile(
                        context,
                        'studio-user',
                        resolver: resolver,
                      );
                    } else {
                      await openCommentAuthorProfile(
                        context,
                        const CommentItem(
                          id: 'comment',
                          user: CommentUserSummary(
                            id: 'studio-user',
                            username: 'studio',
                            avatarUrl: null,
                          ),
                          text: 'Müzik!',
                          deleted: false,
                          parentCommentId: null,
                          replyCount: 0,
                          createdAt: null,
                        ),
                        resolver: resolver,
                      );
                    }
                  },
                  child: const Text('Avatar'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Avatar'));
        await tester.pumpAndSettle();
        expect(resolver.lookups, ['studio-user']);
        expect(find.byKey(const Key('studio-listener-info')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(
          find.byKey(const Key('studio-listener-return')),
        );
        await tester.tap(find.byKey(const Key('studio-listener-return')));
        await tester.pumpAndSettle();
        expect(find.text('Avatar'), findsOneWidget);
        expect(find.byKey(const Key('studio-listener-info')), findsNothing);
      },
    );
  }

  final renderDir = Platform.environment['STUDIO_LISTENER_RENDER_DIR'];
  for (final fixture in [(390.0, 844.0, 1.0), (320.0, 740.0, 2.0)]) {
    testWidgets(
      'studio explanation fits ${fixture.$1} width at ${fixture.$3} text scale',
      (tester) async {
        tester.view.physicalSize = Size(fixture.$1, fixture.$2);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        if (renderDir != null) {
          await tester.runAsync(() async {
            final fonts =
                '${File(Platform.resolvedExecutable).parent.parent.parent.path}/material_fonts';
            final loader = FontLoader('Roboto');
            for (final font in [
              'roboto-regular.ttf',
              'roboto-medium.ttf',
              'roboto-bold.ttf',
              'roboto-black.ttf',
            ]) {
              loader.addFont(
                File('$fonts/$font').readAsBytes().then(ByteData.sublistView),
              );
            }
            await loader.load();
            await (FontLoader('MaterialIcons')
                  ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
                .load();
          });
        }
        final capture = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.navy.copyWith(
              textTheme: AppTheme.navy.textTheme.apply(fontFamily: 'Roboto'),
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(fixture.$3)),
              child: child!,
            ),
            home: RepaintBoundary(
              key: capture,
              child: const StudioListenerInfoScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (renderDir != null) {
          await _capture(
            tester,
            capture,
            '$renderDir/studio-${fixture.$1.toInt()}-top.png',
          );
        }
        await tester.ensureVisible(
          find.byKey(const Key('studio-listener-return')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('studio-listener-return')).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        if (renderDir != null) {
          await _capture(
            tester,
            capture,
            '$renderDir/studio-${fixture.$1.toInt()}-actions.png',
          );
        }
      },
    );
  }
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String path) async {
  await tester.runAsync(() async {
    final image =
        await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary)
            .toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(path).parent.create(recursive: true);
    await File(path).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

class _Badge extends Cubit<DmBadgeState> implements DmBadgeCubit {
  _Badge() : super(const DmBadgeState.initial());
  @override
  Future<void> ensureStarted() async {}
  @override
  Future<void> stop() async {}
}

class _RestrictedResolver implements DmUserProfileResolver {
  final lookups = <String>[];
  @override
  Future<List<DmProfileTarget>> resolveByUserId({
    required String userId,
    String? usernameHint,
  }) async {
    lookups.add(userId);
    return const [DmProfileTarget.studioRestricted()];
  }
}

const _studio = StudioProfile(
  id: 'studio',
  userId: 'owner',
  name: 'Private cached studio',
  description: 'Studio description',
  profilePictureMediaId: null,
  profilePictureUrl: null,
  address: 'Private cached address',
  phone: null,
  website: null,
  facilities: [],
  instagramUrl: null,
  youtubeUrl: null,
  timeZone: 'Europe/Istanbul',
  version: 0,
  spotifyTrackIds: [],
  spotifyTracks: [],
  activeRoomCount: 0,
  backlineUnitCount: 0,
);
