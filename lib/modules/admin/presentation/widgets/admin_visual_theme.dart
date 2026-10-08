import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/gradient_outline_button.dart';
import '../../../collab/presentation/theme/collab_visual_theme.dart';
import '../../../collab/presentation/widgets/collab_discovery_widgets.dart';

/// Admin shares Collab's surfaces. Controls use explicit brand accents rather
/// than Material's seed-derived brown containers.
class AdminThemeScope extends StatelessWidget {
  const AdminThemeScope({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) => CollabThemeScope(
    child: Builder(
      builder: (context) {
        final base = Theme.of(context);
        final colors = base.colorScheme;
        final accent = AppColors.accentText;
        final selected = colors.surfaceContainerHighest;
        final shape = RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        );
        return Theme(
          data: base.copyWith(
            colorScheme: colors.copyWith(
              primary: accent,
              onPrimary: colors.surface,
              primaryContainer: selected,
              onPrimaryContainer: colors.onSurface,
              secondary: accent,
              onSecondary: colors.surface,
              secondaryContainer: selected,
              onSecondaryContainer: colors.onSurface,
              tertiaryContainer: selected,
              onTertiaryContainer: colors.onSurface,
              surfaceTint: Colors.transparent,
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: colors.onSurface,
                disabledBackgroundColor: Colors.transparent,
                disabledForegroundColor: colors.onSurfaceVariant,
                minimumSize: const Size(48, 50),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
                shape: shape,
              ).copyWith(backgroundBuilder: _adminButtonFrame),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.onSurface,
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                side: BorderSide.none,
                shape: shape,
              ).copyWith(backgroundBuilder: _adminButtonFrame),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: colors.onSurfaceVariant,
                minimumSize: const Size(48, 48),
              ),
            ),
            chipTheme: base.chipTheme.copyWith(
              backgroundColor: colors.surfaceContainer,
              selectedColor: selected,
              disabledColor: colors.surfaceContainer,
              checkmarkColor: accent,
              deleteIconColor: colors.onSurfaceVariant,
              labelStyle: TextStyle(color: colors.onSurface),
              side: BorderSide(color: colors.outline),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
            timePickerTheme: base.timePickerTheme.copyWith(
              backgroundColor: colors.surfaceContainerHigh,
              hourMinuteColor: selected,
              hourMinuteTextColor: colors.onSurface,
              dayPeriodColor: selected,
              dayPeriodTextColor: colors.onSurface,
              dialBackgroundColor: colors.surfaceContainer,
              dialHandColor: accent,
              dialTextColor: colors.onSurface,
              entryModeIconColor: colors.onSurfaceVariant,
            ),
          ),
          child: child,
        );
      },
    ),
  );
}

Widget _adminButtonFrame(
  BuildContext context,
  Set<WidgetState> states,
  Widget? child,
) => GradientOutline(
  radius: 16,
  strokeWidth: 1.4,
  colors: states.contains(WidgetState.disabled)
      ? [Theme.of(context).dividerColor, Theme.of(context).dividerColor]
      : AppColors.decorativeGradient,
  child: child ?? const SizedBox.shrink(),
);

class AdminSectionCard extends StatelessWidget {
  const AdminSectionCard({
    required this.title,
    required this.icon,
    required this.children,
    this.description,
    super.key,
  });
  final String title;
  final IconData icon;
  final String? description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: CollabGradientFrame(
        radius: 22,
        padding: const EdgeInsets.all(18),
        child: Material(
          color: Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(icon, size: 21, color: AppColors.accentText),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              if (description != null) ...[
                const SizedBox(height: 7),
                Text(
                  description!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class AdminBrandButton extends StatelessWidget {
  const AdminBrandButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    super.key,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: onPressed,
    icon: Icon(icon, size: 21),
    label: Text(label, textAlign: TextAlign.center),
  );
}
