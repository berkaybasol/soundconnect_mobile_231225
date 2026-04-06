// ignore_for_file: invalid_use_of_protected_member

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
                  const Duration(milliseconds: 320),
                  () => _runSearch(trimmed),
                );
                setState(() {});
              },
              decoration: InputDecoration(
                labelText: 'ÃƒÆ’Ã¢â‚¬Â¡alacak sanatÃƒÆ’Ã‚Â§Ãƒâ€Ã‚Â± / grup',
                hintText:
                    'Ãƒâ€Ã‚Â°sim yaz, eÃƒâ€¦Ã…Â¸leÃƒâ€¦Ã…Â¸irse profile baÃƒâ€Ã…Â¸lanÃƒâ€Ã‚Â±r',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 18,
                ),
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(left: 14, right: 10),
                  child: Icon(
                    Icons.search,
                    size: 19,
                    color: AppColors.textMuted,
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(
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
            const SizedBox(height: 10),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.navBlueDeep.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.navBlueSoft,
                      backgroundImage:
                          _selectedMusicianImageUrl != null &&
                              _selectedMusicianImageUrl!.startsWith('http')
                          ? NetworkImage(_selectedMusicianImageUrl!)
                          : null,
                      child:
                          _selectedMusicianImageUrl == null ||
                              !_selectedMusicianImageUrl!.startsWith('http')
                          ? const Icon(
                              Icons.person_outline,
                              size: 18,
                              color: AppColors.textMuted,
                            )
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedMusicianLabel ?? 'SoundConnect Profili',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (_selectedMusicianSecondaryLabel != null)
                            Text(
                              _selectedMusicianSecondaryLabel!,
                              style: const TextStyle(
                                color: AppColors.textMuted,
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
            const SizedBox(height: 10),
            const LinearProgressIndicator(minHeight: 2),
          ] else if (_searchResults.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              constraints: const BoxConstraints(maxHeight: 190),
              decoration: BoxDecoration(
                color: AppColors.navBlueDeep.withValues(alpha: 0.68),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _searchResults.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: AppColors.border),
                itemBuilder: (context, index) {
                  final item = _searchResults[index];
                  return ListTile(
                    onTap: () {
                      _performerController.text = item.displayName;
                      _performerController.selection = TextSelection.collapsed(
                        offset: _performerController.text.length,
                      );
                      setState(() {
                        _selectedMusicianId = item.profileId;
                        _selectedMusicianLabel = item.displayName;
                        _selectedMusicianSecondaryLabel = item.secondaryLabel;
                        _selectedMusicianImageUrl = item.profilePictureUrl;
                        _searchResults = const [];
                        _searchError = null;
                      });
                    },
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.navBlueSoft,
                      backgroundImage:
                          item.profilePictureUrl != null &&
                              item.profilePictureUrl!.startsWith('http')
                          ? NetworkImage(item.profilePictureUrl!)
                          : null,
                      child:
                          item.profilePictureUrl == null ||
                              !item.profilePictureUrl!.startsWith('http')
                          ? const Icon(
                              Icons.person_outline,
                              color: AppColors.textMuted,
                            )
                          : null,
                    ),
                    title: Text(
                      item.displayName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: item.secondaryLabel == null
                        ? null
                        : Text(
                            item.secondaryLabel!,
                            style: const TextStyle(color: AppColors.textMuted),
                          ),
                  );
                },
              ),
            ),
          ] else if (_searchError != null &&
              _performerController.text.trim().length >= 2) ...[
            const SizedBox(height: 8),
            Text(
              _searchError!,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
