part of 'event_audience_controls_test.dart';

void _registerEventAudienceControls2() {
  testWidgets(
    'new confirmed selection replaces previous queued feedback without stale toast queue',
    (tester) async {
      final repository = AudienceTestRepository();
      await _pump(tester, repository);
      final messenger = ScaffoldMessenger.of(
        tester.element(find.byType(EventAudienceControls)),
      );
      messenger.showSnackBar(const SnackBar(content: Text('Previous')));
      messenger.showSnackBar(const SnackBar(content: Text('Queued')));
      await tester.pumpAndSettle();
      await _tap(tester, 'event-audience-going');
      expect(find.text('Previous'), findsNothing);
      expect(find.text('Queued'), findsNothing);
      expect(find.text('Gidiyorum olarak işaretlendi.'), findsOneWidget);
      await _tap(tester, 'event-audience-thinking');
      expect(find.text('Gidiyorum olarak işaretlendi.'), findsNothing);
      expect(find.text('Düşünüyorum olarak işaretlendi.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 9));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
    },
  );

  testWidgets('logout cleanup never removes a newer unrelated snackbar', (
    tester,
  ) async {
    final repository = AudienceTestRepository();
    final sessions = AudienceTestSessions(audienceSession());
    await _pump(tester, repository, sessions: sessions);
    await _tap(tester, 'event-audience-going');
    final messenger = ScaffoldMessenger.of(
      tester.element(find.byType(EventAudienceControls)),
    );
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(const SnackBar(content: Text('Unrelated feedback')));
    sessions.replace(const AuthSession.guest());
    await tester.pumpAndSettle();
    expect(find.text('Unrelated feedback'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'later post-frame replacement survives previously scheduled session cleanup',
    (tester) async {
      final repository = AudienceTestRepository();
      final sessions = AudienceTestSessions(audienceSession());
      var drafts = 0;
      await _pump(
        tester,
        repository,
        sessions: sessions,
        onProfileShare: (_) async => drafts++,
      );
      await _tap(tester, 'event-audience-going');
      final oldProfileAction = _snackAction(tester);
      final messenger = ScaffoldMessenger.of(
        tester.element(find.byType(EventAudienceControls)),
      );
      // Logout schedules audience cleanup first. A separate feature replaces
      // feedback later in that same frame, before completion microtasks drain.
      sessions.replace(const AuthSession.guest());
      var replacementShown = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        messenger.removeCurrentSnackBar();
        messenger.showSnackBar(
          const SnackBar(content: Text('Later unrelated feedback')),
        );
        replacementShown = true;
      });
      await tester.pump();
      expect(replacementShown, isTrue);
      await tester.pumpAndSettle();
      oldProfileAction();
      await tester.pump();
      expect(drafts, 0);
      expect(find.text('Later unrelated feedback'), findsOneWidget);
      expect(find.text('Gidiyorum olarak işaretlendi.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'changed event binding removes own feedback and invalidates retained controls',
    (tester) async {
      final repository = AudienceTestRepository();
      final sessions = AudienceTestSessions(audienceSession());
      var drafts = 0;
      await _pump(
        tester,
        repository,
        sessions: sessions,
        onProfileShare: (_) async => drafts++,
      );
      final oldChoice = _action(tester, 'event-audience-thinking');
      await _tap(tester, 'event-audience-going');
      final oldProfile = _snackAction(tester);
      repository.current = audienceState(eventId: audienceVenueId);
      await _pump(
        tester,
        repository,
        sessions: sessions,
        eventId: audienceVenueId,
        onProfileShare: (_) async => drafts++,
      );
      oldChoice();
      oldProfile();
      await tester.pumpAndSettle();
      expect(repository.writes.length, 1);
      expect(drafts, 0);
      expect(find.byType(SnackBar), findsNothing);
    },
  );

  testWidgets(
    'session switch closes quick popup and invalidates its captured action',
    (tester) async {
      final repository = AudienceTestRepository()
        ..current = audienceState(
          intent: EventAudienceStatus.going,
          version: 1,
        );
      final sessions = AudienceTestSessions(audienceSession());
      var drafts = 0;
      await _pump(
        tester,
        repository,
        sessions: sessions,
        onProfileShare: (_) async => drafts++,
      );
      await _tap(tester, 'event-audience-going');
      final oldProfile = _popupAction(tester, 'event-audience-quick-profile');
      sessions.replace(audienceSession(user: 'other', token: 'other'));
      oldProfile();
      await tester.pumpAndSettle();
      expect(drafts, 0);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byKey(const Key('event-audience-quick-menu')), findsNothing);
      expect(repository.writes, isEmpty);
    },
  );

  for (final unavailable in [false, true]) {
    testWidgets(
      'past/unavailable detail keeps only the selected removal button unavailable=$unavailable',
      (tester) async {
        final selected = unavailable ? 'thinking' : 'going';
        final other = unavailable ? 'going' : 'thinking';
        final repository = AudienceTestRepository()
          ..current = audienceState(
            intent: unavailable
                ? EventAudienceStatus.thinking
                : EventAudienceStatus.going,
            published: !unavailable,
            note: unavailable ? null : 'Geçmiş',
            version: 4,
            ended: !unavailable,
            available: !unavailable,
          );
        await _pump(
          tester,
          repository,
          sessions: AudienceTestSessions(
            audienceSession(
              role: unavailable ? 'ROLE_MUSICIAN' : 'ROLE_LISTENER',
            ),
          ),
        );
        _expectNoDetailStatusRow();
        expect(find.byKey(Key('event-audience-$selected')), findsOneWidget);
        expect(find.byKey(Key('event-audience-$other')), findsNothing);
        await _tap(tester, 'event-audience-$selected');
        expect(repository.writes, isEmpty);
        expect(find.byType(BottomSheet), findsNothing);
        expect(
          find.byWidgetPredicate((widget) => widget is PopupMenuItem),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('event-audience-quick-profile')),
          findsNothing,
        );
        await _tap(tester, 'event-audience-quick-clear');
        expect(repository.writes, hasLength(1));
        expect(repository.writes.single.intent, EventAudienceStatus.none);
        expect(repository.writes.single.published, isFalse);
        expect(repository.writes.single.note, isNull);
        expect(repository.writes.single.version, 4);
        expect(repository.current.intent, EventAudienceStatus.none);
        expect(find.byKey(Key('event-audience-$selected')), findsNothing);
        _expectNoDetailStatusRow();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'past/unavailable plan management retains only removal actions unavailable=$unavailable',
      (tester) async {
        final repository = AudienceTestRepository()
          ..current = audienceState(
            intent: EventAudienceStatus.going,
            published: true,
            note: 'Geçmiş',
            version: 4,
            ended: !unavailable,
            available: !unavailable,
          );
        await _pumpLauncher(
          tester,
          repository,
          AudienceTestSessions(audienceSession()),
        );
        await tester.tap(find.text('Ben de gidiyorum'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('event-audience-management-going')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('event-audience-profile-share')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('event-audience-external-share')),
          findsNothing,
        );
        await _tap(tester, 'event-audience-unpublish');
        expect(repository.current.publishedOnProfile, isFalse);
        await tester.tap(find.text('Ben de gidiyorum'));
        await tester.pumpAndSettle();
        await _tap(tester, 'event-audience-clear');
        expect(repository.current.intent, EventAudienceStatus.none);
        expect(repository.current.note, isNull);
        expect(find.byType(SnackBar), findsNothing);
      },
    );
  }

  testWidgets(
    'listener lacking server publication capability gets no profile CTA',
    (tester) async {
      final repository = AudienceTestRepository()
        ..current = audienceState(canPublish: false);
      await _pump(tester, repository);
      await _tap(tester, 'event-audience-going');
      expect(find.byType(SnackBarAction), findsNothing);
      await _tap(tester, 'event-audience-going');
      expect(
        find.byKey(const Key('event-audience-quick-profile')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'row helper reads on tap and confirms on host after sheet is fully dismissed',
    (tester) async {
      final repository = AudienceTestRepository();
      final sessions = AudienceTestSessions(audienceSession());
      var drafts = 0;
      await _pumpLauncher(
        tester,
        repository,
        sessions,
        onProfileShare: (_) async {
          expect(find.byType(BottomSheet), findsNothing);
          drafts++;
        },
      );
      expect(repository.reads, isEmpty);
      await tester.tap(find.text('Ben de gidiyorum'));
      await tester.pumpAndSettle();
      expect(repository.reads, ['listener']);
      await _tap(tester, 'event-audience-management-going');
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Gidiyorum olarak işaretlendi.'), findsOneWidget);
      await tester.tap(
        find.byKey(const Key('event-audience-snackbar-profile')),
      );
      await tester.pumpAndSettle();
      expect(drafts, 1);
      expect(repository.writes.single.published, isFalse);
    },
  );

  testWidgets(
    'row-helper confirmation session cleanup safely disposes its controller',
    (tester) async {
      final repository = AudienceTestRepository();
      final sessions = AudienceTestSessions(audienceSession());
      await _pumpLauncher(tester, repository, sessions);
      await tester.tap(find.text('Ben de gidiyorum'));
      await tester.pumpAndSettle();
      await _tap(tester, 'event-audience-management-going');
      sessions.replace(const AuthSession.guest());
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed row mutation stays recoverable and requires GET before another write',
    (tester) async {
      final repository = AudienceTestRepository()
        ..onWrite = (_) async =>
            const Result.failure(AppError(code: '9921', message: 'reload'));
      await _pumpLauncher(
        tester,
        repository,
        AudienceTestSessions(audienceSession()),
      );
      await tester.tap(find.text('Ben de gidiyorum'));
      await tester.pumpAndSettle();
      await _tap(tester, 'event-audience-management-going');
      expect(
        find.byKey(const Key('event-audience-management')),
        findsOneWidget,
      );
      expect(
        find.text('Seçimin doğrulanamadı. Güncel durumu yeniden yükle.'),
        findsOneWidget,
      );
      expect(repository.writes.length, 1);
      expect(
        tester
            .widget<GradientOutlineButton>(
              find.byKey(const Key('event-audience-management-going')),
            )
            .onPressed,
        isNull,
      );
      repository.onWrite = null;
      await tester.tap(find.text('Yeniden yükle'));
      await tester.pumpAndSettle();
      expect(repository.reads.length, 2);
      await _tap(tester, 'event-audience-management-going');
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Gidiyorum olarak işaretlendi.'), findsOneWidget);
    },
  );

  for (final profile in [true, false]) {
    testWidgets(
      'existing plan action leaves the single sheet before navigation profile=$profile',
      (tester) async {
        final repository = AudienceTestRepository()
          ..current = audienceState(
            intent: EventAudienceStatus.going,
            version: 1,
          );
        var routed = false;
        Future<void> complete() async {
          expect(find.byType(BottomSheet), findsNothing);
          routed = true;
        }

        await _pumpLauncher(
          tester,
          repository,
          AudienceTestSessions(audienceSession()),
          onProfileShare: (_) => complete(),
          onExternalShare: (_) => complete(),
        );
        await tester.tap(find.text('Ben de gidiyorum'));
        await tester.pumpAndSettle();
        expect(find.text('Seçimin: Gidiyorum'), findsOneWidget);
        await _tap(
          tester,
          profile
              ? 'event-audience-profile-share'
              : 'event-audience-external-share',
        );
        expect(routed, isTrue);
        expect(repository.writes, isEmpty);
      },
    );
  }

  testWidgets(
    '320px 200 percent text supports compact feedback and readable anchored popup',
    (tester) async {
      final repository = AudienceTestRepository();
      await _pump(tester, repository, width: 320, scale: 2);
      await _tap(tester, 'event-audience-thinking');
      expect(find.text('Düşünüyorum olarak işaretlendi.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _tap(tester, 'event-audience-thinking');
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
      expect(
        find.byKey(const Key('event-audience-quick-clear')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('event-audience-quick-profile')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.tapAt(const Offset(310, 830));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('event-audience-quick-menu')), findsNothing);
      expect(repository.writes.length, 1);
    },
  );
}
