part of 'venue_weekly_calendar_editor_screen.dart';

extension _VenueEventDraftSheetStateMethods on _VenueEventDraftSheetState {
  void _handleFocusChanged() {
    if (mounted) {
      _updateState(() {});
    }
  }

  void _clearFormError() {
    if (_formError != null) {
      _updateState(() => _formError = null);
    }
  }

  void _setFormError(String message) {
    _updateState(() => _formError = message);
  }

  Future<void> _runSearch(String raw, int token) async {
    final query = raw.trim();
    if (token != _searchToken) return;
    if (query.length < 2) {
      _updateState(() {
        _searchLoading = false;
        _searchError = null;
        _searchResults = const [];
      });
      return;
    }
    _updateState(() {
      _searchLoading = true;
      _searchError = null;
    });
    try {
      final result = await _profileSearchRepository.searchProfiles(
        query,
        types: const {
          ProfileSearchResultType.musician,
          ProfileSearchResultType.band,
        },
      );
      if (!result.isSuccess) {
        throw result.error?.message ?? 'Arama yapılamadı.';
      }
      final results = (result.data ?? const <ProfileSearchResult>[])
          .where(
            (item) =>
                _supportsTargetType(item.type) &&
                item.targetId.trim().isNotEmpty &&
                item.title.trim().isNotEmpty,
          )
          .toList(growable: false);
      if (!mounted || token != _searchToken) return;
      _updateState(() {
        _searchLoading = false;
        _searchResults = results;
        _searchError = results.isEmpty ? 'Sonuç bulunamadı.' : null;
      });
      if (results.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || token != _searchToken || _searchResults.isEmpty) {
            return;
          }
          final resultsContext = _performerResultsKey.currentContext;
          if (resultsContext == null) return;
          Scrollable.ensureVisible(
            resultsContext,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: 0.35,
          );
        });
      }
    } catch (_) {
      if (!mounted || token != _searchToken) return;
      _updateState(() {
        _searchLoading = false;
        _searchResults = const [];
        _searchError = 'Arama şu anda yapılamıyor.';
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showSoundConnectDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
      helpText: 'Etkinlik tarihi',
    );
    if (!mounted || picked == null) return;
    _updateState(() {
      _selectedDate = picked;
      _formError = null;
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (_uncertainSubmission) {
      // Venue creation has no server-side replay key. Check the refreshed
      // list before explicitly starting another creation after a lost response.
      await _closeDraft();
      return;
    }
    final title = _titleController.text.trim();
    final performerText = _performerController.text.trim();
    if (_posterUploading) {
      _setFormError('Afiş yüklenirken lütfen bekle.');
      return;
    }
    if (title.isEmpty || _selectedDate == null || _startTime == null) {
      _setFormError('Başlık, tarih ve başlangıç saati zorunlu.');
      return;
    }
    if (_selectedPerformer != null && !_hasSelectedPerformer) {
      _setFormError('Geçerli bir sanatçı veya grup profili seçmelisin.');
      return;
    }
    if (_selectedPerformer == null && performerText.length > 50) {
      _setFormError('Sanatçı adı en fazla 50 karakter olabilir.');
      return;
    }
    final startMinutes = _startTime!.hour * 60 + _startTime!.minute;
    final endMinutes = _endTime == null
        ? null
        : _endTime!.hour * 60 + _endTime!.minute;
    if (endMinutes != null && endMinutes < startMinutes) {
      _setFormError('Bitiş saati başlangıç saatinden önce olamaz.');
      return;
    }
    _formError = null;
    await _saveSubmission(
      VenueEventDraft(
        title: title,
        description: _descriptionController.text.trim(),
        eventDate: _selectedDate!,
        startTime: _startTime!,
        endTime: _endTime,
        posterImage: _posterAssetId,
        musicianProfileId:
            _selectedPerformer?.type == ProfileSearchResultType.musician
            ? _selectedPerformer!.targetId.trim()
            : null,
        bandId: _selectedPerformer?.type == ProfileSearchResultType.band
            ? _selectedPerformer!.targetId.trim()
            : null,
        manualPerformerName:
            _selectedPerformer == null && performerText.isNotEmpty
            ? performerText
            : null,
      ),
    );
  }

  Future<void> _saveSubmission(VenueEventDraft draft) async {
    FocusManager.instance.primaryFocus?.unfocus();
    _updateState(() {
      _submitting = true;
      _formError = null;
    });
    Result<void> result;
    try {
      result = await widget.onSave(draft);
    } catch (_) {
      result = const Result.failure(
        AppError(code: 'event_create_unknown', message: 'Kayıt doğrulanamadı.'),
      );
    }
    if (!mounted) return;
    if (result.isSuccess) {
      Navigator.of(context).pop();
      return;
    }
    final error = result.error!;
    final code = error.code;
    final httpCode = int.tryParse(code);
    final ambiguous =
        code == 'network' ||
        code == '9999' ||
        code.endsWith('_unknown') ||
        (httpCode != null && httpCode >= 500 && httpCode < 600);
    _updateState(() {
      _submitting = false;
      _uncertainSubmission = _uncertainSubmission || ambiguous;
      _formError = _uncertainSubmission
          ? 'Kayıt sonucu doğrulanamadı. Yeniden oluşturmadan önce etkinlik listesini kontrol et.'
          : error.message;
    });
  }

  Future<void> _closeDraft() async {
    if (_submitting || _posterUploading || _confirmingClose) return;
    if (_uncertainSubmission) {
      _confirmingClose = true;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Kayıt sonucu henüz doğrulanmadı'),
          content: const Text(
            'Etkinlik kaydedilmiş olabilir. Yeni bir etkinlik oluşturmadan önce listeyi kontrol et.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Vazgeç'),
            ),
            TextButton(
              key: const Key('confirm-leave-uncertain-event'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Etkinliklere dön'),
            ),
          ],
        ),
      );
      _confirmingClose = false;
      if (!mounted || confirmed != true) return;
    }
    Navigator.of(context).pop();
  }
}
