import 'package:flutter/material.dart';
import '../../../../shared/widgets/gradient_outline_button.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../tablegroup/presentation/widgets/table_group_overview_style.dart';

export '../../../tablegroup/presentation/widgets/table_group_overview_style.dart';

abstract final class OverthinkingPalette {
  // Use the same source of truth as the TableGroup overview, including its
  // backdrop, card depth and warm typography. No separate module palette.
  static const background = TableGroupOverviewStyle.pageBase;
  static const surface = TableGroupOverviewStyle.cardTop;
  static const surfaceRaised = TableGroupOverviewStyle.insetTop;
  static const border = TableGroupOverviewStyle.cardBorder;
  static const text = TableGroupOverviewStyle.primaryText;
  static const muted = TableGroupOverviewStyle.bodyMuted;
  static const accent = TableGroupOverviewStyle.warmHeading;
  static const lilac = TableGroupOverviewStyle.headingMuted;

  static ThemeData theme(BuildContext context) {
    final base = Theme.of(context);
    return base.copyWith(
      scaffoldBackgroundColor: background,
      dividerColor: border,
      colorScheme: base.colorScheme.copyWith(
        brightness: Brightness.dark,
        primary: AppColors.gradientC,
        onPrimary: AppColors.white,
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
          backgroundColor: TableGroupOverviewStyle.cardTop,
          foregroundColor: TableGroupOverviewStyle.primaryText,
          minimumSize: const Size(48, 48),
          textStyle: base.textTheme.labelLarge?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: TableGroupOverviewStyle.cardBorder),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
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
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      gradient: TableGroupOverviewStyle.cardGradient,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: TableGroupOverviewStyle.cardBorder),
      boxShadow: TableGroupOverviewStyle.cardShadows,
    ),
    child: Material(
      color: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(12),
      child: Padding(padding: padding, child: child),
    ),
  );
}

class OverthinkingEyebrow extends StatelessWidget {
  const OverthinkingEyebrow(
    this.text, {
    super.key,
    this.color = OverthinkingPalette.muted,
  });
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      color: color,
      fontSize: 13,
      fontWeight: FontWeight.w700,
      letterSpacing: .1,
    ),
  );
}

class OverthinkingBrandIcon extends StatelessWidget {
  const OverthinkingBrandIcon(this.icon, {super.key, this.size = 24});
  final IconData icon;
  final double size;
  @override
  Widget build(BuildContext context) => ShaderMask(
    shaderCallback: (bounds) => const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: TableGroupOverviewStyle.brandGradient,
    ).createShader(bounds),
    blendMode: BlendMode.srcIn,
    child: Icon(icon, size: size, color: AppColors.white),
  );
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
  Widget build(BuildContext context) => GradientOutlineButton(
    onPressed: onPressed,
    loading: busy,
    backgroundColor: TableGroupOverviewStyle.insetTop,
    strokeWidth: .7,
    leading: Icon(icon, size: 20),
    maxLines: null,
    label: label,
  );
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
  Widget build(BuildContext context) => Padding(
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
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            color: OverthinkingPalette.text,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
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
