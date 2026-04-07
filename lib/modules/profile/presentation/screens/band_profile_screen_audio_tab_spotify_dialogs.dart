part of 'band_profile_screen.dart';

extension _BandAudioTabSpotifyCatalogDialogs on _BandAudioTab {
  Future<void> _openExternalUrl(BuildContext context, String? url) async {
    final parsed = Uri.tryParse(url ?? '');
    if (parsed == null) return;
    final ok = await launchUrl(parsed, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Link acilamadi')));
    }
  }

  Future<void> _showSpotifyCatalog(BuildContext context) async {
    final visibleTracks = List<SpotifyTrackPreview>.from(spotifyTracks);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.navBlueDeep,
      shape: const RoundedRectangleBorder(
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
              final selected = await _showSpotifyTrackPicker(
                context,
                visibleTracks,
              );
              if (selected == null || !sheetContext.mounted) return;
              if (visibleTracks.any((track) => track.id == selected.id)) {
                setSheetState(() {
                  feedbackText = 'Bu parca zaten ekli.';
                  feedbackIsError = true;
                });
                return;
              }

              final nextTracks = [...visibleTracks, selected];
              final ok = await saveTracks(
                nextTracks,
                failureMessage: 'Spotify parcasi eklenemedi.',
              );
              if (!ok || !sheetContext.mounted) return;

              setSheetState(() {
                visibleTracks
                  ..clear()
                  ..addAll(nextTracks);
                feedbackText = 'Spotify parcasi eklendi.';
                feedbackIsError = false;
              });
            }

            Future<void> removeTrack(SpotifyTrackPreview track) async {
              final nextTracks = visibleTracks
                  .where((item) => item.id != track.id)
                  .toList();
              final ok = await saveTracks(
                nextTracks,
                failureMessage: 'Spotify parcasi kaldirilamadi.',
              );
              if (!ok || !sheetContext.mounted) return;

              setSheetState(() {
                visibleTracks
                  ..clear()
                  ..addAll(nextTracks);
                feedbackText = 'Spotify parcasi kaldirildi.';
                feedbackIsError = false;
              });
            }

            return FractionallySizedBox(
              heightFactor: 0.88,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Band Spotify Katalogu',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Spotify parcasi ekle',
                            onPressed: addTrack,
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                      if (feedbackText != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          feedbackText!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: feedbackIsError
                                ? AppColors.coralAlt
                                : AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Expanded(
                        child: visibleTracks.isEmpty
                            ? const Center(
                                child: Text(
                                  'Spotify parcasi yok.',
                                  style: TextStyle(color: AppColors.textMuted),
                                ),
                              )
                            : ListView.separated(
                                itemCount: visibleTracks.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final track = visibleTracks[index];
                                  return Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.inputFill,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppColors.border,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const FaIcon(
                                          FontAwesomeIcons.spotify,
                                          size: 16,
                                          color: Color(0xFF1DB954),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
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
                                        IconButton(
                                          tooltip: 'Spotify\'da ac',
                                          onPressed: () => _openExternalUrl(
                                            context,
                                            track.spotifyUrl,
                                          ),
                                          icon: const Icon(Icons.open_in_new),
                                        ),
                                        IconButton(
                                          tooltip: 'Kaldir',
                                          onPressed: () => removeTrack(track),
                                          icon: const Icon(Icons.close),
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
