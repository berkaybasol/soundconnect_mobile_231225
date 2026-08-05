import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/studio_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/studio_profile_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/cubit/studio_profile_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/cubit/studio_profile_state.dart';

void main() {
  test(
    'stale update refreshes the baseline without automatically retrying',
    () async {
      final repository = _StudioProfileRepositoryFake(
        getResults: [
          const Result.success(_profileV1),
          const Result.success(_profileV2),
        ],
        updateResults: [
          const Result.failure(
            AppError(code: '9804', message: 'Studio resource changed'),
          ),
          const Result.success(_profileV3),
        ],
      );
      final cubit = StudioProfileCubit(repository);
      addTearDown(cubit.close);

      await cubit.loadMyProfile();
      await cubit.updateMyProfile(
        const StudioProfileSaveRequest(description: 'Taslak açıklama'),
      );

      expect(repository.updateRequests, hasLength(1));
      expect(repository.updateRequests.single.version, 1);
      expect(repository.getCalls, 2);
      expect(cubit.state.status, StudioProfileStatus.failure);
      expect(cubit.state.profile?.version, 2);
      expect(cubit.state.error?.code, '9804');
      expect(cubit.state.error?.message, contains('Güncel verileri aldık'));

      await cubit.updateMyProfile(
        const StudioProfileSaveRequest(description: 'Taslak açıklama'),
      );

      expect(repository.updateRequests, hasLength(2));
      expect(repository.updateRequests.last.version, 2);
      expect(cubit.state.status, StudioProfileStatus.success);
      expect(cubit.state.profile?.version, 3);
    },
  );

  test(
    'concurrent updates run FIFO and rebase the queued request version',
    () async {
      final repository = _ControlledStudioProfileRepository();
      final cubit = StudioProfileCubit(repository);
      addTearDown(cubit.close);

      await cubit.loadMyProfile();
      final first = cubit.updateMyProfile(
        const StudioProfileSaveRequest(
          description: 'First local edit',
          version: 1,
        ),
      );
      final second = cubit.updateMyProfile(
        const StudioProfileSaveRequest(
          website: 'https://studio.example',
          version: 1,
        ),
      );

      await Future<void>.delayed(Duration.zero);
      expect(repository.updateRequests, hasLength(1));
      expect(repository.updateRequests.single.version, 1);

      repository.firstUpdate.complete(const Result.success(_profileV2));
      await first;
      await Future<void>.delayed(Duration.zero);

      expect(repository.updateRequests, hasLength(2));
      expect(repository.updateRequests.last.website, 'https://studio.example');
      expect(repository.updateRequests.last.version, 2);

      repository.secondUpdate.complete(const Result.success(_profileV3));
      await second;

      expect(cubit.state.status, StudioProfileStatus.success);
      expect(cubit.state.profile?.version, 3);
    },
  );
}

class _ControlledStudioProfileRepository implements StudioProfileRepository {
  final firstUpdate = Completer<Result<StudioProfile>>();
  final secondUpdate = Completer<Result<StudioProfile>>();
  final List<StudioProfileSaveRequest> updateRequests = [];

  @override
  Future<Result<StudioProfile>> getMyProfile() async =>
      const Result.success(_profileV1);

  @override
  Future<Result<StudioProfile>> getPublicProfile(String profileId) async =>
      const Result.success(_profileV1);

  @override
  Future<Result<StudioProfile>> updateMyProfile(
    StudioProfileSaveRequest request,
  ) {
    updateRequests.add(request);
    return updateRequests.length == 1
        ? firstUpdate.future
        : secondUpdate.future;
  }
}

class _StudioProfileRepositoryFake implements StudioProfileRepository {
  _StudioProfileRepositoryFake({
    required List<Result<StudioProfile>> getResults,
    required List<Result<StudioProfile>> updateResults,
  }) : _getResults = List.of(getResults),
       _updateResults = List.of(updateResults);

  final List<Result<StudioProfile>> _getResults;
  final List<Result<StudioProfile>> _updateResults;
  final List<StudioProfileSaveRequest> updateRequests = [];
  int getCalls = 0;

  @override
  Future<Result<StudioProfile>> getMyProfile() async {
    getCalls++;
    return _getResults.removeAt(0);
  }

  @override
  Future<Result<StudioProfile>> getPublicProfile(String profileId) async =>
      const Result.success(_profileV1);

  @override
  Future<Result<StudioProfile>> updateMyProfile(
    StudioProfileSaveRequest request,
  ) async {
    updateRequests.add(request);
    return _updateResults.removeAt(0);
  }
}

const _profileV1 = StudioProfile(
  id: 'studio-1',
  userId: 'user-1',
  name: 'Studio',
  description: 'İlk açıklama',
  profilePictureMediaId: null,
  profilePictureUrl: null,
  address: null,
  phone: null,
  website: null,
  facilities: [],
  instagramUrl: null,
  youtubeUrl: null,
  timeZone: 'Europe/Istanbul',
  version: 1,
  spotifyTrackIds: [],
  spotifyTracks: [],
  activeRoomCount: 1,
  backlineUnitCount: 0,
);

const _profileV2 = StudioProfile(
  id: 'studio-1',
  userId: 'user-1',
  name: 'Studio',
  description: 'Başka oturumdaki açıklama',
  profilePictureMediaId: null,
  profilePictureUrl: null,
  address: null,
  phone: null,
  website: null,
  facilities: [],
  instagramUrl: null,
  youtubeUrl: null,
  timeZone: 'Europe/Istanbul',
  version: 2,
  spotifyTrackIds: [],
  spotifyTracks: [],
  activeRoomCount: 1,
  backlineUnitCount: 0,
);

const _profileV3 = StudioProfile(
  id: 'studio-1',
  userId: 'user-1',
  name: 'Studio',
  description: 'Taslak açıklama',
  profilePictureMediaId: null,
  profilePictureUrl: null,
  address: null,
  phone: null,
  website: null,
  facilities: [],
  instagramUrl: null,
  youtubeUrl: null,
  timeZone: 'Europe/Istanbul',
  version: 3,
  spotifyTrackIds: [],
  spotifyTracks: [],
  activeRoomCount: 1,
  backlineUnitCount: 0,
);
