part of 'studio_profile_screen.dart';

class _StudioRecordingsPanel extends StatefulWidget {
  final String profileId;
  final bool ownerMode;

  const _StudioRecordingsPanel({
    required this.profileId,
    required this.ownerMode,
  });

  @override
  State<_StudioRecordingsPanel> createState() => _StudioRecordingsPanelState();
}

class _StudioRecordingsPanelState extends State<_StudioRecordingsPanel> {
  List<SpotifyTrackPreview> _spotifyTracks = const [];

  Future<bool> _updateSpotifyTracks(List<SpotifyTrackPreview> tracks) async {
    if (!mounted) return false;
    setState(() => _spotifyTracks = List.unmodifiable(tracks));
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final mediaState = context.watch<ProfileMediaCubit>().state;
    final tracks = mediaState.media?.audios ?? const <Track>[];

    return ProfileAudioTab(
      items: tracks,
      profileId: widget.profileId,
      spotifyTracks: _spotifyTracks,
      spotifyLoading: false,
      ownerMode: widget.ownerMode,
      audioHandler: serviceLocator<AudioHandler>(),
      uploadOwnerType: 'STUDIO_PROFILE',
      uploadProfileType: 'STUDIO',
      showSpotifyCatalogButtonWhenOwnerAndEmpty: true,
      emptyUploadPrompt: 'Henüz kayıt eklemediniz',
      uploadActionLabel: 'Kayıt ekle',
      spotifyCatalogTitle: 'Stüdyonun Spotify Kataloğu',
      onSpotifyTracksChanged: _updateSpotifyTracks,
    );
  }
}
