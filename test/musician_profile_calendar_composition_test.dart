import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/artist_venue/domain/artist_venue_connection_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/artist_venue/presentation/cubit/artist_venue_connections_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_badge_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_badge_state.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/engagement_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/presentation/cubit/interaction_stats_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/follow/domain/follow_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/follow/presentation/cubit/follow_action_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/follow/presentation/cubit/follow_count_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/location_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/musician_calendar.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/musician_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/profile_media.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/profile_venue_models.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/venue_event_detail.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/musician_calendar_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/musician_profile_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/profile_media_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/venue_directory_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/cubit/musician_profile_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/cubit/profile_media_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/musician_profile_calendar_slot.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/musician_profile_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/musician_public_profile_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/profile_route_args.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/weekly_event_carousel.dart';

void main() {
  late _CalendarRepository calendar;
  late _BadgeCubit badge;

  setUp(() async {
    await serviceLocator.reset();
    calendar = _CalendarRepository();
    badge = _BadgeCubit();
    final connections = _ConnectionRepository();
    final followers = _FollowRepository();
    final profiles = _ProfileRepository();
    serviceLocator
      ..registerSingleton<MusicianCalendarRepository>(calendar)
      ..registerSingleton<MusicianProfileRepository>(profiles)
      ..registerSingleton<ArtistVenueConnectionRepository>(connections)
      ..registerSingleton<LocationRepository>(_LocationRepository())
      ..registerSingleton<VenueDirectoryRepository>(_VenueDirectoryRepository())
      ..registerSingleton<AudioHandler>(BaseAudioHandler())
      ..registerSingleton<DmBadgeCubit>(badge)
      ..registerFactory<MusicianProfileCubit>(
        () => MusicianProfileCubit(profiles),
      )
      ..registerFactory<ProfileMediaCubit>(
        () => ProfileMediaCubit(_MediaRepository()),
      )
      ..registerFactory<FollowCountCubit>(() => FollowCountCubit(followers))
      ..registerFactory<FollowActionCubit>(() => FollowActionCubit(followers))
      ..registerFactory<ArtistVenueConnectionsCubit>(
        () => ArtistVenueConnectionsCubit(connections),
      )
      ..registerFactory<InteractionStatsCubit>(
        () => InteractionStatsCubit(_EngagementRepository()),
      );
  });

  tearDown(() async {
    await calendar.dispose();
    await badge.close();
    await serviceLocator.reset();
  });

  for (final owner in [true, false]) {
    final label = owner ? 'owner profile' : 'public profile';

    testWidgets('$label keeps venues through per-event publication changes', (
      tester,
    ) async {
      await _pumpProfile(tester, owner: owner);
      await tester.pumpAndSettle();

      _expectVenues();
      _expectNoCalendar(tester);

      // A published event appears without an additional global preference.
      calendar.approved = true;
      final readsBeforeApproval = calendar.reads;
      calendar.invalidate();
      await tester.pumpAndSettle();
      expect(calendar.reads, greaterThan(readsBeforeApproval));
      _expectVenues();
      expect(find.text('Haftalık Takvim'), findsOneWidget);
      expect(
        tester
            .widget<WeeklyEventCarousel>(find.byType(WeeklyEventCarousel))
            .compactTitle,
        !owner,
      );
      expect(
        tester
            .widget<WeeklyEventCarousel>(find.byType(WeeklyEventCarousel))
            .items
            .single
            .id,
        'approved-event',
      );
      expect(find.text('Onaylı Cuma Gecesi'), findsOneWidget);

      calendar.approved = false;
      calendar.invalidate();
      await tester.pumpAndSettle();
      _expectVenues();
      _expectNoCalendar(tester);

      calendar.approved = true;
      calendar.invalidate();
      await tester.pumpAndSettle();

      // The original linked venue is still navigable with the calendar present.
      await tester.ensureVisible(find.text('Bağlı Sahne'));
      await tester.tap(find.text('Bağlı Sahne'));
      await tester.pumpAndSettle();
      expect(find.text('venue-route:connected-venue'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$label has no calendar placeholder during unknown or error', (
      tester,
    ) async {
      final pending = Completer<Result<MusicianCalendarPage>>();
      calendar.pending = pending.future;
      await _pumpProfile(tester, owner: owner);
      await tester.pump();
      await tester.pump();
      _expectVenues();
      _expectNoCalendar(tester);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      pending.complete(
        const Result.failure(AppError(code: '503', message: 'Unavailable')),
      );
      await tester.pumpAndSettle();
      _expectVenues();
      _expectNoCalendar(tester);
      expect(find.byKey(const Key('musician-calendar-retry')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _pumpProfile(WidgetTester tester, {required bool owner}) async {
  await tester.binding.setSurfaceSize(const Size(390, 1700));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      onGenerateRoute: (settings) {
        if (settings.name == AppRoutes.venuePublicProfile) {
          final args = settings.arguments! as VenuePublicProfileArgs;
          return MaterialPageRoute<void>(
            builder: (_) => Scaffold(body: Text('venue-route:${args.venueId}')),
          );
        }
        return MaterialPageRoute<void>(
          settings: RouteSettings(
            arguments: PublicProfileArgs(
              profileId: 'musician-profile',
              viewerUserId: owner ? 'musician-user' : 'visitor-user',
            ),
          ),
          builder: (_) => owner
              ? const MusicianProfileScreen()
              : const MusicianPublicProfileScreen(),
        );
      },
    ),
  );
}

void _expectVenues() {
  expect(find.text('Çaldığı Mekanlar'), findsOneWidget);
  expect(find.text('Bağlı Sahne'), findsOneWidget);
}

void _expectNoCalendar(WidgetTester tester) {
  expect(find.text('Haftalık Takvim'), findsNothing);
  expect(find.byType(WeeklyEventCarousel), findsNothing);
  expect(tester.getSize(find.byType(MusicianProfileCalendarSlot)).height, 0);
}

const _venue = VenueConnection(
  requestId: 'accepted-connection',
  venueId: 'connected-venue',
  venueName: 'Bağlı Sahne',
);

const _profile = MusicianProfile(
  id: 'musician-profile',
  userId: 'musician-user',
  username: 'bugrasahin',
  stageName: 'Buğra',
  bio: 'Canlı müzik.',
  profilePicture: null,
  instagramUrl: null,
  youtubeUrl: null,
  soundcloudUrl: null,
  spotifyEmbedUrl: null,
  spotifyArtistId: null,
  spotifyTrackIds: [],
  spotifyTracks: [],
  instruments: [],
  activeVenues: ['Bağlı Sahne'],
  activeVenueConnections: [_venue],
  bands: [],
);

class _ProfileRepository extends Fake implements MusicianProfileRepository {
  @override
  Future<Result<MusicianProfile>> getMyProfile() async =>
      const Result.success(_profile);

  @override
  Future<Result<MusicianProfile>> getPublicProfileByProfileId(
    String profileId,
  ) async => const Result.success(_profile);
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
    implements ArtistVenueConnectionRepository {
  @override
  Future<Result<List<VenueConnection>>> getVenueConnectionsByStatus(
    String musicianProfileId, {
    required String status,
  }) async => const Result.success([_venue]);
}

class _FollowRepository extends Fake implements FollowRepository {
  @override
  Future<Result<int>> getFollowersCount(String userId) async =>
      const Result.success(3);

  @override
  Future<Result<int>> getFollowingCount(String userId) async =>
      const Result.success(2);

  @override
  Future<Result<bool>> isFollowing({
    required String followerId,
    required String followingId,
  }) async => const Result.success(false);
}

class _LocationRepository extends Fake implements LocationRepository {}

class _VenueDirectoryRepository extends Fake
    implements VenueDirectoryRepository {}

class _EngagementRepository extends Fake implements EngagementRepository {}

class _BadgeCubit extends Cubit<DmBadgeState> implements DmBadgeCubit {
  _BadgeCubit() : super(const DmBadgeState.initial());

  @override
  Future<void> ensureStarted() async {}

  @override
  Future<void> stop() async {}
}

class _CalendarRepository extends Fake implements MusicianCalendarRepository {
  final _changes = StreamController<void>.broadcast();
  bool visible = true;
  bool approved = false;
  int reads = 0;
  Future<Result<MusicianCalendarPage>>? pending;

  @override
  Stream<void> get changes => _changes.stream;

  @override
  void invalidate() => _changes.add(null);

  @override
  Future<void> dispose() => _changes.close();

  @override
  Future<Result<MusicianCalendarPage>> getCalendar({
    required String profileId,
    required DateTime startDate,
    required DateTime endDate,
    int page = 0,
    int size = 20,
  }) async {
    reads++;
    if (pending != null) return pending!;
    return Result.success(
      MusicianCalendarPage(
        profileId: profileId,
        startDate: startDate,
        endDate: endDate,
        visible: visible,
        page: page,
        size: size,
        hasNext: false,
        events: visible && approved
            ? [
                VenueEventDetail(
                  id: 'approved-event',
                  shareUrl: null,
                  posterImage: null,
                  performerName: 'Buğra',
                  musicianProfileId: profileId,
                  performerType: 'MUSICIAN',
                  title: 'Onaylı Cuma Gecesi',
                  eventDate: startDate,
                  startTime: '21:00:00',
                  venueId: 'event-venue',
                  venueName: 'Etkinlik Sahnesi',
                ),
              ]
            : [],
      ),
    );
  }
}
