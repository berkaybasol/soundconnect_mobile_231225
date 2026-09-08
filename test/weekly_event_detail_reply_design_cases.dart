part of 'weekly_event_detail_design_test.dart';

void _replyDesignTests(_CommentsRepository Function() repository) {
  group('event compact reply design', () {
    testWidgets(
      'short reply stays compact with accessible like and unframed delete',
      (tester) async {
        _registerCommentMember();
        _seedReplyDesign(repository(), [_replyDesignComment()]);
        await _openDetail(tester, _event());
        expect(find.byKey(const ValueKey('event-reply-reply')), findsNothing);
        expect(repository().replyReads, isEmpty);
        await _expandReplyDesign(tester);
        final reply = find.byKey(const ValueKey('event-reply-reply'));
        await tester.ensureVisible(reply);
        await tester.pumpAndSettle();
        // The extra accessible heart may wrap metadata under the wide test
        // font. It must not create the old tall, independently framed reply.
        expect(tester.getSize(reply).height, inInclusiveRange(44, 80));
        final name = find.descendant(of: reply, matching: find.text('@berna'));
        final age = find.descendant(of: reply, matching: find.text('Az önce'));
        final body = find.descendant(of: reply, matching: find.text('a'));
        expect(tester.getTopLeft(name).dx, tester.getTopLeft(body).dx);
        final inline =
            (tester.getCenter(name).dy - tester.getCenter(age).dy).abs() < 1;
        if (inline) {
          expect(
            tester.getTopLeft(age).dx,
            greaterThan(tester.getTopRight(name).dx),
          );
        } else {
          expect(tester.getTopLeft(age).dx, tester.getTopLeft(name).dx);
          expect(
            tester.getTopLeft(age).dy,
            greaterThanOrEqualTo(tester.getBottomLeft(name).dy),
          );
        }
        final like = find.byKey(const ValueKey('comment-like-reply'));
        expect(tester.getSize(like).width, greaterThanOrEqualTo(44));
        expect(tester.getSize(like).height, greaterThanOrEqualTo(44));
        final delete = find.byKey(const ValueKey('event-comment-delete-reply'));
        // Material may pad the visual44dp control to its48dp touch target.
        expect(tester.getSize(delete).width, inInclusiveRange(44, 48));
        expect(tester.getSize(delete).height, inInclusiveRange(44, 48));
        final button = tester.widget<IconButton>(delete);
        expect(button.tooltip, 'Yorumu sil');
        expect(button.style!.backgroundColor!.resolve({}), Colors.transparent);
        expect(button.style!.side!.resolve({}), BorderSide.none);
        expect(repository().deletions, isEmpty);
        expect(repository().replyReads, [('root', 'event-design-1')]);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'folding removes reply rows and reopening keeps the loaded page',
      (tester) async {
        _registerCommentMember();
        _seedReplyDesign(repository(), [_replyDesignComment()]);
        await _openDetail(tester, _event());
        final toggle = find.byKey(const ValueKey('event-replies-root'));
        await _expandReplyDesign(tester);
        expect(find.text('Yanıtları gizle'), findsOneWidget);
        await tester.ensureVisible(toggle);
        await tester.pumpAndSettle();
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(find.text('Yanıtları göster (1)'), findsOneWidget);
        expect(find.byKey(const ValueKey('event-reply-reply')), findsNothing);
        expect(
          find.byKey(const ValueKey('event-replies-more-root')),
          findsNothing,
        );
        await _expandReplyDesign(tester);
        expect(find.byKey(const ValueKey('event-reply-reply')), findsOneWidget);
        expect(repository().replyReads, [('root', 'event-design-1')]);
        expect(tester.takeException(), isNull);
      },
    );

    for (final kind in ['long', 'ghost', 'anonymous', 'deleted']) {
      testWidgets(
        '320dp 2x $kind reply wraps without exposing hidden identity',
        (tester) async {
          _registerCommentMember();
          final item = _replyDesignComment(
            kind: kind,
            text: List.filled(25, 'Uzun yanıt metni. ').join(),
          );
          _seedReplyDesign(repository(), [item]);
          await _openDetail(
            tester,
            _event(),
            size: const Size(320, 844),
            textScale: 2,
          );
          await _expandReplyDesign(tester);
          final reply = find.byKey(const ValueKey('event-reply-reply'));
          await tester.ensureVisible(reply);
          await tester.pumpAndSettle();
          final rect = tester.getRect(reply);
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(320));
          final hidden = kind == 'anonymous' || kind == 'deleted';
          if (!hidden) {
            final initial = find.descendant(
              of: reply,
              matching: find.text('U'),
            );
            final author = find.descendant(
              of: reply,
              matching: find.text('@${item.user.username}'),
            );
            expect(
              MediaQuery.textScalerOf(tester.element(initial)).scale(10),
              10,
            );
            expect(
              MediaQuery.textScalerOf(tester.element(author)).scale(10),
              20,
            );
          }
          expect(
            find.descendant(
              of: reply,
              matching: find.text('@${item.user.username}'),
            ),
            hidden ? findsNothing : findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('event-comment-delete-reply')),
            hidden ? findsNothing : findsOneWidget,
          );
          if (hidden) {
            expect(
              find.descendant(
                of: reply,
                matching: find.byType(AppCachedNetworkImage),
              ),
              findsNothing,
            );
          }
          expect(
            find.descendant(
              of: reply,
              matching: find.text(
                kind == 'deleted' ? 'Bu yorum silindi.' : item.text,
              ),
            ),
            findsOneWidget,
          );
          if (kind == 'ghost') {
            final semantics = tester.ensureSemantics();
            await tester.pump();
            expect(find.bySemanticsLabel('Hayalet profil'), findsOneWidget);
            semantics.dispose();
          }
          expect(tester.takeException(), isNull);
        },
      );
    }

    final directory = Platform.environment['EVENT_REPLY_RENDER_DIR'];
    if (directory == null || directory.isEmpty) return;
    testWidgets('renders folded and opened compact replies with real fonts', (
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
      _registerCommentMember();
      _seedReplyDesign(repository(), [
        _replyDesignComment(),
        _replyDesignComment(id: 'second', text: 'Görüşürüz.', kind: 'guest'),
      ], rootText: 'Burada buluşuyoruz.');
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
        final toggle = find.byKey(const ValueKey('event-replies-root'));
        await tester.scrollUntilVisible(
          toggle,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await _captureCommentAccess(
          tester,
          capture,
          directory,
          'event-replies-folded-${scale.toInt()}x.png',
        );
        await _expandReplyDesign(tester);
        await tester.ensureVisible(
          find.byKey(const ValueKey('event-reply-second')),
        );
        await tester.pumpAndSettle();
        await _captureCommentAccess(
          tester,
          capture,
          directory,
          'event-replies-open-${scale.toInt()}x.png',
        );
        expect(tester.takeException(), isNull);
      }
      expect(repository().creations, isEmpty);
      expect(repository().deletions, isEmpty);
    });
  });
}

void _seedReplyDesign(
  _CommentsRepository repository,
  List<CommentItem> replies, {
  String rootText = 'Burada buluşuyoruz 🎵',
}) {
  repository.comments.add(
    _authComment('root', rootText, replyCount: replies.length),
  );
  repository.replies['root'] = replies;
}

Future<void> _expandReplyDesign(WidgetTester tester) async {
  final toggle = find.byKey(const ValueKey('event-replies-root'));
  await tester.scrollUntilVisible(
    toggle,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.ensureVisible(toggle);
  await tester.pumpAndSettle();
  await tester.tap(toggle);
  await tester.pumpAndSettle();
}

CommentItem _replyDesignComment({
  String id = 'reply',
  String kind = 'own',
  String text = 'a',
}) => CommentItem(
  id: id,
  user: CommentUserSummary(
    id: kind == 'guest' ? 'other' : 'commenter',
    username: kind == 'own'
        ? 'berna'
        : kind == 'guest'
        ? 'sena'
        : 'UzunKullaniciAdiHerKosuldaTasmamali',
    avatarUrl: kind == 'anonymous' || kind == 'deleted'
        ? 'https://example.test/hidden-avatar.png'
        : null,
    visibilityMode: kind == 'ghost'
        ? ListenerVisibilityMode.ghost
        : ListenerVisibilityMode.standard,
  ),
  anonymousAuthor: kind == 'anonymous',
  text: text,
  deleted: kind == 'deleted',
  parentCommentId: 'root',
  replyCount: 0,
  createdAt: DateTime.now().toUtc(),
);
