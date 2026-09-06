part of 'event_performer_request_flow_test.dart';

void _publicationChoiceTests() {
  testWidgets('stale acceptance callback cannot submit a second decision', (
    tester,
  ) async {
    final completion = Completer<Result<void>>();
    final repository = _FakePerformerRequestRepository(
      pages: {
        0: _page([_request()]),
      },
      acceptCompletion: completion,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: EventPerformerRequestsScreen(
          targetType: EventPerformerTargetType.band,
          targetId: 'band-1',
          repository: repository,
          sessionKeyProvider: () => 'owner',
        ),
      ),
    );
    await tester.pumpAndSettle();
    final action = find.byKey(const Key('accept-event-request-request-1'));
    await tester.ensureVisible(action);
    final staleAccept = tester.widget<GradientOutlineButton>(action).onPressed!;
    await _tapRequestControl(
      tester,
      find.byKey(const Key('accept-event-request-request-1')),
    );
    await tester.pump();
    expect(tester.widget<GradientOutlineButton>(action).onPressed, isNull);
    staleAccept();
    await tester.pump();
    expect(
      find.byKey(const Key('accept-event-request-request-1')),
      findsOneWidget,
    );
    completion.complete(const Result<void>.success(null));
    await tester.pumpAndSettle();
    expect(repository.acceptCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('repeated rejection dialog callback never pops the inbox route', (
    tester,
  ) async {
    final repository = _FakePerformerRequestRepository(
      pages: {
        0: _page([_request()]),
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) =>
                      EventPerformerRequestsScreen(repository: repository),
                ),
              ),
              child: const Text('Open inbox'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open inbox'));
    await tester.pumpAndSettle();
    await _tapRequestControl(
      tester,
      find.byKey(const Key('reject-event-request-request-1')),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final finish = tester
        .widget<GradientOutlineButton>(
          find.byKey(const Key('confirm-reject-request-1')),
        )
        .onPressed!;
    finish();
    finish();
    await tester.pumpAndSettle();
    finish();
    await tester.pumpAndSettle();
    expect(repository.rejectCalls, 1);
    expect(find.text('Etkinlik Davetleri'), findsOneWidget);
    expect(find.text('Open inbox'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'publication choice belongs to one request and locks during approval',
    (tester) async {
      final completion = Completer<Result<void>>();
      final repository = _FakePerformerRequestRepository(
        pages: {
          0: _page([_request(), _request(requestId: 'request-2')]),
        },
        acceptCompletion: completion,
      );
      await tester.pumpWidget(
        MaterialApp(home: EventPerformerRequestsScreen(repository: repository)),
      );
      await tester.pumpAndSettle();
      final first = find.byKey(
        const Key('show-on-profile-event-request-request-1'),
      );
      await _tapRequestControl(tester, first);
      await tester.pump();
      expect(tester.widget<CheckboxListTile>(first).value, isTrue);

      final second = find.byKey(
        const Key('show-on-profile-event-request-request-2'),
      );
      await tester.scrollUntilVisible(
        second,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.widget<CheckboxListTile>(second).value, isFalse);
      await _tapRequestControl(
        tester,
        find.byKey(const Key('accept-event-request-request-2')),
      );
      await tester.pump();
      expect(repository.acceptChoices, [('request-2', false)]);
      expect(tester.widget<CheckboxListTile>(second).onChanged, isNull);
      completion.complete(const Result.success(null));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        first,
        -250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.widget<CheckboxListTile>(first).value, isFalse);
    },
  );

  testWidgets(
    'selected publication payload is captured and cannot change in flight',
    (tester) async {
      final completion = Completer<Result<void>>();
      final repository = _FakePerformerRequestRepository(
        pages: {
          0: _page([_request()]),
        },
        acceptCompletion: completion,
      );
      await tester.pumpWidget(
        MaterialApp(home: EventPerformerRequestsScreen(repository: repository)),
      );
      await tester.pumpAndSettle();
      final checkbox = find.byType(CheckboxListTile);
      await _tapRequestControl(tester, checkbox);
      await tester.pump();
      final staleCallback = tester
          .widget<EventPerformerRequestCard>(
            find.byType(EventPerformerRequestCard),
          )
          .onShowOnProfileChanged!;
      await _tapRequestControl(
        tester,
        find.byKey(const Key('accept-event-request-request-1')),
      );
      await tester.pump();
      staleCallback(false);
      await tester.pump();
      expect(repository.acceptChoices, [('request-1', true)]);
      expect(tester.widget<CheckboxListTile>(checkbox).value, isTrue);
      expect(tester.widget<CheckboxListTile>(checkbox).onChanged, isNull);
      completion.complete(const Result.success(null));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'refresh clears publication choice and ignores old card callback',
    (tester) async {
      final refreshed = Completer<Result<EventPerformerRequestPage>>();
      final repository = _FakePerformerRequestRepository(
        listFutures: [
          Future.value(Result.success(_page([_request()]))),
          refreshed.future,
        ],
      );
      await tester.pumpWidget(
        MaterialApp(home: EventPerformerRequestsScreen(repository: repository)),
      );
      await tester.pumpAndSettle();
      final checkbox = find.byType(CheckboxListTile);
      await _tapRequestControl(tester, checkbox);
      await tester.pump();
      final staleCallback = tester
          .widget<EventPerformerRequestCard>(
            find.byType(EventPerformerRequestCard),
          )
          .onShowOnProfileChanged!;
      final refresh = tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pump();
      expect(tester.widget<CheckboxListTile>(checkbox).value, isFalse);
      staleCallback(true);
      await tester.pump();
      expect(tester.widget<CheckboxListTile>(checkbox).value, isFalse);
      refreshed.complete(Result.success(_page([_request()])));
      await refresh;
      await tester.pumpAndSettle();
      expect(tester.widget<CheckboxListTile>(checkbox).value, isFalse);
    },
  );

  testWidgets(
    'same request id in changed band scope cannot inherit publication',
    (tester) async {
      final repository = _FakePerformerRequestRepository(
        listResults: [
          Result.success(_page([_request(targetId: 'band-1')])),
          Result.success(_page([_request(targetId: 'band-2')])),
        ],
      );
      Widget app(String bandId) => MaterialApp(
        home: EventPerformerRequestsScreen(
          key: const Key('scoped-publication'),
          repository: repository,
          targetType: EventPerformerTargetType.band,
          targetId: bandId,
        ),
      );
      await tester.pumpWidget(app('band-1'));
      await tester.pumpAndSettle();
      await _tapRequestControl(tester, find.byType(CheckboxListTile));
      await tester.pump();
      final staleCallback = tester
          .widget<EventPerformerRequestCard>(
            find.byType(EventPerformerRequestCard),
          )
          .onShowOnProfileChanged!;
      await tester.pumpWidget(app('band-2'));
      await tester.pumpAndSettle();
      staleCallback(true);
      await tester.pump();
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isFalse,
      );
      expect(repository.targetIds, ['band-1', 'band-2']);
    },
  );

  for (final change in ['logout', 'other-account', 'same-account-new-token']) {
    testWidgets(
      'session change discards selected publication immediately: $change',
      (tester) async {
        await serviceLocator.reset();
        final session = _ApprovalChoiceSession()..signIn('founder');
        serviceLocator.registerSingleton<AuthSessionManager>(session);
        addTearDown(() async {
          session.dispose();
          await serviceLocator.reset();
        });
        final repository = _FakePerformerRequestRepository(
          pages: {
            0: _page([_request()]),
          },
        );
        await tester.pumpWidget(
          MaterialApp(
            home: EventPerformerRequestsScreen(repository: repository),
          ),
        );
        await tester.pumpAndSettle();
        await _tapRequestControl(tester, find.byType(CheckboxListTile));
        await tester.pump();
        final staleCard = tester.widget<EventPerformerRequestCard>(
          find.byType(EventPerformerRequestCard),
        );
        if (change == 'logout') {
          session.end();
        } else {
          session.signIn(change == 'other-account' ? 'other' : 'founder');
        }
        await tester.pumpAndSettle();
        expect(find.byType(EventPerformerRequestCard), findsNothing);
        expect(find.textContaining('Oturum değişti'), findsOneWidget);
        staleCard.onAccept();
        staleCard.onShowOnProfileChanged!(true);
        await tester.pump();
        expect(repository.acceptCalls, 0);
        expect(repository.rejectCalls, 0);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'legacy approval fails closed even when callback is invoked directly',
    (tester) async {
      final repository = _FakePerformerRequestRepository(
        pages: {
          0: _page([_request(profileCalendarApproved: null)]),
        },
      );
      await tester.pumpWidget(
        MaterialApp(home: EventPerformerRequestsScreen(repository: repository)),
      );
      await tester.pumpAndSettle();
      final card = tester.widget<EventPerformerRequestCard>(
        find.byType(EventPerformerRequestCard),
      );
      card.onShowOnProfileChanged!(true);
      card.onAccept();
      await tester.pumpAndSettle();
      expect(repository.acceptCalls, 0);
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isFalse,
      );
      expect(find.textContaining('Güvenli onay için'), findsWidgets);
      await _tapRequestControl(
        tester,
        find.byKey(const Key('reject-event-request-request-1')),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const Key('confirm-reject-request-1')));
      await tester.pumpAndSettle();
      expect(repository.rejectCalls, 1);
    },
  );
}

class _ApprovalChoiceSession extends AuthSessionManager {
  _ApprovalChoiceSession()
    : super(
        tokenStore: MemoryTokenStore(),
        sessionStore: MemoryAuthSessionStore(),
      );
  AuthSession _current = const AuthSession.guest();
  int _revision = 0;
  @override
  AuthSession get session => _current;
  void signIn(String userId) {
    _current = AuthSession.authenticated(
      token: 'token-${++_revision}',
      userId: userId,
      username: 'bugrasahin',
      accountStatus: 'ACTIVE',
      roles: const ['ROLE_MUSICIAN'],
      permissions: const [],
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      isAdmin: false,
    );
    notifyListeners();
  }

  void end() {
    _current = const AuthSession.guest();
    notifyListeners();
  }
}
