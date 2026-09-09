import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/policy/stage_mode.dart';
import 'package:soundconnect_23_12_25codx/modules/artist_venue/domain/artist_venue_connection_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/artist_venue/presentation/cubit/artist_venue_connections_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_badge_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_badge_state.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/engagement_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_page.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/presentation/cubit/interaction_stats_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/follow/domain/follow_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/follow/presentation/cubit/follow_action_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/follow/presentation/cubit/follow_count_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/musician_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/profile_media.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/venue_event_detail.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/musician_profile_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/profile_media_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/venue_event_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/cubit/musician_profile_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/cubit/profile_media_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/musician_public_profile_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/profile_route_args.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/weekly_event_detail_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/presentation/screens/table_group_route_args.dart';

import 'support/event_audience_fakes.dart';

void main() {
  late _BadgeCubit badge;
  late _ProfileRepository profiles;

  setUp(() async {
    await serviceLocator.reset();
    badge = _BadgeCubit();
    profiles = _ProfileRepository();
    final follow = _FollowRepository();
    final engagement = _EngagementRepository();
    serviceLocator
      ..registerSingleton<AuthSessionManager>(
        AudienceTestSessions(audienceSession()),
      )
      ..registerSingleton<MusicianProfileRepository>(profiles)
      ..registerSingleton<VenueEventRepository>(_EventRepository())
      ..registerSingleton<EngagementRepository>(engagement)
      ..registerSingleton<AudioHandler>(BaseAudioHandler())
      ..registerSingleton<DmBadgeCubit>(badge)
      ..registerFactory<MusicianProfileCubit>(
        () => MusicianProfileCubit(profiles),
      )
      ..registerFactory<ProfileMediaCubit>(
        () => ProfileMediaCubit(_MediaRepository()),
      )
      ..registerFactory<FollowCountCubit>(() => FollowCountCubit(follow))
      ..registerFactory<FollowActionCubit>(() => FollowActionCubit(follow))
      ..registerFactory<ArtistVenueConnectionsCubit>(
        () => ArtistVenueConnectionsCubit(_ConnectionRepository()),
      )
      ..registerFactory<InteractionStatsCubit>(
        () => InteractionStatsCubit(engagement),
      );
  });

  tearDown(() async {
    await badge.close();
    await serviceLocator.reset();
  });

  for (final destination in <String, String>{
    'Keşfet': AppRoutes.eventDiscovery,
    'Müzik Birleştirir!': AppRoutes.tableGroupList,
    'Profil': AppRoutes.listenerProfile,
  }.entries) {
    testWidgets(
      'listener opens event artist and keeps mainstage ${destination.key} navigation',
      (tester) async {
        final routes = <RouteSettings>[];
        await _openEvent(tester, routes);
        final performer = find.byKey(const Key('event-performer-profile-chip'));
        await tester.ensureVisible(performer);
        await tester.tap(performer);
        await tester.pumpAndSettle();

        // Render the real destination, including its default bottom bar, so a
        // correct route name alone cannot conceal the reported stage switch.
        expect(find.byType(MusicianPublicProfileScreen), findsOneWidget);
        expect(find.text('public-artist'), findsOneWidget);
        expect(routes.single.name, AppRoutes.musicianPublicProfile);
        expect(
          (routes.single.arguments as PublicProfileArgs).profileId,
          _profile.id,
        );
        expect(profiles.requestedIds, [_profile.id, _profile.id]);
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
        expect(find.text('Collab'), findsNothing);
        expect(find.text('Git'), findsNothing);

        await tester.tap(
          find
              .descendant(
                of: find.byType(BottomNavigationBar),
                matching: find.text(destination.key),
              )
              .first,
        );
        await tester.pumpAndSettle();

        expect(routes.last.name, destination.value);
        expect(find.text('destination:${destination.value}'), findsOneWidget);
        expect(
          tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
          isFalse,
        );
        if (destination.value == AppRoutes.tableGroupList) {
          expect(
            (routes.last.arguments as TableGroupListArgs).bottomBarStageMode,
            StageMode.mainstage,
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Future<void> _openEvent(WidgetTester tester, List<RouteSettings> routes) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: WeeklyEventDetailScreen(
        event: WeeklyCalendarEvent(
          id: 'linked-event',
          title: 'Listener navigation regression',
          artistName: 'public-artist',
          artistProfileId: _profile.id,
          performerType: 'MUSICIAN',
          venueName: 'Public venue',
          venueId: null,
          city: 'Ankara',
          district: 'Çankaya',
          neighborhood: '',
          eventDate: '09.09.2026',
          startTime: '20:00',
          endTime: '22:00',
          description: 'An event with a verified public musician.',
        ),
      ),
      onGenerateRoute: (settings) {
        routes.add(settings);
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => settings.name == AppRoutes.musicianPublicProfile
              ? const MusicianPublicProfileScreen()
              : Scaffold(body: Text('destination:${settings.name}')),
        );
      },
    ),
  );
  await tester.pumpAndSettle();
}

const _profile = MusicianProfile(
  id: 'public-musician-profile',
  userId: 'public-musician-user',
  username: 'public-artist',
  stageName: null,
  bio: 'Public musician biography.',
  profilePicture: null,
  instagramUrl: null,
  youtubeUrl: null,
  soundcloudUrl: null,
  spotifyEmbedUrl: null,
  spotifyArtistId: null,
  spotifyTrackIds: [],
  spotifyTracks: [],
  instruments: [],
  activeVenues: [],
  bands: [],
);

class _ProfileRepository extends Fake implements MusicianProfileRepository {
  final requestedIds = <String>[];

  @override
  Future<Result<MusicianProfile>> getPublicProfileByProfileId(
    String profileId,
  ) async {
    requestedIds.add(profileId);
    return const Result.success(_profile);
  }
}

class _EventRepository extends Fake implements VenueEventRepository {
  @override
  Future<Result<VenueEventDetail>> getDetail(String eventId) async =>
      Result.success(
        VenueEventDetail(
          id: eventId,
          shareUrl: null,
          posterImage: null,
          performerName: 'public-artist',
          musicianProfileId: _profile.id,
          performerType: 'MUSICIAN',
        ),
      );
}

class _MediaRepository extends Fake implements ProfileMediaRepository {
  @override
  Future<Result<ProfileMedia>> getProfileMedia({
    required String profileType,
    required String profileId,
  }) async => const Result.success(
    ProfileMedia(featuredVideo: null, videos: [], audios: []),
  );
}

class _ConnectionRepository extends Fake
    implements ArtistVenueConnectionRepository {}

class _FollowRepository extends Fake implements FollowRepository {
  @override
  Future<Result<int>> getFollowersCount(String userId) async =>
      const Result.success(0);

  @override
  Future<Result<int>> getFollowingCount(String userId) async =>
      const Result.success(0);

  @override
  Future<Result<bool>> isFollowing({
    required String followerId,
    required String followingId,
  }) async => const Result.success(false);
}

class _EngagementRepository extends Fake implements EngagementRepository {
  @override
  Future<Result<CommentPage>> listComments({
    required String targetType,
    required String targetId,
    int page = 0,
    int size = 20,
  }) async => const Result.success(CommentPage(items: [], totalElements: 0));
}

class _BadgeCubit extends Cubit<DmBadgeState> implements DmBadgeCubit {
  _BadgeCubit() : super(const DmBadgeState.initial());

  @override
  Future<void> ensureStarted() async {}

  @override
  Future<void> stop() async {}
}
