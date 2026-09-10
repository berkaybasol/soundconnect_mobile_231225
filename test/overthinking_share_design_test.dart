import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/data/models/overthinking_post_model.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/share/overthinking_share_card.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/share/overthinking_share_data.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/share/overthinking_share_service.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/share/overthinking_share_sheet.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';

const _preview = bool.fromEnvironment('OVERTHINKING_STORY_PREVIEW');
final _pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==',
);

void main() {
  for (final anonymous in [false, true]) {
    for (final music in [false, true]) {
      for (final longCopy in [false, true]) {
        testWidgets(
          'fixed story bounds anonymous=$anonymous music=$music long=$longCopy',
          (tester) async {
            _viewport(tester, const Size(800, 1000));
            final data = _data(
              anonymous: anonymous,
              music: music,
              longCopy: longCopy,
            );
            await tester.pumpWidget(
              MaterialApp(
                theme: AppTheme.navy,
                home: MediaQuery(
                  data: const MediaQueryData(textScaler: TextScaler.linear(3)),
                  child: Center(
                    child: OverthinkingShareCard(
                      data: data,
                      // Even an accidentally supplied avatar must stay masked.
                      authorAvatar: MemoryImage(_pixel),
                      albumImage: music ? MemoryImage(_pixel) : null,
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final card = find.byType(OverthinkingShareCard);
            expect(tester.getSize(card), const Size(360, 640));
            final bounds = tester.getRect(card);
            final title = find.byKey(const Key('overthinking-share-title'));
            final excerpt = find.byKey(const Key('overthinking-share-excerpt'));
            final author = find.byKey(const Key('overthinking-share-author'));
            final musicFinder = find.byKey(
              const Key('overthinking-share-music'),
            );
            expect(tester.widget<Text>(title).maxLines, 3);
            expect(tester.widget<Text>(excerpt).data, data.content);
            expect(tester.widget<Text>(excerpt).maxLines, greaterThan(0));
            expect(
              tester.getRect(excerpt).top,
              greaterThan(tester.getRect(title).bottom),
            );
            expect(
              tester.getRect(excerpt).bottom,
              lessThan(tester.getRect(author).top),
            );
            for (final finder in [title, excerpt, author]) {
              final rect = tester.getRect(finder);
              expect(rect.left, greaterThanOrEqualTo(bounds.left));
              expect(rect.right, lessThanOrEqualTo(bounds.right));
              expect(rect.bottom, lessThan(bounds.bottom));
            }
            expect(musicFinder, music ? findsOneWidget : findsNothing);
            if (music) {
              expect(
                tester.getRect(musicFinder).top,
                greaterThan(tester.getRect(author).bottom),
              );
              expect(
                tester.getRect(musicFinder).bottom,
                lessThan(bounds.bottom - 60),
              );
            }
            expect(
              find.byKey(const Key('overthinking-share-author-image')),
              anonymous ? findsNothing : findsOneWidget,
            );
            expect(
              find.text(anonymous ? 'Anonim yazar' : '@berna'),
              findsOneWidget,
            );
            if (anonymous) expect(find.text('@berna'), findsNothing);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets('missing images and blank body remain honest and bounded', (
    tester,
  ) async {
    _viewport(tester, const Size(800, 1000));
    final data = OverthinkingShareData.fromPost(
      OverthinkingPostModel.fromJson({
        'id': 'source',
        'title': '',
        'content': '  ',
        'anonymous': true,
        'canViewAuthor': true,
        'authorId': 'private',
        'authorUsername': 'should-never-be-exported',
        'spotifyTrackName': 'Bir şarkı',
        'spotifyArtistName': 'Bir sanatçı',
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.navy,
        home: Center(child: OverthinkingShareCard(data: data)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('overthinking-share-excerpt')), findsNothing);
    expect(find.byKey(const Key('overthinking-share-music')), findsOneWidget);
    expect(find.text('Anonim yazar'), findsOneWidget);
    expect(find.textContaining('should-never-be-exported'), findsNothing);
    expect(
      tester.widgetList<Image>(find.byType(Image)).map((image) => image.image),
      everyElement(isNot(isA<NetworkImage>())),
    );
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 568), const Size(640, 320)]) {
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      testWidgets(
        'story targets reachable $size at 2x on $platform',
        (tester) async {
          _viewport(tester, size);
          EventShareTarget? selected;
          final prepared = PreparedOverthinkingShare(
            bytes: _pixel,
            data: _data(),
          );
          await tester.pumpWidget(
            _sheetHarness(
              prepared,
              onSelected: (value) => selected = value,
              textScale: 2,
            ),
          );
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          final image = tester.widget<Image>(
            find.byKey(const Key('overthinking-share-preview')),
          );
          expect((image.image as MemoryImage).bytes, same(prepared.bytes));
          expect(image.semanticLabel, prepared.data.accessibilityDescription);
          expect(find.text('Overthinking’i paylaş'), findsOneWidget);
          expect(find.text('Profilimde paylaş'), findsNothing);
          final target = find.byKey(
            const Key('overthinking-share-target-other'),
          );
          await tester.ensureVisible(target);
          await tester.pumpAndSettle();
          final instagram = find.byKey(
            const Key('overthinking-share-target-instagramStory'),
          );
          expect(
            instagram,
            platform == TargetPlatform.android ? findsOneWidget : findsNothing,
          );
          if (platform == TargetPlatform.android) {
            final stacked = find
                .byKey(const Key('overthinking-share-targets-column'))
                .evaluate()
                .isNotEmpty;
            if (stacked) {
              expect(
                tester.getRect(target).top,
                greaterThan(tester.getRect(instagram).bottom),
              );
            } else {
              expect(
                tester.getSize(instagram).height,
                tester.getSize(target).height,
              );
            }
          }
          expect(tester.takeException(), isNull);
          await tester.tap(target);
          await tester.pumpAndSettle();
          expect(selected, EventShareTarget.other);
          expect(find.byType(OverthinkingShareSheet), findsNothing);
        },
        variant: TargetPlatformVariant({platform}),
      );
    }
  }

  testWidgets('invalidation removes only the covered private preview', (
    tester,
  ) async {
    final validity = ValueNotifier<bool>(true);
    addTearDown(validity.dispose);
    final navigator = GlobalKey<NavigatorState>();
    var completed = false;
    EventShareTarget? selected;
    await tester.pumpWidget(
      _sheetHarness(
        PreparedOverthinkingShare(bytes: _pixel, data: _data()),
        navigator: navigator,
        validity: validity,
        onSelected: (value) {
          completed = true;
          selected = value;
        },
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    navigator.currentState!.push<void>(
      MaterialPageRoute(
        builder: (_) => const Scaffold(body: Text('Unrelated newer screen')),
      ),
    );
    await tester.pumpAndSettle();
    validity.value = false;
    await tester.pumpAndSettle();
    expect(find.text('Unrelated newer screen'), findsOneWidget);
    expect(
      find.byType(OverthinkingShareSheet, skipOffstage: false),
      findsNothing,
    );
    expect(completed, isTrue);
    expect(selected, isNull);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets('source invalidation during an ancestor build is frame-safe', (
    tester,
  ) async {
    final validity = ValueNotifier<bool>(true);
    addTearDown(validity.dispose);
    late StateSetter rebuild;
    var invalidate = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.navy,
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            if (invalidate) validity.value = false;
            return Scaffold(
              body: TextButton(
                child: const Text('Open'),
                onPressed: () => showOverthinkingShareSheet(
                  context,
                  PreparedOverthinkingShare(bytes: _pixel, data: _data()),
                  validityChanges: validity,
                  isValid: () => validity.value,
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    rebuild(() => invalidate = true);
    await tester.pumpAndSettle();
    expect(find.byType(OverthinkingShareSheet), findsNothing);
    expect(find.text('Open'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  if (_preview) {
    for (final anonymous in [false, true]) {
      testWidgets('real-font story preview anonymous=$anonymous', (
        tester,
      ) async {
        _viewport(tester, const Size(360, 640));
        await _loadPreviewFonts(tester);
        final capture = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.navy,
            home: RepaintBoundary(
              key: capture,
              child: OverthinkingShareCard(
                data: _data(anonymous: anonymous, music: !anonymous),
              ),
            ),
          ),
        );
        await _precache(tester);
        expect(tester.takeException(), isNull);
        final name = anonymous ? 'anonymous' : 'public';
        final bytes = await _capture(tester, capture, 'story-$name', ratio: 3);
        final codec = await tester.runAsync(
          () => ui.instantiateImageCodec(bytes),
        );
        final frame = await tester.runAsync(() => codec!.getNextFrame());
        expect(frame!.image.width, 1080);
        expect(frame.image.height, 1920);
        frame.image.dispose();
        codec!.dispose();
      });
    }

    for (final width in [390, 320]) {
      testWidgets(
        'real-font chooser preview width=$width',
        (tester) async {
          _viewport(tester, Size(width.toDouble(), width == 320 ? 568 : 844));
          await _loadPreviewFonts(tester);
          final capture = GlobalKey();
          final bytes = await tester.runAsync(
            () => File(
              'test/goldens/overthinking/story-public.png',
            ).readAsBytes(),
          );
          await tester.pumpWidget(
            RepaintBoundary(
              key: capture,
              child: _sheetHarness(
                PreparedOverthinkingShare(bytes: bytes!, data: _data()),
                textScale: width == 320 ? 1.6 : 1,
                onSelected: (_) {},
              ),
            ),
          );
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          await _precache(tester);
          await _capture(tester, capture, 'story-sheet-$width');
          if (width == 320) {
            await tester.ensureVisible(
              find.byKey(const Key('overthinking-share-target-other')),
            );
            await tester.pumpAndSettle();
            await _capture(tester, capture, 'story-sheet-$width-options');
          }
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.android),
      );
    }
  }
}

OverthinkingShareData _data({
  bool anonymous = false,
  bool music = true,
  bool longCopy = false,
}) => OverthinkingShareData.fromPost(
  OverthinkingPostModel.fromJson({
    'id': 'source',
    'authorId': 'author-id',
    'authorUsername': 'berna',
    'authorAvatarUrl': 'https://example.com/private-avatar.jpg',
    'anonymous': anonymous,
    'canViewAuthor': true,
    'visibilityType': 'VISIBLE',
    'title': longCopy
        ? List.filled(12, 'Bir şarkının içinde 🪩 🌙 👩🏽‍🎤').join('\n')
        : 'Bir şarkının içinde',
    'content': longCopy
        ? List.filled(
            24,
            'Bazen aynı hissi bambaşka hayatlarda taşıyoruz. 🌙',
          ).join('\n\n')
        : 'Bazı şarkılar bir yere götürmüyor insanı. Bir zamana götürüyor.\n\n'
              'Penceresi açık bir odaya, yarım kalmış bir konuşmaya, '
              'adını koyamadığın bir hisse.\n\n'
              'Belki de aynı şarkıda buluşuyoruz, birbirimizden habersiz.',
    if (music) 'spotifyTrackName': 'Beni Sen İnandır',
    if (music) 'spotifyArtistName': 'Pinhani',
    if (music) 'spotifyTrackUrl': 'https://open.spotify.com/track/song',
  }),
);

Widget _sheetHarness(
  PreparedOverthinkingShare prepared, {
  required ValueChanged<EventShareTarget?> onSelected,
  double textScale = 1,
  GlobalKey<NavigatorState>? navigator,
  ValueNotifier<bool>? validity,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  navigatorKey: navigator,
  theme: AppTheme.navy,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: Builder(
    builder: (context) => Scaffold(
      body: TextButton(
        child: const Text('Open'),
        onPressed: () async {
          onSelected(
            await showOverthinkingShareSheet(
              context,
              prepared,
              validityChanges: validity,
              isValid: validity == null ? null : () => validity.value,
            ),
          );
        },
      ),
    ),
  ),
);

void _viewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _loadPreviewFonts(WidgetTester tester) async {
  await tester.runAsync(() async {
    final directory =
        '${File(Platform.resolvedExecutable).parent.parent.parent.path}/material_fonts';
    final loader = FontLoader('Roboto');
    for (final file in [
      'roboto-regular.ttf',
      'roboto-medium.ttf',
      'roboto-bold.ttf',
      'roboto-black.ttf',
    ]) {
      loader.addFont(
        File('$directory/$file').readAsBytes().then(ByteData.sublistView),
      );
    }
    await loader.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader(
          'packages/font_awesome_flutter/FontAwesomeBrands',
        )..addFont(
          rootBundle.load(
            'packages/font_awesome_flutter/lib/fonts/Font-Awesome-7-Brands-Regular-400.otf',
          ),
        ))
        .load();
  });
}

Future<void> _precache(WidgetTester tester) async {
  await tester.runAsync(() async {
    final context = tester.element(find.byType(MaterialApp));
    for (final rendered in tester.widgetList<Image>(find.byType(Image))) {
      if (context.mounted) await precacheImage(rendered.image, context);
    }
  });
  await tester.pumpAndSettle();
}

Future<Uint8List> _capture(
  WidgetTester tester,
  GlobalKey key,
  String name, {
  double ratio = 2,
}) async => (await tester.runAsync(() async {
  final image =
      await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary)
          .toImage(pixelRatio: ratio);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final data = bytes!.buffer.asUint8List();
  final directory = Directory('test/goldens/overthinking');
  await directory.create(recursive: true);
  await File('${directory.path}/$name.png').writeAsBytes(data);
  image.dispose();
  return data;
}))!;
