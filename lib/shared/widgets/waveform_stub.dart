import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class WaveformStub extends StatelessWidget {
  final List<Color> gradientColors;
  final Color iconColor;
  final Color playIconColor;
  final Color leadingBackgroundColor;
  final Widget? leading;
  final Widget? footer;
  final VoidCallback? onPlay;
  final bool isPlaying;
  final double progress;
  final ValueChanged<double>? onSeek;
  final double height;
  final double waveformHeight;

  const WaveformStub({
    super.key,
    this.gradientColors = AppColors.brandGradient,
    this.iconColor = AppColors.coralAlt,
    this.playIconColor = AppColors.textMuted,
    this.leadingBackgroundColor = AppColors.navBlueSoft,
    this.leading,
    this.footer,
    this.onPlay,
    this.isPlaying = false,
    this.progress = 0,
    this.onSeek,
    this.height = 68,
    this.waveformHeight = 44,
  });

  static const _samples = [
    0.18, 0.32, 0.24, 0.58, 0.4, 0.7, 0.28, 0.82, 0.36,
    0.6, 0.22, 0.76, 0.44, 0.88, 0.3, 0.64, 0.2, 0.72,
    0.52, 0.34, 0.84, 0.26, 0.62, 0.4, 0.78, 0.24, 0.56,
    0.38, 0.86, 0.32, 0.68, 0.22, 0.74, 0.48, 0.9, 0.28,
    0.6, 0.3, 0.8, 0.42, 0.66, 0.2, 0.76, 0.36, 0.58,
    0.26, 0.88, 0.4, 0.7, 0.22, 0.64, 0.34, 0.82, 0.3,
    0.72, 0.24, 0.6, 0.46, 0.78, 0.28, 0.68, 0.38, 0.84,
    0.0, 0.0, 0.0, 0.2, 0.62, 0.32, 0.74, 0.26, 0.56,
    0.4, 0.8, 0.3,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: leadingBackgroundColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Center(
                  child: leading ??
                      Icon(
                        Icons.music_note,
                        size: 16,
                        color: iconColor,
                      ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: SizedBox(
                  height: waveformHeight,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final clampedProgress = progress.clamp(0.0, 1.0);
                      final lineLeft = width * clampedProgress;

                      return GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTapDown: onSeek == null
                            ? null
                            : (details) {
                                final ratio =
                                    details.localPosition.dx / width;
                                onSeek?.call(ratio.clamp(0.0, 1.0));
                              },
                        onHorizontalDragUpdate: onSeek == null
                            ? null
                            : (details) {
                                final ratio =
                                    details.localPosition.dx / width;
                                onSeek?.call(ratio.clamp(0.0, 1.0));
                              },
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CustomPaint(
                              painter: _WaveformPainter(
                                samples: _samples,
                                gradientColors: gradientColors,
                                baseOpacity: 0.35,
                                progress: clampedProgress,
                              ),
                            ),
                            if (progress > 0)
                              Positioned(
                                left: lineLeft.clamp(0.0, width - 1),
                                top: 0,
                                bottom: 0,
                                child: Container(
                                  width: 2,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onPlay,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.navBlueSoft,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 16,
                  color: playIconColor,
                ),
              ),
              ),
            ],
          ),
          if (footer != null) ...[
            const SizedBox(height: 6),
            footer!,
          ],
        ],
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> samples;
  final List<Color> gradientColors;
  final double baseOpacity;
  final double progress;

  const _WaveformPainter({
    required this.samples,
    required this.gradientColors,
    required this.baseOpacity,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty) return;
    final rect = Offset.zero & size;
    final centerY = rect.height / 2;
    final maxAmp = rect.height / 2;
    final barCount = samples.length;
    final gap = 1.5;
    final barWidth =
        ((rect.width - (gap * (barCount - 1))) / barCount).clamp(1.2, 3.0);
    final basePaint = Paint()
      ..isAntiAlias = true
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: gradientColors
            .map((color) => color.withOpacity(baseOpacity))
            .toList(),
      ).createShader(rect)
      ..style = PaintingStyle.fill;
    final progressPaint = Paint()
      ..isAntiAlias = true
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: gradientColors,
      ).createShader(rect)
      ..style = PaintingStyle.fill;
    final progressX = rect.width * progress.clamp(0.0, 1.0);

    double x = rect.left;
    for (var i = 0; i < barCount; i++) {
      final amp = samples[i] * maxAmp;
      final top = centerY - amp;
      final barHeight = amp * 2;
      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, top, barWidth, barHeight),
        const Radius.circular(2),
      );
      canvas.drawRRect(rrect, basePaint);
      final barCenter = x + (barWidth / 2);
      if (barCenter <= progressX) {
        canvas.drawRRect(rrect, progressPaint);
      }
      x += barWidth + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.samples != samples ||
        oldDelegate.baseOpacity != baseOpacity ||
        oldDelegate.progress != progress ||
        oldDelegate.gradientColors != gradientColors;
  }
}
