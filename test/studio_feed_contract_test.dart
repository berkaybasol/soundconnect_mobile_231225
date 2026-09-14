import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_route_guard.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
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
import 'package:soundconnect_23_12_25codx/modules/musician_feed/presentation/widgets/musician_feed_card_chrome.dart';
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
  tearDown(() async => serviceLocator.reset());

  test('studio feed accepts canonical aliases with administrative roles', () {
    for (final roles in [
      ['STUDIO'],
      ['ROLE_STUDIO'],
      [' studio ', 'ROLE_STUDIO', 'ROLE_ADMIN', 'ROLE_OWNER'],
    ]) {
      final identity = backstageFeedSessionIdentity(
        audienceSession(roles: roles),
      );
      expect(identity?.audience, BackstageFeedAudience.studio);
      expect(identity?.audience.apiPath, '/api/v1/feed/studio');
      expect(identity?.audience.supportsProfileCompletion, isFalse);
    }
  });

  test(
    'studio cannot borrow another personal audience or bypass activation',
    () {
      for (final other in [
        'MUSICIAN',
        'VENUE',
        'LISTENER',
        'PRODUCER',
        'ORGANIZER',
      ]) {
        expect(
          backstageFeedSessionIdentity(
            audienceSession(roles: ['ROLE_STUDIO', other, 'ROLE_ADMIN']),
          ),
          isNull,
        );
      }
      for (final session in _ineligibleSessions()) {
        expect(backstageFeedSessionIdentity(session), isNull);
      }
    },
  );

  test(
    'studio reads use the shared card contract and preserve continuation',
    () async {
      final sessions = _sessions();
      addTearDown(sessions.dispose);
      final api = RecordingApiClient(
        (request) => _wirePage(
          [
            _wireItem(
              'completion',
              type: 'PROFILE_COMPLETION',
              payload: {'completed': 0, 'total': 1, 'tasks': <Object?>[]},
            ),
            _wireItem('studio-media', author: 'STUDIO'),
            _wireItem(
              'collab',
              type: 'COLLAB',
              payload: {'listing': <String, Object?>{}},
            ),
          ],
          cursor: request.query?['cursor'] == null ? 'next-studio-page' : null,
        ),
      );
      final repository = MusicianFeedRepositoryImpl(api, sessions);
      final first = await repository.load(limit: 20);
      expect(first.isSuccess, isTrue);
      expect(first.data!.algorithmVersion, 'studio-v1.0.0');
      expect(first.data!.items.map((item) => item.id), [
        'studio-media',
        'collab',
      ]);
      expect(first.data!.nextCursor, 'next-studio-page');
      final next = await repository.load(
        limit: 20,
        cursor: first.data!.nextCursor,
      );
      expect(next.isSuccess, isTrue);
      expect(next.data!.items.map((item) => item.id), [
        'studio-media',
        'collab',
      ]);
      expect(next.data!.hasMore, isFalse);
      expect(api.requests.map((request) => request.path), [
        '/api/v1/feed/studio',
        '/api/v1/feed/studio',
      ]);
      expect(api.lastRequest.query?['cursor'], 'next-studio-page');
      final types = (api.lastRequest.query!['supportedItemTypes'] as String)
          .split(',')
          .toSet();
      expect(
        types,
        MusicianFeedItemType.values
            .where((type) => type != MusicianFeedItemType.profileCompletion)
            .map((type) => type.apiValue)
            .toSet(),
      );
      expect(
        api.requests.every(
          (request) =>
              request.requestContext?.expectedSessionKey == 'studio-owner' &&
              request.requestContext?.expectedToken == 'token',
        ),
        isTrue,
      );
    },
  );

  test('studio mutations and paged muted management use its own API', () async {
    final sessions = _sessions();
    addTearDown(sessions.dispose);
    final notifications = <MusicianFeedAuthorProfileIdentity>[];
    final api = RecordingApiClient(
      (request) =>
          request.path.endsWith('/muted-authors') ? _mutedPage() : null,
    );
    final feed = MusicianFeedRepositoryImpl(api, sessions);
    expect(
      (await feed.sendFeedback(
        itemId: 'TRACK:one+two',
        impressionToken: 'signed',
        action: MusicianFeedFeedbackAction.hide,
      )).isSuccess,
      isTrue,
    );
    expect(
      (await feed.recordEvent(
        clientEventId: '00000000-0000-4000-8000-000000000001',
        impressionToken: 'signed',
        eventType: MusicianFeedTelemetryEventType.impression,
      )).isSuccess,
      isTrue,
    );
    expect(
      (await feed.muteAuthor(
        profileType: 'MUSICIAN',
        profileId: 'artist',
      )).isSuccess,
      isTrue,
    );
    expect(
      (await feed.unmuteAuthor(
        profileType: 'BAND',
        profileId: 'band',
      )).isSuccess,
      isTrue,
    );
    final muted = MusicianFeedMutedAuthorsRepositoryImpl(
      api,
      sessions,
      onUnmuted: notifications.add,
    );
    expect(
      (await muted.load(limit: 15, cursor: 'muted-next')).isSuccess,
      isTrue,
    );
    expect(api.lastRequest.query, {'limit': 15, 'cursor': 'muted-next'});
    expect(
      (await muted.unmute(
        profileType: 'STUDIO',
        profileId: 'other-studio',
      )).isSuccess,
      isTrue,
    );
    expect(notifications, [(profileType: 'STUDIO', profileId: 'other-studio')]);
    expect(api.requests.map((request) => request.path), [
      '/api/v1/feed/studio/items/TRACK%3Aone%2Btwo/feedback',
      '/api/v1/feed/studio/events',
      '/api/v1/feed/studio/authors/MUSICIAN/artist/mute',
      '/api/v1/feed/studio/authors/BAND/band/mute',
      '/api/v1/feed/studio/muted-authors',
      '/api/v1/feed/studio/authors/STUDIO/other-studio/mute',
    ]);
    expect(
      api.requests.every(
        (request) =>
            request.requestContext?.expectedSessionKey == 'studio-owner' &&
            request.requestContext?.expectedToken == 'token',
      ),
      isTrue,
    );
  });

  test(
    'inactive guest and mixed studio sessions never send feed requests',
    () async {
      for (final session in [
        ..._ineligibleSessions(),
        audienceSession(roles: ['ROLE_STUDIO', 'ROLE_LISTENER', 'ROLE_ADMIN']),
      ]) {
        final sessions = AudienceTestSessions(session);
        final api = RecordingApiClient((_) => null);
        final feed = MusicianFeedRepositoryImpl(api, sessions);
        final muted = MusicianFeedMutedAuthorsRepositoryImpl(api, sessions);
        expect((await feed.load(limit: 20)).isSuccess, isFalse);
        expect(
          (await feed.sendFeedback(
            itemId: 'TRACK:item',
            impressionToken: 'signed',
            action: MusicianFeedFeedbackAction.hide,
          )).isSuccess,
          isFalse,
        );
        expect(
          (await feed.recordEvent(
            clientEventId: '00000000-0000-4000-8000-000000000001',
            impressionToken: 'signed',
            eventType: MusicianFeedTelemetryEventType.impression,
          )).isSuccess,
          isFalse,
        );
        expect(
          (await feed.muteAuthor(
            profileType: 'MUSICIAN',
            profileId: 'artist',
          )).isSuccess,
          isFalse,
        );
        expect(
          (await feed.unmuteAuthor(
            profileType: 'MUSICIAN',
            profileId: 'artist',
          )).isSuccess,
          isFalse,
        );
        expect((await muted.load()).isSuccess, isFalse);
        expect(
          (await muted.unmute(
            profileType: 'MUSICIAN',
            profileId: 'artist',
          )).isSuccess,
          isFalse,
        );
        expect(api.requests, isEmpty);
        sessions.dispose();
      }
    },
  );

  for (final (label, next) in [
    ('listener', audienceSession(user: 'studio-owner')),
    ('musician', audienceSession(user: 'studio-owner', role: 'ROLE_MUSICIAN')),
    (
      'token refresh',
      audienceSession(
        user: 'studio-owner',
        role: 'ROLE_STUDIO',
        token: 'new-token',
      ),
    ),
    (
      'account switch',
      audienceSession(user: 'other-studio', role: 'ROLE_STUDIO'),
    ),
    (
      'pending',
      audienceSession(
        user: 'studio-owner',
        role: 'ROLE_STUDIO',
        status: 'PENDING_STUDIO_REQUEST',
      ),
    ),
    (
      'rejected',
      audienceSession(
        user: 'studio-owner',
        role: 'ROLE_STUDIO',
        status: 'REJECTED_STUDIO_REQUEST',
      ),
    ),
    ('logout', const AuthSession.guest()),
  ]) {
    test(
      'studio rejects delayed feed and unmute responses after $label',
      () async {
        final sessions = _sessions();
        addTearDown(sessions.dispose);
        final read = Completer<Object?>();
        final write = Completer<Object?>();
        final callbacks = <MusicianFeedAuthorProfileIdentity>[];
        final api = RecordingApiClient(
          (request) => request.method == RecordedHttpMethod.get
              ? read.future
              : write.future,
        );
        final feed = MusicianFeedRepositoryImpl(api, sessions);
        final muted = MusicianFeedMutedAuthorsRepositoryImpl(
          api,
          sessions,
          onUnmuted: callbacks.add,
        );
        final loading = feed.load(limit: 20);
        final muting = feed.muteAuthor(
          profileType: 'MUSICIAN',
          profileId: 'artist',
        );
        final unmuting = muted.unmute(
          profileType: 'MUSICIAN',
          profileId: 'artist',
        );
        sessions.replace(next);
        read.complete(_wirePage([_wireItem('old')]));
        write.complete(null);
        expect((await loading).error?.code, 'musician_feed_session_changed');
        expect((await muting).error?.code, 'musician_feed_session_changed');
        expect((await unmuting).isSuccess, isFalse);
        expect(callbacks, isEmpty);
      },
    );
  }

  test(
    'studio completion defense keeps normal content and paging state',
    () async {
      final sessions = _sessions();
      addTearDown(sessions.dispose);
      final repository = _Feed([
        _page([_completion('first'), _profile('artist-a')], cursor: 'next'),
        _page([_completion('second'), _profile('artist-b')]),
      ]);
      final cubit = _cubit(repository, sessions);
      addTearDown(cubit.close);
      await cubit.initialize();
      expect(cubit.supportsProfileCompletion, isFalse);
      expect(cubit.state.items.map((item) => item.id), ['artist-a']);
      expect(cubit.state.nextCursor, 'next');
      await cubit.loadMore();
      expect(cubit.state.items.map((item) => item.id), [
        'artist-a',
        'artist-b',
      ]);
      expect(cubit.state.hasMore, isFalse);
      expect(repository.cursors, [null, 'next']);
    },
  );

  test(
    'studio muted screen clears rows and fences DELETE on listener change',
    () async {
      final sessions = _sessions();
      addTearDown(sessions.dispose);
      final deletion = Completer<Object?>();
      final callbacks = <MusicianFeedAuthorProfileIdentity>[];
      final api = RecordingApiClient(
        (request) => request.method == RecordedHttpMethod.get
            ? _mutedPage()
            : deletion.future,
      );
      final repository = MusicianFeedMutedAuthorsRepositoryImpl(
        api,
        sessions,
        onUnmuted: callbacks.add,
      );
      final cubit = MusicianFeedMutedAuthorsCubit(repository, sessions);
      addTearDown(cubit.close);
      await cubit.initialize();
      final unmuting = cubit.unmute(cubit.state.items.single.identity);
      sessions.replace(audienceSession(user: 'studio-owner'));
      expect(cubit.state.items, isEmpty);
      deletion.complete(null);
      expect(await unmuting, isFalse);
      expect(callbacks, isEmpty);
    },
  );

  test(
    'studio route guards retain pending rejected and other owner boundaries',
    () {
      final studio = _studio();
      for (final route in [
        AppRoutes.backstageProfilesHome,
        AppRoutes.musicianFeedMutedAuthors,
        AppRoutes.announcements,
        AppRoutes.studioProfile,
      ]) {
        expect(AppRouteGuard.redirectFor(route, studio), isNull);
        expect(
          AppRouteGuard.redirectFor(
            route,
            _studio(status: 'PENDING_STUDIO_REQUEST'),
          ),
          AppRoutes.studioPending,
        );
        expect(
          AppRouteGuard.redirectFor(
            route,
            _studio(status: 'REJECTED_STUDIO_REQUEST'),
          ),
          AppRoutes.studioRejected,
        );
      }
      expect(
        AppRouteGuard.redirectFor(AppRoutes.listenerFeed, studio),
        AppRoutes.home,
      );
      expect(
        AppRouteGuard.redirectFor(AppRoutes.musicianProfile, studio),
        AppRoutes.home,
      );
      expect(
        AppRouteGuard.redirectFor(AppRoutes.venueProfile, studio),
        AppRoutes.home,
      );
      expect(
        AppRouteGuard.redirectFor(
          AppRoutes.musicianFeedMutedAuthors,
          audienceSession(roles: ['ROLE_STUDIO', 'ROLE_LISTENER']),
        ),
        isNotNull,
      );
    },
  );

  test('city reason is audience-specific without changing other roles', () {
    const reason = MusicianFeedReason(
      code: 'CITY_MATCH',
      actors: [],
      secondaryActorCount: 0,
    );
    for (final (audience, label) in [
      (BackstageFeedAudience.studio, 'Stüdyonla aynı şehirde'),
      (BackstageFeedAudience.venue, 'Mekânınla aynı şehirde'),
      (BackstageFeedAudience.listener, 'Senin şehrinde'),
      (BackstageFeedAudience.musician, 'Fırsat görmek istediğin şehirde'),
    ]) {
      expect(musicianFeedReasonLabel(reason, audience: audience), label);
    }
  });

  test(
    'studio rollout and invalid-cursor errors use existing recovery states',
    () async {
      final sessions = _sessions();
      addTearDown(sessions.dispose);
      final repository = MusicianFeedRepositoryImpl(
        RecordingApiClient(
          (request) => throw ApiException(
            AppError(
              code: request.query?['cursor'] == null
                  ? 'studio_feed_disabled'
                  : 'studio_feed_cursor_invalid',
              message: 'retry',
            ),
          ),
        ),
        sessions,
      );
      expect(
        (await repository.load(limit: 20)).error?.code,
        musicianFeedFeatureUnavailableCode,
      );
      expect(
        (await repository.load(limit: 20, cursor: 'next')).error?.code,
        musicianFeedCursorInvalidCode,
      );
    },
  );

  testWidgets('studio home uses the common cards navigation search and menu', (
    tester,
  ) async {
    final sessions = _sessions();
    addTearDown(sessions.dispose);
    _register(
      sessions,
      () => _cubit(
        _Feed([
          _page([_profile('artist')]),
        ]),
        sessions,
      ),
    );
    await tester.pumpWidget(
      _home(
        routes: {
          AppRoutes.announcements: (_) =>
              const Scaffold(body: Text('Duyuru dizini')),
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MusicianFeedView), findsOneWidget);
    expect(find.byType(ProfilePublicBottomBar), findsOneWidget);
    expect(find.byType(StageHomeTopBar), findsOneWidget);
    expect(find.text('Sanatçı artist'), findsOneWidget);
    expect(find.text('Stüdyonla aynı şehirde'), findsOneWidget);
    expect(find.text('Takip et'), findsOneWidget);
    final bar = tester.widget<BottomNavigationBar>(
      find.byType(BottomNavigationBar),
    );
    expect(bar.items.map((item) => item.label), [
      'Akış',
      'Collab',
      'Git',
      'Mesajlar',
      'Profil',
    ]);
    expect(
      find.text('Müzisyen, dinleyici, grup, stüdyo veya mekân ara'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Menü'));
    await tester.pumpAndSettle();
    expect(find.text('Profil ve iletişim bilgileri'), findsOneWidget);
    expect(find.text('Yönetim Paneli'), findsOneWidget);
    await tester.tap(find.byKey(const Key('profile-menu-announcements')));
    await tester.pumpAndSettle();
    expect(find.text('Duyuru dizini'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'studio home isolates token role and inactive session replacements',
    (tester) async {
      final sessions = _sessions();
      addTearDown(sessions.dispose);
      final old = Completer<Result<MusicianFeedPage>>();
      final created = <MusicianFeedCubit>[];
      _register(sessions, () {
        final repository = _Feed([
          _page([_profile('fresh')]),
        ]);
        if (created.isEmpty) repository.onLoad = () => old.future;
        final cubit = _cubit(repository, sessions);
        created.add(cubit);
        return cubit;
      });
      await tester.pumpWidget(_home());
      await tester.pump();
      final oldFence = created.single.captureSessionFence();
      sessions.replace(_studio(token: 'new-token'));
      await tester.pumpAndSettle();
      expect(created, hasLength(2));
      expect(created.first.isClosed, isTrue);
      expect(created.last.acceptsSessionFence(oldFence), isFalse);
      expect(find.text('Sanatçı fresh'), findsOneWidget);
      old.complete(Result.success(_page([_profile('stale')])));
      await tester.pumpAndSettle();
      expect(find.text('Sanatçı stale'), findsNothing);
      for (final session in [
        audienceSession(user: 'studio-owner', token: 'new-token'),
        ..._ineligibleSessions(),
        audienceSession(roles: ['ROLE_STUDIO', 'ROLE_LISTENER']),
      ]) {
        sessions.replace(session);
        await tester.pumpAndSettle();
        expect(find.byType(MusicianFeedView), findsNothing);
        expect(find.text('Sanatçı fresh'), findsNothing);
        expect(created, hasLength(2));
      }
      expect(created.last.isClosed, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

AuthSession _studio({String token = 'token', String status = 'ACTIVE'}) =>
    audienceSession(
      user: 'studio-owner',
      token: token,
      role: 'ROLE_STUDIO',
      status: status,
    );
AudienceTestSessions _sessions() => AudienceTestSessions(_studio());
List<AuthSession> _ineligibleSessions() => [
  const AuthSession.guest(),
  _studio(status: 'PENDING_STUDIO_REQUEST'),
  _studio(status: 'REJECTED_STUDIO_REQUEST'),
  _studio(status: 'SUSPENDED'),
  _studio(token: ''),
  audienceSession(user: '', role: 'ROLE_STUDIO'),
];

Map<String, Object?> _wirePage(List<Object?> items, {String? cursor}) => {
  'schemaVersion': 1,
  'algorithmVersion': 'studio-v1.0.0',
  'feedSessionId': 'feed-session',
  'generatedAt': '2026-09-14T00:00:00Z',
  'items': items,
  'nextCursor': cursor,
  'hasMore': cursor != null,
};
Map<String, Object?> _wireItem(
  String id, {
  String type = 'TRACK',
  String author = 'MUSICIAN',
  Map<String, Object?>? payload,
}) => {
  'id': id,
  'type': type,
  'payloadVersion': 1,
  'occurredAt': '2026-09-14T00:00:00Z',
  'position': 0,
  'impressionToken': 'signed-$id',
  'reason': {
    'code': 'CITY_MATCH',
    'actors': <Object?>[],
    'secondaryActorCount': 0,
  },
  'author': {
    'profileType': author,
    'profileId': 'author-id',
    'username': 'Yayıncı',
    'displayName': 'Yayıncı',
    'followedByViewer': false,
  },
  'target': {'type': 'MEDIA', 'id': id},
  'feedbackCapabilities': ['HIDE', 'SHOW_LESS', 'REPORT'],
  'payload':
      payload ??
      {
        'trackId': id,
        'mediaAssetId': id,
        'title': 'Kayıt',
        'playbackUrl': null,
        'contentAudience': 'BACKSTAGE',
      },
};
Map<String, Object?> _mutedPage() => {
  'items': [
    {
      'profileType': 'MUSICIAN',
      'profileId': 'artist',
      'available': true,
      'mutedAt': '2026-09-14T00:00:00Z',
      'displayName': 'Sanatçı',
      'avatarUrl': null,
    },
  ],
  'nextCursor': null,
  'hasMore': false,
};

MusicianFeedPage _page(List<MusicianFeedItem> items, {String? cursor}) =>
    MusicianFeedPage(
      schemaVersion: 1,
      algorithmVersion: 'studio-v1.0.0',
      feedSessionId: 'feed-session',
      generatedAt: DateTime.utc(2026, 9, 14),
      items: items,
      nextCursor: cursor,
      hasMore: cursor != null,
    );
MusicianFeedItem _completion(String id) => MusicianFeedItem.fromJson(
  _wireItem(
    id,
    type: 'PROFILE_COMPLETION',
    payload: {'completed': 0, 'total': 1, 'tasks': <Object?>[]},
  ),
);
MusicianFeedItem _profile(String id) => MusicianFeedItem.fromJson(
  _wireItem(
    id,
    type: 'PROFILE',
    payload: {
      'profileId': id,
      'profileType': 'MUSICIAN',
      'userId': 'user-$id',
      'username': 'Sanatçı $id',
      'displayName': 'Sanatçı $id',
      'followedByViewer': false,
    },
  ),
);

MusicianFeedCubit _cubit(
  MusicianFeedRepository repository,
  AuthSessionManager sessions,
) => MusicianFeedCubit(
  repository,
  _Engagement(),
  collabRepository: _Collab(),
  followRepository: _Follow(),
  bandFollowRepository: _BandFollow(),
  sessions: sessions,
);
void _register(
  AudienceTestSessions sessions,
  MusicianFeedCubit Function() factory,
) {
  serviceLocator.registerSingleton<AuthSessionManager>(sessions);
  serviceLocator.registerSingleton<DmBadgeCubit>(_Badges());
  serviceLocator.registerFactory<MusicianFeedCubit>(factory);
}

Widget _home({Map<String, WidgetBuilder> routes = const {}}) =>
    BlocProvider<NotificationCubit>.value(
      value: _Notifications(),
      child: MaterialApp(
        theme: AppTheme.navy,
        routes: routes,
        home: const BackstageProfilesHomeScreen(),
      ),
    );

class _Feed extends Fake implements MusicianFeedRepository {
  _Feed(this.pages);
  final List<MusicianFeedPage> pages;
  final List<String?> cursors = [];
  Future<Result<MusicianFeedPage>> Function()? onLoad;
  @override
  Future<Result<MusicianFeedPage>> load({required int limit, String? cursor}) {
    cursors.add(cursor);
    return onLoad?.call() ??
        Future.value(Result.success(pages[cursors.length - 1]));
  }

  @override
  Future<Result<void>> recordEvent({
    required String clientEventId,
    required String impressionToken,
    required MusicianFeedTelemetryEventType eventType,
    DateTime? occurredAt,
  }) async => const Result.success(null);
}

class _Engagement extends Fake implements EngagementRepository {}

class _Collab extends Fake implements CollabRepository {}

class _Follow extends Fake implements FollowRepository {}

class _BandFollow extends Fake implements BandFollowRepository {}

class _Badges extends Fake implements DmBadgeCubit {
  @override
  DmBadgeState get state => const DmBadgeState.initial();
  @override
  Stream<DmBadgeState> get stream => const Stream.empty();
  @override
  Future<void> ensureStarted() async {}
}

class _Notifications extends Fake implements NotificationCubit {
  @override
  NotificationState get state => const NotificationState.initial();
  @override
  Stream<NotificationState> get stream => const Stream.empty();
}
