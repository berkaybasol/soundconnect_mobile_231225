import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A static, locally drawn cover with the bundled SoundConnect emblem.
/// No animation or image download is needed at any card size.
class EventPosterFallback extends StatelessWidget {
  final String title;
  final String? dateLabel;
  final bool showDetails;

  const EventPosterFallback({
    super.key,
    required this.title,
    this.dateLabel,
    this.showDetails = false,
  });

  @override
  Widget build(BuildContext context) {
    final displayTitle = title.trim().isEmpty ? 'Etkinlik' : title.trim();
    return Semantics(
      image: true,
      label: '$displayTitle için etkinlik afişi',
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final geometry = _EventPosterGeometry(constraints.biggest);
              final emblemSize = geometry.radius * 0.84;
              final emblemPixels =
                  (emblemSize * MediaQuery.devicePixelRatioOf(context))
                      .ceil()
                      .clamp(1, 512);
              final textScaler = MediaQuery.textScalerOf(context);
              final hasDate = dateLabel?.trim().isNotEmpty == true;
              final detailsHeight =
                  constraints.maxHeight -
                  26 -
                  (geometry.center.dy + geometry.radius * 0.4);
              final titleLines =
                  ((detailsHeight -
                              16 -
                              (hasDate ? 10 + textScaler.scale(12) * 1.2 : 0)) /
                          (textScaler.scale(25) * 1.1))
                      .floor()
                      .clamp(0, 3);
              final details =
                  showDetails &&
                  constraints.maxWidth >= 160 &&
                  constraints.maxHeight >= 200 &&
                  titleLines > 0;
              return ClipRect(
                child: CustomPaint(
                  painter: const _EventPosterPainter(),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned(
                        left: geometry.center.dx - emblemSize / 2,
                        top: geometry.center.dy - emblemSize / 2,
                        width: emblemSize,
                        height: emblemSize,
                        child: Image.asset(
                          'assets/logo.png',
                          fit: BoxFit.contain,
                          cacheWidth: emblemPixels,
                          cacheHeight: emblemPixels,
                          filterQuality: FilterQuality.medium,
                          excludeFromSemantics: true,
                        ),
                      ),
                      if (details)
                        Positioned(
                          top: 24,
                          left: 24,
                          child: const Text(
                            'SOUNDCONNECT',
                            textScaler: TextScaler.noScaling,
                            style: TextStyle(
                              color: Color(0xBFE9EAF3),
                              fontSize: 8,
                              letterSpacing: 2.3,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      if (details)
                        Positioned(
                          left: 24,
                          right: 24,
                          bottom: 26,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 32,
                                height: 2,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: AppColors.brandGradient,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                displayTitle,
                                maxLines: titleLines,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 25,
                                  fontWeight: FontWeight.w800,
                                  height: 1.1,
                                  letterSpacing: -0.6,
                                ),
                              ),
                              if (hasDate) ...[
                                const SizedBox(height: 10),
                                Text(
                                  dateLabel!.trim(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xBFE9EAF3),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _EventPosterGeometry {
  final Offset center;
  final double radius;

  _EventPosterGeometry(Size size)
    : center = Offset(
        size.width * (size.width < 120 ? 0.55 : 0.69),
        size.height * (size.width < 120 ? 0.46 : 0.43),
      ),
      radius = math.min(size.width * 0.62, size.height * 0.57);
}

class _EventPosterPainter extends CustomPainter {
  const _EventPosterPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF202337), Color(0xFF0C1322), Color(0xFF17172B)],
        ).createShader(rect),
    );

    final compact = size.width < 120;
    final geometry = _EventPosterGeometry(size);
    final center = geometry.center;
    final radius = geometry.radius;
    final disc = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius * 1.45,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.brandGradient.last.withValues(alpha: 0.16),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius * 1.45)),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF292A40), Color(0xFF101625), Color(0xFF202033)],
        ).createShader(disc),
    );
    final groove = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;
    for (var i = 0; i < 8; i++) {
      groove.color = AppColors.white.withValues(alpha: i.isEven ? 0.08 : 0.035);
      canvas.drawCircle(center, radius * (0.46 + i * 0.073), groove);
    }
    final accent = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = compact ? 1.3 : 1.7
      ..shader = LinearGradient(
        colors: AppColors.brandGradient,
      ).createShader(disc);
    canvas.drawArc(
      disc.deflate(radius * 0.025),
      math.pi * 0.98,
      math.pi * 0.66,
      false,
      accent,
    );
    canvas.drawArc(
      disc.deflate(radius * 0.18),
      math.pi * 0.02,
      math.pi * 0.33,
      false,
      accent..strokeWidth = 0.8,
    );
    canvas.drawCircle(
      center,
      radius * 0.32,
      Paint()..color = const Color(0xFF171B2C),
    );
    // Fine registration lines add structure without texture assets or blur.
    final line = Paint()
      ..color = AppColors.white.withValues(alpha: 0.055)
      ..strokeWidth = 0.7;
    canvas.drawLine(
      Offset(size.width * 0.08, size.height * 0.82),
      Offset(size.width * 0.92, size.height * 0.82),
      line,
    );
    canvas.drawLine(
      Offset(size.width * 0.88, 0),
      Offset(size.width * 0.88, size.height),
      line,
    );
  }

  @override
  bool shouldRepaint(covariant _EventPosterPainter oldDelegate) => false;
}
