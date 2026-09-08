part of 'weekly_event_detail_design_test.dart';

void _commentQualityTests(_CommentsRepository Function() repository) {
  testWidgets(
    'reference event comment card groups author age body and outlined delete',
    (tester) async {
      _registerCommentMember();
      repository().comments.addAll([
        _compactQualityComment('short', 'a', DateTime.now().toUtc()),
        _compactQualityComment(
          'older',
          'deney',
          DateTime.now().toUtc().subtract(const Duration(hours: 7)),
        ),
      ]);
      await _openDetail(tester, _event(title: 'Cuma Falan'));
      final short = find.byKey(const ValueKey('event-comment-short'));
      await tester.ensureVisible(short);
      await tester.pumpAndSettle();
      final card = find.byKey(const ValueKey('event-comment-card-short'));
      expect(tester.getSize(card).height, inInclusiveRange(130, 150));
      final decoration =
          tester.widget<Container>(card).decoration! as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(16));
      expect(decoration.gradient, isA<LinearGradient>());
      final name = find.descendant(of: short, matching: find.text('@berna'));
      final body = find.descendant(of: short, matching: find.text('a'));
      expect(tester.getTopLeft(body).dx, lessThan(tester.getTopLeft(name).dx));
      expect(
        tester.getTopLeft(body).dy,
        greaterThan(tester.getBottomLeft(name).dy),
      );
      expect(
        find.descendant(of: short, matching: find.text('Az önce')),
        findsOneWidget,
      );
      final delete = find.byKey(const ValueKey('event-comment-delete-short'));
      expect(tester.getSize(delete).height, greaterThanOrEqualTo(44));
      expect(tester.widget<IconButton>(delete).tooltip, 'Yorumu sil');
      expect(
        find.descendant(
          of: card,
          matching: find.byIcon(Icons.delete_outline_rounded),
        ),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(delete).dy,
        lessThan(tester.getTopLeft(body).dy),
      );
      final reply = find.descendant(
        of: card,
        matching: find.widgetWithText(TextButton, 'Yanıtla'),
      );
      expect(tester.getSize(reply).height, greaterThanOrEqualTo(44));
      expect(
        tester.getTopLeft(reply).dy,
        greaterThan(tester.getBottomLeft(body).dy),
      );
      final older = find.byKey(const ValueKey('event-comment-older'));
      await tester.ensureVisible(older);
      await tester.pumpAndSettle();
      expect(
        tester
            .getSize(find.byKey(const ValueKey('event-comment-card-older')))
            .height,
        inInclusiveRange(130, 150),
      );
      expect(find.text('7 saat önce'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final anonymous in [false, true]) {
    testWidgets(
      'reference event comment card fits 320dp 2x long ${anonymous ? 'anonymous' : 'named'} content and replies',
      (tester) async {
        _registerCommentMember();
        final body = List.filled(20, 'Uzun yorum metni 🎵 ').join();
        repository().comments.add(
          CommentItem(
            id: 'long',
            user: CommentUserSummary(
              id: anonymous ? '' : 'commenter',
              username: 'CokUzunBirKullaniciAdiHerKosuldaTasmamali',
              avatarUrl: null,
            ),
            anonymousAuthor: anonymous,
            text: body,
            deleted: false,
            parentCommentId: null,
            replyCount: 1,
            createdAt: DateTime.now().toUtc(),
          ),
        );
        repository().replies['long'] = [
          _authComment(
            'nested',
            'Birinci satır\nİkinci satır\nÜçüncü satır',
            parent: 'long',
          ),
        ];
        await _openDetail(
          tester,
          _event(),
          size: const Size(320, 844),
          textScale: 2,
        );
        final more = find.byKey(const ValueKey('event-replies-long'));
        await tester.scrollUntilVisible(
          more,
          400,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(more);
        await tester.pumpAndSettle();
        expect(repository().replyPages, [0]);
        final nested = find.byKey(const ValueKey('event-reply-nested'));
        await tester.ensureVisible(nested);
        await tester.pumpAndSettle();
        expect(find.text(body), findsOneWidget);
        expect(
          find.text('Birinci satır\nİkinci satır\nÜçüncü satır'),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('event-comment-delete-long')),
          anonymous ? findsNothing : findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'reference event deleted card hides author identity and write actions',
    (tester) async {
      _registerCommentMember();
      repository().comments.add(
        const CommentItem(
          id: 'deleted',
          user: CommentUserSummary(
            id: 'commenter',
            username: 'hidden-author',
            avatarUrl: 'https://example.test/hidden.png',
          ),
          text: 'Gizlenmesi gereken içerik',
          deleted: true,
          parentCommentId: null,
          replyCount: 0,
          createdAt: null,
        ),
      );
      await _openDetail(tester, _event());
      final card = find.byKey(const ValueKey('event-comment-card-deleted'));
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      expect(find.text('Bu yorum silindi.'), findsOneWidget);
      expect(find.textContaining('hidden-author'), findsNothing);
      expect(find.text('Gizlenmesi gereken içerik'), findsNothing);
      expect(
        find.descendant(of: card, matching: find.byType(AppCachedNetworkImage)),
        findsNothing,
      );
      expect(
        find.descendant(of: card, matching: find.text('Yanıtla')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('event-comment-delete-deleted')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final error in const [
    AppError(
      code: '9356',
      message:
          'Bu içerikte art arda birkaç yorum gönderdin. 12 saniye bekleyip tekrar deneyebilirsin.',
      retryAfter: Duration(seconds: 12),
    ),
    AppError(
      code: '9357',
      message:
          'Yorum şu anda gönderilemiyor. Biraz sonra tekrar deneyebilirsin.',
      retryAfter: Duration(seconds: 5),
    ),
  ]) {
    for (final reply in [false, true]) {
      testWidgets(
        'comment anti-spam event ${reply ? 'reply' : 'root'} ${error.code} preserves draft without automatic retry',
        (tester) async {
          _registerCommentMember();
          repository().comments.add(_authComment('root', 'Ana yorum'));
          final failed = Completer<Result<CommentItem>>();
          repository().creationCompletion = failed;
          await _openDetail(tester, _event());
          if (reply) await _openCommentReply(tester);
          final field = reply ? _replyField() : _commentField();
          const draft = 'Bu yorum kaybolmasın 🎵';
          await tester.enterText(field, draft);
          await tester.testTextInput.receiveAction(TextInputAction.send);
          await tester.pump();
          expect(repository().creations, hasLength(1));
          final reads = repository().listCalls;
          failed.complete(Result.failure(error));
          await tester.pumpAndSettle();
          expect(tester.widget<TextField>(field).controller!.text, draft);
          expect(find.text(error.message), findsWidgets);
          expect(find.textContaining('Sonuç doğrulanamadı'), findsNothing);
          expect(find.textContaining('Gönderilmiş olabilir'), findsNothing);
          expect(repository().listCalls, reads);
          await tester.pump(const Duration(seconds: 31));
          await tester.pumpAndSettle();
          expect(repository().creations, hasLength(1));
          expect(tester.widget<TextField>(field).controller!.text, draft);

          repository().creationCompletion = null;
          final explicitRetry = tester.widget<TextField>(field).onSubmitted!;
          explicitRetry(draft);
          explicitRetry(
            draft,
          ); // A second queued gesture must not duplicate the retry.
          await tester.pumpAndSettle();
          expect(repository().creations, hasLength(2));
          expect(repository().creationParents, [
            reply ? 'root' : null,
            reply ? 'root' : null,
          ]);
          expect(find.text(error.message), findsNothing);
          if (reply) {
            expect(_replyField(), findsNothing);
            expect(repository().replies['root']!.single.text, draft);
          } else {
            expect(
              tester.widget<TextField>(_commentField()).controller!.text,
              '',
            );
            expect(repository().comments.last.text, draft);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'comment anti-spam event reply cannot replay after account replacement',
    (tester) async {
      final sessions = _registerCommentMember();
      repository().comments.add(_authComment('root', 'Ana yorum'));
      repository().creationCompletion = Completer<Result<CommentItem>>();
      await _openDetail(tester, _event());
      await _openCommentReply(tester);
      await tester.enterText(_replyField(), 'Eski hesabın yanıtı');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump();
      repository().creationCompletion!.complete(
        const Result.failure(
          AppError(
            code: '9356',
            message: 'Biraz bekleyip tekrar deneyebilirsin.',
            retryAfter: Duration(seconds: 12),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final retry = tester.widget<TextField>(_replyField()).onSubmitted!;
      sessions.current = _detailSession(
        userId: 'new-viewer',
        token: 'new-token',
      );
      await tester.pumpAndSettle();
      retry('Eski hesabın yanıtı');
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(repository().creations, hasLength(1));
      expect(_replyField(), findsNothing);
      expect(find.text('Eski hesabın yanıtı'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'comment audit successful reply replaces a pending pre-write reply page',
    (tester) async {
      _registerCommentMember();
      repository().comments.add(
        _authComment('root', 'Ana yorum', replyCount: 1),
      );
      final stale = Completer<Result<CommentPage>>();
      var first = true;
      repository().replyPageResponse = (page) {
        if (first) {
          first = false;
          return stale.future;
        }
        final rows = repository().replies['root'] ?? const <CommentItem>[];
        return Future.value(
          Result.success(
            CommentPage(
              items: rows,
              totalElements: rows.length,
              page: page,
              size: 20,
            ),
          ),
        );
      };
      await _openDetail(tester, _event());
      await tester.ensureVisible(
        find.byKey(const ValueKey('event-replies-root')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('event-replies-root')));
      await tester.pump();
      await tester.tap(_replyAction());
      await tester.pump(const Duration(milliseconds: 350));
      await tester.enterText(_replyField(), 'Yeni yanıt');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();
      expect(repository().creations, hasLength(1));
      expect(repository().replyReads, hasLength(2));
      expect(find.text('Yeni yanıt'), findsOneWidget);
      stale.complete(
        Result.success(
          CommentPage(
            items: [_authComment('old', 'Eski yanıt', parent: 'root')],
            totalElements: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Yeni yanıt'), findsOneWidget);
      expect(find.text('Eski yanıt'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'comment audit own delete requires confirmation and masks deleted text',
    (tester) async {
      _registerCommentMember();
      repository().comments.add(_ownQualityComment());
      await _openDetail(tester, _event());
      final delete = find.byKey(const ValueKey('event-comment-delete-own'));
      await tester.ensureVisible(delete);
      await tester.tap(delete);
      await tester.pumpAndSettle();
      expect(repository().deletions, isEmpty);
      await tester.tap(find.widgetWithText(GradientOutlineButton, 'Sil'));
      await tester.pumpAndSettle();
      expect(repository().deletions, ['own']);
      expect(find.text('Kendi yorumum'), findsNothing);
      expect(find.text('Bu yorum silindi.'), findsOneWidget);
      expect(delete, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'comment audit resume invalidates delete dialog without stale removal',
    (tester) async {
      _registerCommentMember();
      repository().comments.add(_ownQualityComment());
      await _openDetail(tester, _event());
      await tester.ensureVisible(
        find.byKey(const ValueKey('event-comment-delete-own')),
      );
      await tester.tap(find.byKey(const ValueKey('event-comment-delete-own')));
      await tester.pumpAndSettle();
      final delete = tester
          .widget<GradientOutlineButton>(
            find.widgetWithText(GradientOutlineButton, 'Sil'),
          )
          .onPressed!;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Yorumunu silmek istiyor musun?'), findsNothing);
      delete();
      await tester.pumpAndSettle();
      expect(repository().deletions, isEmpty);
      expect(find.byType(WeeklyEventDetailScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('comment audit does not eagerly request every reply thread', (
    tester,
  ) async {
    for (var index = 0; index < 4; index++) {
      repository().comments.add(
        _authComment('root-$index', 'Yorum $index', replyCount: 3),
      );
    }
    await _openDetail(tester, _event());
    expect(repository().replyReads, isEmpty);
  });

  testWidgets('comment audit failed reply preserves editor and authored text', (
    tester,
  ) async {
    _registerCommentMember();
    repository().comments.add(_authComment('root', 'Ana yorum'));
    repository().creationCompletion = Completer<Result<CommentItem>>();
    await _openDetail(tester, _event());
    await _openCommentReply(tester);
    await tester.enterText(_replyField(), 'Yanıtım kaybolmasın 🎵');
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('event-reply-submit')));
    await tester.tap(find.byKey(const Key('event-reply-submit')));
    await tester.pump();
    expect(repository().creations, hasLength(1));
    repository().creationCompletion!.complete(
      const Result.failure(
        AppError(code: 'offline', message: 'Bağlantı kurulamadı.'),
      ),
    );
    await tester.pumpAndSettle();
    expect(_replyField(), findsOneWidget);
    expect(
      tester.widget<TextField>(_replyField()).controller!.text,
      'Yanıtım kaybolmasın 🎵',
    );
    expect(find.textContaining('Bağlantı kurulamadı'), findsWidgets);
  });

  testWidgets(
    'comment audit root pagination makes comments after the first50 reachable',
    (tester) async {
      for (var index = 0; index < 51; index++) {
        repository().comments.add(
          _authComment('row-$index', 'Yorum numarası $index'),
        );
      }
      await _openDetail(tester, _event());
      expect(repository().listPages, [0]);
      await tester.scrollUntilVisible(
        find.byKey(const Key('event-comments-more')),
        450,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('event-comments-more')));
      await tester.pumpAndSettle();
      expect(repository().listPages, [0, 1]);
      expect(find.text('Yorum numarası 50'), findsOneWidget);
      expect(find.byKey(const Key('event-comments-more')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('comment audit lazy replies support retry and the next page', (
    tester,
  ) async {
    repository().comments.add(
      _authComment('root', 'Ana yorum', replyCount: 21),
    );
    repository().replies['root'] = [
      for (var index = 0; index < 21; index++)
        _authComment('reply-$index', 'Yanıt numarası $index', parent: 'root'),
    ];
    repository().replyPageResponse = (_) async => const Result.failure(
      AppError(code: 'offline', message: 'Bağlantı yok.'),
    );
    await _openDetail(tester, _event());
    final more = find.byKey(const ValueKey('event-replies-root'));
    await tester.ensureVisible(more);
    await tester.pumpAndSettle();
    await tester.tap(more);
    await tester.pumpAndSettle();
    expect(find.text('Yanıtlar yüklenemedi · Tekrar dene'), findsOneWidget);
    repository().replyPageResponse = null;
    final next = find.byKey(const ValueKey('event-replies-more-root'));
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(repository().replyPages, [0, 0]);
    expect(find.text('Daha fazla yanıt'), findsOneWidget);
    await tester.ensureVisible(next);
    await tester.pumpAndSettle();
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(repository().replyPages, [0, 0, 1]);
    expect(find.text('Yanıt numarası 20'), findsOneWidget);
    expect(next, findsNothing);
    expect(more, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'comment audit silent account replacement invalidates retained reply sender',
    (tester) async {
      final manager = _registerCommentMember();
      repository().comments.add(_authComment('root', 'Ana yorum'));
      await _openDetail(tester, _event());
      await _openCommentReply(tester);
      await tester.enterText(_replyField(), 'Gönderilmeyecek');
      final callback = tester.widget<TextField>(_replyField()).onSubmitted!;
      manager.setWithoutNotification(
        _detailSession(userId: 'other', token: 'other-token'),
      );
      callback('Gönderilmeyecek');
      await tester.pump();
      expect(repository().creations, isEmpty);
    },
  );

  testWidgets(
    'comment audit account change before reply first frame removes only old sheet',
    (tester) async {
      final manager = _registerCommentMember();
      repository().comments.add(_authComment('root', 'Ana yorum'));
      await _openDetail(tester, _event());
      await tester.ensureVisible(_replyAction());
      await tester.tap(_replyAction());
      manager.current = const AuthSession.guest();
      await tester.pumpAndSettle();
      expect(_replyField(), findsNothing);
      expect(find.byType(WeeklyEventDetailScreen), findsOneWidget);
      expect(find.text(_commentGateCopy), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

CommentItem _ownQualityComment() => CommentItem(
  id: 'own',
  user: const CommentUserSummary(
    id: 'commenter',
    username: 'dinleyici',
    avatarUrl: null,
  ),
  text: 'Kendi yorumum',
  deleted: false,
  parentCommentId: null,
  replyCount: 0,
  createdAt: DateTime(2026, 9, 8, 20),
);

CommentItem _compactQualityComment(
  String id,
  String text,
  DateTime createdAt,
) => CommentItem(
  id: id,
  user: const CommentUserSummary(
    id: 'commenter',
    username: 'berna',
    avatarUrl: null,
  ),
  text: text,
  deleted: false,
  parentCommentId: null,
  replyCount: 0,
  createdAt: createdAt,
);
