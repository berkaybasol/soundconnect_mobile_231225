part of 'venue_weekly_calendar_editor_screen.dart';

extension _VenueEventDraftSheetStateMethodsTimeMedia
    on _VenueEventDraftSheetState {
  Future<void> _pickTime({required bool isStart}) async {
    final current = isStart
        ? (_startTime ?? const TimeOfDay(hour: 20, minute: 0))
        : (_endTime ?? const TimeOfDay(hour: 22, minute: 0));
    int selectedHour = current.hour;
    int selectedMinute = current.minute.clamp(0, 59);
    final hourController = FixedExtentScrollController(
      initialItem: _VenueEventDraftSheetState._timePickerHours.indexOf(
        selectedHour,
      ),
    );
    final minuteController = FixedExtentScrollController(
      initialItem: _VenueEventDraftSheetState._timePickerMinutes.indexOf(
        selectedMinute,
      ),
    );
    final picked = await showModalBottomSheet<TimeOfDay>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final scheme = Theme.of(context).colorScheme;
          final selectedLabel =
              '${selectedHour.toString().padLeft(2, '0')}:'
              '${selectedMinute.toString().padLeft(2, '0')}';
          return Material(
            color: scheme.surface,
            surfaceTintColor: Colors.transparent,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            clipBehavior: Clip.antiAlias,
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.32),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: _gradientIcon(
                              isStart
                                  ? Icons.schedule_outlined
                                  : Icons.timer_outlined,
                              size: 19,
                            ),
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isStart ? 'Başlangıç saati' : 'Bitiş saati',
                                style: TextStyle(
                                  color: scheme.onSurface,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                selectedLabel,
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Kapat',
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          icon: Icon(
                            Icons.close_rounded,
                            color: scheme.onSurfaceVariant,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      height: 190,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: CupertinoPicker(
                              scrollController: hourController,
                              itemExtent: 44,
                              useMagnifier: true,
                              magnification: 1.08,
                              selectionOverlay: _pickerSelectionOverlay(),
                              onSelectedItemChanged: (index) {
                                setSheetState(() {
                                  selectedHour = _VenueEventDraftSheetState
                                      ._timePickerHours[index];
                                });
                              },
                              children: _VenueEventDraftSheetState
                                  ._timePickerHours
                                  .map(
                                    (hour) => Center(
                                      child: Text(
                                        hour.toString().padLeft(2, '0'),
                                        style: TextStyle(
                                          color: scheme.onSurface,
                                          fontSize: 23,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              ':',
                              style: TextStyle(
                                color: scheme.onSurface,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Expanded(
                            child: CupertinoPicker(
                              scrollController: minuteController,
                              itemExtent: 44,
                              useMagnifier: true,
                              magnification: 1.08,
                              selectionOverlay: _pickerSelectionOverlay(),
                              onSelectedItemChanged: (index) {
                                setSheetState(() {
                                  selectedMinute = _VenueEventDraftSheetState
                                      ._timePickerMinutes[index];
                                });
                              },
                              children: _VenueEventDraftSheetState
                                  ._timePickerMinutes
                                  .map(
                                    (minute) => Center(
                                      child: Text(
                                        minute.toString().padLeft(2, '0'),
                                        style: TextStyle(
                                          color: scheme.onSurface,
                                          fontSize: 23,
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
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('Vazgeç'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: _gradientActionButton(
                            label: 'Saati Seç',
                            icon: Icons.check_rounded,
                            onTap: () => Navigator.of(sheetContext).pop(
                              TimeOfDay(
                                hour: selectedHour,
                                minute: selectedMinute,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    hourController.dispose();
    minuteController.dispose();
    if (!mounted || picked == null) return;
    _updateState(() {
      _formError = null;
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
    if (!mounted || picked == null) return;

    _updateState(() {
      _posterUploading = true;
      _posterPreviewPath = picked.path;
      _formError = null;
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
        _formError = 'Afiş yüklenemedi: $e';
      });
    } finally {
      if (mounted) {
        _updateState(() => _posterUploading = false);
      }
    }
  }
}
