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
      LinearGradient(colors: AppColors.brandGradient);

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) =>
          (_social
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: AppColors.socialGradient,
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
