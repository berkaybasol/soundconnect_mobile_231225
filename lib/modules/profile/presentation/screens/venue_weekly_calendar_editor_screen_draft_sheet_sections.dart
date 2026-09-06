part of 'venue_weekly_calendar_editor_screen.dart';

extension _VenueEventDraftSheetStateSections on _VenueEventDraftSheetState {
  Widget _buildDraftSheetHeaderCard() {
    final scheme = Theme.of(context).colorScheme;
    final imageUrl = widget.profileImage?.trim();
    final imageUri = imageUrl == null ? null : Uri.tryParse(imageUrl);
    final hasImage =
        imageUri != null &&
        (imageUri.scheme == 'http' || imageUri.scheme == 'https') &&
        imageUri.host.isNotEmpty;

    Widget avatarFallback() {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Image.asset(
          'assets/logotransparent.png',
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(
            Icons.storefront_outlined,
            color: scheme.onSurfaceVariant,
            size: 22,
          ),
        ),
      );
    }

    return Column(
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
              width: 52,
              height: 52,
              padding: const EdgeInsets.all(1.1),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: AppColors.brandGradient),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brandGradient[2].withValues(alpha: 0.16),
                    blurRadius: 14,
                  ),
                ],
              ),
              child: ClipOval(
                child: ColoredBox(
                  color: scheme.surfaceContainerHighest,
                  child: hasImage
                      ? AppCachedNetworkImage(
                          imageUrl: imageUrl,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          cacheWidth: 150,
                          cacheHeight: 150,
                          errorBuilder: (_) => avatarFallback(),
                        )
                      : avatarFallback(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GradientText(
                    text: widget.profileName,
                    gradient: LinearGradient(colors: AppColors.brandGradient),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      height: 1.1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Yeni etkinlik',
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
              onPressed: _posterUploading || _submitting ? null : _closeDraft,
              style: IconButton.styleFrom(
                backgroundColor: scheme.surfaceContainerHighest,
                foregroundColor: scheme.onSurfaceVariant,
              ),
              icon: const Icon(Icons.close_rounded, size: 20),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDraftSheetBasicInfoSection() {
    final scheme = Theme.of(context).colorScheme;
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Etkinlik bilgileri', icon: Icons.event_note_outlined),
          _fieldFrame(
            active: _titleFocusNode.hasFocus,
            child: TextField(
              controller: _titleController,
              maxLength: 255,
              focusNode: _titleFocusNode,
              onChanged: (_) => _clearFormError(),
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Etkinlik başlığı',
                hintText: 'Örn. Cuma Gecesi Akustik Set',
                counterText: '',
                prefixIcon: Icon(Icons.edit_outlined, size: 19),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Material(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _posterUploading ? null : _pickPoster,
              child: Container(
                constraints: const BoxConstraints(minHeight: 80),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: Container(
                        width: 56,
                        height: 64,
                        color: scheme.surfaceContainer,
                        child: _posterPreviewPath == null
                            ? Center(
                                child: _gradientIcon(
                                  Icons.image_outlined,
                                  size: 23,
                                ),
                              )
                            : Image.file(
                                File(_posterPreviewPath!),
                                fit: BoxFit.cover,
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Afiş görseli',
                            style: TextStyle(
                              color: scheme.onSurface,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _posterUploading
                                ? 'Yükleniyor...'
                                : _posterAssetId != null
                                ? 'Değiştirmek için dokun'
                                : 'İsteğe bağlı',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 11,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_posterUploading)
                      const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: _gradientIcon(
                            _posterAssetId == null
                                ? Icons.add_photo_alternate_outlined
                                : Icons.edit_outlined,
                            size: 18,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraftSheetDateTimeSection() {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Program', icon: Icons.calendar_month_outlined),
          _selectionTile(
            label: 'Tarih',
            value: _selectedDate == null
                ? 'Tarih seç'
                : formatVenueEventDate(_selectedDate!),
            icon: Icons.event_outlined,
            onTap: _pickDate,
          ),
          if (_selectedDate != null &&
              isVenueEventBeyondWeek(_selectedDate!)) ...[
            const SizedBox(height: 12),
            VenueFutureEventNotice(eventDate: _selectedDate!),
          ],
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final stackFields = constraints.maxWidth < 310 || scale > 1.35;
              final startField = _timeField(
                label: 'Başlangıç',
                icon: Icons.schedule_outlined,
                value: _startTime == null
                    ? 'Saat seç'
                    : _formatTimeValue(_startTime!),
                onTap: () => _pickTime(isStart: true),
              );
              final endField = _timeField(
                label: 'Bitiş',
                icon: Icons.timer_outlined,
                value: _endTime == null
                    ? 'Eklenmedi'
                    : _formatTimeValue(_endTime!),
                onTap: () => _pickTime(isStart: false),
                onClear: _endTime == null
                    ? null
                    : () {
                        _updateState(() => _endTime = null);
                        _clearFormError();
                      },
              );
              if (stackFields) {
                return Column(
                  children: [startField, const SizedBox(height: 10), endField],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: startField),
                  const SizedBox(width: 10),
                  Expanded(child: endField),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDraftSheetDescriptionSection() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Açıklama', icon: Icons.notes_rounded),
          _fieldFrame(
            active: _descriptionFocusNode.hasFocus,
            child: TextField(
              controller: _descriptionController,
              focusNode: _descriptionFocusNode,
              minLines: 2,
              maxLines: 4,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Etkinlik hakkında kısa bir not (isteğe bağlı)',
                counterText: '',
                contentPadding: EdgeInsets.fromLTRB(14, 15, 14, 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraftSheetSaveButton() {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 13, 20, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_formError != null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: scheme.error,
                    size: 18,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      _formError!,
                      style: TextStyle(
                        color: scheme.error,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                TextButton(
                  onPressed: _posterUploading || _submitting
                      ? null
                      : _closeDraft,
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.onSurfaceVariant,
                    minimumSize: const Size(86, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Vazgeç',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: KeyedSubtree(
                    key: const Key('venue-event-submit'),
                    child: _gradientActionButton(
                      label: _posterUploading
                          ? 'Afiş yükleniyor...'
                          : _submitting
                          ? 'Kaydediliyor...'
                          : _uncertainSubmission
                          ? 'Listeyi kontrol et'
                          : 'Etkinliği Oluştur',
                      icon: _posterUploading || _submitting
                          ? Icons.hourglass_top_rounded
                          : _uncertainSubmission
                          ? Icons.refresh_rounded
                          : Icons.add_rounded,
                      onTap: _posterUploading || _submitting ? null : _submit,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
