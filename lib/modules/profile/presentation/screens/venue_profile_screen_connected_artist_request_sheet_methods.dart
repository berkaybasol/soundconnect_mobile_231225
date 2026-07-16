part of 'venue_profile_screen.dart';

extension _ConnectedArtistRequestSheetStateMethods
    on _ConnectedArtistRequestSheetState {
  void _onQueryChanged(String raw) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(Duration(milliseconds: 280), () => _runSearch(raw));
  }

  Future<void> _runSearch(String raw) async {
    final trimmed = raw.trim();
    _query = trimmed;
    final token = ++_searchToken;
    if (trimmed.length < 2) {
      _updateState(() {
        _loading = false;
        _searchError = '';
        _results = <ProfileSearchResult>[];
      });
      return;
    }
    _updateState(() {
      _loading = true;
      _searchError = '';
    });
    try {
      final response = await widget.searchArtists(trimmed);
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
        _results = <ProfileSearchResult>[];
        _searchError = 'Sanatci aramasi yapilamadi.';
      });
    }
  }

  void _toggleSelection(ProfileSearchResult item) {
    final targetKey = _connectionKey(item);
    final checked = _selectedTargetKey == targetKey;
    final isAccepted = widget.acceptedIds.contains(targetKey);
    final isPending = widget.pendingIds.contains(targetKey);

    if (isAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bu sanatci zaten profilinde bagli.')),
      );
      return;
    }
    if (isPending) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bu sanatciya zaten basvurdun (beklemede).')),
      );
      return;
    }

    _updateState(() {
      _selectedTargetKey = checked ? null : targetKey;
    });
  }

  Future<String?> _showOptionalMessageDialog() async {
    var noteDraft = '';
    return showDialog<String>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      barrierColor: AppColors.pureBlack.withValues(alpha: 0.35),
      builder: (dialogContext) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Dialog(
            backgroundColor: AppColors.navBlueDeep,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Basvuru Notu (Opsiyonel)',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 10),
                    TextField(
                      minLines: 3,
                      maxLines: 5,
                      onChanged: (value) {
                        noteDraft = value;
                      },
                      decoration: InputDecoration(
                        hintText:
                            'Istersen kisa bir not ekleyebilirsin (zorunlu degil).',
                      ),
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: Text('Vazgec'),
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(
                              dialogContext,
                            ).pop(noteDraft.trim()),
                            child: Text('Gonder'),
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
    final selectedTargetKey = _selectedTargetKey;
    if (selectedTargetKey == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lutfen bir muzisyen sec.')));
      return;
    }
    final message = await _showOptionalMessageDialog();
    if (message == null || !mounted) return;
    ProfileSearchResult? selected;
    for (final item in _results) {
      if (_connectionKey(item) == selectedTargetKey) {
        selected = item;
        break;
      }
    }
    if (selected == null) return;
    Navigator.of(context).pop(
      ConnectedArtistRequestPayload(
        type: selected.type == ProfileSearchResultType.band
            ? ConnectedArtistType.band
            : ConnectedArtistType.musician,
        targetId: selected.targetId,
        message: message,
      ),
    );
  }

  String _connectionKey(ProfileSearchResult item) {
    final prefix = item.type == ProfileSearchResultType.band
        ? 'BAND'
        : 'MUSICIAN';
    return '$prefix:${item.targetId}';
  }
}
