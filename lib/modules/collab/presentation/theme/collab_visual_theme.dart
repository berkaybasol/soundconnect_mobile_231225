import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/backstage_palette.dart';
import '../collab_access_gate.dart';

/// Compatibility facade for Collab's intentionally deeper visual hierarchy.
///
/// The values alias the shared Backstage neutrals so Collab and the musician
/// feed cannot drift while existing Collab call sites keep their public API.
abstract final class CollabPalette {
  static const canvasTop = BackstagePalette.canvasTop;
  static const canvas = BackstagePalette.canvas;
  static const canvasMid = BackstagePalette.canvasMid;
  static const surface = BackstagePalette.surface;
  static const surfaceRaised = BackstagePalette.surfaceRaised;
  static const input = BackstagePalette.input;
  static const border = BackstagePalette.border;
  static const divider = BackstagePalette.divider;
  static const textPrimary = BackstagePalette.textPrimary;
  static const textMuted = BackstagePalette.textMuted;
}

class CollabThemeScope extends StatelessWidget {
  const CollabThemeScope({required this.child, super.key});

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
  BuildContext? context,
}) {
  final identity = collabAccessIdentityFor(context);
  return MaterialPageRoute<T>(
    settings: settings,
    builder: (context) => CollabThemeScope(
      child: CollabAccessGate(builder: builder, expectedIdentity: identity),
    ),
  );
}
