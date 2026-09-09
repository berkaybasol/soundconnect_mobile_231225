import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
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

import 'support/event_audience_fakes.dart';

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
    test('logout immediately removes cached personal profile', () async {
      final sessions = AudienceTestSessions(
        audienceSession(user: 'musician-user-1', role: 'MUSICIAN'),
      );
      final cubit = MusicianProfileCubit(
        _MusicianRepositoryFake(),
        sessions: sessions,
      );
      addTearDown(cubit.close);
      await cubit.loadMyProfile();
      expect(cubit.state.profile, same(_musician));
      sessions.replace(const AuthSession.guest());
      expect(cubit.state.profile, isNull);
      expect(cubit.state.status, MusicianProfileStatus.idle);
    });
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
    test('logout immediately removes cached private venue details', () async {
      final sessions = AudienceTestSessions(
        audienceSession(user: 'owner-1', role: 'VENUE'),
      );
      final cubit = VenueProfileCubit(
        _VenueRepositoryFake(),
        sessions: sessions,
      );
      addTearDown(cubit.close);
      await cubit.loadOwner(venueId: 'venue-1');
      expect(cubit.state.ownerProfile, same(_ownerVenue));
      sessions.replace(const AuthSession.guest());
      expect(cubit.state.ownerProfile, isNull);
      expect(cubit.state.status, VenueProfileStatus.idle);
    });
    test(
      'owner load forwards optional venue id and selects owner view',
      () async {
        final repository = _VenueRepositoryFake();
        final cubit = VenueProfileCubit(repository);
        addTearDown(cubit.close);

        await cubit.loadOwner(venueId: 'venue-1');

        expect(repository.lastOwnerVenueId, 'venue-1');
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

      await cubit.updateOwnerProfile(request, venueId: 'venue-1');

      expect(repository.lastUpdateRequest, same(request));
      expect(repository.lastUpdateVenueId, 'venue-1');
      expect(cubit.state.status, VenueProfileStatus.success);
      expect(cubit.state.view, VenueProfileView.owner);
      expect(cubit.state.ownerProfile, same(_ownerVenue));
    });

    test('late owner response cannot replace a newer public view', () async {
      final pending = Completer<Result<VenueOwnerProfile>>();
      final repository = _VenueRepositoryFake()
        ..ownerLoader = () => pending.future;
      final cubit = VenueProfileCubit(repository);
      addTearDown(cubit.close);
      final owner = cubit.loadOwner(venueId: 'venue-1');
      await cubit.loadPublic(venueId: 'venue-1');
      pending.complete(const Result.success(_ownerVenue));
      await owner;
      expect(cubit.state.view, VenueProfileView.public);
      expect(cubit.state.publicProfile, same(_publicVenue));
      expect(cubit.state.ownerProfile, isNull);
    });

    test(
      'another venue clears cached data and rejects mismatched responses',
      () async {
        final cubit = VenueProfileCubit(_VenueRepositoryFake());
        addTearDown(cubit.close);
        await cubit.loadOwner(venueId: 'venue-1');
        final load = cubit.loadOwner(venueId: 'venue-other');
        expect(cubit.state.ownerProfile, isNull);
        await load;
        expect(cubit.state.status, VenueProfileStatus.failure);
        expect(cubit.state.error?.code, 'venue_profile_identity');
      },
    );

    test('load after close and completion after close do not emit', () async {
      final pending = Completer<Result<VenuePublicProfile>>();
      final repository = _VenueRepositoryFake()
        ..publicLoader = () => pending.future;
      final cubit = VenueProfileCubit(repository);
      final load = cubit.loadPublic(venueId: 'venue-1');
      await cubit.close();
      pending.complete(const Result.success(_publicVenue));
      await load;
      await cubit.loadOwner(venueId: 'ignored');
      expect(repository.lastOwnerVenueId, isNull);
    });

    test(
      'unexpected repository error is recoverable and clears private cache',
      () async {
        final repository = _VenueRepositoryFake();
        final cubit = VenueProfileCubit(repository);
        addTearDown(cubit.close);
        await cubit.loadOwner(venueId: 'venue-1');
        repository.ownerLoader = () => Future.error(StateError('network'));
        await cubit.loadOwner(venueId: 'venue-1');
        expect(cubit.state.status, VenueProfileStatus.failure);
        expect(cubit.state.ownerProfile, isNull);
        repository.ownerLoader = null;
        await cubit.loadOwner(venueId: 'venue-1');
        expect(cubit.state.status, VenueProfileStatus.success);
      },
    );

    test(
      'duplicate save is rejected and refresh waits for the write',
      () async {
        final pending = Completer<Result<VenueOwnerProfile>>();
        final repository = _VenueRepositoryFake()
          ..updater = () => pending.future;
        final cubit = VenueProfileCubit(repository);
        addTearDown(cubit.close);
        const request = VenueProfileSaveRequest(bio: 'changed');
        final write = cubit.updateOwnerProfile(request, venueId: 'venue-1');
        final duplicate = await cubit.updateOwnerProfile(
          request,
          venueId: 'venue-1',
        );
        expect(duplicate.error?.code, 'venue_profile_busy');
        final refresh = cubit.loadOwner(venueId: 'venue-1');
        expect(repository.lastOwnerVenueId, isNull);
        pending.complete(const Result.success(_ownerVenue));
        expect((await write).isSuccess, isTrue);
        await refresh;
        expect(repository.updateCalls, 1);
        expect(repository.lastOwnerVenueId, 'venue-1');
        expect(cubit.state.status, VenueProfileStatus.success);
      },
    );

    test('failed save returns failure to its UI caller', () async {
      const failure = AppError(code: 'forbidden', message: 'Yetki yok');
      final repository = _VenueRepositoryFake()
        ..updater = () async => const Result.failure(failure);
      final cubit = VenueProfileCubit(repository);
      addTearDown(cubit.close);
      final result = await cubit.updateOwnerProfile(
        const VenueProfileSaveRequest(profilePicture: 'photo'),
        venueId: 'venue-1',
      );
      expect(result.isSuccess, isFalse);
      expect(result.error, same(failure));
      expect(cubit.state.status, VenueProfileStatus.failure);
    });

    test(
      'account switch discards late response and rejects stale editor',
      () async {
        await serviceLocator.reset();
        addTearDown(serviceLocator.reset);
        final sessions = AudienceTestSessions(
          audienceSession(user: 'owner-1', role: 'ROLE_VENUE'),
        );
        serviceLocator.registerSingleton<AuthSessionManager>(sessions);
        final pending = Completer<Result<VenueOwnerProfile>>();
        final repository = _VenueRepositoryFake()
          ..ownerLoader = () => pending.future;
        final cubit = VenueProfileCubit(repository);
        addTearDown(cubit.close);
        final load = cubit.loadOwner(venueId: 'venue-1');
        sessions.replace(
          audienceSession(user: 'other-owner', role: 'ROLE_VENUE'),
        );
        pending.complete(const Result.success(_ownerVenue));
        await load;
        expect(cubit.state.ownerProfile, isNull);
        final save = await cubit.updateOwnerProfile(
          const VenueProfileSaveRequest(bio: 'old account edit'),
          venueId: 'venue-1',
          expectedSessionKey: 'owner-1',
        );
        expect(save.error?.code, 'venue_profile_stale');
        expect(repository.updateCalls, 0);
      },
    );
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

class _ListenerRepositoryFake extends ListenerProfileRepository {
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
    MusicianProfileSaveRequest request, {
    String? expectedSessionKey,
  }) async {
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
  Future<Result<VenueOwnerProfile>> Function()? ownerLoader;
  Future<Result<VenuePublicProfile>> Function()? publicLoader;
  Future<Result<VenueOwnerProfile>> Function()? updater;
  int updateCalls = 0;

  @override
  Future<Result<List<VenueProfileSummary>>> getMyVenueProfiles() async =>
      const Result<List<VenueProfileSummary>>.success(<VenueProfileSummary>[]);

  @override
  Future<Result<VenueOwnerProfile>> getMyVenueProfileDetail({
    String? venueId,
  }) async {
    lastOwnerVenueId = venueId;
    return ownerLoader?.call() ?? ownerResult;
  }

  @override
  Future<Result<VenuePublicProfile>> getPublicVenueProfile({
    String? venueId,
  }) async {
    lastPublicVenueId = venueId;
    return publicLoader?.call() ?? publicResult;
  }

  @override
  Future<Result<VenueOwnerProfile>> updateMyVenueProfileDetail(
    VenueProfileSaveRequest request, {
    String? venueId,
  }) async {
    lastUpdateRequest = request;
    lastUpdateVenueId = venueId;
    updateCalls++;
    return updater?.call() ?? updateResult;
  }
}
