// ignore_for_file: invalid_use_of_protected_member

part of 'venue_weekly_calendar_editor_screen.dart';

extension _VenueEventDraftSheetStateMethods on _VenueEventDraftSheetState {
  void _handleFocusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _runSearch(String raw) async {
    final query = raw.trim();
    final token = ++_searchToken;
    if (query.length < 2) {
      setState(() {
        _searchLoading = false;
        _searchError = null;
        _searchResults = const [];
      });
      return;
    }
    setState(() {
      _searchLoading = true;
      _searchError = null;
    });
    try {
      final result = await _musicianSearchRepository.search(query);
      final results = result.data ?? const <MusicianSearchOption>[];
      if (!mounted || token != _searchToken) return;
      setState(() {
        _searchLoading = false;
        _searchResults = results;
        _searchError = results.isEmpty ? 'Sonuc bulunamadi.' : null;
      });
    } catch (_) {
      if (!mounted || token != _searchToken) return;
      setState(() {
        _searchLoading = false;
        _searchResults = const [];
        _searchError = 'Arama su anda yapilamiyor.';
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
      builder: (context, child) {
        final baseTheme = Theme.of(context);
        return Theme(
          data: baseTheme.copyWith(
            colorScheme: baseTheme.colorScheme.copyWith(
              primary: AppColors.brandGradient[1],
              secondary: AppColors.brandGradient[2],
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    setState(() => _selectedDate = picked);
  }

  void _submit() {
    final title = _titleController.text.trim();
    final performerText = _performerController.text.trim();
    if (title.isEmpty || _selectedDate == null || _startTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Baslik, tarih ve baslangic saati zorunlu.'),
        ),
      );
      return;
    }
    Navigator.of(context).pop(
      VenueEventDraft(
        title: title,
        description: _descriptionController.text.trim(),
        eventDate: _selectedDate!,
        startTime: _startTime!,
        endTime: _endTime,
        posterImage: _posterAssetId,
        musicianProfileId: _selectedMusicianId,
        manualPerformerName:
            _selectedMusicianId == null && performerText.isNotEmpty
            ? performerText
            : null,
      ),
    );
  }
}
