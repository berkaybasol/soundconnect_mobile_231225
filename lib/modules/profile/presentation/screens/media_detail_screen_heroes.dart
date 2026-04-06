part of 'media_detail_screen.dart';

class _VideoHero extends StatelessWidget {
  final VideoPlayerController? controller;
  final String? thumbnailUrl;
  final bool ready;
  final String? errorText;

  const _VideoHero({
    required this.controller,
    required this.thumbnailUrl,
    required this.ready,
    required this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final showVideo = ready && c != null && c.value.isInitialized;
    final isPlaying = showVideo && c.value.isPlaying;

    return Container(
      height: 240,
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        image: thumbnailUrl != null
            ? DecorationImage(
                image: NetworkImage(thumbnailUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: Stack(
        children: [
          if (showVideo)
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: c.value.size.width,
                    height: c.value.size.height,
                    child: VideoPlayer(c),
                  ),
                ),
              ),
            ),
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: showVideo
                    ? () {
                        if (c.value.isPlaying) {
                          c.pause();
                        } else {
                          c.play();
                        }
                      }
                    : null,
                child: Center(
                  child: Icon(
                    isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_fill,
                    size: 64,
                    color: AppColors.white,
                  ),
                ),
              ),
            ),
          ),
          if (!showVideo)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Text(
                errorText ?? 'Video yukleniyor...',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ImageHero extends StatelessWidget {
  final String? imageUrl;

  const _ImageHero({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    return Container(
      height: 320,
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: url == null || url.isEmpty
          ? const Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: AppColors.textMuted,
                size: 40,
              ),
            )
          : InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image_outlined,
                    color: AppColors.textMuted,
                    size: 40,
                  ),
                ),
              ),
            ),
    );
  }
}

class _CountRow extends StatelessWidget {
  final int likeCount;
  final int commentCount;
  final bool liked;
  final bool likeLoading;
  final VoidCallback? onLikeTap;

  const _CountRow({
    required this.likeCount,
    required this.commentCount,
    required this.liked,
    required this.likeLoading,
    required this.onLikeTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: likeLoading ? null : onLikeTap,
          borderRadius: BorderRadius.circular(10),
          child: Row(
            children: [
              Icon(
                liked ? Icons.favorite : Icons.favorite_border,
                size: 18,
                color: liked ? AppColors.coralAlt : AppColors.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                likeCount.toString(),
                style: const TextStyle(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        const Icon(
          Icons.chat_bubble_outline,
          size: 18,
          color: AppColors.textMuted,
        ),
        const SizedBox(width: 6),
        Text(
          commentCount.toString(),
          style: const TextStyle(color: AppColors.textMuted),
        ),
      ],
    );
  }
}
