part of 'weekly_event_detail_design_test.dart';

void _detailAudienceTests(_VenueRepository Function() venues) {
  group('real detail audience integration', () {
    for (final role in ['ROLE_LISTENER', 'ROLE_MUSICIAN']) {
      testWidgets(
        '$role has independent generic share and two intent choices',
        (tester) async {
          venues().includePhoto = false;
          final repository = AudienceTestRepository()
            ..current = audienceState(eventId: 'event-design-1');
          serviceLocator
            ..registerSingleton<AuthSessionManager>(
              AudienceTestSessions(audienceSession(role: role)),
            )
            ..registerSingleton<EventAudienceRepository>(repository);
          await _openDetail(tester, _event());
          expect(
            find.byKey(const Key('event-share-action-button')),
            findsOneWidget,
          );
          expect(find.byKey(const Key('event-audience-going')), findsOneWidget);
          expect(
            find.byKey(const Key('event-audience-thinking')),
            findsOneWidget,
          );
          expect(repository.reads, ['listener']);
          final choice = find.byKey(const Key('event-audience-thinking'));
          await tester.ensureVisible(choice);
          await tester.tap(choice);
          await tester.pumpAndSettle();
          expect(repository.writes.single.intent, EventAudienceStatus.thinking);
          expect(repository.writes.single.published, isFalse);
          expect(
            find.byKey(const Key('event-audience-snackbar-profile')),
            role == 'ROLE_LISTENER' ? findsOneWidget : findsNothing,
          );
          expect(find.text('Düşünüyorum olarak işaretlendi.'), findsOneWidget);
          expect(find.byType(BottomSheet), findsNothing);
          expect(
            find.byKey(const Key('event-audience-profile-note')),
            findsNothing,
          );
          await tester.tap(choice);
          await tester.pumpAndSettle();
          expect(
            find.byKey(const Key('event-audience-quick-menu')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('event-audience-quick-clear')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('event-audience-quick-profile')),
            role == 'ROLE_LISTENER' ? findsOneWidget : findsNothing,
          );
          expect(find.byType(BottomSheet), findsNothing);
          expect(repository.writes.length, 1);
          expect(tester.takeException(), isNull);
        },
      );
    }

    for (final actor in [
      const AuthSession.guest(),
      audienceSession(role: 'ROLE_VENUE'),
      audienceSession(isAdmin: true),
    ]) {
      testWidgets(
        'unsupported detail actor ${actor.roles}/${actor.isAdmin} keeps generic share only',
        (tester) async {
          venues().includePhoto = false;
          final repository = AudienceTestRepository()
            ..current = audienceState(eventId: 'event-design-1');
          serviceLocator
            ..registerSingleton<AuthSessionManager>(AudienceTestSessions(actor))
            ..registerSingleton<EventAudienceRepository>(repository);
          await _openDetail(tester, _event());
          expect(
            find.byKey(const Key('event-share-action-button')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('event-audience-controls')),
            findsNothing,
          );
          expect(
            tester
                .getSize(
                  find.byType(EventAudienceControls, skipOffstage: false),
                )
                .height,
            0,
          );
          expect(repository.reads, isEmpty);
          expect(repository.writes, isEmpty);
          expect(tester.takeException(), isNull);
        },
      );
    }

    final directory = Platform.environment['EVENT_AUDIENCE_RENDER_DIR'];
    if (directory == null) return;
    testWidgets(
      'render actual detail selection feedback and quick popup with real fonts',
      (tester) async {
        await tester.runAsync(() async {
          final fonts =
              '${File(Platform.resolvedExecutable).parent.parent.parent.path}/material_fonts';
          final font = FontLoader('Roboto');
          for (final name in [
            'roboto-regular.ttf',
            'roboto-medium.ttf',
            'roboto-bold.ttf',
            'roboto-black.ttf',
          ]) {
            font.addFont(
              File('$fonts/$name').readAsBytes().then(ByteData.sublistView),
            );
          }
          await font.load();
          await (FontLoader('MaterialIcons')
                ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
              .load();
        });
        venues().includePhoto = false;
        final repository = AudienceTestRepository()
          ..current = audienceState(eventId: 'event-design-1');
        serviceLocator
          ..registerSingleton<AuthSessionManager>(
            AudienceTestSessions(audienceSession()),
          )
          ..registerSingleton<EventAudienceRepository>(repository);
        for (final scale in [1.0, 2.0]) {
          await tester.pumpWidget(const SizedBox.shrink());
          repository.current = audienceState(eventId: 'event-design-1');
          final capture = GlobalKey();
          await _openDetail(
            tester,
            _event(title: 'Canlı müzik akşamı', artistName: 'Deniz Yılmaz'),
            size: Size(scale == 1 ? 390 : 320, 844),
            textScale: scale,
            capture: capture,
          );
          final choice = find.byKey(const Key('event-audience-thinking'));
          await tester.ensureVisible(choice);
          await _captureCommentAccess(
            tester,
            capture,
            directory,
            'detail-${scale.toInt()}x.png',
          );
          await tester.tap(choice);
          await tester.pumpAndSettle();
          await _captureCommentAccess(
            tester,
            capture,
            directory,
            'snackbar-${scale.toInt()}x.png',
          );
          await tester.tap(choice);
          await tester.pumpAndSettle();
          await _captureCommentAccess(
            tester,
            capture,
            directory,
            'quick-popup-${scale.toInt()}x.png',
          );
          await tester.tapAt(const Offset(4, 4));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      },
    );
  });
}
