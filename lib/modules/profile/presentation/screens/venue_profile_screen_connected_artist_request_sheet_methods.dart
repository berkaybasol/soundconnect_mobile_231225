part of 'venue_profile_screen.dart';

extension _ConnectedArtistRequestSheetStateMethods
    on _ConnectedArtistRequestSheetState {
  void _onQueryChanged(String raw) {
    _searchDebounce?.cancel();
    // Invalidate at input time, not when the next debounced request starts.
    _searchToken++;
    _updateState(() {
      _query = raw.trim();
      _results = [];
      _selectedTargetKey = null;
      _searchError = '';
      _loading = false;
    });
    if (_query.length < 2) return;
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
        _results = response
            .where(
              (item) =>
                  item.targetId.trim().isNotEmpty &&
                  (item.type == ProfileSearchResultType.band ||
                      item.type == ProfileSearchResultType.musician),
            )
            .toList();
        if (_results.isEmpty) {
          _searchError = 'Sonuç bulunamadı.';
        }
      });
    } catch (_) {
      if (!mounted || token != _searchToken) return;
      _updateState(() {
        _loading = false;
        _results = <ProfileSearchResult>[];
        _searchError = 'Sanatçı araması yapılamadı.';
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
        appSnackBar(
          context,
          tone: AppSnackBarTone.warning,
          content: Text('Bu sanatçı zaten profilinde bağlı.'),
        ),
      );
      return;
    }
    if (isPending) {
      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar(
          context,
          tone: AppSnackBarTone.warning,
          content: Text('Bu sanatçıya zaten başvurdun (beklemede).'),
        ),
      );
      return;
    }

    _updateState(() {
      _selectedTargetKey = checked ? null : targetKey;
    });
  }

  Future<String?> _showOptionalMessageDialog() async {
    var noteDraft = '';
    var decisionDelivered = false;
    final noteForm = GlobalKey<FormState>();
    return showDialog<String>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      barrierColor: AppColors.pureBlack.withValues(alpha: 0.35),
      builder: (dialogContext) {
        void decide({required bool send}) {
          if (decisionDelivered ||
              !dialogContext.mounted ||
              ModalRoute.of(dialogContext)?.isCurrent != true) {
            return;
          }
          if (send && noteForm.currentState?.validate() != true) {
            return;
          }
          decisionDelivered = true;
          Navigator.of(dialogContext).pop(send ? noteDraft.trim() : null);
        }

        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Dialog(
            backgroundColor: AppColors.navBlueDeep,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Form(
                key: noteForm,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'İstek notu (isteğe bağlı)',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 10),
                      TextFormField(
                        minLines: 3,
                        maxLines: 5,
                        validator: (value) => (value?.trim().length ?? 0) > 255
                            ? 'Not en fazla 255 karakter olabilir.'
                            : null,
                        onChanged: (value) {
                          noteDraft = value;
                        },
                        decoration: InputDecoration(
                          hintText: 'İstersen kısa bir not ekleyebilirsin.',
                        ),
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => decide(send: false),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: Text('Vazgeç'),
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: GradientOutlineButton(
                              onPressed: () => decide(send: true),
                              strokeWidth: 1,
                              horizontalPadding: 12,
                              label: 'Gönder',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _continue() async {
    if (!mounted || _continuing || _loading) return;
    final selectedTargetKey = _selectedTargetKey;
    if (selectedTargetKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar(
          context,
          tone: AppSnackBarTone.warning,
          content: Text('Lütfen bir müzisyen veya grup seç.'),
        ),
      );
      return;
    }
    ProfileSearchResult? selected;
    for (final item in _results) {
      if (_connectionKey(item) == selectedTargetKey) {
        selected = item;
        break;
      }
    }
    if (selected == null) return;
    final origin = ModalRoute.of(context);
    _updateState(() => _continuing = true);
    try {
      final message = await _showOptionalMessageDialog();
      if (message == null || !mounted || origin?.isCurrent == false) return;
      Navigator.of(context).pop(
        ConnectedArtistRequestPayload(
          type: selected.type == ProfileSearchResultType.band
              ? ConnectedArtistType.band
              : ConnectedArtistType.musician,
          targetId: selected.targetId,
          message: message,
        ),
      );
    } finally {
      _updateState(() => _continuing = false);
    }
  }

  String _connectionKey(ProfileSearchResult item) {
    final prefix = item.type == ProfileSearchResultType.band
        ? 'BAND'
        : 'MUSICIAN';
    return '$prefix:${item.targetId}';
  }
}
