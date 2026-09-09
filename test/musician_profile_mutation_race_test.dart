import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/modules/artist_venue/domain/artist_venue_connection_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/artist_venue/presentation/cubit/artist_venue_connections_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/engagement_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/dm_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_badge_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/presentation/cubit/interaction_stats_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/follow/domain/follow_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/follow/presentation/cubit/follow_action_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/follow/presentation/cubit/follow_count_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/location_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/models/musician_profile_save_request.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/musician_profile_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/musician_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/musician_profile_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/profile_media_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/venue_directory_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/cubit/musician_profile_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/cubit/musician_profile_state.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/cubit/profile_media_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/musician_profile_screen.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/gradient_outline_button.dart';

void main() {
  late _Repository repository;
  late _Session session;
  late MusicianProfileCubit cubit;
  const request = MusicianProfileSaveRequest(description: 'New bio');

  setUp(() async {
    await serviceLocator.reset();
    repository = _Repository();
    session = _Session();
    serviceLocator.registerSingleton<AuthSessionManager>(session);
    cubit = MusicianProfileCubit(repository);
  });
  tearDown(() async {
    if (!cubit.isClosed) await cubit.close();
    await serviceLocator.reset();
  });

  test(
    'failure is returned to caller and preserves last confirmed profile',
    () async {
      await cubit.loadMyProfile();
      repository.updateResult = const Result.failure(
        AppError(code: 'offline', message: 'No connection'),
      );
      final result = await cubit.updateProfile(request);
      expect(result.isSuccess, isFalse);
      expect(cubit.state.status, MusicianProfileStatus.failure);
      expect(cubit.state.profile?.bio, isNull);
      expect(repository.expectedAccount, 'owner');
    },
  );

  test('thrown transport becomes retryable failure', () async {
    repository.throwUpdate = true;
    expect((await cubit.updateProfile(request)).isSuccess, isFalse);
    repository.throwUpdate = false;
    expect((await cubit.updateProfile(request)).isSuccess, isTrue);
    expect(repository.updates, 2);
  });

  test('duplicate pending mutations dispatch exactly once', () async {
    repository.pendingUpdate = Completer<Result<MusicianProfile>>();
    final first = cubit.updateProfile(request);
    final duplicate = await cubit.updateProfile(request);
    expect(duplicate.error?.code, 'musician_profile_busy');
    expect(repository.updates, 1);
    repository.pendingUpdate!.complete(
      Result.success(_profile(bio: 'New bio')),
    );
    expect((await first).isSuccess, isTrue);
  });

  test('older owner load cannot roll back a later successful save', () async {
    repository.pendingRead = Completer<Result<MusicianProfile>>();
    final oldLoad = cubit.loadMyProfile();
    repository.updateResult = Result.success(_profile(bio: 'New bio'));
    await cubit.updateProfile(request);
    repository.pendingRead!.complete(Result.success(_profile()));
    await oldLoad;
    expect(cubit.state.profile?.bio, 'New bio');
    expect(cubit.state.action, MusicianProfileAction.update);
  });

  test(
    'owner refresh waits for a pending save and reads committed fields',
    () async {
      await cubit.loadMyProfile();
      repository.pendingUpdate = Completer<Result<MusicianProfile>>();
      final save = cubit.updateProfile(request);
      final refresh = cubit.loadMyProfile();
      await Future<void>.delayed(Duration.zero);
      final readsBeforeCommit = repository.ownerReads;

      repository.ownerProfile = _profile(bio: 'New bio');
      repository.pendingUpdate!.complete(
        Result.success(repository.ownerProfile),
      );
      final saved = await save;
      await refresh;

      expect(saved.isSuccess, isTrue);
      expect(readsBeforeCommit, 1);
      expect(repository.ownerReads, 2);
      expect(cubit.state.profile?.bio, 'New bio');
      expect(cubit.state.action, MusicianProfileAction.load);
    },
  );

  test(
    'refresh after a failed write refetches without disguising the failure',
    () async {
      await cubit.loadMyProfile();
      repository.pendingUpdate = Completer<Result<MusicianProfile>>();
      final save = cubit.updateProfile(request);
      final refresh = cubit.loadMyProfile();
      await Future<void>.delayed(Duration.zero);
      expect(repository.ownerReads, 1);

      repository.pendingUpdate!.complete(
        const Result.failure(
          AppError(code: 'offline', message: 'No connection'),
        ),
      );
      expect((await save).error?.code, 'offline');
      await refresh;
      expect(repository.ownerReads, 2);
      expect(cubit.state.status, MusicianProfileStatus.success);
      expect(cubit.state.profile?.bio, isNull);
    },
  );

  test(
    'new public navigation supersedes an owner refresh waiting for a save',
    () async {
      await cubit.loadMyProfile();
      repository.pendingUpdate = Completer<Result<MusicianProfile>>();
      final save = cubit.updateProfile(request);
      final refresh = cubit.loadMyProfile();
      repository.publicProfile = _profile(id: 'public-profile', user: 'artist');
      await cubit.loadPublicProfile('public-profile');

      repository.pendingUpdate!.complete(
        Result.success(_profile(bio: 'New bio')),
      );
      expect((await save).isSuccess, isTrue);
      await refresh;
      expect(repository.ownerReads, 1);
      expect(cubit.state.profile?.id, 'public-profile');
      expect(cubit.state.profile?.userId, 'artist');
    },
  );

  for (final close in [false, true]) {
    test(
      'waiting owner refresh is revoked by ${close ? 'close' : 'account switch'}',
      () async {
        await cubit.loadMyProfile();
        repository.pendingUpdate = Completer<Result<MusicianProfile>>();
        final save = cubit.updateProfile(request);
        final refresh = cubit.loadMyProfile();
        if (close) {
          await cubit.close();
        } else {
          session.current = _auth('other');
          session.notifyListeners();
        }
        repository.pendingUpdate!.complete(
          Result.success(_profile(bio: 'New bio')),
        );
        expect((await save).isSuccess, isFalse);
        await refresh;
        expect(repository.ownerReads, 1);
        if (!close) expect(cubit.state.profile, isNull);
      },
    );
  }

  for (final isUpdate in [false, true]) {
    test(
      'late ${isUpdate ? 'save' : 'read'} after close does not emit',
      () async {
        final pending = Completer<Result<MusicianProfile>>();
        if (isUpdate) {
          repository.pendingUpdate = pending;
        } else {
          repository.pendingRead = pending;
        }
        final operation = isUpdate
            ? cubit.updateProfile(request)
            : cubit.loadMyProfile();
        await cubit.close();
        pending.complete(Result.success(_profile()));
        await operation;
      },
    );
  }

  test(
    'account switch after dispatch suppresses old result and does not claim success',
    () async {
      await cubit.loadMyProfile();
      repository.pendingUpdate = Completer<Result<MusicianProfile>>();
      final operation = cubit.updateProfile(request);
      session.current = _auth('other');
      repository.pendingUpdate!.complete(
        Result.success(_profile(bio: 'New bio')),
      );
      expect((await operation).isSuccess, isFalse);
      expect(cubit.state.profile?.bio, isNull);
    },
  );

  test(
    'old owner profile cannot mutate newly signed-in account even without explicit key',
    () async {
      await cubit.loadMyProfile();
      session.current = _auth('other');
      expect((await cubit.updateProfile(request)).isSuccess, isFalse);
      expect(repository.updates, 0);
    },
  );

  for (final invalid in [
    _profile(id: 'wrong-profile'),
    _profile(user: 'other'),
    _profile(id: ''),
  ]) {
    test(
      'save rejects mismatched response ${invalid.id}/${invalid.userId}',
      () async {
        await cubit.loadMyProfile();
        repository.updateResult = Result.success(invalid);
        expect(
          (await cubit.updateProfile(request)).error?.code,
          'musician_profile_identity',
        );
        expect(cubit.state.profile?.id, 'profile');
      },
    );
  }

  for (final invalid in <String, MusicianProfile>{
    'empty profile ID': _profile(id: ''),
    'blank profile ID': _profile(id: '   '),
    'empty user ID': _profile(user: ''),
    'blank user ID': _profile(user: '   '),
  }.entries) {
    test(
      'first owner read rejects ${invalid.key} and stays retryable',
      () async {
        repository.pendingRead = Completer<Result<MusicianProfile>>()
          ..complete(Result.success(invalid.value));
        await cubit.loadMyProfile();
        expect(cubit.state.status, MusicianProfileStatus.failure);
        expect(cubit.state.error?.code, 'musician_profile_identity');
        expect(cubit.state.profile, isNull);
        repository.pendingRead = null;
        await cubit.loadMyProfile();
        expect(cubit.state.status, MusicianProfileStatus.success);
        expect(cubit.state.profile?.id, 'profile');
      },
    );
  }

  test(
    'public profile request rejects mismatched id and clears previous target',
    () async {
      await cubit.loadMyProfile();
      await cubit.loadPublicProfile('unrelated');
      expect(cubit.state.status, MusicianProfileStatus.failure);
      expect(cubit.state.profile, isNull);
    },
  );

  test('repository sends originating account in fenced PUT', () async {
    final api = _Api();
    final result = await MusicianProfileRepositoryImpl(
      api,
    ).updateMyProfile(request, expectedSessionKey: 'owner');
    expect(result.isSuccess, isTrue);
    expect(api.method, ApiHttpMethod.put);
    expect(api.context?.expectedSessionKey, 'owner');
  });

  Future<void> openEditor(WidgetTester tester) async {
    serviceLocator
      ..registerFactory<MusicianProfileCubit>(() => cubit)
      ..registerFactory<ProfileMediaCubit>(() => _MediaCubit())
      ..registerFactory<FollowCountCubit>(() => _CountCubit())
      ..registerFactory<FollowActionCubit>(() => FollowActionCubit(_Follow()))
      ..registerFactory<ArtistVenueConnectionsCubit>(() => _ConnectionsCubit())
      ..registerFactory<InteractionStatsCubit>(
        () => InteractionStatsCubit(_Engagement()),
      )
      ..registerSingleton<ArtistVenueConnectionRepository>(_Connections())
      ..registerSingleton<LocationRepository>(_Locations())
      ..registerSingleton<VenueDirectoryRepository>(_Venues())
      ..registerSingleton<AudioHandler>(BaseAudioHandler());
    final badge = _BadgeCubit();
    serviceLocator.registerSingleton<DmBadgeCubit>(badge);
    addTearDown(badge.close);
    await tester.binding.setSurfaceSize(const Size(450, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.navy, home: const MusicianProfileScreen()),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Kendini birkaç cümleyle anlat'));
    await tester.tap(find.text('Kendini birkaç cümleyle anlat'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'My unsaved bio');
  }

  testWidgets('failed bio save keeps the draft open and never shows success', (
    tester,
  ) async {
    repository.updateResult = const Result.failure(
      AppError(code: 'offline', message: 'No connection'),
    );
    await openEditor(tester);
    await tester.tap(find.widgetWithText(GradientOutlineButton, 'Kaydet'));
    await tester.pumpAndSettle();
    expect(find.text('Açıklama kaydedilemedi'), findsOneWidget);
    expect(find.text('Açıklama güncellendi'), findsNothing);
    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.text('My unsaved bio'), findsOneWidget);
    ScaffoldMessenger.of(
      tester.element(find.byType(TextFormField)),
    ).removeCurrentSnackBar();
    repository.updateResult = Result.success(_profile(bio: 'My unsaved bio'));
    await tester.tap(find.widgetWithText(GradientOutlineButton, 'Kaydet'));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('Açıklama güncellendi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('old open bio editor cannot save after account change', (
    tester,
  ) async {
    await openEditor(tester);
    session.current = _auth('other');
    await tester.tap(find.widgetWithText(GradientOutlineButton, 'Kaydet'));
    await tester.pumpAndSettle();
    expect(repository.updates, 0);
    expect(find.text('Açıklama güncellendi'), findsNothing);
  });
}

MusicianProfile _profile({
  String id = 'profile',
  String user = 'owner',
  String? bio,
}) => MusicianProfile(
  id: id,
  userId: user,
  username: 'aedrum',
  stageName: null,
  bio: bio,
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
AuthSession _auth(String user) => AuthSession.authenticated(
  token: 'token-$user',
  userId: user,
  username: user,
  roles: const ['ROLE_MUSICIAN'],
  permissions: const [],
  accountStatus: 'ACTIVE',
  expiresAt: DateTime(2099),
  isAdmin: false,
);

class _Session extends Fake with ChangeNotifier implements AuthSessionManager {
  AuthSession current = _auth('owner');
  @override
  AuthSession get session => current;
}

class _Repository extends Fake implements MusicianProfileRepository {
  int updates = 0;
  int ownerReads = 0;
  MusicianProfile ownerProfile = _profile();
  MusicianProfile publicProfile = _profile();
  bool throwUpdate = false;
  String? expectedAccount;
  Result<MusicianProfile> updateResult = Result.success(_profile());
  Completer<Result<MusicianProfile>>? pendingRead;
  Completer<Result<MusicianProfile>>? pendingUpdate;
  @override
  Future<Result<MusicianProfile>> getMyProfile() async {
    ownerReads++;
    return pendingRead?.future ?? Result.success(ownerProfile);
  }

  @override
  Future<Result<MusicianProfile>> getPublicProfileByProfileId(
    String id,
  ) async => Result.success(publicProfile);
  @override
  Future<Result<MusicianProfile>> updateMyProfile(
    MusicianProfileSaveRequest request, {
    String? expectedSessionKey,
  }) async {
    updates++;
    expectedAccount = expectedSessionKey;
    if (throwUpdate) throw StateError('network');
    return pendingUpdate?.future ?? updateResult;
  }
}

class _Api extends Fake implements ApiClient {
  ApiHttpMethod? method;
  ApiRequestContext? context;
  @override
  Future<T> request<T>(
    ApiHttpMethod method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    T Function(Object?)? decoder,
    ApiRequestContext? requestContext,
  }) async {
    this.method = method;
    context = requestContext;
    return decoder!({'id': 'profile', 'userId': 'owner'});
  }
}

class _Media extends Fake implements ProfileMediaRepository {}

class _MediaCubit extends ProfileMediaCubit {
  _MediaCubit() : super(_Media());
  @override
  Future<void> loadMedia({
    required String profileType,
    required String profileId,
  }) async {}
}

class _Follow extends Fake implements FollowRepository {}

class _CountCubit extends FollowCountCubit {
  _CountCubit() : super(_Follow());
  @override
  Future<void> loadCounts(String userId) async {}
}

class _Connections extends Fake implements ArtistVenueConnectionRepository {}

class _ConnectionsCubit extends ArtistVenueConnectionsCubit {
  _ConnectionsCubit() : super(_Connections());
  @override
  Future<void> loadAcceptedVenues(String musicianProfileId) async {}
}

class _Engagement extends Fake implements EngagementRepository {}

class _Locations extends Fake implements LocationRepository {}

class _Venues extends Fake implements VenueDirectoryRepository {}

class _Dm extends Fake implements DmRepository {}

class _Tokens extends Fake implements TokenStore {}

class _BadgeCubit extends DmBadgeCubit {
  _BadgeCubit() : super(_Dm(), _Tokens());
  @override
  Future<void> ensureStarted() async {}
}
