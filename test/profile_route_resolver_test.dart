import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/band_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/band_member_summary.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/band_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/listener_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/musician_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/studio_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/venue_public_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/listener_profile_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/musician_profile_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/studio_profile_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/venue_profile_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/navigation/profile_route_resolver.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/band_profile_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/profile_route_args.dart';

void main() {
  const resolver = ProfileRouteResolver();

  tearDown(() async => serviceLocator.reset());

  group('profile route argument normalization', () {
    for (final kind in ProfileRouteKind.values) {
      test('$kind accepts and trims string and typed identity', () {
        final fromString = ProfileRouteTarget.fromArguments(kind, ' target ');
        final fromTyped = ProfileRouteTarget.fromArguments(
          kind,
          kind == ProfileRouteKind.band
              ? BandProfileScreenArgs(bandId: ' target ')
              : const PublicProfileArgs(
                  profileId: ' target ',
                  viewerUserId: 'spoof',
                ),
        );
        expect(fromString.id, 'target');
        expect(fromTyped.id, 'target');
        expect(fromTyped.kind, kind);
      });

      test('$kind rejects missing and nonstring target values', () {
        final key = _argumentKey(kind);
        for (final args in <Object?>[
          null,
          42,
          '',
          '  ',
          <String, Object>{key: 42},
          <String, String>{'userId': 'not-a-profile-id'},
          const PublicProfileArgs(viewerUserId: 'not-a-profile-id'),
        ]) {
          expect(ProfileRouteTarget.fromArguments(kind, args).id, isEmpty);
        }
      });

      test(
        '$kind map uses its identity key, never supplied viewer identity',
        () {
          final target = ProfileRouteTarget.fromArguments(kind, {
            _argumentKey(kind): ' target ',
            'viewerUserId': 'spoof',
            'userId': 'spoof',
          });
          expect(target.id, 'target');
          final args = target.publicArguments;
          if (kind == ProfileRouteKind.venue) {
            expect(args, isA<VenuePublicProfileArgs>());
            expect((args as VenuePublicProfileArgs).venueId, 'target');
            expect(args.viewerUserId, isNull);
          } else if (kind == ProfileRouteKind.band) {
            expect(args, isA<BandProfileScreenArgs>());
            expect((args as BandProfileScreenArgs).bandId, 'target');
            expect(args.viewMode, BandProfileViewMode.public);
          } else {
            expect(args, isA<PublicProfileArgs>());
            expect((args as PublicProfileArgs).profileId, 'target');
            expect(args.viewerUserId, isNull);
          }
        },
      );
    }

    test('DM legacy venue argument becomes a venue ID, not profile ID', () {
      final target = ProfileRouteTarget.fromArguments(
        ProfileRouteKind.venue,
        const PublicProfileArgs(profileId: 'venue-id'),
      );
      final args = target.publicArguments as VenuePublicProfileArgs;
      expect(args.venueId, 'venue-id');
    });

    test('venue and band typed arguments preserve canonical ID', () {
      expect(
        ProfileRouteTarget.fromArguments(
          ProfileRouteKind.venue,
          const VenuePublicProfileArgs(venueId: ' venue '),
        ).id,
        'venue',
      );
      expect(
        ProfileRouteTarget.fromArguments(
          ProfileRouteKind.band,
          BandProfileScreenArgs(bandId: ' band '),
        ).id,
        'band',
      );
    });

    test('typed payload cannot cross a different profile kind', () {
      for (final kind in ProfileRouteKind.values) {
        if (kind != ProfileRouteKind.band) {
          expect(
            ProfileRouteTarget.fromArguments(
              kind,
              BandProfileScreenArgs(bandId: 'band'),
            ).id,
            isEmpty,
          );
        }
        if (kind != ProfileRouteKind.venue) {
          expect(
            ProfileRouteTarget.fromArguments(
              kind,
              const VenuePublicProfileArgs(venueId: 'venue'),
            ).id,
            isEmpty,
          );
        }
      }
      expect(
        ProfileRouteTarget.fromArguments(
          ProfileRouteKind.band,
          const PublicProfileArgs(profileId: 'musician'),
        ).id,
        isEmpty,
      );
    });
  });

  group('central ownership resolver', () {
    for (final kind in ProfileRouteKind.values) {
      final target = ProfileRouteTarget(kind: kind, id: 'target');
      test('$kind requires a nonempty target even for guests', () async {
        await expectLater(
          resolver.resolve(
            ProfileRouteTarget(kind: kind, id: ''),
            const AuthSession.guest(),
          ),
          throwsFormatException,
        );
      });

      for (final viewer in <String, AuthSession>{
        'guest': const AuthSession.guest(),
        'inactive': _session(kind, status: 'SUSPENDED'),
        'missing identity': _session(kind, userId: ''),
        'blank identity': _session(kind, userId: '  '),
        'wrong role': _session(kind, roles: const ['ROLE_UNRELATED']),
      }.entries) {
        test('$kind ${viewer.key} never reads owner repositories', () async {
          expect(await resolver.resolve(target, viewer.value), isNull);
        });
      }

      for (final role in [_role(kind), ' ${_role(kind).toLowerCase()} ']) {
        test('$kind supports normalized role $role', () async {
          final reads = _register(kind);
          final destination = await resolver.resolve(
            target,
            _session(kind, roles: [role]),
          );
          expect(destination?.route, _ownerRoute(kind));
          expect(reads.count, 1);
          if (kind == ProfileRouteKind.venue) {
            expect(
              (destination!.arguments as VenueProfileArgs).venueId,
              'target',
            );
          } else if (kind == ProfileRouteKind.band) {
            final args = destination!.arguments as BandProfileScreenArgs;
            expect(args.bandId, 'target');
            expect(args.viewMode, BandProfileViewMode.auto);
          } else {
            expect(destination!.arguments, isNull);
          }
        });
      }

      test('$kind another identity stays public', () async {
        final reads = _register(
          kind,
          id: kind == ProfileRouteKind.band || kind == ProfileRouteKind.venue
              ? 'target'
              : 'my-different-profile',
          userId:
              kind == ProfileRouteKind.band || kind == ProfileRouteKind.venue
              ? 'another-user'
              : 'viewer',
        );
        expect(await resolver.resolve(target, _session(kind)), isNull);
        expect(reads.count, 1);
      });

      test(
        '$kind blank profile ID is not treated as another profile',
        () async {
          _register(kind, id: '');
          await expectLater(
            resolver.resolve(target, _session(kind)),
            throwsStateError,
          );
        },
      );

      for (final fail in ['result', 'null', 'exception']) {
        test('$kind $fail fails closed without a public fallback', () async {
          _register(kind, failure: fail);
          await expectLater(
            resolver.resolve(target, _session(kind)),
            throwsA(isA<StateError>()),
          );
        });
      }
    }

    for (final kind in [
      ProfileRouteKind.musician,
      ProfileRouteKind.studio,
      ProfileRouteKind.listener,
    ]) {
      for (final userId in ['', ' ', 'another-user']) {
        test('$kind own payload owner $userId must match session', () async {
          _register(kind, userId: userId);
          await expectLater(
            resolver.resolve(
              ProfileRouteTarget(kind: kind, id: 'target'),
              _session(kind),
            ),
            throwsStateError,
          );
        });
      }

      test('$kind stable IDs are compared after trimming', () async {
        _register(kind, id: ' target ', userId: ' viewer ');
        expect(
          (await resolver.resolve(
            ProfileRouteTarget(kind: kind, id: 'target'),
            _session(kind, userId: ' viewer '),
          ))?.route,
          _ownerRoute(kind),
        );
      });
    }

    for (final kind in [ProfileRouteKind.venue, ProfileRouteKind.band]) {
      test('$kind mismatched public ID fails closed', () async {
        _register(kind, id: 'wrong-target');
        await expectLater(
          resolver.resolve(
            ProfileRouteTarget(kind: kind, id: 'target'),
            _session(kind),
          ),
          throwsStateError,
        );
      });
    }

    test('venue missing owner ID cannot establish ownership', () async {
      _register(ProfileRouteKind.venue, userId: '  ');
      await expectLater(
        resolver.resolve(
          const ProfileRouteTarget(kind: ProfileRouteKind.venue, id: 'target'),
          _session(ProfileRouteKind.venue),
        ),
        throwsStateError,
      );
    });

    for (final role in ['MEMBER', 'MANAGER', 'PR_MANAGER', 'BOS_ADAM']) {
      test(
        'active band $role opens member route without founder privileges',
        () async {
          _register(ProfileRouteKind.band, members: [_member(role: role)]);
          final destination = await resolver.resolve(
            const ProfileRouteTarget(kind: ProfileRouteKind.band, id: 'target'),
            _session(ProfileRouteKind.band),
          );
          expect(destination?.route, AppRoutes.bandMemberProfile);
          final args = destination!.arguments as BandProfileScreenArgs;
          expect(args.viewMode, BandProfileViewMode.member);
          expect(args.bandId, 'target');
        },
      );
    }

    for (final status in [
      'PENDING',
      'INVITED',
      'REMOVED',
      'LEFT',
      'INACTIVE',
    ]) {
      test('band $status founder cannot receive owner route', () async {
        _register(ProfileRouteKind.band, members: [_member(status: status)]);
        expect(
          await resolver.resolve(
            const ProfileRouteTarget(kind: ProfileRouteKind.band, id: 'target'),
            _session(ProfileRouteKind.band),
          ),
          isNull,
        );
      });
    }

    test('duplicate active band memberships fail closed', () async {
      _register(
        ProfileRouteKind.band,
        members: [
          _member(),
          _member(role: 'MEMBER'),
        ],
      );
      await expectLater(
        resolver.resolve(
          const ProfileRouteTarget(kind: ProfileRouteKind.band, id: 'target'),
          _session(ProfileRouteKind.band),
        ),
        throwsStateError,
      );
    });

    test(
      'inactive old founder row does not elevate active ordinary member',
      () async {
        _register(
          ProfileRouteKind.band,
          members: [
            _member(status: 'LEFT'),
            _member(role: ' member ', status: ' active ', userId: ' viewer '),
          ],
        );
        expect(
          (await resolver.resolve(
            const ProfileRouteTarget(kind: ProfileRouteKind.band, id: 'target'),
            _session(ProfileRouteKind.band),
          ))?.route,
          AppRoutes.bandMemberProfile,
        );
      },
    );
  });
}

String _argumentKey(ProfileRouteKind kind) => switch (kind) {
  ProfileRouteKind.band => 'bandId',
  ProfileRouteKind.venue => 'venueId',
  _ => 'profileId',
};

String _role(ProfileRouteKind kind) => switch (kind) {
  ProfileRouteKind.musician || ProfileRouteKind.band => 'MUSICIAN',
  ProfileRouteKind.venue => 'VENUE',
  ProfileRouteKind.studio => 'STUDIO',
  ProfileRouteKind.listener => 'LISTENER',
};

String _ownerRoute(ProfileRouteKind kind) => switch (kind) {
  ProfileRouteKind.musician => AppRoutes.musicianProfile,
  ProfileRouteKind.band => AppRoutes.bandProfile,
  ProfileRouteKind.venue => AppRoutes.venueProfile,
  ProfileRouteKind.studio => AppRoutes.studioProfile,
  ProfileRouteKind.listener => AppRoutes.listenerProfile,
};

AuthSession _session(
  ProfileRouteKind kind, {
  String userId = 'viewer',
  String status = 'ACTIVE',
  List<String>? roles,
}) => AuthSession.authenticated(
  token: 'token',
  userId: userId,
  username: 'same-username-does-not-establish-ownership',
  accountStatus: status,
  roles: roles ?? ['ROLE_${_role(kind)}'],
  permissions: const [],
  expiresAt: DateTime.utc(2100),
  isAdmin: false,
);

class _Reads {
  int count = 0;
  final String? failure;
  _Reads(this.failure);

  Future<Result<T>> read<T>(T profile) async {
    count++;
    return switch (failure) {
      'exception' => throw StateError('Transport failure'),
      'result' => const Result.failure(
        AppError(code: 'unavailable', message: 'Unavailable'),
      ),
      'null' => const Result.success(null),
      _ => Result.success(profile),
    };
  }
}

_Reads _register(
  ProfileRouteKind kind, {
  String id = 'target',
  String userId = 'viewer',
  String? failure,
  List<BandMemberSummary>? members,
}) {
  final reads = _Reads(failure);
  switch (kind) {
    case ProfileRouteKind.musician:
      serviceLocator.registerSingleton<MusicianProfileRepository>(
        _MusicianRepository(reads, _Musician(id, userId)),
      );
    case ProfileRouteKind.studio:
      serviceLocator.registerSingleton<StudioProfileRepository>(
        _StudioRepository(reads, _Studio(id, userId)),
      );
    case ProfileRouteKind.listener:
      serviceLocator.registerSingleton<ListenerProfileRepository>(
        _ListenerRepository(reads, _Listener(id, userId)),
      );
    case ProfileRouteKind.venue:
      serviceLocator.registerSingleton<VenueProfileRepository>(
        _VenueRepository(reads, _Venue(id, userId)),
      );
    case ProfileRouteKind.band:
      serviceLocator.registerSingleton<BandRepository>(
        _BandRepository(reads, _Band(id, members ?? [_member(userId: userId)])),
      );
  }
  return reads;
}

BandMemberSummary _member({
  String userId = 'viewer',
  String role = 'FOUNDER',
  String status = 'ACTIVE',
}) => BandMemberSummary(
  userId: userId,
  profileId: 'member-profile',
  username: 'same-username-does-not-establish-ownership',
  profilePictureUrl: null,
  role: role,
  status: status,
);

class _Musician extends Fake implements MusicianProfile {
  @override
  final String id;
  @override
  final String userId;
  _Musician(this.id, this.userId);
}

class _Studio extends Fake implements StudioProfile {
  @override
  final String id;
  @override
  final String userId;
  _Studio(this.id, this.userId);
}

class _Listener extends Fake implements ListenerProfile {
  @override
  final String id;
  @override
  final String userId;
  _Listener(this.id, this.userId);
}

class _Venue extends Fake implements VenuePublicProfile {
  @override
  final String venueId;
  @override
  final String ownerUserId;
  _Venue(this.venueId, this.ownerUserId);
}

class _Band extends Fake implements BandProfile {
  @override
  final String id;
  @override
  final List<BandMemberSummary> members;
  _Band(this.id, this.members);
}

class _MusicianRepository extends Fake implements MusicianProfileRepository {
  final _Reads reads;
  final MusicianProfile profile;
  _MusicianRepository(this.reads, this.profile);
  @override
  Future<Result<MusicianProfile>> getMyProfile() => reads.read(profile);
}

class _StudioRepository extends Fake implements StudioProfileRepository {
  final _Reads reads;
  final StudioProfile profile;
  _StudioRepository(this.reads, this.profile);
  @override
  Future<Result<StudioProfile>> getMyProfile() => reads.read(profile);
}

class _ListenerRepository extends Fake implements ListenerProfileRepository {
  final _Reads reads;
  final ListenerProfile profile;
  _ListenerRepository(this.reads, this.profile);
  @override
  Future<Result<ListenerProfile>> getMyProfile() => reads.read(profile);
}

class _VenueRepository extends Fake implements VenueProfileRepository {
  final _Reads reads;
  final VenuePublicProfile profile;
  _VenueRepository(this.reads, this.profile);
  @override
  Future<Result<VenuePublicProfile>> getPublicVenueProfile({String? venueId}) =>
      reads.read(profile);
}

class _BandRepository extends Fake implements BandRepository {
  final _Reads reads;
  final BandProfile profile;
  _BandRepository(this.reads, this.profile);
  @override
  Future<Result<BandProfile>> getPublicBandById(String bandId) =>
      reads.read(profile);
}
