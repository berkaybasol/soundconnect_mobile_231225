part of 'weekly_event_detail_screen.dart';

class _EventEndedNotice extends StatelessWidget {
  const _EventEndedNotice();

  @override
  Widget build(BuildContext context) => _EventCommentFrame(
    frameKey: const Key('event-ended-notice'),
    radius: 16,
    borderColors: const [Color(0x805F365E), Color(0x806F429C)],
    child: Stack(
      children: [
        const Positioned(
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: RepaintBoundary(
                child: SizedBox(
                  width: 116,
                  height: 62,
                  child: CustomPaint(painter: _EventEndWavePainter()),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: AppColors.brandGradient),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(1),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                    ),
                    child: const BrandGradientIcon.social(
                      Icons.schedule_rounded,
                      size: 23,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Container(
                width: .8,
                height: 28,
                color: AppColors.textMuted.withValues(alpha: .45),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bu etkinlik sona erdi.',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Etkinliğe gösterdiğin ilgi için teşekkürler!',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 11.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _EventCommentsHeading extends StatelessWidget {
  const _EventCommentsHeading({required this.state});
  final CommentThreadState state;

  @override
  Widget build(BuildContext context) {
    final unknown =
        state.comments.isEmpty && (state.loading || state.error != null);
    final count = unknown
        ? (state.loading ? '…' : '—')
        : NumberFormat.compact(locale: 'tr').format(state.totalElements);
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sorular & Yorumlar',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 7),
                Container(
                  key: const Key('event-comments-heading-accent'),
                  width: 34,
                  height: 2,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    gradient: LinearGradient(colors: AppColors.brandGradient),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Semantics(
            label: unknown
                ? (state.loading
                      ? 'Yorum sayısı yükleniyor'
                      : 'Yorum sayısı yüklenemedi')
                : '${state.totalElements} yorum, yanıtlar hariç',
            child: ExcludeSemantics(
              child: _EventCommentFrame(
                frameKey: const Key('event-comment-count'),
                radius: 24,
                borderColors: const [Color(0x70564776), Color(0x70564776)],
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.mode_comment_outlined, size: 17),
                      const SizedBox(width: 7),
                      Text(
                        count,
                        style: Theme.of(
                          context,
                        ).textTheme.labelMedium?.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventCommentComposerSurface extends StatelessWidget {
  const _EventCommentComposerSurface({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('event-comment-composer-surface'),
    padding: const EdgeInsets.fromLTRB(16, 13, 12, 12),
    decoration: BoxDecoration(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Theme.of(context).colorScheme.surfaceContainerHighest,
          AppColors.navBlueDeep,
        ],
      ),
      border: Border.all(
        color: AppColors.border.withValues(alpha: .8),
        width: .8,
      ),
    ),
    child: child,
  );
}

class _EventCommentInputFrame extends StatelessWidget {
  const _EventCommentInputFrame({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => _EventCommentFrame(
    frameKey: const Key('event-comment-input-frame'),
    radius: 23,
    borderColors: [
      AppColors.brandGradient.first.withValues(alpha: .7),
      AppColors.brandGradient.last.withValues(alpha: .6),
    ],
    glow: true,
    child: child,
  );
}

class _EventCommentFrame extends StatelessWidget {
  const _EventCommentFrame({
    required this.child,
    required this.radius,
    required this.borderColors,
    this.frameKey,
    this.glow = false,
  });
  final Widget child;
  final double radius;
  final List<Color> borderColors;
  final Key? frameKey;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      key: frameKey,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(colors: borderColors),
        boxShadow: glow
            ? [
                BoxShadow(
                  color: AppColors.brandGradient.first.withValues(alpha: .09),
                  blurRadius: 12,
                  offset: const Offset(-3, 3),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(.8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius - .8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  scheme.surfaceContainerHighest,
                  Color.lerp(
                    scheme.surfaceContainerHighest,
                    scheme.surface,
                    .35,
                  )!,
                ],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Static code-native linework, clipped by its parent. No animation or image request.
class _EventEndWavePainter extends CustomPainter {
  const _EventEndWavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .35
      ..shader = const LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: [Color(0x00372A61), Color(0x447E4AAB), Color(0x66F07A5E)],
      ).createShader(Offset.zero & size);
    for (var line = 0; line < 28; line++) {
      final depth = line / 27;
      final crest = Path()
        ..moveTo(-4, size.height * (1.08 + depth * .12))
        ..cubicTo(
          size.width * .35,
          size.height * (1.1 + depth * .15),
          size.width * .35,
          size.height * (.20 + depth * .75),
          size.width * 1.08,
          size.height * (.55 + depth * .55),
        );
      final rising = Path()
        ..moveTo(size.width * .08, size.height * (1.08 + depth * .12))
        ..cubicTo(
          size.width * .72,
          size.height * 1.15,
          size.width * .77,
          size.height * (.32 + depth * .80),
          size.width * 1.06,
          size.height * (.08 + depth * .85),
        );
      canvas.drawPath(crest, paint);
      canvas.drawPath(rising, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _EventEndWavePainter oldDelegate) => false;
}
