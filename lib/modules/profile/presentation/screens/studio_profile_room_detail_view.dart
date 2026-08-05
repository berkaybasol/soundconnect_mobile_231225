part of 'studio_profile_screen.dart';

extension _StudioRoomDetailView on _StudioRoomDetailScreenState {
  Widget _buildOwnerReservationOverview() {
    final dates = List.generate(
      5,
      (index) => studioAddCivilDays(_ownerDateWindowStart, index),
    ).where((date) => !date.isAfter(_latestBookableDate)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 162,
          child: Stack(
            children: [
              PageView.builder(
                controller: _ownerRoomPageController,
                itemCount: _managedRooms.length,
                onPageChanged: _selectRoom,
                itemBuilder: (context, index) {
                  final room = _managedRooms[index];
                  return _StudioOwnerRoomSummaryCard(
                    room: room,
                    reservationCount: index == _selectedRoomIndex
                        ? _ownerReservationsForDate(
                            _selectedOwnerOverviewDate,
                          ).length
                        : room.reservationCount,
                    occupiedHours: index == _selectedRoomIndex
                        ? _occupiedHoursForDate(_selectedOwnerOverviewDate)
                        : room.reservedHours,
                  );
                },
              ),
              if (_selectedRoomIndex > 0)
                Positioned(
                  left: 0,
                  top: 61,
                  child: _StudioRoomSwipeCue(
                    icon: Icons.chevron_left_rounded,
                    tooltip: 'Önceki oda',
                    onTap: () => _animateToRoom(_selectedRoomIndex - 1),
                  ),
                ),
              if (_selectedRoomIndex < _managedRooms.length - 1)
                Positioned(
                  right: 0,
                  top: 61,
                  child: _StudioRoomSwipeCue(
                    icon: Icons.chevron_right_rounded,
                    tooltip: 'Sonraki oda',
                    onTap: () => _animateToRoom(_selectedRoomIndex + 1),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _managedRooms.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 7,
              height: 7,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: index == _selectedRoomIndex
                    ? const Color(0xFFFF8A8A)
                    : const Color(0xFF3A4658),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Tarih Seç',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _calendarLoading ? null : _pickDate,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFD7DCE5),
                minimumSize: const Size(0, 34),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                side: const BorderSide(color: Color(0xFF334157)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              icon: const Icon(Icons.calendar_month_outlined, size: 16),
              label: const Text('Takvimi Aç'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 84,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: dates.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final date = dates[index];
              final count = _ownerReservationsForDate(date).length;
              return _StudioOwnerReservationDateCard(
                date: date,
                reservationCount: count,
                selected: _sameRoomOverviewDate(
                  date,
                  _selectedOwnerOverviewDate,
                ),
                onTap: () => _selectOwnerDate(date),
              );
            },
          ),
        ),
      ],
    );
  }

  void _selectRoom(int index) {
    if (index == _selectedRoomIndex || index >= _managedRooms.length) return;
    final nextRoom = _managedRooms[index];
    final today = _StudioRoomDetailScreenState._dateOnly(
      nextRoom.todayLocalDate,
    );
    _setState(() {
      _selectedRoomIndex = index;
      _bookingPolicy = null;
      _selectedOwnerOverviewDate = today;
      _ownerDateWindowStart = today;
      _selectedDate = today;
      _selectedTime = null;
      _durationHours = 1;
      _clearPendingReservationRequest();
    });
    _loadCalendarData();
  }

  void _animateToRoom(int index) {
    if (index < 0 || index >= _managedRooms.length) return;
    if (!_ownerRoomPageController.hasClients) return;
    _ownerRoomPageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  void _selectOwnerDate(DateTime date) {
    _setState(() {
      _selectedOwnerOverviewDate = date;
      _selectedDate = date;
      _selectedTime = null;
    });
  }

  Widget _buildGallery() {
    final pageCount = _photos.isEmpty ? 1 : _photos.length;
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 16 / 10,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: PageView.builder(
              controller: _pageController,
              itemCount: pageCount,
              onPageChanged: (index) => _setState(() => _activePhoto = index),
              itemBuilder: (_, index) {
                if (_photos.isEmpty) {
                  return _StudioRoomPhotoPlaceholder(room: _room);
                }
                return AppCachedNetworkImage(
                  imageUrl: _photos[index],
                  fit: BoxFit.cover,
                  cacheProfile: AppImageCacheProfile.original,
                  cacheWidth: 1200,
                  errorBuilder: (_) => _StudioRoomPhotoPlaceholder(room: _room),
                );
              },
            ),
          ),
        ),
        if (pageCount > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              pageCount,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: index == _activePhoto ? 18 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  gradient: index == _activePhoto
                      ? LinearGradient(colors: AppColors.brandGradient)
                      : null,
                  color: index == _activePhoto ? null : const Color(0xFF3A4453),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildIdentity() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _room.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              if (_room.type.trim().isNotEmpty) ...[
                Text(
                  _room.type,
                  style: const TextStyle(
                    color: Color(0xFFB5BDCA),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
              ] else
                const SizedBox(height: 5),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StudioRoomDetailMeta(
                    icon: Icons.people_outline,
                    label: _room.capacity,
                  ),
                  _StudioRoomDetailMeta(
                    icon: Icons.payments_outlined,
                    label: _room.price,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _StudioRoomStatusPill(room: _room),
      ],
    );
  }

  Widget _buildFeatures() {
    return _StudioRoomDetailCard(
      title: 'Oda Özellikleri',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _room.features
            .map((feature) => _StudioRoomFeatureChip(label: feature))
            .toList(growable: false),
      ),
    );
  }

  Widget _buildAvailability() {
    return _StudioRoomDetailCard(
      title: 'Müsaitlik ve Rezervasyon',
      subtitle: widget.canReserve
          ? 'Tarih ve başlangıç saati seç'
          : 'Seçili güne ait saatlik rezervasyon durumu',
      child: _calendarLoading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          : _calendarError != null
          ? _StudioRoomsErrorState(
              message: _calendarError!,
              onRetry: _loadCalendarData,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_calendarMutationInFlight) ...[
                  const LinearProgressIndicator(minHeight: 2),
                  const SizedBox(height: 12),
                ],
                if (widget.canReserve) ...[
                  _StudioRoomDateSelector(
                    date: _selectedDate,
                    canGoBack:
                        _bookingPolicy?.shiftDate(_selectedDate, -1) != null,
                    canGoForward:
                        _bookingPolicy?.shiftDate(_selectedDate, 1) != null,
                    onPrevious: () => _changeDate(-1),
                    onNext: () => _changeDate(1),
                    onPick: _pickDate,
                  ),
                  const SizedBox(height: 16),
                ],
                if (widget.canReserve)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ..._StudioRoomDetailScreenState._times.map((time) {
                        final state = _publicSlotState(time);
                        final available =
                            state == _StudioPublicRoomSlotState.available;
                        final ownReservation =
                            state == _StudioPublicRoomSlotState.reservedByMe ||
                                state == _StudioPublicRoomSlotState.pendingByMe
                            ? _customerReservationAt(
                                int.parse(time.substring(0, 2)),
                              )
                            : null;
                        final statusLabel = switch (state) {
                          _StudioPublicRoomSlotState.available => null,
                          _StudioPublicRoomSlotState.occupied => 'Dolu',
                          _StudioPublicRoomSlotState.reservedByMe =>
                            'Rezervasyonun',
                          _StudioPublicRoomSlotState.pendingByMe =>
                            'Onay Bekliyor',
                          _StudioPublicRoomSlotState.past => 'Geçti',
                        };
                        final accentColor = switch (state) {
                          _StudioPublicRoomSlotState.reservedByMe =>
                            _studioReservationApprovedColor,
                          _StudioPublicRoomSlotState.pendingByMe =>
                            _studioReservationPendingColor,
                          _ => null,
                        };
                        final statusColor = switch (state) {
                          _StudioPublicRoomSlotState.reservedByMe =>
                            _studioReservationApprovedColor,
                          _StudioPublicRoomSlotState.pendingByMe =>
                            _studioReservationPendingColor,
                          _StudioPublicRoomSlotState.available ||
                          _StudioPublicRoomSlotState.occupied => null,
                          _StudioPublicRoomSlotState.past => const Color(
                            0xFF6F7A8B,
                          ),
                        };
                        return _StudioRoomTimeChip(
                          time: time,
                          available: available,
                          selected: _selectedTime == time,
                          accentColor: accentColor,
                          statusLabel: statusLabel,
                          statusColor: statusColor,
                          onTap: switch ((available, ownReservation)) {
                            (true, _) => () => _selectStartTime(time),
                            (false, final reservation?) =>
                              () => _confirmCustomerReservationCancellation(
                                reservation,
                              ),
                            _ => null,
                          },
                        );
                      }),
                      const _StudioRoomBrandTile(width: 152),
                    ],
                  )
                else
                  _StudioOwnerReservationTimeline(
                    times: _StudioRoomDetailScreenState._times,
                    reservations: _ownerReservationsForSelection(),
                    manualBusyRanges: _manualBusyRangesForSelection,
                    isTimeAvailable: _isSlotUnoccupied,
                    canEditTime: _canEditOwnerTime,
                    onReservationTap: _showOwnerReservationActions,
                    onEmptyTimeTap: _openManualBusyEditor,
                    onManualBusyTap: _removeManualBusyRange,
                  ),
                if (widget.canReserve) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Rezervasyon Süresi',
                    style: TextStyle(
                      color: Color(0xFFCDD3DE),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _selectedTime == null
                        ? 'Önce başlangıç saatini seç'
                        : '$_selectedTime için uygun süreler',
                    style: const TextStyle(
                      color: Color(0xFF7F8998),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [1, 2, 3, 4]
                        .map((hours) {
                          final enabled = _canUseDuration(hours);
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                right: hours == 4 ? 0 : 8,
                              ),
                              child: _StudioRoomDurationChip(
                                hours: hours,
                                selected: enabled && _durationHours == hours,
                                enabled: enabled,
                                onTap: enabled
                                    ? () => _selectDuration(hours)
                                    : null,
                              ),
                            ),
                          );
                        })
                        .toList(growable: false),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildReservationSummary() {
    final ready = _selectedTime != null && _canUseDuration(_durationHours);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF101722),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF202B3A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StudioRoomReservationRow(
            label: 'Tarih',
            value: _StudioRoomDetailScreenState._formatDate(_selectedDate),
          ),
          const SizedBox(height: 8),
          _StudioRoomReservationRow(
            label: 'Saat',
            value: _selectedTime ?? 'Başlangıç saati seç',
          ),
          const SizedBox(height: 8),
          _StudioRoomReservationRow(
            label: 'Süre',
            value: '$_durationHours saat',
          ),
          const SizedBox(height: 14),
          _StudioRoomReserveButton(
            enabled: ready && !_reservationSubmitting,
            onTap: _confirmReservation,
          ),
        ],
      ),
    );
  }
}
