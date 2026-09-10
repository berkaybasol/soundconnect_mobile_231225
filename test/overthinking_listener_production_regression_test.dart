import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/engagement_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_page.dart';
import 'package:soundconnect_23_12_25codx/modules/event_audience/domain/event_audience_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/data/models/overthinking_post_model.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/data/overthinking_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/overthinking_profile_share_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/presentation/cubit/overthinking_feed_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/presentation/screens/overthinking_feed_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/venue_event_detail.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_event_post_card.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_event_post_engagement.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/presentation/cubit/interaction_stats_state.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_event_posts.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_overthinking_share_card.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/share/overthinking_share_service.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/share/overthinking_share_data.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/trusted_spotify_artwork.dart';

import 'support/event_audience_fakes.dart';

void main() {
  testWidgets(
    'fresh page projection replaces locally changed stats even when original values match',
    (tester) async {
      final sessions = AudienceTestSessions(audienceSession(user: 'viewer'));
      final repository = _Engagement();
      final firstProjection = Object();
      addTearDown(sessions.dispose);
      Widget host(Object projection) => MaterialApp(
        home: Scaffold(
          body: ListenerEventPostEngagement(
            postId: 'publication',
            repository: repository,
            sessions: sessions,
            canInteract: () => true,
            onError: (_) {},
            projectionKey: projection,
            initialStats: const InteractionStatsItemState(
              loading: false,
              likeCount: 4,
              commentCount: 2,
              isLiked: true,
            ),
            builder: (stats, toggle, refresh) => Column(
              children: [
                Text('${stats.likeCount}:${stats.isLiked}'),
                TextButton(onPressed: toggle, child: const Text('Toggle')),
              ],
            ),
          ),
        ),
      );
      await tester.pumpWidget(host(firstProjection));
      await tester.pumpAndSettle();
      expect(find.text('4:true'), findsOneWidget);
      expect(repository.reads, 0);
      await tester.tap(find.text('Toggle'));
      await tester.pumpAndSettle();
      expect(find.text('0:false'), findsOneWidget);
      await tester.pumpWidget(host(firstProjection));
      await tester.pumpAndSettle();
      expect(find.text('0:false'), findsOneWidget);
      await tester.pumpWidget(host(Object()));
      await tester.pumpAndSettle();
      expect(find.text('4:true'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'composer reconciles lost create response with same UUID and frozen payload',
    (tester) async {
      final api = _CommittedButLostResponse();
      final cubit = OverthinkingFeedCubit(
        overthinkingRepository: OverthinkingRepositoryImpl(api),
        engagementRepository: _Engagement(),
      );
      addTearDown(cubit.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => BlocProvider.value(
                      value: cubit,
                      child: const OverthinkingCreateScreen(),
                    ),
                  ),
                ),
                child: const Text('Compose'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Compose'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('overthinking-title')),
        'Same draft',
      );
      await tester.enterText(
        find.byKey(const ValueKey('overthinking-content')),
        'Same text',
      );
      final publish = find.byKey(const ValueKey('overthinking-publish'));
      await tester.scrollUntilVisible(
        publish,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(publish);
      await tester.pumpAndSettle();
      expect(api.committedBodies, hasLength(1));
      expect(api.receipts, hasLength(1));
      expect(find.text('Gönderimi doğrula'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('overthinking-title')),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('overthinking-title')))
            .readOnly,
        isTrue,
      );
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('overthinking-content')),
            )
            .readOnly,
        isTrue,
      );
      await tester.scrollUntilVisible(
        publish,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(publish);
      await tester.pumpAndSettle();
      expect(api.committedBodies, hasLength(2));
      expect(api.committedBodies[0], api.committedBodies[1]);
      expect(
        (api.committedBodies.first as Map)['clientRequestId'],
        matches(
          RegExp(
            r'^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$',
          ),
        ),
      );
      expect(api.receipts, hasLength(1));
      expect(cubit.state.posts.single.id, 'post-1');
      expect(find.text('Compose'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test('only the trusted Spotify CDN image path reaches export data', () {
    for (final url in [
      'https://attacker.invalid/a.jpg',
      'https://i.scdn.co.attacker.invalid/image/abc',
      'http://i.scdn.co/image/abc',
      'https://u@i.scdn.co/image/abc',
      'https://i.scdn.co:444/image/abc',
      'https://i.scdn.co/image/abc?reader=123',
      'https://i.scdn.co/image/abc#reader',
      'https://i.scdn.co/image/',
      'https://i.scdn.co/image/a/b',
      'https://i.scdn.co/image/%2fabc',
    ]) {
      expect(trustedSpotifyArtworkUrl(url), isNull, reason: url);
      final post = OverthinkingPostModel.fromJson({
        'id': 'post',
        'title': 'Title',
        'content': 'Text',
        'spotifyAlbumImageUrl': url,
      });
      expect(
        OverthinkingShareData.fromPost(post).albumImageUrl,
        isNull,
        reason: url,
      );
    }
    expect(
      trustedSpotifyArtworkUrl('https://i.scdn.co/image/album123'),
      'https://i.scdn.co/image/album123',
    );
    expect(
      trustedSpotifyArtworkUrl('https://i.scdn.co:443/image/album123'),
      'https://i.scdn.co/image/album123',
    );
  });

  testWidgets('feed never requests client supplied external artwork', (
    tester,
  ) async {
    const tracker = 'https://attacker.invalid/unique-reader-probe.jpg';
    final client = _ImageRequestRecorder();
    debugNetworkImageHttpClientProvider = () => client;
    final post = OverthinkingPostModel.fromJson({
      'id': 'post',
      'title': 'A title',
      'content': 'Some text',
      'anonymous': true,
      'visibilityType': 'ANONYMOUS',
      'canViewAuthor': false,
      'spotifyTrackName': 'Fake track',
      'spotifyTrackUrl':
          'https://open.spotify.com/track/0000000000000000000000',
      'spotifyAlbumImageUrl': tracker,
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OverthinkingPostCard(
            post: post,
            onTap: () {},
            onLike: () {},
            onComments: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    debugNetworkImageHttpClientProvider = null;
    expect(client.requests, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'enriched event rows use two source reads and mount only visible cards',
    (tester) async {
      final sessions = AudienceTestSessions(audienceSession(user: 'viewer'));
      final events = _Events();
      final shares = _Shares();
      final engagement = _Engagement();
      serviceLocator.registerSingleton<EngagementRepository>(engagement);
      addTearDown(() async {
        await serviceLocator.reset();
        sessions.dispose();
        events.signal.dispose();
        shares.signal.dispose();
      });
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                ListenerProfilePostsSection(
                  asSliver: true,
                  listenerProfileId: 'profile',
                  username: 'owner',
                  eventsRepository: events,
                  overthinkingRepository: shares,
                  sessions: sessions,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byType(ListenerEventPostCard).evaluate().length,
        inInclusiveRange(1, 4),
      );
      expect(events.listReads, 1);
      expect(shares.listReads, 1);
      expect(events.intentReads, 0);
      expect(engagement.reads, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test('requested external share store placeholder is preserved', () {
    expect(
      PlatformOverthinkingShareService.caption,
      contains('[Google Play URL’si buraya eklenecek]'),
    );
  });

  testWidgets(
    'return from source retains loaded second page and scroll offset',
    (tester) async {
      final sessions = AudienceTestSessions(audienceSession(user: 'viewer'));
      final events = _Events()..count = 0;
      final shares = _Shares()
        ..items = List.generate(
          12,
          (index) => OverthinkingProfileShare(
            shareId: 'share-$index',
            note: null,
            publishedAt: DateTime.utc(
              2026,
              9,
              10,
              12,
            ).subtract(Duration(minutes: index)),
            post: OverthinkingPostModel.fromJson({
              'id': 'post-$index',
              'title': 'Title $index',
              'content': 'Post text',
              'anonymous': true,
              'visibilityType': 'ANONYMOUS',
              'canViewAuthor': false,
            }),
          ),
        );
      var opened = 0;
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      addTearDown(() {
        sessions.dispose();
        events.signal.dispose();
        shares.signal.dispose();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              controller: scroll,
              child: ListenerProfilePostsSection(
                listenerProfileId: 'profile',
                username: 'owner',
                eventsRepository: events,
                overthinkingRepository: shares,
                sessions: sessions,
                onOpenSource: (_) async {
                  opened++;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ListenerOverthinkingShareCard), findsNWidgets(6));
      final more = find.byKey(const Key('listener-profile-posts-more'));
      await tester.ensureVisible(more);
      await tester.pumpAndSettle();
      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(find.byType(ListenerOverthinkingShareCard), findsNWidgets(12));
      final oldPost = find.byKey(
        const ValueKey('listener-overthinking-open-share-8'),
      );
      await tester.ensureVisible(oldPost);
      await tester.pumpAndSettle();
      final offsetBefore = scroll.offset;
      await tester.tap(oldPost);
      await tester.pumpAndSettle();
      expect(opened, 1);
      expect(find.byType(ListenerOverthinkingShareCard), findsNWidgets(12));
      expect(oldPost, findsOneWidget);
      expect(scroll.offset, closeTo(offsetBefore, 1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

class _ImageRequestRecorder extends Fake implements HttpClient {
  final requests = <Uri>[];
  @override
  Future<HttpClientRequest> getUrl(Uri uri) async {
    requests.add(uri);
    // No network is used: record the actual Image.network transport attempt.
    throw const SocketException('Audit recorder stops the request');
  }
}

class _CommittedButLostResponse extends Fake implements ApiClient {
  final committedBodies = <Object?>[];
  final receipts = <String, Map<String, dynamic>>{};
  @override
  Future<T> request<T>(
    ApiHttpMethod method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    T Function(Object?)? decoder,
    ApiRequestContext? requestContext,
  }) async {
    expect(method, ApiHttpMethod.post);
    committedBodies.add(body);
    final key = (body as Map)['clientRequestId'] as String;
    final saved = receipts.putIfAbsent(
      key,
      () => {
        'id': 'post-${receipts.length + 1}',
        'title': 'Same draft',
        'content': 'Same text',
      },
    );
    if (committedBodies.length == 1) {
      throw ApiException(
        const AppError(
          code: 'network',
          message: 'Connection lost after commit',
        ),
      );
    }
    return decoder!(saved);
  }
}

class _Engagement extends Fake implements EngagementRepository {
  int reads = 0;
  @override
  Future<Result<void>> unlike({
    required String targetType,
    required String targetId,
  }) async => const Result.success(null);
  @override
  Future<Result<int>> getLikeCount({
    required String targetType,
    required String targetId,
  }) async {
    reads++;
    return const Result.success(0);
  }

  @override
  Future<Result<bool>> isLiked({
    required String targetType,
    required String targetId,
  }) async {
    reads++;
    return const Result.success(false);
  }

  @override
  Future<Result<CommentPage>> listComments({
    required String targetType,
    required String targetId,
    int page = 0,
    int size = 20,
  }) async {
    reads++;
    return Result.success(
      CommentPage(items: const [], totalElements: 0, page: page, size: size),
    );
  }
}

class _Events extends Fake implements EventAudienceRepository {
  final signal = ValueNotifier(0);
  int count = 6;
  int listReads = 0;
  int intentReads = 0;
  @override
  ValueListenable<int> get changes => signal;
  @override
  Future<Result<EventAudienceState>> getIntent({
    required String eventId,
    required String expectedSessionKey,
  }) async {
    intentReads++;
    return Result.success(audienceState(eventId: eventId));
  }

  @override
  Future<Result<EventAudiencePage<EventAudiencePost>>> listPublic(
    String listenerProfileId, {
    String? expectedSessionKey,
    EventAudiencePeriod period = EventAudiencePeriod.all,
    int page = 0,
    int size = 20,
  }) async {
    listReads++;
    return Result.success(
      EventAudiencePage(
        items: List.generate(
          count,
          (index) => EventAudiencePost(
            engagement: const EventAudienceEngagement(
              likeCount: 4,
              commentCount: 2,
              likedByMe: true,
            ),
            viewerIntentState: audienceState(eventId: 'event-$index'),
            eventId: 'event-$index',
            postId: 'publication-$index',
            intent: EventAudienceStatus.going,
            note: null,
            publishedAt: DateTime.utc(2026, 9, 10, 12 - index),
            eventEnded: false,
            event: VenueEventDetail(
              id: 'event-$index',
              shareUrl: null,
              posterImage: null,
              performerName: 'Artist',
              musicianProfileId: null,
              title: 'Event $index',
              eventDate: DateTime.utc(2100, 1, 1),
              venueName: 'Venue',
            ),
          ),
        ),
        page: page,
        size: size,
        totalElements: count,
        totalPages: count == 0 ? 0 : 1,
        hasNext: false,
      ),
    );
  }
}

class _Shares extends Fake implements OverthinkingProfileShareRepository {
  final signal = ValueNotifier(0);
  List<OverthinkingProfileShare> items = [];
  int listReads = 0;
  @override
  ValueListenable<int> get changes => signal;
  @override
  Future<Result<Page<OverthinkingProfileShare>>> listProfile({
    required String profileId,
    required AuthSession expectedSession,
    int page = 0,
    int size = 20,
  }) async {
    listReads++;
    return Result.success(
      Page(
        items: items.skip(page * size).take(size).toList(),
        hasNext: (page + 1) * size < items.length,
      ),
    );
  }
}
