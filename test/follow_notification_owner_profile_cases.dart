part of 'follow_notification_open_test.dart';

extension _OwnerProfileCases on _FollowNotificationOpenCases {
  void _registerOwnProfileCases() {
    for (final role in ['MUSICIAN', 'LISTENER', 'VENUE', 'STUDIO']) {
      for (final outcome in [
        'success',
        'wrong-profile',
        'wrong-user',
        'session-change',
        'failure',
      ]) {
        testWidgets(
          'ADMIN_BROADCAST own $role waits for real owner data: $outcome',
          (t) async {
            final pending = Completer<Result<Object>>();
            await t.runAsync(() async {
              sessions.replace(
                audienceSession(user: recipient, role: 'ROLE_$role'),
              );
              await cubit.ensureStarted();
              await prepareCustomProfile();
              customProfileUser = recipient;
              resolved = {
                'userId': recipient,
                'profiles': [
                  {
                    'type': role,
                    'profileId': profileId,
                    'displayName': 'Owner target',
                  },
                ],
              };
              reconciliations = 0;
            });
            switch (role) {
              case 'MUSICIAN':
                final repo = _OwnerMusician(pending);
                await serviceLocator.unregister<MusicianProfileRepository>();
                await serviceLocator.unregister<MusicianProfileCubit>();
                serviceLocator
                  ..registerSingleton<MusicianProfileRepository>(repo)
                  ..registerFactory<MusicianProfileCubit>(
                    () => MusicianProfileCubit(repo, sessions: sessions),
                  )
                  ..registerSingleton<LocationRepository>(_OwnerLocations())
                  ..registerSingleton<VenueDirectoryRepository>(
                    _OwnerDirectory(),
                  );
              case 'LISTENER':
                final repo = _OwnerListener(pending);
                serviceLocator
                  ..registerSingleton<ListenerProfileRepository>(repo)
                  ..registerFactory<ListenerProfileCubit>(
                    () => ListenerProfileCubit(repo, sessions: sessions),
                  );
              case 'VENUE':
                final repo = _OwnerVenue(pending);
                serviceLocator
                  ..registerSingleton<VenueProfileRepository>(repo)
                  ..registerFactory<VenueProfileCubit>(
                    () => VenueProfileCubit(repo, sessions: sessions),
                  )
                  ..registerSingleton<ProfileSearchRepository>(_OwnerSearch());
              case 'STUDIO':
                final repo = _OwnerStudio(pending);
                serviceLocator
                  ..registerSingleton<StudioProfileRepository>(repo)
                  ..registerFactory<StudioProfileCubit>(
                    () => StudioProfileCubit(repo),
                  );
            }
            await mount(t);
            await openCustomProfile(t);
            for (var frame = 0; frame < 8; frame++) {
              await t.pump(const Duration(milliseconds: 200));
            }
            unread();
            final expected = switch (role) {
              'MUSICIAN' => find.byType(MusicianProfileScreen),
              'LISTENER' => find.byType(ListenerProfileScreen),
              'VENUE' => find.byType(VenueProfileScreen),
              _ => find.byType(StudioProfileScreen),
            };
            expect(expected, findsOneWidget);
            if (outcome == 'session-change') {
              await t.runAsync(() async {
                sessions.replace(
                  audienceSession(
                    user: recipient,
                    role: 'ROLE_$role',
                    token: 'replacement',
                  ),
                );
                await cubit.stop();
              });
            }
            pending.complete(
              outcome == 'failure'
                  ? const Result.failure(fail)
                  : Result.success(
                      _ownerObject(
                        role,
                        id: outcome == 'wrong-profile' ? bandId : profileId,
                        user: outcome == 'wrong-user' ? follower : recipient,
                      ),
                    ),
            );
            for (var frame = 0; frame < 8; frame++) {
              await t.pump(const Duration(milliseconds: 200));
            }
            if (outcome == 'success') {
              onlyTarget();
              expect(expected, findsOneWidget);
              expect(resolverGets(), 1);
              expect(
                api.requests.where((r) => r.path.endsWith('/custom-target')),
                hasLength(1),
              );
            } else {
              expect(acks, isEmpty);
              expect(repository.items.every((item) => !item.read), isTrue);
              expect(reconciliations, 0);
            }
            expect(t.takeException(), isNull);
            await t.pumpWidget(const SizedBox.shrink());
            await t.pump();
          },
        );
      }
    }
  }
}

Object _ownerObject(
  String role, {
  String id = profileId,
  String user = recipient,
}) => switch (role) {
  'MUSICIAN' => MusicianProfile(
    id: id,
    userId: user,
    username: 'Owner musician',
    stageName: null,
    bio: null,
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
  ),
  'LISTENER' => ListenerProfile(
    id: id,
    userId: user,
    username: 'Owner listener',
    bio: null,
    profilePictureUrl: null,
    followerCount: 0,
    followingCount: 0,
  ),
  'VENUE' => VenueOwnerProfile(
    venueProfileId: bandId,
    venueId: id,
    ownerUserId: user,
    venueName: 'Owner venue',
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
    cityName: null,
    districtId: null,
    districtName: null,
    neighborhoodId: null,
    neighborhoodName: null,
    status: 'APPROVED',
    activeMusicians: [],
    activeBands: [],
    weeklyEvents: [],
  ),
  _ => StudioProfile(
    id: id,
    userId: user,
    name: 'Owner studio',
    description: null,
    profilePictureMediaId: null,
    profilePictureUrl: null,
    address: null,
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
  ),
};

Future<Result<T>> _ownerResult<T>(Completer<Result<Object>> pending) async {
  final result = await pending.future;
  return result.isSuccess
      ? Result.success(result.data as T)
      : Result.failure(result.error!);
}

class _OwnerMusician extends Fake implements MusicianProfileRepository {
  _OwnerMusician(this.pending);
  final Completer<Result<Object>> pending;
  int gets = 0;
  @override
  Future<Result<MusicianProfile>> getMyProfile() async => ++gets == 1
      ? Result.success(_ownerObject('MUSICIAN') as MusicianProfile)
      : _ownerResult(pending);
}

class _OwnerListener extends Fake implements ListenerProfileRepository {
  _OwnerListener(this.pending);
  final Completer<Result<Object>> pending;
  int gets = 0;
  @override
  Future<Result<ListenerProfile>> getMyProfile() async => ++gets == 1
      ? Result.success(_ownerObject('LISTENER') as ListenerProfile)
      : _ownerResult(pending);
}

class _OwnerStudio extends Fake implements StudioProfileRepository {
  _OwnerStudio(this.pending);
  final Completer<Result<Object>> pending;
  int gets = 0;
  @override
  Future<Result<StudioProfile>> getMyProfile() async => ++gets == 1
      ? Result.success(_ownerObject('STUDIO') as StudioProfile)
      : _ownerResult(pending);
}

class _OwnerVenue extends _Venues {
  _OwnerVenue(this.pending);
  final Completer<Result<Object>> pending;
  @override
  Future<Result<VenueOwnerProfile>> getMyVenueProfileDetail({
    String? venueId,
  }) => _ownerResult(pending);
  @override
  Future<Result<VenuePublicProfile>> getPublicVenueProfile({
    String? venueId,
  }) async => Result.success(
    VenuePublicProfile(
      venueProfileId: bandId,
      venueId: profileId,
      ownerUserId: recipient,
      venueName: 'Owner venue',
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
      cityName: null,
      districtName: null,
      neighborhoodName: null,
      activeMusicians: [],
      activeBands: [],
      weeklyEvents: [],
    ),
  );
}

class _OwnerLocations extends Fake implements LocationRepository {}

class _OwnerDirectory extends Fake implements VenueDirectoryRepository {}

class _OwnerSearch extends Fake implements ProfileSearchRepository {}
