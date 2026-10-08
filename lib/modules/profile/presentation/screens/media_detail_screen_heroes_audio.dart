part of 'media_detail_screen.dart';

class _AudioHero extends StatelessWidget {
  final String title;
  final bool isSpotify;
  final String? playbackUrl;
  final VoidCallback onPlay;
  final VoidCallback onBack10;
  final VoidCallback onForward10;
  final bool isPlaying;
  final double progress;
  final ValueChanged<double> onSeek;

  _AudioHero({
    required this.title,
    required this.isSpotify,
    required this.playbackUrl,
    required this.onPlay,
    required this.onBack10,
    required this.onForward10,
    required this.isPlaying,
    required this.progress,
    required this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    if (!isSpotify) return _buildUploadedAudio(context);

    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 10),
          WaveformStub(
            gradientColors: isSpotify
                ? [
                    AppColors.spotifyGreenBright,
                    AppColors.spotifyGreen,
                    AppColors.spotifyGreenDark,
                  ]
                : AppColors.brandGradient,
            iconColor: isSpotify
                ? AppColors.spotifyGreen
                : (AppColors.isLight
                      ? AppColors.accentText
                      : AppColors.coralAlt),
            playIconColor: isSpotify
                ? AppColors.spotifyGreen
                : Theme.of(context).colorScheme.onSurfaceVariant,
            leading: isSpotify
                ? FaIcon(
                    FontAwesomeIcons.spotify,
                    size: 16,
                    color: AppColors.spotifyGreen,
                  )
                : Image.asset(
                    'assets/logo.png',
                    width: 26,
                    height: 26,
                    fit: BoxFit.contain,
                  ),
            height: 92,
            waveformHeight: 44,
            isPlaying: isPlaying,
            progress: progress,
            onSeek: onSeek,
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _TransportButton(
                icon: Icons.replay_10_rounded,
                onTap: playbackUrl == null || playbackUrl!.isEmpty
                    ? null
                    : onBack10,
                color: isSpotify
                    ? AppColors.spotifyGreen
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              SizedBox(width: 10),
              _TransportButton(
                icon: isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                onTap: playbackUrl == null || playbackUrl!.isEmpty
                    ? null
                    : onPlay,
                color: isSpotify
                    ? AppColors.spotifyGreen
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                big: true,
              ),
              SizedBox(width: 10),
              _TransportButton(
                icon: Icons.forward_10_rounded,
                onTap: playbackUrl == null || playbackUrl!.isEmpty
                    ? null
                    : onForward10,
                color: isSpotify
                    ? AppColors.spotifyGreen
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUploadedAudio(BuildContext context) {
    final theme = Theme.of(context);
    final canPlay = playbackUrl != null && playbackUrl!.isNotEmpty;

    return GradientOutline(
      radius: 20,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 12),
            Theme(
              data: theme.copyWith(
                dividerColor: Colors.transparent,
                colorScheme: theme.colorScheme.copyWith(
                  surfaceContainer: Colors.transparent,
                  surfaceContainerHighest: Colors.transparent,
                ),
              ),
              child: WaveformStub(
                leading: const BrandGradientIcon(
                  Icons.graphic_eq_rounded,
                  size: 24,
                ),
                samples: WaveformStub.samplesFromSeed(title, length: 54),
                height: 72,
                waveformHeight: 48,
                isPlaying: isPlaying,
                progress: progress,
                onSeek: onSeek,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _UploadedAudioTransportButton(
                  icon: Icons.replay_10_rounded,
                  tooltip: '10 saniye geri',
                  onPressed: canPlay ? onBack10 : null,
                ),
                const SizedBox(width: 16),
                _UploadedAudioTransportButton(
                  icon: isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  tooltip: isPlaying ? 'Duraklat' : 'Çal',
                  onPressed: canPlay ? onPlay : null,
                  primary: true,
                ),
                const SizedBox(width: 16),
                _UploadedAudioTransportButton(
                  icon: Icons.forward_10_rounded,
                  tooltip: '10 saniye ileri',
                  onPressed: canPlay ? onForward10 : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadedAudioTransportButton extends StatelessWidget {
  const _UploadedAudioTransportButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.primary = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final theme = Theme.of(context);
    final size = primary ? 56.0 : 48.0;
    final iconSize = primary ? 30.0 : 24.0;
    return SizedBox.square(
      dimension: size,
      child: GradientOutline(
        radius: size / 2,
        colors: onPressed == null
            ? [theme.dividerColor, theme.dividerColor]
            : null,
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          style: IconButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.square(size),
            shape: const CircleBorder(),
          ),
          icon: onPressed == null
              ? Icon(
                  icon,
                  size: iconSize,
                  color: theme.colorScheme.onSurfaceVariant,
                )
              : BrandGradientIcon(icon, size: iconSize),
        ),
      ),
    );
  }
}

class _TransportButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color color;
  final bool big;

  _TransportButton({
    required this.icon,
    required this.onTap,
    required this.color,
    this.big = false,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: Container(
            width: big ? 36 : 32,
            height: big ? 36 : 32,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              shape: BoxShape.circle,
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Icon(icon, size: big ? 20 : 16, color: color),
          ),
        ),
      ),
    );
  }
}
