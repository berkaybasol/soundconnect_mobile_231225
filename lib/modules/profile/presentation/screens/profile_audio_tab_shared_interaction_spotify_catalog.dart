part of 'profile_audio_tab_shared.dart';

extension _ProfileAudioTabSpotifyCatalogMethods on ProfileAudioTab {
  Future<bool> _removeSpotifyTrackFromCatalog(
    BuildContext context,
    String trackId, {
    List<SpotifyTrackPreview>? sourceTracks,
    bool showSnackbar = true,
  }) async {
    final baseTracks = sourceTracks ?? spotifyTracks;
    final nextTracks = baseTracks.where((e) => e.id != trackId).toList();
    if (nextTracks.length == baseTracks.length) return false;

    final nextTrackIds = nextTracks.map((e) => e.id).toList();
    final nextTrackMaps = nextTracks
        .map((track) => _trackToSaveJson(track))
        .toList();

    final cubit = context.read<MusicianProfileCubit>();
    await cubit.updateProfile(
      MusicianProfileSaveRequest(
        spotifyTrackIds: nextTrackIds,
        spotifyTracks: nextTrackMaps,
      ),
    );
    if (!context.mounted) return false;
    if (cubit.state.status == MusicianProfileStatus.failure) {
      if (showSnackbar) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              cubit.state.error?.message ?? 'Spotify parçası silinemedi.',
            ),
          ),
        );
      }
      return false;
    }
    if (showSnackbar) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Spotify parçası kaldırıldı.')),
      );
    }
    return true;
  }
}
