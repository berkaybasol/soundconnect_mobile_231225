import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A compact, non-interactive identity marker for listener ghost profiles.
///
/// Callers render this for a ghost-safe contextual identity. Missing legacy
/// visibility remains standard, while unknown non-null values fail closed to
/// ghost at the shared parser boundary.
class GhostProfileBadge extends StatelessWidget {
  const GhostProfileBadge({
    super.key,
    this.compact = true,
    this.showLabel = true,
  });

  final bool compact;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Rebuild palette colors when the theme changes.
    final iconSize = compact ? 11.0 : 13.0;
    final horizontalPadding = showLabel ? (compact ? 7.0 : 9.0) : 5.0;
    final borderRadius = BorderRadius.circular(999);

    return Semantics(
      label: 'Hayalet profil',
      container: true,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            // Keep the identity marker legible on content and neutral surfaces.
            color: AppColors.isLight
                ? AppColors.avatarBackground
                : const Color(0xFF21182D),
            borderRadius: borderRadius,
            border: Border.all(
              color: AppColors.isLight
                  ? AppColors.decorativeGradient[3]
                  : const Color(0xFFC96BE8),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: compact ? 3 : 4,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (bounds) => LinearGradient(
                    colors: AppColors.decorativeGradient,
                  ).createShader(bounds),
                  child: Icon(Icons.visibility_off_outlined, size: iconSize),
                ),
                if (showLabel) ...[
                  SizedBox(width: compact ? 4 : 5),
                  Flexible(
                    child: Text(
                      'HAYALET PROFİL',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.isLight
                            ? AppColors.textPrimary
                            : const Color(0xFFF7EFFF),
                        fontSize: compact ? 8.5 : 10,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: compact ? 0.35 : 0.45,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
