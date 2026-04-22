part of 'band_profile_screen.dart';

class _BandAudioTab extends StatelessWidget {
  final BandProfile profile;
  final List<dynamic> items;
  final List<SpotifyTrackPreview> spotifyTracks;
  final bool spotifyLoading;
  final bool editable;
  final Future<bool> Function(
    List<SpotifyTrackPreview> nextTracks, {
    required String failureMessage,
  })
  onSaveSpotifyTracks;

  _BandAudioTab({
    required this.profile,
    required this.items,
    required this.spotifyTracks,
    required this.spotifyLoading,
    required this.editable,
    required this.onSaveSpotifyTracks,
  });

  @override
  Widget build(BuildContext context) {
    final audioHandler = serviceLocator<AudioHandler>();
    final positionStream = audioHandler is AudioPlayerHandler
        ? audioHandler.positionStream
        : Stream<Duration>.empty();

    return StreamBuilder<Duration>(
      stream: positionStream,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final currentId = audioHandler.mediaItem.value?.id;
        final isPlaying = audioHandler.playbackState.value.playing;

        return ListView(
          padding: EdgeInsets.all(20),
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showSpotifyCatalog(context),
                icon: FaIcon(
                  FontAwesomeIcons.spotify,
                  size: 16,
                  color: AppColors.white,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.spotifyGreen,
                  foregroundColor: AppColors.white,
                ),
                label: Text('Spotify Katalogu'),
              ),
            ),
            SizedBox(height: 18),
            if (editable) ...[
              InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => _showTrackUpload(context),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 24, horizontal: 18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      colors: [
                        Color(0x1AFFFFFF),
                        Color(0x1A8A5CFF),
                        Color(0x1AFF7A3D),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                        child: Icon(
                          Icons.add,
                          color: Theme.of(context).colorScheme.onSurface,
                          size: 28,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        items.isEmpty ? 'Henuz ses eklemediniz' : 'Ses ekle',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'SoundConnect uzerinden sarki yuklemek icin dokun.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
            ],
            if (items.isEmpty)
              Text(
                'Band henuz ses eklemedi.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
            else
              ...items.asMap().entries.map((entry) {
                final index = entry.key;
                final track = entry.value;
                final trackId = track.id?.toString() ?? '';
                final playback = track.playbackUrl?.toString() ?? '';
                final isSpotify =
                    playback.contains('spotify') ||
                    playback.contains('open.spotify') ||
                    playback.contains('spotify.com');
                final isCurrent = currentId == trackId;
                final totalFromTrackMs =
                    ((track.durationSeconds as int?) ?? 0) * 1000;
                final totalFromHandlerMs =
                    audioHandler.mediaItem.value?.duration?.inMilliseconds ?? 0;
                final totalMs =
                    (totalFromTrackMs > 0
                            ? totalFromTrackMs
                            : totalFromHandlerMs)
                        .toDouble();
                final progress = totalMs > 0
                    ? (position.inMilliseconds / totalMs).clamp(0.0, 1.0)
                    : 0.0;
                final fallbackLikeCount = 128 + (index * 7);
                final fallbackCommentCount = 32 + (index * 3);

                return Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ProfileAudioPreviewCard(
                        title: track.title?.toString() ?? 'Ses kaydi',
                        actionLabel: isSpotify
                            ? "Tamamini Spotify'da Dinle"
                            : null,
                        actionColor: isSpotify ? AppColors.spotifyGreen : null,
                        waveform: WaveformStub(
                          samples: WaveformStub.samplesFromSeed(
                            '$trackId:${track.title}:${track.mediaAssetId}',
                          ),
                          gradientColors: isSpotify
                              ? [
                                  AppColors.spotifyGreenBright,
                                  AppColors.spotifyGreen,
                                  AppColors.spotifyGreenDark,
                                ]
                              : AppColors.brandGradient,
                          iconColor: isSpotify
                              ? AppColors.spotifyGreen
                              : AppColors.coralAlt,
                          playIconColor: isSpotify
                              ? AppColors.spotifyGreen
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          leading: isSpotify
                              ? FaIcon(
                                  FontAwesomeIcons.spotify,
                                  size: 16,
                                  color: AppColors.spotifyGreen,
                                )
                              : Image.asset(
                                  'assets/logo.png',
                                  width: 26,
                                  height: 26,
                                  fit: BoxFit.contain,
                                ),
                          height: 92,
                          waveformHeight: 44,
                          isPlaying: isCurrent && isPlaying,
                          progress: isCurrent ? progress : 0,
                          onSeek: isCurrent
                              ? (ratio) {
                                  final milliseconds = (totalMs * ratio)
                                      .round()
                                      .clamp(0, 1000000)
                                      .toInt();
                                  audioHandler.seek(
                                    Duration(milliseconds: milliseconds),
                                  );
                                }
                              : null,
                        ),
                        bottomControls: ProfileAudioTransportRow(
                          isPlaying: isCurrent && isPlaying,
                          iconColor: isSpotify
                              ? AppColors.spotifyGreen
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          onPlayPause: () => _toggleTrack(track, audioHandler),
                          onBack10: isCurrent
                              ? () {
                                  final totalInt = totalMs.round();
                                  final currentMs = position.inMilliseconds;
                                  final targetMs = (currentMs - 10000)
                                      .clamp(0, totalInt)
                                      .toInt();
                                  audioHandler.seek(
                                    Duration(milliseconds: targetMs),
                                  );
                                }
                              : null,
                          onForward10: isCurrent
                              ? () {
                                  final totalInt = totalMs.round();
                                  final currentMs = position.inMilliseconds;
                                  final targetMs = (currentMs + 10000)
                                      .clamp(0, totalInt)
                                      .toInt();
                                  audioHandler.seek(
                                    Duration(milliseconds: targetMs),
                                  );
                                }
                              : null,
                        ),
                      ),
                      SizedBox(height: 6),
                      ProfileCountRow(
                        likeCount: fallbackLikeCount,
                        commentCount: fallbackCommentCount,
                        isLiked: false,
                        onLikeTap: null,
                        onCommentTap: null,
                      ),
                    ],
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}
