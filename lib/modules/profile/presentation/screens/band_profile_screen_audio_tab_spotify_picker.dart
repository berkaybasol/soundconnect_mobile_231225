part of 'band_profile_screen.dart';

extension _BandAudioTabSpotifyPicker on _BandAudioTab {
  Future<SpotifyTrackPreview?> _showSpotifyTrackPicker(
    BuildContext context,
    List<SpotifyTrackPreview> currentTracks, {
    Future<bool> Function(SpotifyTrackPreview track)? onTrackSelected,
  }) async {
    final queryController = TextEditingController();
    final repository = serviceLocator<SpotifyRepository>();
    Timer? searchDebounce;
    int lastSearchToken = 0;

    final selected = await showModalBottomSheet<SpotifyTrackPreview>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.navBlueDeep,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        var loading = false;
        var results = <SpotifyTrackPreview>[];
        var errorText = '';
        final existingIds = currentTracks.map((e) => e.id).toSet();
        final savingIds = <String>{};

        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> selectTrack(SpotifyTrackPreview track) async {
              if (existingIds.contains(track.id) ||
                  savingIds.contains(track.id)) {
                return;
              }
              if (onTrackSelected == null) {
                Navigator.of(sheetContext).pop(track);
                return;
              }
              setSheetState(() {
                savingIds.add(track.id);
                errorText = '';
              });
              final ok = await onTrackSelected(track);
              if (!sheetContext.mounted) return;
              setSheetState(() {
                savingIds.remove(track.id);
                if (ok) {
                  existingIds.add(track.id);
                } else {
                  errorText = 'Spotify parçası eklenemedi.';
                }
              });
            }

            Future<void> runSearch() async {
              final q = queryController.text.trim();
              final token = ++lastSearchToken;
              if (q.length < 2) {
                setSheetState(() {
                  results = [];
                  errorText = 'En az 2 karakter yaz.';
                });
                return;
              }

              setSheetState(() {
                loading = true;
                errorText = '';
              });

              final result = await repository.searchTracks(q, limit: 10);
              if (!sheetContext.mounted || token != lastSearchToken) return;

              setSheetState(() {
                loading = false;
                if (result.isSuccess && result.data != null) {
                  results = result.data!;
                  if (results.isEmpty) {
                    errorText = 'Sonuç bulunamadı.';
                  }
                } else {
                  errorText = result.error?.message ?? 'Arama başarısız.';
                }
              });
            }

            return AnimatedPadding(
              duration: Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SafeArea(
                top: false,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.78,
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: Column(
                      children: [
                        TextField(
                          controller: queryController,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => runSearch(),
                          onChanged: (value) {
                            searchDebounce?.cancel();
                            if (value.trim().length >= 2) {
                              searchDebounce = Timer(
                                Duration(milliseconds: 320),
                                runSearch,
                              );
                            } else {
                              setSheetState(() {
                                results = [];
                                errorText = '';
                              });
                            }
                          },
                          decoration: InputDecoration(
                            hintText: 'Spotify parçası ara...',
                            prefixIcon: Icon(Icons.search),
                            suffixIcon: IconButton(
                              onPressed: runSearch,
                              icon: Icon(Icons.arrow_forward),
                            ),
                          ),
                        ),
                        SizedBox(height: 12),
                        if (loading) ...[
                          LinearProgressIndicator(minHeight: 2),
                          SizedBox(height: 12),
                        ],
                        if (!loading && errorText.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Text(
                              errorText,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        Expanded(
                          child: ListView.separated(
                            itemCount: results.length,
                            separatorBuilder: (_, __) => SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final track = results[index];
                              final alreadyAdded = existingIds.contains(
                                track.id,
                              );
                              final saving = savingIds.contains(track.id);
                              return Container(
                                padding: EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Theme.of(context).dividerColor,
                                  ),
                                ),
                                child: Row(
                                  children: [
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
                                              color: alreadyAdded
                                                  ? Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant
                                                  : Theme.of(
                                                      context,
                                                    ).colorScheme.onSurface,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          SizedBox(height: 3),
                                          Text(
                                            track.artistNames.join(', '),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    if (alreadyAdded)
                                      Text(
                                        'Eklendi',
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      )
                                    else if (saving)
                                      SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    else
                                      IconButton(
                                        onPressed: () => selectTrack(track),
                                        icon: Icon(
                                          Icons.add_circle_outline,
                                          color: AppColors.coralAlt,
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
              ),
            );
          },
        );
      },
    );

    searchDebounce?.cancel();
    return selected;
  }
}
