import 'package:flutter/material.dart';

import '../../../shared/theme/backstage_palette.dart';

/// Shares Backstage's dark neutral surfaces with its profile routes.
/// Brand accents, component geometry, and the light theme stay inherited.
class ProfileVisualThemeScope extends StatelessWidget {
  const ProfileVisualThemeScope({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    // Keep the same widget structure when the theme changes so mounted editors
    // and profile state are preserved.
    return Theme(
      data: base.brightness == Brightness.dark ? _darkTheme(base) : base,
      child: child,
    );
  }

  ThemeData _darkTheme(ThemeData base) {
    final scheme = base.colorScheme.copyWith(
      surface: BackstagePalette.canvas,
      surfaceDim: BackstagePalette.canvasTop,
      surfaceBright: BackstagePalette.surfaceRaised,
      surfaceContainerLowest: BackstagePalette.canvasTop,
      surfaceContainerLow: BackstagePalette.canvas,
      surfaceContainer: BackstagePalette.surface,
      surfaceContainerHigh: BackstagePalette.surfaceRaised,
      surfaceContainerHighest: BackstagePalette.input,
      onSurface: BackstagePalette.textPrimary,
      onSurfaceVariant: BackstagePalette.textMuted,
      outline: BackstagePalette.border,
      outlineVariant: BackstagePalette.divider,
    );
    final inputs = base.inputDecorationTheme;
    InputBorder? neutralBorder(InputBorder? border) => border?.copyWith(
      borderSide: border.borderSide.copyWith(color: scheme.outline),
    );
    final cardShape = base.cardTheme.shape;

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: BackstagePalette.canvas,
      canvasColor: BackstagePalette.surfaceRaised,
      cardColor: BackstagePalette.surface,
      dividerColor: BackstagePalette.divider,
      textTheme: base.textTheme.apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ),
      appBarTheme: base.appBarTheme.copyWith(
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: inputs.copyWith(
        fillColor: BackstagePalette.input,
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
        labelStyle: inputs.labelStyle?.copyWith(color: scheme.onSurfaceVariant),
        hintStyle: inputs.hintStyle?.copyWith(color: scheme.onSurfaceVariant),
        border: neutralBorder(inputs.border),
        enabledBorder: neutralBorder(inputs.enabledBorder),
        disabledBorder: neutralBorder(inputs.disabledBorder),
      ),
      cardTheme: base.cardTheme.copyWith(
        color: BackstagePalette.surface,
        surfaceTintColor: Colors.transparent,
        shape: cardShape is OutlinedBorder
            ? cardShape.copyWith(
                side: cardShape.side.copyWith(color: scheme.outline),
              )
            : cardShape,
      ),
      dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: BackstagePalette.surfaceRaised,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: base.bottomSheetTheme.copyWith(
        backgroundColor: BackstagePalette.surface,
        modalBackgroundColor: BackstagePalette.surface,
        surfaceTintColor: Colors.transparent,
      ),
      popupMenuTheme: base.popupMenuTheme.copyWith(
        color: BackstagePalette.surfaceRaised,
        surfaceTintColor: Colors.transparent,
      ),
      dropdownMenuTheme: base.dropdownMenuTheme.copyWith(
        menuStyle: (base.dropdownMenuTheme.menuStyle ?? const MenuStyle())
            .copyWith(
              backgroundColor: const WidgetStatePropertyAll(
                BackstagePalette.surfaceRaised,
              ),
              side: WidgetStatePropertyAll(BorderSide(color: scheme.outline)),
            ),
      ),
    );
  }
}
