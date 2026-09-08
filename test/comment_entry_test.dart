import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_item.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_user_summary.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/presentation/widgets/comment_author_identity.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/presentation/widgets/comment_entry.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/listener_visibility_mode.dart';
import 'package:soundconnect_23_12_25codx/shared/images/app_cached_network_image.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/ghost_profile_badge.dart';

void main() {
  testWidgets(
    'reference root is130to150dp tall with44dp author and outlined delete',
    (tester) async {
      await _mount(
        tester,
        CommentEntry(
          key: const Key('entry'),
          comment: _comment(),
          timeLabel: 'Az önce',
          onReplyTap: () {},
          onDeleteTap: () {},
          deleteKey: const Key('delete'),
          likeButton: IconButton(
            key: const Key('like'),
            tooltip: 'Beğen',
            onPressed: () {},
            icon: const Icon(Icons.favorite_border),
          ),
        ),
      );
      expect(
        tester.getSize(find.byKey(const Key('entry'))).height,
        inInclusiveRange(130, 150),
      );
      expect(
        tester
            .widget<CommentAuthorAvatar>(find.byType(CommentAuthorAvatar))
            .size,
        44,
      );
      for (final button in tester.widgetList<TextButton>(
        find.byType(TextButton),
      )) {
        expect(button.style!.minimumSize!.resolve({})!.height, 44);
        expect(button.style!.backgroundColor!.resolve({}), Colors.transparent);
        expect(button.style!.textStyle!.resolve({})!.fontSize, 14);
      }
      expect(
        tester.getSize(find.byKey(const Key('delete'))).height,
        greaterThanOrEqualTo(44),
      );
      expect(find.byTooltip('Yorumu sil'), findsOneWidget);
      expect(
        tester.getTopRight(find.byKey(const Key('like'))).dx,
        lessThan(tester.getTopLeft(find.text('Yanıtla')).dx),
      );
      expect(find.byType(Card), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reply avatar is28dp and keeps the same content and callbacks', (
    tester,
  ) async {
    var author = 0, reply = 0, deleted = 0, liked = 0;
    await _mount(
      tester,
      CommentEntry(
        comment: _comment(text: 'Yanıt'),
        timeLabel: '2 dk önce',
        isReply: true,
        onAuthorTap: () => author++,
        onReplyTap: () => reply++,
        onDeleteTap: () => deleted++,
        likeButton: IconButton(
          key: const Key('like'),
          tooltip: 'Beğen',
          onPressed: () => liked++,
          icon: const Icon(Icons.favorite_border),
        ),
      ),
    );
    expect(
      tester.widget<CommentAuthorAvatar>(find.byType(CommentAuthorAvatar)).size,
      28,
    );
    await tester.tap(find.text('@bugrasahin'));
    expect(
      tester.getTopRight(find.byKey(const Key('like'))).dx,
      lessThan(tester.getTopLeft(find.text('Yanıtla')).dx),
    );
    await tester.tap(find.byTooltip('Beğen'));
    await tester.tap(find.text('Yanıtla'));
    await tester.tap(find.byTooltip('Yorumu sil'));
    expect((author, reply, deleted, liked), (1, 1, 1, 1));
    expect(find.text('Yanıt'), findsOneWidget);
  });

  for (final enabled in [false, true]) {
    testWidgets(
      'actionsEnabled=$enabled preserves visible actions without changing authority',
      (tester) async {
        var actions = 0;
        await _mount(
          tester,
          CommentEntry(
            comment: _comment(),
            timeLabel: 'Az önce',
            actionsEnabled: enabled,
            onReplyTap: () => actions++,
            onDeleteTap: () => actions++,
          ),
        );
        await tester.tap(find.text('Yanıtla'));
        await tester.tap(find.byTooltip('Yorumu sil'));
        expect(actions, enabled ? 2 : 0);
      },
    );
  }

  testWidgets(
    'deleting disables both actions and shows a small progress indicator',
    (tester) async {
      await _mount(
        tester,
        CommentEntry(
          comment: _comment(),
          timeLabel: 'Az önce',
          deleting: true,
          onReplyTap: () {},
          onDeleteTap: () {},
          deleteKey: const Key('delete'),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.widget<IconButton>(find.byKey(const Key('delete'))).onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Yanıtla'))
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final deleted in [false, true]) {
    testWidgets(
      '${deleted ? 'deleted' : 'anonymous'} identity never fetches supplied photo or exposes delete',
      (tester) async {
        var author = 0;
        await _mount(
          tester,
          CommentEntry(
            comment: _comment(
              anonymous: !deleted,
              deleted: deleted,
              avatar: 'https://private.invalid/avatar',
            ),
            timeLabel: 'Az önce',
            onAuthorTap: () => author++,
            onReplyTap: () {},
            onDeleteTap: () {},
          ),
        );
        expect(find.byType(AppCachedNetworkImage), findsNothing);
        expect(find.text('@bugrasahin'), findsNothing);
        expect(find.text('Sil'), findsNothing);
        expect(find.byTooltip('Yorumu sil'), findsNothing);
        await tester.tap(find.byType(CommentAuthorAvatar));
        expect(author, 0);
        if (deleted) {
          expect(find.text('Bu yorum silindi.'), findsOneWidget);
          expect(find.text('Yanıtla'), findsNothing);
        } else {
          expect(
            find.text('Kimliğini açıklamak istemeyen yazar'),
            findsOneWidget,
          );
          expect(find.text('Yanıtla'), findsOneWidget);
        }
      },
    );
  }

  for (final scale in [1.0, 2.0]) {
    for (final variant in [
      'longName',
      '500chars',
      'multiline',
      'ghost',
      'anonymous',
    ]) {
      testWidgets(
        '320dp ${scale}x $variant has no overflow or cropped comment text',
        (tester) async {
          final text = switch (variant) {
            '500chars' => List.filled(50, 'uzunmetin ').join(),
            'multiline' => 'İlk satır\nİkinci satır\nÜçüncü satır',
            _ => 'Sesler çok güzel olmuş.',
          };
          await _mount(
            tester,
            CommentEntry(
              comment: _comment(
                text: text,
                username: variant == 'longName'
                    ? List.filled(8, 'ÇokUzunKullanıcıAdı').join()
                    : 'bugrasahin',
                ghost: variant == 'ghost',
                anonymous: variant == 'anonymous',
              ),
              timeLabel: '3 saat önce',
              onReplyTap: () {},
              onDeleteTap: () {},
            ),
            width: 320,
            scale: scale,
          );
          final comment = tester.widget<Text>(find.text(text));
          expect(comment.maxLines, isNull);
          expect(comment.style!.fontSize, 14);
          expect(comment.style!.height, 1.4);
          if (variant == 'ghost') {
            final semantics = tester.ensureSemantics();
            expect(find.bySemanticsLabel('Hayalet profil'), findsOneWidget);
            expect(
              tester
                  .widget<GhostProfileBadge>(find.byType(GhostProfileBadge))
                  .showLabel,
              isTrue,
            );
            semantics.dispose();
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('read-only missing-time entry does not reserve an empty footer', (
    tester,
  ) async {
    await _mount(
      tester,
      CommentEntry(key: const Key('entry'), comment: _comment(), timeLabel: ''),
    );
    expect(find.byType(TextButton), findsNothing);
    expect(
      tester.getSize(find.byKey(const Key('entry'))).height,
      lessThan(110),
    );
  });

  if (Platform.environment['COMMENT_ENTRY_RENDER_DIR']
      case final String directory) {
    testWidgets('render compact comment entries with real fonts', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final fonts =
            '${File(Platform.resolvedExecutable).parent.parent.parent.path}/material_fonts';
        final loader = FontLoader('Roboto');
        for (final name in ['regular', 'medium', 'bold', 'black']) {
          loader.addFont(
            File(
              '$fonts/roboto-$name.ttf',
            ).readAsBytes().then(ByteData.sublistView),
          );
        }
        await loader.load();
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      });
      await _mount(
        tester,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                'Sorular & Yorumlar',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
            CommentEntry(
              comment: _comment(),
              timeLabel: 'Az önce',
              onReplyTap: () {},
              onDeleteTap: () {},
            ),
            const Divider(height: 12),
            CommentEntry(
              comment: _comment(
                username: 'aedrum',
                text: 'Sesler çok iyi olmuş! Bu akşam sahne kaçta başlıyor?',
              ),
              timeLabel: '2 dk önce',
              onReplyTap: () {},
            ),
            Padding(
              padding: const EdgeInsets.only(left: 30),
              child: CommentEntry(
                isReply: true,
                comment: _comment(text: '20.00’de görüşürüz.'),
                timeLabel: 'Az önce',
                onReplyTap: () {},
                onDeleteTap: () {},
              ),
            ),
            const Divider(height: 12),
            CommentEntry(
              comment: _comment(
                username: 'dinleyici',
                ghost: true,
                text: 'Güzel bir akşam olacak.',
              ),
              timeLabel: '5 dk önce',
              onReplyTap: () {},
            ),
          ],
        ),
        width: 390,
      );
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('entry-render')),
      );
      await tester.runAsync(() async {
        final pixels = await boundary.toImage(pixelRatio: 2);
        final bytes = await pixels.toByteData(format: ui.ImageByteFormat.png);
        await Directory(directory).create(recursive: true);
        await File(
          '$directory/compact-comment-entry.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        pixels.dispose();
      });
      await _mount(
        tester,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CommentEntry(
              comment: _comment(
                username: 'uzun_kullanici_adi',
                ghost: true,
                text: 'Güzel bir akşam olacak.\nSahne kaçta başlıyor?',
              ),
              timeLabel: 'Az önce',
              onReplyTap: () {},
              onDeleteTap: () {},
            ),
          ],
        ),
        width: 320,
        scale: 2,
      );
      expect(tester.takeException(), isNull);
      final narrow = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('entry-render')),
      );
      await tester.runAsync(() async {
        final pixels = await narrow.toImage(pixelRatio: 2);
        final bytes = await pixels.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '$directory/compact-comment-ghost-320-2x.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        pixels.dispose();
      });
    });
  }
}

Future<void> _mount(
  WidgetTester tester,
  Widget child, {
  double width = 390,
  double scale = 1,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.navy.copyWith(
        textTheme: AppTheme.navy.textTheme.apply(fontFamily: 'Roboto'),
      ),
      builder: (context, child) => RepaintBoundary(
        key: const Key('entry-render'),
        child: MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
      home: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    ),
  );
  // A deleting entry deliberately animates indefinitely.
  await tester.pump();
}

CommentItem _comment({
  String text = 'a',
  String username = 'bugrasahin',
  String? avatar,
  bool anonymous = false,
  bool deleted = false,
  bool ghost = false,
}) => CommentItem(
  id: 'comment',
  user: CommentUserSummary(
    id: 'user',
    username: username,
    avatarUrl: avatar,
    visibilityMode: ghost
        ? ListenerVisibilityMode.ghost
        : ListenerVisibilityMode.standard,
  ),
  text: text,
  anonymousAuthor: anonymous,
  deleted: deleted,
  parentCommentId: null,
  replyCount: 0,
  createdAt: DateTime(2026),
);
