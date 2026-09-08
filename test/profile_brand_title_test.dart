import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/profile_brand_title.dart';

const _logoAsset = 'assets/Logoyanyana.png';
const _targetAppBars = <String, String>{
  'musician owner': 'musician_profile_screen_content.dart',
  'musician public': 'musician_public_profile_screen_content.dart',
  'venue owner': 'venue_profile_screen_content.dart',
  'venue public': 'venue_public_profile_screen_content.dart',
  'band shared owner and public': 'band_profile_screen.dart',
  'studio shared owner and public': 'studio_profile_screen.dart',
  'listener owner': 'listener_profile_screen.dart',
  'listener public': 'listener_public_profile_screen.dart',
};

void main() {
  for (final entry in _targetAppBars.entries) {
    test('${entry.key} AppBar uses the shared profile brand title', () {
      final source = File(
        'lib/modules/profile/presentation/screens/${entry.value}',
      ).readAsStringSync();
      expect(
        RegExp(r'title:\s*const ProfileBrandTitle\(\)').allMatches(source),
        hasLength(1),
        reason: entry.value,
      );
      expect(
        RegExp(
          r"title:\s*GradientText\(\s*text:\s*'SoundConnect'",
        ).hasMatch(source),
        isFalse,
        reason: 'The AppBar must not retain the text-only brand title.',
      );
    });
  }

  testWidgets(
    'uses the original horizontal asset with no tint or text substitute',
    (tester) async {
      await _mount(tester);
      final image = tester.widget<Image>(_brandImage);
      expect(image.image, isA<AssetImage>());
      expect((image.image as AssetImage).assetName, _logoAsset);
      expect(image.fit, BoxFit.fitWidth);
      expect(image.alignment, Alignment.center);
      expect(image.filterQuality, FilterQuality.high);
      expect(image.color, isNull);
      expect(image.semanticLabel, 'SoundConnect');
      expect(find.text('SoundConnect'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(ProfileBrandTitle),
          matching: find.byType(ClipRect),
        ),
        findsOneWidget,
      );
      expect(
        tester.getSize(find.byType(ProfileBrandTitle)),
        const Size(212, 40),
      );
    },
  );

  testWidgets(
    'logo has one accessible SoundConnect label and no false action',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await _mount(tester);
        final logo = find.bySemanticsLabel('SoundConnect');
        expect(logo, findsOneWidget);
        final data = tester.getSemantics(logo).getSemanticsData();
        expect(data.hasAction(ui.SemanticsAction.tap), isFalse);
        expect(find.byTooltip('Back'), findsOneWidget);
        expect(find.byTooltip('Menü'), findsOneWidget);
      } finally {
        semantics.dispose();
      }
    },
  );

  for (final width in [390.0, 320.0, 240.0]) {
    for (final textScale in [1.0, 2.0]) {
      for (final owner in [false, true]) {
        testWidgets(
          'centered AppBar fits at $width px text$textScale owner=$owner',
          (tester) async {
            var backCount = 0;
            var menuCount = 0;
            await _mount(
              tester,
              size: Size(width, 720),
              textScale: textScale,
              owner: owner,
              onBack: () => backCount++,
              onMenu: () => menuCount++,
            );
            final title = tester.getRect(find.byType(ProfileBrandTitle));
            final back = tester.getRect(find.byType(BackButton));
            expect(title.width, lessThanOrEqualTo(212));
            expect(title.width, greaterThan(0));
            expect(title.height, 40);
            expect(
              tester.widget<AppBar>(find.byType(AppBar)).centerTitle,
              isTrue,
            );
            if (width == 390) {
              expect(title.center.dx, closeTo(width / 2, 0.01));
            }
            // Native AppBar shifts a centered title when an asymmetric
            // leading/action slot would otherwise overlap it on narrow views.
            expect(title.right, lessThanOrEqualTo(width));
            expect(title.left, greaterThanOrEqualTo(back.right));
            expect(title.top, greaterThanOrEqualTo(0));
            expect(title.bottom, lessThanOrEqualTo(kToolbarHeight));
            if (owner) {
              final menu = tester.getRect(find.byTooltip('Menü'));
              expect(title.right, lessThanOrEqualTo(menu.left));
              await tester.tap(find.byTooltip('Menü'));
              await tester.pump();
              expect(menuCount, 1);
            } else {
              expect(find.byTooltip('Menü'), findsNothing);
            }
            await tester.tap(find.byType(BackButton));
            await tester.pump();
            expect(backCount, 1);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  for (final availableWidth in [80.0, 140.0, 320.0]) {
    testWidgets(
      'shrinks to parent width $availableWidth without resizing height',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: availableWidth),
                  child: const ProfileBrandTitle(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.getSize(find.byType(ProfileBrandTitle)),
          Size(math.min(212, availableWidth), 40),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  final renderDirectory = Platform.environment['PROFILE_BRAND_RENDER_DIR'];
  if (renderDirectory != null) {
    testWidgets('render real profile logo at normal and narrow AppBar sizes', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      });
      for (final preview in [
        (const Size(390, 180), 1.0, '01-profile-brand-normal.png'),
        (const Size(320, 180), 2.0, '02-profile-brand-narrow-large-text.png'),
      ]) {
        await tester.pumpWidget(const SizedBox.shrink());
        final capture = GlobalKey();
        await _mount(
          tester,
          size: preview.$1,
          textScale: preview.$2,
          capture: capture,
        );
        await tester.runAsync(() async {
          final context = tester.element(find.byType(ProfileBrandTitle));
          for (final image in tester.widgetList<Image>(find.byType(Image))) {
            await precacheImage(image.image, context);
          }
        });
        await tester.pumpAndSettle();
        final boundary =
            capture.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory(renderDirectory).create(recursive: true);
          await File(
            '$renderDirectory/${preview.$3}',
          ).writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
        expect(tester.takeException(), isNull);
      }
    });
  }
}

Finder get _brandImage => find.descendant(
  of: find.byType(ProfileBrandTitle),
  matching: find.byType(Image),
);

Future<void> _mount(
  WidgetTester tester, {
  Size size = const Size(390, 720),
  double textScale = 1,
  bool owner = true,
  VoidCallback? onBack,
  VoidCallback? onMenu,
  GlobalKey? capture,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    RepaintBoundary(
      key: capture,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.navy,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          appBar: AppBar(
            title: const ProfileBrandTitle(),
            centerTitle: true,
            leading: BackButton(onPressed: onBack ?? () {}),
            actions: owner
                ? [
                    IconButton(
                      tooltip: 'Menü',
                      onPressed: onMenu ?? () {},
                      icon: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          'assets/logo.png',
                          width: 34,
                          height: 34,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ]
                : null,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
