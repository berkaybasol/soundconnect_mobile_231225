part of 'profile_audio_tab_shared.dart';

class _SpotifyCatalogTrackTile extends StatelessWidget {
  final SpotifyTrackPreview track;
  final bool ownerMode;
  final Future<bool> Function() onConfirmDismiss;
  final VoidCallback onOpenOnSpotify;
  final VoidCallback onRemove;

  const _SpotifyCatalogTrackTile({
    required this.track,
    required this.ownerMode,
    required this.onConfirmDismiss,
    required this.onOpenOnSpotify,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final albumArtUrl = isValidNetworkImageUrl(track.albumImageUrl)
        ? track.albumImageUrl!.trim()
        : null;

    return Dismissible(
      key: ValueKey('spotify-track-${track.id}'),
      direction: ownerMode
          ? DismissDirection.endToStart
          : DismissDirection.none,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFB3261E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: ownerMode ? (_) => onConfirmDismiss() : null,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.inputFill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.navBlueSoft,
                borderRadius: BorderRadius.circular(12),
                image: albumArtUrl != null
                    ? DecorationImage(
                        image: NetworkImage(albumArtUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: albumArtUrl == null
                  ? const Icon(Icons.music_note, color: AppColors.textMuted)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    track.artistNames.join(', '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: onOpenOnSpotify,
              child: const Text(
                "Spotify'da Dinle",
                style: TextStyle(color: Color(0xFF1DB954)),
              ),
            ),
            if (ownerMode)
              IconButton(
                tooltip: 'Katalogdan kaldir',
                onPressed: onRemove,
                icon: const Icon(
                  Icons.delete_outline,
                  color: AppColors.textMuted,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
