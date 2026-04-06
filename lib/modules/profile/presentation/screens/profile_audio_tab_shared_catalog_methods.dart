part of 'profile_audio_tab_shared.dart';

extension _ProfileAudioTabCatalogMethods on ProfileAudioTab {
  Future<void> _showSpotifyCatalog(
    BuildContext hostContext,
    List<SpotifyTrackPreview> tracks,
  ) async {
    if (tracks.isEmpty && !ownerMode) return;
    await showModalBottomSheet<void>(
      context: hostContext,
      isScrollControlled: true,
      backgroundColor: AppColors.navBlueDeep,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _SpotifyCatalogSheet(
        tab: this,
        hostContext: hostContext,
        initialTracks: tracks,
      ),
    );
  }
}
