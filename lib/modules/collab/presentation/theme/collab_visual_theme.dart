import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';

/// Collab's intentionally deeper visual hierarchy.
///
/// These colors are local to the module so the shared application theme and
/// the real Backstage bottom navigation keep their existing appearance.
abstract final class CollabPalette {
  static const canvasTop = Color(0xFF030713);
  static const canvas = Color(0xFF050910);
  static const canvasMid = Color(0xFF07101D);
  static const surface = Color(0xFF0B111D);
  static const surfaceRaised = Color(0xFF101722);
  static const input = Color(0xFF070B13);
  static const border = Color(0xFF202B3A);
  static const divider = Color(0xFF151D29);
  static const textPrimary = Color(0xFFEFF2F8);
  static const textMuted = Color(0xFF9EA8B7);
}

class CollabThemeScope extends StatelessWidget {
  const CollabThemeScope({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: CollabPalette.border),
    );
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.coral,
          brightness: Brightness.dark,
        ).copyWith(
          surface: CollabPalette.canvas,
          surfaceDim: CollabPalette.canvasTop,
          surfaceBright: CollabPalette.surfaceRaised,
          surfaceContainerLowest: CollabPalette.canvasTop,
          surfaceContainerLow: CollabPalette.canvas,
          surfaceContainer: CollabPalette.surface,
          surfaceContainerHigh: CollabPalette.surfaceRaised,
          surfaceContainerHighest: CollabPalette.input,
          onSurface: CollabPalette.textPrimary,
          onSurfaceVariant: CollabPalette.textMuted,
          outline: CollabPalette.border,
          outlineVariant: CollabPalette.divider,
        );

    final scopedTheme = base.copyWith(
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: CollabPalette.surfaceRaised,
      dividerColor: CollabPalette.border,
      textTheme: base.textTheme.apply(
        bodyColor: CollabPalette.textPrimary,
        displayColor: CollabPalette.textPrimary,
      ),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: Colors.transparent,
        foregroundColor: CollabPalette.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: CollabPalette.input,
        prefixIconColor: CollabPalette.textMuted,
        suffixIconColor: CollabPalette.textMuted,
        labelStyle: const TextStyle(color: CollabPalette.textMuted),
        hintStyle: const TextStyle(color: CollabPalette.textMuted),
        border: inputBorder,
        enabledBorder: inputBorder,
        disabledBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: CollabPalette.divider),
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
        color: CollabPalette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: CollabPalette.border),
        ),
      ),
      dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: CollabPalette.surfaceRaised,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: base.bottomSheetTheme.copyWith(
        backgroundColor: CollabPalette.surfaceRaised,
        modalBackgroundColor: CollabPalette.surfaceRaised,
        surfaceTintColor: Colors.transparent,
      ),
      popupMenuTheme: base.popupMenuTheme.copyWith(
        color: CollabPalette.surfaceRaised,
        surfaceTintColor: Colors.transparent,
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(
            CollabPalette.surfaceRaised,
          ),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          side: const WidgetStatePropertyAll(
            BorderSide(color: CollabPalette.border),
          ),
        ),
      ),
      snackBarTheme: base.snackBarTheme.copyWith(
        backgroundColor: CollabPalette.surfaceRaised,
        contentTextStyle: const TextStyle(color: CollabPalette.textPrimary),
      ),
    );

    return Theme(
      data: scopedTheme,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              CollabPalette.canvasTop,
              CollabPalette.canvasMid,
              CollabPalette.canvasTop,
            ],
            stops: [0, 0.48, 1],
          ),
        ),
        child: child,
      ),
    );
  }
}

Route<T> collabPageRoute<T>({
  required WidgetBuilder builder,
  RouteSettings? settings,
}) {
  return MaterialPageRoute<T>(
    settings: settings,
    builder: (context) => CollabThemeScope(child: builder(context)),
  );
}
