part of 'studio_profile_screen.dart';

extension _StudioRoomDetailActions on _StudioRoomDetailScreenState {
  List<_StudioOwnerReservation> _ownerReservationsForSelection() {
    return _ownerReservationsForDate(_selectedDate);
  }

  List<_StudioOwnerReservation> _ownerReservationsForDate(DateTime date) {
    final dateKey = _StudioRoomDetailScreenState._apiDate(date);
    return _scheduleReservations
        .where(
          (reservation) =>
              (reservation.status.isPending ||
                  reservation.status.isConfirmed) &&
              _StudioRoomDetailScreenState._reservationDateKey(reservation) ==
                  dateKey,
        )
        .map(
          (reservation) => _StudioOwnerReservation.fromDomain(
            reservation,
            evaluatedAt: _studioClockNow,
          ),
        )
        .where(
          (reservation) =>
              reservation.startIndex >= 0 &&
              reservation.startIndex <
                  _StudioRoomDetailScreenState._times.length &&
              reservation.durationHours > 0,
        )
        .toList(growable: false);
  }

  List<_StudioManualBusyRange> get _manualBusyRangesForSelection =>
      _scheduleOccupancies
          .where(
            (occupancy) =>
                occupancy.active &&
                occupancy.type == StudioOccupancyType.manualBlock &&
                _StudioRoomDetailScreenState._occupancyDateKey(occupancy) ==
                    _StudioRoomDetailScreenState._apiDate(_selectedDate),
          )
          .map(_StudioManualBusyRange.fromDomain)
          .where((range) => range.durationHours > 0)
          .toList(growable: false);

  int _occupiedHoursForDate(DateTime date) {
    return _scheduleOccupancies
        .where(
          (occupancy) =>
              occupancy.active &&
              _StudioRoomDetailScreenState._occupancyDateKey(occupancy) ==
                  _StudioRoomDetailScreenState._apiDate(date),
        )
        .map(_StudioManualBusyRange.fromDomain)
        .fold(0, (total, range) => total + range.durationHours);
  }

  bool _isSlotFreeForManualBusy(int index) {
    if (_ownerReservationsForSelection().any(
      (reservation) =>
          index >= reservation.startIndex &&
          index < reservation.startIndex + reservation.durationHours,
    )) {
      return false;
    }
    if (_manualBusyRangesForSelection.any((range) => range.contains(index))) {
      return false;
    }
    return _isSlotUnoccupied(_StudioRoomDetailScreenState._times[index]);
  }

  bool _canEditOwnerTime(String time) {
    final startHour = int.parse(time.substring(0, 2));
    return _bookingPolicy?.canStartAt(_selectedDate, startHour) == true;
  }

  Future<void> _openManualBusyEditor(int startIndex) async {
    if (_calendarMutationInFlight) return;
    final endOptions = <int>[];
    for (
      var index = startIndex;
      index < _StudioRoomDetailScreenState._times.length;
      index++
    ) {
      if (!_isSlotFreeForManualBusy(index)) break;
      endOptions.add(index + 1);
    }
    if (endOptions.isEmpty || !mounted) return;
    final endIndex = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StudioManualBusySheet(
        roomName: _room.name,
        date: _selectedDate,
        startIndex: startIndex,
        endOptions: endOptions,
      ),
    );
    if (endIndex == null || !mounted) return;
    final requestKey =
        '${_room.id}|${_StudioRoomDetailScreenState._apiDate(_selectedDate)}|$startIndex|$endIndex';
    final requestId = _manualBlockRequestIds.putIfAbsent(
      requestKey,
      () => const Uuid().v4(),
    );
    _setState(() => _calendarMutationInFlight = true);
    final result = await _repository.createManualBlock(
      roomId: _room.id,
      date: _selectedDate,
      startHour: 9 + startIndex,
      durationHours: endIndex - startIndex,
      clientRequestId: requestId,
    );
    if (!mounted) return;
    _setState(() => _calendarMutationInFlight = false);
    if (!result.isSuccess) {
      _showCalendarError(
        result.error?.message ?? 'Saat aralığı dolu olarak işaretlenemedi.',
      );
      return;
    }
    _manualBlockRequestIds.remove(requestKey);
    await _loadCalendarData(showLoading: false);
  }

  Future<void> _removeManualBusyRange(_StudioManualBusyRange range) async {
    if (_calendarMutationInFlight) return;
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF101722),
        title: const Text('Saatler müsait yapılsın mı?'),
        content: Text(
          '${_manualHourLabel(range.startIndex)}–${_manualHourLabel(range.endIndex)} aralığı yeniden rezervasyona açılacak.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Müsait Yap'),
          ),
        ],
      ),
    );
    if (shouldRemove != true || !mounted) return;
    _setState(() => _calendarMutationInFlight = true);
    final result = await _repository.releaseManualBlock(
      roomId: _room.id,
      blockId: range.id,
      expectedVersion: range.version,
    );
    if (!mounted) return;
    _setState(() => _calendarMutationInFlight = false);
    if (!result.isSuccess) {
      _showCalendarError(
        result.error?.message ?? 'Manuel doluluk kaldırılamadı.',
      );
      if (isStudioStaleError(result.error)) {
        await _loadCalendarData(showLoading: false);
      }
      return;
    }
    await _loadCalendarData(showLoading: false);
  }

  Future<void> _showOwnerReservationActions(
    _StudioOwnerReservation reservation,
  ) async {
    final profileTarget = _resolveReservationGuestProfileTarget(reservation);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _StudioReservationActionSheet(
        reservation: reservation,
        roomName: _room.name,
        date: _selectedDate,
        startTime: _manualHourLabel(reservation.startIndex),
        endTime: _manualHourLabel(
          reservation.startIndex + reservation.durationHours,
        ),
        onApprove: () => _approveReservation(reservation),
        onReject: () => _confirmReservationRejection(reservation),
        onShowDetails: () => _showReservationDetails(reservation),
        profileTarget: profileTarget,
        onShowProfile: _showReservationGuestProfile,
        onSendMessage: () => _messageReservationGuest(reservation),
        onCancel: () => _confirmReservationCancellation(reservation),
      ),
    );
  }

  Future<void> _approveReservation(_StudioOwnerReservation reservation) async {
    if (_calendarMutationInFlight) return;
    if (!reservation.capabilities.canApprove) {
      _showCalendarError('Bu rezervasyon artık onaylanamaz.');
      await _loadCalendarData(showLoading: false);
      return;
    }
    _setState(() => _calendarMutationInFlight = true);
    final result = await _repository.approveReservation(
      roomId: _room.id,
      reservationId: reservation.id,
      expectedVersion: reservation.version,
    );
    if (!mounted) return;
    _setState(() => _calendarMutationInFlight = false);
    if (!result.isSuccess) {
      _showCalendarError(result.error?.message ?? 'Rezervasyon onaylanamadı.');
      await _loadCalendarData(showLoading: false);
      return;
    }
    await _loadCalendarData(showLoading: false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${reservation.userName} rezervasyonu onaylandı.'),
      ),
    );
  }

  Future<void> _confirmReservationCancellation(
    _StudioOwnerReservation reservation,
  ) async {
    if (_calendarMutationInFlight) return;
    if (!reservation.capabilities.canCancel) {
      _showCalendarError('Bu rezervasyon artık iptal edilemez.');
      await _loadCalendarData(showLoading: false);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF101722),
        title: const Text('Rezervasyon iptal edilsin mi?'),
        content: Text(
          '${reservation.userName} tarafından oluşturulan rezervasyon kaldırılacak.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFFF7373),
            ),
            child: const Text('Rezervasyonu İptal Et'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _setState(() => _calendarMutationInFlight = true);
    final result = await _repository.cancelOwnerReservation(
      roomId: _room.id,
      reservationId: reservation.id,
      expectedVersion: reservation.version,
    );
    if (!mounted) return;
    _setState(() => _calendarMutationInFlight = false);
    if (!result.isSuccess) {
      _showCalendarError(
        result.error?.message ?? 'Rezervasyon iptal edilemedi.',
      );
      await _loadCalendarData(showLoading: false);
      return;
    }
    await _loadCalendarData(showLoading: false);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Rezervasyon iptal edildi.')));
  }

  Future<void> _confirmReservationRejection(
    _StudioOwnerReservation reservation,
  ) async {
    if (_calendarMutationInFlight) return;
    if (!reservation.capabilities.canReject) {
      _showCalendarError('Bu rezervasyon talebi artık reddedilemez.');
      await _loadCalendarData(showLoading: false);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF101722),
        title: const Text('Rezervasyon talebi reddedilsin mi?'),
        content: Text(
          '${reservation.userName} tarafından gönderilen rezervasyon talebi '
          'reddedilecek.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFFF7373),
            ),
            child: const Text('Talebi Reddet'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _setState(() => _calendarMutationInFlight = true);
    final result = await _repository.rejectReservation(
      roomId: _room.id,
      reservationId: reservation.id,
      expectedVersion: reservation.version,
    );
    if (!mounted) return;
    _setState(() => _calendarMutationInFlight = false);
    if (!result.isSuccess) {
      _showCalendarError(
        result.error?.message ?? 'Rezervasyon talebi reddedilemedi.',
      );
      await _loadCalendarData(showLoading: false);
      return;
    }
    await _loadCalendarData(showLoading: false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Rezervasyon talebi reddedildi.')),
    );
  }

  Future<void> _showReservationDetails(_StudioOwnerReservation reservation) {
    return showDialog<void>(
      context: context,
      builder: (_) => _StudioReservationDetailsDialog(
        reservation: reservation,
        roomName: _room.name,
        date: _selectedDate,
        startTime: _manualHourLabel(reservation.startIndex),
        endTime: _manualHourLabel(
          reservation.startIndex + reservation.durationHours,
        ),
      ),
    );
  }

  Future<DmProfileTarget?> _resolveReservationGuestProfileTarget(
    _StudioOwnerReservation reservation,
  ) => _resolveStudioReservationGuestTarget(reservation);

  Future<void> _showReservationGuestProfile(DmProfileTarget target) async {
    final route = dmProfileRouteFor(target);
    if (route == null || !mounted) return;
    await Navigator.of(
      context,
    ).pushNamed(route.routeName, arguments: route.arguments);
  }

  Future<void> _messageReservationGuest(
    _StudioOwnerReservation reservation,
  ) async {
    if (reservation.userId.trim().isEmpty) {
      _showCalendarError('Kullanıcı bilgisi alınamadığı için mesaj açılamadı.');
      return;
    }
    final profileTarget = await _resolveReservationGuestProfileTarget(
      reservation,
    );
    if (!mounted) return;
    final resolvedAvatarUrl = profileTarget?.imageUrl?.trim() ?? '';
    final reservationAvatarUrl = reservation.avatarUrl.trim();
    final resolvedDisplayName = profileTarget?.displayName.trim() ?? '';
    await Navigator.of(context).pushNamed(
      AppRoutes.dmChat,
      arguments: DmChatScreenArgs(
        otherUserId: reservation.userId,
        otherUsername: resolvedDisplayName.isNotEmpty
            ? resolvedDisplayName
            : reservation.userName,
        otherUserProfilePicture: resolvedAvatarUrl.isNotEmpty
            ? resolvedAvatarUrl
            : reservationAvatarUrl,
      ),
    );
  }

  Future<void> _pickDate() async {
    final today = _studioToday;
    final lastDate = _latestBookableDate;
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: today,
      lastDate: lastDate,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.dark(
            primary: AppColors.socialPink,
            onPrimary: Colors.white,
            surface: const Color(0xFF101722),
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;
    _setState(() {
      _selectedDate = _StudioRoomDetailScreenState._dateOnly(date);
      _selectedTime = null;
      _clearPendingReservationRequest();
      if (!widget.canReserve) {
        _selectedOwnerOverviewDate = _selectedDate;
        _ownerDateWindowStart = _selectedDate;
      }
    });
    await _loadCalendarData();
  }

  void _changeDate(int days) {
    final next = _bookingPolicy?.shiftDate(_selectedDate, days);
    if (next == null) return;
    _setState(() {
      _selectedDate = next;
      _selectedTime = null;
      _clearPendingReservationRequest();
    });
    _loadCalendarData();
  }

  _StudioPublicRoomSlotState _publicSlotState(String time) {
    final startIndex = _StudioRoomDetailScreenState._times.indexOf(time);
    if (startIndex < 0) return _StudioPublicRoomSlotState.past;
    final startHour = int.parse(time.substring(0, 2));
    final policy = _bookingPolicy;
    if (policy == null || !policy.canStartAt(_selectedDate, startHour)) {
      return _StudioPublicRoomSlotState.past;
    }
    final ownReservation = _customerReservationAt(startHour);
    if (ownReservation != null) {
      return ownReservation.status.isPending
          ? _StudioPublicRoomSlotState.pendingByMe
          : _StudioPublicRoomSlotState.reservedByMe;
    }
    if (!_isSlotUnoccupied(time)) {
      return _StudioPublicRoomSlotState.occupied;
    }
    return _StudioPublicRoomSlotState.available;
  }

  StudioReservation? _customerReservationAt(int hour) {
    final dateKey = _StudioRoomDetailScreenState._apiDate(_selectedDate);
    StudioReservation? pendingReservation;
    for (final reservation in _customerReservations) {
      if (reservation.roomId != _room.id ||
          (!reservation.status.isPending && !reservation.status.isConfirmed) ||
          _StudioRoomDetailScreenState._reservationDateKey(reservation) !=
              dateKey) {
        continue;
      }
      final startsAt = _StudioRoomDetailScreenState._localHour(
        reservation.localStartTime,
        reservation.startsAt,
      );
      final endsAt = _StudioRoomDetailScreenState._localHour(
        reservation.localEndTime,
        reservation.endsAt,
      );
      if (hour < startsAt || hour >= endsAt) continue;
      if (reservation.status.isConfirmed) return reservation;
      pendingReservation ??= reservation;
    }
    return pendingReservation;
  }

  Future<void> _confirmCustomerReservationCancellation(
    StudioReservation reservation,
  ) async {
    if (_calendarMutationInFlight) return;
    if (!reservation.status.isPending && !reservation.status.isConfirmed) {
      _showCalendarError('Bu rezervasyon artık iptal edilemez.');
      await _loadCalendarData(showLoading: false);
      return;
    }
    final startHour = _StudioRoomDetailScreenState._localHour(
      reservation.localStartTime,
      reservation.startsAt,
    );
    final endHour = _StudioRoomDetailScreenState._localHour(
      reservation.localEndTime,
      reservation.endsAt,
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF101722),
        title: const Text('Rezervasyonunu iptal et'),
        content: Text(
          '${_room.name}\n'
          '${_StudioRoomDetailScreenState._formatDate(_selectedDate)} • '
          '${startHour.toString().padLeft(2, '0')}:00–'
          '${endHour.toString().padLeft(2, '0')}:00\n\n'
          '${reservation.status.isPending ? 'Onay bekleyen talebin' : 'Onaylı rezervasyonun'} iptal edilecek.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFFF7373),
            ),
            child: const Text('Rezervasyonu İptal Et'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _setState(() => _calendarMutationInFlight = true);
    final result = await _repository.cancelCustomerReservation(
      reservationId: reservation.id,
      expectedVersion: reservation.version,
    );
    if (!mounted) return;
    _setState(() => _calendarMutationInFlight = false);
    if (!result.isSuccess) {
      _showCalendarError(
        result.error?.message ?? 'Rezervasyon iptal edilemedi.',
      );
      await _loadCalendarData(showLoading: false);
      return;
    }
    _clearPendingReservationRequest();
    await _loadCalendarData(showLoading: false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Rezervasyonun iptal edildi.')),
    );
  }

  void _selectStartTime(String time) {
    final nextDuration = _canUseDurationAt(time, _durationHours)
        ? _durationHours
        : 1;
    _setState(() {
      _selectedTime = time;
      _durationHours = nextDuration;
      _clearPendingReservationRequest();
    });
  }

  bool _canUseDuration(int hours) {
    final time = _selectedTime;
    return time != null && _canUseDurationAt(time, hours);
  }

  bool _canUseDurationAt(String time, int hours) {
    if (hours < 1 || hours > 4) return false;
    final startIndex = _StudioRoomDetailScreenState._times.indexOf(time);
    if (startIndex < 0 ||
        startIndex + hours > _StudioRoomDetailScreenState._times.length) {
      return false;
    }
    final startHour = int.parse(time.substring(0, 2));
    if (_bookingPolicy?.canStartAt(_selectedDate, startHour) != true) {
      return false;
    }
    for (var offset = 0; offset < hours; offset++) {
      if (!_isSlotUnoccupied(
        _StudioRoomDetailScreenState._times[startIndex + offset],
      )) {
        return false;
      }
    }
    return true;
  }

  bool _isSlotUnoccupied(String time) {
    final hour = int.parse(time.substring(0, 2));
    if (_calendarLoading || _calendarError != null) return false;
    final dateKey = _StudioRoomDetailScreenState._apiDate(_selectedDate);
    if (widget.canReserve) {
      return !(_publicAvailability?.unavailable ?? const []).any(
        (interval) =>
            _StudioRoomDetailScreenState._intervalDateKey(interval) ==
                dateKey &&
            hour >= _StudioRoomDetailScreenState._intervalStartHour(interval) &&
            hour < _StudioRoomDetailScreenState._intervalEndHour(interval),
      );
    }
    return !_scheduleOccupancies.any(
      (occupancy) =>
          occupancy.active &&
          _StudioRoomDetailScreenState._occupancyDateKey(occupancy) ==
              dateKey &&
          hour >= _StudioRoomDetailScreenState._occupancyStartHour(occupancy) &&
          hour < _StudioRoomDetailScreenState._occupancyEndHour(occupancy),
    );
  }

  void _selectDuration(int hours) {
    if (!_canUseDuration(hours)) return;
    _setState(() {
      _durationHours = hours;
      _clearPendingReservationRequest();
    });
  }

  Future<void> _confirmReservation() async {
    final time = _selectedTime;
    if (time == null || !_canUseDuration(_durationHours)) return;
    final contactPhone = await showDialog<String>(
      context: context,
      builder: (_) => _StudioReservationConfirmDialog(
        roomName: _room.name,
        dateLabel: _StudioRoomDetailScreenState._formatDate(_selectedDate),
        startTime: time,
        durationHours: _durationHours,
      ),
    );
    if (contactPhone == null ||
        contactPhone.isEmpty ||
        !mounted ||
        _reservationSubmitting) {
      return;
    }
    final startHour = int.parse(time.substring(0, 2));
    final payloadKey =
        '${_room.id}|${_StudioRoomDetailScreenState._apiDate(_selectedDate)}|$startHour|$_durationHours|${_StudioRoomDetailScreenState._phonePayloadKey(contactPhone)}';
    if (_pendingReservationPayloadKey != payloadKey) {
      _pendingReservationPayloadKey = payloadKey;
      _pendingReservationRequestId = const Uuid().v4();
    }
    _setState(() => _reservationSubmitting = true);
    final result = await _repository.createReservation(
      roomId: _room.id,
      date: _selectedDate,
      startHour: startHour,
      durationHours: _durationHours,
      contactPhone: contactPhone,
      clientRequestId: _pendingReservationRequestId!,
    );
    if (!mounted) return;
    _setState(() => _reservationSubmitting = false);
    final reservation = result.data;
    if (!result.isSuccess || reservation == null) {
      _showCalendarError(
        result.error?.message ?? 'Rezervasyon oluşturulamadı.',
      );
      if (isStudioReservationConflict(result.error)) {
        await _loadCalendarData(showLoading: false);
      }
      return;
    }
    _clearPendingReservationRequest();
    await _loadCalendarData(showLoading: false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          reservation.status.isConfirmed
              ? 'Rezervasyonun onaylandı.'
              : 'Rezervasyon talebin oluşturuldu.',
        ),
      ),
    );
  }
}
