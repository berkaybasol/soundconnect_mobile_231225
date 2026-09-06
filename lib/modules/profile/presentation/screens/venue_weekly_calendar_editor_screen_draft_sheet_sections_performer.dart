part of 'venue_weekly_calendar_editor_screen.dart';

extension _VenueEventDraftSheetStateSectionsPerformer
    on _VenueEventDraftSheetState {
  bool get _hasSelectedPerformer =>
      _selectedPerformer?.targetId.trim().isNotEmpty == true &&
      _supportsTargetType(_selectedPerformer?.type);

  bool _supportsTargetType(ProfileSearchResultType? type) =>
      type == ProfileSearchResultType.musician ||
      type == ProfileSearchResultType.band;

  IconData _performerIcon(ProfileSearchResultType? type) {
    return type == ProfileSearchResultType.band
        ? Icons.groups_2_outlined
        : Icons.person_outline_rounded;
  }

  String _performerSubtitle(ProfileSearchResult item) {
    if (item.type == ProfileSearchResultType.band) return 'Grup';
    final raw = item.subtitle?.trim() ?? '';
    if (raw.isEmpty || raw == item.title) return 'Müzisyen';
    final username = raw.startsWith('@') ? raw : '@$raw';
    return 'Müzisyen • $username';
  }

  void _openSelectedPerformer() {
    final performerId = _selectedPerformer?.targetId.trim() ?? '';
    if (performerId.isEmpty) return;
    if (_selectedPerformer?.type == ProfileSearchResultType.band) {
      Navigator.of(context).pushNamed(
        AppRoutes.bandPublicProfile,
        arguments: BandProfileScreenArgs(
          bandId: performerId,
          viewMode: BandProfileViewMode.public,
        ),
      );
      return;
    }
    if (_selectedPerformer?.type == ProfileSearchResultType.musician) {
      Navigator.of(context).pushNamed(
        AppRoutes.musicianPublicProfile,
        arguments: {
          'profileId': performerId,
          'viewerUserId': widget.ownerProfile.ownerUserId,
        },
      );
    }
  }

  Widget _buildDraftSheetPerformerSection() {
    final scheme = Theme.of(context).colorScheme;
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Sanatçı', icon: Icons.mic_external_on_outlined),
          _fieldFrame(
            active: _performerFocusNode.hasFocus,
            child: TextField(
              controller: _performerController,
              focusNode: _performerFocusNode,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _performerFocusNode.unfocus(),
              onChanged: (value) {
                final trimmed = value.trim();
                final searchToken = ++_searchToken;
                _searchDebounce?.cancel();
                _updateState(() {
                  _formError = null;
                  _searchResults = [];
                  _searchError = null;
                  _searchLoading = trimmed.length >= 2;
                  if (_hasSelectedPerformer &&
                      trimmed != (_selectedPerformer?.title ?? '').trim()) {
                    _selectedPerformer = null;
                  }
                });
                if (trimmed.length < 2) return;
                _searchDebounce = Timer(
                  const Duration(milliseconds: 320),
                  () => _runSearch(trimmed, searchToken),
                );
              },
              decoration: InputDecoration(
                labelText: 'Sanatçı veya grup',
                hintText: 'Profil ara ya da isim yaz',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 16,
                ),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 14, right: 10),
                  child: Icon(
                    Icons.search_rounded,
                    size: 19,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 0,
                  minHeight: 0,
                ),
                suffixIcon: _hasSelectedPerformer
                    ? Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: _gradientIcon(Icons.verified_rounded, size: 19),
                      )
                    : null,
                suffixIconConstraints: const BoxConstraints(
                  minWidth: 0,
                  minHeight: 0,
                ),
              ),
            ),
          ),
          if (_hasSelectedPerformer) ...[
            const SizedBox(height: 10),
            Material(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _openSelectedPerformer,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        padding: const EdgeInsets.all(1),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: AppColors.brandGradient,
                          ),
                        ),
                        child: ClipOval(
                          child: ColoredBox(
                            color: scheme.surfaceContainer,
                            child:
                                _selectedPerformer?.imageUrl != null &&
                                    _selectedPerformer!.imageUrl!.startsWith(
                                      'http',
                                    )
                                ? AppCachedNetworkImage(
                                    imageUrl: _selectedPerformer!.imageUrl,
                                    width: 38,
                                    height: 38,
                                    fit: BoxFit.cover,
                                    cacheWidth: 114,
                                    cacheHeight: 114,
                                    errorBuilder: (_) => Icon(
                                      _performerIcon(_selectedPerformer?.type),
                                      size: 19,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  )
                                : Icon(
                                    _performerIcon(_selectedPerformer?.type),
                                    size: 19,
                                    color: scheme.onSurfaceVariant,
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedPerformer?.title ??
                                  'SoundConnect profili',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: scheme.onSurface,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _selectedPerformer != null
                                  ? _performerSubtitle(_selectedPerformer!)
                                  : 'Bağlı profil',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_outward_rounded,
                        size: 18,
                        color: scheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (_searchLoading) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(minHeight: 2),
          ] else if (_searchResults.isNotEmpty) ...[
            const SizedBox(height: 10),
            ConstrainedBox(
              key: _performerResultsKey,
              constraints: const BoxConstraints(maxHeight: 200),
              child: Material(
                color: scheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Theme.of(context).dividerColor),
                ),
                clipBehavior: Clip.antiAlias,
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: _searchResults.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: Theme.of(context).dividerColor),
                  itemBuilder: (context, index) {
                    final item = _searchResults[index];
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                      onTap: () {
                        final targetId = item.targetId.trim();
                        final supportedType = _supportsTargetType(item.type);
                        if (targetId.isEmpty ||
                            item.title.trim().isEmpty ||
                            !supportedType) {
                          _setFormError(
                            'Bu profil etkinliğe eklenmek için geçerli değil.',
                          );
                          return;
                        }
                        _searchDebounce?.cancel();
                        _searchToken++;
                        _performerFocusNode.unfocus();
                        _performerController.text = item.title;
                        _performerController.selection =
                            TextSelection.collapsed(
                              offset: _performerController.text.length,
                            );
                        _updateState(() {
                          _selectedPerformer = ProfileSearchResult(
                            type: item.type,
                            targetId: targetId,
                            userId: item.userId,
                            title: item.title.trim(),
                            subtitle: item.subtitle,
                            imageUrl: item.imageUrl,
                            visibilityMode: item.visibilityMode,
                          );
                          _searchResults = [];
                          _searchError = null;
                          _searchLoading = false;
                          _formError = null;
                        });
                      },
                      leading: CircleAvatar(
                        radius: 17,
                        backgroundColor: scheme.surfaceContainer,
                        child: ClipOval(
                          child:
                              item.imageUrl != null &&
                                  item.imageUrl!.startsWith('http')
                              ? AppCachedNetworkImage(
                                  imageUrl: item.imageUrl,
                                  width: 34,
                                  height: 34,
                                  fit: BoxFit.cover,
                                  cacheWidth: 102,
                                  cacheHeight: 102,
                                  errorBuilder: (_) => Icon(
                                    _performerIcon(item.type),
                                    size: 18,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                )
                              : Icon(
                                  _performerIcon(item.type),
                                  size: 18,
                                  color: scheme.onSurfaceVariant,
                                ),
                        ),
                      ),
                      title: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        _performerSubtitle(item),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                      trailing: Icon(
                        Icons.add_rounded,
                        color: scheme.onSurfaceVariant,
                        size: 19,
                      ),
                    );
                  },
                ),
              ),
            ),
          ] else if (_searchError != null &&
              _performerController.text.trim().length >= 2) ...[
            const SizedBox(height: 8),
            Text(
              _searchError!,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11.5),
            ),
          ],
        ],
      ),
    );
  }
}
