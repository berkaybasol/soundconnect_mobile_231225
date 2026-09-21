import 'package:flutter/material.dart';
import '../../../../shared/widgets/gradient_outline_button.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_surface_theme.dart';
import '../../../../shared/theme/backstage_palette.dart';
import '../../../tablegroup/presentation/widgets/table_group_overview_style.dart';

export '../../../tablegroup/presentation/widgets/table_group_overview_style.dart';

abstract final class OverthinkingPalette {
  // Keep the established light palette while adopting the shared dark neutrals.
  static Color get background => AppColors.isOriginalDark
      ? BackstagePalette.canvas
      : TableGroupOverviewStyle.pageBase;
  static Color get surface => AppColors.isOriginalDark
      ? BackstagePalette.surface
      : TableGroupOverviewStyle.cardTop;
  static Color get surfaceRaised => AppColors.isOriginalDark
      ? BackstagePalette.input
      : TableGroupOverviewStyle.insetTop;
  static Color get border => AppColors.isOriginalDark
      ? BackstagePalette.border
      : TableGroupOverviewStyle.cardBorder;
  static Color get text => AppColors.isOriginalDark
      ? BackstagePalette.textPrimary
      : TableGroupOverviewStyle.primaryText;
  static Color get muted => AppColors.isOriginalDark
      ? BackstagePalette.textMuted
      : TableGroupOverviewStyle.bodyMuted;
  static Color get accent => AppColors.isOriginalDark
      ? BackstagePalette.textPrimary
      : TableGroupOverviewStyle.warmHeading;
  static Color get lilac => AppColors.isOriginalDark
      ? BackstagePalette.textMuted
      : TableGroupOverviewStyle.headingMuted;

  static ThemeData theme(BuildContext context) {
    final base = Theme.of(context);
    final themed = base.copyWith(
      scaffoldBackgroundColor: background,
      dividerColor: border,
      colorScheme: base.colorScheme.copyWith(
        brightness: base.brightness,
        primary: AppColors.gradientC,
        onPrimary: AppColors.onAccent,
        secondary: AppColors.brandGradient.last,
        surface: surface,
        onSurface: text,
        onSurfaceVariant: muted,
        surfaceContainer: surfaceRaised,
        surfaceContainerHighest: surfaceRaised,
        outline: border,
      ),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: background,
        foregroundColor: text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      textTheme: base.textTheme.apply(bodyColor: text, displayColor: text),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: surface,
          foregroundColor: text,
          minimumSize: const Size(48, 48),
          textStyle: base.textTheme.labelLarge?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
          shape: RoundedRectangleBorder(
            side: BorderSide(color: border),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
    return base.brightness == Brightness.dark
        ? appSurfaceTheme(themed)
        : themed;
  }
}

/// Place above stateful screens so callbacks and modal routes inherit the same
/// surfaces as the visible content. The Theme wrapper stays stable on switches.
class OverthinkingThemeScope extends StatelessWidget {
  const OverthinkingThemeScope({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Theme(data: OverthinkingPalette.theme(context), child: child);
}

class OverthinkingSurface extends StatelessWidget {
  const OverthinkingSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: TableGroupSurfaceStyle.of(context).cardGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: TableGroupSurfaceStyle.of(context).cardBorder,
        ),
        boxShadow: TableGroupSurfaceStyle.of(context).cardShadows,
      ),
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(12),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class OverthinkingEyebrow extends StatelessWidget {
  const OverthinkingEyebrow(this.text, {super.key, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Text(
      text,
      style: TextStyle(
        color: color ?? OverthinkingPalette.muted,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: .1,
      ),
    );
  }
}

class OverthinkingBrandIcon extends StatelessWidget {
  const OverthinkingBrandIcon(this.icon, {super.key, this.size = 24});
  final IconData icon;
  final double size;
  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: TableGroupSurfaceStyle.of(context).decorativeGradient,
      ).createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: Icon(icon, size: size, color: AppColors.white),
    );
  }
}

class OverthinkingPrimaryAction extends StatelessWidget {
  const OverthinkingPrimaryAction({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.busy = false,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool busy;
  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return GradientOutlineButton(
      onPressed: onPressed,
      loading: busy,
      backgroundColor: TableGroupSurfaceStyle.of(context).insetTop,
      strokeWidth: .7,
      leading: Icon(icon, size: 20),
      maxLines: null,
      label: label,
    );
  }
}

class OverthinkingEmptyState extends StatelessWidget {
  const OverthinkingEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 40),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: OverthinkingPalette.surfaceRaised,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(icon, color: OverthinkingPalette.lilac, size: 30),
          ),
          const SizedBox(height: 22),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: OverthinkingPalette.text,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: OverthinkingPalette.muted,
              height: 1.6,
              fontSize: 14,
            ),
          ),
          if (action != null) ...[const SizedBox(height: 22), action!],
        ],
      ),
    );
  }
}
