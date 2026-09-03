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
    final iconSize = compact ? 11.0 : 13.0;
    final horizontalPadding = showLabel ? (compact ? 7.0 : 9.0) : 5.0;
    final borderRadius = BorderRadius.circular(999);

    return Semantics(
      label: 'Hayalet profil',
      container: true,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            // Context-independent colors are intentional: this identity badge
            // appears on light, navy and black surfaces throughout the app.
            color: const Color(0xFF21182D),
            borderRadius: borderRadius,
            border: Border.all(color: const Color(0xFFC96BE8)),
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
                    colors: AppColors.brandGradient,
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
                        color: const Color(0xFFF7EFFF),
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
