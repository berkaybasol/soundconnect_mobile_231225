part of 'musician_profile_screen.dart';

class _MediaContent extends StatelessWidget {
  final ProfileMedia media;
  final String profileId;
  final List<SpotifyTrackPreview> spotifyTracks;
  final bool spotifyLoading;
  final bool ownerMode;

  const _MediaContent({
    required this.media,
    required this.profileId,
    required this.spotifyTracks,
    required this.spotifyLoading,
    required this.ownerMode,
  });

  @override
  Widget build(BuildContext context) {
    final audioItems = media.audios;
    final featuredVideo = media.featuredVideo;
    final videoItems = <MediaAsset>[
      if (featuredVideo != null) featuredVideo,
      ...media.videos.where(
        (item) => featuredVideo == null || item.id != featuredVideo.id,
      ),
    ];
    final audioHandler = serviceLocator<AudioHandler>();

    return ProfileMediaContentSwitcher(
      firstTab: _AudioTab(
        items: audioItems,
        profileId: profileId,
        spotifyTracks: spotifyTracks,
        spotifyLoading: spotifyLoading,
        ownerMode: ownerMode,
        audioHandler: audioHandler,
      ),
      videoItems: videoItems,
      videoProfileId: profileId,
      ownerMode: ownerMode,
      profileType: 'MUSICIAN',
      uploadOwnerType: 'MUSICIAN_PROFILE',
    );
  }
}
