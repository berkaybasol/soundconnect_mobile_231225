import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/theme/collab_visual_theme.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/presentation/musician_feed_visual_theme.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/backstage_palette.dart';

void main() {
  test('Collab palette remains an exact alias of Backstage neutrals', () {
    expect(CollabPalette.canvasTop, BackstagePalette.canvasTop);
    expect(CollabPalette.canvas, BackstagePalette.canvas);
    expect(CollabPalette.canvasMid, BackstagePalette.canvasMid);
    expect(CollabPalette.surface, BackstagePalette.surface);
    expect(CollabPalette.surfaceRaised, BackstagePalette.surfaceRaised);
    expect(CollabPalette.input, BackstagePalette.input);
    expect(CollabPalette.border, BackstagePalette.border);
    expect(CollabPalette.divider, BackstagePalette.divider);
    expect(CollabPalette.textPrimary, BackstagePalette.textPrimary);
    expect(CollabPalette.textMuted, BackstagePalette.textMuted);
  });

  testWidgets('musician feed theme is scoped and maps every neutral surface', (
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
            return MusicianFeedThemeScope(
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

    final decoratedBox = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(MusicianFeedThemeScope),
        matching: find.byType(DecoratedBox),
      ),
    );
    final decoration = decoratedBox.decoration as BoxDecoration;
    final gradient = decoration.gradient! as LinearGradient;
    expect(gradient.colors, const [
      BackstagePalette.canvasTop,
      BackstagePalette.canvasMid,
      BackstagePalette.canvasTop,
    ]);
    expect(gradient.stops, const [0, 0.48, 1]);
  });
}
