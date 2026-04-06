part of 'venue_public_profile_screen.dart';

class _MediaContent extends StatelessWidget {
  final ProfileMedia media;
  final String galleryOwnerId;
  final List<SpotifyTrackPreview> spotifyTracks;
  final bool spotifyLoading;

  const _MediaContent({
    required this.media,
    required this.galleryOwnerId,
    required this.spotifyTracks,
    required this.spotifyLoading,
  });

  @override
  Widget build(BuildContext context) {
    final imageItems = media.videos
        .where((item) => (item.kind ?? '').toUpperCase() == 'IMAGE')
        .toList(growable: false);
    final videoItems = media.videos
        .where((item) => (item.kind ?? '').toUpperCase() == 'VIDEO')
        .toList(growable: false);
    final controller = DefaultTabController.of(context);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return controller.index == 0
            ? ProfilePhotoGalleryTab(items: imageItems, ownerMode: false)
            : ProfilePublicVideoTab(items: videoItems);
      },
    );
  }
}
