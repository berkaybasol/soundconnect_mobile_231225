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

  static ThemeData get current => AppColors.isLight ? light : navy;

  static ThemeData get navy => _navy;
  static final ThemeData _navy = _buildNavy();

  static ThemeData _buildNavy() {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.originalDark.coral,
          brightness: Brightness.dark,
        ).copyWith(
          surface: AppColors.originalDark.navBlueDeep,
          surfaceContainer: AppColors.originalDark.navBlueSoft,
          surfaceContainerHighest: AppColors.originalDark.inputFill,
          outline: AppColors.originalDark.border,
          onSurfaceVariant: AppColors.originalDark.textMuted,
        );
    final theme = ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      pageTransitionsTheme: _pageTransitionsTheme,
      splashFactory: InkRipple.splashFactory,
      splashColor: AppColors.originalDark.coral.withValues(alpha: 0.18),
      highlightColor: AppColors.originalDark.coralLight.withValues(alpha: 0.10),
      scaffoldBackgroundColor: AppColors.originalDark.navBlueDeep,
      textTheme: ThemeData(brightness: Brightness.dark).textTheme.copyWith(
        headlineMedium: TextStyle(
          color: AppColors.originalDark.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        bodyMedium: TextStyle(color: AppColors.originalDark.textMuted),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.originalDark.textPrimary,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.originalDark.inputFill,
        prefixIconColor: AppColors.originalDark.textMuted,
        suffixIconColor: AppColors.originalDark.textMuted,
        labelStyle: TextStyle(color: AppColors.originalDark.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.originalDark.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.originalDark.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.originalDark.coralLight),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style:
            ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              backgroundColor: AppColors.originalDark.coralAlt,
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
          foreground: AppColors.originalDark.textPrimary,
          pressedOverlay: AppColors.white.withValues(alpha: 0.18),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _interactiveButtonStyle(
          foreground: AppColors.originalDark.textPrimary,
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
      dividerColor: AppColors.originalDark.border,
    );
    return _withSurfaceStyles(
      theme,
      cardColor: AppColors.originalDark.navBlueSoft,
      menuColor: AppColors.originalDark.inputFill,
      borderColor: AppColors.originalDark.border,
    );
  }

  static ThemeData get light => _light;
  static final ThemeData _light = _buildLight();

  static ThemeData _buildLight() {
    final colors = AppColors.lightPalette;
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: colors.coral,
          brightness: Brightness.light,
        ).copyWith(
          primary: colors.coralAlt,
          onPrimary: colors.textPrimary,
          primaryContainer: AppColors.lightAvatarBackground,
          onPrimaryContainer: AppColors.lightAvatarForeground,
          secondary: colors.brandGradient.last,
          onSecondary: colors.textPrimary,
          surface: colors.navBlue,
          onSurface: colors.textPrimary,
          surfaceContainerLowest: colors.navBlue,
          surfaceContainerLow: colors.navBlueDeep,
          surfaceContainer: colors.navBlueSoft,
          surfaceContainerHigh: colors.navBlueSoft,
          surfaceContainerHighest: colors.inputFill,
          outline: colors.border,
          onSurfaceVariant: colors.textMuted,
        );
    final theme = ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      pageTransitionsTheme: _pageTransitionsTheme,
      splashFactory: InkRipple.splashFactory,
      splashColor: colors.coral.withValues(alpha: 0.18),
      highlightColor: colors.coralLight.withValues(alpha: 0.10),
      scaffoldBackgroundColor: colors.navBlueDeep,
      textTheme: ThemeData(brightness: Brightness.light).textTheme
          .apply(
            bodyColor: colors.textPrimary,
            displayColor: colors.textPrimary,
          )
          .copyWith(
            headlineMedium: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
            bodyMedium: TextStyle(color: colors.textMuted),
          ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: colors.textPrimary,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.inputFill,
        prefixIconColor: colors.textMuted,
        suffixIconColor: colors.textMuted,
        labelStyle: TextStyle(color: colors.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colors.coralLight),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style:
            ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              backgroundColor: colors.coralAlt,
              foregroundColor: colors.textPrimary,
            ).copyWith(
              animationDuration: const Duration(milliseconds: 110),
              overlayColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.pressed)
                    ? AppColors.white.withValues(alpha: 0.18)
                    : null,
              ),
            ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: _interactiveButtonStyle(
          foreground: colors.textPrimary,
          pressedOverlay: colors.textPrimary.withValues(alpha: 0.18),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _interactiveButtonStyle(
          foreground: colors.textPrimary,
          pressedOverlay: colors.textPrimary.withValues(alpha: 0.14),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          animationDuration: const Duration(milliseconds: 110),
          overlayColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.pressed)
                ? colors.textPrimary.withValues(alpha: 0.18)
                : null,
          ),
        ),
      ),
      dividerColor: colors.border,
    );
    return _withSurfaceStyles(
      theme,
      cardColor: colors.navBlue,
      menuColor: colors.navBlue,
      borderColor: colors.border,
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
