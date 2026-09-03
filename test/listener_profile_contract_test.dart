import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/listener_profile_endpoints.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/listener_profile_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/models/listener_profile_model.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/models/listener_public_profile_model.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/listener_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/listener_public_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/listener_visibility_context.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/listener_visibility_mode.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/listener_profile_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/cubit/listener_profile_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/cubit/listener_profile_state.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/listener_visibility_error_message.dart';

import 'support/recording_api_client.dart';

void main() {
  group('ListenerVisibilityMode', () {
    test('uses an explicit and strict wire contract', () {
      expect(
        ListenerVisibilityMode.fromWire(' ghost '),
        ListenerVisibilityMode.ghost,
      );
      expect(ListenerVisibilityMode.ghost.isGhost, isTrue);
      expect(ListenerVisibilityMode.standard.wireValue, 'STANDARD');
      expect(
        () => ListenerVisibilityMode.fromWire(null),
        throwsFormatException,
      );
      expect(
        ListenerVisibilityMode.fromWire(null, allowMissingStandard: true),
        ListenerVisibilityMode.standard,
      );
      expect(
        () => ListenerVisibilityMode.fromWire('PRIVATE'),
        throwsFormatException,
      );
    });

    test(
      'context parser permits missing legacy values but fails unknown closed',
      () {
        expect(
          parseContextualListenerVisibilityMode(null),
          ListenerVisibilityMode.standard,
        );
        expect(
          parseContextualListenerVisibilityMode('FUTURE_MODE'),
          ListenerVisibilityMode.ghost,
        );
        expect(
          () => parseContextualListenerVisibilityMode(
            'FUTURE_MODE',
            rejectUnknown: true,
          ),
          throwsFormatException,
        );
      },
    );
  });

  group('listener visibility rate-limit message', () {
    test('preserves backend retry guidance for error code 1306', () {
      const backendMessage =
          'Görünürlük ayarını çok sık değiştirdin. Lütfen biraz sonra tekrar dene.';

      expect(
        listenerVisibilityErrorMessage(
          const AppError(code: '1306', message: backendMessage),
        ),
        backendMessage,
      );
    });

    test('replaces a technical HTTP 429 message with a localized fallback', () {
      expect(
        listenerVisibilityErrorMessage(
          const AppError(
            code: '429',
            message:
                'DioException [bad response]: status code of 429 was returned',
          ),
        ),
        'Görünürlük ayarını çok sık değiştirdin. Lütfen kısa bir süre sonra tekrar dene.',
      );
    });
  });

  group('listener profile wire models', () {
    test('an unchosen domain profile defaults to restricted capabilities', () {
      const profile = ListenerProfile(
        id: 'profile-1',
        userId: 'user-1',
        username: 'listener',
        bio: null,
        profilePictureUrl: null,
        followerCount: null,
        followingCount: null,
        visibilityChoiceCompleted: false,
      );

      expect(profile.profileContentVisible, isFalse);
      expect(profile.profileContentEditable, isFalse);
      expect(profile.canReceiveFollowers, isFalse);
      expect(profile.avatarEditable, isTrue);
    });

    test('parses a ghost owner without inventing hidden content', () {
      final profile = ListenerProfileModel.fromJson(
        _ownerJson(mode: ListenerVisibilityMode.ghost, version: 7),
      );

      expect(profile.isGhost, isTrue);
      expect(profile.bio, isNull);
      expect(profile.followerCount, isNull);
      expect(profile.followingCount, isNull);
      expect(profile.profilePictureMediaId, 'media-1');
      expect(profile.profileContentVisible, isFalse);
      expect(profile.profileContentEditable, isFalse);
      expect(profile.avatarEditable, isTrue);
      expect(profile.canReceiveFollowers, isFalse);
      expect(profile.version, 7);
      expect(
        profile.visibilityChangedAt,
        DateTime.parse('2026-09-03T01:02:03'),
      );
    });

    test('rejects a ghost response that leaks content or capabilities', () {
      final json = _ownerJson(mode: ListenerVisibilityMode.ghost, version: 7)
        ..['bio'] = 'must stay hidden';

      expect(() => ListenerProfileModel.fromJson(json), throwsFormatException);
    });

    test('treats an unchosen standard storage default as restricted', () {
      final json = _ownerJson(mode: ListenerVisibilityMode.standard, version: 0)
        ..['visibilityChoiceCompleted'] = false
        ..remove('bio')
        ..remove('followerCount')
        ..remove('followingCount')
        ..['profileContentVisible'] = false
        ..['profileContentEditable'] = false
        ..['canReceiveFollowers'] = false;

      final profile = ListenerProfileModel.fromJson(json);

      expect(profile.visibilityMode, ListenerVisibilityMode.standard);
      expect(profile.visibilityChoiceCompleted, isFalse);
      expect(profile.bio, isNull);
      expect(profile.profileContentVisible, isFalse);
      expect(profile.profileContentEditable, isFalse);
      expect(profile.canReceiveFollowers, isFalse);
      expect(profile.avatarEditable, isTrue);
    });

    test('rejects social capabilities before an explicit choice', () {
      final json = _ownerJson(mode: ListenerVisibilityMode.standard, version: 0)
        ..['visibilityChoiceCompleted'] = false;

      expect(() => ListenerProfileModel.fromJson(json), throwsFormatException);
    });

    test('parses standard and ghost public projections separately', () {
      final standard = ListenerPublicProfileModel.fromJson(
        _publicJson(mode: ListenerVisibilityMode.standard),
      );
      final ghost = ListenerPublicProfileModel.fromJson(
        _publicJson(mode: ListenerVisibilityMode.ghost),
      );

      expect(standard.restricted, isFalse);
      expect(standard.canFollow, isTrue);
      expect(standard.followerCount, 12);
      expect(ghost.isGhost, isTrue);
      expect(ghost.restricted, isTrue);
      expect(ghost.canFollow, isFalse);
      expect(ghost.canMessage, isTrue);
      expect(ghost.bio, isNull);
      expect(ghost.followerCount, isNull);
    });

    test('requires exact non-negative integer fields', () {
      final json = _ownerJson(mode: ListenerVisibilityMode.standard, version: 2)
        ..['followerCount'] = 12.8;

      expect(() => ListenerProfileModel.fromJson(json), throwsFormatException);
    });
  });

  group('ListenerProfileRepositoryImpl', () {
    test('uses public and owner endpoints with typed projections', () async {
      final api = RecordingApiClient((request) {
        if (request.path == ListenerProfileEndpoints.me) {
          return _ownerJson(mode: ListenerVisibilityMode.standard, version: 3);
        }
        if (request.path ==
            ListenerProfileEndpoints.publicDetail('profile/id')) {
          return _publicJson(mode: ListenerVisibilityMode.ghost);
        }
        throw StateError('Unexpected request: ${request.path}');
      });
      final repository = ListenerProfileRepositoryImpl(api);

      final owner = await repository.getMyProfile();
      final publicProfile = await repository.getPublicProfile('profile/id');

      expect(owner.data?.version, 3);
      expect(publicProfile.data?.isGhost, isTrue);
      expect(api.requests.first.path, ListenerProfileEndpoints.me);
      expect(
        api.requests.last.path,
        '/api/v1/public/listener-profiles/profile%2Fid',
      );
    });

    test(
      'PATCH visibility carries desired state and expected version',
      () async {
        final api = RecordingApiClient(
          (_) => _ownerJson(mode: ListenerVisibilityMode.ghost, version: 5),
        );
        final repository = ListenerProfileRepositoryImpl(api);

        final result = await repository.updateVisibility(
          const ListenerVisibilityUpdateRequest(
            visibilityMode: ListenerVisibilityMode.ghost,
            expectedVersion: 4,
          ),
        );

        expect(result.data?.isGhost, isTrue);
        expect(api.lastRequest.method, RecordedHttpMethod.patch);
        expect(api.lastRequest.path, ListenerProfileEndpoints.visibility);
        expect(api.lastRequest.body, <String, dynamic>{
          'visibilityMode': 'GHOST',
          'expectedVersion': 4,
        });
      },
    );

    test('PATCH visibility preserves a backend rate-limit error', () async {
      const backendMessage =
          'Görünürlük ayarını çok sık değiştirdin. Lütfen biraz sonra tekrar dene.';
      final api = RecordingApiClient(
        (_) => throw ApiException(
          const AppError(code: '1306', message: backendMessage),
        ),
      );
      final repository = ListenerProfileRepositoryImpl(api);

      final result = await repository.updateVisibility(
        const ListenerVisibilityUpdateRequest(
          visibilityMode: ListenerVisibilityMode.ghost,
          expectedVersion: 4,
        ),
      );

      expect(result.isSuccess, isFalse);
      expect(result.error?.code, '1306');
      expect(result.error?.message, backendMessage);
    });

    test('PATCH avatar preserves explicit null removal intent', () async {
      final api = RecordingApiClient(
        (_) => _ownerJson(mode: ListenerVisibilityMode.standard, version: 6)
          ..remove('profilePictureMediaId')
          ..remove('profilePictureUrl'),
      );
      final repository = ListenerProfileRepositoryImpl(api);

      final result = await repository.updateAvatar(
        const ListenerAvatarUpdateRequest(
          profilePictureMediaId: null,
          expectedVersion: 5,
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(api.lastRequest.method, RecordedHttpMethod.patch);
      expect(api.lastRequest.path, ListenerProfileEndpoints.avatar);
      expect(api.lastRequest.body, <String, dynamic>{
        'profilePictureMediaId': null,
        'expectedVersion': 5,
      });
    });

    test('does not dispatch invalid public id or stale version', () async {
      final api = RecordingApiClient((_) => throw StateError('not called'));
      final repository = ListenerProfileRepositoryImpl(api);

      final publicResult = await repository.getPublicProfile('   ');
      final visibilityResult = await repository.updateVisibility(
        const ListenerVisibilityUpdateRequest(
          visibilityMode: ListenerVisibilityMode.ghost,
          expectedVersion: -1,
        ),
      );
      final avatarResult = await repository.updateAvatar(
        const ListenerAvatarUpdateRequest(
          profilePictureMediaId: null,
          expectedVersion: -1,
        ),
      );

      expect(publicResult.error?.code, 'listener_profile_validation');
      expect(visibilityResult.error?.code, 'listener_profile_validation');
      expect(avatarResult.error?.code, 'listener_profile_validation');
      expect(api.requests, isEmpty);
    });
  });

  group('ListenerProfileCubit', () {
    test('loads a distinct public projection', () async {
      final repository = _ListenerRepositoryFake();
      final cubit = ListenerProfileCubit(repository);
      addTearDown(cubit.close);

      await cubit.loadPublicProfile('public-profile');

      expect(repository.lastPublicId, 'public-profile');
      expect(cubit.state.status, ListenerProfileStatus.success);
      expect(cubit.state.view, ListenerProfileView.public);
      expect(cubit.state.publicProfile?.isGhost, isTrue);
    });

    test(
      'serializes mutations and rebases visibility on latest version',
      () async {
        final repository = _ListenerRepositoryFake();
        final cubit = ListenerProfileCubit(repository);
        addTearDown(cubit.close);
        await cubit.loadMyProfile();

        final avatar = cubit.updateAvatar(null);
        final visibility = cubit.updateVisibility(ListenerVisibilityMode.ghost);
        await Future.wait(<Future<void>>[avatar, visibility]);

        expect(repository.calls, <String>['avatar', 'visibility']);
        expect(repository.lastAvatarMediaId, isNull);
        expect(repository.lastAvatarExpectedVersion, 3);
        expect(repository.lastVisibilityRequest?.expectedVersion, 4);
        expect(cubit.state.profile?.version, 5);
        expect(cubit.state.profile?.isGhost, isTrue);
        expect(cubit.state.action, ListenerProfileAction.updateVisibility);
      },
    );

    test('refreshes owner state after a visibility version conflict', () async {
      final repository = _ListenerRepositoryFake(conflictVisibility: true);
      final cubit = ListenerProfileCubit(repository);
      addTearDown(cubit.close);
      await cubit.loadMyProfile();

      await cubit.updateVisibility(ListenerVisibilityMode.ghost);

      expect(repository.ownerLoads, 2);
      expect(cubit.state.status, ListenerProfileStatus.failure);
      expect(cubit.state.profile?.version, 9);
      expect(cubit.state.error?.code, '1304');
    });
  });
}

Map<String, dynamic> _ownerJson({
  required ListenerVisibilityMode mode,
  required int version,
}) {
  final ghost = mode.isGhost;
  return <String, dynamic>{
    'id': 'profile-1',
    'userId': 'user-1',
    'username': 'berkaybasol',
    'visibilityMode': mode.wireValue,
    'version': version,
    'visibilityChangedAt': '2026-09-03T01:02:03',
    if (!ghost) 'bio': 'Gece müzikleri',
    'profilePictureMediaId': 'media-1',
    'profilePictureUrl': 'https://cdn.example/avatar.jpg',
    if (!ghost) 'followerCount': 12,
    if (!ghost) 'followingCount': 8,
    'profileContentVisible': !ghost,
    'profileContentEditable': !ghost,
    'avatarEditable': true,
    'canReceiveFollowers': !ghost,
    'visibilityChoiceCompleted': true,
  };
}

Map<String, dynamic> _publicJson({required ListenerVisibilityMode mode}) {
  final ghost = mode.isGhost;
  return <String, dynamic>{
    'id': 'profile-1',
    'userId': 'user-1',
    'username': 'berkaybasol',
    'visibilityMode': mode.wireValue,
    if (!ghost) 'bio': 'Gece müzikleri',
    'profilePictureMediaId': 'media-1',
    'profilePictureUrl': 'https://cdn.example/avatar.jpg',
    if (!ghost) 'followerCount': 12,
    if (!ghost) 'followingCount': 8,
    'restricted': ghost,
    'canFollow': !ghost,
    'canMessage': true,
  };
}

class _ListenerRepositoryFake implements ListenerProfileRepository {
  _ListenerRepositoryFake({this.conflictVisibility = false});

  final bool conflictVisibility;
  final List<String> calls = <String>[];
  int ownerLoads = 0;
  String? lastPublicId;
  String? lastAvatarMediaId;
  int? lastAvatarExpectedVersion;
  ListenerVisibilityUpdateRequest? lastVisibilityRequest;
  ListenerProfile current = _ownerProfile(version: 3);

  @override
  Future<Result<ListenerProfile>> getMyProfile() async {
    ownerLoads += 1;
    if (conflictVisibility && ownerLoads > 1) {
      current = _ownerProfile(version: 9);
    }
    return Result.success(current);
  }

  @override
  Future<Result<ListenerPublicProfile>> getPublicProfile(
    String profileId,
  ) async {
    lastPublicId = profileId;
    return const Result.success(_ghostPublicProfile);
  }

  @override
  Future<Result<ListenerProfile>> updateAvatar(
    ListenerAvatarUpdateRequest request,
  ) async {
    calls.add('avatar');
    lastAvatarMediaId = request.profilePictureMediaId;
    lastAvatarExpectedVersion = request.expectedVersion;
    await Future<void>.delayed(Duration.zero);
    current = _ownerProfile(version: current.version + 1);
    return Result.success(current);
  }

  @override
  Future<Result<ListenerProfile>> updateVisibility(
    ListenerVisibilityUpdateRequest request,
  ) async {
    calls.add('visibility');
    lastVisibilityRequest = request;
    if (conflictVisibility) {
      return const Result.failure(AppError(code: '1304', message: 'stale'));
    }
    current = _ownerProfile(
      version: current.version + 1,
      mode: request.visibilityMode,
    );
    return Result.success(current);
  }

  @override
  Future<Result<ListenerProfile>> updateMyProfile(
    ListenerProfileSaveRequest request,
  ) async => Result.success(current);
}

ListenerProfile _ownerProfile({
  required int version,
  ListenerVisibilityMode mode = ListenerVisibilityMode.standard,
}) {
  final ghost = mode.isGhost;
  return ListenerProfile(
    id: 'profile-1',
    userId: 'user-1',
    username: 'berkaybasol',
    bio: ghost ? null : 'Gece müzikleri',
    profilePictureMediaId: null,
    profilePictureUrl: null,
    followerCount: ghost ? null : 12,
    followingCount: ghost ? null : 8,
    visibilityMode: mode,
    version: version,
    visibilityChangedAt: DateTime(2026, 9, 3),
    profileContentVisible: !ghost,
    profileContentEditable: !ghost,
    avatarEditable: true,
    canReceiveFollowers: !ghost,
  );
}

const _ghostPublicProfile = ListenerPublicProfile(
  id: 'profile-1',
  userId: 'user-1',
  username: 'berkaybasol',
  visibilityMode: ListenerVisibilityMode.ghost,
  bio: null,
  profilePictureMediaId: null,
  profilePictureUrl: null,
  followerCount: null,
  followingCount: null,
  restricted: true,
  canFollow: false,
  canMessage: true,
);
