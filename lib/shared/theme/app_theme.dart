import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static const _pageTransitionsTheme = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: _FadeSlidePageTransitionsBuilder(),
      TargetPlatform.iOS: _FadeSlidePageTransitionsBuilder(),
      TargetPlatform.macOS: _FadeSlidePageTransitionsBuilder(),
      TargetPlatform.windows: _FadeSlidePageTransitionsBuilder(),
      TargetPlatform.linux: _FadeSlidePageTransitionsBuilder(),
      TargetPlatform.fuchsia: _FadeSlidePageTransitionsBuilder(),
    },
  );

  static ButtonStyle _interactiveButtonStyle({
    required Color foreground,
    required Color pressedOverlay,
  }) {
    return ButtonStyle(
      foregroundColor: WidgetStatePropertyAll(foreground),
      animationDuration: const Duration(milliseconds: 110),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) return pressedOverlay;
        if (states.contains(WidgetState.hovered)) {
          return pressedOverlay.withValues(alpha: 0.08);
        }
        return null;
      }),
    );
  }

  static ThemeData get navy {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.coral,
          brightness: Brightness.dark,
        ).copyWith(
          surface: AppColors.navBlueDeep,
          surfaceContainer: AppColors.navBlueSoft,
          surfaceContainerHighest: AppColors.inputFill,
          outline: AppColors.border,
          onSurfaceVariant: AppColors.textMuted,
        );
    final theme = ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      pageTransitionsTheme: _pageTransitionsTheme,
      splashFactory: InkRipple.splashFactory,
      splashColor: AppColors.coral.withValues(alpha: 0.18),
      highlightColor: AppColors.coralLight.withValues(alpha: 0.10),
      scaffoldBackgroundColor: AppColors.navBlueDeep,
      textTheme: ThemeData(brightness: Brightness.dark).textTheme.copyWith(
        headlineMedium: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        bodyMedium: TextStyle(color: AppColors.textMuted),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputFill,
        prefixIconColor: AppColors.textMuted,
        suffixIconColor: AppColors.textMuted,
        labelStyle: TextStyle(color: AppColors.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.coralLight),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style:
            ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              backgroundColor: AppColors.coralAlt,
              foregroundColor: AppColors.white,
            ).copyWith(
              animationDuration: const Duration(milliseconds: 110),
              overlayColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.pressed)) {
                  return AppColors.white.withValues(alpha: 0.18);
                }
                return null;
              }),
            ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: _interactiveButtonStyle(
          foreground: AppColors.textPrimary,
          pressedOverlay: AppColors.white.withValues(alpha: 0.18),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _interactiveButtonStyle(
          foreground: AppColors.textPrimary,
          pressedOverlay: AppColors.white.withValues(alpha: 0.14),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          animationDuration: const Duration(milliseconds: 110),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return AppColors.white.withValues(alpha: 0.18);
            }
            return null;
          }),
        ),
      ),
      dividerColor: AppColors.border,
    );
    return _withSurfaceStyles(
      theme,
      cardColor: AppColors.navBlueSoft,
      menuColor: AppColors.inputFill,
      borderColor: AppColors.border,
    );
  }

  static ThemeData _withSurfaceStyles(
    ThemeData theme, {
    required Color cardColor,
    required Color menuColor,
    required Color borderColor,
  }) {
    return theme.copyWith(
      dividerColor: borderColor,
      cardTheme: CardThemeData(
        color: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: borderColor),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: menuColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(menuColor),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          side: WidgetStatePropertyAll(BorderSide(color: borderColor)),
        ),
      ),
    );
  }
}

class _FadeSlidePageTransitionsBuilder extends PageTransitionsBuilder {
  const _FadeSlidePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return FadeTransition(
      opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curved),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.02, 0.0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
