part of 'musician_public_profile_screen.dart';

class _AudioTab extends StatelessWidget {
  final List<Track> items;
  final List<SpotifyTrackPreview> spotifyTracks;
  final bool spotifyLoading;
  final AudioHandler audioHandler;

  const _AudioTab({
    required this.items,
    required this.spotifyTracks,
    required this.spotifyLoading,
    required this.audioHandler,
  });

  @override
  Widget build(BuildContext context) {
    final positionStream = audioHandler is AudioPlayerHandler
        ? (audioHandler as AudioPlayerHandler).positionStream
        : const Stream<Duration>.empty();
    final spotifyPreviewItems = spotifyTracks;

    if (items.isEmpty && spotifyPreviewItems.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          'Kullanici henuz ses eklemedi.',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    return StreamBuilder<Duration>(
      stream: positionStream,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final currentId = audioHandler.mediaItem.value?.id;
        final isPlaying = audioHandler.playbackState.value.playing;
        final statsState = context.watch<InteractionStatsCubit>().state;

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              if (spotifyLoading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: LinearProgressIndicator(),
                ),
              if (spotifyPreviewItems.isNotEmpty) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _showSpotifyCatalog(context, spotifyPreviewItems),
                    icon: const FaIcon(
                      FontAwesomeIcons.spotify,
                      size: 16,
                      color: Colors.white,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1DB954),
                      foregroundColor: Colors.white,
                    ),
                    label: const Text('Spotify Katalogu'),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              ...List.generate(items.length, (index) {
                return _buildAudioTrackItem(
                  context: context,
                  track: items[index],
                  index: index,
                  position: position,
                  currentId: currentId,
                  isPlaying: isPlaying,
                  statsState: statsState,
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
