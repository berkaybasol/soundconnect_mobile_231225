import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/listener_profile_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/models/venue_profile_save_request.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/venue_profile_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/listener_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/listener_visibility_mode.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/listener_profile_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/cubit/listener_profile_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/cubit/listener_profile_state.dart';

import 'support/event_audience_fakes.dart';
import 'support/recording_api_client.dart';

void main() {
  test('listener logout clears loaded private profile immediately', () async {
    final sessions = AudienceTestSessions(
      audienceSession(user: 'listener-user'),
    );
    final cubit = ListenerProfileCubit(
      _ListenerRepository(),
      sessions: sessions,
    );
    addTearDown(cubit.close);
    await cubit.loadMyProfile();
    expect(cubit.state.profile, same(_listener));
    sessions.replace(const AuthSession.guest());
    expect(cubit.state.status, ListenerProfileStatus.idle);
    expect(cubit.state.profile, isNull);
  });

  test(
    'queued listener edit cannot adopt another account or restore old cache',
    () async {
      final sessions = AudienceTestSessions(
        audienceSession(user: 'listener-user'),
      );
      final pending = Completer<Result<ListenerProfile>>();
      final started = Completer<void>();
      final repository = _ListenerRepository()
        ..onUpdate = () {
          started.complete();
          return pending.future;
        };
      final cubit = ListenerProfileCubit(repository, sessions: sessions);
      addTearDown(cubit.close);
      await cubit.loadMyProfile();
      final first = cubit.updateVisibility(ListenerVisibilityMode.ghost);
      await started.future;
      final queued = cubit.updateAvatar('another-photo');
      sessions.replace(audienceSession(user: 'other-listener'));
      pending.complete(const Result.success(_listener));
      await Future.wait([first, queued]);
      expect(repository.visibilityWrites, 1);
      expect(repository.avatarWrites, 0);
      expect(cubit.state.profile, isNull);
      expect(cubit.state.status, ListenerProfileStatus.idle);
    },
  );

  test('listener request after logout is rejected before transport', () async {
    final api = RecordingApiClient(
      (_) => throw StateError('must not dispatch'),
    );
    final repository = ListenerProfileRepositoryImpl(
      api,
      sessionKeyProvider: () => null,
    );
    final result = await repository.updateVisibility(
      const ListenerVisibilityUpdateRequest(
        visibilityMode: ListenerVisibilityMode.ghost,
        expectedVersion: 0,
      ),
    );
    expect(result.error?.code, 'listener_profile_session_changed');
    expect(api.requests, isEmpty);
  });

  test(
    'listener writes carry the initiating account to the transport fence',
    () async {
      final api = RecordingApiClient((_) => _listenerJson);
      final repository = ListenerProfileRepositoryImpl(
        api,
        sessionKeyProvider: () => 'listener-user',
      );
      final result = await repository.updateAvatar(
        const ListenerAvatarUpdateRequest(
          profilePictureMediaId: null,
          expectedVersion: 0,
        ),
      );
      expect(result.isSuccess, isTrue);
      expect(
        api.lastRequest.requestContext?.expectedSessionKey,
        'listener-user',
      );
      expect(api.lastRequest.body, {
        'profilePictureMediaId': null,
        'expectedVersion': 0,
      });
    },
  );

  test('late listener response from another session is discarded', () async {
    String? user = 'listener-user';
    final pending = Completer<Object?>();
    final api = RecordingApiClient((_) => pending.future);
    final repository = ListenerProfileRepositoryImpl(
      api,
      sessionKeyProvider: () => user,
    );
    final load = repository.getMyProfile();
    user = 'other-listener';
    pending.complete(_listenerJson);
    expect((await load).error?.code, 'listener_profile_session_changed');
  });

  test(
    'venue update cannot resolve a venue under one account and write under another',
    () async {
      String? user = 'owner';
      final pending = Completer<Object?>();
      final api = RecordingApiClient((_) => pending.future);
      final repository = VenueProfileRepositoryImpl(
        api,
        sessionKeyProvider: () => user,
      );
      final save = repository.updateMyVenueProfileDetail(
        const VenueProfileSaveRequest(bio: 'edit'),
      );
      expect(api.requests.length, 1);
      expect(api.lastRequest.requestContext?.expectedSessionKey, 'owner');
      user = 'other-owner';
      pending.complete([
        {'id': 'profile', 'venueId': 'venue', 'venueName': 'Venue'},
      ]);
      expect((await save).error?.code, 'venue_profile_session_changed');
      expect(api.requests.length, 1);
    },
  );

  test(
    'venue lookup preserves network errors instead of claiming there is no venue',
    () async {
      const error = AppError(code: 'network', message: 'Network unavailable');
      final api = RecordingApiClient((_) => throw ApiException(error));
      final repository = VenueProfileRepositoryImpl(api);
      final result = await repository.getMyVenueProfileDetail();
      expect(result.error, same(error));
    },
  );
}

const _listener = ListenerProfile(
  id: 'listener-profile',
  userId: 'listener-user',
  username: 'listener',
  bio: null,
  profilePictureUrl: null,
  followerCount: 0,
  followingCount: 0,
);

const _listenerJson = <String, Object?>{
  'id': 'listener-profile',
  'userId': 'listener-user',
  'username': 'listener',
  'bio': null,
  'profilePictureUrl': null,
  'followerCount': 0,
  'followingCount': 0,
  'visibilityMode': 'STANDARD',
  'version': 0,
  'visibilityChoiceCompleted': true,
  'profileContentVisible': true,
  'profileContentEditable': true,
  'avatarEditable': true,
  'canReceiveFollowers': true,
  'playlists': <Object?>[],
};

class _ListenerRepository extends ListenerProfileRepository {
  Future<Result<ListenerProfile>> Function()? onUpdate;
  int visibilityWrites = 0;
  int avatarWrites = 0;

  @override
  Future<Result<ListenerProfile>> getMyProfile() async =>
      const Result.success(_listener);

  @override
  Future<Result<ListenerProfile>> updateMyProfile(
    ListenerProfileSaveRequest request,
  ) async => const Result.success(_listener);

  @override
  Future<Result<ListenerProfile>> updateVisibility(
    ListenerVisibilityUpdateRequest request,
  ) async {
    visibilityWrites++;
    return onUpdate?.call() ?? const Result.success(_listener);
  }

  @override
  Future<Result<ListenerProfile>> updateAvatar(
    ListenerAvatarUpdateRequest request,
  ) async {
    avatarWrites++;
    return const Result.success(_listener);
  }
}
