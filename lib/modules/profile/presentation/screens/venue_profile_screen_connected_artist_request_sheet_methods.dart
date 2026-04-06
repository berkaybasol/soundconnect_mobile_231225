part of 'venue_profile_screen.dart';

extension _ConnectedArtistRequestSheetStateMethods
    on _ConnectedArtistRequestSheetState {
  void _onQueryChanged(String raw) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 280),
      () => _runSearch(raw),
    );
  }

  Future<void> _runSearch(String raw) async {
    final trimmed = raw.trim();
    _query = trimmed;
    final token = ++_searchToken;
    if (trimmed.length < 2) {
      _updateState(() {
        _loading = false;
        _searchError = '';
        _results = const <MusicianSearchOption>[];
      });
      return;
    }
    _updateState(() {
      _loading = true;
      _searchError = '';
    });
    try {
      final response = await widget.searchMusicians(trimmed);
      if (!mounted || token != _searchToken) return;
      _updateState(() {
        _loading = false;
        _results = response;
        if (response.isEmpty) {
          _searchError = 'Sonuc bulunamadi.';
        }
      });
    } catch (_) {
      if (!mounted || token != _searchToken) return;
      _updateState(() {
        _loading = false;
        _results = const <MusicianSearchOption>[];
        _searchError = 'Sanatci aramasi yapilamadi.';
      });
    }
  }

  void _toggleSelection(MusicianSearchOption item) {
    final checked = _selectedMusicianId == item.profileId;
    final isAccepted = widget.acceptedIds.contains(item.profileId);
    final isPending = widget.pendingIds.contains(item.profileId);

    if (isAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu muzisyen zaten profilinde bagli.')),
      );
      return;
    }
    if (isPending) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bu muzisyene zaten basvurdun (beklemede).'),
        ),
      );
      return;
    }

    _updateState(() {
      _selectedMusicianId = checked ? null : item.profileId;
    });
  }

  Future<String?> _showOptionalMessageDialog() async {
    var noteDraft = '';
    return showDialog<String>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (dialogContext) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Dialog(
            backgroundColor: AppColors.navBlueDeep,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Basvuru Notu (Opsiyonel)',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      minLines: 3,
                      maxLines: 5,
                      onChanged: (value) {
                        noteDraft = value;
                      },
                      decoration: const InputDecoration(
                        hintText:
                            'Istersen kisa bir not ekleyebilirsin (zorunlu degil).',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: const Text('Vazgec'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(
                              dialogContext,
                            ).pop(noteDraft.trim()),
                            child: const Text('Gonder'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _continue() async {
    final selectedMusicianId = _selectedMusicianId;
    if (selectedMusicianId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Lutfen bir muzisyen sec.')));
      return;
    }
    final message = await _showOptionalMessageDialog();
    if (message == null || !mounted) return;
    Navigator.of(context).pop(
      MusicianRequestPayload(
        musicianProfileId: selectedMusicianId,
        message: message,
      ),
    );
  }
}
