import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/dm_visual_theme.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/widgets/dm_visual_components.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/backstage_palette.dart';

void main() {
  testWidgets('DM theme maps Backstage neutrals without leaking its scope', (
    tester,
  ) async {
    late ThemeData outsideTheme;
    late ThemeData insideTheme;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.navy,
        home: Builder(
          builder: (outsideContext) {
            outsideTheme = Theme.of(outsideContext);
            return DmVisualThemeScope(
              child: Builder(
                builder: (insideContext) {
                  insideTheme = Theme.of(insideContext);
                  return const SizedBox.expand();
                },
              ),
            );
          },
        ),
      ),
    );

    final colors = insideTheme.colorScheme;
    expect(colors.surface, BackstagePalette.canvas);
    expect(colors.surfaceDim, BackstagePalette.canvasTop);
    expect(colors.surfaceBright, BackstagePalette.surfaceRaised);
    expect(colors.surfaceContainerLowest, BackstagePalette.canvasTop);
    expect(colors.surfaceContainerLow, BackstagePalette.canvas);
    expect(colors.surfaceContainer, BackstagePalette.surface);
    expect(colors.surfaceContainerHigh, BackstagePalette.surfaceRaised);
    expect(colors.surfaceContainerHighest, BackstagePalette.input);
    expect(colors.onSurface, BackstagePalette.textPrimary);
    expect(colors.onSurfaceVariant, BackstagePalette.textMuted);
    expect(colors.outline, BackstagePalette.border);
    expect(colors.outlineVariant, BackstagePalette.divider);
    expect(insideTheme.scaffoldBackgroundColor, Colors.transparent);
    expect(insideTheme.canvasColor, BackstagePalette.surfaceRaised);
    expect(insideTheme.dividerColor, BackstagePalette.border);

    expect(outsideTheme.colorScheme.surface, AppTheme.navy.colorScheme.surface);
    expect(
      outsideTheme.colorScheme.surfaceContainer,
      AppTheme.navy.colorScheme.surfaceContainer,
    );
  });

  testWidgets('DM theme preserves brand and semantic accents', (tester) async {
    const brandPrimary = Color(0xFF123456);
    const brandSecondary = Color(0xFF654321);
    const semanticError = Color(0xFFDE3344);
    late ColorScheme scopedColors;
    final appTheme = AppTheme.navy.copyWith(
      colorScheme: AppTheme.navy.colorScheme.copyWith(
        primary: brandPrimary,
        secondary: brandSecondary,
        error: semanticError,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: DmVisualThemeScope(
          child: Builder(
            builder: (context) {
              scopedColors = Theme.of(context).colorScheme;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );

    expect(scopedColors.primary, brandPrimary);
    expect(scopedColors.secondary, brandSecondary);
    expect(scopedColors.error, semanticError);
  });

  testWidgets('DM scope paints the canonical Backstage canvas gradient', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.navy,
        home: const DmVisualThemeScope(child: SizedBox.expand()),
      ),
    );

    final decoratedBox = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(DmVisualThemeScope),
        matching: find.byType(DecoratedBox),
      ),
    );
    final decoration = decoratedBox.decoration as BoxDecoration;

    expect(decoration.gradient, same(DmVisualThemeScope.canvasGradient));
    expect(DmVisualThemeScope.canvasGradient.colors, const [
      BackstagePalette.canvasTop,
      BackstagePalette.canvasMid,
      BackstagePalette.canvasTop,
    ]);
    expect(DmVisualThemeScope.canvasGradient.stops, const [0, 0.48, 1]);
  });

  testWidgets('DM header actions keep a 48dp accessible tap target', (
    tester,
  ) async {
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.navy,
        home: DmVisualThemeScope(
          child: Scaffold(
            body: Center(
              child: DmHeaderAction(
                icon: Icons.refresh_rounded,
                tooltip: 'Yenile',
                onPressed: () => taps += 1,
              ),
            ),
          ),
        ),
      ),
    );

    final action = find.byType(InkWell);
    expect(tester.getSize(action), const Size.square(48));
    await tester.tap(action);
    expect(taps, 1);
  });
}
