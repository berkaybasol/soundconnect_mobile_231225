part of 'musician_feed_contract_test.dart';

void _registerMusicianFeedContract4() {
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
          {
            ..._itemJson('announcement', 'ANNOUNCEMENT', announcementFixture()),
            'author': null,
            'reason': {
              'code': 'PLATFORM_ANNOUNCEMENT',
              'actors': [],
              'secondaryActorCount': 0,
            },
            'target': {'type': 'ANNOUNCEMENT', 'id': announcementFixtureId},
            'engagement': {
              'targetType': 'ANNOUNCEMENT',
              'targetId': announcementFixtureId,
              'likeCount': 7,
              'commentCount': 3,
              'likedByMe': false,
              'likable': true,
              'commentable': true,
            },
            'feedbackCapabilities': ['HIDE'],
          },
        ]),
      );

      expect(page.items, hasLength(14));
      expect(
        page.items.map((item) => item.type).toSet(),
        containsAll(MusicianFeedItemType.values),
      );
      expect(page.feedSessionId, 'session-id');
      expect(page.items.first.position, 0);
      expect(page.items.first.impressionToken, 'delivery-token-track');
    });

    test('accepts safe backend-relative media references', () {
      const mediaPath = '/media/audio/track.mp3';
      final item = _itemJson('relative-track', 'TRACK', {
        'trackId': 'track-id',
        'mediaAssetId': 'media-id',
        'title': 'Yerel kayıt',
        'playbackUrl': mediaPath,
        'durationSeconds': 12,
        'bpm': 108,
      });
      (item['author'] as Map<String, dynamic>)['avatarUrl'] =
          '/media/avatars/profile.webp';

      final page = MusicianFeedPage.fromJson(_pageJson([item]));
      final payload = page.items.single.payload as TrackFeedPayload;

      expect(payload.playbackUrl, mediaPath);
      expect(
        page.items.single.author?.avatarUrl,
        '/media/avatars/profile.webp',
      );
    });

    test(
      'retains local absolute HTTP media for guarded runtime resolution',
      () {
        final item = _itemJson('http-track', 'TRACK', {
          'trackId': 'track-id',
          'mediaAssetId': 'media-id',
          'title': 'Güvensiz kayıt',
          'playbackUrl': 'http://127.0.0.1:8080/media/audio/track.mp3',
          'durationSeconds': 12,
          'bpm': 108,
        });

        final page = MusicianFeedPage.fromJson(_pageJson([item]));
        expect(
          (page.items.single.payload as TrackFeedPayload).playbackUrl,
          'http://127.0.0.1:8080/media/audio/track.mp3',
        );
      },
    );

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
        'deniz ve 2 kişi daha bunu beğendi',
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
}
