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

    final saved = await persistSpotifyTracks(context, nextTracks);
    if (!context.mounted) return false;
    if (!saved) {
      if (showSnackbar) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Spotify parçası silinemedi.')),
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
