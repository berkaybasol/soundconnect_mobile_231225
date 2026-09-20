import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/backstage_palette.dart';

/// Applies SoundConnect's Backstage visual language only to direct messages.
///
/// The scope deliberately leaves brand and semantic colors inherited from the
/// surrounding application theme. Only neutral surfaces, borders, and content
/// colors are remapped, so message state and action colors keep their existing
/// meaning while DM screens can use the premium Backstage surface hierarchy.
class DmVisualThemeScope extends StatelessWidget {
  const DmVisualThemeScope({required this.child, super.key});

  /// Canonical DM page background, exposed for presentation-only descendants
  /// that need to reuse the exact canvas without duplicating color values.
  static const canvasGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      BackstagePalette.canvasTop,
      BackstagePalette.canvasMid,
      BackstagePalette.canvasTop,
    ],
    stops: [0, 0.48, 1],
  );

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    if (base.brightness == Brightness.light) {
      return Theme(
        data: base.copyWith(scaffoldBackgroundColor: Colors.transparent),
        child: DecoratedBox(
          decoration: BoxDecoration(color: base.scaffoldBackgroundColor),
          child: child,
        ),
      );
    }
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: BackstagePalette.border),
    );
    final colorScheme = base.colorScheme.copyWith(
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

    final scopedTheme = base.copyWith(
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: BackstagePalette.surfaceRaised,
      dividerColor: BackstagePalette.border,
      textTheme: base.textTheme.apply(
        bodyColor: BackstagePalette.textPrimary,
        displayColor: BackstagePalette.textPrimary,
      ),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: Colors.transparent,
        foregroundColor: BackstagePalette.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: BackstagePalette.input,
        prefixIconColor: BackstagePalette.textMuted,
        suffixIconColor: BackstagePalette.textMuted,
        labelStyle: const TextStyle(color: BackstagePalette.textMuted),
        hintStyle: const TextStyle(color: BackstagePalette.textMuted),
        border: inputBorder,
        enabledBorder: inputBorder,
        disabledBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: BackstagePalette.divider),
        ),
        focusedBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: AppColors.coralLight),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: colorScheme.error, width: 1.3),
        ),
      ),
      cardTheme: base.cardTheme.copyWith(
        color: BackstagePalette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: BackstagePalette.border),
        ),
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
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(
            BackstagePalette.surfaceRaised,
          ),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          side: const WidgetStatePropertyAll(
            BorderSide(color: BackstagePalette.border),
          ),
        ),
      ),
      snackBarTheme: base.snackBarTheme.copyWith(
        backgroundColor: BackstagePalette.surfaceRaised,
        contentTextStyle: const TextStyle(color: BackstagePalette.textPrimary),
      ),
    );

    return Theme(
      data: scopedTheme,
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: canvasGradient),
        child: child,
      ),
    );
  }
}
