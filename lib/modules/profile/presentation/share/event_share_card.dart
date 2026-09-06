import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import 'event_share_data.dart';

/// A fixed 9:16 export canvas. The preview and exported PNG use the same pixels.
/// All images are resolved before capture; this widget performs no networking.
class EventShareCard extends StatelessWidget {
  const EventShareCard({
    super.key,
    required this.data,
    this.posterImage,
    this.venueAvatar,
  });

  final EventShareData data;
  final ImageProvider? posterImage;
  final ImageProvider? venueAvatar;

  static const canvasSize = Size(360, 640);
  static const _white = Color(0xFFF4F2F7);
  static const _muted = Color(0xFFA8A9BB);

  @override
  Widget build(BuildContext context) => MediaQuery(
    data: const MediaQueryData(
      size: canvasSize,
      devicePixelRatio: 3,
      textScaler: TextScaler.noScaling,
    ),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox.fromSize(
        size: canvasSize,
        child: Material(
          color: const Color(0xFF090F1D),
          child: DefaultTextStyle(
            style: const TextStyle(fontFamily: 'Roboto', color: _white),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF171A2D),
                    Color(0xFF090F1D),
                    Color(0xFF21162C),
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 46, 22, 44),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Image.asset('assets/logo.png', width: 27, height: 27),
                        const SizedBox(width: 8),
                        const Text(
                          'SoundConnect',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          'ETKİNLİK',
                          style: TextStyle(
                            color: _muted,
                            fontSize: 8,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 19),
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          gradient: LinearGradient(
                            colors: [
                              AppColors.brandGradient.first.withValues(
                                alpha: 0.7,
                              ),
                              const Color(0xFF333446),
                              AppColors.brandGradient.last.withValues(
                                alpha: 0.7,
                              ),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(0.8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(21.2),
                            child: ColoredBox(
                              color: const Color(0xFF111827),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _Artwork(poster: posterImage),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        18,
                                        17,
                                        18,
                                        17,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                width: 3,
                                                height: 27,
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(2),
                                                  gradient: LinearGradient(
                                                    begin: Alignment.topCenter,
                                                    end: Alignment.bottomCenter,
                                                    colors:
                                                        AppColors.brandGradient,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 9),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      data.dateLabel,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 3),
                                                    Text(
                                                      [
                                                            data.weekdayLabel,
                                                            data.timeLabel,
                                                          ]
                                                          .where(
                                                            (part) =>
                                                                part.isNotEmpty,
                                                          )
                                                          .join(' · '),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontSize: 10,
                                                        color: _muted,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 13),
                                          Text(
                                            data.title,
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 25,
                                              height: 1.08,
                                              letterSpacing: -0.8,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          Expanded(
                                            child: _ShareDescription(
                                              description: data.description,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          const Text(
                                            'SANATÇI / GRUP',
                                            style: TextStyle(
                                              color: _muted,
                                              fontSize: 8,
                                              letterSpacing: 1.6,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            data.performerLabel,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              height: 1.1,
                                            ),
                                          ),
                                          const Padding(
                                            padding: EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                            child: Divider(
                                              height: 1,
                                              color: Color(0xFF2B3140),
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(11),
                                                child: SizedBox.square(
                                                  dimension: 34,
                                                  child: venueAvatar != null
                                                      ? Image(
                                                          image: venueAvatar!,
                                                          fit: BoxFit.cover,
                                                        )
                                                      : const ColoredBox(
                                                          color: Color(
                                                            0xFF20273A,
                                                          ),
                                                          child: Icon(
                                                            Icons
                                                                .location_on_outlined,
                                                            size: 18,
                                                            color: Color(
                                                              0xFFE17BAF,
                                                            ),
                                                          ),
                                                        ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      data.venueLabel,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                    if (data
                                                        .location
                                                        .isNotEmpty) ...[
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        data.location,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                          fontSize: 10,
                                                          color: _muted,
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            'Etkinlik detayları SoundConnect’te',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 10, color: _muted),
                          ),
                        ),
                        SizedBox(width: 7),
                        Icon(Icons.north_east_rounded, size: 12, color: _muted),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Use the space left by the title without moving the identity/footer rows.
/// Long copy is an excerpt in the image; preview semantics retain the full text.
class _ShareDescription extends StatelessWidget {
  const _ShareDescription({required this.description});
  final String description;

  @override
  Widget build(BuildContext context) {
    final text = description.trim();
    if (text.isEmpty) return const SizedBox.shrink();
    const fontSize = 12.0;
    const lineHeight = 1.4;
    const topGap = 10.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final lines =
            ((constraints.maxHeight - topGap) / (fontSize * lineHeight))
                .floor()
                .clamp(0, 4);
        if (lines == 0) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: topGap),
          child: Align(
            alignment: Alignment.topLeft,
            child: Text(
              text,
              key: const Key('event-share-description'),
              maxLines: lines,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: fontSize,
                height: lineHeight,
                color: Color(0xFFB2B4C5),
              ),
              strutStyle: const StrutStyle(
                fontSize: fontSize,
                height: lineHeight,
                forceStrutHeight: true,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Artwork extends StatelessWidget {
  const _Artwork({this.poster});
  final ImageProvider? poster;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 170,
    child: poster != null
        ? ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Image(image: poster!, fit: BoxFit.cover),
                ),
                const ColoredBox(color: Color(0x990D1321)),
                Image(image: poster!, fit: BoxFit.contain),
              ],
            ),
          )
        : CustomPaint(
            painter: const _OrbitPainter(),
            child: Center(
              child: Image.asset('assets/logo.png', width: 100, height: 100),
            ),
          ),
  );
}

class _OrbitPainter extends CustomPainter {
  const _OrbitPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF272039), Color(0xFF101726)],
          radius: 0.85,
        ).createShader(rect),
    );
    canvas.save();
    canvas.clipRect(rect);
    final center = Offset(size.width / 2, size.height / 2);
    for (var index = 0; index < 7; index++) {
      canvas.drawCircle(
        center,
        61 + index * 17,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6
          ..color = const Color(0xFF9596AD).withValues(alpha: 0.10),
      );
    }
    final orbit = Rect.fromCircle(center: center, radius: 125);
    canvas.drawArc(
      orbit,
      math.pi * 0.95,
      math.pi * 0.9,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..shader = LinearGradient(
          colors: AppColors.brandGradient,
        ).createShader(orbit),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter oldDelegate) => false;
}
