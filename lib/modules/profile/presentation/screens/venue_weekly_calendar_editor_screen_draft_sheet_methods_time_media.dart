part of 'venue_weekly_calendar_editor_screen.dart';

extension _VenueEventDraftSheetStateMethodsTimeMedia
    on _VenueEventDraftSheetState {
  Future<void> _pickTime({required bool isStart}) async {
    final current = isStart
        ? (_startTime ?? TimeOfDay(hour: 20, minute: 0))
        : (_endTime ?? TimeOfDay(hour: 22, minute: 0));
    final initialHour = current.hour == 0 ? 24 : current.hour;
    int selectedHour = initialHour;
    int selectedMinute = current.minute.clamp(0, 59);
    if (initialHour == 24 && selectedMinute != 0) {
      selectedMinute = 0;
    }
    final hourController = FixedExtentScrollController(
      initialItem: _VenueEventDraftSheetState._timePickerHours.indexOf(
        initialHour,
      ),
    );
    final minuteController = FixedExtentScrollController(
      initialItem: _VenueEventDraftSheetState._timePickerMinutes.indexOf(
        selectedMinute,
      ),
    );
    final picked = await showModalBottomSheet<TimeOfDay>(
      context: context,
      backgroundColor: AppColors.navBlueDeep,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GradientText(
                  text: isStart ? 'Baslangic Saati' : 'Bitis Saati',
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: AppColors.brandGradient,
                  ),
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 8),
                Text(
                  'Saati ve dakikayi kaydirarak sec.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 18),
                Container(
                  height: 216,
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: CupertinoPicker(
                          scrollController: hourController,
                          itemExtent: 48,
                          useMagnifier: true,
                          magnification: 1.08,
                          selectionOverlay: _pickerSelectionOverlay(),
                          onSelectedItemChanged: (index) {
                            setSheetState(() {
                              selectedHour = _VenueEventDraftSheetState
                                  ._timePickerHours[index];
                              if (selectedHour == 24 && selectedMinute == 30) {
                                selectedMinute = 0;
                                minuteController.jumpToItem(0);
                              }
                            });
                          },
                          children: _VenueEventDraftSheetState._timePickerHours
                              .map(
                                (hour) => Center(
                                  child: Text(
                                    hour.toString().padLeft(2, '0'),
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          ':',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Expanded(
                        child: CupertinoPicker(
                          scrollController: minuteController,
                          itemExtent: 48,
                          useMagnifier: true,
                          magnification: 1.08,
                          selectionOverlay: _pickerSelectionOverlay(),
                          onSelectedItemChanged: (index) {
                            setSheetState(() {
                              final nextMinute = _VenueEventDraftSheetState
                                  ._timePickerMinutes[index];
                              selectedMinute = selectedHour == 24
                                  ? 0
                                  : nextMinute;
                              if (selectedHour == 24 && nextMinute != 0) {
                                minuteController.jumpToItem(0);
                              }
                            });
                          },
                          children: _VenueEventDraftSheetState
                              ._timePickerMinutes
                              .map(
                                (minute) => Center(
                                  child: Text(
                                    minute.toString().padLeft(2, '0'),
                                    style: TextStyle(
                                      color: selectedHour == 24 && minute == 30
                                          ? Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant
                                                .withValues(alpha: 0.45)
                                          : Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 14),
                Text(
                  selectedHour == 24 && selectedMinute == 0
                      ? 'Secilen saat: 24.00'
                      : 'Secilen saat: ${selectedHour.toString().padLeft(2, '0')}.${selectedMinute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(
                    TimeOfDay(
                      hour: selectedHour == 24 ? 0 : selectedHour,
                      minute: selectedMinute,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                    side: BorderSide(color: Theme.of(context).dividerColor),
                    minimumSize: Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Text(
                    'Saati Sec',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (picked == null) return;
    _updateState(() {
      if (isStart) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
    });
  }

  Future<void> _pickPoster() async {
    if (_posterUploading) return;
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
      maxWidth: 2048,
    );
    if (picked == null) return;

    _updateState(() {
      _posterUploading = true;
      _posterPreviewPath = picked.path;
    });

    try {
      final fileName = fileNameFromPath(picked.path, fallback: picked.name);
      final source = await createProfileUploadSource(filePath: picked.path);
      final uploaded = await uploadProfileMediaAsset(
        source: source,
        ownerType: 'VENUE_PROFILE',
        ownerId: widget.ownerProfile.venueProfileId,
        mediaKind: 'IMAGE',
        mimeType: inferImageMimeType(fileName),
        originalFileName: fileName,
      );
      if (!mounted) return;
      _updateState(() {
        _posterAssetId = uploaded.uuid.trim().isEmpty
            ? null
            : uploaded.uuid.trim();
      });
    } catch (e) {
      if (!mounted) return;
      _updateState(() {
        _posterAssetId = null;
        _posterPreviewPath = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Afis yuklenemedi: $e')));
    } finally {
      if (mounted) {
        _updateState(() => _posterUploading = false);
      }
    }
  }
}
