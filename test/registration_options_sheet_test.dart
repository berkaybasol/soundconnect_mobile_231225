import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/presentation/widgets/registration_options_sheet.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';

const _sheetKey = Key('registration-options-sheet');
const _googleKey = Key('registration-google-unavailable');
const _emailKey = Key('registration-email-continue');

void main() {
  testWidgets(
    'offers email and clearly unavailable Google without navigating',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final host = await _mount(tester);
        openRegistrationOptions(host.context);
        await tester.pumpAndSettle();
        expect(find.byKey(_sheetKey), findsOneWidget);
        expect(find.text('Üye ol'), findsOneWidget);
        expect(find.text('Google ile devam et'), findsOneWidget);
        expect(find.text('Yakında'), findsOneWidget);
        expect(find.text('E-posta ile devam et'), findsOneWidget);
        expect(find.byType(TextField), findsNothing);
        expect(host.routes, isEmpty);
        final google = find.byKey(_googleKey);
        expect(tester.widget<OutlinedButton>(google).onPressed, isNull);
        final googleSemantics = tester.getSemantics(google).getSemanticsData();
        expect(
          googleSemantics.hasFlag(ui.SemanticsFlag.hasEnabledState),
          isTrue,
        );
        expect(googleSemantics.hasFlag(ui.SemanticsFlag.isEnabled), isFalse);
        expect(googleSemantics.hasAction(ui.SemanticsAction.tap), isFalse);
        for (final button in tester.widgetList<ButtonStyleButton>(
          find.descendant(of: google, matching: find.byType(ButtonStyleButton)),
        )) {
          expect(button.onPressed, isNull);
        }
        for (final ink in tester.widgetList<InkWell>(
          find.descendant(of: google, matching: find.byType(InkWell)),
        )) {
          expect(ink.onTap, isNull);
        }
        await tester.tap(google);
        await tester.pumpAndSettle();
        expect(find.byKey(_sheetKey), findsOneWidget);
        expect(host.routes, isEmpty);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('email continues through the existing registration route once', (
    tester,
  ) async {
    final host = await _mount(tester);
    openRegistrationOptions(host.context);
    await tester.pumpAndSettle();
    final callback = _emailCallback(tester);
    callback();
    callback();
    await tester.pumpAndSettle();
    expect(host.routes.map((route) => route.name), [AppRoutes.register]);
    expect(host.routes.single.arguments, isNull);
    expect(find.text('REGISTER DESTINATION'), findsOneWidget);
    expect(find.byKey(_sheetKey), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('REGISTRATION HOST'), findsOneWidget);
    openRegistrationOptions(host.context);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_emailKey));
    await tester.pumpAndSettle();
    expect(host.routes.map((route) => route.name), [
      AppRoutes.register,
      AppRoutes.register,
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('concurrent open requests do not stack option sheets', (
    tester,
  ) async {
    final host = await _mount(tester);
    openRegistrationOptions(host.context);
    openRegistrationOptions(host.context);
    await tester.pumpAndSettle();
    expect(find.byKey(_sheetKey, skipOffstage: false), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(_sheetKey, skipOffstage: false), findsNothing);
    expect(find.text('REGISTRATION HOST'), findsOneWidget);
    expect(host.routes, isEmpty);
  });

  testWidgets('stale email callback after back dismissal cannot register', (
    tester,
  ) async {
    final host = await _mount(tester);
    openRegistrationOptions(host.context);
    await tester.pumpAndSettle();
    final callback = _emailCallback(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(callback, returnsNormally);
    await tester.pumpAndSettle();
    expect(host.routes, isEmpty);
    expect(find.text('REGISTRATION HOST'), findsOneWidget);
  });

  for (final dismiss in ['back', 'barrier', 'close']) {
    testWidgets('$dismiss dismissal does not register and allows reopening', (
      tester,
    ) async {
      final host = await _mount(tester);
      var completed = false;
      openRegistrationOptions(host.context).then((_) => completed = true);
      await tester.pumpAndSettle();
      if (dismiss == 'back') {
        await tester.binding.handlePopRoute();
      } else if (dismiss == 'close') {
        await tester.tap(find.byTooltip('Kapat'));
      } else {
        await tester.tapAt(const Offset(8, 8));
      }
      await tester.pumpAndSettle();
      expect(completed, isTrue);
      expect(find.byKey(_sheetKey), findsNothing);
      expect(host.routes, isEmpty);
      openRegistrationOptions(host.context);
      await tester.pumpAndSettle();
      expect(find.byKey(_sheetKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in [const Size(320, 720), const Size(320, 500)]) {
    testWidgets('options remain usable at $size with 200 percent text', (
      tester,
    ) async {
      final host = await _mount(tester, size: size, textScale: 2);
      openRegistrationOptions(host.context);
      await tester.pumpAndSettle();
      for (final key in [_googleKey, _emailKey]) {
        final control = find.byKey(key);
        await tester.ensureVisible(control);
        await tester.pumpAndSettle();
        final rect = tester.getRect(control);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(size.width));
        expect(rect.height, greaterThanOrEqualTo(44));
        expect(tester.takeException(), isNull);
      }
      await tester.tap(find.byKey(_emailKey));
      await tester.pumpAndSettle();
      expect(find.text('REGISTER DESTINATION'), findsOneWidget);
      expect(host.routes.length, 1);
      expect(tester.takeException(), isNull);
    });
  }

  final renderDirectory =
      Platform.environment['REGISTRATION_OPTIONS_RENDER_DIR'];
  if (renderDirectory != null) {
    testWidgets('render registration choices with actual fonts', (
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
      for (final preview in [
        (const Size(390, 844), 1.0, '01-registration-options.png'),
        (const Size(320, 720), 2.0, '02-registration-options-large-text.png'),
      ]) {
        await tester.pumpWidget(const SizedBox.shrink());
        final capture = GlobalKey();
        final host = await _mount(
          tester,
          capture: capture,
          size: preview.$1,
          textScale: preview.$2,
        );
        openRegistrationOptions(host.context);
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          for (final image in tester.widgetList<Image>(find.byType(Image))) {
            await precacheImage(image.image, host.context);
          }
        });
        await tester.pumpAndSettle();
        final boundary =
            capture.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory(renderDirectory).create(recursive: true);
          await File(
            '$renderDirectory/${preview.$3}',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        expect(tester.takeException(), isNull);
      }
    });
  }
}

VoidCallback _emailCallback(WidgetTester tester) {
  final keyed = find.byKey(_emailKey);
  final widget = tester.widget(keyed);
  if (widget is ButtonStyleButton) return widget.onPressed!;
  if (widget is InkWell) return widget.onTap!;
  return tester
      .widget<InkWell>(
        find.descendant(of: keyed, matching: find.byType(InkWell)).first,
      )
      .onTap!;
}

class _Host {
  late BuildContext context;
  final routes = <RouteSettings>[];
}

Future<_Host> _mount(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double textScale = 1,
  GlobalKey? capture,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final host = _Host();
  await tester.pumpWidget(
    RepaintBoundary(
      key: capture,
      child: MaterialApp(
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
        onGenerateRoute: (settings) {
          host.routes.add(settings);
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const Scaffold(body: Text('REGISTER DESTINATION')),
          );
        },
        home: Builder(
          builder: (context) {
            host.context = context;
            return Scaffold(
              body: capture == null
                  ? const Center(child: Text('REGISTRATION HOST'))
                  : null,
            );
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return host;
}
