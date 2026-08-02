part of 'studio_profile_screen.dart';

class _StudioRecordingsPanel extends StatefulWidget {
  final String profileId;
  final bool ownerMode;
  final List<SpotifyTrackPreview> initialSpotifyTracks;

  const _StudioRecordingsPanel({
    required this.profileId,
    required this.ownerMode,
    required this.initialSpotifyTracks,
  });

  @override
  State<_StudioRecordingsPanel> createState() => _StudioRecordingsPanelState();
}

class _StudioRecordingsPanelState extends State<_StudioRecordingsPanel> {
  late List<SpotifyTrackPreview> _spotifyTracks;

  @override
  void initState() {
    super.initState();
    _spotifyTracks = List.unmodifiable(widget.initialSpotifyTracks);
  }

  @override
  void didUpdateWidget(covariant _StudioRecordingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameTrackIds(
      oldWidget.initialSpotifyTracks,
      widget.initialSpotifyTracks,
    )) {
      _spotifyTracks = List.unmodifiable(widget.initialSpotifyTracks);
    }
  }

  Future<bool> _updateSpotifyTracks(List<SpotifyTrackPreview> tracks) async {
    if (!mounted) return false;
    final cubit = context.read<StudioProfileCubit>();
    await cubit.updateMyProfile(
      StudioProfileSaveRequest(
        spotifyTrackIds: tracks
            .map((track) => track.id)
            .toList(growable: false),
        spotifyTracks: tracks.map(_trackToJson).toList(growable: false),
      ),
    );
    if (!mounted || cubit.state.status == StudioProfileStatus.failure) {
      return false;
    }
    setState(() {
      _spotifyTracks = List.unmodifiable(
        cubit.state.profile?.spotifyTracks ?? tracks,
      );
    });
    return true;
  }

  Map<String, dynamic> _trackToJson(SpotifyTrackPreview track) {
    return <String, dynamic>{
      'spotifyTrackId': track.id,
      'name': track.name,
      'durationMs': track.durationSeconds == null
          ? null
          : track.durationSeconds! * 1000,
      'explicit': false,
      'previewUrl': track.previewUrl,
      'spotifyUrl': track.spotifyUrl,
      'albumName': null,
      'albumImageUrl': track.albumImageUrl,
      'artistNames': track.artistNames,
    };
  }

  bool _sameTrackIds(
    List<SpotifyTrackPreview> left,
    List<SpotifyTrackPreview> right,
  ) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index].id != right[index].id) return false;
    }
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
