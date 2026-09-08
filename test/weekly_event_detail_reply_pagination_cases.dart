part of 'weekly_event_detail_design_test.dart';

void _replyPaginationTests(_CommentsRepository Function() repository) {
  group('event expandable reply pagination', () {
    testWidgets('400 roots load in50s without eagerly reading reply threads', (
      tester,
    ) async {
      repository().comments.addAll([
        for (var i = 0; i < 400; i++)
          _authComment('root-$i', 'Ana yorum $i', replyCount: 15),
      ]);
      await _openDetail(tester, _event());
      expect(repository().listPages, [0]);
      expect(find.text('Ana yorum 399'), findsNothing);
      for (var page = 1; page < 8; page++) {
        await tester.scrollUntilVisible(
          find.byKey(const Key('event-comments-more')),
          550,
          maxScrolls: 60,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('event-comments-more')));
        await tester.pumpAndSettle();
        expect(repository().listPages, List.generate(page + 1, (i) => i));
        expect(repository().replyReads, isEmpty);
        // Offscreen root cards are not built just because their data was read.
        expect(
          find.textContaining('Ana yorum ').evaluate().length,
          lessThan(50),
        );
      }
      await tester.scrollUntilVisible(
        find.text('Ana yorum 399'),
        550,
        maxScrolls: 60,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Ana yorum 399'), findsOneWidget);
      expect(find.byKey(const Key('event-comments-more')), findsNothing);
      expect(repository().listSizes, List.filled(8, 50));
      expect(repository().replyReads, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      '400 replies load only20 per explicit request and can all hide',
      (tester) async {
        repository().comments.add(
          _authComment('root', 'Ana yorum', replyCount: 400),
        );
        repository().replies['root'] = [
          for (var i = 0; i < 400; i++)
            _authComment('reply-$i', 'Yanıt $i', parent: 'root'),
        ];
        await _openDetail(tester, _event());
        expect(repository().replyPages, isEmpty);
        final toggle = find.byKey(const ValueKey('event-replies-root'));
        await _tapReplyPaginationControl(tester, toggle);
        expect(repository().replyPages, [0]);
        expect(
          find.byKey(const ValueKey('event-reply-reply-20')),
          findsNothing,
        );
        final more = find.byKey(const ValueKey('event-replies-more-root'));
        for (var page = 1; page < 20; page++) {
          await _tapReplyPaginationControl(tester, more);
          expect(repository().replyPages, List.generate(page + 1, (i) => i));
        }
        expect(more, findsNothing);
        expect(
          find.byKey(const ValueKey('event-reply-reply-399')),
          findsOneWidget,
        );
        expect(repository().replySizes, List.filled(20, 20));
        await _tapReplyPaginationControl(tester, toggle);
        expect(find.byKey(const ValueKey('event-reply-reply-0')), findsNothing);
        expect(
          find.byKey(const ValueKey('event-reply-reply-399')),
          findsNothing,
        );
        expect(find.text('Yanıtları göster (400)'), findsOneWidget);
        await _tapReplyPaginationControl(tester, toggle);
        expect(repository().replyPages, List.generate(20, (i) => i));
        expect(more, findsNothing);
        expect(
          find.byKey(const ValueKey('event-reply-reply-399')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('closing a pending thread never reopens it or duplicates GET', (
      tester,
    ) async {
      repository().comments.add(
        _authComment('root', 'Ana yorum', replyCount: 1),
      );
      final pending = Completer<Result<CommentPage>>();
      repository().replyPageResponse = (_) => pending.future;
      await _openDetail(tester, _event());
      final toggle = find.byKey(const ValueKey('event-replies-root'));
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await tester.pump();
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(find.text('Yanıtları göster (1)'), findsOneWidget);
      await tester.tap(toggle);
      await tester.pump();
      expect(repository().replyPages, [0]);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      pending.complete(
        Result.success(
          CommentPage(
            items: [_authComment('reply', 'Geciken yanıt', parent: 'root')],
            totalElements: 1,
            size: 20,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Geciken yanıt'), findsNothing);
      await _tapReplyPaginationControl(tester, toggle);
      expect(find.text('Geciken yanıt'), findsOneWidget);
      expect(repository().replyPages, [0]);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'a reply sent from a closed thread stays folded with new count',
      (tester) async {
        _registerCommentMember();
        repository().comments.add(_authComment('root', 'Ana yorum'));
        await _openDetail(tester, _event());
        await _openCommentReply(tester);
        await tester.enterText(_replyField(), 'Yeni kapalı yanıt');
        await tester.testTextInput.receiveAction(TextInputAction.send);
        await tester.pumpAndSettle();
        expect(_replyField(), findsNothing);
        expect(repository().creationParents, ['root']);
        expect(repository().replyReads, isEmpty);
        expect(find.text('Yeni kapalı yanıt'), findsNothing);
        final toggle = find.byKey(const ValueKey('event-replies-root'));
        await _tapReplyPaginationControl(tester, toggle);
        expect(find.text('Yeni kapalı yanıt'), findsOneWidget);
        expect(repository().replyPages, [0]);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'next page retry survives folding without losing loaded replies',
      (tester) async {
        repository().comments.add(
          _authComment('root', 'Ana yorum', replyCount: 21),
        );
        repository().replies['root'] = [
          for (var i = 0; i < 21; i++)
            _authComment('reply-$i', 'Yanıt $i', parent: 'root'),
        ];
        await _openDetail(tester, _event());
        final toggle = find.byKey(const ValueKey('event-replies-root'));
        final more = find.byKey(const ValueKey('event-replies-more-root'));
        await _tapReplyPaginationControl(tester, toggle);
        repository().replyPageResponse = (_) async => const Result.failure(
          AppError(code: 'offline', message: 'Bağlantı yok.'),
        );
        await _tapReplyPaginationControl(tester, more);
        expect(repository().replyPages, [0, 1]);
        await _tapReplyPaginationControl(tester, toggle);
        expect(find.textContaining('Yanıtlar yüklenemedi'), findsNothing);
        await _tapReplyPaginationControl(tester, toggle);
        expect(find.text('Yanıtlar yüklenemedi · Tekrar dene'), findsOneWidget);
        expect(repository().replyPages, [0, 1]);
        repository().replyPageResponse = null;
        await _tapReplyPaginationControl(tester, more);
        expect(repository().replyPages, [0, 1, 1]);
        expect(find.text('Yanıt 0'), findsOneWidget);
        expect(find.text('Yanıt 20'), findsOneWidget);
        expect(more, findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'overlapping reply page replaces stale data and stops by offset',
      (tester) async {
        repository().comments.add(
          _authComment('root', 'Ana yorum', replyCount: 30),
        );
        repository().replyPageResponse = (page) async => Result.success(
          CommentPage(
            items: page == 0
                ? [
                    for (var i = 0; i < 20; i++)
                      _authComment('reply-$i', 'Eski yanıt $i', parent: 'root'),
                  ]
                : [
                    _authComment('reply-19', 'Güncel yanıt', parent: 'root'),
                    for (var i = 20; i < 29; i++)
                      _authComment('reply-$i', 'Son yanıt $i', parent: 'root'),
                  ],
            totalElements: 30,
            page: page,
            size: 20,
          ),
        );
        await _openDetail(tester, _event());
        await _tapReplyPaginationControl(
          tester,
          find.byKey(const ValueKey('event-replies-root')),
        );
        final more = find.byKey(const ValueKey('event-replies-more-root'));
        await _tapReplyPaginationControl(tester, more);
        expect(find.text('Güncel yanıt'), findsOneWidget);
        expect(find.text('Eski yanıt 19'), findsNothing);
        expect(
          find.byKey(const ValueKey('event-reply-reply-19')),
          findsOneWidget,
        );
        expect(repository().replyPages, [0, 1]);
        expect(more, findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'session replacement drops cached replies and retained controls',
      (tester) async {
        final sessions = _registerCommentMember();
        repository().comments.add(
          _authComment('root', 'Ana yorum', replyCount: 1),
        );
        repository().replies['root'] = [
          _authComment('reply', 'Eski görünüm', parent: 'root'),
        ];
        await _openDetail(tester, _event());
        final toggle = find.byKey(const ValueKey('event-replies-root'));
        await _tapReplyPaginationControl(tester, toggle);
        final retained = tester.widget<TextButton>(toggle).onPressed!;
        sessions.current = _detailSession(
          userId: 'other',
          token: 'other-token',
        );
        await tester.pumpAndSettle();
        retained();
        await tester.pumpAndSettle();
        expect(find.text('Eski görünüm'), findsNothing);
        expect(repository().replyPages, [0]);
        await _tapReplyPaginationControl(tester, toggle);
        expect(repository().replyPages, [0, 0]);
        expect(find.text('Eski görünüm'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}

Future<void> _tapReplyPaginationControl(
  WidgetTester tester,
  Finder finder,
) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      450,
      maxScrolls: 60,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
