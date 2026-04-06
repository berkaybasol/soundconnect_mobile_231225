// ignore_for_file: unused_element, unused_element_parameter, unused_local_variable, use_build_context_synchronously, invalid_use_of_protected_member

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
      shape: const RoundedRectangleBorder(
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
                  results = const [];
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
                    errorText = 'Sonuc bulunamadi.';
                  }
                } else {
                  errorText = result.error?.message ?? 'Arama basarisiz.';
                }
              });
            }

            return AnimatedPadding(
              duration: const Duration(milliseconds: 180),
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
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
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
                                const Duration(milliseconds: 320),
                                runSearch,
                              );
                            } else {
                              setSheetState(() {
                                results = const [];
                                errorText = '';
                              });
                            }
                          },
                          decoration: InputDecoration(
                            hintText: 'Muzisyen ara...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: IconButton(
                              onPressed: runSearch,
                              icon: const Icon(Icons.arrow_forward),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (loading) ...[
                          const LinearProgressIndicator(minHeight: 2),
                          const SizedBox(height: 12),
                        ],
                        if (!loading && errorText.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              errorText,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        Expanded(
                          child: ListView.separated(
                            itemCount: results.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final musician = results[index];
                              final alreadyMember = existingUsernames.contains(
                                musician.displayName.trim().toLowerCase(),
                              );
                              return Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.inputFill,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: AppColors.navBlueSoft,
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
                                          : const Icon(
                                              Icons.person_outline,
                                              color: AppColors.textMuted,
                                            ),
                                    ),
                                    const SizedBox(width: 12),
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
                                                  ? AppColors.textMuted
                                                  : AppColors.textPrimary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          if ((musician.secondaryLabel ?? '')
                                              .isNotEmpty) ...[
                                            const SizedBox(height: 3),
                                            Text(
                                              musician.secondaryLabel!,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: AppColors.textMuted,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (alreadyMember)
                                      const Text(
                                        'Uye',
                                        style: TextStyle(
                                          color: AppColors.textMuted,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      )
                                    else
                                      IconButton(
                                        onPressed: () => Navigator.of(
                                          sheetContext,
                                        ).pop(musician),
                                        icon: const Icon(
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
