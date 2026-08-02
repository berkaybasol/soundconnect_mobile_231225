import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/models/musician_profile_save_request.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/models/venue_profile_save_request.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/listener_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/musician_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/venue_owner_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/venue_profile_summary.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/venue_public_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/listener_profile_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/musician_profile_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/venue_profile_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/cubit/listener_profile_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/cubit/listener_profile_state.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/cubit/musician_profile_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/cubit/musician_profile_state.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/cubit/venue_profile_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/cubit/venue_profile_state.dart';

void main() {
  group('ListenerProfileCubit', () {
    test('replaces a typed failure with a later successful profile', () async {
      const failure = AppError(code: 'listener_failed', message: 'Unavailable');
      final repository = _ListenerRepositoryFake(
        const Result<ListenerProfile>.failure(failure),
      );
      final cubit = ListenerProfileCubit(repository);
      addTearDown(cubit.close);

      await cubit.loadMyProfile();
      expect(cubit.state.status, ListenerProfileStatus.failure);
      expect(cubit.state.error, same(failure));

      repository.result = const Result<ListenerProfile>.success(_listener);
      await cubit.loadMyProfile();
      expect(cubit.state.status, ListenerProfileStatus.success);
      expect(cubit.state.profile?.id, 'listener-profile-1');
      expect(cubit.state.error, isNull);
      expect(repository.calls, 2);
    });
  });

  group('MusicianProfileCubit', () {
    test('replaces a typed failure with a later signed-in profile', () async {
      const failure = AppError(code: 'musician_failed', message: 'Unavailable');
      final repository = _MusicianRepositoryFake(
        myResult: const Result<MusicianProfile>.failure(failure),
      );
      final cubit = MusicianProfileCubit(repository);
      addTearDown(cubit.close);

      await cubit.loadMyProfile();
      expect(cubit.state.status, MusicianProfileStatus.failure);
      expect(cubit.state.action, MusicianProfileAction.load);
      expect(cubit.state.error, same(failure));

      repository.myResult = const Result<MusicianProfile>.success(_musician);
      await cubit.loadMyProfile();
      expect(cubit.state.status, MusicianProfileStatus.success);
      expect(cubit.state.action, MusicianProfileAction.load);
      expect(cubit.state.profile?.id, 'musician-profile-1');
      expect(cubit.state.error, isNull);
      expect(repository.myCalls, 2);
    });

    test('forwards public id and keeps the load action on failure', () async {
      const failure = AppError(code: 'public_failed', message: 'Not found');
      final repository = _MusicianRepositoryFake(
        publicResult: const Result<MusicianProfile>.failure(failure),
      );
      final cubit = MusicianProfileCubit(repository);
      addTearDown(cubit.close);

      await cubit.loadPublicProfile('public-profile-9');

      expect(repository.lastPublicProfileId, 'public-profile-9');
      expect(cubit.state.status, MusicianProfileStatus.failure);
      expect(cubit.state.action, MusicianProfileAction.load);
      expect(cubit.state.error, same(failure));
    });

    test(
      'forwards update request and publishes the returned profile',
      () async {
        final repository = _MusicianRepositoryFake();
        final cubit = MusicianProfileCubit(repository);
        addTearDown(cubit.close);
        const request = MusicianProfileSaveRequest(
          stageName: 'Ada',
          instrumentIds: <String>['guitar'],
        );

        await cubit.updateProfile(request);

        expect(repository.lastUpdateRequest, same(request));
        expect(cubit.state.status, MusicianProfileStatus.success);
        expect(cubit.state.action, MusicianProfileAction.update);
        expect(cubit.state.profile, same(_musician));
      },
    );
  });

  group('VenueProfileCubit', () {
    test(
      'owner load forwards optional venue id and selects owner view',
      () async {
        final repository = _VenueRepositoryFake();
        final cubit = VenueProfileCubit(repository);
        addTearDown(cubit.close);

        await cubit.loadOwner(venueId: 'venue-9');

        expect(repository.lastOwnerVenueId, 'venue-9');
        expect(cubit.state.status, VenueProfileStatus.success);
        expect(cubit.state.view, VenueProfileView.owner);
        expect(cubit.state.ownerProfile, same(_ownerVenue));
        expect(cubit.state.publicProfile, isNull);
      },
    );

    test('public load selects public view and exposes typed failure', () async {
      const failure = AppError(code: 'venue_public_failed', message: 'Hidden');
      final repository = _VenueRepositoryFake(
        publicResult: const Result<VenuePublicProfile>.failure(failure),
      );
      final cubit = VenueProfileCubit(repository);
      addTearDown(cubit.close);

      await cubit.loadPublic(venueId: 'venue-10');

      expect(repository.lastPublicVenueId, 'venue-10');
      expect(cubit.state.status, VenueProfileStatus.failure);
      expect(cubit.state.view, VenueProfileView.public);
      expect(cubit.state.error, same(failure));
    });

    test('owner update forwards request and venue id', () async {
      final repository = _VenueRepositoryFake();
      final cubit = VenueProfileCubit(repository);
      addTearDown(cubit.close);
      const request = VenueProfileSaveRequest(bio: 'Live music venue');

      await cubit.updateOwnerProfile(request, venueId: 'venue-11');

      expect(repository.lastUpdateRequest, same(request));
      expect(repository.lastUpdateVenueId, 'venue-11');
      expect(cubit.state.status, VenueProfileStatus.success);
      expect(cubit.state.view, VenueProfileView.owner);
      expect(cubit.state.ownerProfile, same(_ownerVenue));
    });
  });
}

const _listener = ListenerProfile(
  id: 'listener-profile-1',
  userId: 'listener-user-1',
  username: 'listener',
  bio: null,
  profilePictureUrl: null,
  followerCount: 2,
  followingCount: 3,
);

const _musician = MusicianProfile(
  id: 'musician-profile-1',
  userId: 'musician-user-1',
  username: 'musician',
  stageName: 'Ada',
  bio: null,
  profilePicture: null,
  instagramUrl: null,
  youtubeUrl: null,
  soundcloudUrl: null,
  spotifyEmbedUrl: null,
  spotifyArtistId: null,
  spotifyTrackIds: <String>[],
  spotifyTracks: [],
  instruments: <String>['Guitar'],
  activeVenues: <String>[],
  bands: <String>[],
);

const _ownerVenue = VenueOwnerProfile(
  venueProfileId: 'venue-profile-1',
  venueId: 'venue-1',
  ownerUserId: 'owner-1',
  venueName: 'Sound Hall',
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
  status: 'ACTIVE',
  activeMusicians: [],
  activeBands: [],
  weeklyEvents: [],
);

const _publicVenue = VenuePublicProfile(
  venueProfileId: 'venue-profile-1',
  venueId: 'venue-1',
  ownerUserId: 'owner-1',
  venueName: 'Sound Hall',
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
);

class _ListenerRepositoryFake implements ListenerProfileRepository {
  _ListenerRepositoryFake(this.result);

  Result<ListenerProfile> result;
  int calls = 0;

  @override
  Future<Result<ListenerProfile>> getMyProfile() async {
    calls += 1;
    return result;
  }

  @override
  Future<Result<ListenerProfile>> updateMyProfile(
    ListenerProfileSaveRequest request,
  ) async => result;
}

class _MusicianRepositoryFake implements MusicianProfileRepository {
  _MusicianRepositoryFake({
    this.myResult = const Result<MusicianProfile>.success(_musician),
    this.publicResult = const Result<MusicianProfile>.success(_musician),
  });

  Result<MusicianProfile> myResult;
  Result<MusicianProfile> publicResult;
  final Result<MusicianProfile> updateResult =
      const Result<MusicianProfile>.success(_musician);
  int myCalls = 0;
  String? lastPublicProfileId;
  MusicianProfileSaveRequest? lastUpdateRequest;

  @override
  Future<Result<MusicianProfile>> getMyProfile() async {
    myCalls += 1;
    return myResult;
  }

  @override
  Future<Result<MusicianProfile>> getPublicProfileByProfileId(
    String profileId,
  ) async {
    lastPublicProfileId = profileId;
    return publicResult;
  }

  @override
  Future<Result<MusicianProfile>> updateMyProfile(
    MusicianProfileSaveRequest request,
  ) async {
    lastUpdateRequest = request;
    return updateResult;
  }
}

class _VenueRepositoryFake implements VenueProfileRepository {
  _VenueRepositoryFake({
    this.publicResult = const Result<VenuePublicProfile>.success(_publicVenue),
  });

  final Result<VenueOwnerProfile> ownerResult =
      const Result<VenueOwnerProfile>.success(_ownerVenue);
  Result<VenuePublicProfile> publicResult;
  final Result<VenueOwnerProfile> updateResult =
      const Result<VenueOwnerProfile>.success(_ownerVenue);
  String? lastOwnerVenueId;
  String? lastPublicVenueId;
  String? lastUpdateVenueId;
  VenueProfileSaveRequest? lastUpdateRequest;

  @override
  Future<Result<List<VenueProfileSummary>>> getMyVenueProfiles() async =>
      const Result<List<VenueProfileSummary>>.success(<VenueProfileSummary>[]);

  @override
  Future<Result<VenueOwnerProfile>> getMyVenueProfileDetail({
    String? venueId,
  }) async {
    lastOwnerVenueId = venueId;
    return ownerResult;
  }

  @override
  Future<Result<VenuePublicProfile>> getPublicVenueProfile({
    String? venueId,
  }) async {
    lastPublicVenueId = venueId;
    return publicResult;
  }

  @override
  Future<Result<VenueOwnerProfile>> updateMyVenueProfileDetail(
    VenueProfileSaveRequest request, {
    String? venueId,
  }) async {
    lastUpdateRequest = request;
    lastUpdateVenueId = venueId;
    return updateResult;
  }
}
