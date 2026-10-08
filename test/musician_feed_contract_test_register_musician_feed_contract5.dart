part of 'musician_feed_contract_test.dart';

void _registerMusicianFeedContract5() {
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
    _registerMusicianFeedCubit1();
    _registerMusicianFeedCubit2();
    _registerMusicianFeedCubit3();
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

  for (final afterConfirmation in [false, true]) {
    testWidgets(
      'mute dialog and undo remain bound to their opening login ($afterConfirmation)',
      (tester) async {
        final sessions = _musicianSessions();
        final items = [_trackItem('first', authorUserId: 'author-a')];
        final feed = _FeedRepository()
          ..responses.add(Future.value(Result.success(_itemsPage(items))));
        final cubit = MusicianFeedCubit(
          feed,
          _EngagementRepository(),
          collabRepository: _CollabRepository(),
          followRepository: _FollowRepository(),
          bandFollowRepository: _BandFollowRepository(),
          sessions: sessions,
        );
        addTearDown(sessions.dispose);
        addTearDown(cubit.close);
        await cubit.initialize();
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.navy,
            home: Scaffold(
              body: BlocProvider.value(
                value: cubit,
                child: MusicianFeedView(
                  registry: MusicianFeedCardRegistry({
                    for (final type in MusicianFeedItemType.values)
                      type: MusicianFeedCardRegistration.presentationOnly(
                        (context, item, actions) => TextButton(
                          onPressed: () =>
                              actions.muteAuthor(item, item.author!),
                          child: const Text('Open mute dialog'),
                        ),
                      ),
                  }),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open mute dialog'));
        await tester.pumpAndSettle();
        VoidCallback? oldUndo;
        if (afterConfirmation) {
          await tester.tap(find.text('Sessize al'));
          await tester.pumpAndSettle();
          oldUndo = tester
              .widget<SnackBarAction>(find.byType(SnackBarAction))
              .onPressed;
        }
        sessions.replace(
          audienceSession(
            user: 'other-viewer',
            token: 'other-token',
            role: 'ROLE_MUSICIAN',
          ),
        );
        if (afterConfirmation) {
          feed.responses.add(Future.value(Result.success(_itemsPage(items))));
          await cubit.refresh();
          expect(
            await cubit.muteAuthor(
              sourceItemId: 'first',
              profileType: 'MUSICIAN',
              profileId: 'profile-author-a',
            ),
            isTrue,
          );
          oldUndo!();
          await tester.pump();
          expect(feed.unmuteCalls, isEmpty);
        } else {
          await tester.tap(find.text('Sessize al'));
          await tester.pumpAndSettle();
          expect(feed.muteCalls, isEmpty);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

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
