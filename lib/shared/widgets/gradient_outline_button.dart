import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class GradientOutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const GradientOutlineButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fillColor = theme.colorScheme.surfaceContainerHighest;
    final enabledTextColor = theme.colorScheme.onSurface;
    final disabledTextColor = theme.colorScheme.onSurfaceVariant;
    final borderRadius = BorderRadius.circular(18);
    final isEnabled = onPressed != null;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: isEnabled
            ? [
                BoxShadow(
                  color: AppColors.neonPurpleGradient[1].withValues(
                    alpha: 0.16,
                  ),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
        gradient: LinearGradient(
          colors: [
            AppColors.neonPurpleGradient[0],
            AppColors.neonPurpleGradient[1],
            AppColors.neonPurpleGradient[2],
            AppColors.neonPurpleGradient[3],
            AppColors.neonPurpleGradient[4],
            AppColors.neonPurpleGradient[5],
            AppColors.neonPurpleGradient[0],
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(0.7),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: Container(
            color: fillColor,
            child: TextButton(
              onPressed: onPressed,
              style: TextButton.styleFrom(
                foregroundColor: isEnabled
                    ? enabledTextColor
                    : disabledTextColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(borderRadius: borderRadius),
                backgroundColor: Colors.transparent,
              ),
              child: Text(label),
            ),
          ),
        ),
      ),
    );
  }
}
