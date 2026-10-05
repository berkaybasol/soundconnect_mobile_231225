part of 'table_group_create_screen.dart';

extension _TableGroupCreateScreenStateOnFocusChangedMethods
    on _TableGroupCreateScreenState {
  void _updateFocus() {
    if (mounted) _updateView(() {});
  }

  void _updateVenue() {
    if (!context.mounted) return;
    if (_settingVenueText) return;
    if (!_cubit.state.hasSpecificVenue) return;
    if (_cubit.state.venueMode == TableGroupVenueMode.registered) {
      _updateView(() {
        _selectedCityId = null;
        _selectedDistrictId = null;
        _selectedNeighborhoodId = null;
      });
    }
    _cubit.venueTextChanged(_venueController.text);
  }

  void _selectRegisteredVenue(TableGroupVenueOption option) {
    if (_cubit.state.status == TableGroupCreateStatus.submitting) return;
    _cubit.selectRegisteredVenue(option);
    _settingVenueText = true;
    _venueController.value = TextEditingValue(
      text: option.name,
      selection: TextSelection.collapsed(offset: option.name.length),
    );
    _settingVenueText = false;
    _updateView(() {
      _selectedCityId = option.cityId;
      _selectedDistrictId = option.districtId;
      _selectedNeighborhoodId = option.neighborhoodId;
    });
  }

  void _useCustomVenue() {
    if (_cubit.state.status == TableGroupCreateStatus.submitting) return;
    _cubit.useCustomVenue(_venueController.text);
  }

  void _clearRegisteredVenue() {
    if (_cubit.state.status == TableGroupCreateStatus.submitting) return;

    _settingVenueText = true;
    _venueController.clear();
    _settingVenueText = false;
    _updateView(() {
      _selectedCityId = null;
      _selectedDistrictId = null;
      _selectedNeighborhoodId = null;
    });
    _cubit.detachRegisteredVenue('');
    _venueFocusNode.requestFocus();
  }

  void _setHasSpecificVenue(bool value) {
    if (_cubit.state.status == TableGroupCreateStatus.submitting ||
        value == _cubit.state.hasSpecificVenue) {
      return;
    }
    if (value) {
      _cubit.enableSpecificVenue();
      return;
    }

    final leavingRegisteredVenue =
        _cubit.state.venueMode == TableGroupVenueMode.registered;
    _venueFocusNode.unfocus();
    _settingVenueText = true;
    _venueController.clear();
    _settingVenueText = false;
    if (leavingRegisteredVenue) {
      _updateView(() {
        _selectedCityId = null;
        _selectedDistrictId = null;
        _selectedNeighborhoodId = null;
      });
    }
    _cubit.disableSpecificVenue();
  }

  int get _guestCount => _femaleCount + _maleCount + _otherCount;

  int get _totalSeats => _guestCount + 1;

  String get _genderDistributionText {
    final parts = <String>[];
    if (_femaleCount > 0) parts.add('$_femaleCount kız');
    if (_maleCount > 0) parts.add('$_maleCount erkek');
    if (_otherCount > 0) parts.add('$_otherCount fark etmez');
    if (parts.isEmpty) return 'Seçim yok';
    return parts.join(', ');
  }

  void _changeGenderCount(_SeatGender type, int delta) {
    final total = _guestCount;
    if (delta > 0 && total >= 5) return;

    _updateView(() {
      switch (type) {
        case _SeatGender.female:
          _femaleCount = (_femaleCount + delta).clamp(0, 5);
        case _SeatGender.male:
          _maleCount = (_maleCount + delta).clamp(0, 5);
        case _SeatGender.other:
          _otherCount = (_otherCount + delta).clamp(0, 5);
        case _SeatGender.me:
          break;
      }
    });
  }

  List<_SeatGender> _seatGenders() {
    final list = <_SeatGender>[_SeatGender.me];
    list.addAll(List<_SeatGender>.filled(_femaleCount, _SeatGender.female));
    list.addAll(List<_SeatGender>.filled(_maleCount, _SeatGender.male));
    list.addAll(List<_SeatGender>.filled(_otherCount, _SeatGender.other));
    return list;
  }

  List<String> _buildGenderPrefs() {
    final prefs = <String>['OTHER'];
    prefs.addAll(List<String>.filled(_femaleCount, 'FEMALE'));
    prefs.addAll(List<String>.filled(_maleCount, 'MALE'));
    prefs.addAll(List<String>.filled(_otherCount, 'OTHER'));
    return prefs;
  }

  String _formatCardTime() {
    final now = widget.now();
    return formatTableGroupMeetingAt(
      resolveTableGroupMeetingAt(
        now: now,
        hour: _selectedTime.hour,
        minute: _selectedTime.minute,
      ),
      now: now,
    );
  }

  void _requestBackNavigation() {
    if (!mounted || _cubit.state.status == TableGroupCreateStatus.submitting) {
      return;
    }
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
  }

  Future<void> _pickTime() async {
    if (_cubit.state.status == TableGroupCreateStatus.submitting) return;
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.isLight
                  ? AppColors.accentText
                  : AppColors.brandGradient.last,
              surface: Theme.of(context).colorScheme.surfaceContainer,
              onSurface: Theme.of(context).colorScheme.onSurface,
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
            ),
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
              dialBackgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
              hourMinuteColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
              hourMinuteTextColor: Theme.of(context).colorScheme.onSurface,
              dayPeriodColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
              dayPeriodTextColor: Theme.of(context).colorScheme.onSurface,
              entryModeIconColor: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant,
              dialHandColor: AppColors.brandGradient.last,
              dialTextColor: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (!mounted || picked == null) return;
    _updateView(() => _selectedTime = picked);
  }

  Widget _venuePickerFeedback(
    BuildContext context,
    TableGroupCreateState state, {
    required bool submitting,
  }) {
    final selected = state.selectedVenue;
    if (state.venueMode == TableGroupVenueMode.registered && selected != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: _compactVenueRow(
          context,
          selected,
          key: const Key('table_group_registered_venue_summary'),
          infoKey: const Key('table_group_selected_venue_info'),
          selected: true,
          infoEnabled: !submitting,
        ),
      );
    }

    final query = state.venueQuery;
    if (query.length < 2 || !state.venueSuggestionsVisible) {
      return const SizedBox.shrink();
    }
    return Container(
      key: const Key('table_group_venue_search_results'),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.venueSearchLoading)
            const LinearProgressIndicator(minHeight: 2),
          if (state.venueSearchError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
              child: Text(
                state.venueSearchError!.message,
                key: const Key('table_group_venue_search_error'),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ),
          for (var index = 0; index < state.venueOptions.length; index++) ...[
            _compactVenueRow(
              context,
              state.venueOptions[index],
              key: ValueKey<String>(
                'table_group_venue_option-${state.venueOptions[index].id}',
              ),
              infoKey: ValueKey<String>(
                'table_group_venue_info-${state.venueOptions[index].id}',
              ),
              onTap: submitting
                  ? null
                  : () => _selectRegisteredVenue(state.venueOptions[index]),
              infoEnabled: !submitting,
            ),
            if (index < state.venueOptions.length - 1)
              const Divider(height: 1, indent: 64),
          ],
          TextButton(
            key: const Key('table_group_use_custom_venue'),
            onPressed: submitting ? null : _useCustomVenue,
            child: Text('“$query” adını serbest kullan'),
          ),
        ],
      ),
    );
  }

  Widget _compactVenueRow(
    BuildContext context,
    TableGroupVenueOption option, {
    required Key key,
    required Key infoKey,
    VoidCallback? onTap,
    bool selected = false,
    bool infoEnabled = true,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = colorScheme.onSurface;
    final secondary = colorScheme.onSurfaceVariant;

    return Semantics(
      key: ValueKey<String>('table_group_venue_semantics-${option.id}'),
      selected: selected ? true : null,
      child: Material(
        key: key,
        color: selected
            ? colorScheme.surfaceContainerHighest
            : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: selected
              ? BorderSide(
                  color: AppColors.decorativeGradient.last.withValues(
                    alpha: 0.72,
                  ),
                  width: 1.2,
                )
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
            child: Row(
              children: [
                CircleAvatar(
                  key: ValueKey<String>(
                    'table_group_venue_avatar-${option.id}',
                  ),
                  radius: 21,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  child: ClipOval(
                    child: AppCachedNetworkImage(
                      key: ValueKey<String>(
                        'table_group_venue_image-${option.id}',
                      ),
                      imageUrl: option.profilePictureUrl,
                      width: 42,
                      height: 42,
                      cacheWidth: 126,
                      cacheHeight: 126,
                      errorBuilder: (context) => Icon(
                        Icons.storefront_rounded,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        option.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: foreground,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        option.locationSummary,
                        key: selected
                            ? const Key('table_group_locked_venue_location')
                            : null,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: secondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: infoKey,
                  tooltip: '${option.name} hakkında bilgi',
                  icon: const Icon(Icons.info_outline_rounded, size: 20),
                  color: secondary,
                  onPressed: infoEnabled
                      ? () =>
                            unawaited(_showVenueSelectionInfo(context, option))
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showVenueSelectionInfo(
    BuildContext context,
    TableGroupVenueOption option,
  ) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('table_group_venue_info_dialog'),
        scrollable: true,
        title: Text(option.name, key: const Key('table_group_venue_info_name')),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              option.locationSummary,
              key: const Key('table_group_venue_info_location'),
              style: Theme.of(dialogContext).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Text(
              option.address,
              key: const Key('table_group_venue_info_address'),
            ),
            const Divider(height: 24),
            const Text(
              'Bu mekânı seçmen yalnızca masanın buluşma konumunu belirtir. '
              'Mekâna bildirim gönderilmez ve rezervasyon oluşturulmaz.',
            ),
          ],
        ),
        actions: [
          TextButton(
            key: const Key('table_group_venue_info_close'),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Anladım'),
          ),
        ],
      ),
    );
  }

  Widget _descriptionField(BuildContext context, {required bool loading}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FieldCaption('Masa açıklaması'),
        const SizedBox(height: 8),
        _GradientFocusFrame(
          isFocused: _descriptionFocusNode.hasFocus,
          child: TextFormField(
            key: const Key('table_group_description_input'),
            controller: _descriptionController,
            focusNode: _descriptionFocusNode,
            readOnly: loading,
            minLines: 3,
            maxLines: 5,
            inputFormatters: const [
              _DescriptionCodePointLengthFormatter(
                TableGroupCreateRequest.maxDescriptionLength,
              ),
            ],
            textCapitalization: TextCapitalization.sentences,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: 'Masada nasıl bir buluşma planladığını kısaca anlat.',
              alignLabelWithHint: true,
              counterText: '',
              contentPadding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
              filled: true,
              fillColor: (AppColors.isOriginalDark
                  ? Theme.of(context).colorScheme.surfaceContainerHighest
                  : AppColors.inputFill),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            validator: (value) {
              final description = TableGroupCreateRequest.normalizeDescription(
                value ?? '',
              );
              if (description.isEmpty) {
                return 'Masa açıklaması zorunlu';
              }
              if (TableGroupCreateRequest.descriptionCodePointLength(
                    description,
                  ) >
                  TableGroupCreateRequest.maxDescriptionLength) {
                return 'Masa açıklaması en fazla 280 karakter olabilir';
              }
              return null;
            },
          ),
        ),
        const SizedBox(height: 6),
        _DescriptionCounter(controller: _descriptionController),
      ],
    );
  }

  Future<void> _submit(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);

    if (!_attemptedSubmit) _updateView(() => _attemptedSubmit = true);
    if (_formKey.currentState?.validate() != true) return;
    if (_guestCount < 1) {
      messenger.showSnackBar(
        appSnackBar(
          context,
          tone: AppSnackBarTone.warning,
          content: Text('En az 1 katılımcı seçmelisin'),
        ),
      );
      return;
    }
    final selectedVenue = _cubit.state.selectedVenue;
    final registered =
        _cubit.state.hasSpecificVenue &&
        _cubit.state.venueMode == TableGroupVenueMode.registered &&
        selectedVenue != null;
    final cityId = registered ? selectedVenue.cityId : _selectedCityId;
    if (cityId == null || cityId.isEmpty) {
      messenger.showSnackBar(
        appSnackBar(
          context,
          tone: AppSnackBarTone.warning,
          content: Text('Şehir seçimi zorunlu'),
        ),
      );
      return;
    }

    final venueId = registered ? selectedVenue.id : null;
    final venueName = !_cubit.state.hasSpecificVenue || registered
        ? null
        : _venueController.text.trim();
    final districtId = registered
        ? selectedVenue.districtId
        : _selectedDistrictId;
    final neighborhoodId = registered
        ? selectedVenue.neighborhoodId
        : _selectedNeighborhoodId;
    final draft = (
      venueId: venueId,
      venueName: venueName,
      description: _descriptionController.text.trim(),
      maxPersonCount: _totalSeats,
      femaleCount: _femaleCount,
      maleCount: _maleCount,
      otherCount: _otherCount,
      ageMin: _ageRange.start.round(),
      ageMax: _ageRange.end.round(),
      hour: _selectedTime.hour,
      minute: _selectedTime.minute,
      cityId: cityId,
      districtId: districtId,
      neighborhoodId: neighborhoodId,
    );

    var request = _retryableCreateDraft == draft
        ? _retryableCreateRequest
        : null;
    if (request == null) {
      final now = widget.now();
      final meetingAt = resolveTableGroupMeetingAt(
        now: now,
        hour: _selectedTime.hour,
        minute: _selectedTime.minute,
      );
      final meetingLead = meetingAt.difference(now);
      if (meetingLead <= Duration.zero ||
          meetingLead > tableGroupMaximumMeetingLead) {
        messenger.showSnackBar(
          appSnackBar(
            context,
            tone: AppSnackBarTone.warning,
            content: Text('Buluşma saati en fazla 24 saat sonrası olabilir'),
          ),
        );
        return;
      }
      request = TableGroupCreateRequest(
        venueId: venueId,
        venueName: venueName,
        description: draft.description,
        maxPersonCount: draft.maxPersonCount,
        genderPrefs: _buildGenderPrefs(),
        ageMin: draft.ageMin,
        ageMax: draft.ageMax,
        meetingAt: meetingAt,
        cityId: draft.cityId,
        districtId: draft.districtId,
        neighborhoodId: draft.neighborhoodId,
      );
      // A committed response can be lost. Keep the exact request snapshot for
      // semantically identical retries so the backend's replay fingerprint is
      // preserved even if the selected minute has rolled into tomorrow.
      _retryableCreateDraft = draft;
      _retryableCreateRequest = request;
    }

    final ok = await _cubit.createTableGroup(request);
    if (!mounted) return;
    if (!ok) {
      if (identical(_retryableCreateRequest, request) &&
          _isDefinitiveCreateRejection(_cubit.state.error?.code)) {
        _retryableCreateDraft = null;
        _retryableCreateRequest = null;
      }
      return;
    }
    ScaffoldMessenger.of(this.context).showSnackBar(
      appSnackBar(
        this.context,
        tone: AppSnackBarTone.success,
        duration: const Duration(seconds: 6),
        content: const Text(
          'Masa oluşturuldu.\n'
          'Masana Mesajlar bölümünden ulaşabilirsin.',
        ),
      ),
    );
    Navigator.of(
      this.context,
    ).pop(TableGroupCreateResult(cityId: request.cityId));
  }

  bool _isDefinitiveCreateRejection(String? rawCode) {
    final code = rawCode?.trim().toUpperCase();
    if (code == null || code.isEmpty) return false;

    // These responses prove that this exact request did not commit. Keep the
    // snapshot for transport/decode ambiguity and every 5xx path so a replay
    // can still recover a response that was lost after commit.
    return const <String>{
      '9100', // VENUE_ID_AND_NAME_CONFLICT
      '9102', // INVALID_AGE_RANGE
      '9103', // GENDER_AND_COUNT_MISMATCH
      '9104', // TABLE_END_DATE_PASSED
      '9112', // TABLE_GROUP_DURATION_INVALID
      '9114', // TABLE_GROUP_VENUE_LOCATION_MISMATCH
      '9127', // TABLE_GROUP_OWNER_ACTIVE_EXISTS
    }.contains(code);
  }
}
