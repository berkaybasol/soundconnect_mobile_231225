import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class BrandGradientIcon extends StatelessWidget {
  const BrandGradientIcon(this.icon, {super.key, this.size, this.semanticLabel})
    : _social = false;

  /// The diagonal orange/pink/purple treatment used by studio profile actions.
  const BrandGradientIcon.social(
    this.icon, {
    super.key,
    this.size,
    this.semanticLabel,
  }) : _social = true;

  final IconData icon;
  final double? size;
  final String? semanticLabel;
  final bool _social;

  static LinearGradient get gradient =>
      LinearGradient(colors: AppColors.decorativeGradient);

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Rebuild palette colors when the theme changes.
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) =>
          (_social
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: AppColors.decorativeSocialGradient,
                    )
                  : gradient)
              .createShader(bounds),
      child: Icon(
        icon,
        size: size,
        color: AppColors.white,
        semanticLabel: semanticLabel,
      ),
    );
  }
}
