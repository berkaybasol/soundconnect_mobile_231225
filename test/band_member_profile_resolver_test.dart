import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/dm_user_profile_resolver.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/entities/dm_profile_target.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/band_member_summary.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/musician_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/musician_profile_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/navigation/band_member_profile_resolver.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/profile_route_args.dart';

void main() {
  late _Musicians musicians;
  late _Users users;
  late _SessionManager session;
  late BandMemberProfileResolver resolver;

  setUp(() async {
    await serviceLocator.reset();
    musicians = _Musicians();
    users = _Users();
    session = _SessionManager();
    resolver = BandMemberProfileResolver(
      repository: musicians,
      userProfileResolver: users,
      sessionManager: session,
    );
  });
  tearDown(serviceLocator.reset);

  test('direct profile must match both stable IDs', () async {
    musicians.results['profile'] = Result.success(_profile());
    expect((await resolver.resolve(_member()))?.id, 'profile');
    expect(musicians.reads, ['profile']);
    expect(users.reads, isEmpty);
  });

  for (final wrongIdentity in ['user', 'profile']) {
    test('rejects a response with mismatched $wrongIdentity ID', () async {
      musicians.results['profile'] = Result.success(
        _profile(
          userId: wrongIdentity == 'user' ? 'stranger' : 'user',
          id: wrongIdentity == 'profile' ? 'stranger' : 'profile',
        ),
      );
      expect(await resolver.resolve(_member()), isNull);
      expect(musicians.reads, ['profile']);
    });
  }

  test('same username never establishes member identity', () async {
    musicians.results['profile'] = Result.success(
      _profile(userId: 'stranger', username: 'aedrum'),
    );
    expect(await resolver.resolve(_member()), isNull);
    expect(users.reads, ['user']);
  });

  test('blank user ID cannot resolve even with direct profile ID', () async {
    musicians.results['profile'] = Result.success(_profile());
    expect(await resolver.resolve(_member(userId: ' ')), isNull);
    expect(musicians.reads, isEmpty);
    expect(users.reads, isEmpty);
  });

  test(
    'missing profile ID uses canonical by-user target, not user ID',
    () async {
      users.targets = [_target('canonical')];
      musicians.results['canonical'] = Result.success(
        _profile(id: 'canonical'),
      );
      expect(
        (await resolver.resolve(_member(profileId: null)))?.id,
        'canonical',
      );
      expect(users.reads, ['user']);
      expect(musicians.reads, ['canonical']);
    },
  );

  test(
    'wrong direct ID can recover only through verified canonical ID',
    () async {
      musicians.results['profile'] = Result.success(
        _profile(userId: 'stranger'),
      );
      users.targets = [_target('canonical')];
      musicians.results['canonical'] = Result.success(
        _profile(id: 'canonical'),
      );
      expect((await resolver.resolve(_member()))?.id, 'canonical');
      expect(musicians.reads, ['profile', 'canonical']);
    },
  );

  test(
    'canonical resolver candidate is also checked against member user',
    () async {
      users.targets = [_target('canonical')];
      musicians.results['canonical'] = Result.success(
        _profile(id: 'canonical', userId: 'stranger'),
      );
      expect(await resolver.resolve(_member(profileId: null)), isNull);
    },
  );

  test('non-musician targets never become a musician profile lookup', () async {
    users.targets = [_target('venue', type: DmProfileTargetType.venue)];
    expect(await resolver.resolve(_member(profileId: null)), isNull);
    expect(musicians.reads, isEmpty);
  });

  test('ambiguous canonical musician identity fails closed', () async {
    users.targets = [_target('one'), _target('two')];
    expect(await resolver.resolve(_member(profileId: null)), isNull);
    expect(musicians.reads, isEmpty);
  });

  test('duplicate canonical targets are safely de-duplicated', () async {
    users.targets = [_target('profile'), _target('profile')];
    musicians.results['profile'] = Result.success(_profile());
    expect((await resolver.resolve(_member(profileId: null)))?.id, 'profile');
    expect(musicians.reads, ['profile']);
  });

  test('concurrent hydration and tap share one identity request', () async {
    musicians.pending = Completer<Result<MusicianProfile>>();
    final first = resolver.resolve(_member());
    final second = resolver.resolve(_member());
    expect(identical(first, second), isTrue);
    expect(musicians.reads, ['profile']);
    musicians.pending!.complete(Result.success(_profile()));
    expect(await first, isNotNull);
    expect(await second, isNotNull);
  });

  test('completed lookups are not stale-cached across later taps', () async {
    musicians.results['profile'] = Result.success(_profile());
    expect(await resolver.resolve(_member()), isNotNull);
    musicians.results['profile'] = Result.success(_profile(userId: 'stranger'));
    expect(await resolver.resolve(_member()), isNull);
    expect(musicians.reads, ['profile', 'profile']);
  });

  test('session replacement discards pending identity results', () async {
    musicians.pending = Completer<Result<MusicianProfile>>();
    final result = resolver.resolve(_member());
    session.value = _session('other');
    musicians.pending!.complete(Result.success(_profile()));
    expect(await result, isNull);
    expect(users.reads, isEmpty);
  });

  test(
    'repository and canonical resolver failures return no guessed identity',
    () async {
      musicians.throwRead = true;
      expect(await resolver.resolve(_member()), isNull);
      musicians.throwRead = false;
      users.throwRead = true;
      expect(await resolver.resolve(_member(profileId: null)), isNull);
    },
  );

  testWidgets('rapid taps push one verified named profile route', (
    tester,
  ) async {
    musicians.pending = Completer<Result<MusicianProfile>>();
    final routes = <RouteSettings>[];
    final context = await _host(tester, routes);
    final first = resolver.open(context, _member());
    final second = resolver.open(context, _member());
    musicians.pending!.complete(Result.success(_profile()));
    await tester.pumpAndSettle();
    expect(routes, hasLength(1));
    expect(routes.single.name, AppRoutes.musicianPublicProfile);
    expect((routes.single.arguments as PublicProfileArgs).profileId, 'profile');
    expect(musicians.reads, ['profile']);
    Navigator.of(context).pop();
    await tester.pumpAndSettle();
    await Future.wait([first, second]);
    expect(tester.takeException(), isNull);
  });

  for (final invalidation in ['session', 'covered', 'disposed', 'member']) {
    testWidgets('pending tap cannot navigate after $invalidation changes', (
      tester,
    ) async {
      musicians.pending = Completer<Result<MusicianProfile>>();
      final routes = <RouteSettings>[];
      final context = await _host(tester, routes);
      var currentMember = true;
      final operation = resolver.open(
        context,
        _member(),
        isMemberCurrent: () => currentMember,
      );
      if (invalidation == 'session') session.value = _session('other');
      if (invalidation == 'member') currentMember = false;
      if (invalidation == 'covered') {
        unawaited(
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Other page')),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }
      if (invalidation == 'disposed') {
        await tester.pumpWidget(const SizedBox.shrink());
      }
      musicians.pending!.complete(Result.success(_profile()));
      await tester.pumpAndSettle();
      await operation;
      expect(routes, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'lookup failure leaves retry available without wrong navigation',
    (tester) async {
      final routes = <RouteSettings>[];
      final context = await _host(tester, routes);
      await resolver.open(context, _member());
      await tester.pumpAndSettle();
      expect(routes, isEmpty);
      expect(
        find.text('Bu üyenin profili açılamadı. Lütfen tekrar dene.'),
        findsOneWidget,
      );
      musicians.results['profile'] = Result.success(_profile());
      final operation = resolver.open(context, _member());
      await tester.pumpAndSettle();
      expect(routes, hasLength(1));
      Navigator.of(context).pop();
      await tester.pumpAndSettle();
      await operation;
    },
  );
}

Future<BuildContext> _host(
  WidgetTester tester,
  List<RouteSettings> routes,
) async {
  late BuildContext source;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          source = context;
          return const Scaffold(body: Text('Roster'));
        },
      ),
      onGenerateRoute: (settings) {
        routes.add(settings);
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const Scaffold(body: Text('Profile')),
        );
      },
    ),
  );
  await tester.pumpAndSettle();
  return source;
}

BandMemberSummary _member({
  String userId = 'user',
  String? profileId = 'profile',
}) => BandMemberSummary(
  userId: userId,
  profileId: profileId,
  username: 'aedrum',
  profilePictureUrl: null,
  role: 'MEMBER',
  status: 'ACTIVE',
);

MusicianProfile _profile({
  String id = 'profile',
  String userId = 'user',
  String username = 'aedrum',
}) => MusicianProfile(
  id: id,
  userId: userId,
  username: username,
  stageName: null,
  bio: null,
  profilePicture: null,
  instagramUrl: null,
  youtubeUrl: null,
  soundcloudUrl: null,
  spotifyEmbedUrl: null,
  spotifyArtistId: null,
  spotifyTrackIds: const [],
  spotifyTracks: const [],
  instruments: const [],
  activeVenues: const [],
  bands: const [],
);

DmProfileTarget _target(
  String id, {
  DmProfileTargetType type = DmProfileTargetType.musician,
}) =>
    DmProfileTarget(type: type, id: id, displayName: 'aedrum', imageUrl: null);

AuthSession _session(String id) => AuthSession.authenticated(
  token: 'token-$id',
  userId: id,
  username: 'aedrum',
  accountStatus: 'ACTIVE',
  roles: const ['ROLE_MUSICIAN'],
  permissions: const [],
  expiresAt: DateTime.utc(2040),
  isAdmin: false,
);

class _SessionManager extends Fake implements AuthSessionManager {
  AuthSession value = _session('user');
  @override
  AuthSession get session => value;
}

class _Musicians extends Fake implements MusicianProfileRepository {
  final reads = <String>[];
  final results = <String, Result<MusicianProfile>>{};
  Completer<Result<MusicianProfile>>? pending;
  bool throwRead = false;
  @override
  Future<Result<MusicianProfile>> getPublicProfileByProfileId(
    String profileId,
  ) async {
    reads.add(profileId);
    if (throwRead) throw StateError('Offline');
    return pending?.future ??
        results[profileId] ??
        const Result.failure(AppError(code: 'missing', message: 'Missing'));
  }
}

class _Users extends Fake implements DmUserProfileResolver {
  final reads = <String>[];
  List<DmProfileTarget> targets = [];
  bool throwRead = false;
  @override
  Future<List<DmProfileTarget>> resolveByUserId({
    required String userId,
    String? usernameHint,
  }) async {
    reads.add(userId);
    expect(usernameHint, isNull);
    if (throwRead) throw StateError('Offline');
    return targets;
  }
}
