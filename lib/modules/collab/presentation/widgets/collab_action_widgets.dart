import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/gradient_outline_button.dart';
import 'collab_discovery_widgets.dart';

class CollabPrimaryAction extends StatelessWidget {
  const CollabPrimaryAction({
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Rebuild palette colors when the theme changes.
    final enabled = onPressed != null && !busy;
    final ink = AppColors.isOriginalDark || enabled
        ? AppColors.onAccent
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final child = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(17),
        child: SizedBox(
          height: 54,
          child: Center(
            child: busy
                ? SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: ink,
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, color: ink, size: 21),
                          const SizedBox(width: 9),
                        ],
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: ink,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
    if (AppColors.isLight) {
      return GradientOutline(
        radius: 17,
        colors: enabled
            ? AppColors.decorativeGradient
            : [Theme.of(context).dividerColor, Theme.of(context).dividerColor],
        child: child,
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: enabled
              ? AppColors.actionGradient
              : [
                  Theme.of(context).disabledColor.withValues(alpha: 0.45),
                  Theme.of(context).disabledColor.withValues(alpha: 0.28),
                ],
        ),
        borderRadius: BorderRadius.circular(17),
      ),
      child: child,
    );
  }
}

class CollabOutlineAction extends StatelessWidget {
  const CollabOutlineAction({
    required this.label,
    required this.onPressed,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(16),
      child: CollabGradientFrame(
        highlighted: onPressed != null,
        radius: 16,
        strokeWidth: 1.15,
        child: SizedBox(
          height: 50,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: 19,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CollabSectionTitle extends StatelessWidget {
  const CollabSectionTitle(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: 17,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}
