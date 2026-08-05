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
          gradient: LinearGradient(colors: AppColors.brandGradient),
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
                  const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                else
                  Icon(icon, size: 18, color: Colors.white),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
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
