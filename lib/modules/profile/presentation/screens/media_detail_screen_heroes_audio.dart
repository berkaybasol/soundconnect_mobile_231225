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

  const _AudioHero({
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          WaveformStub(
            gradientColors: isSpotify
                ? const [
                    Color(0xFF1ED760),
                    Color(0xFF1DB954),
                    Color(0xFF18A34A),
                  ]
                : AppColors.brandGradient,
            iconColor: isSpotify ? const Color(0xFF1DB954) : AppColors.coralAlt,
            playIconColor: isSpotify
                ? const Color(0xFF1DB954)
                : AppColors.textMuted,
            leading: isSpotify
                ? const FaIcon(
                    FontAwesomeIcons.spotify,
                    size: 16,
                    color: Color(0xFF1DB954),
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
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _TransportButton(
                icon: Icons.replay_10_rounded,
                onTap: playbackUrl == null || playbackUrl!.isEmpty
                    ? null
                    : onBack10,
                color: isSpotify
                    ? const Color(0xFF1DB954)
                    : AppColors.textMuted,
              ),
              const SizedBox(width: 10),
              _TransportButton(
                icon: isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                onTap: playbackUrl == null || playbackUrl!.isEmpty
                    ? null
                    : onPlay,
                color: isSpotify
                    ? const Color(0xFF1DB954)
                    : AppColors.textMuted,
                big: true,
              ),
              const SizedBox(width: 10),
              _TransportButton(
                icon: Icons.forward_10_rounded,
                onTap: playbackUrl == null || playbackUrl!.isEmpty
                    ? null
                    : onForward10,
                color: isSpotify
                    ? const Color(0xFF1DB954)
                    : AppColors.textMuted,
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

  const _TransportButton({
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
              color: AppColors.navBlueSoft,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(icon, size: big ? 20 : 16, color: color),
          ),
        ),
      ),
    );
  }
}
