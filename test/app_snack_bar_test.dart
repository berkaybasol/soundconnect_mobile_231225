import 'dart:ui' show SemanticsAction, SemanticsFlag;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/app_snack_bar.dart';

void main() {
  Future<BuildContext> launch(
    WidgetTester tester, {
    ThemeData? theme,
    double textScale = 1,
    double bottomInset = 0,
    EdgeInsets safePadding = const EdgeInsets.only(bottom: 24),
    bool accessibleNavigation = false,
  }) async {
    late BuildContext host;
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? AppTheme.navy,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            padding: safePadding,
            viewInsets: EdgeInsets.only(bottom: bottomInset),
            accessibleNavigation: accessibleNavigation,
          ),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              host = context;
              return const SizedBox.expand();
            },
          ),
          bottomNavigationBar: const SizedBox(height: 56),
        ),
      ),
    );
    return host;
  }

  final themes = {
    'light': AppTheme.light,
    'navy': AppTheme.navy,
    'black': AppTheme.black,
  };
  final icons = {
    AppSnackBarTone.success: Icons.check_circle_outline_rounded,
    AppSnackBarTone.error: Icons.error_outline_rounded,
    AppSnackBarTone.warning: Icons.warning_amber_rounded,
    AppSnackBarTone.info: Icons.info_outline_rounded,
  };

  for (final theme in themes.entries) {
    for (final tone in icons.entries) {
      testWidgets('${theme.key} ${tone.key.name} feedback remains readable', (
        tester,
      ) async {
        final context = await launch(tester, theme: theme.value);
        ScaffoldMessenger.of(context).showSnackBar(
          appSnackBar(
            context,
            content: const Text('İşlem sonucu'),
            tone: tone.key,
          ),
        );
        await tester.pumpAndSettle();

        final snack = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(snack.behavior, SnackBarBehavior.floating);
        expect(
          snack.backgroundColor,
          theme.value.colorScheme.surfaceContainerHighest,
        );
        expect(snack.elevation, 0);
        expect(snack.margin, const EdgeInsets.fromLTRB(20, 12, 20, 18));
        final shape = snack.shape! as RoundedRectangleBorder;
        expect(shape.borderRadius, BorderRadius.circular(16));
        expect(find.byIcon(tone.value), findsOneWidget);
        final textContext = tester.element(find.text('İşlem sonucu'));
        expect(
          DefaultTextStyle.of(textContext).style.color,
          theme.value.colorScheme.onSurface,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('default lifetime and action persistence match native SnackBar', (
    tester,
  ) async {
    final context = await launch(tester);
    for (final action in <SnackBarAction?>[
      null,
      SnackBarAction(label: 'Geri Al', onPressed: () {}),
    ]) {
      final native = SnackBar(content: const Text('Mesaj'), action: action);
      final feedback = appSnackBar(
        context,
        content: const Text('Mesaj'),
        tone: AppSnackBarTone.success,
        action: action,
      );
      expect(feedback.duration, native.duration);
      expect(feedback.persist, native.persist);
      expect(feedback.dismissDirection, native.dismissDirection);
      if (action != null) {
        ScaffoldMessenger.of(context).showSnackBar(feedback);
        await tester.pumpAndSettle();
        final renderedAction = tester.widget<SnackBarAction>(
          find.byType(SnackBarAction),
        );
        expect(renderedAction.onPressed, same(action.onPressed));
      }
    }
  });

  testWidgets('custom duration times out and advances the existing queue', (
    tester,
  ) async {
    final context = await launch(tester);
    final messenger = ScaffoldMessenger.of(context);
    SnackBarClosedReason? reason;
    messenger
        .showSnackBar(
          appSnackBar(
            context,
            content: const Text('İlk mesaj'),
            tone: AppSnackBarTone.warning,
            duration: const Duration(seconds: 2),
          ),
        )
        .closed
        .then((value) => reason = value);
    messenger.showSnackBar(
      appSnackBar(
        context,
        content: const Text('İkinci mesaj'),
        tone: AppSnackBarTone.info,
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1900));
    expect(find.text('İlk mesaj'), findsOneWidget);
    expect(find.text('İkinci mesaj'), findsNothing);
    await tester.pump(const Duration(milliseconds: 101));
    await tester.pumpAndSettle();
    expect(reason, SnackBarClosedReason.timeout);
    expect(find.text('İkinci mesaj'), findsOneWidget);
  });

  testWidgets('long feedback fits above the keyboard with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final context = await launch(tester, textScale: 2, bottomInset: 180);
    const message =
        'Video işleme beklenenden uzun sürdü. Biraz sonra tekrar kontrol et.';
    ScaffoldMessenger.of(context).showSnackBar(
      appSnackBar(
        context,
        content: const Text(message),
        tone: AppSnackBarTone.warning,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(message), findsOneWidget);
    expect(tester.takeException(), isNull);
    final rect = tester.getRect(find.byType(SnackBar));
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThanOrEqualTo(620));
  });

  testWidgets('persistent action fits after window resize and advances queue', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final context = await launch(tester, textScale: 2);
    final messenger = ScaffoldMessenger.of(context);
    const margin = EdgeInsetsDirectional.fromSTEB(24, 12, 32, 96);
    var calls = 0;
    SnackBarClosedReason? reason;
    messenger
        .showSnackBar(
          appSnackBar(
            context,
            content: const Text('İşlem tamamlanamadı.'),
            tone: AppSnackBarTone.error,
            margin: margin,
            action: SnackBarAction(
              label: 'Tekrar Dene',
              onPressed: () => calls++,
            ),
          ),
        )
        .closed
        .then((value) => reason = value);
    messenger.showSnackBar(
      appSnackBar(
        context,
        content: const Text('Sıradaki mesaj'),
        tone: AppSnackBarTone.info,
      ),
    );
    await tester.pumpAndSettle();

    tester.view.physicalSize = const Size(320, 800);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    expect(tester.takeException(), isNull);
    expect(reason, isNull);
    expect(find.text('Sıradaki mesaj'), findsNothing);
    expect(tester.widget<SnackBar>(find.byType(SnackBar)).margin, margin);
    final action = find.byType(SnackBarAction);
    final rect = tester.getRect(action);
    expect(rect.left, greaterThanOrEqualTo(24));
    expect(rect.right, lessThanOrEqualTo(288));
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThanOrEqualTo(744));

    await tester.tap(find.text('Tekrar Dene'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(reason, SnackBarClosedReason.action);
    expect(find.text('Sıradaki mesaj'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final label in ['Geri Al', 'Tekrar Dene']) {
    testWidgets('$label fits 320dp at 200% text and fires once', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final context = await launch(tester, textScale: 2);
      var calls = 0;
      SnackBarClosedReason? reason;
      ScaffoldMessenger.of(context)
          .showSnackBar(
            appSnackBar(
              context,
              content: Text(
                label == 'Geri Al'
                    ? 'Fotoğraf kaldırıldı.'
                    : 'Profil henüz yüklenemedi; tekrar dene.',
              ),
              tone: AppSnackBarTone.error,
              action: SnackBarAction(label: label, onPressed: () => calls++),
            ),
          )
          .closed
          .then((value) => reason = value);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final rect = tester.getRect(find.byType(SnackBar));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(320));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(744));

      final button = tester.widget<TextButton>(
        find.descendant(
          of: find.byType(SnackBarAction),
          matching: find.byType(TextButton),
        ),
      );
      button.onPressed!();
      button.onPressed!();
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(reason, SnackBarClosedReason.action);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('retry action stays inside lateral safe areas at doubled text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final context = await launch(
      tester,
      textScale: 2,
      safePadding: const EdgeInsets.fromLTRB(44, 0, 44, 24),
    );
    var calls = 0;
    ScaffoldMessenger.of(context).showSnackBar(
      appSnackBar(
        context,
        content: const Text('Profil yüklenemedi.'),
        tone: AppSnackBarTone.error,
        action: SnackBarAction(label: 'Tekrar Dene', onPressed: () => calls++),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final action = find.byType(SnackBarAction);
    final rect = tester.getRect(action);
    expect(rect.left, greaterThanOrEqualTo(64));
    expect(rect.right, lessThanOrEqualTo(256));
    await tester.tap(find.text('Tekrar Dene'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile retry remains reachable in compact landscape at 200%', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(560, 280);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final context = await launch(tester, textScale: 2);
    var calls = 0;
    ScaffoldMessenger.of(context).showSnackBar(
      appSnackBar(
        context,
        content: const Text('Profil henüz yüklenemedi; tekrar dene.'),
        tone: AppSnackBarTone.error,
        action: SnackBarAction(label: 'Tekrar Dene', onPressed: () => calls++),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final rect = tester.getRect(find.byType(SnackBar));
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThanOrEqualTo(224));
    await tester.tap(find.text('Tekrar Dene'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long keyboard-landscape feedback scrolls without hiding retry', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(560, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final context = await launch(tester, textScale: 2, bottomInset: 120);
    final message = List.filled(20, 'İşlem tamamlanamadı.').join(' ');
    var calls = 0;
    ScaffoldMessenger.of(context).showSnackBar(
      appSnackBar(
        context,
        content: Text(message),
        tone: AppSnackBarTone.error,
        action: SnackBarAction(label: 'Tekrar Dene', onPressed: () => calls++),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final retry = find.widgetWithText(TextButton, 'Tekrar Dene');
    final actionRect = tester.getRect(retry);
    expect(actionRect.top, greaterThanOrEqualTo(0));
    expect(actionRect.bottom, lessThanOrEqualTo(280));
    final scroll = find.descendant(
      of: find.byType(SnackBar),
      matching: find.byType(Scrollable),
    );
    final scrollState = tester.state<ScrollableState>(scroll);
    expect(scrollState.position.maxScrollExtent, greaterThan(0));
    await tester.drag(scroll, const Offset(0, -180));
    await tester.pumpAndSettle();
    expect(scrollState.position.pixels, greaterThan(0));
    expect(tester.getRect(retry), actionRect);
    expect(tester.widget<Text>(find.text(message)).data, message);

    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('accessible native action remains labelled and persistent', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final context = await launch(tester, accessibleNavigation: true);
      var calls = 0;
      SnackBarClosedReason? reason;
      ScaffoldMessenger.of(context)
          .showSnackBar(
            appSnackBar(
              context,
              content: const Text('Profil yüklenemedi.'),
              tone: AppSnackBarTone.error,
              action: SnackBarAction(
                label: 'Tekrar Dene',
                onPressed: () => calls++,
              ),
            ),
          )
          .closed
          .then((value) => reason = value);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(minutes: 1));
      final button = find.widgetWithText(TextButton, 'Tekrar Dene');
      final data = tester.getSemantics(button).getSemanticsData();
      expect(data.label, 'Tekrar Dene');
      expect(data.hasFlag(SemanticsFlag.isButton), isTrue);
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      expect(reason, isNull);

      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(reason, SnackBarClosedReason.action);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('swiping persistent action advances queue without invoking it', (
    tester,
  ) async {
    final context = await launch(tester);
    final messenger = ScaffoldMessenger.of(context);
    var calls = 0;
    SnackBarClosedReason? reason;
    messenger
        .showSnackBar(
          appSnackBar(
            context,
            content: const Text('Fotoğraf kaldırıldı.'),
            tone: AppSnackBarTone.success,
            action: SnackBarAction(label: 'Geri Al', onPressed: () => calls++),
          ),
        )
        .closed
        .then((value) => reason = value);
    messenger.showSnackBar(
      appSnackBar(
        context,
        content: const Text('Sıradaki bildirim'),
        tone: AppSnackBarTone.info,
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(SnackBar), const Offset(0, 500));
    await tester.pumpAndSettle();

    expect(reason, SnackBarClosedReason.swipe);
    expect(calls, 0);
    expect(find.text('Sıradaki bildirim'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Escape follows native SnackBar dismissal behavior', (
    tester,
  ) async {
    final context = await launch(tester);
    final messenger = ScaffoldMessenger.of(context);
    final outcomes = <SnackBarClosedReason?>[];
    for (final shared in [false, true]) {
      SnackBarClosedReason? reason;
      final action = SnackBarAction(label: 'Geri Al', onPressed: () {});
      messenger
          .showSnackBar(
            shared
                ? appSnackBar(
                    context,
                    content: const Text('Fotoğraf kaldırıldı.'),
                    tone: AppSnackBarTone.success,
                    action: action,
                  )
                : SnackBar(
                    content: const Text('Fotoğraf kaldırıldı.'),
                    action: action,
                  ),
          )
          .closed
          .then((value) => reason = value);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      outcomes.add(reason);
      messenger.removeCurrentSnackBar();
      await tester.pumpAndSettle();
    }
    expect(outcomes.last, outcomes.first);
    expect(tester.takeException(), isNull);
  });
}
