part of 'weekly_event_detail_design_test.dart';

const _commentGateCopy = 'Yorum yapmak için giriş yap veya üye ol.';

void _commentAuthenticationTests(_CommentsRepository Function() repository) {
  group('event comment authentication', () {
    for (final registered in [false, true]) {
      testWidgets(
        'guest gate is shown with session manager registered=$registered',
        (tester) async {
          if (registered) {
            serviceLocator.registerSingleton<AuthSessionManager>(
              _DetailSessionManager(const AuthSession.guest()),
            );
          }
          await _openDetail(tester, _event());
          expect(find.text(_commentGateCopy), findsOneWidget);
          expect(find.byKey(const Key('event-comment-login')), findsOneWidget);
          expect(
            find.byKey(const Key('event-comment-register')),
            findsOneWidget,
          );
          expect(find.byType(TextField), findsNothing);
          expect(find.text('Henüz yorum yok.'), findsOneWidget);
          expect(
            find.text('Henüz yorum yok. İlk yorumu sen yaz.'),
            findsNothing,
          );
          expect(_replyAction(), findsNothing);
          expect(repository().listCalls, 1);
          expect(repository().creations, isEmpty);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'guest can read existing comments and event-scoped replies without reply actions',
      (tester) async {
        repository().comments.add(
          _authComment('root', 'Herkesin okuyabildiği yorum', replyCount: 1),
        );
        repository().replies['root'] = [
          _authComment('reply', 'Herkesin okuyabildiği yanıt', parent: 'root'),
        ];
        await _openDetail(tester, _event());
        await tester.ensureVisible(find.text('Herkesin okuyabildiği yanıt'));
        await tester.pumpAndSettle();
        expect(find.text('Herkesin okuyabildiği yorum'), findsOneWidget);
        expect(find.text('Herkesin okuyabildiği yanıt'), findsOneWidget);
        expect(repository().replyReads, [('root', 'event-design-1')]);
        expect(_replyAction(), findsNothing);
        expect(find.byType(TextField), findsNothing);
        expect(repository().creations, isEmpty);
      },
    );

    for (final target in [
      ('event-comment-login', AppRoutes.login),
      ('event-comment-register', AppRoutes.register),
    ]) {
      testWidgets(
        '${target.$1} navigates once and is usable again after returning',
        (tester) async {
          final routes = <RouteSettings>[];
          await _openDetail(tester, _event(), onRoute: routes.add);
          final action = find.byKey(Key(target.$1));
          final callback = target.$1 == 'event-comment-login'
              ? tester.widget<OutlinedButton>(action).onPressed!
              : tester.widget<GradientOutlineButton>(action).onPressed!;
          callback();
          callback();
          await tester.pumpAndSettle();
          if (target.$1 == 'event-comment-register') {
            expect(
              find.byKey(const Key('registration-options-sheet')),
              findsOneWidget,
            );
            expect(routes, isEmpty);
            await tester.tap(
              find.byKey(const Key('registration-email-continue')),
            );
            await tester.pumpAndSettle();
          }
          expect(routes.map((route) => route.name), [target.$2]);
          expect(repository().creations, isEmpty);
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(find.text(_commentGateCopy), findsOneWidget);
          await tester.tap(action);
          await tester.pumpAndSettle();
          if (target.$1 == 'event-comment-register') {
            await tester.tap(
              find.byKey(const Key('registration-email-continue')),
            );
            await tester.pumpAndSettle();
          }
          expect(routes.map((route) => route.name), [target.$2, target.$2]);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('member retains composer and reply action with no guest gate', (
      tester,
    ) async {
      _registerCommentMember();
      repository().comments.add(_authComment('root', 'Katılımcı yorumu'));
      await _openDetail(tester, _event());
      expect(find.byKey(const Key('event-comment-input')), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text(_commentGateCopy), findsNothing);
      expect(_replyAction(), findsOneWidget);
    });

    testWidgets(
      'session changes update gate clear drafts and unsubscribe on dispose',
      (tester) async {
        final manager = _DetailSessionManager(const AuthSession.guest());
        serviceLocator.registerSingleton<AuthSessionManager>(manager);
        await _openDetail(tester, _event());
        expect(manager.hasSessionListeners, isTrue);
        expect(find.byType(TextField), findsNothing);
        manager.current = _detailSession(userId: 'first');
        await tester.pumpAndSettle();
        await tester.enterText(_commentField(), 'İlk hesabın taslağı');
        manager.current = _detailSession(
          userId: 'second',
          token: 'second-token',
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(_commentField()).controller!.text,
          isEmpty,
        );
        await tester.enterText(_commentField(), 'İkinci hesabın taslağı');
        manager.current = const AuthSession.guest();
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsNothing);
        expect(find.text(_commentGateCopy), findsOneWidget);
        manager.current = _detailSession(userId: 'third', token: 'third-token');
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(_commentField()).controller!.text,
          isEmpty,
        );
        expect(repository().creations, isEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
        expect(manager.hasSessionListeners, isFalse);
        manager.current = const AuthSession.guest();
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'dispatch rechecks authentication even before a session notification rebuilds UI',
      (tester) async {
        final manager = _registerCommentMember();
        await _openDetail(tester, _event());
        await tester.enterText(_commentField(), 'Gönderilmemeli');
        final submit = tester.widget<TextField>(_commentField()).onSubmitted!;
        manager.setWithoutNotification(const AuthSession.guest());
        submit('Gönderilmemeli');
        await tester.pump();
        expect(repository().creations, isEmpty);
        manager.notifyListeners();
        await tester.pumpAndSettle();
        expect(find.text(_commentGateCopy), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'identity change hides old comment content while the public reload is pending',
      (tester) async {
        final manager = _registerCommentMember();
        repository().comments.add(
          _authComment('old', 'Önceki oturuma ait yorum görünümü'),
        );
        await _openDetail(tester, _event());
        await tester.ensureVisible(
          find.text('Önceki oturuma ait yorum görünümü'),
        );
        final pending = Completer<Result<CommentPage>>();
        repository().listResponse = () => pending.future;
        manager.current = const AuthSession.guest();
        await tester.pump();
        expect(find.text('Önceki oturuma ait yorum görünümü'), findsNothing);
        expect(find.text(_commentGateCopy), findsOneWidget);
        expect(repository().listCalls, 2);
        pending.complete(
          Result.success(
            CommentPage(
              items: [_authComment('public', 'Güncel herkese açık yorum')],
              totalElements: 1,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Güncel herkese açık yorum'), findsOneWidget);
        expect(find.byType(TextField), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'captured reply action targets the same comment after a list reorder',
      (tester) async {
        _registerCommentMember();
        final first = _authComment('first', 'İlk yorum');
        final second = _authComment('second', 'İkinci yorum');
        repository().comments.addAll([first, second]);
        await _openDetail(tester, _event());
        final tile = find.ancestor(
          of: find.text('İlk yorum'),
          matching: find.byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == '_CommentTile',
          ),
        );
        final action = tester
            .widget<InkWell>(
              find
                  .ancestor(
                    of: find.descendant(of: tile, matching: _replyAction()),
                    matching: find.byType(InkWell),
                  )
                  .first,
            )
            .onTap!;
        repository().comments
          ..clear()
          ..addAll([second, first]);
        final consumer = tester
            .widget<BlocConsumer<CommentThreadCubit, CommentThreadState>>(
              find.byWidgetPredicate(
                (widget) =>
                    widget
                        is BlocConsumer<CommentThreadCubit, CommentThreadState>,
              ),
            );
        await consumer.bloc!.load(
          targetType: 'EVENT',
          targetId: 'event-design-1',
        );
        await tester.pumpAndSettle();
        action();
        await tester.pumpAndSettle();
        await tester.enterText(_replyField(), 'İlk yoruma yanıt');
        await tester.testTextInput.receiveAction(TextInputAction.send);
        await tester.pumpAndSettle();
        expect(repository().creationParents, ['first']);
        expect(repository().creations.single.$3, 'İlk yoruma yanıt');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'a completed old-account submission cannot clear a new-account draft',
      (tester) async {
        final manager = _registerCommentMember();
        repository().creationCompletion = Completer<Result<CommentItem>>();
        await _openDetail(tester, _event());
        await tester.enterText(_commentField(), 'Eski gönderim');
        tester.widget<TextField>(_commentField()).onSubmitted!('Eski gönderim');
        await tester.pump();
        expect(repository().creations, hasLength(1));
        manager.current = _detailSession(
          userId: 'second',
          token: 'second-token',
        );
        await tester.pump();
        await tester.enterText(_commentField(), 'Yeni hesabın taslağı');
        repository().creationCompletion!.complete(
          Result.success(_authComment('created', 'Eski gönderim')),
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(_commentField()).controller!.text,
          'Yeni hesabın taslağı',
        );
        expect(tester.takeException(), isNull);
      },
    );

    for (final dismiss in ['back', 'barrier']) {
      testWidgets('reply draft is not posted on $dismiss dismissal', (
        tester,
      ) async {
        _registerCommentMember();
        repository().comments.add(_authComment('root', 'Ana yorum'));
        await _openDetail(tester, _event());
        await _openCommentReply(tester);
        await tester.enterText(_replyField(), 'İptal edilen taslak');
        if (dismiss == 'back') {
          await tester.binding.handlePopRoute();
        } else {
          await tester.tapAt(const Offset(10, 10));
        }
        await tester.pumpAndSettle();
        expect(_replyField(), findsNothing);
        expect(repository().creations, isEmpty);
        expect(tester.takeException(), isNull);
      });
    }

    for (final explicitAction in ['button', 'keyboard']) {
      testWidgets(
        'reply posts one trimmed event-scoped reply only via $explicitAction',
        (tester) async {
          _registerCommentMember();
          repository().comments.add(_authComment('root', 'Ana yorum'));
          await _openDetail(tester, _event());
          await _openCommentReply(tester);
          await tester.enterText(_replyField(), '  Onaylanan yanıt  ');
          await tester.pump();
          if (explicitAction == 'button') {
            await tester.tap(find.byKey(const Key('event-reply-submit')));
          } else {
            await tester.testTextInput.receiveAction(TextInputAction.send);
          }
          await tester.pumpAndSettle();
          expect(repository().creations, [
            ('EVENT', 'event-design-1', 'Onaylanan yanıt'),
          ]);
          expect(repository().creationParents, ['root']);
          expect(_replyField(), findsNothing);
          expect(find.byType(WeeklyEventDetailScreen), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'logout dismisses an open reply editor and rejects its stale submission callback',
      (tester) async {
        final manager = _registerCommentMember();
        repository().comments.add(_authComment('root', 'Ana yorum'));
        await _openDetail(tester, _event());
        await _openCommentReply(tester);
        await tester.enterText(_replyField(), 'Eski hesabın yanıtı');
        final submit = tester.widget<TextField>(_replyField()).onSubmitted!;
        manager.current = const AuthSession.guest();
        await tester.pumpAndSettle();
        expect(_replyField(), findsNothing);
        expect(find.text(_commentGateCopy), findsOneWidget);
        submit('Eski hesabın yanıtı');
        await tester.pumpAndSettle();
        expect(repository().creations, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('guest comment gate fits at 320px with 200 percent text', (
      tester,
    ) async {
      await _openDetail(
        tester,
        _event(),
        size: const Size(320, 720),
        textScale: 2,
      );
      expect(find.text(_commentGateCopy), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      for (final key in ['event-comment-login', 'event-comment-register']) {
        final rect = tester.getRect(find.byKey(Key(key)));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(320));
        expect(rect.bottom, lessThanOrEqualTo(720));
        expect(rect.height, greaterThanOrEqualTo(44));
      }
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}

_DetailSessionManager _registerCommentMember() {
  final manager = _DetailSessionManager(
    _detailSession(userId: 'commenter', roles: const ['ROLE_LISTENER']),
  );
  serviceLocator.registerSingleton<AuthSessionManager>(manager);
  return manager;
}

Finder _commentField() => find.byKey(const Key('event-comment-input'));
Finder _replyField() => find.byKey(const Key('event-reply-input'));
Finder _replyAction() => find.textContaining(RegExp(r'Yan[ıi]tla'));

Future<void> _openCommentReply(WidgetTester tester) async {
  await tester.ensureVisible(_replyAction().first);
  await tester.tap(_replyAction().first);
  await tester.pumpAndSettle();
  expect(_replyField(), findsOneWidget);
}

CommentItem _authComment(
  String id,
  String text, {
  String? parent,
  int replyCount = 0,
}) => CommentItem(
  id: id,
  user: const CommentUserSummary(
    id: 'reader',
    username: 'dinleyici',
    avatarUrl: null,
  ),
  text: text,
  deleted: false,
  parentCommentId: parent,
  replyCount: replyCount,
  createdAt: DateTime(2026, 9, 5, 22),
);

void _commentAccessPreviewTests(_CommentsRepository Function() repository) {
  final directory = Platform.environment['EVENT_COMMENT_RENDER_DIR'];
  if (directory == null) return;
  testWidgets(
    'render guest readable comments member composer and explicit reply previews',
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
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      });
      var capture = GlobalKey();
      await _openDetail(tester, _event(), capture: capture);
      await _captureCommentAccess(
        tester,
        capture,
        directory,
        '01-guest-empty.png',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      repository().comments.add(
        _authComment(
          'root',
          'Etkinlik için rezervasyon gerekiyor mu?',
          replyCount: 1,
        ),
      );
      repository().replies['root'] = [
        _authComment(
          'reply',
          'Kapıda da katılabilirsin. Görüşmek üzere!',
          parent: 'root',
        ),
      ];
      capture = GlobalKey();
      await _openDetail(tester, _event(), capture: capture);
      await tester.ensureVisible(
        find.text('Kapıda da katılabilirsin. Görüşmek üzere!'),
      );
      await _captureCommentAccess(
        tester,
        capture,
        directory,
        '02-guest-readable-comments.png',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      _registerCommentMember();
      capture = GlobalKey();
      await _openDetail(tester, _event(), capture: capture);
      await tester.ensureVisible(
        find.text('Kapıda da katılabilirsin. Görüşmek üzere!'),
      );
      await _captureCommentAccess(
        tester,
        capture,
        directory,
        '03-member-composer.png',
      );
      await _openCommentReply(tester);
      await _captureCommentAccess(
        tester,
        capture,
        directory,
        '04-member-reply.png',
      );
      expect(repository().creations, isEmpty);
    },
  );
}

Future<void> _captureCommentAccess(
  WidgetTester tester,
  GlobalKey key,
  String directory,
  String filename,
) async {
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final context = tester.element(find.byType(WeeklyEventDetailScreen));
    for (final image in tester.widgetList<Image>(find.byType(Image))) {
      await precacheImage(image.image, context);
    }
  });
  await tester.pumpAndSettle();
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(directory).create(recursive: true);
    await File(
      '$directory/$filename',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
