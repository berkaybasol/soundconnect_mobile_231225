// ignore_for_file: unused_element, unused_element_parameter

part of 'venue_public_profile_screen.dart';

class _SpotifyPreviewCard extends StatelessWidget {
  const _SpotifyPreviewCard();

  @override
  Widget build(BuildContext context) {
    return const ProfileSpotifyPreviewCard(ringSize: 74);
  }
}

class _AudioPreviewCard extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final Color? actionColor;
  final VoidCallback? onTap;
  final VoidCallback? onActionTap;
  final VoidCallback? onDoubleTap;
  final Widget waveform;
  final Widget? bottomControls;

  const _AudioPreviewCard({
    required this.title,
    required this.waveform,
    this.actionLabel,
    this.actionColor,
    this.onTap,
    this.onActionTap,
    this.onDoubleTap,
    this.bottomControls,
  });

  @override
  Widget build(BuildContext context) {
    return ProfileAudioPreviewCard(
      title: title,
      waveform: waveform,
      actionLabel: actionLabel,
      actionColor: actionColor,
      onTap: onTap,
      onActionTap: onActionTap,
      onDoubleTap: onDoubleTap,
      bottomControls: bottomControls,
      ringSize: 74,
    );
  }
}
