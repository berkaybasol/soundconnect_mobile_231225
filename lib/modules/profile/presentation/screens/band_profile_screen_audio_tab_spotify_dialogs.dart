part of 'band_profile_screen.dart';

extension _BandAudioTabSpotifyCatalogDialogs on _BandAudioTab {
  Future<void> _openExternalUrl(BuildContext context, String? url) async {
    final parsed = Uri.tryParse(url ?? '');
    if (parsed == null) return;
    final ok = await launchUrl(parsed, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Link acilamadi')));
    }
  }

  Future<void> _showSpotifyCatalog(BuildContext context) async {
    final visibleTracks = List<SpotifyTrackPreview>.from(spotifyTracks);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.navBlueDeep,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        String? feedbackText;
        bool feedbackIsError = false;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<bool> saveTracks(
              List<SpotifyTrackPreview> nextTracks, {
              required String failureMessage,
            }) async {
              final ok = await onSaveSpotifyTracks(
                nextTracks,
                failureMessage: failureMessage,
              );
              if (!sheetContext.mounted) return false;
              if (!ok) {
                setSheetState(() {
                  feedbackText = failureMessage;
                  feedbackIsError = true;
                });
              }
              return ok;
            }

            Future<void> addTrack() async {
              await _showSpotifyTrackPicker(
                context,
                visibleTracks,
                onTrackSelected: (selected) async {
                  if (visibleTracks.any((track) => track.id == selected.id)) {
                    setSheetState(() {
                      feedbackText = 'Bu parça zaten ekli.';
                      feedbackIsError = true;
                    });
                    return true;
                  }

                  final nextTracks = [...visibleTracks, selected];
                  final ok = await saveTracks(
                    nextTracks,
                    failureMessage: 'Spotify parçası eklenemedi.',
                  );
                  if (!ok || !sheetContext.mounted) return false;

                  setSheetState(() {
                    visibleTracks
                      ..clear()
                      ..addAll(nextTracks);
                    feedbackText = 'Spotify parçası eklendi.';
                    feedbackIsError = false;
                  });
                  return true;
                },
              );
            }

            Future<void> removeTrack(SpotifyTrackPreview track) async {
              final nextTracks = visibleTracks
                  .where((item) => item.id != track.id)
                  .toList();
              final ok = await saveTracks(
                nextTracks,
                failureMessage: 'Spotify parçası kaldırılamadı.',
              );
              if (!ok || !sheetContext.mounted) return;

              setSheetState(() {
                visibleTracks
                  ..clear()
                  ..addAll(nextTracks);
                feedbackText = 'Spotify parçası kaldırıldı.';
                feedbackIsError = false;
              });
            }

            return FractionallySizedBox(
              heightFactor: 0.88,
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Theme.of(context).dividerColor,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Band Spotify Kataloğu',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (editable)
                            IconButton(
                              tooltip: 'Spotify parçası ekle',
                              onPressed: addTrack,
                              icon: Icon(Icons.add_circle_outline),
                            ),
                        ],
                      ),
                      if (feedbackText != null) ...[
                        SizedBox(height: 8),
                        Text(
                          feedbackText!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: feedbackIsError
                                ? AppColors.coralAlt
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      SizedBox(height: 12),
                      Expanded(
                        child: visibleTracks.isEmpty
                            ? Center(
                                child: Text(
                                  'Spotify parçası yok.',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                itemCount: visibleTracks.length,
                                separatorBuilder: (_, __) =>
                                    SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final track = visibleTracks[index];
                                  final albumArtUrl =
                                      isValidNetworkImageUrl(
                                        track.albumImageUrl,
                                      )
                                      ? track.albumImageUrl!.trim()
                                      : null;
                                  return Container(
                                    padding: EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Theme.of(context).dividerColor,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.surfaceContainer,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            image: albumArtUrl != null
                                                ? DecorationImage(
                                                    image: NetworkImage(
                                                      albumArtUrl,
                                                    ),
                                                    fit: BoxFit.cover,
                                                  )
                                                : null,
                                          ),
                                          child: albumArtUrl == null
                                              ? Icon(
                                                  Icons.music_note,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                )
                                              : null,
                                        ),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                track.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.onSurface,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                track.artistNames.join(', '),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        TextButton(
                                          onPressed: () => _openExternalUrl(
                                            context,
                                            track.spotifyUrl,
                                          ),
                                          child: Text(
                                            "Spotify'da Dinle",
                                            style: TextStyle(
                                              color: AppColors.spotifyGreen,
                                            ),
                                          ),
                                        ),
                                        if (editable)
                                          IconButton(
                                            tooltip: 'Kaldir',
                                            onPressed: () => removeTrack(track),
                                            icon: Icon(
                                              Icons.delete_outline,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
