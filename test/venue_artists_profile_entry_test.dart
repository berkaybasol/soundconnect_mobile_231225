import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
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
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/profile_media.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/venue_event_item.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/venue_owner_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/venue_public_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/profile_media_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/profile_search_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/venue_artist_directory_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/venue_event_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/venue_profile_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/cubit/musician_profile_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/cubit/profile_media_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/cubit/venue_profile_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/profile_route_args.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/venue_artists_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/venue_profile_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/venue_public_profile_screen.dart';

import 'support/event_invitation_navigation_fakes.dart';

void main() {
  late _Directory directory;
  late _Badge badge;
  late _Profiles profiles;

  setUp(() async {
    await serviceLocator.reset();
    directory = _Directory();
    badge = _Badge();
    profiles = _Profiles();
    final connections = _Connections();
    final followers = _Followers();
    serviceLocator
      ..registerSingleton<VenueArtistDirectoryRepository>(directory)
      ..registerSingleton<ArtistVenueConnectionRepository>(connections)
      ..registerSingleton<ProfileSearchRepository>(_Search())
      ..registerSingleton<VenueEventRepository>(_Events())
      ..registerSingleton<AudioHandler>(BaseAudioHandler())
      ..registerSingleton<DmBadgeCubit>(badge)
      ..registerFactory<VenueProfileCubit>(() => VenueProfileCubit(profiles))
      ..registerFactory<MusicianProfileCubit>(
        () => MusicianProfileCubit(InvitationProfileRepository()),
      )
      ..registerFactory<ProfileMediaCubit>(() => ProfileMediaCubit(_Media()))
      ..registerFactory<FollowCountCubit>(() => FollowCountCubit(followers))
      ..registerFactory<FollowActionCubit>(() => FollowActionCubit(followers))
      ..registerFactory<ArtistVenueConnectionsCubit>(
        () => ArtistVenueConnectionsCubit(connections),
      )
      ..registerFactory<InteractionStatsCubit>(
        () => InteractionStatsCubit(_Engagement()),
      );
  });

  tearDown(() async {
    await badge.close();
    await serviceLocator.reset();
  });

  for (final owner in [true, false]) {
    testWidgets(
      '${owner ? 'owner' : 'public'} profile Tümü opens actual venue directory',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 1700));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              settings: RouteSettings(
                arguments: owner
                    ? VenueProfileArgs(
                        venueId: 'actual-venue',
                        viewerUserId: 'owner',
                      )
                    : VenuePublicProfileArgs(
                        venueId: 'actual-venue',
                        viewerUserId: 'visitor',
                      ),
              ),
              builder: (_) => owner
                  ? const VenueProfileScreen()
                  : const VenuePublicProfileScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(profiles.ownerReads, owner ? ['actual-venue'] : isEmpty);
        expect(profiles.publicReads, owner ? isEmpty : ['actual-venue']);
        expect(directory.requests, isEmpty);
        expect(find.text('Aktif Sanatçılar'), findsOneWidget);
        final showAll = find.text('Tümü');
        expect(showAll, findsOneWidget);
        await tester.ensureVisible(showAll);
        await tester.tap(showAll);
        await tester.pumpAndSettle();

        final page = tester.widget<VenueArtistsScreen>(
          find.byType(VenueArtistsScreen),
        );
        expect(page.venueId, 'actual-venue');
        expect(page.venueId, isNot('venue-profile-record'));
        expect(page.venueName, 'SoundConnect Ankara');
        expect(directory.requests, [
          ('actual-venue', VenueArtistKind.musician, '', 0),
        ]);
        await tester.tap(find.byKey(const Key('venue-artists-tab-band')));
        await tester.pumpAndSettle();
        expect(directory.requests.last, (
          'actual-venue',
          VenueArtistKind.band,
          '',
          0,
        ));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }
}

const _owner = VenueOwnerProfile(
  venueProfileId: 'venue-profile-record',
  venueId: 'actual-venue',
  ownerUserId: 'owner',
  venueName: 'SoundConnect Ankara',
  bio: null,
  profilePictureUrl: null,
  instagramUrl: null,
  youtubeUrl: null,
  websiteUrl: null,
  address: null,
  phone: null,
  website: null,
  description: null,
  musicStartTime: null,
  cityId: null,
  cityName: 'Ankara',
  districtId: null,
  districtName: 'Çankaya',
  neighborhoodId: null,
  neighborhoodName: null,
  status: 'ACTIVE',
  activeMusicians: [],
  activeBands: [],
  weeklyEvents: [],
);

const _public = VenuePublicProfile(
  venueProfileId: 'venue-profile-record',
  venueId: 'actual-venue',
  ownerUserId: 'owner',
  venueName: 'SoundConnect Ankara',
  bio: null,
  profilePictureUrl: null,
  instagramUrl: null,
  youtubeUrl: null,
  websiteUrl: null,
  address: null,
  phone: null,
  website: null,
  description: null,
  musicStartTime: null,
  cityName: 'Ankara',
  districtName: 'Çankaya',
  neighborhoodName: null,
  activeMusicians: [],
  activeBands: [],
  weeklyEvents: [],
);

class _Profiles extends Fake implements VenueProfileRepository {
  final ownerReads = <String?>[];
  final publicReads = <String?>[];
  @override
  Future<Result<VenueOwnerProfile>> getMyVenueProfileDetail({
    String? venueId,
  }) async {
    ownerReads.add(venueId);
    return const Result.success(_owner);
  }

  @override
  Future<Result<VenuePublicProfile>> getPublicVenueProfile({
    String? venueId,
  }) async {
    publicReads.add(venueId);
    return const Result.success(_public);
  }
}

class _Directory extends Fake implements VenueArtistDirectoryRepository {
  final requests = <(String, VenueArtistKind, String, int)>[];
  @override
  Future<Result<VenueArtistDirectoryPage>> list({
    required String venueId,
    required VenueArtistKind kind,
    String query = '',
    int page = 0,
    int size = 20,
    String? expectedSessionKey,
  }) async {
    requests.add((venueId, kind, query, page));
    return Result.success(
      VenueArtistDirectoryPage(
        items: const [],
        page: page,
        size: size,
        totalElements: 0,
        totalPages: 0,
        last: true,
      ),
    );
  }
}

class _Media extends Fake implements ProfileMediaRepository {
  @override
  Future<Result<ProfileMedia>> getProfileMedia({
    required String profileType,
    required String profileId,
  }) async => const Result.success(
    ProfileMedia(featuredVideo: null, videos: [], audios: []),
  );
}

class _Events extends Fake implements VenueEventRepository {
  @override
  Future<Result<List<VenueOwnerEventItem>>> listByVenue(String venueId) async =>
      const Result.success([]);
  @override
  Future<Result<List<VenueOwnerEventItem>>> listPublicByVenue(
    String venueId,
  ) async => const Result.success([]);
}

class _Followers extends Fake implements FollowRepository {
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

class _Connections extends Fake implements ArtistVenueConnectionRepository {}

class _Search extends Fake implements ProfileSearchRepository {}

class _Engagement extends Fake implements EngagementRepository {}

class _Badge extends Cubit<DmBadgeState> implements DmBadgeCubit {
  _Badge() : super(const DmBadgeState.initial());
  @override
  Future<void> ensureStarted() async {}
  @override
  Future<void> stop() async {}
}
