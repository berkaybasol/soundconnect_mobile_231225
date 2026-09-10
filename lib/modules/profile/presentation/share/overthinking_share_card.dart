import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/profile_brand_title.dart';
import 'overthinking_share_data.dart';

/// The same fixed canvas is used for the on-screen PNG and the exported story.
/// Resolved image providers are optional; this widget never starts networking.
class OverthinkingShareCard extends StatelessWidget {
  const OverthinkingShareCard({
    super.key,
    required this.data,
    this.albumImage,
    this.authorAvatar,
  });

  final OverthinkingShareData data;
  final ImageProvider? albumImage;
  final ImageProvider? authorAvatar;

  static const canvasSize = Size(360, 640);
  static const _white = Color(0xFFF4F2F7);
  static const _muted = Color(0xFFA8ADBF);

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
          color: const Color(0xFF0B1321),
          child: DefaultTextStyle(
            style: const TextStyle(fontFamily: 'Roboto', color: _white),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1D2034),
                    Color(0xFF0B1321),
                    Color(0xFF21192F),
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 44, 22, 34),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Transform.translate(
                          offset: const Offset(-204 * 10 / 190, 0),
                          child: const SizedBox(
                            width: 204,
                            height: 42,
                            child: ProfileBrandTitle(),
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          'OVERTHINKING',
                          style: TextStyle(
                            color: _muted,
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.brandGradient.first.withValues(
                                alpha: 0.8,
                              ),
                              const Color(0xFF35394C),
                              AppColors.brandGradient.last.withValues(
                                alpha: 0.65,
                              ),
                            ],
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(0.8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(23.2),
                            child: CustomPaint(
                              painter: const _PagePainter(),
                              child: Padding(
                                padding: const EdgeInsets.all(21),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const _QuoteMark(),
                                    const SizedBox(height: 14),
                                    Text(
                                      data.title,
                                      key: const Key(
                                        'overthinking-share-title',
                                      ),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 27,
                                        height: 1.13,
                                        letterSpacing: -0.8,
                                        fontWeight: FontWeight.w800,
                                      ),
                                      strutStyle: const StrutStyle(
                                        fontSize: 27,
                                        height: 1.13,
                                        forceStrutHeight: true,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Expanded(
                                      child: _Excerpt(content: data.content),
                                    ),
                                    const SizedBox(height: 19),
                                    _AuthorRow(
                                      data: data,
                                      avatar: data.anonymous
                                          ? null
                                          : authorAvatar,
                                    ),
                                    if (data.hasMusic) ...[
                                      const Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        child: Divider(
                                          height: 1,
                                          color: Color(0xFF2D3446),
                                        ),
                                      ),
                                      _MusicRow(data: data, image: albumImage),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Birbirimizi tanımıyoruz.\nAma bu hissi biliyoruz.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.6,
                        color: _muted,
                        letterSpacing: 0.15,
                      ),
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

class _Excerpt extends StatelessWidget {
  const _Excerpt({required this.content});
  final String content;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const fontSize = 15.0;
      const height = 1.55;
      final lines = (constraints.maxHeight / (fontSize * height)).floor();
      if (lines < 1 || content.trim().isEmpty) return const SizedBox.shrink();
      return Align(
        alignment: Alignment.topLeft,
        child: Text(
          content,
          key: const Key('overthinking-share-excerpt'),
          maxLines: lines,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: fontSize,
            height: height,
            color: Color(0xFFC5C9D6),
          ),
          strutStyle: const StrutStyle(
            fontSize: fontSize,
            height: height,
            forceStrutHeight: true,
          ),
        ),
      );
    },
  );
}

class _AuthorRow extends StatelessWidget {
  const _AuthorRow({required this.data, this.avatar});
  final OverthinkingShareData data;
  final ImageProvider? avatar;

  @override
  Widget build(BuildContext context) => Row(
    key: const Key('overthinking-share-author'),
    children: [
      ClipOval(
        child: SizedBox.square(
          dimension: 34,
          child: avatar == null
              ? ColoredBox(
                  color: const Color(0xFF293044),
                  child: Icon(
                    data.anonymous
                        ? Icons.person_outline_rounded
                        : Icons.person_rounded,
                    size: 19,
                    color: const Color(0xFFB9B6CA),
                  ),
                )
              : Image(
                  key: const Key('overthinking-share-author-image'),
                  image: avatar!,
                  fit: BoxFit.cover,
                ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          data.authorLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFFD4D5E0),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );
}

class _MusicRow extends StatelessWidget {
  const _MusicRow({required this.data, this.image});
  final OverthinkingShareData data;
  final ImageProvider? image;

  @override
  Widget build(BuildContext context) => Row(
    key: const Key('overthinking-share-music'),
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox.square(
          dimension: 48,
          child: image == null
              ? CustomPaint(
                  painter: const _RecordPainter(),
                  child: const Icon(
                    Icons.music_note_rounded,
                    color: Color(0xFFE389AF),
                    size: 22,
                  ),
                )
              : Image(image: image!, fit: BoxFit.cover),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'BU YAZIYA EŞLİK EDEN',
              style: TextStyle(
                color: Color(0xFF959EB4),
                fontSize: 7,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              data.trackName.isEmpty
                  ? 'Bir şarkı eşlik ediyor'
                  : data.trackName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            if (data.artistName.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                data.artistName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFFA8ADBF), fontSize: 10),
              ),
            ],
          ],
        ),
      ),
    ],
  );
}

class _QuoteMark extends StatelessWidget {
  const _QuoteMark();

  @override
  Widget build(BuildContext context) => ShaderMask(
    shaderCallback: (rect) =>
        LinearGradient(colors: AppColors.brandGradient).createShader(rect),
    blendMode: BlendMode.srcIn,
    child: const Icon(
      Icons.format_quote_rounded,
      size: 32,
      color: Colors.white,
    ),
  );
}

class _PagePainter extends CustomPainter {
  const _PagePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B2335), Color(0xFF131C2D)],
        ).createShader(rect),
    );
    final center = Offset(size.width + 8, -26);
    for (var index = 0; index < 5; index++) {
      canvas.drawCircle(
        center,
        74 + index * 18,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.7
          ..color = const Color(0xFFB7A4D0).withValues(alpha: 0.075),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PagePainter oldDelegate) => false;
}

class _RecordPainter extends CustomPainter {
  const _RecordPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = const Color(0xFF272941));
    final center = rect.center;
    for (var index = 0; index < 4; index++) {
      canvas.drawCircle(
        center,
        10 + index * 5,
        Paint()
          ..color = const Color(0xFF70708E).withValues(alpha: 0.22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6,
      );
    }
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: 21),
      math.pi,
      math.pi * 0.55,
      false,
      Paint()
        ..shader = LinearGradient(
          colors: AppColors.brandGradient,
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(covariant _RecordPainter oldDelegate) => false;
}
