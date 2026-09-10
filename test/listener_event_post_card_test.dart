import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/venue_event_detail.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_event_post_card.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_colors.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';

void main() {
  if (Platform.environment['LISTENER_EVENT_CARD_RENDER_DIR'] != null) {
    testWidgets('render updated event post cards with real fonts', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final fonts =
            '${File(Platform.resolvedExecutable).parent.parent.parent.path}/material_fonts';
        final loader = FontLoader('Roboto');
        for (final font in [
          'roboto-regular.ttf',
          'roboto-medium.ttf',
          'roboto-bold.ttf',
          'roboto-black.ttf',
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
        'owner',
        'owner-liked',
        'owner-long-note',
        'public',
        'public-going',
        'owner-narrow-2x',
        'public-narrow-2x',
        'public-going-narrow-2x',
      ]) {
        final capture = GlobalKey();
        final owner = name.startsWith('owner');
        final narrow = name.endsWith('2x');
        await _pump(
          tester,
          _card(
            owner: owner,
            isParticipating: name.startsWith('public-going'),
            note: name == 'owner-long-note'
                ? 'Bu akşam aynı şarkılara eşlik edelim. Uzun zamandır canlı '
                      'dinlemek istediğim bir sahne; aranızda gelmeyi düşünen '
                      'varsa konser öncesi buluşabiliriz. Şehrin gürültüsünden '
                      'biraz uzaklaşıp müziğe karışmak iyi gelecek.'
                : 'Hadi gidek',
            onOpen: () {},
            onIntent: () {},
            onComments: () {},
            onLike: () {},
            isLiked: name == 'owner-liked',
            likeCount: 12,
            commentCount: 3,
            onShare: () {},
            onDelete: owner ? () {} : null,
          ),
          capture: capture,
          width: narrow ? 320 : 390,
          textScale: narrow ? 2 : 1,
        );
        await tester.runAsync(() async {
          await precacheImage(
            const AssetImage('assets/logo.png'),
            tester.element(find.byType(Scaffold)),
          );
        });
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final pixels =
              await (capture.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 2);
          final bytes = await pixels.toByteData(format: ui.ImageByteFormat.png);
          final output =
              Platform.environment['LISTENER_EVENT_CARD_RENDER_DIR']!;
          await Directory(output).create(recursive: true);
          await File(
            '$output/$name.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          pixels.dispose();
        });
      }
    });
  }
  testWidgets('published header uses one @ without repeating the participant', (
    tester,
  ) async {
    await _pump(tester, _card(username: '@berna'));

    expect(find.text('@berna'), findsOneWidget);
    expect(find.text('Bu etkinliğe gidiyor.'), findsOneWidget);
    expect(find.text('Gidiyorum'), findsNothing);
    expect(find.text('@@berna'), findsNothing);
  });

  testWidgets('thinking status does not claim confirmed attendance', (
    tester,
  ) async {
    await _pump(tester, _card(intentLabel: 'Düşünüyorum', owner: true));

    expect(find.text('Bu etkinliğe katılmayı düşünüyor.'), findsOneWidget);
    expect(find.text('Bu etkinliğe katılmayı düşünüyorsun.'), findsOneWidget);
    expect(find.text('Bu etkinliğe katılıyorsun!'), findsNothing);
  });

  testWidgets('past post describes the plan without claiming attendance', (
    tester,
  ) async {
    await _pump(tester, _card(ended: true, owner: true));

    expect(find.text('Bu etkinliğe gitmeyi planlamıştı.'), findsOneWidget);
    expect(find.text('Bu etkinliğe katılmayı planlamıştın.'), findsOneWidget);
    expect(find.text('Bu etkinliğe katılıyorsun!'), findsNothing);
  });

  testWidgets('owner gets a noninteractive status and only delete in menu', (
    tester,
  ) async {
    var deletes = 0;
    var intents = 0;
    await _pump(
      tester,
      _card(owner: true, onDelete: () => deletes++, onIntent: () => intents++),
    );

    expect(find.text('Planımı düzenle'), findsNothing);
    expect(
      find.byKey(const ValueKey('listener-event-intent-event')),
      findsNothing,
    );
    final status = find.text('Bu etkinliğe katılıyorsun!');
    await tester.tap(status);
    expect(intents, 0);
    expect(deletes, 0);
    final menu = find.byTooltip('Paylaşım seçenekleri');
    expect(tester.getSize(menu), const Size(48, 48));
    await tester.tap(menu);
    await tester.pumpAndSettle();

    expect(find.byType(PopupMenuItem<String>), findsOneWidget);
    await tester.tap(find.text('Paylaşımı sil'));
    await tester.pumpAndSettle();
    expect(deletes, 1);
    expect(intents, 0);
  });

  testWidgets('visitors never get owner management actions', (tester) async {
    var edits = 0;
    await _pump(
      tester,
      _card(
        onDelete: () => edits++,
        onChangeIntent: () => edits++,
        onEditNote: () => edits++,
      ),
    );

    expect(find.byTooltip('Paylaşım seçenekleri'), findsNothing);
    expect(find.text('Paylaşımı sil'), findsNothing);
    expect(find.text('Açıklamayı düzenle'), findsNothing);
    expect(find.text('Düşünüyorum olarak değiştir'), findsNothing);
    expect(edits, 0);
  });

  for (final scale in [1.0, 2.0, 3.0]) {
    testWidgets(
      'all owner menu actions remain distinct and usable at ${scale}x',
      (tester) async {
        final calls = <String>[];
        await _pump(
          tester,
          _card(
            owner: true,
            intentLabel: 'Düşünüyorum',
            onChangeIntent: () => calls.add('intent'),
            onEditNote: () => calls.add('note'),
            onDelete: () => calls.add('delete'),
          ),
          width: 320,
          textScale: scale,
        );

        for (final action in const {
          'Gidiyorum olarak değiştir': 'intent',
          'Açıklamayı düzenle': 'note',
          'Paylaşımı sil': 'delete',
        }.entries) {
          await tester.tap(find.byTooltip('Paylaşım seçenekleri'));
          await tester.pumpAndSettle();
          expect(find.byType(PopupMenuItem<String>), findsNWidgets(3));
          expect(tester.takeException(), isNull);
          final target = find.text(action.key);
          await tester.ensureVisible(target);
          await tester.tap(target);
          await tester.pumpAndSettle();
          expect(calls, [action.value]);
          calls.clear();
          expect(find.byType(PopupMenuItem<String>), findsNothing);
          expect(tester.takeException(), isNull);
        }
      },
    );
  }

  testWidgets(
    'owner management uses the menu instead of a separate plan button',
    (tester) async {
      var edits = 0;
      await _pump(
        tester,
        _card(owner: true, onChangeIntent: () => edits++, onEditNote: () {}),
      );

      expect(find.text('Planımı düzenle'), findsNothing);
      expect(find.text('Bu etkinliğe katılıyorsun!'), findsOneWidget);
      await tester.tap(find.byTooltip('Paylaşım seçenekleri'));
      await tester.pumpAndSettle();
      expect(find.text('Açıklamayı düzenle'), findsOneWidget);
      await tester.tap(find.text('Düşünüyorum olarak değiştir'));
      await tester.pumpAndSettle();
      expect(edits, 1);
    },
  );

  testWidgets('post comments and event opening are distinct actions', (
    tester,
  ) async {
    var eventOpens = 0;
    var commentOpens = 0;
    var shares = 0;
    await _pump(
      tester,
      _card(
        onOpen: () => eventOpens++,
        onComments: () => commentOpens++,
        onShare: () => shares++,
      ),
    );

    expect(find.text('Yorumlar'), findsNothing);
    expect(find.text('Paylaş'), findsNothing);
    await tester.tap(find.byTooltip('Yorumlar'));
    expect(commentOpens, 1);
    expect(eventOpens, 0);
    await tester.tap(find.byKey(const ValueKey('listener-event-open-event')));
    expect(eventOpens, 1);
    expect(commentOpens, 1);
    await tester.tap(find.byTooltip('Paylaş'));
    expect(shares, 1);
    expect(commentOpens, 1);
    expect(eventOpens, 1);
  });

  testWidgets('missing post comments callback never exposes event comments', (
    tester,
  ) async {
    await _pump(tester, _card(onOpen: () {}));

    expect(find.byTooltip('Yorumlar'), findsNothing);
    expect(
      find.byKey(const ValueKey('listener-event-comments-event')),
      findsNothing,
    );
  });

  testWidgets('like and comment counts use their actual post callbacks', (
    tester,
  ) async {
    var likes = 0;
    var comments = 0;
    var eventOpens = 0;
    await _pump(
      tester,
      _card(
        onOpen: () => eventOpens++,
        onLike: () => likes++,
        onComments: () => comments++,
        onShare: () {},
        likeCount: 42,
        commentCount: 7,
      ),
    );

    final like = find.byKey(const ValueKey('listener-event-like-event'));
    final comment = find.byKey(const ValueKey('listener-event-comments-event'));
    expect(
      find.descendant(of: like, matching: find.text('42')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: comment, matching: find.text('7')),
      findsOneWidget,
    );
    expect(find.text('Beğen'), findsNothing);
    expect(find.text('Yorumlar'), findsNothing);
    // The counter may grow the target with different font metrics; its touch
    // height stays compact and its width must never shrink below 48 pixels.
    expect(tester.getSize(like).height, 48);
    expect(tester.getSize(like).width, inInclusiveRange(48, 80));
    expect(tester.getRect(comment).left - tester.getRect(like).right, 18);
    await tester.tap(find.byTooltip('Beğen'));
    await tester.tap(find.byTooltip('Yorumlar'));
    expect(likes, 1);
    expect(comments, 1);
    expect(eventOpens, 0);
  });

  testWidgets('unread counts do not fabricate zeros', (tester) async {
    await _pump(tester, _card(onLike: () {}, onComments: () {}));

    expect(find.byTooltip('Beğen'), findsOneWidget);
    expect(find.byTooltip('Yorumlar'), findsOneWidget);
    expect(find.text('0'), findsNothing);

    await _pump(
      tester,
      _card(onLike: () {}, onComments: () {}, likeCount: 0, commentCount: 0),
    );
    expect(find.text('0'), findsNWidgets(2));
  });

  testWidgets('liked state is a filled pink heart with an unlike action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var unlikes = 0;
    await _pump(
      tester,
      _card(isLiked: true, likeCount: 18, onLike: () => unlikes++),
    );

    expect(find.byIcon(Icons.favorite_border_rounded), findsNothing);
    final icon = tester.widget<Icon>(find.byIcon(Icons.favorite_rounded));
    expect(icon.size, 18);
    expect(icon.color, AppColors.likeHeart);
    expect(
      tester.getSemantics(
        find.byKey(const ValueKey('listener-event-like-event')),
      ),
      matchesSemantics(
        label: 'Beğenmekten vazgeç',
        value: '18 beğeni',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    await tester.tap(find.byTooltip('Beğenmekten vazgeç'));
    expect(unlikes, 1);
    semantics.dispose();
  });

  testWidgets('busy like remains visible and cannot send another request', (
    tester,
  ) async {
    var likes = 0;
    await _pump(
      tester,
      _card(
        onLike: () => likes++,
        likeBusy: true,
        isLiked: true,
        likeCount: 19,
      ),
    );

    final action = find.byKey(const ValueKey('listener-event-like-event'));
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    expect(
      find.descendant(of: action, matching: find.text('19')),
      findsOneWidget,
    );
    await tester.tap(action);
    await tester.tap(action);
    expect(likes, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('draft keeps its editor and actions without a delete menu', (
    tester,
  ) async {
    var publishes = 0;
    await _pump(
      tester,
      _card(
        owner: true,
        onDelete: () {},
        noteEditor: const TextField(
          decoration: InputDecoration(labelText: 'Açıklama'),
        ),
        actions: TextButton(
          onPressed: () => publishes++,
          child: const Text('Paylaşımı yayınla'),
        ),
      ),
    );

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Gidiyorum'), findsOneWidget);
    expect(find.byTooltip('Paylaşım seçenekleri'), findsNothing);
    expect(find.text('Bu etkinliğe katılıyorsun!'), findsNothing);
    await tester.tap(find.text('Paylaşımı yayınla'));
    expect(publishes, 1);
  });

  for (final scale in [1.0, 2.0, 3.0]) {
    testWidgets('large engagement counts fit narrow layout at ${scale}x', (
      tester,
    ) async {
      await _pump(
        tester,
        _card(
          owner: true,
          onLike: () {},
          onComments: () {},
          onShare: () {},
          likeCount: 12345678,
          commentCount: 123456,
        ),
        width: 320,
        textScale: scale,
      );

      final share = find.byKey(const ValueKey('listener-event-share-event'));
      await tester.ensureVisible(share);
      await tester.pumpAndSettle();
      for (final name in ['like', 'comments', 'share']) {
        final bounds = tester.getRect(
          find.byKey(ValueKey('listener-event-$name-event')),
        );
        expect(bounds.width, greaterThanOrEqualTo(48));
        expect(bounds.height, greaterThanOrEqualTo(48));
        expect(bounds.left, greaterThanOrEqualTo(0));
        expect(bounds.right, lessThanOrEqualTo(320));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('owner actions fit narrow viewport at ${scale}x text size', (
      tester,
    ) async {
      await _pump(
        tester,
        _card(
          username: 'cok_uzun_kullanici_adi_olan_dinleyici',
          owner: true,
          onDelete: () {},
          onComments: () {},
          onShare: () {},
        ),
        width: 320,
        textScale: scale,
      );

      expect(tester.takeException(), isNull);
      final comments = find.byKey(
        const ValueKey('listener-event-comments-event'),
      );
      final share = find.byKey(const ValueKey('listener-event-share-event'));
      await tester.ensureVisible(share);
      await tester.pumpAndSettle();
      final commentsBounds = tester.getRect(comments);
      final shareBounds = tester.getRect(share);
      expect(commentsBounds.left, greaterThanOrEqualTo(0));
      expect(shareBounds.right, lessThanOrEqualTo(320));
      expect(commentsBounds.size, const Size(48, 48));
      expect(shareBounds.size, const Size(48, 48));
      expect(commentsBounds.top, shareBounds.top);
      expect(tester.takeException(), isNull);
    });
  }

  for (final scale in [1.0, 2.0, 3.0]) {
    testWidgets(
      'selected participation remains compact and clickable at ${scale}x',
      (tester) async {
        var intents = 0;
        await _pump(
          tester,
          _card(
            isParticipating: true,
            onIntent: () => intents++,
            onComments: () {},
            onShare: () {},
          ),
          width: 320,
          textScale: scale,
        );
        final intent = find.text('Bu etkinliğe katılıyorsun!');
        await tester.ensureVisible(intent);
        await tester.tap(intent);
        expect(intents, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final scale in [2.0, 3.0]) {
    testWidgets('visitor participation action fits at ${scale}x text size', (
      tester,
    ) async {
      var intents = 0;
      await _pump(
        tester,
        _card(onIntent: () => intents++, onComments: () {}, onShare: () {}),
        width: 320,
        textScale: scale,
      );

      expect(tester.takeException(), isNull);
      final intent = find.text('Ben de gidiyorum');
      await tester.ensureVisible(intent);
      await tester.tap(intent);
      expect(intents, 1);
      expect(tester.takeException(), isNull);
    });
  }
}

ListenerEventPostCard _card({
  String username = 'berna',
  String intentLabel = 'Gidiyorum',
  bool owner = false,
  bool ended = false,
  VoidCallback? onOpen,
  VoidCallback? onIntent,
  VoidCallback? onComments,
  VoidCallback? onLike,
  bool isLiked = false,
  bool likeBusy = false,
  bool isParticipating = false,
  int? likeCount,
  int? commentCount,
  VoidCallback? onDelete,
  VoidCallback? onChangeIntent,
  VoidCallback? onEditNote,
  VoidCallback? onShare,
  Widget? noteEditor,
  Widget? actions,
  String? note,
}) => ListenerEventPostCard(
  event: VenueEventDetail(
    id: 'event',
    shareUrl: null,
    posterImage: null,
    performerName: 'bugrasahin',
    musicianProfileId: 'musician',
    title: 'Test Sahnesi',
    eventDate: DateTime(2026, 9, 9),
    startTime: '20:00',
    endTime: '22:00',
    venueName: 'soundconnectankara',
    venueCity: 'Ankara',
    venueDistrict: 'Çankaya',
  ),
  username: username,
  intentLabel: intentLabel,
  owner: owner,
  ended: ended,
  onOpen: onOpen,
  onIntent: onIntent,
  onComments: onComments,
  onLike: onLike,
  isLiked: isLiked,
  likeBusy: likeBusy,
  isParticipating: isParticipating,
  likeCount: likeCount,
  commentCount: commentCount,
  onDelete: onDelete,
  onChangeIntent: onChangeIntent,
  onEditNote: onEditNote,
  onShare: onShare,
  noteEditor: noteEditor,
  actions: actions,
  note: note,
);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double width = 390,
  double textScale = 1,
  GlobalKey? capture,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: capture == null
          ? AppTheme.navy
          : AppTheme.navy.copyWith(
              textTheme: AppTheme.navy.textTheme.apply(fontFamily: 'Roboto'),
              primaryTextTheme: AppTheme.navy.primaryTextTheme.apply(
                fontFamily: 'Roboto',
              ),
            ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: capture == null
              ? child
              : RepaintBoundary(key: capture, child: child),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
