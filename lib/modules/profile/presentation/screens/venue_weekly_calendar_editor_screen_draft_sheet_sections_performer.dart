part of 'venue_weekly_calendar_editor_screen.dart';

extension _VenueEventDraftSheetStateSectionsPerformer
    on _VenueEventDraftSheetState {
  Widget _buildDraftSheetPerformerSection() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Performer'),
          _fieldFrame(
            active: _performerFocusNode.hasFocus,
            child: TextField(
              controller: _performerController,
              focusNode: _performerFocusNode,
              onChanged: (value) {
                final trimmed = value.trim();
                if (_selectedMusicianId != null &&
                    trimmed != (_selectedMusicianLabel ?? '').trim()) {
                  _selectedMusicianId = null;
                  _selectedMusicianLabel = null;
                }
                _searchDebounce?.cancel();
                _searchDebounce = Timer(
                  Duration(milliseconds: 320),
                  () => _runSearch(trimmed),
                );
                _updateState(() {});
              },
              decoration: InputDecoration(
                labelText: 'ÃƒÆ’Ã¢â‚¬Â¡alacak sanatÃƒÆ’Ã‚Â§Ãƒâ€Ã‚Â± / grup',
                hintText:
                    'Ãƒâ€Ã‚Â°sim yaz, eÃƒâ€¦Ã…Â¸leÃƒâ€¦Ã…Â¸irse profile baÃƒâ€Ã…Â¸lanÃƒâ€Ã‚Â±r',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 18,
                ),
                prefixIcon: Padding(
                  padding: EdgeInsets.only(left: 14, right: 10),
                  child: Icon(
                    Icons.search,
                    size: 19,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                prefixIconConstraints: BoxConstraints(
                  minWidth: 0,
                  minHeight: 0,
                ),
                suffixIcon: _selectedMusicianId != null
                    ? _gradientIcon(Icons.verified_rounded)
                    : null,
              ),
            ),
          ),
          if (_selectedMusicianId != null) ...[
            SizedBox(height: 10),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                if (_selectedMusicianId == null ||
                    _selectedMusicianId!.isEmpty) {
                  return;
                }
                Navigator.of(context).pushNamed(
                  AppRoutes.musicianPublicProfile,
                  arguments: {
                    'profileId': _selectedMusicianId,
                    'viewerUserId': widget.ownerProfile.ownerUserId,
                  },
                );
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.navBlueDeep.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainer,
                      backgroundImage:
                          _selectedMusicianImageUrl != null &&
                              _selectedMusicianImageUrl!.startsWith('http')
                          ? NetworkImage(_selectedMusicianImageUrl!)
                          : null,
                      child:
                          _selectedMusicianImageUrl == null ||
                              !_selectedMusicianImageUrl!.startsWith('http')
                          ? Icon(
                              Icons.person_outline,
                              size: 18,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            )
                          : null,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedMusicianLabel ?? 'SoundConnect Profili',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (_selectedMusicianSecondaryLabel != null)
                            Text(
                              _selectedMusicianSecondaryLabel!,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),
                    _gradientIcon(Icons.open_in_new_rounded, size: 18),
                  ],
                ),
              ),
            ),
          ],
          if (_searchLoading) ...[
            SizedBox(height: 10),
            LinearProgressIndicator(minHeight: 2),
          ] else if (_searchResults.isNotEmpty) ...[
            SizedBox(height: 10),
            Container(
              constraints: BoxConstraints(maxHeight: 190),
              decoration: BoxDecoration(
                color: AppColors.navBlueDeep.withValues(alpha: 0.68),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _searchResults.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: Theme.of(context).dividerColor),
                itemBuilder: (context, index) {
                  final item = _searchResults[index];
                  return ListTile(
                    onTap: () {
                      _performerController.text = item.displayName;
                      _performerController.selection = TextSelection.collapsed(
                        offset: _performerController.text.length,
                      );
                      _updateState(() {
                        _selectedMusicianId = item.profileId;
                        _selectedMusicianLabel = item.displayName;
                        _selectedMusicianSecondaryLabel = item.secondaryLabel;
                        _selectedMusicianImageUrl = item.profilePictureUrl;
                        _searchResults = [];
                        _searchError = null;
                      });
                    },
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainer,
                      backgroundImage:
                          item.profilePictureUrl != null &&
                              item.profilePictureUrl!.startsWith('http')
                          ? NetworkImage(item.profilePictureUrl!)
                          : null,
                      child:
                          item.profilePictureUrl == null ||
                              !item.profilePictureUrl!.startsWith('http')
                          ? Icon(
                              Icons.person_outline,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            )
                          : null,
                    ),
                    title: Text(
                      item.displayName,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: item.secondaryLabel == null
                        ? null
                        : Text(
                            item.secondaryLabel!,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                  );
                },
              ),
            ),
          ] else if (_searchError != null &&
              _performerController.text.trim().length >= 2) ...[
            SizedBox(height: 8),
            Text(
              _searchError!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
