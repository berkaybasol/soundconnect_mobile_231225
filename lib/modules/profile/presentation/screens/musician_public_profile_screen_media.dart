// ignore_for_file: unused_element, unused_element_parameter, unused_local_variable, use_build_context_synchronously

part of 'musician_public_profile_screen.dart';

class _MediaContent extends StatelessWidget {
  final ProfileMedia media;
  final List<SpotifyTrackPreview> spotifyTracks;
  final bool spotifyLoading;

  const _MediaContent({
    required this.media,
    required this.spotifyTracks,
    required this.spotifyLoading,
  });

  @override
  Widget build(BuildContext context) {
    final audioItems = media.audios;
    final videoItems = media.videos;
    final controller = DefaultTabController.of(context);
    final audioHandler = serviceLocator<AudioHandler>();

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return controller.index == 0
            ? _AudioTab(
                items: audioItems,
                spotifyTracks: spotifyTracks,
                spotifyLoading: spotifyLoading,
                audioHandler: audioHandler,
              )
            : ProfilePublicVideoTab(items: videoItems);
      },
    );
  }
}
