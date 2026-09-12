import 'package:flutter/material.dart';

import '../../../shared/theme/backstage_palette.dart';

/// Applies Backstage neutrals only inside a musician's profile route.
///
/// The surrounding app theme, other profile types and all semantic brand
/// accents stay unchanged. Removing this scope restores the previous palette.
class MusicianProfileThemeScope extends StatelessWidget {
  const MusicianProfileThemeScope({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final colors = base.colorScheme.copyWith(
      brightness: Brightness.dark,
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
    final theme = base.copyWith(
      brightness: Brightness.dark,
      colorScheme: colors,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: BackstagePalette.surfaceRaised,
      dividerColor: BackstagePalette.border,
      textTheme: base.textTheme.apply(
        bodyColor: BackstagePalette.textPrimary,
        displayColor: BackstagePalette.textPrimary,
      ),
      appBarTheme: base.appBarTheme.copyWith(
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: inputs.copyWith(
        fillColor: BackstagePalette.input,
        prefixIconColor: BackstagePalette.textMuted,
        suffixIconColor: BackstagePalette.textMuted,
        labelStyle: inputs.labelStyle?.copyWith(
          color: BackstagePalette.textMuted,
        ),
        hintStyle: (inputs.hintStyle ?? const TextStyle()).copyWith(
          color: BackstagePalette.textMuted,
        ),
        border: _neutralBorder(inputs.border),
        enabledBorder: _neutralBorder(inputs.enabledBorder),
        disabledBorder: _neutralBorder(
          inputs.disabledBorder,
          color: BackstagePalette.divider,
        ),
      ),
      cardTheme: base.cardTheme.copyWith(
        color: BackstagePalette.surface,
        surfaceTintColor: Colors.transparent,
        shape: switch (base.cardTheme.shape) {
          final OutlinedBorder shape => shape.copyWith(
            side: const BorderSide(color: BackstagePalette.border),
          ),
          final shape => shape,
        },
      ),
      dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: BackstagePalette.surfaceRaised,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: base.bottomSheetTheme.copyWith(
        backgroundColor: BackstagePalette.surfaceRaised,
        modalBackgroundColor: BackstagePalette.surfaceRaised,
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
              surfaceTintColor: const WidgetStatePropertyAll(
                Colors.transparent,
              ),
              side: const WidgetStatePropertyAll(
                BorderSide(color: BackstagePalette.border),
              ),
            ),
      ),
      snackBarTheme: base.snackBarTheme.copyWith(
        backgroundColor: BackstagePalette.surfaceRaised,
        contentTextStyle:
            (base.snackBarTheme.contentTextStyle ?? const TextStyle()).copyWith(
              color: BackstagePalette.textPrimary,
            ),
      ),
    );

    return _MusicianProfileBaseTheme(
      data: base,
      child: Theme(
        data: theme,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                BackstagePalette.canvasTop,
                BackstagePalette.canvasMid,
                BackstagePalette.canvasTop,
              ],
              stops: [0, 0.48, 1],
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  InputBorder? _neutralBorder(
    InputBorder? border, {
    Color color = BackstagePalette.border,
  }) => border?.copyWith(borderSide: border.borderSide.copyWith(color: color));
}

/// Keeps existing navigation chrome outside the profile's visual experiment.
class MusicianProfileChromeScope extends StatelessWidget {
  const MusicianProfileChromeScope({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final original = context
        .dependOnInheritedWidgetOfExactType<_MusicianProfileBaseTheme>();
    return original == null ? child : Theme(data: original.data, child: child);
  }
}

class _MusicianProfileBaseTheme extends InheritedWidget {
  const _MusicianProfileBaseTheme({required this.data, required super.child});

  final ThemeData data;

  @override
  bool updateShouldNotify(_MusicianProfileBaseTheme oldWidget) =>
      data != oldWidget.data;
}
