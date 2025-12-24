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
    final borderRadius = BorderRadius.circular(18);
    final isEnabled = onPressed != null;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: isEnabled
            ? [
                BoxShadow(
                  color: const Color(0xFF9B5DE5).withOpacity(0.16),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
        gradient: const LinearGradient(
          colors: [
            Color(0xFF7B2FF7),
            Color(0xFF9B5DE5),
            Color(0xFFC65BF0),
            Color(0xFFF26CA7),
            Color(0xFFFF7AA2),
            Color(0xFFB66DFF),
            Color(0xFF7B2FF7),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(0.7),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: Container(
            color: AppColors.inputFill,
            child: TextButton(
              onPressed: onPressed,
              style: TextButton.styleFrom(
                foregroundColor:
                    isEnabled ? AppColors.textPrimary : AppColors.textMuted,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
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
