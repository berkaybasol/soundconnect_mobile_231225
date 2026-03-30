import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';

class ProfileAudioTransportRow extends StatelessWidget {
  final bool isPlaying;
  final Color iconColor;
  final VoidCallback? onPlayPause;
  final VoidCallback? onBack10;
  final VoidCallback? onForward10;

  const ProfileAudioTransportRow({
    super.key,
    required this.isPlaying,
    required this.iconColor,
    this.onPlayPause,
    this.onBack10,
    this.onForward10,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ProfileTransportButton(
          icon: Icons.replay_10_rounded,
          onTap: onBack10,
          color: iconColor,
        ),
        const SizedBox(width: 10),
        _ProfileTransportButton(
          icon: isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          onTap: onPlayPause,
          color: iconColor,
          big: true,
        ),
        const SizedBox(width: 10),
        _ProfileTransportButton(
          icon: Icons.forward_10_rounded,
          onTap: onForward10,
          color: iconColor,
        ),
      ],
    );
  }
}

class _ProfileTransportButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color color;
  final bool big;

  const _ProfileTransportButton({
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
