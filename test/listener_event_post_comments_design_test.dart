import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/engagement_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_item.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_page.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_user_summary.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_event_post_comments_sheet.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';

import 'support/event_audience_fakes.dart';

void main() {
  testWidgets('empty panel is compact with a docked accessible composer', (
    tester,
  ) async {
    await _mount(tester, _Repository());
    expect(find.text('Yorumlar'), findsOneWidget);
    expect(find.text('Henüz yorum yok'), findsOneWidget);
    expect(find.text('İlk yorumu sen yaz.'), findsOneWidget);
    expect(
      tester
          .getSize(find.byKey(const Key('listener-event-post-comments-panel')))
          .height,
      360,
    );
    expect(tester.getSize(find.byType(TextField)).height, closeTo(48, 1));
    expect(tester.getSize(find.byTooltip('Yorumu gönder')), const Size(48, 48));
    expect(
      tester.getSize(find.byTooltip('Yorumları kapat')),
      const Size(48, 48),
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).decoration!.fillColor,
      const Color(0xFF070B13),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('populated panel shows the real count and allows scrolling', (
    tester,
  ) async {
    await _mount(tester, _Repository(populated: true));
    expect(find.text('2'), findsOneWidget);
    expect(find.byKey(const Key('comment-thread-compact-empty')), findsNothing);
    expect(find.byType(ListView), findsOneWidget);
    expect(
      tester
          .getSize(find.byKey(const Key('listener-event-post-comments-panel')))
          .height,
      closeTo(844 * .72, .1),
    );
    expect(tester.takeException(), isNull);
  });

  for (final scale in [1.0, 2.0]) {
    for (final populated in [false, true]) {
      testWidgets(
        'narrow keyboard layout remains usable at ${scale}x with populated=$populated',
        (tester) async {
          await _mount(
            tester,
            _Repository(populated: populated),
            width: 320,
            height: 568,
            scale: scale,
            keyboard: 280,
          );
          await tester.enterText(
            find.byType(TextField),
            'Uzun bir yorum yazıyorum.\nİkinci satır.\nÜçüncü satır.',
          );
          await tester.pumpAndSettle();
          expect(
            tester.getRect(find.byType(TextField)).bottom,
            lessThanOrEqualTo(288),
          );
          expect(
            tester.getRect(find.byTooltip('Yorumu gönder')).bottom,
            lessThanOrEqualTo(288),
          );
          expect(tester.getRect(find.byType(TextField)).height, lessThan(90));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'reply strip and composer fit with narrow keyboard and large text',
    (tester) async {
      await _mount(
        tester,
        _Repository(populated: true),
        width: 320,
        height: 568,
        scale: 2,
      );
      await tester.ensureVisible(find.text('Yanıtla').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yanıtla').first);
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      expect(find.textContaining('Yanıtlanıyor:'), findsOneWidget);
      expect(
        tester.getRect(find.byType(TextField)).bottom,
        lessThanOrEqualTo(288),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Yanıttan vazgeç'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Yanıtlanıyor:'), findsNothing);
    },
  );

  if (Platform.environment['LISTENER_EVENT_COMMENTS_RENDER_DIR'] != null) {
    testWidgets('render publication comments with real fonts', (tester) async {
      await tester.runAsync(() async {
        final fonts =
            '${File(Platform.resolvedExecutable).parent.parent.parent.path}/material_fonts';
        final loader = FontLoader('Roboto');
        for (final font in [
          'roboto-regular.ttf',
          'roboto-medium.ttf',
          'roboto-bold.ttf',
        ]) {
          loader.addFont(
            File('$fonts/$font').readAsBytes().then(ByteData.sublistView),
          );
        }
        await loader.load();
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      });
      for (final name in [
        'empty',
        'populated',
        'keyboard',
        'narrow-keyboard-2x',
      ]) {
        final capture = GlobalKey();
        final narrow = name.startsWith('narrow');
        await _mount(
          tester,
          _Repository(populated: name == 'populated'),
          capture: capture,
          width: narrow ? 320 : 390,
          height: narrow ? 568 : 844,
          scale: narrow ? 2 : 1,
          keyboard: name.contains('keyboard') ? 280 : 0,
        );
        if (name.contains('keyboard')) {
          await tester.enterText(find.byType(TextField), 'Ben de geliyorum!');
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final pixels =
              await (capture.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 2);
          final bytes = await pixels.toByteData(format: ui.ImageByteFormat.png);
          final output =
              Platform.environment['LISTENER_EVENT_COMMENTS_RENDER_DIR']!;
          await Directory(output).create(recursive: true);
          await File(
            '$output/$name.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          pixels.dispose();
        });
      }
    });
  }
}

Future<void> _mount(
  WidgetTester tester,
  _Repository repository, {
  GlobalKey? capture,
  double width = 390,
  double height = 844,
  double scale = 1,
  double keyboard = 0,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetViewInsets);
  final sessions = AudienceTestSessions(audienceSession());
  addTearDown(sessions.dispose);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.navy.copyWith(
        textTheme: AppTheme.navy.textTheme.apply(fontFamily: 'Roboto'),
        primaryTextTheme: AppTheme.navy.primaryTextTheme.apply(
          fontFamily: 'Roboto',
        ),
      ),
      builder: (context, child) => RepaintBoundary(
        key: capture,
        child: MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
      home: Scaffold(
        backgroundColor: const Color(0xFF070B13),
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              showDragHandle: false,
              backgroundColor: const Color(0xFF101722),
              clipBehavior: Clip.antiAlias,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              builder: (_) => ListenerEventPostCommentsSheet(
                postId: audiencePostId,
                repository: repository,
                sessions: sessions,
                expectedSession: sessions.session,
              ),
            ),
            child: const Text('Yorumları aç'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Yorumları aç'));
  await tester.pumpAndSettle();
}

class _Repository extends Fake implements EngagementRepository {
  _Repository({this.populated = false});
  final bool populated;

  @override
  Future<Result<CommentPage>> listComments({
    required String targetType,
    required String targetId,
    int page = 0,
    int size = 20,
  }) async => Result.success(
    CommentPage(
      items: populated
          ? const [
              CommentItem(
                id: 'sample-one',
                user: CommentUserSummary(
                  id: 'other-user',
                  username: 'bugrasahin',
                  avatarUrl: null,
                ),
                text: 'Harika bir akşam olacak, sahnede görüşürüz! 🎸',
                deleted: false,
                parentCommentId: null,
                replyCount: 0,
                createdAt: null,
              ),
              CommentItem(
                id: 'sample-two',
                user: CommentUserSummary(
                  id: 'listener',
                  username: 'berna',
                  avatarUrl: null,
                ),
                text: 'Ben de oradayım 🙌',
                deleted: false,
                parentCommentId: null,
                replyCount: 0,
                createdAt: null,
              ),
            ]
          : const [],
      totalElements: populated ? 2 : 0,
      page: page,
      size: size,
    ),
  );
}
