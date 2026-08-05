import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class BrandGradientIcon extends StatelessWidget {
  const BrandGradientIcon(
    this.icon, {
    super.key,
    this.size,
    this.semanticLabel,
  });

  final IconData icon;
  final double? size;
  final String? semanticLabel;

  static LinearGradient get gradient =>
      LinearGradient(colors: AppColors.brandGradient);

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => gradient.createShader(bounds),
      child: Icon(
        icon,
        size: size,
        color: AppColors.white,
        semanticLabel: semanticLabel,
      ),
    );
  }
}
