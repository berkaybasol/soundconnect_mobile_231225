part of 'event_performer_request_flow_test.dart';

void _registerEventPerformerRequestFlow2() {
  group('event performer request screen', () {
    _publicationChoiceTests();
    for (final target in EventPerformerTargetType.values) {
      testWidgets('$target can approve while calendar display remains off', (
        tester,
      ) async {
        await serviceLocator.reset();
        addTearDown(serviceLocator.reset);
        final calendar = _DisabledApprovalCalendarRepository();
        serviceLocator.registerSingleton<MusicianCalendarRepository>(calendar);
        final bandCalendar = _DisabledApprovalCalendarRepository();
        final bandCalendars = _DisabledApprovalBandCalendarFactory(
          bandCalendar,
        );
        serviceLocator.registerSingleton<BandCalendarRepositoryFactory>(
          bandCalendars,
        );
        final targetId = target == EventPerformerTargetType.band
            ? 'band-1'
            : 'musician-1';
        final repository = _FakePerformerRequestRepository(
          pages: {
            0: _page([_request(targetType: target, targetId: targetId)]),
          },
        );
        await tester.pumpWidget(
          MaterialApp(
            home: EventPerformerRequestsScreen(
              repository: repository,
              targetType: target,
              targetId: targetId,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Etkinlik Davetleri'), findsOneWidget);
        await _tapRequestControl(
          tester,
          find.byKey(const Key('accept-event-request-request-1')),
        );
        await tester.pumpAndSettle();
        expect(repository.acceptCalls, 1);
        expect(repository.acceptChoices, [('request-1', false)]);
        expect(calendar.reads, 0);
        expect(calendar.updates, 0);
        expect(bandCalendars.acquires, 0);
        expect(bandCalendar.reads, 0);
        expect(bandCalendar.updates, 0);
        expect(find.byType(SwitchListTile), findsNothing);
      });
    }

    testWidgets(
      'account switch during performer rejection confirmation never writes',
      (tester) async {
        var session = 'founder-a';
        final repository = _FakePerformerRequestRepository(
          pages: {
            0: _page([_request()]),
          },
        );
        await tester.pumpWidget(
          MaterialApp(
            home: EventPerformerRequestsScreen(
              repository: repository,
              sessionKeyProvider: () => session,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await _tapRequestControl(
          tester,
          find.byKey(const Key('reject-event-request-request-1')),
        );
        // The card has an in-progress indicator while its dialog is open.
        await tester.pump(const Duration(milliseconds: 300));
        session = 'founder-b';
        await tester.tap(find.byKey(const Key('confirm-reject-request-1')));
        await tester.pumpAndSettle();
        expect(repository.rejectCalls, 0);
        expect(find.text('Sahbaz Gecesi'), findsNothing);
        expect(find.textContaining('Oturum değişti'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'account switch during performer page load discards private results',
      (tester) async {
        var session = 'founder-a';
        final pending = Completer<Result<EventPerformerRequestPage>>();
        final repository = _FakePerformerRequestRepository(
          listFutures: [pending.future],
        );
        await tester.pumpWidget(
          MaterialApp(
            home: EventPerformerRequestsScreen(
              repository: repository,
              sessionKeyProvider: () => session,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump();
        expect(repository.listCalls, 1);
        session = 'founder-b';
        pending.complete(Result.success(_page([_request()])));
        await tester.pumpAndSettle();
        expect(find.text('Sahbaz Gecesi'), findsNothing);
        expect(find.textContaining('Oturum değişti'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('accept is single-flight and removes the resolved request', (
      tester,
    ) async {
      final completion = Completer<Result<void>>();
      final repository = _FakePerformerRequestRepository(
        pages: <int, EventPerformerRequestPage>{
          0: _page(<EventPerformerRequest>[_request()]),
        },
        acceptCompletion: completion,
      );
      await tester.pumpWidget(
        MaterialApp(home: EventPerformerRequestsScreen(repository: repository)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sahbaz Gecesi'), findsOneWidget);
      await _tapRequestControl(
        tester,
        find.byKey(const Key('accept-event-request-request-1')),
      );
      await tester.pump();
      await _tapRequestControl(
        tester,
        find.byKey(const Key('accept-event-request-request-1')),
        warnIfMissed: false,
      );
      expect(repository.acceptCalls, 1);

      completion.complete(const Result.success(null));
      await tester.pumpAndSettle();
      expect(find.text('Bekleyen etkinlik daveti yok'), findsOneWidget);
    });

    testWidgets('refresh cannot replay a locally resolved request', (
      tester,
    ) async {
      final repository = _FakePerformerRequestRepository(
        pages: <int, EventPerformerRequestPage>{
          0: _page(<EventPerformerRequest>[_request()]),
        },
      );
      await tester.pumpWidget(
        MaterialApp(home: EventPerformerRequestsScreen(repository: repository)),
      );
      await tester.pumpAndSettle();

      await _tapRequestControl(
        tester,
        find.byKey(const Key('accept-event-request-request-1')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Bekleyen etkinlik daveti yok'), findsOneWidget);

      final refreshFuture = tester
          .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
          .show();
      await tester.pump();
      await tester.pumpAndSettle();
      await refreshFuture;

      expect(find.text('Bekleyen etkinlik daveti yok'), findsOneWidget);
      expect(
        find.byKey(const Key('accept-event-request-request-1')),
        findsNothing,
      );
      expect(repository.acceptCalls, 1);
    });

    testWidgets(
      'decision reloads page zero so offset shrink cannot skip an item',
      (tester) async {
        // Keep the action in view: this case isolates decision reconciliation,
        // while separate tests exercise scroll-triggered/explicit pagination.
        await tester.binding.setSurfaceSize(const Size(800, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final repository = _FakePerformerRequestRepository(
          listResults: <Result<EventPerformerRequestPage>>[
            Result.success(
              _page(<EventPerformerRequest>[_request()], hasNext: true),
            ),
            Result.success(
              _page(<EventPerformerRequest>[
                _request(
                  requestId: 'request-shifted',
                  performerName: 'Sıradaki Grup',
                ),
              ]),
            ),
          ],
        );
        await tester.pumpWidget(
          MaterialApp(
            home: EventPerformerRequestsScreen(repository: repository),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('accept-event-request-request-1')),
        );
        await tester.pumpAndSettle();

        expect(repository.requestedPages, <int>[0, 0]);
        expect(find.text('Sıradaki Grup • Grup'), findsOneWidget);
      },
    );

    testWidgets('out-of-range next page reconciles from page zero', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _FakePerformerRequestRepository(
        listResults: <Result<EventPerformerRequestPage>>[
          Result.success(
            _page(<EventPerformerRequest>[_request()], hasNext: true),
          ),
          const Result.success(
            EventPerformerRequestPage(
              items: <EventPerformerRequest>[],
              page: 1,
              size: 20,
              totalElements: 1,
              totalPages: 1,
              hasNext: false,
            ),
          ),
          Result.success(
            _page(<EventPerformerRequest>[
              _request(
                requestId: 'request-reconciled',
                performerName: 'Güncel Grup',
              ),
            ]),
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(home: EventPerformerRequestsScreen(repository: repository)),
      );
      await tester.pumpAndSettle();

      // The wide viewport already exposes the footer; scrolling to align it
      // would itself trigger automatic pagination before the explicit tap.
      await tester.tap(
        find.byKey(const Key('load-more-event-performer-requests')),
      );
      await tester.pumpAndSettle();

      expect(repository.requestedPages, <int>[0, 1, 0]);
      expect(find.text('Güncel Grup • Grup'), findsOneWidget);
    });

    testWidgets('band scoped screen hides another target request', (
      tester,
    ) async {
      final repository = _FakePerformerRequestRepository(
        pages: <int, EventPerformerRequestPage>{
          0: _page(<EventPerformerRequest>[
            _request(),
            _request(
              requestId: 'request-2',
              targetType: EventPerformerTargetType.musician,
              targetId: 'musician-1',
              performerName: 'Büğra Şahin',
            ),
          ]),
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: EventPerformerRequestsScreen(
            repository: repository,
            targetType: EventPerformerTargetType.band,
            targetId: 'band-1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sahbaz • Grup'), findsOneWidget);
      expect(find.textContaining('Büğra'), findsNothing);
      expect(repository.targetTypes, <EventPerformerTargetType?>[
        EventPerformerTargetType.band,
      ]);
      expect(repository.targetIds, <String?>['band-1']);
    });

    testWidgets('renders the first page then loads the next page on demand', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _FakePerformerRequestRepository(
        pages: <int, EventPerformerRequestPage>{
          0: _page(<EventPerformerRequest>[_request()], hasNext: true),
          1: _page(<EventPerformerRequest>[
            _request(requestId: 'request-2', performerName: 'İkinci Grup'),
          ], page: 1),
        },
      );
      await tester.pumpWidget(
        MaterialApp(home: EventPerformerRequestsScreen(repository: repository)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sahbaz • Grup'), findsOneWidget);
      expect(repository.requestedPages, <int>[0]);
      await tester.tap(
        find.byKey(const Key('load-more-event-performer-requests')),
      );
      await tester.pumpAndSettle();

      expect(find.text('İkinci Grup • Grup'), findsOneWidget);
      expect(repository.requestedPages, <int>[0, 1]);
    });

    testWidgets(
      'invitation page cap preserves results and refresh without requesting page 101',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final repository = _FakePerformerRequestRepository(
          pages: {
            for (var page = 0; page <= 100; page++)
              page: EventPerformerRequestPage(
                items: [_request()],
                page: page,
                size: 20,
                totalElements: 2040,
                totalPages: 102,
                hasNext: true,
              ),
          },
        );
        await tester.pumpWidget(
          MaterialApp(
            home: EventPerformerRequestsScreen(repository: repository),
          ),
        );
        await tester.pumpAndSettle();
        final savedMore = tester
            .widget<TextButton>(
              find.byKey(const Key('load-more-event-performer-requests')),
            )
            .onPressed!;
        for (var page = 1; page <= 100; page++) {
          savedMore();
          await tester.pumpAndSettle();
        }
        expect(repository.requestedPages, List.generate(101, (i) => i));
        expect(find.text('Sahbaz • Grup'), findsOneWidget);
        expect(
          find.byKey(const Key('event-invitation-page-limit')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('load-more-event-performer-requests')),
          findsNothing,
        );
        savedMore();
        await tester.pumpAndSettle();
        expect(repository.listCalls, 101);
        final refresh = tester
            .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
            .show();
        await tester.pumpAndSettle();
        await refresh;
        expect(repository.requestedPages.last, 0);
        expect(
          find.byKey(const Key('event-invitation-page-limit')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('load-more-event-performer-requests')),
          findsOneWidget,
        );
        expect(repository.acceptCalls, 0);
        expect(repository.rejectCalls, 0);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'filtered invitation scans stop at the API cap without claiming an empty inbox',
      (tester) async {
        final repository = _FakePerformerRequestRepository(
          pages: {
            for (var page = 0; page <= 100; page++)
              page: EventPerformerRequestPage(
                items: [_request(targetId: 'another-band')],
                page: page,
                size: 20,
                totalElements: 2040,
                totalPages: 102,
                hasNext: true,
              ),
          },
        );
        await tester.pumpWidget(
          MaterialApp(
            home: EventPerformerRequestsScreen(
              repository: repository,
              targetType: EventPerformerTargetType.band,
              targetId: 'band-wanted',
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(repository.requestedPages, [0, 1, 2, 3]);
        final savedContinue = tester
            .widget<OutlinedButton>(
              find.byKey(const Key('continue-filtered-event-request-search')),
            )
            .onPressed!;
        for (var scan = 0; scan < 33; scan++) {
          savedContinue();
          await tester.pumpAndSettle();
        }
        expect(repository.requestedPages, List.generate(101, (i) => i));
        expect(
          find.byKey(const Key('event-invitation-page-limit')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('continue-filtered-event-request-search')),
          findsNothing,
        );
        expect(find.text('Bekleyen etkinlik daveti yok'), findsNothing);
        expect(find.text('Sahbaz • Grup'), findsNothing);
        savedContinue();
        await tester.pumpAndSettle();
        expect(repository.listCalls, 101);
        expect(repository.acceptCalls, 0);
        expect(repository.rejectCalls, 0);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('scoped inbox auto-pages before showing an empty state', (
      tester,
    ) async {
      final repository = _FakePerformerRequestRepository(
        pages: <int, EventPerformerRequestPage>{
          0: _page(<EventPerformerRequest>[
            _request(
              targetType: EventPerformerTargetType.musician,
              targetId: 'musician-1',
            ),
          ], hasNext: true),
          1: _page(<EventPerformerRequest>[
            _request(requestId: 'request-2', targetId: 'band-2'),
          ], page: 1),
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: EventPerformerRequestsScreen(
            repository: repository,
            targetType: EventPerformerTargetType.band,
            targetId: 'band-2',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bekleyen etkinlik daveti yok'), findsNothing);
      expect(find.text('Sahbaz • Grup'), findsOneWidget);
      expect(repository.requestedPages, <int>[0, 1]);
    });

    testWidgets('shows an auth-aware error and supports retry', (tester) async {
      final repository = _FakePerformerRequestRepository(
        listResults: <Result<EventPerformerRequestPage>>[
          const Result.failure(
            AppError(code: 'unauthorized', message: 'raw backend message'),
          ),
          Result.success(_page(const <EventPerformerRequest>[])),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(home: EventPerformerRequestsScreen(repository: repository)),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('yeniden giriş'), findsOneWidget);
      await _tapRequestControl(
        tester,
        find.byKey(const Key('retry-event-performer-requests')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Bekleyen etkinlik daveti yok'), findsOneWidget);
      expect(repository.listCalls, 2);
    });

    for (final accept in [true, false]) {
      testWidgets(
        'saved ${accept ? 'accept' : 'reject'} cannot act on a refreshed eligibility snapshot',
        (tester) async {
          final repository = _FakePerformerRequestRepository(
            listResults: [
              Result.success(_page([_request()])),
              Result.success(_page([_request(decisionAllowed: false)])),
            ],
          );
          await tester.pumpWidget(
            MaterialApp(
              home: EventPerformerRequestsScreen(repository: repository),
            ),
          );
          await tester.pumpAndSettle();
          final card = tester.widget<EventPerformerRequestCard>(
            find.byType(EventPerformerRequestCard),
          );
          final savedDecision = accept ? card.onAccept : card.onReject;
          await tester
              .widget<RefreshIndicator>(find.byType(RefreshIndicator))
              .onRefresh();
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<EventPerformerRequestCard>(
                  find.byType(EventPerformerRequestCard),
                )
                .decisionAllowed,
            isFalse,
          );
          savedDecision();
          await tester.pumpAndSettle();
          expect(repository.acceptCalls, 0);
          expect(repository.rejectCalls, 0);
          expect(find.byType(EventInvitationRejectionDialog), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'visible invitation choices and decisions stay disabled during refresh',
      (tester) async {
        final pending = Completer<Result<EventPerformerRequestPage>>();
        final repository = _FakePerformerRequestRepository(
          listFutures: [
            Future.value(Result.success(_page([_request()]))),
            pending.future,
          ],
        );
        await tester.pumpWidget(
          MaterialApp(
            home: EventPerformerRequestsScreen(repository: repository),
          ),
        );
        await tester.pumpAndSettle();
        final saved = tester.widget<EventPerformerRequestCard>(
          find.byType(EventPerformerRequestCard),
        );
        final refresh = tester
            .widget<RefreshIndicator>(find.byType(RefreshIndicator))
            .onRefresh();
        await tester.pump();
        final current = tester.widget<EventPerformerRequestCard>(
          find.byType(EventPerformerRequestCard),
        );
        expect(current.interactionLocked, isTrue);
        saved.onAccept();
        saved.onReject();
        saved.onShowOnProfileChanged!(true);
        await tester.pump();
        expect(repository.acceptCalls, 0);
        expect(repository.rejectCalls, 0);
        expect(find.byType(EventInvitationRejectionDialog), findsNothing);
        pending.complete(Result.success(_page([_request()])));
        await refresh;
        await tester.pumpAndSettle();
        final refreshed = tester.widget<EventPerformerRequestCard>(
          find.byType(EventPerformerRequestCard),
        );
        expect(refreshed.interactionLocked, isFalse);
        expect(refreshed.showOnProfile, isFalse);
        saved.onAccept();
        await tester.pumpAndSettle();
        expect(repository.acceptCalls, 0);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'overlapping pages retain order but replace stale action eligibility',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final repository = _FakePerformerRequestRepository(
          pages: {
            0: _page([_request()], hasNext: true),
            1: _page([_request(decisionAllowed: false)], page: 1),
          },
        );
        await tester.pumpWidget(
          MaterialApp(
            home: EventPerformerRequestsScreen(repository: repository),
          ),
        );
        await tester.pumpAndSettle();
        final saved = tester.widget<EventPerformerRequestCard>(
          find.byType(EventPerformerRequestCard),
        );
        await tester.tap(
          find.byKey(const Key('load-more-event-performer-requests')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(EventPerformerRequestCard), findsOneWidget);
        expect(
          tester
              .widget<EventPerformerRequestCard>(
                find.byType(EventPerformerRequestCard),
              )
              .decisionAllowed,
          isFalse,
        );
        saved.onAccept();
        saved.onReject();
        saved.onShowOnProfileChanged!(true);
        await tester.pumpAndSettle();
        expect(repository.acceptCalls, 0);
        expect(repository.rejectCalls, 0);
        expect(
          tester
              .widget<EventPerformerRequestCard>(
                find.byType(EventPerformerRequestCard),
              )
              .showOnProfile,
          isFalse,
        );
        expect(find.byType(EventInvitationRejectionDialog), findsNothing);
        expect(repository.requestedPages, [0, 1]);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('pull-to-refresh keeps the current page visible in flight', (
      tester,
    ) async {
      final refreshCompletion = Completer<Result<EventPerformerRequestPage>>();
      final repository = _FakePerformerRequestRepository(
        listFutures: <Future<Result<EventPerformerRequestPage>>>[
          Future.value(
            Result.success(_page(<EventPerformerRequest>[_request()])),
          ),
          refreshCompletion.future,
        ],
      );
      await tester.pumpWidget(
        MaterialApp(home: EventPerformerRequestsScreen(repository: repository)),
      );
      await tester.pumpAndSettle();

      final refreshFuture = tester
          .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
          .show();
      await tester.pump();
      expect(find.text('Sahbaz • Grup'), findsOneWidget);

      refreshCompletion.complete(
        Result.success(
          _page(<EventPerformerRequest>[
            _request(requestId: 'request-2', performerName: 'Yeni Grup'),
          ]),
        ),
      );
      await tester.pumpAndSettle();
      await refreshFuture;

      expect(find.text('Yeni Grup • Grup'), findsOneWidget);
      expect(find.text('Sahbaz • Grup'), findsNothing);
    });

    testWidgets('failed refresh preserves the usable current page', (
      tester,
    ) async {
      final repository = _FakePerformerRequestRepository(
        listResults: <Result<EventPerformerRequestPage>>[
          Result.success(_page(<EventPerformerRequest>[_request()])),
          const Result.failure(
            AppError(code: 'network', message: 'Bağlantı kurulamadı.'),
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(home: EventPerformerRequestsScreen(repository: repository)),
      );
      await tester.pumpAndSettle();

      final refreshFuture = tester
          .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
          .show();
      await tester.pump();
      await tester.pumpAndSettle();
      await refreshFuture;

      expect(find.text('Sahbaz • Grup'), findsOneWidget);
      expect(find.text('Bağlantı kurulamadı.'), findsWidgets);
      expect(
        find.byKey(const Key('retry-event-performer-requests')),
        findsNothing,
      );
    });

    testWidgets('unexpected decision failure restores the action', (
      tester,
    ) async {
      final repository = _FakePerformerRequestRepository(
        pages: <int, EventPerformerRequestPage>{
          0: _page(<EventPerformerRequest>[_request()]),
        },
        throwOnAccept: true,
      );
      await tester.pumpWidget(
        MaterialApp(home: EventPerformerRequestsScreen(repository: repository)),
      );
      await tester.pumpAndSettle();

      final accept = find.byKey(const Key('accept-event-request-request-1'));
      await _tapRequestControl(tester, accept);
      await tester.pumpAndSettle();
      expect(find.text('Sahbaz Gecesi'), findsOneWidget);
      expect(find.text('Etkinlik onayı güncellenemedi.'), findsOneWidget);

      // The longer consent explanation places the action near the snackbar.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.ensureVisible(accept);
      await _tapRequestControl(tester, accept);
      await tester.pumpAndSettle();
      expect(repository.acceptCalls, 2);
    });

    testWidgets('scoped fallback paging is bounded and explicitly resumable', (
      tester,
    ) async {
      final pages = <int, EventPerformerRequestPage>{
        for (var page = 0; page < 4; page++)
          page: _page(
            <EventPerformerRequest>[
              _request(
                requestId: 'other-$page',
                targetId: 'another-band-$page',
              ),
            ],
            page: page,
            hasNext: true,
          ),
        4: _page(<EventPerformerRequest>[
          _request(requestId: 'wanted', targetId: 'band-wanted'),
        ], page: 4),
      };
      final repository = _FakePerformerRequestRepository(pages: pages);
      await tester.pumpWidget(
        MaterialApp(
          home: EventPerformerRequestsScreen(
            repository: repository,
            targetType: EventPerformerTargetType.band,
            targetId: 'band-wanted',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(repository.requestedPages, <int>[0, 1, 2, 3]);
      expect(
        find.byKey(const Key('continue-filtered-event-request-search')),
        findsOneWidget,
      );

      await _tapRequestControl(
        tester,
        find.byKey(const Key('continue-filtered-event-request-search')),
      );
      await tester.pumpAndSettle();
      expect(repository.requestedPages, <int>[0, 1, 2, 3, 4]);
      expect(find.text('Sahbaz • Grup'), findsOneWidget);
    });

    testWidgets('a stale page cannot overwrite a changed band scope', (
      tester,
    ) async {
      final stale = Completer<Result<EventPerformerRequestPage>>();
      final repository = _FakePerformerRequestRepository(
        listFutures: <Future<Result<EventPerformerRequestPage>>>[
          stale.future,
          Future.value(
            Result.success(
              _page(<EventPerformerRequest>[
                _request(requestId: 'fresh', targetId: 'band-2'),
              ]),
            ),
          ),
        ],
      );
      const screenKey = Key('scoped-requests');
      await tester.pumpWidget(
        MaterialApp(
          home: EventPerformerRequestsScreen(
            key: screenKey,
            repository: repository,
            targetType: EventPerformerTargetType.band,
            targetId: 'band-1',
          ),
        ),
      );
      await tester.pump();

      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(repository.listCalls, 1);
      await tester.pumpWidget(
        MaterialApp(
          home: EventPerformerRequestsScreen(
            key: screenKey,
            repository: repository,
            targetType: EventPerformerTargetType.band,
            targetId: 'band-2',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sahbaz • Grup'), findsOneWidget);

      stale.complete(
        Result.success(
          _page(<EventPerformerRequest>[
            _request(requestId: 'stale', targetId: 'band-1'),
          ]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sahbaz • Grup'), findsOneWidget);
      expect(repository.targetIds, <String?>['band-1', 'band-2']);
    });
  });
}
