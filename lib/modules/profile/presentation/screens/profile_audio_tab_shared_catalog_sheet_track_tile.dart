part of 'profile_audio_tab_shared.dart';

class _SpotifyCatalogTrackTile extends StatelessWidget {
  final SpotifyTrackPreview track;
  final bool ownerMode;
  final Future<bool> Function() onConfirmDismiss;
  final VoidCallback onOpenOnSpotify;
  final VoidCallback onRemove;
  final bool actionsEnabled;
  final int? reorderIndex;

  _SpotifyCatalogTrackTile({
    required this.track,
    required this.ownerMode,
    required this.onConfirmDismiss,
    required this.onOpenOnSpotify,
    required this.onRemove,
    this.actionsEnabled = true,
    this.reorderIndex,
  });

  @override
  Widget build(BuildContext context) {
    final albumArtUrl = isValidNetworkImageUrl(track.albumImageUrl)
        ? track.albumImageUrl!.trim()
        : null;

    return Dismissible(
      key: ValueKey('spotify-track-${track.id}'),
      direction: ownerMode && actionsEnabled
          ? DismissDirection.endToStart
          : DismissDirection.none,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Color(0xFFB3261E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.delete_outline, color: AppColors.white),
      ),
      confirmDismiss: ownerMode && actionsEnabled
          ? (_) => onConfirmDismiss()
          : null,
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
                image: albumArtUrl != null
                    ? DecorationImage(
                        image: NetworkImage(albumArtUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: albumArtUrl == null
                  ? Icon(
                      Icons.music_note,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    )
                  : null,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    track.artistNames.join(', '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8),
            TextButton(
              onPressed: onOpenOnSpotify,
              child: Text(
                "Spotify'da Dinle",
                style: TextStyle(color: AppColors.spotifyGreen),
              ),
            ),
            if (ownerMode)
              IconButton(
                tooltip: 'Katalogdan kaldir',
                onPressed: actionsEnabled ? onRemove : null,
                icon: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            if (ownerMode && reorderIndex != null)
              ReorderableDragStartListener(
                key: ValueKey('spotify-reorder-handle-${track.id}'),
                index: reorderIndex!,
                enabled: actionsEnabled,
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(
                    Icons.drag_handle_rounded,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
