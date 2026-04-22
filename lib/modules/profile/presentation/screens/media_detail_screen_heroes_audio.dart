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
            iconColor: isSpotify ? AppColors.spotifyGreen : AppColors.coralAlt,
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
