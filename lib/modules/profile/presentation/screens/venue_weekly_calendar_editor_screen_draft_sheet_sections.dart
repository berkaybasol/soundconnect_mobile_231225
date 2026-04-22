part of 'venue_weekly_calendar_editor_screen.dart';

extension _VenueEventDraftSheetStateSections on _VenueEventDraftSheetState {
  Widget _buildDraftSheetHeaderCard() {
    return Container(
      padding: EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.surfaceContainerHighest,
            Theme.of(context).colorScheme.surfaceContainer,
            AppColors.navBlueDeep.withValues(alpha: 0.96),
          ],
        ),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GradientText(
            text: 'Etkinlik Ekle',
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: AppColors.brandGradient,
            ),
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 8),
          Text(
            'AfiÃƒâ€¦Ã…Â¸i ekle, sanatÃƒÆ’Ã‚Â§Ãƒâ€Ã‚Â±yÃƒâ€Ã‚Â± baÃƒâ€Ã…Â¸la ve sahne akÃƒâ€Ã‚Â±Ãƒâ€¦Ã…Â¸Ãƒâ€Ã‚Â±nÃƒâ€Ã‚Â± tek formdan oluÃƒâ€¦Ã…Â¸tur.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraftSheetBasicInfoSection() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Temel bilgiler'),
          _fieldFrame(
            active: _titleFocusNode.hasFocus,
            child: TextField(
              controller: _titleController,
              focusNode: _titleFocusNode,
              decoration: InputDecoration(
                labelText: 'Etkinlik baÃƒâ€¦Ã…Â¸lÃƒâ€Ã‚Â±Ãƒâ€Ã…Â¸Ãƒâ€Ã‚Â±',
                hintText: 'ÃƒÆ’Ã¢â‚¬â€œrn: Cuma Gecesi Akustik Set',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
              ),
            ),
          ),
          SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: _pickPoster,
            child: Container(
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.navBlueDeep.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 74,
                      height: 74,
                      color: Theme.of(context).colorScheme.surfaceContainer,
                      child: _posterPreviewPath == null
                          ? Icon(
                              Icons.image_outlined,
                              size: 28,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            )
                          : Image.file(
                              File(_posterPreviewPath!),
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AfiÃƒâ€¦Ã…Â¸ gÃƒÆ’Ã‚Â¶rseli',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          _posterUploading
                              ? 'GÃƒÆ’Ã‚Â¶rsel yÃƒÆ’Ã‚Â¼kleniyor...'
                              : _posterAssetId != null
                              ? 'AfiÃƒâ€¦Ã…Â¸ hazÃƒâ€Ã‚Â±r, deÃƒâ€Ã…Â¸iÃƒâ€¦Ã…Â¸tirmek iÃƒÆ’Ã‚Â§in dokun'
                              : 'Galeriden etkinlik afiÃƒâ€¦Ã…Â¸i seÃƒÆ’Ã‚Â§',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_posterUploading)
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(
                      Icons.cloud_upload_outlined,
                      size: 22,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraftSheetDateTimeSection() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Tarih ve saat'),
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: _pickDate,
            child: Ink(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.navBlueDeep.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  _gradientIcon(Icons.event_outlined, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _selectedDate == null
                          ? 'Tarih seÃƒÆ’Ã‚Â§'
                          : formatVenueEventDate(_selectedDate!),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              _timeField(
                label: 'BaÃƒâ€¦Ã…Â¸langÃƒâ€Ã‚Â±ÃƒÆ’Ã‚Â§ saati',
                icon: Icons.schedule_outlined,
                value: _startTime == null
                    ? 'Saat seÃƒÆ’Ã‚Â§'
                    : _formatTimeValue(_startTime!),
                onTap: () => _pickTime(isStart: true),
              ),
              SizedBox(width: 10),
              _timeField(
                label: 'BitiÃƒâ€¦Ã…Â¸ saati',
                icon: Icons.timer_outlined,
                value: _endTime == null
                    ? 'Opsiyonel'
                    : _formatTimeValue(_endTime!),
                onTap: () => _pickTime(isStart: false),
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            'BitiÃƒâ€¦Ã…Â¸ saati girmezsen etkinlik tek saat ÃƒÆ’Ã‚Â¼zerinden oluÃƒâ€¦Ã…Â¸turulur.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
              height: 1.4,
            ),
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
          _sectionLabel('AÃƒÆ’Ã‚Â§Ãƒâ€Ã‚Â±klama'),
          _fieldFrame(
            active: _descriptionFocusNode.hasFocus,
            child: TextField(
              controller: _descriptionController,
              focusNode: _descriptionFocusNode,
              minLines: 2,
              maxLines: 3,
              decoration: InputDecoration(
                hintText:
                    'KÃƒâ€Ã‚Â±sa aÃƒÆ’Ã‚Â§Ãƒâ€Ã‚Â±klama, sahne akÃƒâ€Ã‚Â±Ãƒâ€¦Ã…Â¸Ãƒâ€Ã‚Â± veya ÃƒÆ’Ã‚Â¶zel notlar',
                contentPadding: EdgeInsets.fromLTRB(16, 16, 16, 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraftSheetSaveButton() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: FilledButton.icon(
        onPressed: _submit,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          shadowColor: Colors.transparent,
          minimumSize: Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        icon: _gradientIcon(Icons.save_outlined),
        label: Text(
          'EtkinliÃƒâ€Ã…Â¸i Kaydet',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
