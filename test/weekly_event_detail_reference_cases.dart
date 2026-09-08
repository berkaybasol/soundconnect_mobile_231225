part of 'weekly_event_detail_design_test.dart';

void _detailReferenceTests(_CommentsRepository Function() repository) {
  group('detail reference layout', () {
    testWidgets('like action appears before reply on the same row', (
      tester,
    ) async {
      _registerCommentMember();
      repository().comments.add(_authComment('root', 'Kısa yorum'));
      await _openDetail(tester, _event());
      final like = find.byKey(const ValueKey('comment-like-root'));
      await tester.scrollUntilVisible(
        like,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      final reply = find.descendant(
        of: find.byKey(const ValueKey('event-comment-card-root')),
        matching: find.widgetWithText(TextButton, 'Yanıtla'),
      );
      expect(like, findsOneWidget);
      expect(reply, findsOneWidget);
      expect(
        tester.getTopRight(like).dx,
        lessThan(tester.getTopLeft(reply).dx),
      );
      expect(tester.getCenter(like).dy, tester.getCenter(reply).dy);
      expect(tester.widget<TextButton>(like).onPressed, isNotNull);
      expect(tester.widget<TextButton>(reply).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ended empty choice shows notice without intent buttons', (
      tester,
    ) async {
      final audience = _referenceAudience(ended: true);
      await _openDetail(tester, _event(title: 'Cuma Falan'));
      expect(find.byKey(const Key('event-ended-notice')), findsOneWidget);
      expect(find.text('Bu etkinlik sona erdi.'), findsOneWidget);
      expect(
        find.text('Etkinliğe gösterdiğin ilgi için teşekkürler!'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('event-audience-going')), findsNothing);
      expect(find.byKey(const Key('event-audience-thinking')), findsNothing);
      expect(audience.reads, ['commenter']);
      expect(audience.writes, isEmpty);
      expect(repository().listCalls, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('active event keeps both choices and has no ended notice', (
      tester,
    ) async {
      final audience = _referenceAudience();
      await _openDetail(tester, _event());
      expect(find.byKey(const Key('event-audience-going')), findsOneWidget);
      expect(find.byKey(const Key('event-audience-thinking')), findsOneWidget);
      expect(find.byKey(const Key('event-ended-notice')), findsNothing);
      expect(audience.writes, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ended existing choice retains its single removal action', (
      tester,
    ) async {
      final audience = _referenceAudience(
        ended: true,
        intent: EventAudienceStatus.going,
      );
      await _openDetail(tester, _event());
      final selected = find.byKey(const Key('event-audience-going'));
      expect(selected, findsOneWidget);
      expect(find.byKey(const Key('event-audience-thinking')), findsNothing);
      expect(find.byKey(const Key('event-ended-notice')), findsOneWidget);
      await tester.ensureVisible(selected);
      await tester.tap(selected);
      await tester.pumpAndSettle();
      expect(audience.writes, isEmpty);
      expect(
        find.byKey(const Key('event-audience-quick-clear')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('event-audience-quick-profile')),
        findsNothing,
      );
      await tester.tap(find.byKey(const Key('event-audience-quick-clear')));
      await tester.pumpAndSettle();
      expect(audience.writes, hasLength(1));
      expect(audience.writes.single.intent, EventAudienceStatus.none);
      expect(selected, findsNothing);
      expect(find.byKey(const Key('event-ended-notice')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('unavailable event retains fallback instead of ended banner', (
      tester,
    ) async {
      _referenceAudience(available: false);
      await _openDetail(tester, _event());
      expect(find.text('Etkinlik şu anda kullanılamıyor.'), findsOneWidget);
      expect(find.byKey(const Key('event-ended-notice')), findsNothing);
      expect(find.byKey(const Key('event-audience-going')), findsNothing);
      expect(find.byKey(const Key('event-audience-thinking')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'guest retains comment entry prompt without audience requests',
      (tester) async {
        final audience = AudienceTestRepository()
          ..current = audienceState(eventId: 'event-design-1', ended: true);
        serviceLocator.registerSingleton<EventAudienceRepository>(audience);
        await _openDetail(tester, _event());
        expect(find.text(_commentGateCopy), findsOneWidget);
        expect(find.byKey(const Key('event-comment-login')), findsOneWidget);
        expect(find.byKey(const Key('event-comment-register')), findsOneWidget);
        expect(_commentField(), findsNothing);
        expect(find.byKey(const Key('event-ended-notice')), findsNothing);
        expect(audience.reads, isEmpty);
        expect(repository().listCalls, 1);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'comment badge uses backend root total without counting replies',
      (tester) async {
        _referenceAudience(ended: true);
        final root = _authComment('root', 'Ana yorum', replyCount: 1);
        repository().listResponse = () async => Result.success(
          CommentPage(items: [root], totalElements: 51, size: 50),
        );
        repository().replies['root'] = [
          _authComment('reply', 'Tek yanıt', parent: 'root'),
        ];
        await _openDetail(tester, _event());
        final badge = find.byKey(const Key('event-comment-count'));
        await tester.ensureVisible(badge);
        expect(badge, findsOneWidget);
        expect(find.text('51'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('event-comment-root')),
          findsOneWidget,
        );
        expect(repository().listPages, [0]);
        expect(repository().replyReads, isEmpty);

        final replies = find.byKey(const ValueKey('event-replies-root'));
        await tester.ensureVisible(replies);
        await tester.pumpAndSettle();
        await tester.ensureVisible(replies);
        await tester.pumpAndSettle();
        await tester.tap(replies);
        await tester.pumpAndSettle();
        expect(find.text('Tek yanıt'), findsOneWidget);
        expect(find.text('51'), findsOneWidget);
        expect(repository().listPages, [0]);
        expect(repository().replyReads, [('root', 'event-design-1')]);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('initial unknown comment count is not presented as zero', (
      tester,
    ) async {
      _referenceAudience(ended: true);
      final pending = Completer<Result<CommentPage>>();
      repository().listResponse = () => pending.future;
      await _openDetail(tester, _event(), settle: false);
      expect(find.byKey(const Key('event-comment-count')), findsOneWidget);
      expect(find.text('…'), findsOneWidget);
      expect(find.text('0'), findsNothing);
      expect(repository().listCalls, 1);
      pending.complete(
        const Result.success(CommentPage(items: [], totalElements: 0)),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('event-comment-count')), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      expect(repository().listCalls, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('banner heading and composer fit 320px at 200 percent text', (
      tester,
    ) async {
      _referenceAudience(ended: true);
      repository().comments.add(
        _compactQualityComment('root', 'a', DateTime.now().toUtc()),
      );
      repository().listResponse = () async => Result.success(
        CommentPage(
          items: List.of(repository().comments),
          totalElements: 1234567,
          size: 50,
        ),
      );
      await _openDetail(
        tester,
        _event(title: 'Cuma Falan'),
        size: const Size(320, 844),
        textScale: 2,
      );
      // The enlarged hero initially keeps the lazy comments header outside the
      // viewport. Scroll to materialize it before measuring the new chrome.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pumpAndSettle();
      for (final key in [
        'event-ended-notice',
        'event-comments-heading-accent',
        'event-comment-count',
        'event-comment-input-frame',
        'event-comment-composer-surface',
      ]) {
        final finder = find.byKey(Key(key));
        expect(finder, findsOneWidget);
        final rect = tester.getRect(finder);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(320));
      }
      final semantics = tester.ensureSemantics();
      await tester.pump();
      try {
        expect(
          find.bySemanticsLabel('1234567 yorum, yanıtlar hariç'),
          findsOneWidget,
        );
      } finally {
        semantics.dispose();
      }
      final sendFinder = find.byKey(const Key('event-comment-send'));
      final send = tester.widget<Material>(sendFinder);
      expect(tester.getSize(sendFinder), const Size(46, 46));
      expect(
        send.color,
        Theme.of(
          tester.element(sendFinder),
        ).colorScheme.surfaceContainerHighest,
      );
      expect(
        find.descendant(
          of: sendFinder,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is DecoratedBox &&
                widget.decoration is BoxDecoration &&
                (widget.decoration as BoxDecoration).gradient != null,
          ),
        ),
        findsNothing,
      );
      await tester.ensureVisible(find.byKey(const Key('event-ended-notice')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('event-comment-root')),
        160,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(repository().listPages, [0]);
      expect(repository().listCalls, 1);
      expect(repository().replyReads, isEmpty);
      expect(tester.takeException(), isNull);
    });

    final directory = Platform.environment['EVENT_REFERENCE_RENDER_DIR'];
    if (directory == null || directory.isEmpty) return;
    testWidgets('render ended detail reference with real fonts', (
      tester,
    ) async {
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
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      });
      _referenceAudience(ended: true);
      repository().comments.add(
        _compactQualityComment('root', 'a', DateTime.now().toUtc()),
      );
      for (final scale in [1.0, 2.0]) {
        await tester.pumpWidget(const SizedBox.shrink());
        final capture = GlobalKey();
        await _openDetail(
          tester,
          _event(title: 'Cuma Falan'),
          size: Size(scale == 1 ? 390 : 320, 844),
          textScale: scale,
          capture: capture,
        );
        await Scrollable.ensureVisible(
          tester.element(find.byKey(const Key('event-share-action-button'))),
          alignment: 0,
        );
        await _captureCommentAccess(
          tester,
          capture,
          directory,
          'event-reference-${scale.toInt()}x.png',
        );
        expect(tester.takeException(), isNull);
      }
      expect(repository().creations, isEmpty);
    });
  });
}

AudienceTestRepository _referenceAudience({
  bool ended = false,
  bool available = true,
  EventAudienceStatus intent = EventAudienceStatus.none,
}) {
  _registerCommentMember();
  final repository = AudienceTestRepository()
    ..current = audienceState(
      eventId: 'event-design-1',
      intent: intent,
      version: intent == EventAudienceStatus.none ? 0 : 1,
      ended: ended,
      available: available,
    );
  serviceLocator.registerSingleton<EventAudienceRepository>(repository);
  return repository;
}
