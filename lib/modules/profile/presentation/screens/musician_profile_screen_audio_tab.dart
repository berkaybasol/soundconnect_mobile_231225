part of 'musician_profile_screen.dart';

class _AudioTab extends StatelessWidget {
  final List<Track> items;
  final String profileId;
  final List<SpotifyTrackPreview> spotifyTracks;
  final bool spotifyLoading;
  final bool ownerMode;
  final AudioHandler audioHandler;

  const _AudioTab({
    required this.items,
    required this.profileId,
    required this.spotifyTracks,
    required this.spotifyLoading,
    required this.ownerMode,
    required this.audioHandler,
  });

  @override
  Widget build(BuildContext context) {
    return ProfileAudioTab(
      items: items,
      profileId: profileId,
      spotifyTracks: spotifyTracks,
      spotifyLoading: spotifyLoading,
      ownerMode: ownerMode,
      audioHandler: audioHandler,
      uploadOwnerType: 'MUSICIAN_PROFILE',
      uploadProfileType: 'MUSICIAN',
      showSpotifyCatalogButtonWhenOwnerAndEmpty: true,
      emptyUploadPrompt: 'Henüz ses eklemediniz',
      uploadActionLabel: 'Ses ekle',
    );
  }
}
