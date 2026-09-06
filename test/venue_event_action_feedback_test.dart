import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/venue_event_action_feedback.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/gradient_outline_button.dart';

void main() {
  Future<void> launch(
    WidgetTester tester, {
    required void Function(bool) onResult,
    bool large = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.navy,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                final result = await confirmVenueEventDeletion(
                  context,
                  large
                      ? 'Şahbaz ile Ankara Açık Hava Sahnesinde Çok Özel Akustik Gece'
                      : 'falanca',
                );
                onResult(result);
              },
              child: const Text('Open'),
            ),
          ),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(large ? 2 : 1)),
          child: child!,
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('cancel does not confirm deletion', (tester) async {
    bool? result;
    await launch(tester, onResult: (value) => result = value);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(GradientOutlineButton), findsOneWidget);
    await tester.tap(find.byKey(const Key('venue-event-delete-cancel')));
    await tester.pumpAndSettle();
    expect(result, isFalse);
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets('repeat confirmation callback resolves once and keeps origin', (
    tester,
  ) async {
    var calls = 0;
    bool? result;
    await launch(
      tester,
      onResult: (value) {
        calls++;
        result = value;
      },
    );
    final button = tester.widget<GradientOutlineButton>(
      find.byKey(const Key('venue-event-delete-confirm')),
    );
    button.onPressed!();
    button.onPressed!();
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(result, isTrue);
    expect(find.text('Open'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long deletion dialog fits 320dp with 200 percent text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    bool? result;
    await launch(tester, large: true, onResult: (value) => result = value);
    expect(tester.takeException(), isNull);
    final cancel = find.byKey(const Key('venue-event-delete-cancel'));
    await tester.ensureVisible(cancel);
    await tester.tap(cancel);
    await tester.pumpAndSettle();
    expect(result, isFalse);
    expect(tester.takeException(), isNull);
  });

  for (final isError in [false, true]) {
    testWidgets(
      'floating feedback uses dark surface and explicit status: $isError',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.navy,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showVenueEventFeedback(
                    context,
                    isError ? 'Etkinlik silinemedi.' : 'Etkinlik silindi.',
                    isError: isError,
                  ),
                  child: const Text('Show'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Show'));
        await tester.pumpAndSettle();
        final snack = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(snack.behavior, SnackBarBehavior.floating);
        expect(
          snack.backgroundColor,
          AppTheme.navy.colorScheme.surfaceContainerHighest,
        );
        expect(
          find.byIcon(
            isError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
