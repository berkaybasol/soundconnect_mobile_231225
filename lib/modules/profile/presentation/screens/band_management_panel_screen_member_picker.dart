part of 'band_management_panel_screen.dart';

extension _BandManagementPanelScreenStateMemberPicker
    on _BandManagementPanelScreenState {
  Future<MusicianSearchOption?> _showMusicianPicker() async {
    final queryController = TextEditingController();
    Timer? searchDebounce;
    int lastSearchToken = 0;

    final selected = await showModalBottomSheet<MusicianSearchOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.navBlueDeep,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        var loading = false;
        var results = <MusicianSearchOption>[];
        var errorText = '';
        final existingUsernames = _profile.members
            .map((member) => member.username.trim().toLowerCase())
            .toSet();

        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> runSearch() async {
              final query = queryController.text.trim();
              final token = ++lastSearchToken;
              if (query.length < 2) {
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

              final result = await _musicianSearchRepository.search(query);
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
                            hintText: 'Müzisyen ara...',
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
                              final musician = results[index];
                              final alreadyMember = existingUsernames.contains(
                                musician.displayName.trim().toLowerCase(),
                              );
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
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainer,
                                      backgroundImage:
                                          musician.profilePictureUrl
                                                  ?.trim()
                                                  .isNotEmpty ==
                                              true
                                          ? NetworkImage(
                                              musician.profilePictureUrl!,
                                            )
                                          : null,
                                      child:
                                          musician.profilePictureUrl
                                                  ?.trim()
                                                  .isNotEmpty ==
                                              true
                                          ? null
                                          : Icon(
                                              Icons.person_outline,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                            ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            musician.displayName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: alreadyMember
                                                  ? Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant
                                                  : Theme.of(
                                                      context,
                                                    ).colorScheme.onSurface,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          if ((musician.secondaryLabel ?? '')
                                              .isNotEmpty) ...[
                                            SizedBox(height: 3),
                                            Text(
                                              musician.secondaryLabel!,
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
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    if (alreadyMember)
                                      Text(
                                        'Üye',
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      )
                                    else
                                      IconButton(
                                        onPressed: () => Navigator.of(
                                          sheetContext,
                                        ).pop(musician),
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
    queryController.dispose();
    return selected;
  }
}
