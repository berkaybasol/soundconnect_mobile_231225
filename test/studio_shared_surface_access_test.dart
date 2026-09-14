import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_badge_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_badge_state.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/engagement_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/presentation/cubit/interaction_stats_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/navigation/studio_navigation.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/profile_audio_tab_shared.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/profile_social_support.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/studio_listener_info_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/spotify/domain/entities/spotify_track_preview.dart';
import 'package:soundconnect_23_12_25codx/modules/spotify/domain/spotify_repository.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/profile_menu_actions.dart';

import 'support/event_audience_fakes.dart';

void main() {
  late AudienceTestSessions sessions;
  setUp(() {
    sessions = AudienceTestSessions(audienceSession(role: 'ROLE_STUDIO'));
    serviceLocator.registerSingleton<AuthSessionManager>(sessions);
    serviceLocator.registerSingleton<DmBadgeCubit>(
      _Badge(),
      dispose: (value) => value.close(),
    );
  });
  tearDown(() async {
    await serviceLocator.reset();
    sessions.dispose();
  });

  testWidgets(
    'open studio quick menu removes its owner actions after listener switch',
    (tester) async {
      var managementCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showProfileQuickMenu(
                  context,
                  onSettings: () async {},
                  onManagement: () async {
                    managementCalls++;
                  },
                  routeBoundary: studioRouteBoundary,
                ),
                child: const Text('Open studio menu'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open studio menu'));
      await tester.pumpAndSettle();
      expect(find.text('Yönetim Paneli'), findsOneWidget);

      sessions.replace(audienceSession());
      await tester.pumpAndSettle();
      expect(find.text('Yönetim Paneli'), findsNothing);
      expect(find.byKey(const Key('studio-listener-info')), findsOneWidget);
      expect(managementCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'studio social dialog drops its cached URL after listener switch',
    (tester) async {
      String? submitted;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  submitted = await promptForSocialLink(
                    context,
                    platform: ProfileSocialPlatform.instagram,
                    initialValue: 'https://instagram.com/cached-studio',
                    allowRemoval: true,
                    routeBoundary: studioRouteBoundary,
                  );
                },
                child: const Text('Open social editor'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open social editor'));
      await tester.pumpAndSettle();
      expect(find.text('https://instagram.com/cached-studio'), findsOneWidget);

      sessions.replace(audienceSession());
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNothing);
      expect(find.text('https://instagram.com/cached-studio'), findsNothing);
      expect(find.byKey(const Key('studio-listener-info')), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const Key('studio-listener-return')),
      );
      await tester.tap(find.byKey(const Key('studio-listener-return')));
      await tester.pumpAndSettle();
      expect(submitted, isNull);
      expect(find.text('Open social editor'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final studio in [true, false]) {
    testWidgets(
      studio
          ? 'studio Spotify catalog drops its snapshot after listener switch'
          : 'shared musician Spotify catalog remains available to a listener',
      (tester) async {
        await _mountAudio(tester, studio: studio);
        await tester.tap(find.text('Spotify Kataloğu'));
        await tester.pumpAndSettle();
        expect(find.text('Cached recording'), findsOneWidget);

        sessions.replace(audienceSession());
        await tester.pumpAndSettle();
        expect(
          find.text('Cached recording'),
          studio ? findsNothing : findsOneWidget,
        );
        expect(
          find.byType(ReorderableListView),
          studio ? findsNothing : findsOneWidget,
        );
        expect(
          find.byKey(const Key('studio-listener-info')),
          studio ? findsWidgets : findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'open studio Spotify picker ignores a late result after listener switch',
    (tester) async {
      final spotify = _Spotify();
      serviceLocator.registerSingleton<SpotifyRepository>(spotify);
      await _mountAudio(tester);
      await tester.tap(find.text('Spotify Kataloğu'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Spotify parçası ekle'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'late track');
      await tester.pump(const Duration(milliseconds: 350));
      expect(spotify.queries, ['late track']);

      sessions.replace(audienceSession());
      await tester.pumpAndSettle();
      spotify.result.complete(const Result.success([_track]));
      await tester.pumpAndSettle();
      expect(find.byType(TextField, skipOffstage: false), findsNothing);
      expect(find.text('Cached recording', skipOffstage: false), findsNothing);
      expect(find.byKey(const Key('studio-listener-info')), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'studio Spotify debounce does not start a request after listener switch',
    (tester) async {
      final spotify = _Spotify();
      serviceLocator.registerSingleton<SpotifyRepository>(spotify);
      await _mountAudio(tester);
      await tester.tap(find.text('Spotify Kataloğu'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Spotify parçası ekle'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'queued track');
      expect(spotify.queries, isEmpty);

      sessions.replace(audienceSession());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(spotify.queries, isEmpty);
      expect(find.byType(TextField, skipOffstage: false), findsNothing);
      expect(find.byKey(const Key('studio-listener-info')), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'open studio audio upload sheet hides its draft after listener switch',
    (tester) async {
      await _mountAudio(tester);
      await tester.tap(find.text('Kayıt ekle'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('profile-track-upload-submit')),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), 'Private upload draft');

      sessions.replace(audienceSession());
      await tester.pumpAndSettle();
      expect(find.byType(TextField, skipOffstage: false), findsNothing);
      expect(
        find.text('Private upload draft', skipOffstage: false),
        findsNothing,
      );
      expect(
        find.byKey(const Key('profile-track-upload-submit')),
        findsNothing,
      );
      expect(find.byKey(const Key('studio-listener-info')), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _mountAudio(WidgetTester tester, {bool studio = true}) async {
  Widget content(BuildContext context) => Scaffold(
    body: ProfileAudioTab(
      items: const [],
      profileId: studio ? 'studio-1' : 'musician-1',
      spotifyTracks: const [_track],
      spotifyLoading: false,
      ownerMode: true,
      audioHandler: _Audio(),
      uploadOwnerType: studio ? 'STUDIO_PROFILE' : 'MUSICIAN_PROFILE',
      uploadProfileType: studio ? 'STUDIO' : 'MUSICIAN',
      showSpotifyCatalogButtonWhenOwnerAndEmpty: true,
      emptyUploadPrompt: 'Kayıt ekle',
      uploadActionLabel: 'Kayıt ekle',
      onSpotifyTracksChanged: (_) async => true,
      routeBoundary: studio ? studioRouteBoundary : null,
    ),
  );
  await tester.pumpWidget(
    BlocProvider(
      create: (_) => InteractionStatsCubit(_Engagement()),
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: studio
            ? StudioListenerAccessGate(builder: content)
            : Builder(builder: content),
      ),
    ),
  );
}

class _Badge extends Cubit<DmBadgeState> implements DmBadgeCubit {
  _Badge() : super(const DmBadgeState.initial());
  @override
  Future<void> ensureStarted() async {}
  @override
  Future<void> stop() async {}
}

class _Audio extends BaseAudioHandler {}

class _Engagement extends Fake implements EngagementRepository {}

class _Spotify extends Fake implements SpotifyRepository {
  final queries = <String>[];
  final result = Completer<Result<List<SpotifyTrackPreview>>>();
  @override
  Future<Result<List<SpotifyTrackPreview>>> searchTracks(
    String query, {
    int limit = 5,
  }) {
    queries.add(query);
    return result.future;
  }
}

const _track = SpotifyTrackPreview(
  id: 'track-1',
  name: 'Cached recording',
  previewUrl: null,
  durationSeconds: 120,
  spotifyUrl: null,
  albumImageUrl: null,
  artistNames: ['Studio artist'],
);
