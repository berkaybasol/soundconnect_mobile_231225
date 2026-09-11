import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/collab_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/collab_types.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/engagement_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/follow/domain/band_follow_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/follow/domain/follow_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/analytics/presentation/widgets/analytics_exposure.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/data/musician_feed_preferences_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/data/musician_feed_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/domain/musician_feed_models.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/domain/musician_feed_preferences.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/domain/musician_feed_preferences_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/domain/musician_feed_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/presentation/cubit/musician_feed_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/presentation/cubit/musician_feed_state.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/presentation/navigation/musician_feed_navigation_coordinator.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/presentation/screens/musician_feed_view.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/presentation/widgets/musician_feed_content_cards.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/presentation/widgets/musician_feed_card_chrome.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/presentation/widgets/musician_feed_card_registry.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/presentation/widgets/musician_feed_opportunity_city_sheet.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/entities/city.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/location_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/musician_profile_screen.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';

import 'support/event_audience_fakes.dart';
import 'support/recording_api_client.dart';

void main() {
  group('musician feed wire contract', () {
    test('city search is Turkish-character tolerant and safely empty', () {
      const cities = [
        City(id: 'istanbul', name: 'İstanbul'),
        City(id: 'sanliurfa', name: 'Şanlıurfa'),
      ];

      expect(
        filterMusicianFeedOpportunityCities(
          cities,
          'istanbul',
        ).map((city) => city.id),
        ['istanbul'],
      );
      expect(
        filterMusicianFeedOpportunityCities(
          cities,
          'sanliurfa',
        ).map((city) => city.id),
        ['sanliurfa'],
      );
      expect(filterMusicianFeedOpportunityCities(cities, 'ankara'), isEmpty);
    });

    testWidgets(
      'city conflict reloads the version, preserves selection, and retries once',
      (tester) async {
        final preferences = _OpportunityCityPreferencesRepository(
          getResults: [
            Result.success(_feedPreferences(version: 3, cityId: 'istanbul')),
            Result.success(_feedPreferences(version: 4, cityId: 'izmir')),
          ],
          updateResults: [
            const Result.failure(
              AppError(code: '1317', message: 'Tercihler değişti.'),
            ),
            Result.success(_feedPreferences(version: 5, cityId: 'ankara')),
          ],
        );
        final location = _OpportunityCityLocationRepository();
        bool? changed;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.navy,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    changed = await showMusicianFeedOpportunityCitySheet(
                      context,
                      preferencesRepository: preferences,
                      locationRepository: location,
                    );
                  },
                  child: const Text('Şehir seçimini aç'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Şehir seçimini aç'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ankara'));
        await tester.pump();
        await tester.tap(find.text('Şehri kaydet'));
        await tester.pumpAndSettle();

        expect(preferences.updateCalls, [
          (cityId: 'ankara', expectedVersion: 3),
          (cityId: 'ankara', expectedVersion: 4),
        ]);
        expect(preferences.getCallCount, 2);
        expect(changed, isTrue);
        expect(find.text('Fırsat şehrin'), findsNothing);
      },
    );

    testWidgets('city conflict performs no more than one automatic retry', (
      tester,
    ) async {
      final preferences = _OpportunityCityPreferencesRepository(
        getResults: [
          Result.success(_feedPreferences(version: 8, cityId: 'istanbul')),
          Result.success(_feedPreferences(version: 9, cityId: 'izmir')),
        ],
        updateResults: const [
          Result.failure(AppError(code: '1317', message: 'Tercihler değişti.')),
          Result.failure(AppError(code: '1317', message: 'Yine değişti.')),
        ],
      );
      final location = _OpportunityCityLocationRepository();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.navy,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showMusicianFeedOpportunityCitySheet(
                  context,
                  preferencesRepository: preferences,
                  locationRepository: location,
                ),
                child: const Text('Şehir seçimini aç'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Şehir seçimini aç'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ankara'));
      await tester.pump();
      await tester.tap(find.text('Şehri kaydet'));
      await tester.pumpAndSettle();

      expect(preferences.updateCalls, [
        (cityId: 'ankara', expectedVersion: 8),
        (cityId: 'ankara', expectedVersion: 9),
      ]);
      expect(preferences.getCallCount, 2);
      expect(
        find.text(
          'Akış tercihlerin yeniden değişti. Seçimini koruduk; lütfen tekrar dene.',
        ),
        findsOneWidget,
      );
      expect(find.text('Ankara'), findsOneWidget);
    });

    test('parses the supported v1 payload families', () {
      final page = MusicianFeedPage.fromJson(
        _pageJson([
          _itemJson('track', 'TRACK', {
            'trackId': 'track-id',
            'mediaAssetId': 'media-id',
            'title': 'Gece Provası',
            'playbackUrl': 'https://cdn.soundconnect.test/track.mp3',
            'durationSeconds': 180,
            'bpm': 124,
          }),
          _itemJson('media', 'PROFILE_MEDIA', {
            'mediaAssetId': 'media-id',
            'kind': 'IMAGE',
            'displayUrl': 'https://cdn.soundconnect.test/photo.jpg',
            'playbackUrl': null,
            'thumbnailUrl': null,
            'title': 'Stüdyodan',
            'description': null,
            'durationSeconds': null,
            'width': 1080,
            'height': 1080,
          }),
          _itemJson('collab', 'COLLAB', {
            'listing': {'id': 'listing-id'},
          }),
          _itemJson('event', 'EVENT', {
            'event': {'id': 'event-id', 'title': 'Canlı Performans'},
            'note': null,
            'publicationId': null,
          }),
          _itemJson('event-share', 'EVENT_PROFILE_SHARE', {
            'event': {'id': 'event-id', 'title': 'Canlı Performans'},
            'note': 'Bu gece buradayım.',
            'publicationId': 'publication-id',
          }),
          _itemJson('ot-share', 'OVERTHINKING_PROFILE_SHARE', {
            'shareId': 'share-id',
            'note': 'Bunu konuşalım.',
            'publishedAt': '2026-09-11T10:00:00Z',
            'source': {'content': 'Turne sonrası sessizlik.'},
          }),
          _itemJson('table-share', 'TABLEGROUP_PROFILE_SHARE', {
            'shareId': 'table-share-id',
            'note': null,
            'publishedAt': '2026-09-11T10:00:00Z',
            'source': {'tableGroupId': 'table-id', 'title': 'Caz masası'},
          }),
          _itemJson('profile', 'PROFILE', {
            'profileId': 'profile-id',
            'profileType': 'STUDIO',
            'userId': 'user-id',
            'username': 'northstudio',
            'displayName': 'North Studio',
            'avatarUrl': null,
            'bio': 'Analog kayıt odası',
            'location': 'İstanbul',
            'followedByViewer': false,
          }),
          _itemJson('activity', 'ACTIVITY_LIKE', {
            'action': 'LIKE',
            'actor': _authorJson(),
            'targetItemType': 'PROFILE',
            'targetPayload': {
              'profileId': 'profile-id',
              'profileType': 'MUSICIAN',
              'userId': 'user-id',
              'username': 'deniz',
              'displayName': 'Deniz',
              'avatarUrl': null,
              'bio': null,
              'location': 'Ankara',
              'followedByViewer': false,
            },
          }),
          _itemJson('activity-follow', 'ACTIVITY_FOLLOW', {
            'action': 'FOLLOW',
            'actor': _authorJson(),
            'targetItemType': 'PROFILE',
            'targetPayload': {
              'profileId': 'followed-profile-id',
              'profileType': 'STUDIO',
              'userId': 'followed-user-id',
              'username': 'analogroom',
              'displayName': 'Analog Room',
              'avatarUrl': null,
              'bio': null,
              'location': 'İzmir',
              'followedByViewer': false,
            },
          }),
          _itemJson('activity-comment', 'ACTIVITY_COMMENT', {
            'action': 'COMMENT',
            'actor': _authorJson(),
            'targetItemType': 'PROFILE_MEDIA',
            'targetPayload': {
              'mediaAssetId': 'commented-media-id',
              'kind': 'IMAGE',
              'displayUrl': 'https://cdn.soundconnect.test/commented.jpg',
              'playbackUrl': null,
              'thumbnailUrl': null,
              'title': 'Konser sonrası',
              'description': null,
              'durationSeconds': null,
              'width': 1080,
              'height': 1080,
            },
          }),
          _itemJson('completion', 'PROFILE_COMPLETION', {
            'completed': 1,
            'total': 2,
            'tasks': [
              {
                'code': 'OPPORTUNITY_CITY',
                'title': 'Fırsat şehrini seç',
                'description': 'Yakınındaki fırsatları öne çıkaralım.',
                'ctaLabel': 'Şehir seç',
                'route': '/backstage/feed/preferences',
                'priority': 1,
                'complete': false,
              },
            ],
          }),
          _itemJson('sponsored', 'SPONSORED', {
            'title': 'Yeni backline serisi',
            'body': 'Turneye hazır ekipmanlar.',
            'mediaUrl': null,
            'ctaLabel': 'İncele',
            'ctaUrl': '/collab',
          }, promotion: true),
        ]),
      );

      expect(page.items, hasLength(13));
      expect(
        page.items.map((item) => item.type).toSet(),
        containsAll(MusicianFeedItemType.values),
      );
      expect(page.feedSessionId, 'session-id');
      expect(page.items.first.position, 0);
      expect(page.items.first.impressionToken, 'delivery-token-track');
    });

    test('requires a valid delivery position and impression token', () {
      final missingToken = _itemJson('missing-token', 'TRACK', {
        'trackId': 'track-id',
        'mediaAssetId': 'media-id',
        'title': 'Parça',
        'playbackUrl': null,
        'durationSeconds': null,
        'bpm': null,
      })..remove('impressionToken');
      final negativePosition = _itemJson('negative-position', 'TRACK', {
        'trackId': 'track-id',
        'mediaAssetId': 'media-id',
        'title': 'Parça',
        'playbackUrl': null,
        'durationSeconds': null,
        'bpm': null,
      })..['position'] = -1;

      expect(
        () => MusicianFeedPage.fromJson(_pageJson([missingToken])),
        throwsA(isA<MusicianFeedFormatException>()),
      );
      expect(
        () => MusicianFeedPage.fromJson(_pageJson([negativePosition])),
        throwsA(isA<MusicianFeedFormatException>()),
      );
    });

    test('standalone sponsor destinations accept HTTPS only', () {
      expect(
        parseMusicianFeedExternalPromotionUri(
          'https://sponsor.soundconnect.com/campaign',
        ),
        Uri.parse('https://sponsor.soundconnect.com/campaign'),
      );
      expect(
        parseMusicianFeedExternalPromotionUri(
          'http://sponsor.soundconnect.com/campaign',
        ),
        isNull,
      );
      expect(
        parseMusicianFeedExternalPromotionUri('//sponsor.soundconnect.com'),
        isNull,
      );
    });

    test('fails closed for an unknown item type', () {
      expect(
        () => MusicianFeedPage.fromJson(
          _pageJson([_itemJson('future', 'FUTURE_CARD', const {})]),
        ),
        throwsA(isA<MusicianFeedFormatException>()),
      );
    });

    test('requires a cursor whenever hasMore is true', () {
      final json = _pageJson(const [])
        ..['hasMore'] = true
        ..['nextCursor'] = null;
      expect(
        () => MusicianFeedPage.fromJson(json),
        throwsA(isA<MusicianFeedFormatException>()),
      );
    });

    test('ignores additive feedback capabilities it cannot execute', () {
      final item = _itemJson('track', 'TRACK', {
        'trackId': 'track-id',
        'mediaAssetId': 'media-id',
        'title': 'Parça',
        'playbackUrl': null,
        'durationSeconds': null,
        'bpm': null,
      })..['feedbackCapabilities'] = const ['HIDE', 'MUTE_AUTHOR'];

      final page = MusicianFeedPage.fromJson(_pageJson([item]));

      expect(page.items.single.feedbackCapabilities, {
        MusicianFeedFeedbackAction.hide,
      });
    });

    test('renders backend social and completion reason codes', () {
      expect(
        musicianFeedReasonLabel(
          MusicianFeedReason(
            code: 'FOLLOWED_USER_LIKED',
            actors: [MusicianFeedActor.fromJson(_authorJson(), path: 'actor')],
            secondaryActorCount: 2,
          ),
        ),
        'Deniz ve 2 kişi daha bunu beğendi',
      );
      expect(
        musicianFeedReasonLabel(
          const MusicianFeedReason(
            code: 'PROFILE_INCOMPLETE',
            actors: [],
            secondaryActorCount: 0,
          ),
        ),
        'Akışını sana göre şekillendir',
      );
    });

    test('promotion disclosure is normalized and never silently omitted', () {
      expect(musicianFeedPromotionDisclosureLabel(' sponsored '), 'Sponsorlu');
      expect(musicianFeedPromotionDisclosureLabel('featured'), 'Öne Çıkan');
      expect(
        musicianFeedPromotionDisclosureLabel('platform_announcement'),
        'SoundConnect duyurusu',
      );
      expect(
        musicianFeedPromotionDisclosureLabel('future_paid_format'),
        'Sponsorlu',
      );
    });

    test('fails soft when a reused nested card projection is malformed', () {
      expect(
        tryParseMusicianFeedCollab(const {'id': 'incomplete-listing'}),
        isNull,
      );
      expect(
        tryParseMusicianFeedEvent(const {
          'id': 'event-id',
          'title': 'Bozuk saatli etkinlik',
          'startTime': '99:15',
        }),
        isNull,
      );
    });

    test('accepts nullable event end time for native and shared cards', () {
      final page = MusicianFeedPage.fromJson(
        _pageJson([
          _itemJson('event-native', 'EVENT', {
            'event': {
              'id': 'event-native-id',
              'title': 'Açık bitiş saatli etkinlik',
              'startTime': '21:30',
              'endTime': null,
            },
            'note': null,
            'publicationId': null,
          }),
          _itemJson('event-share', 'EVENT_PROFILE_SHARE', {
            'event': {
              'id': 'event-share-id',
              'title': 'Paylaşılan etkinlik',
              'startTime': '22:00',
              'endTime': null,
            },
            'note': 'Sahnede görüşürüz.',
            'publicationId': 'publication-id',
          }),
        ]),
      );

      for (final item in page.items) {
        final payload = item.payload as EventFeedPayload;
        final event = tryParseMusicianFeedEvent(payload.event);
        expect(event, isNotNull, reason: item.id);
        expect(event!.endTime, isNull, reason: item.id);
      }
    });

    test(
      'resolves a safe Overthinking source for profile-share navigation',
      () {
        final base = ProfileShareFeedPayload(
          shareId: 'profile-share-id',
          note: null,
          publishedAt: DateTime.utc(2026, 9, 11),
          source: const {'id': 'source-post-id'},
        );
        final missing = ProfileShareFeedPayload(
          shareId: 'profile-share-id',
          note: null,
          publishedAt: DateTime.utc(2026, 9, 11),
          source: const {},
        );
        final oversized = ProfileShareFeedPayload(
          shareId: 'profile-share-id',
          note: null,
          publishedAt: DateTime.utc(2026, 9, 11),
          source: {'id': List.filled(129, 'x').join()},
        );

        expect(musicianFeedOverthinkingSourceId(base), 'source-post-id');
        expect(musicianFeedOverthinkingSourceId(missing), isNull);
        expect(musicianFeedOverthinkingSourceId(oversized), isNull);
      },
    );

    test(
      'card registry owns nested activity and promoted-native open dispatch',
      () async {
        final registry = MusicianFeedCardRegistry.standard();
        final navigation = _RecordingFeedNavigation();
        const actor = MusicianFeedActor(
          userId: 'actor-user',
          profileId: 'actor-profile',
          profileType: 'MUSICIAN',
          username: 'actor',
          displayName: 'Actor',
          avatarUrl: null,
          followedByViewer: true,
        );
        final activity = _registryItem(
          id: 'activity',
          type: MusicianFeedItemType.activityLike,
          payload: const ActivityFeedPayload(
            action: 'LIKE',
            actor: actor,
            targetItemType: MusicianFeedItemType.collab,
            targetPayload: CollabFeedPayload(listing: {'id': 'nested-collab'}),
          ),
        );
        final promotedEvent = _registryItem(
          id: 'promoted-event',
          type: MusicianFeedItemType.event,
          payload: const EventFeedPayload(
            event: {'id': 'event-id'},
            note: null,
            publicationId: null,
          ),
          promotion: const MusicianFeedPromotion(
            campaignId: 'campaign-id',
            disclosure: 'SPONSORED',
            ctaLabel: 'İncele',
            ctaUrl: '/events',
          ),
        );
        final profileShareActivity = _registryItem(
          id: 'profile-share-activity',
          type: MusicianFeedItemType.activityComment,
          payload: ActivityFeedPayload(
            action: 'COMMENT',
            actor: actor,
            targetItemType: MusicianFeedItemType.overthinkingProfileShare,
            targetPayload: ProfileShareFeedPayload(
              shareId: 'share-id',
              note: null,
              publishedAt: DateTime.utc(2026, 9, 11),
              source: const {'id': 'post-id'},
            ),
          ),
        );
        final sponsored = _registryItem(
          id: 'sponsored',
          type: MusicianFeedItemType.sponsored,
          payload: const SponsoredFeedPayload(
            title: 'Sponsor',
            body: 'İçerik',
            mediaUrl: null,
            ctaLabel: 'İncele',
            ctaUrl: 'https://sponsor.soundconnect.test',
          ),
        );
        final sponsoredActivity = _registryItem(
          id: 'sponsored-activity',
          type: MusicianFeedItemType.activityLike,
          payload: const ActivityFeedPayload(
            action: 'LIKE',
            actor: actor,
            targetItemType: MusicianFeedItemType.sponsored,
            targetPayload: SponsoredFeedPayload(
              title: 'Sponsor aktivitesi',
              body: 'İçerik',
              mediaUrl: null,
              ctaLabel: 'İncele',
              ctaUrl: 'https://nested.soundconnect.test',
            ),
          ),
        );

        await registry.open(navigation, activity);
        await registry.open(navigation, profileShareActivity);
        await registry.open(navigation, promotedEvent);
        await registry.open(navigation, sponsored);
        await registry.open(navigation, sponsoredActivity);

        expect(navigation.opened, [
          'collab',
          'share:overthinkingProfileShare',
          'event',
          'promotion',
          'promotion',
        ]);
        expect(navigation.promotionPayloadUrls, [
          'https://sponsor.soundconnect.test',
          'https://nested.soundconnect.test',
        ]);
        expect(navigation.recordedOpenIds, [
          'activity',
          'profile-share-activity',
          'promoted-event',
          'sponsored-activity',
        ]);
      },
    );

    test('Collab feed snapshot comparison covers every mutable card field', () {
      final snapshot = tryParseMusicianFeedCollab(
        (_validCollabFeedItem().payload as CollabFeedPayload).listing,
      )!;

      expect(musicianFeedCollabStateChanged(snapshot, snapshot), isFalse);
      for (final changed in [
        snapshot.copyWith(version: snapshot.version + 1),
        snapshot.copyWith(status: CollabListingStatus.closed),
        snapshot.copyWith(savedByMe: !snapshot.savedByMe),
        snapshot.copyWith(appliedByMe: !snapshot.appliedByMe),
        snapshot.copyWith(applicationCount: snapshot.applicationCount + 1),
      ]) {
        expect(musicianFeedCollabStateChanged(snapshot, changed), isTrue);
      }
    });
  });

  group('musician feed repositories', () {
    late AudienceTestSessions sessions;

    setUp(() {
      sessions = AudienceTestSessions(
        audienceSession(
          user: 'musician-id',
          token: 'token-a',
          role: 'ROLE_MUSICIAN',
        ),
      );
    });

    tearDown(() => sessions.dispose());

    test('sends bounded paging and the complete capability list', () async {
      final api = RecordingApiClient((_) => _pageJson(const []));
      final repository = MusicianFeedRepositoryImpl(api, sessions);

      final result = await repository.load(limit: 20, cursor: 'cursor-1');

      expect(result.isSuccess, isTrue);
      expect(api.lastRequest.path, '/api/v1/feed/musician');
      expect(api.lastRequest.query?['limit'], 20);
      expect(api.lastRequest.query?['cursor'], 'cursor-1');
      final supported = api.lastRequest.query?['supportedItemTypes'] as String;
      expect(
        supported.split(',').toSet(),
        MusicianFeedItemType.values.map((type) => type.apiValue).toSet(),
      );
      expect(api.lastRequest.requestContext?.expectedSessionKey, 'musician-id');
      expect(api.lastRequest.requestContext?.expectedToken, 'token-a');
    });

    test(
      'maps an absent initial feed endpoint to the rollout signal',
      () async {
        final api = RecordingApiClient(
          (_) => throw ApiException(
            const AppError(code: '404', message: 'Not Found'),
          ),
        );
        final repository = MusicianFeedRepositoryImpl(api, sessions);

        final result = await repository.load(limit: 20);

        expect(result.error?.code, musicianFeedFeatureUnavailableCode);
      },
    );

    test(
      'does not hide transient, auth, or paging errors as feature-off',
      () async {
        Future<Result<MusicianFeedPage>> loadWith(
          String code, {
          String? cursor,
        }) {
          final api = RecordingApiClient(
            (_) => throw ApiException(AppError(code: code, message: 'failure')),
          );
          return MusicianFeedRepositoryImpl(
            api,
            sessions,
          ).load(limit: 20, cursor: cursor);
        }

        expect((await loadWith('503')).error?.code, '503');
        expect((await loadWith('401')).error?.code, '401');
        expect((await loadWith('404', cursor: 'next-page')).error?.code, '404');
      },
    );

    test('maps only backend cursor-invalid 1318 on paged requests', () async {
      Future<Result<MusicianFeedPage>> loadWith(String code, {String? cursor}) {
        final api = RecordingApiClient(
          (_) => throw ApiException(AppError(code: code, message: 'failure')),
        );
        return MusicianFeedRepositoryImpl(
          api,
          sessions,
        ).load(limit: 20, cursor: cursor);
      }

      expect(
        (await loadWith('1318', cursor: 'stale')).error?.code,
        musicianFeedCursorInvalidCode,
      );
      expect((await loadWith('1318')).error?.code, '1318');
      expect((await loadWith('400', cursor: 'stale')).error?.code, '400');
    });

    test('drops a response after the authenticated identity changes', () async {
      final response = Completer<Object?>();
      final api = RecordingApiClient((_) => response.future);
      final repository = MusicianFeedRepositoryImpl(api, sessions);

      final pending = repository.load(limit: 20);
      sessions.replace(const AuthSession.guest());
      response.complete(_pageJson(const []));
      final result = await pending;

      expect(result.error?.code, 'musician_feed_session_changed');
    });

    test('uses the stable profile identity for author mute routes', () async {
      final api = RecordingApiClient((_) => null);
      final repository = MusicianFeedRepositoryImpl(api, sessions);

      final muted = await repository.muteAuthor(
        profileType: ' venue ',
        profileId: 'venue+istanbul',
      );
      final unmuted = await repository.unmuteAuthor(
        profileType: 'VENUE',
        profileId: 'venue+istanbul',
      );

      expect(muted.isSuccess, isTrue);
      expect(unmuted.isSuccess, isTrue);
      expect(api.requests[0].method, RecordedHttpMethod.put);
      expect(
        api.requests[0].path,
        '/api/v1/feed/musician/authors/VENUE/venue%2Bistanbul/mute',
      );
      expect(api.requests[1].method, RecordedHttpMethod.delete);
      expect(
        api.requests[1].path,
        '/api/v1/feed/musician/authors/VENUE/venue%2Bistanbul/mute',
      );
    });

    test('rejects unsupported or unsafe mute identities before I/O', () async {
      final api = RecordingApiClient((_) => null);
      final repository = MusicianFeedRepositoryImpl(api, sessions);

      final unsupported = await repository.muteAuthor(
        profileType: 'ORGANIZER',
        profileId: 'organizer-id',
      );
      final unsafe = await repository.muteAuthor(
        profileType: 'MUSICIAN',
        profileId: 'musician/id',
      );

      expect(unsupported.error?.code, 'musician_feed_invalid_request');
      expect(unsafe.error?.code, 'musician_feed_invalid_request');
      expect(api.requests, isEmpty);
    });

    test('binds feedback to the signed delivered item token', () async {
      final api = RecordingApiClient((_) => null);
      final repository = MusicianFeedRepositoryImpl(api, sessions);

      final result = await repository.sendFeedback(
        itemId: 'TRACK:item+id',
        impressionToken: 'signed-delivery-token',
        action: MusicianFeedFeedbackAction.report,
        reason: ' SPAM ',
      );

      expect(result.isSuccess, isTrue);
      expect(api.lastRequest.method, RecordedHttpMethod.post);
      expect(
        api.lastRequest.path,
        '/api/v1/feed/musician/items/TRACK%3Aitem%2Bid/feedback',
      );
      expect(api.lastRequest.body, {
        'action': 'REPORT',
        'reason': 'SPAM',
        'impressionToken': 'signed-delivery-token',
      });
    });

    test('rejects feedback without a delivery token before I/O', () async {
      final api = RecordingApiClient((_) => null);
      final repository = MusicianFeedRepositoryImpl(api, sessions);

      final result = await repository.sendFeedback(
        itemId: 'item-id',
        impressionToken: ' ',
        action: MusicianFeedFeedbackAction.hide,
      );

      expect(result.error?.code, 'musician_feed_invalid_request');
      expect(api.requests, isEmpty);
    });

    test('posts idempotent delivery-scoped feed events', () async {
      final api = RecordingApiClient((_) => null);
      final repository = MusicianFeedRepositoryImpl(api, sessions);

      final result = await repository.recordEvent(
        clientEventId: '00000000-0000-4000-8000-000000000001',
        impressionToken: 'signed-delivery-token',
        eventType: MusicianFeedTelemetryEventType.open,
        occurredAt: DateTime.parse('2026-09-11T10:00:00+03:00'),
      );

      expect(result.isSuccess, isTrue);
      expect(api.lastRequest.method, RecordedHttpMethod.post);
      expect(api.lastRequest.path, '/api/v1/feed/musician/events');
      expect(api.lastRequest.body, {
        'clientEventId': '00000000-0000-4000-8000-000000000001',
        'impressionToken': 'signed-delivery-token',
        'eventType': 'OPEN',
        'occurredAt': '2026-09-11T07:00:00.000Z',
      });
      expect(api.lastRequest.requestContext?.expectedSessionKey, 'musician-id');
    });

    test(
      'uses expectedVersion on the shared feed preferences endpoint',
      () async {
        final api = RecordingApiClient(
          (_) => {
            'contractVersion': 1,
            'version': 4,
            'opportunityCity': {'id': 'city-id', 'name': 'İstanbul'},
            'instruments': const [],
            'completion': null,
          },
        );
        final repository = MusicianFeedPreferencesRepositoryImpl(api, sessions);

        final result = await repository.updateOpportunityCity(
          cityId: 'city-id',
          expectedVersion: 3,
        );

        expect(result.isSuccess, isTrue);
        expect(api.lastRequest.path, '/api/v1/feed/musician/preferences');
        expect(api.lastRequest.body, {
          'opportunityCityId': 'city-id',
          'expectedVersion': 3,
        });
      },
    );
  });

  group('MusicianFeedCubit', () {
    test(
      'initial endpoint feature-off becomes a non-error fallback state',
      () async {
        final feed = _FeedRepository()
          ..responses.add(
            Future.value(
              const Result.failure(
                AppError(
                  code: musicianFeedFeatureUnavailableCode,
                  message: 'rollout off',
                ),
              ),
            ),
          );
        final cubit = MusicianFeedCubit(
          feed,
          _EngagementRepository(),
          collabRepository: _CollabRepository(),
          followRepository: _FollowRepository(),
          bandFollowRepository: _BandFollowRepository(),
          sessions: _musicianSessions(),
        );
        addTearDown(cubit.close);

        await cubit.initialize();

        expect(cubit.state.status, MusicianFeedStatus.featureUnavailable);
        expect(cubit.state.items, isEmpty);
        expect(cubit.state.error, isNull);
        expect(cubit.state.actionError, isNull);
      },
    );

    test('feature-off fallback can recover through a clean refresh', () async {
      final feed = _FeedRepository()
        ..responses.add(
          Future.value(
            const Result.failure(
              AppError(
                code: musicianFeedFeatureUnavailableCode,
                message: 'rollout off',
              ),
            ),
          ),
        )
        ..responses.add(Future.value(Result.success(_page('available'))));
      final cubit = MusicianFeedCubit(
        feed,
        _EngagementRepository(),
        collabRepository: _CollabRepository(),
        followRepository: _FollowRepository(),
        bandFollowRepository: _BandFollowRepository(),
        sessions: _musicianSessions(),
      );
      addTearDown(cubit.close);

      await cubit.initialize();
      await cubit.refresh();

      expect(cubit.state.status, MusicianFeedStatus.ready);
      expect(cubit.state.items.single.id, 'available');
      expect(feed.loadCursors, [null, null]);
    });

    test('initial transient failure retains the error state', () async {
      final feed = _FeedRepository()
        ..responses.add(
          Future.value(
            const Result.failure(AppError(code: '503', message: 'Geçici hata')),
          ),
        );
      final cubit = MusicianFeedCubit(
        feed,
        _EngagementRepository(),
        collabRepository: _CollabRepository(),
        followRepository: _FollowRepository(),
        bandFollowRepository: _BandFollowRepository(),
        sessions: _musicianSessions(),
      );
      addTearDown(cubit.close);

      await cubit.initialize();

      expect(cubit.state.status, MusicianFeedStatus.failure);
      expect(cubit.state.error?.code, '503');
    });

    test('a late refresh cannot replace a newer feed generation', () async {
      final feed = _FeedRepository();
      feed.responses.add(Future.value(Result.success(_page('initial'))));
      final cubit = MusicianFeedCubit(
        feed,
        _EngagementRepository(),
        collabRepository: _CollabRepository(),
        followRepository: _FollowRepository(),
        bandFollowRepository: _BandFollowRepository(),
        sessions: _musicianSessions(),
      );
      addTearDown(cubit.close);
      await cubit.initialize();
      final older = Completer<Result<MusicianFeedPage>>();
      final newer = Completer<Result<MusicianFeedPage>>();
      feed.responses
        ..add(older.future)
        ..add(newer.future);

      final olderRefresh = cubit.refresh();
      final newerRefresh = cubit.refresh();
      newer.complete(Result.success(_page('newer')));
      await newerRefresh;
      older.complete(Result.success(_page('older')));
      await olderRefresh;

      expect(cubit.state.items.single.id, 'newer');
    });

    test('rejects a non-advancing pagination cursor', () async {
      final feed = _FeedRepository()
        ..responses.add(
          Future.value(
            Result.success(
              _itemsPage(
                [_trackItem('first')],
                hasMore: true,
                nextCursor: 'cursor-1',
              ),
            ),
          ),
        )
        ..responses.add(
          Future.value(
            Result.success(
              _itemsPage(
                [_trackItem('second')],
                hasMore: true,
                nextCursor: 'cursor-1',
              ),
            ),
          ),
        );
      final cubit = MusicianFeedCubit(
        feed,
        _EngagementRepository(),
        collabRepository: _CollabRepository(),
        followRepository: _FollowRepository(),
        bandFollowRepository: _BandFollowRepository(),
        sessions: _musicianSessions(),
      );
      addTearDown(cubit.close);
      await cubit.initialize();

      await cubit.loadMore();

      expect(cubit.state.items.map((item) => item.id), ['first']);
      expect(
        cubit.state.loadMoreError?.code,
        'musician_feed_page_identity_mismatch',
      );
    });

    test(
      'cursor-invalid paging starts a clean first-page feed session',
      () async {
        final feed = _FeedRepository()
          ..responses.add(
            Future.value(
              Result.success(
                _itemsPage(
                  [_trackItem('old')],
                  hasMore: true,
                  nextCursor: 'stale-cursor',
                ),
              ),
            ),
          )
          ..responses.add(
            Future.value(
              const Result.failure(
                AppError(code: musicianFeedCursorInvalidCode, message: 'stale'),
              ),
            ),
          )
          ..responses.add(
            Future.value(Result.success(_itemsPage([_trackItem('fresh')]))),
          );
        final cubit = MusicianFeedCubit(
          feed,
          _EngagementRepository(),
          collabRepository: _CollabRepository(),
          followRepository: _FollowRepository(),
          bandFollowRepository: _BandFollowRepository(),
          sessions: _musicianSessions(),
        );
        addTearDown(cubit.close);
        await cubit.initialize();

        await cubit.loadMore();

        expect(feed.loadCursors, [null, 'stale-cursor', null]);
        expect(cubit.state.items.map((item) => item.id), ['fresh']);
        expect(cubit.state.loadMoreError, isNull);
        expect(cubit.state.status, MusicianFeedStatus.ready);
      },
    );

    test(
      'generic paging errors keep the explicit footer retry state',
      () async {
        final feed = _FeedRepository()
          ..responses.add(
            Future.value(
              Result.success(
                _itemsPage(
                  [_trackItem('first')],
                  hasMore: true,
                  nextCursor: 'cursor-1',
                ),
              ),
            ),
          )
          ..responses.add(
            Future.value(
              const Result.failure(
                AppError(code: '400', message: 'Geçersiz istek'),
              ),
            ),
          );
        final cubit = MusicianFeedCubit(
          feed,
          _EngagementRepository(),
          collabRepository: _CollabRepository(),
          followRepository: _FollowRepository(),
          bandFollowRepository: _BandFollowRepository(),
          sessions: _musicianSessions(),
        );
        addTearDown(cubit.close);
        await cubit.initialize();

        await cubit.loadMore();

        expect(feed.loadCursors, [null, 'cursor-1']);
        expect(cubit.state.items.map((item) => item.id), ['first']);
        expect(cubit.state.loadMoreError?.code, '400');
      },
    );

    test(
      'restores an optimistically hidden item when feedback fails',
      () async {
        final feed = _FeedRepository()
          ..responses.add(Future.value(Result.success(_page('item'))))
          ..feedbackResult = const Result.failure(
            AppError(code: 'offline', message: 'Çevrimdışı'),
          );
        final cubit = MusicianFeedCubit(
          feed,
          _EngagementRepository(),
          collabRepository: _CollabRepository(),
          followRepository: _FollowRepository(),
          bandFollowRepository: _BandFollowRepository(),
          sessions: _musicianSessions(),
        );
        addTearDown(cubit.close);
        await cubit.initialize();

        final success = await cubit.dismiss(
          'item',
          MusicianFeedFeedbackAction.hide,
        );

        expect(success, isFalse);
        expect(cubit.state.items.single.id, 'item');
        expect(cubit.state.actionError?.code, 'offline');
      },
    );

    test('keeps an accepted hide suppressed across a stale refresh', () async {
      final refresh = Completer<Result<MusicianFeedPage>>();
      final feedback = Completer<Result<void>>();
      final feed = _FeedRepository()
        ..responses.add(
          Future.value(Result.success(_itemsPage([_trackItem('item')]))),
        )
        ..responses.add(refresh.future)
        ..feedbackFuture = feedback.future;
      final cubit = MusicianFeedCubit(
        feed,
        _EngagementRepository(),
        collabRepository: _CollabRepository(),
        followRepository: _FollowRepository(),
        bandFollowRepository: _BandFollowRepository(),
        sessions: _musicianSessions(),
      );
      addTearDown(cubit.close);
      await cubit.initialize();

      final refreshing = cubit.refresh();
      final hiding = cubit.dismiss('item', MusicianFeedFeedbackAction.hide);
      expect(cubit.state.items, isEmpty);

      refresh.complete(Result.success(_itemsPage([_trackItem('item')])));
      await refreshing;
      expect(cubit.state.items, isEmpty);

      feedback.complete(const Result.success(null));
      expect(await hiding, isTrue);
      expect(feed.eventCalls, [
        (
          token: 'delivery-token-item',
          type: MusicianFeedTelemetryEventType.hide,
        ),
      ]);
      feed.responses.add(
        Future.value(Result.success(_itemsPage([_trackItem('item')]))),
      );
      await cubit.refresh();

      expect(cubit.state.items, isEmpty);
    });

    test('does not carry an accepted hide into another account', () async {
      final sessions = _musicianSessions();
      final feed = _FeedRepository()
        ..responses.add(
          Future.value(Result.success(_itemsPage([_trackItem('same-item')]))),
        )
        ..responses.add(
          Future.value(Result.success(_itemsPage([_trackItem('same-item')]))),
        );
      final cubit = MusicianFeedCubit(
        feed,
        _EngagementRepository(),
        collabRepository: _CollabRepository(),
        followRepository: _FollowRepository(),
        bandFollowRepository: _BandFollowRepository(),
        sessions: sessions,
      );
      addTearDown(cubit.close);
      addTearDown(sessions.dispose);
      await cubit.initialize();

      expect(
        await cubit.dismiss('same-item', MusicianFeedFeedbackAction.hide),
        isTrue,
      );
      expect(cubit.state.items, isEmpty);

      sessions.replace(
        audienceSession(
          user: 'other-viewer',
          token: 'other-token',
          role: 'ROLE_MUSICIAN',
        ),
      );
      await cubit.refresh();

      expect(cubit.state.items.map((item) => item.id), ['same-item']);
    });

    test(
      'SHOW_LESS invalidates the old cursor and wins a concurrent load-more',
      () async {
        final paging = Completer<Result<MusicianFeedPage>>();
        final feed = _FeedRepository()
          ..responses.add(
            Future.value(
              Result.success(
                _itemsPage(
                  [_trackItem('less'), _trackItem('kept')],
                  hasMore: true,
                  nextCursor: 'old-cursor',
                ),
              ),
            ),
          )
          ..responses.add(paging.future)
          ..responses.add(
            Future.value(Result.success(_itemsPage([_trackItem('fresh')]))),
          );
        final cubit = MusicianFeedCubit(
          feed,
          _EngagementRepository(),
          collabRepository: _CollabRepository(),
          followRepository: _FollowRepository(),
          bandFollowRepository: _BandFollowRepository(),
          sessions: _musicianSessions(),
        );
        addTearDown(cubit.close);
        await cubit.initialize();

        final loadingMore = cubit.loadMore();
        final showingLess = cubit.dismiss(
          'less',
          MusicianFeedFeedbackAction.showLess,
        );
        expect(await showingLess, isTrue);
        expect(cubit.state.items.map((item) => item.id), ['fresh']);
        expect(cubit.state.nextCursor, isNull);
        expect(cubit.state.hasMore, isFalse);
        expect(feed.loadCursors, [null, 'old-cursor', null]);
        expect(feed.eventCalls, isEmpty);

        paging.complete(Result.success(_itemsPage([_trackItem('stale-page')])));
        await loadingMore;
        expect(cubit.state.items.map((item) => item.id), ['fresh']);
      },
    );

    test('restores every author item when mute fails during refresh', () async {
      final refresh = Completer<Result<MusicianFeedPage>>();
      final mute = Completer<Result<void>>();
      final feed = _FeedRepository()
        ..responses.add(
          Future.value(
            Result.success(
              _itemsPage([_trackItem('first', authorUserId: 'author-a')]),
            ),
          ),
        )
        ..responses.add(refresh.future)
        ..muteFuture = mute.future;
      final cubit = MusicianFeedCubit(
        feed,
        _EngagementRepository(),
        collabRepository: _CollabRepository(),
        followRepository: _FollowRepository(),
        bandFollowRepository: _BandFollowRepository(),
        sessions: _musicianSessions(),
      );
      addTearDown(cubit.close);
      await cubit.initialize();

      final refreshing = cubit.refresh();
      final muting = cubit.muteAuthor(
        sourceItemId: 'first',
        profileType: 'MUSICIAN',
        profileId: 'profile-author-a',
      );
      refresh.complete(
        Result.success(
          _itemsPage([
            _trackItem('first', authorUserId: 'author-a'),
            _trackItem('older', authorUserId: 'author-a'),
            _trackItem('other', authorUserId: 'author-b'),
          ]),
        ),
      );
      await refreshing;
      expect(cubit.state.items.map((item) => item.id), ['other']);

      mute.complete(
        const Result.failure(AppError(code: 'mute-failed', message: 'Olmadı')),
      );
      expect(await muting, isFalse);

      expect(cubit.state.items.map((item) => item.id), [
        'first',
        'older',
        'other',
      ]);
      expect(cubit.state.actionError?.code, 'mute-failed');
      expect(feed.eventCalls, isEmpty);
    });

    test(
      'mutes only the matching profile when one user owns several',
      () async {
        final feed = _FeedRepository()
          ..responses.add(
            Future.value(
              Result.success(
                _itemsPage([
                  _trackItem(
                    'studio',
                    authorUserId: 'owner-a',
                    authorProfileType: 'STUDIO',
                    authorProfileId: 'studio-a',
                  ),
                  _trackItem(
                    'musician',
                    authorUserId: 'owner-a',
                    authorProfileType: 'MUSICIAN',
                    authorProfileId: 'musician-a',
                  ),
                ]),
              ),
            ),
          );
        final cubit = MusicianFeedCubit(
          feed,
          _EngagementRepository(),
          collabRepository: _CollabRepository(),
          followRepository: _FollowRepository(),
          bandFollowRepository: _BandFollowRepository(),
          sessions: _musicianSessions(),
        );
        addTearDown(cubit.close);
        await cubit.initialize();

        final success = await cubit.muteAuthor(
          sourceItemId: 'studio',
          profileType: 'STUDIO',
          profileId: 'studio-a',
        );

        expect(success, isTrue);
        expect(cubit.state.items.map((item) => item.id), ['musician']);
        expect(feed.muteCalls, [
          (profileType: 'STUDIO', profileId: 'studio-a'),
        ]);
        expect(feed.eventCalls, [
          (
            token: 'delivery-token-studio',
            type: MusicianFeedTelemetryEventType.mute,
          ),
        ]);
      },
    );

    test('rolls back a pending mute after the account changes', () async {
      final mute = Completer<Result<void>>();
      final sessions = _musicianSessions();
      final feed = _FeedRepository()
        ..responses.add(
          Future.value(
            Result.success(
              _itemsPage([
                _trackItem('first', authorUserId: 'author-a'),
                _trackItem('other', authorUserId: 'author-b'),
              ]),
            ),
          ),
        )
        ..muteFuture = mute.future;
      final cubit = MusicianFeedCubit(
        feed,
        _EngagementRepository(),
        collabRepository: _CollabRepository(),
        followRepository: _FollowRepository(),
        bandFollowRepository: _BandFollowRepository(),
        sessions: sessions,
      );
      addTearDown(cubit.close);
      addTearDown(sessions.dispose);
      await cubit.initialize();

      final muting = cubit.muteAuthor(
        sourceItemId: 'first',
        profileType: 'MUSICIAN',
        profileId: 'profile-author-a',
      );
      expect(cubit.state.items.map((item) => item.id), ['other']);
      sessions.replace(
        audienceSession(
          user: 'other-viewer',
          token: 'other-token',
          role: 'ROLE_MUSICIAN',
        ),
      );
      mute.complete(const Result.success(null));

      expect(await muting, isFalse);
      expect(cubit.state.items.map((item) => item.id), ['first', 'other']);
      expect(
        cubit.state.actionError?.code,
        'musician_feed_action_session_changed',
      );
    });

    test(
      'reapplies accepted mute to load-more and refresh until unmute succeeds',
      () async {
        final loadMore = Completer<Result<MusicianFeedPage>>();
        final mute = Completer<Result<void>>();
        final feed = _FeedRepository()
          ..responses.add(
            Future.value(
              Result.success(
                _itemsPage(
                  [
                    _trackItem('first', authorUserId: 'author-a'),
                    _trackItem('other', authorUserId: 'author-b'),
                  ],
                  hasMore: true,
                  nextCursor: 'cursor-1',
                ),
              ),
            ),
          )
          ..responses.add(loadMore.future)
          ..muteFuture = mute.future;
        final cubit = MusicianFeedCubit(
          feed,
          _EngagementRepository(),
          collabRepository: _CollabRepository(),
          followRepository: _FollowRepository(),
          bandFollowRepository: _BandFollowRepository(),
          sessions: _musicianSessions(),
        );
        addTearDown(cubit.close);
        await cubit.initialize();

        final paging = cubit.loadMore();
        final muting = cubit.muteAuthor(
          sourceItemId: 'first',
          profileType: 'MUSICIAN',
          profileId: 'profile-author-a',
        );
        loadMore.complete(
          Result.success(
            _itemsPage([
              _trackItem('older-a', authorUserId: 'author-a'),
              _trackItem('older-b', authorUserId: 'author-b'),
            ]),
          ),
        );
        await paging;
        expect(cubit.state.items.map((item) => item.id), ['other', 'older-b']);

        mute.complete(const Result.success(null));
        expect(await muting, isTrue);
        feed.responses.add(
          Future.value(
            Result.success(
              _itemsPage([
                _trackItem('new-a', authorUserId: 'author-a'),
                _trackItem('new-b', authorUserId: 'author-b'),
              ]),
            ),
          ),
        );
        await cubit.refresh();
        expect(cubit.state.items.map((item) => item.id), ['new-b']);

        feed.responses.add(
          Future.value(
            Result.success(
              _itemsPage([
                _trackItem('new-a', authorUserId: 'author-a'),
                _trackItem('new-b', authorUserId: 'author-b'),
              ]),
            ),
          ),
        );
        expect(
          await cubit.unmuteAuthor(
            profileType: 'MUSICIAN',
            profileId: 'profile-author-a',
          ),
          isTrue,
        );
        expect(cubit.state.items.map((item) => item.id), ['new-a', 'new-b']);
      },
    );

    test('does not carry an accepted mute into another account', () async {
      final sessions = _musicianSessions();
      final feed = _FeedRepository()
        ..responses.add(
          Future.value(
            Result.success(
              _itemsPage([_trackItem('first', authorUserId: 'same-author')]),
            ),
          ),
        )
        ..responses.add(
          Future.value(
            Result.success(
              _itemsPage([_trackItem('second', authorUserId: 'same-author')]),
            ),
          ),
        );
      final cubit = MusicianFeedCubit(
        feed,
        _EngagementRepository(),
        collabRepository: _CollabRepository(),
        followRepository: _FollowRepository(),
        bandFollowRepository: _BandFollowRepository(),
        sessions: sessions,
      );
      addTearDown(cubit.close);
      addTearDown(sessions.dispose);
      await cubit.initialize();

      expect(
        await cubit.muteAuthor(
          sourceItemId: 'first',
          profileType: 'MUSICIAN',
          profileId: 'profile-same-author',
        ),
        isTrue,
      );
      expect(cubit.state.items, isEmpty);

      sessions.replace(
        audienceSession(
          user: 'other-viewer',
          token: 'other-token',
          role: 'ROLE_MUSICIAN',
        ),
      );
      await cubit.refresh();

      expect(cubit.state.items.map((item) => item.id), ['second']);
    });

    test(
      'synchronizes an optimistic like across every card for its target',
      () async {
        final feed = _FeedRepository()
          ..responses.add(
            Future.value(
              Result.success(
                _itemsPage([_trackItem('native'), _trackItem('activity')]),
              ),
            ),
          );
        final write = Completer<Result<void>>();
        final engagement = _EngagementRepository()..likeFuture = write.future;
        final cubit = MusicianFeedCubit(
          feed,
          engagement,
          collabRepository: _CollabRepository(),
          followRepository: _FollowRepository(),
          bandFollowRepository: _BandFollowRepository(),
          sessions: _musicianSessions(),
        );
        addTearDown(cubit.close);
        await cubit.initialize();

        final pending = cubit.toggleLike('native');

        expect(
          cubit.state.items.map((item) => item.engagement?.likedByMe),
          everyElement(isTrue),
        );
        expect(
          cubit.state.items.map((item) => item.engagement?.likeCount),
          everyElement(3),
        );
        expect(cubit.state.pendingItemIds, {'native', 'activity'});

        write.complete(const Result.success(null));
        expect(await pending, isTrue);
        expect(cubit.state.pendingItemIds, isEmpty);
        expect(engagement.likeCalls, [('MEDIA', 'media-id')]);
      },
    );

    test(
      'rolls back every shared-target card after a failed optimistic like',
      () async {
        final feed = _FeedRepository()
          ..responses.add(
            Future.value(
              Result.success(
                _itemsPage([_trackItem('native'), _trackItem('activity')]),
              ),
            ),
          );
        final engagement = _EngagementRepository()
          ..likeResult = const Result.failure(
            AppError(code: 'like-failed', message: 'Olmadı'),
          );
        final cubit = MusicianFeedCubit(
          feed,
          engagement,
          collabRepository: _CollabRepository(),
          followRepository: _FollowRepository(),
          bandFollowRepository: _BandFollowRepository(),
          sessions: _musicianSessions(),
        );
        addTearDown(cubit.close);
        await cubit.initialize();

        final success = await cubit.toggleLike('activity');

        expect(success, isFalse);
        expect(
          cubit.state.items.map((item) => item.engagement?.likedByMe),
          everyElement(isFalse),
        );
        expect(
          cubit.state.items.map((item) => item.engagement?.likeCount),
          everyElement(2),
        );
        expect(cubit.state.pendingItemIds, isEmpty);
      },
    );

    test(
      'rolls back a like result that crosses an account session boundary',
      () async {
        final sessions = _musicianSessions();
        final write = Completer<Result<void>>();
        final feed = _FeedRepository()
          ..responses.add(
            Future.value(
              Result.success(
                _itemsPage([_trackItem('native'), _trackItem('activity')]),
              ),
            ),
          );
        final engagement = _EngagementRepository()..likeFuture = write.future;
        final cubit = MusicianFeedCubit(
          feed,
          engagement,
          collabRepository: _CollabRepository(),
          followRepository: _FollowRepository(),
          bandFollowRepository: _BandFollowRepository(),
          sessions: sessions,
        );
        addTearDown(cubit.close);
        addTearDown(sessions.dispose);
        await cubit.initialize();

        final pending = cubit.toggleLike('native');
        sessions.replace(
          audienceSession(
            user: 'replacement-user',
            token: 'replacement-token',
            role: 'ROLE_MUSICIAN',
          ),
        );
        write.complete(const Result.success(null));

        expect(await pending, isFalse);
        expect(
          cubit.state.items.map((item) => item.engagement?.likedByMe),
          everyElement(isFalse),
        );
        expect(cubit.state.pendingItemIds, isEmpty);
        expect(
          cubit.state.actionError?.code,
          'musician_feed_action_session_changed',
        );
      },
    );

    test(
      'a late like failure cannot roll back a refreshed feed generation',
      () async {
        const refreshedEngagement = MusicianFeedEngagement(
          targetType: 'MEDIA',
          targetId: 'media-id',
          likeCount: 18,
          commentCount: 7,
          likedByMe: true,
          likable: true,
          commentable: true,
        );
        final write = Completer<Result<void>>();
        final feed = _FeedRepository()
          ..responses.add(
            Future.value(Result.success(_itemsPage([_trackItem('old')]))),
          )
          ..responses.add(
            Future.value(
              Result.success(
                _itemsPage([
                  _trackItem('fresh').copyWith(engagement: refreshedEngagement),
                ]),
              ),
            ),
          );
        final engagement = _EngagementRepository()..likeFuture = write.future;
        final cubit = MusicianFeedCubit(
          feed,
          engagement,
          collabRepository: _CollabRepository(),
          followRepository: _FollowRepository(),
          bandFollowRepository: _BandFollowRepository(),
          sessions: _musicianSessions(),
        );
        addTearDown(cubit.close);
        await cubit.initialize();

        final pending = cubit.toggleLike('old');
        await cubit.refresh();
        write.complete(
          const Result.failure(AppError(code: 'late-failure', message: 'late')),
        );

        expect(await pending, isFalse);
        expect(cubit.state.items.single.id, 'fresh');
        expect(cubit.state.items.single.engagement?.likeCount, 18);
        expect(cubit.state.items.single.engagement?.likedByMe, isTrue);
        expect(cubit.state.actionError, isNull);
      },
    );

    test('a failed refresh cannot strand a failed optimistic like', () async {
      final write = Completer<Result<void>>();
      final feed = _FeedRepository()
        ..responses.add(
          Future.value(Result.success(_itemsPage([_trackItem('item')]))),
        )
        ..responses.add(
          Future.value(
            const Result.failure(
              AppError(code: 'refresh-failed', message: 'refresh failed'),
            ),
          ),
        );
      final engagement = _EngagementRepository()..likeFuture = write.future;
      final cubit = MusicianFeedCubit(
        feed,
        engagement,
        collabRepository: _CollabRepository(),
        followRepository: _FollowRepository(),
        bandFollowRepository: _BandFollowRepository(),
        sessions: _musicianSessions(),
      );
      addTearDown(cubit.close);
      await cubit.initialize();

      final pending = cubit.toggleLike('item');
      await cubit.refresh();
      expect(cubit.state.items.single.engagement?.likedByMe, isTrue);
      write.complete(
        const Result.failure(
          AppError(code: 'like-failed', message: 'like failed'),
        ),
      );

      expect(await pending, isFalse);
      expect(cubit.state.items.single.engagement?.likedByMe, isFalse);
      expect(cubit.state.items.single.engagement?.likeCount, 2);
      expect(cubit.state.actionError?.code, 'like-failed');
    });

    test(
      'synchronizes comment deltas across cards for the same target',
      () async {
        final feed = _FeedRepository()
          ..responses.add(
            Future.value(
              Result.success(
                _itemsPage([_trackItem('native'), _trackItem('activity')]),
              ),
            ),
          );
        final cubit = MusicianFeedCubit(
          feed,
          _EngagementRepository(),
          collabRepository: _CollabRepository(),
          followRepository: _FollowRepository(),
          bandFollowRepository: _BandFollowRepository(),
          sessions: _musicianSessions(),
        );
        addTearDown(cubit.close);
        await cubit.initialize();

        cubit.adjustCommentCount('activity', 1);

        expect(
          cubit.state.items.map((item) => item.engagement?.commentCount),
          everyElement(2),
        );
      },
    );

    test(
      'uses the existing Collab repository and rolls back save failure',
      () async {
        final feed = _FeedRepository()
          ..responses.add(
            Future.value(Result.success(_page('collab', collab: true))),
          );
        final collab = _CollabRepository()
          ..saveResult = const Result.failure(
            AppError(code: 'save-failed', message: 'Olmadı'),
          );
        final cubit = MusicianFeedCubit(
          feed,
          _EngagementRepository(),
          collabRepository: collab,
          followRepository: _FollowRepository(),
          bandFollowRepository: _BandFollowRepository(),
          sessions: _musicianSessions(),
        );
        addTearDown(cubit.close);
        await cubit.initialize();

        final success = await cubit.toggleCollabSaved('collab', true);

        expect(success, isFalse);
        expect(collab.savedIds, ['listing-id']);
        final payload = cubit.state.items.single.payload as CollabFeedPayload;
        expect(payload.listing['savedByMe'], isFalse);
        expect(feed.eventCalls, isEmpty);
      },
    );

    test(
      'an account switch fences and rolls back an in-flight Collab save',
      () async {
        final sessions = _musicianSessions();
        final write = Completer<Result<void>>();
        final feed = _FeedRepository()
          ..responses.add(
            Future.value(Result.success(_page('collab', collab: true))),
          );
        final collab = _CollabRepository()..saveFuture = write.future;
        final cubit = MusicianFeedCubit(
          feed,
          _EngagementRepository(),
          collabRepository: collab,
          followRepository: _FollowRepository(),
          bandFollowRepository: _BandFollowRepository(),
          sessions: sessions,
        );
        addTearDown(cubit.close);
        addTearDown(sessions.dispose);
        await cubit.initialize();

        final pending = cubit.toggleCollabSaved('collab', true);
        expect(
          (cubit.state.items.single.payload as CollabFeedPayload)
              .listing['savedByMe'],
          isTrue,
        );
        sessions.replace(
          audienceSession(
            user: 'replacement-user',
            token: 'replacement-token',
            role: 'ROLE_MUSICIAN',
          ),
        );
        write.complete(const Result.success(null));

        expect(await pending, isFalse);
        expect(
          (cubit.state.items.single.payload as CollabFeedPayload)
              .listing['savedByMe'],
          isFalse,
        );
        expect(cubit.state.pendingItemIds, isEmpty);
        expect(
          cubit.state.actionError?.code,
          'musician_feed_action_session_changed',
        );
        expect(feed.eventCalls, isEmpty);
      },
    );

    test(
      'a failed refresh cannot strand a failed optimistic Collab save',
      () async {
        final write = Completer<Result<void>>();
        final feed = _FeedRepository()
          ..responses.add(
            Future.value(Result.success(_page('collab', collab: true))),
          )
          ..responses.add(
            Future.value(
              const Result.failure(
                AppError(code: 'refresh-failed', message: 'refresh failed'),
              ),
            ),
          );
        final collab = _CollabRepository()..saveFuture = write.future;
        final cubit = MusicianFeedCubit(
          feed,
          _EngagementRepository(),
          collabRepository: collab,
          followRepository: _FollowRepository(),
          bandFollowRepository: _BandFollowRepository(),
          sessions: _musicianSessions(),
        );
        addTearDown(cubit.close);
        await cubit.initialize();

        final pending = cubit.toggleCollabSaved('collab', true);
        await cubit.refresh();
        expect(
          (cubit.state.items.single.payload as CollabFeedPayload)
              .listing['savedByMe'],
          isTrue,
        );
        write.complete(
          const Result.failure(
            AppError(code: 'save-failed', message: 'save failed'),
          ),
        );

        expect(await pending, isFalse);
        expect(
          (cubit.state.items.single.payload as CollabFeedPayload)
              .listing['savedByMe'],
          isFalse,
        );
        expect(cubit.state.actionError?.code, 'save-failed');
      },
    );

    test('records SAVE only after the Collab save succeeds', () async {
      final feed = _FeedRepository()
        ..responses.add(
          Future.value(Result.success(_page('collab', collab: true))),
        );
      final cubit = MusicianFeedCubit(
        feed,
        _EngagementRepository(),
        collabRepository: _CollabRepository(),
        followRepository: _FollowRepository(),
        bandFollowRepository: _BandFollowRepository(),
        sessions: _musicianSessions(),
      );
      addTearDown(cubit.close);
      await cubit.initialize();

      expect(await cubit.toggleCollabSaved('collab', true), isTrue);

      expect(feed.eventCalls, [
        (
          token: 'delivery-token-collab',
          type: MusicianFeedTelemetryEventType.save,
        ),
      ]);
    });

    test('records REPORT only after signed feedback succeeds', () async {
      final item = _trackItem(
        'reported',
        feedbackCapabilities: const {MusicianFeedFeedbackAction.report},
      );
      final feed = _FeedRepository()
        ..responses.add(Future.value(Result.success(_itemsPage([item]))));
      final cubit = MusicianFeedCubit(
        feed,
        _EngagementRepository(),
        collabRepository: _CollabRepository(),
        followRepository: _FollowRepository(),
        bandFollowRepository: _BandFollowRepository(),
        sessions: _musicianSessions(),
      );
      addTearDown(cubit.close);
      await cubit.initialize();

      expect(
        await cubit.dismiss(
          'reported',
          MusicianFeedFeedbackAction.report,
          reason: 'SPAM',
        ),
        isTrue,
      );

      expect(
        feed.feedbackCalls.single.impressionToken,
        'delivery-token-reported',
      );
      expect(feed.eventCalls, [
        (
          token: 'delivery-token-reported',
          type: MusicianFeedTelemetryEventType.report,
        ),
      ]);
    });

    test(
      'keeps a successful user-profile follow optimistic through refresh',
      () async {
        final write = Completer<Result<void>>();
        final refresh = Completer<Result<MusicianFeedPage>>();
        final feed = _FeedRepository()
          ..responses.add(
            Future.value(
              Result.success(
                _itemsPage([
                  _profileItem(
                    'profile-card',
                    profileType: 'STUDIO',
                    profileId: 'studio-id',
                    userId: 'studio-owner-id',
                  ),
                ]),
              ),
            ),
          )
          ..responses.add(refresh.future);
        final follow = _FollowRepository()..followFuture = write.future;
        final cubit = MusicianFeedCubit(
          feed,
          _EngagementRepository(),
          collabRepository: _CollabRepository(),
          followRepository: follow,
          bandFollowRepository: _BandFollowRepository(),
          sessions: _musicianSessions(),
        );
        addTearDown(cubit.close);
        await cubit.initialize();

        final following = cubit.followProfile('profile-card');
        expect(
          (cubit.state.items.single.payload as ProfileFeedPayload)
              .followedByViewer,
          isTrue,
        );
        expect(feed.eventCalls, isEmpty);
        expect(cubit.state.pendingItemIds, contains('profile-card'));
        expect(follow.followCalls, [('viewer-id', 'studio-owner-id')]);

        write.complete(const Result.success(null));
        await Future<void>.delayed(Duration.zero);
        expect(cubit.state.refreshing, isTrue);
        expect(cubit.state.pendingItemIds, isNot(contains('profile-card')));
        expect(
          (cubit.state.items.single.payload as ProfileFeedPayload)
              .followedByViewer,
          isTrue,
        );
        expect(feed.eventCalls, [
          (
            token: 'delivery-token-profile-card',
            type: MusicianFeedTelemetryEventType.follow,
          ),
        ]);

        refresh.complete(
          Result.success(
            _itemsPage([
              _profileItem(
                'profile-card',
                profileType: 'STUDIO',
                profileId: 'studio-id',
                userId: 'studio-owner-id',
              ),
            ]),
          ),
        );
        expect(await following, isTrue);
        expect(
          (cubit.state.items.single.payload as ProfileFeedPayload)
              .followedByViewer,
          isTrue,
        );
      },
    );

    test('uses the dedicated band follow endpoint', () async {
      final feed = _FeedRepository()
        ..responses.add(
          Future.value(
            Result.success(
              _itemsPage([
                _profileItem(
                  'band-card',
                  profileType: 'BAND',
                  profileId: 'band-id',
                  // A band payload user is a representative member, never the
                  // identity accepted by the band-follow API.
                  userId: 'representative-user-id',
                ),
              ]),
            ),
          ),
        )
        ..responses.add(
          Future.value(
            Result.success(
              _itemsPage([
                _profileItem(
                  'band-card',
                  profileType: 'BAND',
                  profileId: 'band-id',
                  userId: 'representative-user-id',
                ),
              ]),
            ),
          ),
        );
      final follow = _FollowRepository();
      final bandFollow = _BandFollowRepository();
      final cubit = MusicianFeedCubit(
        feed,
        _EngagementRepository(),
        collabRepository: _CollabRepository(),
        followRepository: follow,
        bandFollowRepository: bandFollow,
        sessions: _musicianSessions(),
      );
      addTearDown(cubit.close);
      await cubit.initialize();

      expect(await cubit.followProfile('band-card'), isTrue);

      expect(bandFollow.followedBandIds, ['band-id']);
      expect(follow.followCalls, isEmpty);
    });

    test('does not carry an accepted follow into another account', () async {
      final sessions = _musicianSessions();
      final profile = _profileItem(
        'listener-card',
        profileType: 'LISTENER',
        profileId: 'listener-id',
        userId: 'listener-user-id',
      );
      final feed = _FeedRepository()
        ..responses.add(Future.value(Result.success(_itemsPage([profile]))))
        ..responses.add(Future.value(Result.success(_itemsPage([profile]))))
        ..responses.add(Future.value(Result.success(_itemsPage([profile]))));
      final cubit = MusicianFeedCubit(
        feed,
        _EngagementRepository(),
        collabRepository: _CollabRepository(),
        followRepository: _FollowRepository(),
        bandFollowRepository: _BandFollowRepository(),
        sessions: sessions,
      );
      addTearDown(cubit.close);
      addTearDown(sessions.dispose);
      await cubit.initialize();

      expect(await cubit.followProfile('listener-card'), isTrue);
      expect(
        (cubit.state.items.single.payload as ProfileFeedPayload)
            .followedByViewer,
        isTrue,
      );

      sessions.replace(
        audienceSession(
          user: 'other-viewer',
          token: 'other-token',
          role: 'ROLE_MUSICIAN',
        ),
      );
      await cubit.refresh();

      expect(
        (cubit.state.items.single.payload as ProfileFeedPayload)
            .followedByViewer,
        isFalse,
      );
    });

    test('rolls back follow when the authenticated session changes', () async {
      final sessions = _musicianSessions();
      final write = Completer<Result<void>>();
      final feed = _FeedRepository()
        ..responses.add(
          Future.value(
            Result.success(
              _itemsPage([
                _profileItem(
                  'listener-card',
                  profileType: 'LISTENER',
                  profileId: 'listener-id',
                  userId: 'listener-user-id',
                ),
              ]),
            ),
          ),
        );
      final follow = _FollowRepository()..followFuture = write.future;
      final cubit = MusicianFeedCubit(
        feed,
        _EngagementRepository(),
        collabRepository: _CollabRepository(),
        followRepository: follow,
        bandFollowRepository: _BandFollowRepository(),
        sessions: sessions,
      );
      addTearDown(cubit.close);
      await cubit.initialize();

      final following = cubit.followProfile('listener-card');
      sessions.replace(
        audienceSession(
          user: 'other-viewer',
          token: 'other-token',
          role: 'ROLE_MUSICIAN',
        ),
      );
      write.complete(const Result.success(null));

      expect(await following, isFalse);
      expect(cubit.state.pendingItemIds, isEmpty);
      expect(
        (cubit.state.items.single.payload as ProfileFeedPayload)
            .followedByViewer,
        isFalse,
      );
      expect(
        cubit.state.actionError?.code,
        'musician_feed_action_session_changed',
      );
    });

    test(
      'rolls back an optimistic profile follow after write failure',
      () async {
        final feed = _FeedRepository()
          ..responses.add(
            Future.value(
              Result.success(
                _itemsPage([
                  _profileItem(
                    'musician-card',
                    profileType: 'MUSICIAN',
                    profileId: 'musician-id',
                    userId: 'musician-user-id',
                  ),
                ]),
              ),
            ),
          );
        final follow = _FollowRepository()
          ..followResult = const Result.failure(
            AppError(code: 'follow-failed', message: 'Takip edilemedi'),
          );
        final cubit = MusicianFeedCubit(
          feed,
          _EngagementRepository(),
          collabRepository: _CollabRepository(),
          followRepository: follow,
          bandFollowRepository: _BandFollowRepository(),
          sessions: _musicianSessions(),
        );
        addTearDown(cubit.close);
        await cubit.initialize();

        expect(await cubit.followProfile('musician-card'), isFalse);

        expect(cubit.state.pendingItemIds, isEmpty);
        expect(
          (cubit.state.items.single.payload as ProfileFeedPayload)
              .followedByViewer,
          isFalse,
        );
        expect(cubit.state.actionError?.code, 'follow-failed');
      },
    );
  });

  testWidgets(
    'Collab detail refreshes only for changed authoritative state and fences sessions',
    (tester) async {
      final sessions = _musicianSessions();
      addTearDown(sessions.dispose);
      final item = _validCollabFeedItem();
      final payload = item.payload as CollabFeedPayload;
      final snapshot = tryParseMusicianFeedCollab(payload.listing)!;
      final feed = _FeedRepository()
        ..responses.add(Future.value(Result.success(_itemsPage(const []))));
      final cubit = MusicianFeedCubit(
        feed,
        _EngagementRepository(),
        collabRepository: _CollabRepository(),
        followRepository: _FollowRepository(),
        bandFollowRepository: _BandFollowRepository(),
        sessions: sessions,
      );
      addTearDown(cubit.close);
      late BuildContext feedContext;
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: cubit,
            child: Builder(
              builder: (context) {
                feedContext = context;
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      var launches = 0;
      final navigation = MusicianFeedNavigationCoordinator(
        context: feedContext,
        cubit: cubit,
        collabRouteLauncher:
            (
              context, {
              required listingId,
              required onListingChanged,
              required onApplied,
            }) async {
              launches += 1;
              if (launches == 1) {
                onListingChanged(snapshot);
                return;
              }
              onListingChanged(
                snapshot.copyWith(
                  version: snapshot.version + 1,
                  savedByMe: true,
                  appliedByMe: true,
                  applicationCount: snapshot.applicationCount + 1,
                ),
              );
              onApplied();
            },
      );
      final registry = MusicianFeedCardRegistry.standard();

      await registry.open(navigation, item);
      expect(feed.loadCursors, isEmpty);

      await registry.open(navigation, item);
      expect(feed.loadCursors, [null]);
      expect(feed.eventCalls.map((call) => call.type), [
        MusicianFeedTelemetryEventType.open,
        MusicianFeedTelemetryEventType.open,
        MusicianFeedTelemetryEventType.apply,
      ]);

      final fencedNavigation = MusicianFeedNavigationCoordinator(
        context: feedContext,
        cubit: cubit,
        collabRouteLauncher:
            (
              context, {
              required listingId,
              required onListingChanged,
              required onApplied,
            }) async {
              sessions.replace(
                audienceSession(
                  user: 'replacement-user',
                  token: 'replacement-token',
                  role: 'ROLE_MUSICIAN',
                ),
              );
              onListingChanged(
                snapshot.copyWith(version: snapshot.version + 2),
              );
              onApplied();
            },
      );
      await registry.open(fencedNavigation, item);
      expect(feed.loadCursors, [null]);
      expect(
        feed.eventCalls.where(
          (call) => call.type == MusicianFeedTelemetryEventType.apply,
        ),
        hasLength(1),
      );
    },
  );

  testWidgets(
    'event detail refreshes only after a reported engagement change',
    (tester) async {
      final sessions = _musicianSessions();
      addTearDown(sessions.dispose);
      final item = _registryItem(
        id: 'event',
        type: MusicianFeedItemType.event,
        payload: const EventFeedPayload(
          event: {
            'id': 'event-id',
            'title': 'Canlı performans',
            'startTime': '20:30',
            'endTime': null,
          },
          note: null,
          publicationId: null,
        ),
      );
      final feed = _FeedRepository()
        ..responses.add(Future.value(Result.success(_itemsPage(const []))));
      final cubit = MusicianFeedCubit(
        feed,
        _EngagementRepository(),
        collabRepository: _CollabRepository(),
        followRepository: _FollowRepository(),
        bandFollowRepository: _BandFollowRepository(),
        sessions: sessions,
      );
      addTearDown(cubit.close);
      late BuildContext feedContext;
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: cubit,
            child: Builder(
              builder: (context) {
                feedContext = context;
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      var launches = 0;
      final navigation = MusicianFeedNavigationCoordinator(
        context: feedContext,
        cubit: cubit,
        eventRouteLauncher:
            (context, {required event, required onEngagementChanged}) async {
              launches += 1;
              if (launches == 2) onEngagementChanged();
            },
      );
      final registry = MusicianFeedCardRegistry.standard();

      await registry.open(navigation, item);
      expect(feed.loadCursors, isEmpty);
      await registry.open(navigation, item);
      expect(feed.loadCursors, [null]);
    },
  );

  for (final code in const ['PORTFOLIO', 'PROFILE_PHOTO_AND_SOCIAL_LINKS']) {
    testWidgets('$code completion CTA keeps its actionable editor route code', (
      tester,
    ) async {
      final task = MusicianFeedCompletionTask(
        code: code,
        title: 'Profilini tamamla',
        description: 'Eksik adımı tamamla.',
        ctaLabel: 'Düzenle',
        route: '/profile/musician/edit',
        priority: 1,
        complete: false,
      );
      final feed = _FeedRepository()
        ..responses.add(
          Future.value(Result.success(_itemsPage([_completionItem(task)]))),
        );
      final cubit = MusicianFeedCubit(
        feed,
        _EngagementRepository(),
        collabRepository: _CollabRepository(),
        followRepository: _FollowRepository(),
        bandFollowRepository: _BandFollowRepository(),
        sessions: _musicianSessions(),
      );
      addTearDown(cubit.close);
      await cubit.initialize();
      RouteSettings? opened;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.navy,
          onGenerateRoute: (settings) {
            opened = settings;
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const Scaffold(body: Text('Profil editörü')),
            );
          },
          home: Scaffold(
            body: BlocProvider.value(
              value: cubit,
              child: MusicianFeedView(
                registry: _completionLauncherRegistry(task),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('open-completion-editor')));
      await tester.pumpAndSettle();

      expect(opened?.name, AppRoutes.musicianProfile);
      final args = opened?.arguments as MusicianProfileScreenArgs;
      expect(args.completionTaskCode, code);
      expect(args.openManagementPanel, isFalse);
      expect(find.text('Profil editörü'), findsOneWidget);
    });
  }

  testWidgets(
    'feature-off renders a calm Backstage fallback without retry UX',
    (tester) async {
      final feed = _FeedRepository()
        ..responses.add(
          Future.value(
            const Result.failure(
              AppError(
                code: musicianFeedFeatureUnavailableCode,
                message: 'rollout off',
              ),
            ),
          ),
        );
      final cubit = MusicianFeedCubit(
        feed,
        _EngagementRepository(),
        collabRepository: _CollabRepository(),
        followRepository: _FollowRepository(),
        bandFollowRepository: _BandFollowRepository(),
        sessions: _musicianSessions(),
      );
      addTearDown(cubit.close);
      await cubit.initialize();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.navy,
          home: Scaffold(
            body: BlocProvider.value(
              value: cubit,
              child: MusicianFeedView(registry: _stubCardRegistry()),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('musician-feed-feature-unavailable')),
        findsOneWidget,
      );
      expect(find.text('Backstage akışın hazırlanıyor'), findsOneWidget);
      expect(find.text('Akışına ulaşamadık'), findsNothing);
      expect(find.text('Tekrar dene'), findsNothing);
    },
  );

  testWidgets('initial skeleton announces feed loading as a live region', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final response = Completer<Result<MusicianFeedPage>>();
    final feed = _FeedRepository()..responses.add(response.future);
    final cubit = MusicianFeedCubit(
      feed,
      _EngagementRepository(),
      collabRepository: _CollabRepository(),
      followRepository: _FollowRepository(),
      bandFollowRepository: _BandFollowRepository(),
      sessions: _musicianSessions(),
    );
    addTearDown(cubit.close);
    final initialization = cubit.initialize();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.navy,
        home: Scaffold(
          body: BlocProvider.value(
            value: cubit,
            child: MusicianFeedView(registry: _stubCardRegistry()),
          ),
        ),
      ),
    );
    await tester.pump();

    final data = tester
        .getSemantics(find.bySemanticsLabel('Akış yükleniyor'))
        .getSemanticsData();
    expect(data.hasFlag(SemanticsFlag.isLiveRegion), isTrue);

    response.complete(Result.success(_itemsPage(const [])));
    await initialization;
    semantics.dispose();
  });

  testWidgets('transient initial failures retain the retry error experience', (
    tester,
  ) async {
    final feed = _FeedRepository()
      ..responses.add(
        Future.value(
          const Result.failure(AppError(code: '503', message: 'Geçici hata')),
        ),
      );
    final cubit = MusicianFeedCubit(
      feed,
      _EngagementRepository(),
      collabRepository: _CollabRepository(),
      followRepository: _FollowRepository(),
      bandFollowRepository: _BandFollowRepository(),
      sessions: _musicianSessions(),
    );
    addTearDown(cubit.close);
    await cubit.initialize();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.navy,
        home: Scaffold(
          body: BlocProvider.value(
            value: cubit,
            child: MusicianFeedView(registry: _stubCardRegistry()),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Akışına ulaşamadık'), findsOneWidget);
    expect(find.text('Geçici hata'), findsOneWidget);
    expect(find.text('Tekrar dene'), findsOneWidget);
    expect(
      find.byKey(const Key('musician-feed-feature-unavailable')),
      findsNothing,
    );
  });

  testWidgets('visible feed cards emit one delivery-scoped impression', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final feed = _FeedRepository()
      ..responses.add(Future.value(Result.success(_page('visible-item'))));
    final cubit = MusicianFeedCubit(
      feed,
      _EngagementRepository(),
      collabRepository: _CollabRepository(),
      followRepository: _FollowRepository(),
      bandFollowRepository: _BandFollowRepository(),
      sessions: _musicianSessions(),
      eventIdFactory: () => '00000000-0000-4000-8000-000000000001',
    );
    addTearDown(cubit.close);
    await cubit.initialize();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.navy,
        navigatorObservers: [analyticsRouteObserver],
        home: Scaffold(
          body: BlocProvider.value(
            value: cubit,
            child: MusicianFeedView(registry: _stubCardRegistry()),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(feed.eventCalls, [
      (
        token: 'delivery-token-visible-item',
        type: MusicianFeedTelemetryEventType.impression,
      ),
    ]);
    await tester.pumpWidget(const SizedBox());
  });
}

MusicianFeedCardRegistry _stubCardRegistry() => MusicianFeedCardRegistry({
  for (final type in MusicianFeedItemType.values)
    type: MusicianFeedCardRegistration.presentationOnly(
      (_, item, _) =>
          SizedBox(height: 180, child: Center(child: Text(item.id))),
    ),
});

MusicianFeedCardRegistry _completionLauncherRegistry(
  MusicianFeedCompletionTask task,
) => MusicianFeedCardRegistry({
  for (final type in MusicianFeedItemType.values)
    type: MusicianFeedCardRegistration.presentationOnly(
      (_, item, actions) => type == MusicianFeedItemType.profileCompletion
          ? TextButton(
              key: const Key('open-completion-editor'),
              onPressed: () => actions.openCompletionTask(task),
              child: const Text('Düzenle'),
            )
          : SizedBox(height: 180, child: Center(child: Text(item.id))),
    ),
});

MusicianFeedItem _completionItem(MusicianFeedCompletionTask task) =>
    MusicianFeedItem(
      id: 'completion-${task.code}',
      type: MusicianFeedItemType.profileCompletion,
      payloadVersion: 1,
      occurredAt: DateTime.utc(2026, 9, 11),
      position: 0,
      impressionToken: 'delivery-token-completion-${task.code}',
      reason: const MusicianFeedReason(
        code: 'PROFILE_INCOMPLETE',
        actors: [],
        secondaryActorCount: 0,
      ),
      author: null,
      target: null,
      engagement: null,
      promotion: null,
      feedbackCapabilities: const {},
      payload: CompletionFeedPayload(completed: 0, total: 1, tasks: [task]),
    );

Map<String, dynamic> _pageJson(List<Map<String, dynamic>> items) => {
  'schemaVersion': 1,
  'algorithmVersion': 'musician-v1',
  'feedSessionId': 'session-id',
  'generatedAt': '2026-09-11T10:00:00Z',
  'items': items,
  'nextCursor': null,
  'hasMore': false,
};

Map<String, dynamic> _itemJson(
  String id,
  String type,
  Map<String, dynamic> payload, {
  bool promotion = false,
}) => {
  'id': id,
  'type': type,
  'payloadVersion': 1,
  'occurredAt': '2026-09-11T09:00:00Z',
  'position': 0,
  'impressionToken': 'delivery-token-$id',
  'reason': {
    'code': promotion ? 'SPONSORED' : 'DISCOVERY',
    'actors': const [],
    'secondaryActorCount': 0,
  },
  'author': type == 'PROFILE_COMPLETION' ? null : _authorJson(),
  'target': null,
  'engagement': null,
  'promotion': promotion
      ? {
          'campaignId': 'campaign-id',
          'disclosure': 'SPONSORED',
          'ctaLabel': 'İncele',
          'ctaUrl': '/collab',
        }
      : null,
  'feedbackCapabilities': const ['HIDE', 'SHOW_LESS', 'REPORT'],
  'payload': payload,
};

Map<String, dynamic> _authorJson() => {
  'userId': 'user-id',
  'profileId': 'profile-id',
  'profileType': 'MUSICIAN',
  'username': 'deniz',
  'displayName': 'Deniz',
  'avatarUrl': null,
  'followedByViewer': true,
};

MusicianFeedPage _page(String id, {bool collab = false}) => MusicianFeedPage(
  schemaVersion: 1,
  algorithmVersion: 'musician-v1',
  feedSessionId: 'session-id',
  generatedAt: DateTime.utc(2026, 9, 11),
  items: [
    MusicianFeedItem(
      id: id,
      type: collab ? MusicianFeedItemType.collab : MusicianFeedItemType.track,
      payloadVersion: 1,
      occurredAt: DateTime.utc(2026, 9, 11),
      position: 0,
      impressionToken: 'delivery-token-$id',
      reason: const MusicianFeedReason(
        code: 'DISCOVERY',
        actors: [],
        secondaryActorCount: 0,
      ),
      author: null,
      target: null,
      engagement: collab
          ? null
          : const MusicianFeedEngagement(
              targetType: 'MEDIA',
              targetId: 'media-id',
              likeCount: 2,
              commentCount: 1,
              likedByMe: false,
              likable: true,
              commentable: true,
            ),
      promotion: null,
      feedbackCapabilities: const {
        MusicianFeedFeedbackAction.hide,
        MusicianFeedFeedbackAction.showLess,
      },
      payload: collab
          ? const CollabFeedPayload(
              listing: {'id': 'listing-id', 'savedByMe': false},
            )
          : const TrackFeedPayload(
              trackId: 'track-id',
              mediaAssetId: 'media-id',
              title: 'Parça',
              playbackUrl: null,
              durationSeconds: 120,
              bpm: null,
            ),
    ),
  ],
  nextCursor: null,
  hasMore: false,
);

MusicianFeedPage _itemsPage(
  List<MusicianFeedItem> items, {
  bool hasMore = false,
  String? nextCursor,
}) => MusicianFeedPage(
  schemaVersion: 1,
  algorithmVersion: 'musician-v1',
  feedSessionId: 'session-id',
  generatedAt: DateTime.utc(2026, 9, 11),
  items: items,
  nextCursor: nextCursor,
  hasMore: hasMore,
);

MusicianFeedItem _trackItem(
  String id, {
  String? authorUserId,
  String authorProfileType = 'MUSICIAN',
  String? authorProfileId,
  Set<MusicianFeedFeedbackAction> feedbackCapabilities = const {
    MusicianFeedFeedbackAction.hide,
    MusicianFeedFeedbackAction.showLess,
  },
}) => MusicianFeedItem(
  id: id,
  type: MusicianFeedItemType.track,
  payloadVersion: 1,
  occurredAt: DateTime.utc(2026, 9, 11),
  position: 0,
  impressionToken: 'delivery-token-$id',
  reason: const MusicianFeedReason(
    code: 'DISCOVERY',
    actors: [],
    secondaryActorCount: 0,
  ),
  author: authorUserId == null
      ? null
      : MusicianFeedActor(
          userId: authorUserId,
          profileId: authorProfileId ?? 'profile-$authorUserId',
          profileType: authorProfileType,
          username: authorUserId,
          displayName: authorUserId,
          avatarUrl: null,
          followedByViewer: true,
        ),
  target: null,
  engagement: const MusicianFeedEngagement(
    targetType: 'MEDIA',
    targetId: 'media-id',
    likeCount: 2,
    commentCount: 1,
    likedByMe: false,
    likable: true,
    commentable: true,
  ),
  promotion: null,
  feedbackCapabilities: feedbackCapabilities,
  payload: TrackFeedPayload(
    trackId: 'track-$id',
    mediaAssetId: 'media-$id',
    title: 'Parça $id',
    playbackUrl: null,
    durationSeconds: 120,
    bpm: null,
  ),
);

MusicianFeedItem _profileItem(
  String id, {
  required String profileType,
  required String profileId,
  required String userId,
}) => MusicianFeedItem(
  id: id,
  type: MusicianFeedItemType.profile,
  payloadVersion: 1,
  occurredAt: DateTime.utc(2026, 9, 11),
  position: 0,
  impressionToken: 'delivery-token-$id',
  reason: const MusicianFeedReason(
    code: 'DISCOVERY',
    actors: [],
    secondaryActorCount: 0,
  ),
  author: null,
  target: MusicianFeedTarget(type: 'PROFILE', id: profileId),
  engagement: null,
  promotion: null,
  feedbackCapabilities: const {
    MusicianFeedFeedbackAction.hide,
    MusicianFeedFeedbackAction.showLess,
  },
  payload: ProfileFeedPayload(
    profileId: profileId,
    profileType: profileType,
    userId: userId,
    username: 'profile-user',
    displayName: 'Profil',
    avatarUrl: null,
    bio: null,
    location: null,
    followedByViewer: false,
  ),
);

AudienceTestSessions _musicianSessions() => AudienceTestSessions(
  audienceSession(
    user: 'viewer-id',
    token: 'viewer-token',
    role: 'ROLE_MUSICIAN',
  ),
);

class _RecordingFeedNavigation extends Fake implements MusicianFeedNavigation {
  final recordedOpenIds = <String>[];
  final opened = <String>[];
  final promotionPayloadUrls = <String?>[];

  @override
  void recordOpen(MusicianFeedItem item) => recordedOpenIds.add(item.id);

  @override
  Future<void> openCollab(
    MusicianFeedItem item,
    CollabFeedPayload payload,
  ) async {
    opened.add('collab');
  }

  @override
  Future<void> openEvent(
    MusicianFeedItem item,
    EventFeedPayload payload,
  ) async {
    opened.add('event');
  }

  @override
  Future<void> openPromotion(
    MusicianFeedItem item, {
    SponsoredFeedPayload? payload,
  }) async {
    opened.add('promotion');
    promotionPayloadUrls.add(payload?.ctaUrl);
  }

  @override
  Future<void> openProfileShare(
    MusicianFeedItem item,
    ProfileShareFeedPayload payload,
    MusicianFeedItemType type,
  ) async {
    opened.add('share:${type.name}');
  }
}

MusicianFeedItem _registryItem({
  required String id,
  required MusicianFeedItemType type,
  required MusicianFeedPayload payload,
  MusicianFeedPromotion? promotion,
}) => MusicianFeedItem(
  id: id,
  type: type,
  payloadVersion: 1,
  occurredAt: DateTime.utc(2026, 9, 11),
  position: 0,
  impressionToken: 'delivery-token-$id',
  reason: const MusicianFeedReason(
    code: 'DISCOVERY',
    actors: [],
    secondaryActorCount: 0,
  ),
  author: null,
  target: null,
  engagement: null,
  promotion: promotion,
  feedbackCapabilities: const {},
  payload: payload,
);

MusicianFeedItem _validCollabFeedItem() => _registryItem(
  id: 'collab',
  type: MusicianFeedItemType.collab,
  payload: const CollabFeedPayload(
    listing: {
      'id': 'listing-id',
      'version': 1,
      'status': 'OPEN',
      'closureReason': null,
      'cadence': 'REGULAR',
      'wantedType': 'MUSICIAN',
      'instrument': {'id': 'bass-id', 'name': 'Bas Gitar'},
      'branch': null,
      'customSpecialty': null,
      'title': 'Bas gitarist aranıyor',
      'description': 'Haftalık sahne programı için ekip arkadaşı arıyoruz.',
      'city': {'id': 'istanbul-id', 'name': 'İstanbul'},
      'genres': ['Rock'],
      'scheduledAt': null,
      'expiresAt': '2026-10-01T12:00:00Z',
      'feeAmountMinor': null,
      'currency': null,
      'feeStatus': 'UNSPECIFIED',
      'publishedAt': '2026-09-11T10:00:00Z',
      'createdAt': '2026-09-11T09:55:00Z',
      'closedAt': null,
      'publisher': {
        'actorId': 'venue-actor-id',
        'profileType': 'VENUE',
        'sourceProfileId': 'venue-profile-id',
        'contactUserId': 'venue-user-id',
        'displayName': 'Kadıköy Sahne',
        'avatarUrl': null,
        'rating': 4.8,
        'reviewCount': 12,
        'completedJobCount': 31,
      },
      'ownedByMe': false,
      'appliedByMe': false,
      'savedByMe': false,
      'applicationCount': 2,
    },
  ),
);

class _FeedRepository extends Fake implements MusicianFeedRepository {
  final responses = <Future<Result<MusicianFeedPage>>>[];
  final loadCursors = <String?>[];
  Result<void> feedbackResult = const Result.success(null);
  Future<Result<void>>? feedbackFuture;
  Future<Result<void>>? muteFuture;
  Result<void> unmuteResult = const Result.success(null);
  final muteCalls = <MusicianFeedAuthorProfileIdentity>[];
  final unmuteCalls = <MusicianFeedAuthorProfileIdentity>[];
  final feedbackCalls =
      <
        ({
          String itemId,
          String impressionToken,
          MusicianFeedFeedbackAction action,
          String? reason,
        })
      >[];

  @override
  Future<Result<MusicianFeedPage>> load({required int limit, String? cursor}) {
    loadCursors.add(cursor);
    return responses.removeAt(0);
  }

  @override
  Future<Result<void>> sendFeedback({
    required String itemId,
    required String impressionToken,
    required MusicianFeedFeedbackAction action,
    String? reason,
  }) {
    feedbackCalls.add((
      itemId: itemId,
      impressionToken: impressionToken,
      action: action,
      reason: reason,
    ));
    return feedbackFuture ?? Future.value(feedbackResult);
  }

  final eventCalls = <({String token, MusicianFeedTelemetryEventType type})>[];

  @override
  Future<Result<void>> recordEvent({
    required String clientEventId,
    required String impressionToken,
    required MusicianFeedTelemetryEventType eventType,
    DateTime? occurredAt,
  }) async {
    eventCalls.add((token: impressionToken, type: eventType));
    return const Result.success(null);
  }

  @override
  Future<Result<void>> muteAuthor({
    required String profileType,
    required String profileId,
  }) {
    muteCalls.add((profileType: profileType, profileId: profileId));
    return muteFuture ?? Future.value(const Result.success(null));
  }

  @override
  Future<Result<void>> unmuteAuthor({
    required String profileType,
    required String profileId,
  }) async {
    unmuteCalls.add((profileType: profileType, profileId: profileId));
    return unmuteResult;
  }
}

class _EngagementRepository extends Fake implements EngagementRepository {
  Result<void> likeResult = const Result.success(null);
  Future<Result<void>>? likeFuture;
  final likeCalls = <(String, String)>[];

  @override
  Future<Result<void>> like({
    required String targetType,
    required String targetId,
  }) {
    likeCalls.add((targetType, targetId));
    return likeFuture ?? Future.value(likeResult);
  }

  @override
  Future<Result<void>> unlike({
    required String targetType,
    required String targetId,
  }) async => const Result.success(null);
}

class _CollabRepository extends Fake implements CollabRepository {
  Result<void> saveResult = const Result.success(null);
  Future<Result<void>>? saveFuture;
  final savedIds = <String>[];

  @override
  Future<Result<void>> saveListing(String listingId) {
    savedIds.add(listingId);
    return saveFuture ?? Future.value(saveResult);
  }

  @override
  Future<Result<void>> unsaveListing(String listingId) async =>
      const Result.success(null);
}

class _FollowRepository extends Fake implements FollowRepository {
  Future<Result<void>>? followFuture;
  Result<void> followResult = const Result.success(null);
  final followCalls = <(String, String)>[];

  @override
  Future<Result<void>> follow({
    required String followerId,
    required String followingId,
  }) {
    followCalls.add((followerId, followingId));
    return followFuture ?? Future.value(followResult);
  }
}

class _BandFollowRepository extends Fake implements BandFollowRepository {
  Future<Result<void>>? followFuture;
  Result<void> followResult = const Result.success(null);
  final followedBandIds = <String>[];

  @override
  Future<Result<void>> followBand(String bandId) {
    followedBandIds.add(bandId);
    return followFuture ?? Future.value(followResult);
  }
}

MusicianFeedPreferences _feedPreferences({
  required int version,
  required String cityId,
}) => MusicianFeedPreferences(
  contractVersion: 1,
  version: version,
  opportunityCity: MusicianFeedPreferenceCity(
    id: cityId,
    name: switch (cityId) {
      'ankara' => 'Ankara',
      'izmir' => 'İzmir',
      _ => 'İstanbul',
    },
  ),
  instruments: const [],
);

class _OpportunityCityPreferencesRepository extends Fake
    implements MusicianFeedPreferencesRepository {
  _OpportunityCityPreferencesRepository({
    required List<Result<MusicianFeedPreferences>> getResults,
    required List<Result<MusicianFeedPreferences>> updateResults,
  }) : _getResults = List.of(getResults),
       _updateResults = List.of(updateResults);

  final List<Result<MusicianFeedPreferences>> _getResults;
  final List<Result<MusicianFeedPreferences>> _updateResults;
  final updateCalls = <({String? cityId, int expectedVersion})>[];
  int getCallCount = 0;

  @override
  Future<Result<MusicianFeedPreferences>> get() async {
    getCallCount += 1;
    return _getResults.removeAt(0);
  }

  @override
  Future<Result<MusicianFeedPreferences>> updateOpportunityCity({
    required String? cityId,
    required int expectedVersion,
  }) async {
    updateCalls.add((cityId: cityId, expectedVersion: expectedVersion));
    return _updateResults.removeAt(0);
  }
}

class _OpportunityCityLocationRepository extends Fake
    implements LocationRepository {
  @override
  Future<Result<List<City>>> getCities() async => const Result.success([
    City(id: 'istanbul', name: 'İstanbul'),
    City(id: 'ankara', name: 'Ankara'),
    City(id: 'izmir', name: 'İzmir'),
  ]);
}
