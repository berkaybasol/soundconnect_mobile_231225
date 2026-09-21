import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';

/// Scoped surfaces for Müzik Birleştirir. The legacy style below is also used
/// by Overthinking and profile share artwork, which keep their own appearance.
class TableGroupSurfaceStyle {
  TableGroupSurfaceStyle.of(BuildContext context) : _theme = Theme.of(context);

  final ThemeData _theme;
  bool get _dark => _theme.brightness == Brightness.dark;
  ColorScheme get _colors => _theme.colorScheme;

  Color get pageBase =>
      _dark ? _theme.scaffoldBackgroundColor : TableGroupOverviewStyle.pageBase;
  Color get pageDeep => _dark ? pageBase : TableGroupOverviewStyle.pageDeep;
  Color get cardTop =>
      _dark ? _colors.surfaceContainer : TableGroupOverviewStyle.cardTop;
  Color get cardBottom => _dark
      ? Color.lerp(cardTop, pageBase, .45)!
      : TableGroupOverviewStyle.cardBottom;
  Color get cardBorder =>
      _dark ? _colors.outline : TableGroupOverviewStyle.cardBorder;
  Color get insetTop => _dark
      ? _colors.surfaceContainerHighest
      : TableGroupOverviewStyle.insetTop;
  Color get insetBottom =>
      _dark ? insetTop : TableGroupOverviewStyle.insetBottom;
  Color get insetBorder =>
      _dark ? _colors.outlineVariant : TableGroupOverviewStyle.insetBorder;
  Color get primaryText =>
      _dark ? _colors.onSurface : TableGroupOverviewStyle.primaryText;
  Color get warmHeading =>
      _dark ? _colors.onSurface : TableGroupOverviewStyle.warmHeading;
  Color get headingMuted =>
      _dark ? _colors.onSurfaceVariant : TableGroupOverviewStyle.headingMuted;
  Color get bodyMuted =>
      _dark ? _colors.onSurfaceVariant : TableGroupOverviewStyle.bodyMuted;
  Color get tertiaryText =>
      _dark ? _colors.onSurfaceVariant : TableGroupOverviewStyle.tertiaryText;
  Color get divider =>
      _dark ? _colors.outlineVariant : TableGroupOverviewStyle.divider;
  List<Color> get brandGradient => TableGroupOverviewStyle.brandGradient;
  List<Color> get decorativeGradient =>
      TableGroupOverviewStyle.decorativeGradient;
  LinearGradient get cardGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [cardTop, cardBottom],
  );
  LinearGradient get insetGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [insetTop, insetBottom],
  );
  List<BoxShadow> get cardShadows => _dark
      ? const [
          BoxShadow(
            color: Color(0x4D000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ]
      : TableGroupOverviewStyle.cardShadows;
}

class TableGroupSurfaceBackdrop extends StatelessWidget {
  const TableGroupSurfaceBackdrop({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      TableGroupOverviewBackdrop(useAppSurfaces: true, child: child);
}

/// Visual language shared by the public table list and detail overview.
///
/// The original navy values remain unchanged; light mode resolves the same
/// hierarchy through the application palette.
abstract final class TableGroupOverviewStyle {
  static const unspecifiedVenueLabel = 'Belirtilmemiş';

  static Color get pageBase => AppColors.isOriginalDark
      ? const Color(0xFF07101D)
      : AppColors.navBlueDeep;
  static Color get pageDeep => AppColors.isOriginalDark
      ? const Color(0xFF060D18)
      : AppColors.navBlueDeep;
  static Color get cardTop =>
      AppColors.isOriginalDark ? const Color(0xFF0D1725) : AppColors.navBlue;
  static Color get cardBottom =>
      AppColors.isOriginalDark ? const Color(0xFF09121F) : AppColors.inputFill;
  static Color get cardBorder =>
      AppColors.isOriginalDark ? const Color(0xFF26364B) : AppColors.border;
  static Color get insetTop =>
      AppColors.isOriginalDark ? const Color(0xFF07101B) : AppColors.inputFill;
  static Color get insetBottom => AppColors.isOriginalDark
      ? const Color(0xFF050B14)
      : AppColors.navBlueSoft;
  static Color get insetBorder =>
      AppColors.isOriginalDark ? const Color(0xFF1C2A3D) : AppColors.border;
  static Color get primaryText => AppColors.isOriginalDark
      ? const Color(0xFFF5F2F4)
      : AppColors.textPrimary;
  static Color get warmHeading => AppColors.isOriginalDark
      ? const Color(0xFFF4E5E6)
      : AppColors.textPrimary;
  static Color get headingMuted =>
      AppColors.isOriginalDark ? const Color(0xFFBAC7DC) : AppColors.textMuted;
  static Color get bodyMuted =>
      AppColors.isOriginalDark ? const Color(0xFFA8B5C9) : AppColors.textMuted;
  static Color get tertiaryText =>
      AppColors.isOriginalDark ? const Color(0xFF8795AA) : AppColors.textMuted;
  static Color get divider =>
      AppColors.isOriginalDark ? const Color(0xFF223147) : AppColors.border;

  static List<Color> get brandGradient => AppColors.isOriginalDark
      ? const <Color>[Color(0xFFFF6A5F), Color(0xFFF45591), Color(0xFFC34CFF)]
      : AppColors.brandGradient;

  static List<Color> get decorativeGradient =>
      AppColors.isOriginalDark ? brandGradient : AppColors.decorativeGradient;

  static LinearGradient get cardGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[cardTop, cardBottom],
  );

  static LinearGradient get insetGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[insetTop, insetBottom],
  );

  static List<BoxShadow> get cardShadows => AppColors.isOriginalDark
      ? const <BoxShadow>[
          BoxShadow(
            color: Color(0x4D000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
          BoxShadow(
            color: Color(0x122A6AA4),
            blurRadius: 28,
            spreadRadius: -6,
            offset: Offset(0, 8),
          ),
        ]
      : const <BoxShadow>[
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ];
}

class TableGroupOverviewBackdrop extends StatelessWidget {
  const TableGroupOverviewBackdrop({
    super.key,
    required this.child,
    this.useAppSurfaces = false,
  });

  final Widget child;
  final bool useAppSurfaces;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final useDarkSurfaces =
        useAppSurfaces && theme.brightness == Brightness.dark;
    // Keep the same child structure when brightness changes so open forms,
    // scroll positions and chat focus survive the palette switch.
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: useDarkSurfaces
                  ? List<Color>.filled(3, theme.scaffoldBackgroundColor)
                  : <Color>[
                      TableGroupOverviewStyle.pageBase,
                      (AppColors.isOriginalDark
                          ? const Color(0xFF07111F)
                          : AppColors.navBlueDeep),
                      TableGroupOverviewStyle.pageDeep,
                    ],
              stops: <double>[0, 0.48, 1],
            ),
          ),
        ),
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.65, -0.72),
                radius: 1.05,
                colors: useDarkSurfaces
                    ? const [Colors.transparent, Colors.transparent]
                    : const <Color>[Color(0x29183B61), Color(0x00060D18)],
                stops: <double>[0, 1],
              ),
            ),
          ),
        ),
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.95, 0.15),
                radius: 0.9,
                colors: useDarkSurfaces
                    ? const [Colors.transparent, Colors.transparent]
                    : const <Color>[Color(0x18123151), Color(0x00060D18)],
                stops: <double>[0, 1],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
