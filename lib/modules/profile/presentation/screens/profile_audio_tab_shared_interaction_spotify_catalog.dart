// ignore_for_file: use_build_context_synchronously
// ignore_for_file: unused_element

part of 'profile_audio_tab_shared.dart';

extension _ProfileAudioTabSpotifyCatalogMethods on ProfileAudioTab {
  Future<void> _addSpotifyTrackFromCatalog(BuildContext context) async {
    final selected = await _showSpotifyTrackPicker(context, spotifyTracks);
    if (selected == null) return;
    final existingIds = spotifyTracks.map((e) => e.id).toSet();
    if (existingIds.contains(selected.id)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Bu parca zaten ekli.')));
      return;
    }
    final nextTracks = [...spotifyTracks, selected];
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
    if (!context.mounted) return;
    if (cubit.state.status == MusicianProfileStatus.failure) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            cubit.state.error?.message ?? 'Spotify parcasi eklenemedi.',
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Sarki basariyla eklendi.')));
  }

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
              cubit.state.error?.message ?? 'Spotify parcasi silinemedi.',
            ),
          ),
        );
      }
      return false;
    }
    if (showSnackbar) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Spotify parcasi kaldirildi.')),
      );
    }
    return true;
  }
}
