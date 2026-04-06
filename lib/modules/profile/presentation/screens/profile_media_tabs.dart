import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';

class ProfileMediaTabs extends StatelessWidget {
  final List<Widget> tabs;

  const ProfileMediaTabs({super.key, required this.tabs});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TabBar(
        labelColor: AppColors.textPrimary,
        unselectedLabelColor: AppColors.textMuted,
        indicator: const _GradientTabIndicator(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: AppColors.brandGradient,
          ),
          thickness: 2,
          horizontalInset: 0,
        ),
        labelPadding: const EdgeInsets.symmetric(horizontal: 6),
        tabs: tabs,
      ),
    );
  }
}

class _GradientTabIndicator extends Decoration {
  final LinearGradient gradient;
  final double thickness;
  final double horizontalInset;

  const _GradientTabIndicator({
    required this.gradient,
    this.thickness = 2,
    this.horizontalInset = 0,
  });

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _GradientTabIndicatorPainter(
      gradient: gradient,
      thickness: thickness,
      horizontalInset: horizontalInset,
    );
  }
}

class _GradientTabIndicatorPainter extends BoxPainter {
  final LinearGradient gradient;
  final double thickness;
  final double horizontalInset;

  _GradientTabIndicatorPainter({
    required this.gradient,
    required this.thickness,
    required this.horizontalInset,
  });

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null) return;

    final left = offset.dx + horizontalInset;
    final right = offset.dx + size.width - horizontalInset;
    final top = offset.dy + size.height - thickness;
    final rect = Rect.fromLTRB(left, top, right, top + thickness);
    final paint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(thickness)),
      paint,
    );
  }
}
