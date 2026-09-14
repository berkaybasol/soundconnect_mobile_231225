import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_route_guard.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/policy/stage_mode.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/collab_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_badge_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_badge_state.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/engagement_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/follow/domain/band_follow_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/follow/domain/follow_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/data/musician_feed_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/data/musician_feed_muted_authors_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/domain/backstage_feed_session.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/domain/feed_item_access.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/domain/musician_feed_models.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/domain/musician_feed_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/presentation/cubit/musician_feed_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/presentation/navigation/musician_feed_navigation_coordinator.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/presentation/screens/listener_feed_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/presentation/screens/musician_feed_view.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/cubit/notification_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/cubit/notification_state.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/presentation/screens/overthinking_feed_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/profile_search_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/profile_search_result.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/profile_search_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/backstage_profile_search_sheet.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/presentation/screens/table_group_detail_screen.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';

import 'support/event_audience_fakes.dart';
import 'support/recording_api_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() async => serviceLocator.reset());

  test(
    'listener audience accepts aliases and rejects mixed personal roles',
    () {
      for (final roles in [
        ['LISTENER'],
        ['ROLE_LISTENER', 'LISTENER'],
        ['LISTENER', 'ROLE_ADMIN'],
      ]) {
        expect(
          backstageFeedSessionIdentity(audienceSession(roles: roles))?.audience,
          BackstageFeedAudience.listener,
        );
      }
      for (final other in [
        'MUSICIAN',
        'VENUE',
        'STUDIO',
        'ORGANIZER',
        'PRODUCER',
      ]) {
        expect(
          backstageFeedSessionIdentity(
            audienceSession(roles: ['LISTENER', other]),
          ),
          isNull,
        );
      }
    },
  );

  test(
    'listener read uses its endpoint and filters mixed responses without losing cursor',
    () async {
      final sessions = AudienceTestSessions(audienceSession());
      addTearDown(sessions.dispose);
      final api = RecordingApiClient(
        (_) => _wirePage([
          _wireItem('music'),
          _wireItem('studio', author: 'STUDIO'),
          _wireItem('business', payload: _track(audience: 'BACKSTAGE')),
          _wireItem(
            'collab',
            type: 'COLLAB',
            payload: {'listing': <String, dynamic>{}},
          ),
        ], cursor: 'next-page'),
      );
      final result = await MusicianFeedRepositoryImpl(
        api,
        sessions,
      ).load(limit: 20);
      expect(result.isSuccess, isTrue);
      expect(result.data!.items.map((item) => item.id), ['music']);
      expect(result.data!.nextCursor, 'next-page');
      expect(result.data!.hasMore, isTrue);
      expect(api.lastRequest.path, '/api/v1/feed/listener');
      final types = (api.lastRequest.query!['supportedItemTypes'] as String)
          .split(',');
      expect(
        types,
        containsAll([
          'TRACK',
          'PROFILE_MEDIA',
          'EVENT',
          'EVENT_PROFILE_SHARE',
          'OVERTHINKING_PROFILE_SHARE',
          'TABLEGROUP_PROFILE_SHARE',
          'ACTIVITY_COMMENT',
          'ANNOUNCEMENT',
        ]),
      );
      expect(types, isNot(contains('COLLAB')));
      expect(types, isNot(contains('PROFILE_COMPLETION')));
      expect(types, isNot(contains('SPONSORED')));
      expect(api.lastRequest.requestContext!.expectedSessionKey, 'listener');
      expect(api.lastRequest.requestContext!.expectedToken, 'token');
    },
  );

  test(
    'listener feedback telemetry mute and management use the shared scoped API',
    () async {
      final sessions = AudienceTestSessions(audienceSession());
      addTearDown(sessions.dispose);
      final api = RecordingApiClient(
        (request) => request.path.endsWith('/muted-authors')
            ? {'items': <Object?>[], 'hasMore': false, 'nextCursor': null}
            : null,
      );
      final feed = MusicianFeedRepositoryImpl(api, sessions);
      expect(
        (await feed.sendFeedback(
          itemId: 'TRACK:one',
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
      final muted = MusicianFeedMutedAuthorsRepositoryImpl(api, sessions);
      expect((await muted.load()).isSuccess, isTrue);
      expect(
        (await muted.unmute(
          profileType: 'MUSICIAN',
          profileId: 'artist',
        )).isSuccess,
        isTrue,
      );
      expect(api.requests.map((r) => r.path), [
        '/api/v1/feed/listener/items/TRACK%3Aone/feedback',
        '/api/v1/feed/listener/events',
        '/api/v1/feed/listener/authors/MUSICIAN/artist/mute',
        '/api/v1/feed/listener/muted-authors',
        '/api/v1/feed/listener/authors/MUSICIAN/artist/mute',
      ]);
    },
  );

  test(
    'same credentials cannot accept listener responses after a role change',
    () async {
      final sessions = AudienceTestSessions(audienceSession());
      addTearDown(sessions.dispose);
      final read = Completer<Object?>();
      final write = Completer<Object?>();
      final api = RecordingApiClient(
        (r) => r.method == RecordedHttpMethod.get ? read.future : write.future,
      );
      final repository = MusicianFeedRepositoryImpl(api, sessions);
      final loading = repository.load(limit: 20);
      final muting = repository.muteAuthor(
        profileType: 'MUSICIAN',
        profileId: 'artist',
      );
      sessions.replace(audienceSession(role: 'VENUE'));
      read.complete(_wirePage([_wireItem('old')]));
      write.complete(null);
      expect((await loading).error!.code, 'musician_feed_session_changed');
      expect((await muting).error!.code, 'musician_feed_session_changed');
    },
  );

  test(
    'shared Cubit filters each listener page while retaining public social shares',
    () async {
      final sessions = AudienceTestSessions(audienceSession());
      addTearDown(sessions.dispose);
      MusicianFeedItem item(
        String id, {
        String author = 'MUSICIAN',
        String? audience,
      }) => MusicianFeedItem.fromJson(
        _wireItem(
          id,
          author: author,
          payload: _track(audience: audience),
        ),
      );
      final share = MusicianFeedItem.fromJson(
        _wireItem(
          'public-share',
          author: 'LISTENER',
          type: 'TABLEGROUP_PROFILE_SHARE',
          payload: _share({'tableGroupId': 'table'}),
        ),
      );
      final cubit = _cubit(
        _Feed([
          _page([
            item('music'),
            item('studio', author: 'STUDIO'),
          ], cursor: 'page-2'),
          _page([share, item('business', audience: 'BACKSTAGE')]),
        ]),
        sessions,
      );
      addTearDown(cubit.close);
      await cubit.initialize();
      expect(cubit.state.items.map((item) => item.id), ['music']);
      expect(cubit.state.nextCursor, 'page-2');
      await cubit.loadMore();
      expect(cubit.state.items.map((item) => item.id), [
        'music',
        'public-share',
      ]);
      expect(cubit.state.feedSessionId, 'feed');
      expect(cubit.state.hasMore, isFalse);
    },
  );

  test(
    'listener excludes nested professional targets and studio social actors',
    () {
      final targets = <(String, Map<String, dynamic>)>[
        ('COLLAB', {'listing': <String, dynamic>{}}),
        ('TRACK', _track(audience: 'BACKSTAGE')),
        ('PROFILE', _profile('STUDIO')),
        (
          'TABLEGROUP_PROFILE_SHARE',
          _share({
            'id': 'table',
            'publisher': {'profileType': 'STUDIO'},
          }),
        ),
        (
          'OVERTHINKING_PROFILE_SHARE',
          _share({'id': 'post', 'contentAudience': 'BACKSTAGE'}),
        ),
      ];
      for (final target in targets) {
        final item = MusicianFeedItem.fromJson(
          _wireItem(
            'activity',
            type: 'ACTIVITY_COMMENT',
            payload: {
              'action': 'COMMENT',
              'actor': _actor('LISTENER'),
              'targetItemType': target.$1,
              'targetPayload': target.$2,
            },
          ),
        );
        expect(
          feedCanShowItem(BackstageFeedAudience.listener, item),
          isFalse,
          reason: target.$1,
        );
        expect(feedCanShowItem(BackstageFeedAudience.musician, item), isTrue);
      }
      final studioActor = MusicianFeedItem.fromJson(
        _wireItem(
          'activity',
          type: 'ACTIVITY_LIKE',
          payload: {
            'action': 'LIKE',
            'actor': _actor('STUDIO'),
            'targetItemType': 'TRACK',
            'targetPayload': _track(),
          },
        ),
      );
      expect(
        feedCanShowItem(BackstageFeedAudience.listener, studioActor),
        isFalse,
      );
    },
  );

  test('listener announcement projections require the listener audience', () {
    for (final targets in <List<String>>[
      ['MUSICIAN', 'VENUE'],
      ['LISTENER'],
      ['LISTENER', 'MUSICIAN'],
    ]) {
      final item = MusicianFeedItem.fromJson(
        _wireItem(
          'announcement',
          type: 'ANNOUNCEMENT',
          payload: {
            'id': 'bde0eb94-c6d9-42aa-ae0e-8d16a8d374da',
            'version': 1,
            'title': 'SoundConnect',
            'body': 'Birlikte müzik.',
            'targetProfiles': targets,
            'status': 'PUBLISHED',
            'createdAt': '2026-09-14T00:00:00Z',
            'updatedAt': '2026-09-14T00:00:00Z',
          },
        ),
      );
      expect(
        feedCanShowItem(BackstageFeedAudience.listener, item),
        targets.contains('LISTENER'),
      );
      expect(feedCanShowItem(BackstageFeedAudience.musician, item), isTrue);
    }
  });

  test(
    'explicit null or unknown source audience cannot become legacy music',
    () {
      for (final audience in [null, 'UNKNOWN', 'BACKSTAGE']) {
        for (final target in <(String, Map<String, dynamic>)>[
          ('TRACK', {..._track(), 'contentAudience': audience}),
          (
            'PROFILE_MEDIA',
            {
              'mediaAssetId': 'media',
              'kind': 'VIDEO',
              'contentAudience': audience,
            },
          ),
          (
            'OVERTHINKING_PROFILE_SHARE',
            _share({
              'id': 'thought',
              'source': {'contentAudience': audience},
            }),
          ),
        ]) {
          final item = MusicianFeedItem.fromJson(
            _wireItem('source', type: target.$1, payload: target.$2),
          );
          expect(
            feedCanShowItem(BackstageFeedAudience.listener, item),
            isFalse,
          );
          expect(feedCanShowItem(BackstageFeedAudience.musician, item), isTrue);
        }
      }
    },
  );

  test('public listener source shares and legacy music remain eligible', () {
    for (final target in [
      'OVERTHINKING_PROFILE_SHARE',
      'TABLEGROUP_PROFILE_SHARE',
    ]) {
      final item = MusicianFeedItem.fromJson(
        _wireItem(
          target,
          author: 'LISTENER',
          type: target,
          payload: _share({'id': 'source'}),
        ),
      );
      expect(feedCanShowItem(BackstageFeedAudience.listener, item), isTrue);
    }
    final event = MusicianFeedItem.fromJson(
      _wireItem(
        'event',
        type: 'EVENT_PROFILE_SHARE',
        author: 'LISTENER',
        payload: {
          'event': {'id': 'event'},
          'publicationId': 'published-post',
        },
      ),
    );
    expect(feedCanShowItem(BackstageFeedAudience.listener, event), isTrue);
    expect(
      feedCanShowItem(
        BackstageFeedAudience.listener,
        MusicianFeedItem.fromJson(_wireItem('legacy-music')),
      ),
      isTrue,
    );
    expect(
      feedCanShowItem(
        BackstageFeedAudience.listener,
        MusicianFeedItem.fromJson(
          _wireItem('unknown', payload: _track(audience: 'UNKNOWN')),
        ),
      ),
      isFalse,
    );
  });

  test(
    'listener routing rejects studio and collab but allows feed and mute management',
    () {
      final session = audienceSession();
      for (final route in [
        AppRoutes.studioPublicProfile,
        AppRoutes.studioProfile,
        AppRoutes.studioReservationCalendar,
        AppRoutes.collabDiscovery,
      ]) {
        expect(
          AppRouteGuard.redirectFor(route, session),
          AppRoutes.listenerProfile,
        );
      }
      expect(
        AppRouteGuard.redirectFor(AppRoutes.listenerFeed, session),
        isNull,
      );
      expect(
        AppRouteGuard.redirectFor(AppRoutes.musicianFeedMutedAuthors, session),
        isNull,
      );
      expect(
        AppRouteGuard.redirectFor(
          AppRoutes.listenerFeed,
          audienceSession(role: 'MUSICIAN'),
        ),
        AppRoutes.home,
      );
    },
  );

  test(
    'listener search removes studios in request and response, preserving public listener visibility',
    () async {
      final sessions = AudienceTestSessions(audienceSession());
      addTearDown(sessions.dispose);
      final api = RecordingApiClient(
        (_) => [
          {'type': 'STUDIO', 'targetId': 'studio', 'title': 'Hidden Studio'},
          {'type': 'MUSICIAN', 'targetId': 'artist', 'title': 'Artist'},
          {
            'type': 'LISTENER',
            'targetId': 'ghost',
            'title': 'Ghost',
            'visibilityMode': 'GHOST',
          },
        ],
      );
      final repository = ProfileSearchRepositoryImpl(api, sessions: sessions);
      final result = await repository.searchProfiles('  ankara  ');
      expect(result.data!.map((item) => item.type), [
        ProfileSearchResultType.musician,
        ProfileSearchResultType.listener,
      ]);
      expect(result.data!.last.isGhostListener, isTrue);
      expect(api.lastRequest.query, {
        'q': 'ankara',
        'limit': 20,
        'types': 'BAND,LISTENER,MUSICIAN,VENUE',
      });
      await repository.searchProfiles(
        'studio',
        types: {ProfileSearchResultType.studio},
      );
      expect(api.requests, hasLength(1));
      final emptyScope = await repository.searchProfiles('ankara', types: {});
      expect(emptyScope.data!.map((item) => item.type), [
        ProfileSearchResultType.musician,
        ProfileSearchResultType.listener,
      ]);
      expect(api.requests, hasLength(2));
    },
  );

  test('late search cannot return a previous audience result', () async {
    final sessions = AudienceTestSessions(audienceSession(role: 'MUSICIAN'));
    addTearDown(sessions.dispose);
    final delayed = Completer<Object?>();
    final repository = ProfileSearchRepositoryImpl(
      RecordingApiClient((_) => delayed.future),
      sessions: sessions,
    );
    final search = repository.searchProfiles('studio');
    sessions.replace(audienceSession());
    delayed.complete([
      {'type': 'STUDIO', 'targetId': 'studio', 'title': 'Studio'},
    ]);
    expect((await search).error!.code, 'profile_search_session_changed');
  });

  testWidgets(
    'listener feed keeps all five Mainstage destinations and Keşfet navigation',
    (tester) async {
      final sessions = AudienceTestSessions(audienceSession());
      addTearDown(sessions.dispose);
      serviceLocator.registerSingleton<AuthSessionManager>(sessions);
      serviceLocator.registerSingleton<DmBadgeCubit>(_Badges());
      serviceLocator.registerFactory<MusicianFeedCubit>(
        () => _cubit(_Feed([_page([])]), sessions),
      );
      await tester.pumpWidget(
        BlocProvider<NotificationCubit>.value(
          value: _Notifications(),
          child: MaterialApp(
            theme: AppTheme.navy,
            routes: {
              AppRoutes.eventDiscovery: (_) =>
                  const Scaffold(body: Text('Etkinlik araması')),
            },
            home: const ListenerFeedScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MusicianFeedView), findsOneWidget);
      expect(find.text('Akışın henüz sessiz'), findsOneWidget);
      final bar = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar),
      );
      expect(bar.items.map((item) => item.label), [
        'Keşfet',
        'Overthinking',
        'Müzik Birleştirir!',
        'Mesajlar',
        'Profil',
      ]);
      expect(find.textContaining('stüdyo'), findsNothing);
      await tester.tap(find.text('Keşfet'));
      await tester.pumpAndSettle();
      expect(find.text('Etkinlik araması'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'listener feed replaces old account Cubit and ignores delayed page',
    (tester) async {
      final sessions = AudienceTestSessions(audienceSession());
      addTearDown(sessions.dispose);
      serviceLocator.registerSingleton<AuthSessionManager>(sessions);
      serviceLocator.registerSingleton<DmBadgeCubit>(_Badges());
      final delayed = Completer<Result<MusicianFeedPage>>();
      final cubits = <MusicianFeedCubit>[];
      serviceLocator.registerFactory<MusicianFeedCubit>(() {
        final repository = _Feed([]);
        // Capture the account's repository work independently of the next factory call.
        final first = cubits.isEmpty;
        repository.onLoad = () =>
            first ? delayed.future : Future.value(Result.success(_page([])));
        final cubit = _cubit(repository, sessions);
        cubits.add(cubit);
        return cubit;
      });
      await tester.pumpWidget(
        BlocProvider<NotificationCubit>.value(
          value: _Notifications(),
          child: MaterialApp(
            theme: AppTheme.navy,
            home: const ListenerFeedScreen(),
          ),
        ),
      );
      await tester.pump();
      sessions.replace(
        audienceSession(user: 'other-listener', token: 'other-token'),
      );
      await tester.pumpAndSettle();
      expect(cubits, hasLength(2));
      expect(cubits.first.isClosed, isTrue);
      delayed.complete(
        Result.success(_page([MusicianFeedItem.fromJson(_wireItem('old'))])),
      );
      await tester.pumpAndSettle();
      expect(cubits.last.state.items, isEmpty);
      sessions.replace(audienceSession(role: 'VENUE'));
      await tester.pumpAndSettle();
      expect(find.byType(MusicianFeedView), findsNothing);
      expect(cubits.last.isClosed, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'shared navigation uses Mainstage source routes and blocks professional callbacks',
    (tester) async {
      final sessions = AudienceTestSessions(audienceSession());
      addTearDown(sessions.dispose);
      final cubit = _cubit(_Feed([]), sessions);
      addTearDown(cubit.close);
      late BuildContext feedContext;
      final routes = <RouteSettings>[];
      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: (settings) {
            routes.add(settings);
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const Scaffold(body: Text('Kaynak')),
            );
          },
          home: BlocProvider.value(
            value: cubit,
            child: Builder(
              builder: (context) {
                feedContext = context;
                return const Scaffold();
              },
            ),
          ),
        ),
      );
      final navigation = MusicianFeedNavigationCoordinator(
        context: feedContext,
        cubit: cubit,
      );
      final table = MusicianFeedItem.fromJson(
        _wireItem(
          'table',
          type: 'TABLEGROUP_PROFILE_SHARE',
          payload: _share({'tableGroupId': 'table'}),
        ),
      );
      unawaited(
        navigation.openProfileShare(
          table,
          table.payload as ProfileShareFeedPayload,
          table.type,
        ),
      );
      await tester.pumpAndSettle();
      expect(routes.last.name, AppRoutes.tableGroupDetail);
      expect(
        (routes.last.arguments as TableGroupDetailArgs).bottomBarStageMode,
        StageMode.mainstage,
      );
      Navigator.of(feedContext).pop();
      await tester.pumpAndSettle();
      final thought = MusicianFeedItem.fromJson(
        _wireItem(
          'thought',
          type: 'OVERTHINKING_PROFILE_SHARE',
          payload: _share({}),
        ),
      );
      unawaited(
        navigation.openProfileShare(
          thought,
          thought.payload as ProfileShareFeedPayload,
          thought.type,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        (routes.last.arguments as OverthinkingFeedArgs).bottomBarStageMode,
        StageMode.mainstage,
      );
      Navigator.of(feedContext).pop();
      await tester.pumpAndSettle();
      final count = routes.length;
      await navigation.openProfile(
        ProfileFeedPayload.fromJson(_profile('STUDIO'), 'profile'),
      );
      final collab = MusicianFeedItem.fromJson(
        _wireItem(
          'collab',
          type: 'COLLAB',
          payload: {'listing': <String, dynamic>{}},
        ),
      );
      await navigation.openCollab(collab, collab.payload as CollabFeedPayload);
      sessions.replace(audienceSession(role: 'VENUE'));
      await navigation.openProfileShare(
        table,
        table.payload as ProfileShareFeedPayload,
        table.type,
      );
      expect(routes, hasLength(count));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'listener profile search keeps debounce and filters stale studio projections',
    (tester) async {
      final sessions = AudienceTestSessions(audienceSession());
      addTearDown(sessions.dispose);
      serviceLocator.registerSingleton<AuthSessionManager>(sessions);
      final search = _Search();
      serviceLocator.registerSingleton<ProfileSearchRepository>(search);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.navy,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showBackstageProfileSearch(context),
                child: const Text('Ara'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Ara'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'san');
      await tester.pump(const Duration(milliseconds: 299));
      expect(search.calls, 0);
      await tester.pump(const Duration(milliseconds: 2));
      await tester.pumpAndSettle();
      expect(search.calls, 1);
      expect(search.types, isNot(contains(ProfileSearchResultType.studio)));
      expect(find.text('Hidden studio'), findsNothing);
      expect(find.text('Visible artist'), findsOneWidget);
      sessions.replace(audienceSession(user: 'other'));
      await tester.pumpAndSettle();
      expect(find.text('Visible artist'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

Map<String, dynamic> _wirePage(List<Object?> items, {String? cursor}) => {
  'schemaVersion': 1,
  'algorithmVersion': 'listener-v1.0.0',
  'feedSessionId': 'feed',
  'generatedAt': '2026-09-14T00:00:00Z',
  'items': items,
  'hasMore': cursor != null,
  'nextCursor': cursor,
};
Map<String, dynamic> _actor(String type) => {
  'userId': 'author',
  'profileId': 'profile',
  'profileType': type,
  'username': 'artist',
  'displayName': 'Artist',
  'followedByViewer': true,
};
Map<String, dynamic> _track({String? audience}) => {
  'trackId': 'track',
  'mediaAssetId': 'media',
  'title': 'Song',
  if (audience != null) 'contentAudience': audience,
};
Map<String, dynamic> _profile(String type) => {
  'profileId': 'profile',
  'profileType': type,
  'userId': 'artist',
  'username': 'artist',
  'displayName': 'Artist',
  'followedByViewer': true,
};
Map<String, dynamic> _share(Map<String, dynamic> source) => {
  'shareId': 'share',
  'publishedAt': '2026-09-14T00:00:00Z',
  'source': source,
};
Map<String, dynamic> _wireItem(
  String id, {
  String type = 'TRACK',
  String author = 'MUSICIAN',
  Map<String, dynamic>? payload,
}) => {
  'id': id,
  'type': type,
  'payloadVersion': 1,
  'occurredAt': '2026-09-14T00:00:00Z',
  'position': 0,
  'impressionToken': 'signed-$id',
  'reason': {
    'code': 'DISCOVERY',
    'actors': <Object?>[],
    'secondaryActorCount': 0,
  },
  'author': _actor(author),
  'feedbackCapabilities': <String>[],
  'payload': payload ?? _track(),
};
MusicianFeedPage _page(List<MusicianFeedItem> items, {String? cursor}) =>
    MusicianFeedPage(
      schemaVersion: 1,
      algorithmVersion: 'listener-v1.0.0',
      feedSessionId: 'feed',
      generatedAt: DateTime.utc(2026, 9, 14),
      items: items,
      nextCursor: cursor,
      hasMore: cursor != null,
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

class _Feed extends Fake implements MusicianFeedRepository {
  _Feed(this.pages);
  final List<MusicianFeedPage> pages;
  Future<Result<MusicianFeedPage>> Function()? onLoad;
  int reads = 0;
  @override
  Future<Result<MusicianFeedPage>> load({required int limit, String? cursor}) =>
      onLoad?.call() ?? Future.value(Result.success(pages[reads++]));
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

class _Search extends Fake implements ProfileSearchRepository {
  int calls = 0;
  Set<ProfileSearchResultType>? types;
  @override
  Future<Result<List<ProfileSearchResult>>> searchProfiles(
    String query, {
    Set<ProfileSearchResultType>? types,
  }) async {
    calls++;
    this.types = types;
    return Result.success([
      ProfileSearchResult.fromJson({
        'type': 'STUDIO',
        'targetId': 'studio',
        'title': 'Hidden studio',
      }),
      ProfileSearchResult.fromJson({
        'type': 'MUSICIAN',
        'targetId': 'artist',
        'title': 'Visible artist',
      }),
    ]);
  }
}
