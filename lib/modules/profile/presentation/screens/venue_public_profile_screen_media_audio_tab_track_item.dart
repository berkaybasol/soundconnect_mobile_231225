part of 'venue_public_profile_screen.dart';

extension _VenuePublicProfileAudioTabTrackItem on _AudioTab {
  Widget _buildAudioTrackItem({
    required BuildContext context,
    required Track track,
    required int index,
    required Duration position,
    required String? currentId,
    required bool isPlaying,
    required dynamic statsState,
  }) {
    final fallbackLikeCount = 128 + (index * 7);
    final fallbackCommentCount = 32 + (index * 3);
    final targetType = 'MEDIA';
    final targetId = track.mediaAssetId;
    final statsKey = '$targetType:$targetId';
    if (targetId.isNotEmpty && !statsState.items.containsKey(statsKey)) {
      context.read<InteractionStatsCubit>().load(
        targetType: targetType,
        targetId: targetId,
      );
    }
    final stats = statsState.items[statsKey];
    final likeCount = stats?.likeCount ?? fallbackLikeCount;
    final commentCount = stats?.commentCount ?? fallbackCommentCount;
    final playback = track.playbackUrl ?? '';
    final isSpotify =
        playback.contains('spotify') ||
        playback.contains('open.spotify') ||
        playback.contains('spotify.com');
    final isCurrent = currentId == track.id;
    final totalFromTrackMs = (track.durationSeconds ?? 0) * 1000;
    final totalFromHandlerMs =
        audioHandler.mediaItem.value?.duration?.inMilliseconds ?? 0;
    final totalMs =
        (totalFromTrackMs > 0 ? totalFromTrackMs : totalFromHandlerMs)
            .toDouble();
    final progress = totalMs > 0
        ? (position.inMilliseconds / totalMs).clamp(0.0, 1.0)
        : 0.0;
    final isLiked = stats?.isLiked ?? false;

    void toggleLike() {
      if (targetId.isEmpty) return;
      context.read<InteractionStatsCubit>().toggleLike(
        targetType: targetType,
        targetId: targetId,
      );
    }

    void openDetails() {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MultiBlocProvider(
            providers: [
              BlocProvider.value(value: context.read<InteractionStatsCubit>()),
              BlocProvider(create: (_) => serviceLocator<CommentThreadCubit>()),
            ],
            child: MediaDetailScreen(
              title: track.title,
              isVideo: false,
              playbackUrl: track.playbackUrl,
              thumbnailUrl: null,
              durationSeconds: track.durationSeconds,
              targetType: targetType,
              targetId: targetId,
              likeCount: likeCount,
              commentCount: commentCount,
              isSpotify: isSpotify,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AudioPreviewCard(
            onTap: openDetails,
            onDoubleTap: () {
              if (!isLiked) {
                toggleLike();
              }
            },
            title: track.title,
            actionLabel: isSpotify ? "Tamamini Spotify'da Dinle" : null,
            actionColor: isSpotify ? AppColors.spotifyGreen : null,
            bottomControls: ProfileAudioTransportRow(
              isPlaying: isCurrent && isPlaying,
              iconColor: isSpotify
                  ? AppColors.spotifyGreen
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              onPlayPause: () => _toggleTrack(track),
              onBack10: isCurrent
                  ? () {
                      final totalInt = totalMs.round();
                      final currentMs = position.inMilliseconds;
                      final targetMs = (currentMs - 10000)
                          .clamp(0, totalInt)
                          .toInt();
                      audioHandler.seek(Duration(milliseconds: targetMs));
                    }
                  : null,
              onForward10: isCurrent
                  ? () {
                      final totalInt = totalMs.round();
                      final currentMs = position.inMilliseconds;
                      final targetMs = (currentMs + 10000)
                          .clamp(0, totalInt)
                          .toInt();
                      audioHandler.seek(Duration(milliseconds: targetMs));
                    }
                  : null,
            ),
            waveform: WaveformStub(
              samples: WaveformStub.samplesFromSeed(
                '${track.id}:${track.title}:${track.mediaAssetId}',
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
                      audioHandler.seek(Duration(milliseconds: milliseconds));
                    }
                  : null,
            ),
          ),
          SizedBox(height: 6),
          ProfileCountRow(
            likeCount: likeCount,
            commentCount: commentCount,
            isLiked: isLiked,
            onLikeTap: toggleLike,
            onCommentTap: openDetails,
          ),
        ],
      ),
    );
  }
}
