// ignore_for_file: unused_element, unused_element_parameter, unused_local_variable, use_build_context_synchronously

part of 'band_profile_screen.dart';

extension _BandAudioTabMethods on _BandAudioTab {
  Future<void> _showTrackUpload(BuildContext context) async {
    await showProfileTrackUploadSheet(
      hostContext: context,
      profileId: profile.id,
      ownerType: 'BAND',
      profileType: 'BAND',
    );
  }

  Future<void> _toggleTrack(dynamic track, AudioHandler audioHandler) async {
    final url = track.playbackUrl?.toString();
    if (url == null || url.isEmpty) return;

    final trackId = track.id?.toString() ?? url;
    final currentId = audioHandler.mediaItem.value?.id;
    final isPlaying = audioHandler.playbackState.value.playing;
    final isCurrent = currentId == trackId;

    if (audioHandler is AudioPlayerHandler) {
      if (isCurrent && isPlaying) {
        await audioHandler.pause();
      } else if (isCurrent && !isPlaying) {
        await audioHandler.play();
      } else {
        await audioHandler.playUrl(
          url,
          title: track.title?.toString(),
          duration: (track.durationSeconds is int)
              ? Duration(seconds: track.durationSeconds as int)
              : null,
          mediaId: trackId,
        );
      }
    }
  }
}
