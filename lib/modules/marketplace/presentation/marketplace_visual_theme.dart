import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/backstage_palette.dart';

/// Shares Backstage's neutral surfaces and the application's brand accents.
/// Route-local styling keeps marketplace controls consistent without changing
/// the appearance of profiles, Collab, or the rest of the application.
class MarketplaceThemeScope extends StatelessWidget {
  const MarketplaceThemeScope({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final dark = base.brightness == Brightness.dark;
    final scheme = dark
        ? base.colorScheme.copyWith(
            primary: AppColors.coralLight,
            onPrimary: BackstagePalette.canvas,
            primaryContainer: BackstagePalette.surfaceRaised,
            onPrimaryContainer: BackstagePalette.textPrimary,
            secondaryContainer: BackstagePalette.surfaceRaised,
            onSecondaryContainer: BackstagePalette.textPrimary,
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
          )
        : base.colorScheme;
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: scheme.outline),
    );
    final scoped = base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: scheme.surfaceContainerHigh,
      dividerColor: scheme.outlineVariant,
      textTheme: base.textTheme.apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: base.textTheme.titleLarge?.fontFamily,
          color: scheme.onSurface,
          fontSize: 19,
          fontWeight: FontWeight.w800,
          letterSpacing: -.4,
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: dark ? BackstagePalette.input : base.colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
        labelStyle: base.textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
          fontSize: 14,
        ),
        hintStyle: base.textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
          fontSize: 14,
        ),
        counterStyle: base.textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
          fontSize: 11,
        ),
        border: fieldBorder,
        enabledBorder: fieldBorder,
        disabledBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: scheme.primary, width: 1.3),
        ),
        errorBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: scheme.error, width: 1.3),
        ),
      ),
      cardTheme: base.cardTheme.copyWith(
        color: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.outline),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: scheme.surfaceContainer,
        selectedColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        labelStyle: TextStyle(
          fontFamily: base.textTheme.labelLarge?.fontFamily,
          color: scheme.onSurfaceVariant,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: TextStyle(
          fontFamily: base.textTheme.labelLarge?.fontFamily,
          color: scheme.onSurface,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        checkmarkColor: scheme.primary,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        side: WidgetStateBorderSide.resolveWith(
          (states) => BorderSide(
            color: states.contains(WidgetState.selected)
                ? scheme.primary.withValues(alpha: .65)
                : scheme.outline,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: base.bottomSheetTheme.copyWith(
        backgroundColor: scheme.surfaceContainer,
        modalBackgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: scheme.outline,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          side: BorderSide(color: scheme.outline),
        ),
      ),
      popupMenuTheme: base.popupMenuTheme.copyWith(
        color: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: base.snackBarTheme.copyWith(
        backgroundColor: scheme.surfaceContainerHigh,
        contentTextStyle: TextStyle(color: scheme.onSurface),
      ),
    );
    return Theme(
      data: scoped,
      child: DecoratedBox(
        decoration: dark
            ? const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    BackstagePalette.canvasTop,
                    BackstagePalette.canvasMid,
                    BackstagePalette.canvasTop,
                  ],
                  stops: [0, .48, 1],
                ),
              )
            : BoxDecoration(color: base.scaffoldBackgroundColor),
        child: child,
      ),
    );
  }
}
