import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_route_guard.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/collab_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_badge_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_badge_state.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/engagement_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/follow/domain/band_follow_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/follow/domain/follow_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/data/musician_feed_muted_authors_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/data/musician_feed_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/domain/backstage_feed_session.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/domain/musician_feed_models.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/domain/musician_feed_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/presentation/cubit/musician_feed_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/presentation/cubit/musician_feed_muted_authors_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/presentation/screens/musician_feed_view.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/cubit/notification_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/cubit/notification_state.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/backstage_profiles_home_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/profile_public_bottom_bar.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/stage_home_top_bar.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';

import 'support/event_audience_fakes.dart';
import 'support/recording_api_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'feed audience requires one active personal role and accepts role aliases',
    () {
      for (final roles in [
        ['VENUE'],
        ['ROLE_VENUE'],
        ['VENUE', 'ROLE_VENUE', 'ROLE_ADMIN'],
      ]) {
        expect(
          backstageFeedSessionIdentity(audienceSession(roles: roles))?.audience,
          BackstageFeedAudience.venue,
        );
      }
      for (final roles in [
        ['ROLE_MUSICIAN', 'ROLE_VENUE'],
        ['ROLE_VENUE', 'ROLE_LISTENER'],
        ['ROLE_MUSICIAN', 'ROLE_STUDIO'],
        ['ROLE_VENUE', 'ROLE_PRODUCER'],
        ['ROLE_VENUE', 'ROLE_ORGANIZER'],
        ['ROLE_STUDIO'],
        ['ROLE_ADMIN'],
      ]) {
        expect(
          backstageFeedSessionIdentity(audienceSession(roles: roles)),
          isNull,
        );
      }
      expect(backstageFeedSessionIdentity(const AuthSession.guest()), isNull);
      expect(
        backstageFeedSessionIdentity(
          audienceSession(role: 'ROLE_VENUE', status: 'PENDING_VENUE_REQUEST'),
        ),
        isNull,
      );
    },
  );

  test(
    'venue uses shared read contract without profile completion capability',
    () async {
      final sessions = _sessions();
      addTearDown(sessions.dispose);
      final api = RecordingApiClient((_) => _wirePage());
      final repository = MusicianFeedRepositoryImpl(api, sessions);

      expect(
        (await repository.load(limit: 20, cursor: 'next-venue-page')).isSuccess,
        isTrue,
      );
      expect(api.lastRequest.path, '/api/v1/feed/venue');
      expect(api.lastRequest.query?['cursor'], 'next-venue-page');
      expect(
        (api.lastRequest.query?['supportedItemTypes'] as String)
            .split(',')
            .toSet(),
        MusicianFeedItemType.values
            .where((type) => type != MusicianFeedItemType.profileCompletion)
            .map((type) => type.apiValue)
            .toSet(),
      );
      expect(api.lastRequest.requestContext?.expectedSessionKey, 'viewer');
      expect(api.lastRequest.requestContext?.expectedToken, 'token');
    },
  );

  test(
    'venue feedback telemetry and mute writes stay on the selected audience',
    () async {
      final sessions = _sessions();
      addTearDown(sessions.dispose);
      final api = RecordingApiClient((_) => null);
      final repository = MusicianFeedRepositoryImpl(api, sessions);
      expect(
        (await repository.sendFeedback(
          itemId: 'TRACK:item+id',
          impressionToken: 'signed-item',
          action: MusicianFeedFeedbackAction.hide,
        )).isSuccess,
        isTrue,
      );
      expect(
        (await repository.recordEvent(
          clientEventId: '00000000-0000-4000-8000-000000000001',
          impressionToken: 'signed-item',
          eventType: MusicianFeedTelemetryEventType.impression,
        )).isSuccess,
        isTrue,
      );
      expect(
        (await repository.muteAuthor(
          profileType: 'MUSICIAN',
          profileId: 'artist',
        )).isSuccess,
        isTrue,
      );
      expect(
        (await repository.unmuteAuthor(
          profileType: 'BAND',
          profileId: 'band',
        )).isSuccess,
        isTrue,
      );
      expect(api.requests.map((request) => request.path), [
        '/api/v1/feed/venue/items/TRACK%3Aitem%2Bid/feedback',
        '/api/v1/feed/venue/events',
        '/api/v1/feed/venue/authors/MUSICIAN/artist/mute',
        '/api/v1/feed/venue/authors/BAND/band/mute',
      ]);
      expect(
        api.requests.every(
          (request) =>
              request.requestContext?.expectedSessionKey == 'viewer' &&
              request.requestContext?.expectedToken == 'token',
        ),
        isTrue,
      );
    },
  );

  test(
    'read and write responses cannot cross a role change with unchanged credentials',
    () async {
      final sessions = _sessions();
      addTearDown(sessions.dispose);
      final read = Completer<Object?>();
      final write = Completer<Object?>();
      final api = RecordingApiClient(
        (request) => request.method == RecordedHttpMethod.get
            ? read.future
            : write.future,
      );
      final repository = MusicianFeedRepositoryImpl(api, sessions);
      final loading = repository.load(limit: 20);
      final muting = repository.muteAuthor(
        profileType: 'MUSICIAN',
        profileId: 'artist',
      );
      sessions.replace(
        audienceSession(user: 'viewer', token: 'token', role: 'ROLE_MUSICIAN'),
      );
      read.complete(_wirePage());
      write.complete(null);
      expect((await loading).error?.code, 'musician_feed_session_changed');
      expect((await muting).error?.code, 'musician_feed_session_changed');
    },
  );

  test(
    'unsupported roles do not send a read or mutation to another feed',
    () async {
      final sessions = AudienceTestSessions(
        audienceSession(role: 'ROLE_STUDIO'),
      );
      addTearDown(sessions.dispose);
      final api = RecordingApiClient((_) => null);
      final repository = MusicianFeedRepositoryImpl(api, sessions);
      expect((await repository.load(limit: 20)).isSuccess, isFalse);
      expect(
        (await repository.muteAuthor(
          profileType: 'MUSICIAN',
          profileId: 'artist',
        )).isSuccess,
        isFalse,
      );
      expect(api.requests, isEmpty);
    },
  );

  test(
    'venue muted authors share paging and unmute, with role-fenced callbacks',
    () async {
      final sessions = _sessions();
      addTearDown(sessions.dispose);
      final deletion = Completer<Object?>();
      var callbacks = 0;
      final api = RecordingApiClient(
        (request) => request.method == RecordedHttpMethod.get
            ? {
                'items': [_wireAuthor()],
                'nextCursor': null,
                'hasMore': false,
              }
            : deletion.future,
      );
      final repository = MusicianFeedMutedAuthorsRepositoryImpl(
        api,
        sessions,
        onUnmuted: (_) => callbacks++,
      );
      final cubit = MusicianFeedMutedAuthorsCubit(repository, sessions);
      addTearDown(cubit.close);
      await cubit.initialize();
      expect(cubit.state.items.single.visibleName, 'Sanatçı');
      expect(api.lastRequest.path, '/api/v1/feed/venue/muted-authors');
      final unmuting = cubit.unmute(cubit.state.items.single.identity);
      expect(
        api.lastRequest.path,
        '/api/v1/feed/venue/authors/MUSICIAN/artist/mute',
      );
      sessions.replace(
        audienceSession(user: 'viewer', token: 'token', role: 'ROLE_MUSICIAN'),
      );
      deletion.complete(null);
      expect(await unmuting, isFalse);
      expect(cubit.state.items, isEmpty);
      expect(callbacks, 0);
    },
  );

  test(
    'venue completion is omitted on first and subsequent pages without losing cursor',
    () async {
      final sessions = _sessions();
      addTearDown(sessions.dispose);
      final repository = _FeedRepository([
        Future.value(
          Result.success(_page([_completion('first')], nextCursor: 'next')),
        ),
        Future.value(Result.success(_page([_completion('second')]))),
      ]);
      final cubit = _cubit(repository, sessions);
      addTearDown(cubit.close);
      await cubit.initialize();
      expect(cubit.supportsProfileCompletion, isFalse);
      expect(cubit.state.items, isEmpty);
      expect(cubit.state.nextCursor, 'next');
      await cubit.loadMore();
      expect(cubit.state.items, isEmpty);
      expect(cubit.state.hasMore, isFalse);
      expect(repository.loads, 2);
    },
  );

  test(
    'musician keeps completion and role changes invalidate navigation fences',
    () async {
      final sessions = _sessions(role: 'ROLE_MUSICIAN');
      addTearDown(sessions.dispose);
      final repository = _FeedRepository([
        Future.value(Result.success(_page([_completion('completion')]))),
      ]);
      final cubit = _cubit(repository, sessions);
      addTearDown(cubit.close);
      await cubit.initialize();
      final fence = cubit.captureSessionFence();
      expect(cubit.supportsProfileCompletion, isTrue);
      expect(
        cubit.state.items.single.type,
        MusicianFeedItemType.profileCompletion,
      );
      sessions.replace(
        audienceSession(user: 'viewer', token: 'token', role: 'ROLE_VENUE'),
      );
      expect(cubit.acceptsSessionFence(fence), isFalse);
    },
  );

  test(
    'muted management route allows venue and keeps musician-only owner routes protected',
    () {
      final venue = audienceSession(role: 'ROLE_VENUE');
      expect(
        AppRouteGuard.redirectFor(AppRoutes.musicianFeedMutedAuthors, venue),
        isNull,
      );
      expect(
        AppRouteGuard.redirectFor(AppRoutes.musicianProfile, venue),
        AppRoutes.home,
      );
      expect(
        AppRouteGuard.redirectFor(AppRoutes.myBands, venue),
        AppRoutes.home,
      );
      expect(
        AppRouteGuard.redirectFor(
          AppRoutes.musicianFeedMutedAuthors,
          audienceSession(role: 'ROLE_STUDIO'),
        ),
        AppRoutes.home,
      );
    },
  );

  testWidgets(
    'venue home reuses feed and controls and replaces a stale role session',
    (tester) async {
      await serviceLocator.reset();
      final sessions = _sessions();
      final delayed = Completer<Result<MusicianFeedPage>>();
      final venueRepository = _FeedRepository([delayed.future]);
      final musicianRepository = _FeedRepository([
        Future.value(Result.success(_page([_completion('new-musician')]))),
      ]);
      final created = <MusicianFeedCubit>[];
      serviceLocator.registerSingleton<AuthSessionManager>(sessions);
      serviceLocator.registerSingleton<DmBadgeCubit>(_DmBadgeCubit());
      serviceLocator.registerFactory<MusicianFeedCubit>(() {
        final cubit = _cubit(
          created.isEmpty ? venueRepository : musicianRepository,
          sessions,
        );
        created.add(cubit);
        return cubit;
      });
      await tester.pumpWidget(
        BlocProvider<NotificationCubit>.value(
          value: _NotificationCubit(),
          child: MaterialApp(
            theme: AppTheme.navy,
            home: const BackstageProfilesHomeScreen(),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(MusicianFeedView), findsOneWidget);
      expect(find.byType(ProfilePublicBottomBar), findsOneWidget);
      expect(find.byType(StageHomeTopBar), findsOneWidget);
      expect(venueRepository.loads, 1);

      // A role change also rebuilds when token/user are unchanged in session metadata.
      sessions.replace(
        audienceSession(user: 'viewer', token: 'token', role: 'ROLE_MUSICIAN'),
      );
      await tester.pumpAndSettle();
      expect(created, hasLength(2));
      expect(created.first.isClosed, isTrue);
      expect(created.last.state.items.single.id, 'new-musician');
      delayed.complete(
        Result.success(_page([_completion('old-venue-response')])),
      );
      await tester.pumpAndSettle();
      expect(created.last.state.items.single.id, 'new-musician');

      await tester.pumpWidget(const SizedBox.shrink());
      sessions.dispose();
      await serviceLocator.reset();
    },
  );

  testWidgets(
    'venue home exposes the existing announcements directory action',
    (tester) async {
      await serviceLocator.reset();
      final sessions = _sessions();
      final repository = _FeedRepository([
        Future.value(Result.success(_page([]))),
      ]);
      serviceLocator.registerSingleton<AuthSessionManager>(sessions);
      serviceLocator.registerSingleton<DmBadgeCubit>(_DmBadgeCubit());
      serviceLocator.registerFactory<MusicianFeedCubit>(
        () => _cubit(repository, sessions),
      );
      await tester.pumpWidget(
        BlocProvider<NotificationCubit>.value(
          value: _NotificationCubit(),
          child: MaterialApp(
            theme: AppTheme.navy,
            routes: {
              AppRoutes.announcements: (_) =>
                  const Scaffold(body: Text('Duyuru dizini')),
            },
            home: const BackstageProfilesHomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Menü'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('profile-menu-announcements')));
      await tester.pumpAndSettle();
      expect(find.text('Duyuru dizini'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      sessions.dispose();
      await serviceLocator.reset();
    },
  );
}

AudienceTestSessions _sessions({String role = 'ROLE_VENUE'}) =>
    AudienceTestSessions(
      audienceSession(user: 'viewer', token: 'token', role: role),
    );

Map<String, Object?> _wirePage() => {
  'schemaVersion': 1,
  'algorithmVersion': 'venue-v1.0.0',
  'feedSessionId': 'feed-session',
  'generatedAt': '2026-09-14T00:00:00Z',
  'items': [],
  'nextCursor': null,
  'hasMore': false,
};

Map<String, Object?> _wireAuthor() => {
  'profileType': 'MUSICIAN',
  'profileId': 'artist',
  'available': true,
  'mutedAt': '2026-09-14T00:00:00Z',
  'displayName': 'Sanatçı',
  'avatarUrl': null,
};

MusicianFeedPage _page(List<MusicianFeedItem> items, {String? nextCursor}) =>
    MusicianFeedPage(
      schemaVersion: 1,
      algorithmVersion: 'shared-test',
      feedSessionId: 'feed-session',
      generatedAt: DateTime.utc(2026, 9, 14),
      items: items,
      nextCursor: nextCursor,
      hasMore: nextCursor != null,
    );

MusicianFeedItem _completion(String id) => MusicianFeedItem(
  id: id,
  type: MusicianFeedItemType.profileCompletion,
  payloadVersion: 1,
  occurredAt: DateTime.utc(2026, 9, 14),
  position: 0,
  impressionToken: 'signed-$id',
  reason: const MusicianFeedReason(
    code: 'PROFILE_INCOMPLETE',
    actors: [],
    secondaryActorCount: 0,
  ),
  author: null,
  target: null,
  engagement: null,
  promotion: null,
  feedbackCapabilities: {},
  payload: const CompletionFeedPayload(completed: 0, total: 1, tasks: []),
);

MusicianFeedCubit _cubit(
  MusicianFeedRepository repository,
  AuthSessionManager sessions,
) => MusicianFeedCubit(
  repository,
  _EngagementRepository(),
  collabRepository: _CollabRepository(),
  followRepository: _FollowRepository(),
  bandFollowRepository: _BandFollowRepository(),
  sessions: sessions,
);

class _FeedRepository extends Fake implements MusicianFeedRepository {
  _FeedRepository(this.pages);
  final List<Future<Result<MusicianFeedPage>>> pages;
  int loads = 0;
  @override
  Future<Result<MusicianFeedPage>> load({required int limit, String? cursor}) =>
      pages[loads++];
  @override
  Future<Result<void>> recordEvent({
    required String clientEventId,
    required String impressionToken,
    required MusicianFeedTelemetryEventType eventType,
    DateTime? occurredAt,
  }) async => const Result.success(null);
}

class _EngagementRepository extends Fake implements EngagementRepository {}

class _CollabRepository extends Fake implements CollabRepository {}

class _FollowRepository extends Fake implements FollowRepository {}

class _BandFollowRepository extends Fake implements BandFollowRepository {}

class _DmBadgeCubit extends Fake implements DmBadgeCubit {
  @override
  DmBadgeState get state => const DmBadgeState.initial();
  @override
  Stream<DmBadgeState> get stream => const Stream.empty();
  @override
  Future<void> ensureStarted() async {}
}

class _NotificationCubit extends Fake implements NotificationCubit {
  @override
  NotificationState get state => const NotificationState.initial();
  @override
  Stream<NotificationState> get stream => const Stream.empty();
}
