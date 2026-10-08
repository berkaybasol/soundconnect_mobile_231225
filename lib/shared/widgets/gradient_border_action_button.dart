import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class GradientBorderActionButton extends StatelessWidget {
  const GradientBorderActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.loading = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final ink = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;
    const borderRadius = BorderRadius.all(Radius.circular(8));
    const innerRadius = BorderRadius.all(Radius.circular(7.3));
    final enabled = onPressed != null && !loading;

    return AnimatedOpacity(
      opacity: enabled ? 1 : 0.58,
      duration: const Duration(milliseconds: 160),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          gradient: LinearGradient(colors: AppColors.decorativeGradient),
        ),
        padding: const EdgeInsets.all(0.7),
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: innerRadius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (loading)
                  SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: ink,
                    ),
                  )
                else
                  Icon(icon, size: 18, color: ink),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
