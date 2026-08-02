part of 'studio_profile_screen.dart';

enum _StudioPublicRoomSlotState {
  available,
  occupied,
  reservedByMe,
  pendingByMe,
  past,
}

class _StudioRoomDetailScreen extends StatefulWidget {
  final _StudioRoomItem room;
  final String studioProfileId;
  final bool canReserve;
  final List<_StudioRoomItem> ownerRooms;
  final DateTime? initialDate;
  final String? initialReservationId;

  const _StudioRoomDetailScreen({
    required this.room,
    required this.studioProfileId,
    required this.canReserve,
    this.ownerRooms = const [],
    this.initialDate,
    this.initialReservationId,
  });

  @override
  State<_StudioRoomDetailScreen> createState() =>
      _StudioRoomDetailScreenState();
}

class _StudioRoomDetailScreenState extends State<_StudioRoomDetailScreen> {
  final StudioRoomRepository _repository =
      serviceLocator<StudioRoomRepository>();
  final PageController _pageController = PageController();
  final PageController _ownerRoomPageController = PageController();
  late DateTime _selectedDate;
  late DateTime _selectedOwnerOverviewDate;
  late DateTime _ownerDateWindowStart;
  StudioBookingCalendarPolicy? _bookingPolicy;
  int _activePhoto = 0;
  String? _selectedTime;
  int _durationHours = 1;
  late int _selectedRoomIndex;
  StudioRoomAvailability? _publicAvailability;
  List<StudioReservation> _customerReservations = const [];
  List<StudioReservation> _scheduleReservations = const [];
  List<StudioOccupancy> _scheduleOccupancies = const [];
  bool _calendarLoading = true;
  bool _calendarMutationInFlight = false;
  String? _calendarError;
  int _calendarLoadGeneration = 0;
  String? _pendingReservationRequestId;
  String? _pendingReservationPayloadKey;
  bool _reservationSubmitting = false;
  final Map<String, String> _manualBlockRequestIds = {};
  bool _initialReservationSheetHandled = false;

  static const _times = <String>[
    '09:00',
    '10:00',
    '11:00',
    '12:00',
    '13:00',
    '14:00',
    '15:00',
    '16:00',
    '17:00',
    '18:00',
    '19:00',
    '20:00',
    '21:00',
    '22:00',
  ];

  _StudioRoomItem get _room => widget.ownerRooms.isEmpty
      ? widget.room
      : widget.ownerRooms[_selectedRoomIndex];

  List<_StudioRoomItem> get _managedRooms =>
      widget.ownerRooms.isEmpty ? [widget.room] : widget.ownerRooms;

  List<String> get _photos => _room.photoUrls.take(10).toList();

  DateTime get _studioToday =>
      _bookingPolicy?.todayLocalDate ?? _room.todayLocalDate;

  DateTime get _latestBookableDate =>
      _bookingPolicy?.latestBookableLocalDate ??
      _studioToday.add(const Duration(days: 365));

  @override
  void initState() {
    super.initState();
    _selectedRoomIndex = 0;
    final today = _dateOnly(widget.room.todayLocalDate);
    final requestedDate = widget.initialDate == null
        ? today
        : _dateOnly(widget.initialDate!);
    final initialDate = requestedDate.isBefore(today) ? today : requestedDate;
    _selectedDate = initialDate;
    _selectedOwnerOverviewDate = initialDate;
    _ownerDateWindowStart = initialDate;
    _loadCalendarData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _ownerRoomPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: Column(
          children: [
            _StudioRoomDetailHeader(
              title: widget.ownerRooms.isNotEmpty
                  ? 'Rezervasyon Yönetimi'
                  : _room.name,
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!widget.canReserve) ...[
                      _buildOwnerReservationOverview(),
                    ],
                    if (widget.canReserve) ...[
                      _buildGallery(),
                      const SizedBox(height: 18),
                      _buildIdentity(),
                      const SizedBox(height: 14),
                      _buildFeatures(),
                      const SizedBox(height: 16),
                    ],
                    if (!widget.canReserve) ...[const SizedBox(height: 16)],
                    _buildAvailability(),
                    const SizedBox(height: 16),
                    if (widget.canReserve) _buildReservationSummary(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOwnerReservationOverview() {
    final dates = List.generate(
      5,
      (index) => _ownerDateWindowStart.add(Duration(days: index)),
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
    final today = _dateOnly(nextRoom.todayLocalDate);
    setState(() {
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
    setState(() {
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
              onPageChanged: (index) => setState(() => _activePhoto = index),
              itemBuilder: (_, index) {
                if (_photos.isEmpty) {
                  return _StudioRoomPhotoPlaceholder(room: _room);
                }
                return Image.network(
                  _photos[index],
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      _StudioRoomPhotoPlaceholder(room: _room),
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
                      ..._times.map((time) {
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
                    times: _times,
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
            value: _formatDate(_selectedDate),
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

  List<_StudioOwnerReservation> _ownerReservationsForSelection() {
    return _ownerReservationsForDate(_selectedDate);
  }

  List<_StudioOwnerReservation> _ownerReservationsForDate(DateTime date) {
    final dateKey = _apiDate(date);
    return _scheduleReservations
        .where(
          (reservation) =>
              (reservation.status.isPending ||
                  reservation.status.isConfirmed) &&
              _reservationDateKey(reservation) == dateKey,
        )
        .map(_StudioOwnerReservation.fromDomain)
        .where(
          (reservation) =>
              reservation.startIndex >= 0 &&
              reservation.startIndex < _times.length &&
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
                _occupancyDateKey(occupancy) == _apiDate(_selectedDate),
          )
          .map(_StudioManualBusyRange.fromDomain)
          .where((range) => range.durationHours > 0)
          .toList(growable: false);

  int _occupiedHoursForDate(DateTime date) {
    return _scheduleOccupancies
        .where(
          (occupancy) =>
              occupancy.active &&
              _occupancyDateKey(occupancy) == _apiDate(date),
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
    return _isSlotUnoccupied(_times[index]);
  }

  bool _canEditOwnerTime(String time) {
    final startHour = int.parse(time.substring(0, 2));
    return _bookingPolicy?.canStartAt(_selectedDate, startHour) == true;
  }

  Future<void> _openManualBusyEditor(int startIndex) async {
    if (_calendarMutationInFlight) return;
    final endOptions = <int>[];
    for (var index = startIndex; index < _times.length; index++) {
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
        '${_room.id}|${_apiDate(_selectedDate)}|$startIndex|$endIndex';
    final requestId = _manualBlockRequestIds.putIfAbsent(
      requestKey,
      () => const Uuid().v4(),
    );
    setState(() => _calendarMutationInFlight = true);
    final result = await _repository.createManualBlock(
      roomId: _room.id,
      date: _selectedDate,
      startHour: 9 + startIndex,
      durationHours: endIndex - startIndex,
      clientRequestId: requestId,
    );
    if (!mounted) return;
    setState(() => _calendarMutationInFlight = false);
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
    setState(() => _calendarMutationInFlight = true);
    final result = await _repository.releaseManualBlock(
      roomId: _room.id,
      blockId: range.id,
      expectedVersion: range.version,
    );
    if (!mounted) return;
    setState(() => _calendarMutationInFlight = false);
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
    if (!reservation.capabilitiesAt(DateTime.now().toUtc()).canApprove) {
      _showCalendarError('Bu rezervasyon artık onaylanamaz.');
      await _loadCalendarData(showLoading: false);
      return;
    }
    setState(() => _calendarMutationInFlight = true);
    final result = await _repository.approveReservation(
      roomId: _room.id,
      reservationId: reservation.id,
      expectedVersion: reservation.version,
    );
    if (!mounted) return;
    setState(() => _calendarMutationInFlight = false);
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
    if (!reservation.capabilitiesAt(DateTime.now().toUtc()).canCancel) {
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
    setState(() => _calendarMutationInFlight = true);
    final result = await _repository.cancelOwnerReservation(
      roomId: _room.id,
      reservationId: reservation.id,
      expectedVersion: reservation.version,
    );
    if (!mounted) return;
    setState(() => _calendarMutationInFlight = false);
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
    if (!reservation.capabilitiesAt(DateTime.now().toUtc()).canReject) {
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
    setState(() => _calendarMutationInFlight = true);
    final result = await _repository.rejectReservation(
      roomId: _room.id,
      reservationId: reservation.id,
      expectedVersion: reservation.version,
    );
    if (!mounted) return;
    setState(() => _calendarMutationInFlight = false);
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
    setState(() {
      _selectedDate = _dateOnly(date);
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
    setState(() {
      _selectedDate = next;
      _selectedTime = null;
      _clearPendingReservationRequest();
    });
    _loadCalendarData();
  }

  _StudioPublicRoomSlotState _publicSlotState(String time) {
    final startIndex = _times.indexOf(time);
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
    final dateKey = _apiDate(_selectedDate);
    StudioReservation? pendingReservation;
    for (final reservation in _customerReservations) {
      if (reservation.roomId != _room.id ||
          (!reservation.status.isPending && !reservation.status.isConfirmed) ||
          _reservationDateKey(reservation) != dateKey) {
        continue;
      }
      final startsAt = _localHour(
        reservation.localStartTime,
        reservation.startsAt,
      );
      final endsAt = _localHour(reservation.localEndTime, reservation.endsAt);
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
    final startHour = _localHour(
      reservation.localStartTime,
      reservation.startsAt,
    );
    final endHour = _localHour(reservation.localEndTime, reservation.endsAt);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF101722),
        title: const Text('Rezervasyonunu iptal et'),
        content: Text(
          '${_room.name}\n'
          '${_formatDate(_selectedDate)} • '
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
    setState(() => _calendarMutationInFlight = true);
    final result = await _repository.cancelCustomerReservation(
      reservationId: reservation.id,
      expectedVersion: reservation.version,
    );
    if (!mounted) return;
    setState(() => _calendarMutationInFlight = false);
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
    setState(() {
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
    final startIndex = _times.indexOf(time);
    if (startIndex < 0 || startIndex + hours > _times.length) return false;
    final startHour = int.parse(time.substring(0, 2));
    if (_bookingPolicy?.canStartAt(_selectedDate, startHour) != true) {
      return false;
    }
    for (var offset = 0; offset < hours; offset++) {
      if (!_isSlotUnoccupied(_times[startIndex + offset])) return false;
    }
    return true;
  }

  bool _isSlotUnoccupied(String time) {
    final hour = int.parse(time.substring(0, 2));
    if (_calendarLoading || _calendarError != null) return false;
    final dateKey = _apiDate(_selectedDate);
    if (widget.canReserve) {
      return !(_publicAvailability?.unavailable ?? const []).any(
        (interval) =>
            _intervalDateKey(interval) == dateKey &&
            hour >= _intervalStartHour(interval) &&
            hour < _intervalEndHour(interval),
      );
    }
    return !_scheduleOccupancies.any(
      (occupancy) =>
          occupancy.active &&
          _occupancyDateKey(occupancy) == dateKey &&
          hour >= _occupancyStartHour(occupancy) &&
          hour < _occupancyEndHour(occupancy),
    );
  }

  void _selectDuration(int hours) {
    if (!_canUseDuration(hours)) return;
    setState(() {
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
        dateLabel: _formatDate(_selectedDate),
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
        '${_room.id}|${_apiDate(_selectedDate)}|$startHour|$_durationHours|${_phonePayloadKey(contactPhone)}';
    if (_pendingReservationPayloadKey != payloadKey) {
      _pendingReservationPayloadKey = payloadKey;
      _pendingReservationRequestId = const Uuid().v4();
    }
    setState(() => _reservationSubmitting = true);
    final result = await _repository.createReservation(
      roomId: _room.id,
      date: _selectedDate,
      startHour: startHour,
      durationHours: _durationHours,
      contactPhone: contactPhone,
      clientRequestId: _pendingReservationRequestId!,
    );
    if (!mounted) return;
    setState(() => _reservationSubmitting = false);
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

  static String? _reservationPhoneError(String? value) {
    final phone = value?.trim() ?? '';
    if (phone.isEmpty) return 'Telefon numarası zorunludur.';
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 11 || !digits.startsWith('0')) {
      return 'Numara 0 ile başlayan 11 rakam olmalıdır.';
    }
    return null;
  }

  static String _phonePayloadKey(String phone) =>
      phone.replaceAll(RegExp(r'\D'), '');

  Future<void> _loadCalendarData({bool showLoading = true}) async {
    final generation = ++_calendarLoadGeneration;
    if (showLoading && mounted) {
      setState(() {
        _calendarLoading = true;
        _calendarError = null;
      });
    }
    if (widget.canReserve) {
      final availabilityFuture = _repository.getPublicAvailability(
        studioProfileId: widget.studioProfileId,
        roomId: _room.id,
        from: _selectedDate,
        to: _selectedDate,
      );
      final reservationsFuture = _repository
          .listCustomerReservationsForRoomDate(
            roomId: _room.id,
            date: _selectedDate,
          );
      final result = await availabilityFuture;
      final reservationsResult = await reservationsFuture;
      if (!mounted || generation != _calendarLoadGeneration) return;
      if (!result.isSuccess ||
          result.data == null ||
          !reservationsResult.isSuccess ||
          reservationsResult.data == null) {
        setState(() {
          _calendarLoading = false;
          _calendarError =
              result.error?.message ??
              reservationsResult.error?.message ??
              'Oda müsaitliği getirilemedi.';
        });
        return;
      }
      final customerReservations = <StudioReservation>[
        ...reservationsResult.data!.items,
      ];
      var reservationsPage = reservationsResult.data!;
      const maximumCustomerReservationPages = 20;
      while (reservationsPage.hasNext &&
          reservationsPage.pageIndex + 1 < maximumCustomerReservationPages) {
        final nextResult = await _repository
            .listCustomerReservationsForRoomDate(
              roomId: _room.id,
              date: _selectedDate,
              page: reservationsPage.pageIndex + 1,
            );
        if (!mounted || generation != _calendarLoadGeneration) return;
        final nextPage = nextResult.data;
        if (!nextResult.isSuccess || nextPage == null) {
          setState(() {
            _calendarLoading = false;
            _calendarError =
                nextResult.error?.message ?? 'Rezervasyonların getirilemedi.';
          });
          return;
        }
        customerReservations.addAll(nextPage.items);
        reservationsPage = nextPage;
      }
      setState(() {
        final availability = result.data!;
        _publicAvailability = availability;
        _customerReservations = List.unmodifiable(customerReservations);
        _bookingPolicy = StudioBookingCalendarPolicy(
          todayLocalDate: availability.todayLocalDate,
          currentLocalTime: availability.currentLocalTime,
          latestBookableLocalDateTime: availability.latestBookableLocalDateTime,
        );
        _calendarLoading = false;
        _calendarError = null;
      });
      return;
    }

    final from = _ownerDateWindowStart;
    final candidateTo = from.add(const Duration(days: 4));
    final to = candidateTo.isAfter(_latestBookableDate)
        ? _latestBookableDate
        : candidateTo;
    final reservations = <StudioReservation>[];
    List<StudioOccupancy> occupancies = const [];
    StudioBookingCalendarPolicy? bookingPolicy;
    var pageIndex = 0;
    const maximumPagesPerLoad = 20;
    while (pageIndex < maximumPagesPerLoad) {
      final result = await _repository.getOwnerSchedule(
        roomId: _room.id,
        from: from,
        to: to,
        page: pageIndex,
        size: 100,
      );
      if (!mounted || generation != _calendarLoadGeneration) return;
      final schedule = result.data;
      if (!result.isSuccess || schedule == null) {
        setState(() {
          _calendarLoading = false;
          _calendarError =
              result.error?.message ?? 'Rezervasyon takvimi getirilemedi.';
        });
        return;
      }
      reservations.addAll(schedule.reservations.items);
      occupancies = schedule.occupancies;
      bookingPolicy ??= StudioBookingCalendarPolicy(
        todayLocalDate: schedule.todayLocalDate,
        currentLocalTime: schedule.currentLocalTime,
        latestBookableLocalDateTime: schedule.latestBookableLocalDateTime,
      );
      if (!schedule.reservations.hasNext) break;
      pageIndex++;
    }
    if (!mounted || generation != _calendarLoadGeneration) return;
    if (pageIndex >= maximumPagesPerLoad) {
      setState(() {
        _calendarLoading = false;
        _calendarError =
            'Bu tarih aralığında görüntülenemeyecek kadar çok talep var.';
      });
      return;
    }
    setState(() {
      _scheduleReservations = List.unmodifiable(reservations);
      _scheduleOccupancies = List.unmodifiable(occupancies);
      _bookingPolicy = bookingPolicy;
      _calendarLoading = false;
      _calendarError = null;
    });
    _openInitialReservationSheetIfPossible();
  }

  void _openInitialReservationSheetIfPossible() {
    if (_initialReservationSheetHandled || !mounted) return;
    final reservationId = widget.initialReservationId?.trim() ?? '';
    if (reservationId.isEmpty) {
      _initialReservationSheetHandled = true;
      return;
    }
    StudioReservation? domainReservation;
    for (final reservation in _scheduleReservations) {
      if (reservation.id == reservationId) {
        domainReservation = reservation;
        break;
      }
    }
    if (domainReservation == null) return;
    _initialReservationSheetHandled = true;
    final reservation = _StudioOwnerReservation.fromDomain(domainReservation);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showOwnerReservationActions(reservation);
    });
  }

  void _showCalendarError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _clearPendingReservationRequest() {
    _pendingReservationPayloadKey = null;
    _pendingReservationRequestId = null;
  }

  static String _apiDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static int _localHour(String? value, DateTime fallback) {
    final normalized = value?.trim() ?? '';
    if (normalized.length >= 2) {
      final parsed = int.tryParse(normalized.substring(0, 2));
      if (parsed != null) return parsed;
    }
    return fallback.toLocal().hour;
  }

  static String _localDateKey(String? value, DateTime fallback) {
    final normalized = value?.trim() ?? '';
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(normalized)) {
      return normalized;
    }
    return _apiDate(fallback.toLocal());
  }

  static String _reservationDateKey(StudioReservation reservation) =>
      _localDateKey(reservation.localDate, reservation.startsAt);

  static String _occupancyDateKey(StudioOccupancy occupancy) =>
      _localDateKey(occupancy.localDate, occupancy.startsAt);

  static String _intervalDateKey(StudioUnavailableInterval interval) =>
      _localDateKey(interval.localDate, interval.startsAt);

  static int _occupancyStartHour(StudioOccupancy occupancy) =>
      _localHour(occupancy.localStartTime, occupancy.startsAt);

  static int _occupancyEndHour(StudioOccupancy occupancy) =>
      _localHour(occupancy.localEndTime, occupancy.endsAt);

  static int _intervalStartHour(StudioUnavailableInterval interval) =>
      _localHour(interval.localStartTime, interval.startsAt);

  static int _intervalEndHour(StudioUnavailableInterval interval) =>
      _localHour(interval.localEndTime, interval.endsAt);

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static String _formatDate(DateTime date) {
    const months = <String>[
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class _StudioReservationConfirmDialog extends StatefulWidget {
  const _StudioReservationConfirmDialog({
    required this.roomName,
    required this.dateLabel,
    required this.startTime,
    required this.durationHours,
  });

  final String roomName;
  final String dateLabel;
  final String startTime;
  final int durationHours;

  @override
  State<_StudioReservationConfirmDialog> createState() =>
      _StudioReservationConfirmDialogState();
}

class _StudioReservationConfirmDialogState
    extends State<_StudioReservationConfirmDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: '0')
      ..selection = const TextSelection.collapsed(offset: 1);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    Navigator.of(context).pop(_phoneController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: AlertDialog(
        backgroundColor: const Color(0xFF101722),
        title: const Text('Rezervasyonu Onayla'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.roomName}\n${widget.dateLabel} • '
                '${widget.startTime}\n${widget.durationHours} saat',
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
                textInputAction: TextInputAction.done,
                inputFormatters: const [_TurkishMobilePhoneFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Telefon numarası',
                  hintText: '0 534 576 27 72',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: _StudioRoomDetailScreenState._reservationPhoneError,
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 8),
              Text(
                'Stüdyo bu numarayı yalnızca rezervasyonunuz için görebilir.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 18),
              const Text(
                'Ödeme yöntemi',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 9),
              const _StudioReservationPaymentOption(
                icon: Icons.payments_outlined,
                title: 'Elden ödeme yapacağım',
                subtitle: 'Ödeme stüdyo ile doğrudan gerçekleştirilir.',
                selected: true,
              ),
              const SizedBox(height: 8),
              const _StudioReservationPaymentOption(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Online ödeme yapacağım',
                subtitle: 'Ödeme uygulama üzerinden gerçekleştirilir.',
                comingSoon: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: _submit,
            child: const Text('Rezervasyon Oluştur'),
          ),
        ],
      ),
    );
  }
}

class _StudioReservationPaymentOption extends StatelessWidget {
  const _StudioReservationPaymentOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.selected = false,
    this.comingSoon = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final bool comingSoon;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? const Color(0xFFFF7F87)
        : const Color(0xFF2A3547);
    return Opacity(
      opacity: comingSoon ? 0.68 : 1,
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1520),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Icon(icon, color: _roomFormIconColor, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (comingSoon) ...[
                        const SizedBox(width: 7),
                        const _StudioComingSoonBadge(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF98A2B1),
                      fontSize: 9.5,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected
                  ? const Color(0xFFFF7F87)
                  : const Color(0xFF667184),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _TurkishMobilePhoneFormatter extends TextInputFormatter {
  const _TurkishMobilePhoneFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (newValue.text.trimLeft().startsWith('+90') && digits.startsWith('90')) {
      digits = '0${digits.substring(2)}';
    } else if (digits.isEmpty) {
      digits = '0';
    } else if (!digits.startsWith('0')) {
      digits = '0$digits';
    }
    if (digits.length > 11) digits = digits.substring(0, 11);
    final formatted = _formatReservationPhone(digits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

String _formatReservationPhone(String value) {
  var digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 12 && digits.startsWith('90')) {
    digits = '0${digits.substring(2)}';
  }
  if (digits.length != 11 || !digits.startsWith('0')) {
    return value.trim();
  }
  return '${digits.substring(0, 1)} '
      '${digits.substring(1, 4)} '
      '${digits.substring(4, 7)} '
      '${digits.substring(7, 9)} '
      '${digits.substring(9, 11)}';
}

class _StudioRoomDetailHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const _StudioRoomDetailHeader({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: Row(
        children: [
          IconButton(
            tooltip: 'Geri',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _StudioRoomPhotoPlaceholder extends StatelessWidget {
  final _StudioRoomItem room;

  const _StudioRoomPhotoPlaceholder({required this.room});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: room.gradient,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            right: -28,
            bottom: -36,
            child: Icon(
              room.icon,
              size: 180,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Icon(room.icon, color: Colors.white, size: 58),
          const Positioned(
            right: 12,
            bottom: 10,
            child: Text(
              'Fotoğraf yakında',
              style: TextStyle(
                color: Color(0xFFCDD3DE),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudioRoomDetailCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _StudioRoomDetailCard({
    required this.title,
    this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
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
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(
              subtitle!,
              style: const TextStyle(color: Color(0xFF8E98A7), fontSize: 12),
            ),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _StudioRoomDetailMeta extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StudioRoomDetailMeta({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF101722),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF263244)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StudioSocialGradientIcon(icon, size: 15),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFD5DBE5),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StudioRoomDateSelector extends StatelessWidget {
  final DateTime date;
  final bool canGoBack;
  final bool canGoForward;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPick;

  const _StudioRoomDateSelector({
    required this.date,
    required this.canGoBack,
    required this.canGoForward,
    required this.onPrevious,
    required this.onNext,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CalendarArrowButton(
          icon: Icons.arrow_back,
          onTap: canGoBack ? onPrevious : null,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onPick,
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF0A101A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF263244)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.calendar_month_outlined,
                    color: Color(0xFFF06C86),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _StudioRoomDetailScreenState._formatDate(date),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _CalendarArrowButton(
          icon: Icons.arrow_forward,
          onTap: canGoForward ? onNext : null,
        ),
      ],
    );
  }
}

class _StudioManualBusyRange {
  final String id;
  final int startIndex;
  final int endIndex;
  final int version;

  const _StudioManualBusyRange({
    required this.id,
    required this.startIndex,
    required this.endIndex,
    required this.version,
  });

  factory _StudioManualBusyRange.fromDomain(StudioOccupancy occupancy) {
    return _StudioManualBusyRange(
      id: occupancy.id,
      startIndex:
          _StudioRoomDetailScreenState._occupancyStartHour(occupancy) - 9,
      endIndex: _StudioRoomDetailScreenState._occupancyEndHour(occupancy) - 9,
      version: occupancy.version,
    );
  }

  int get durationHours => endIndex - startIndex;

  bool contains(int index) => index >= startIndex && index < endIndex;
}

String _manualHourLabel(int index) =>
    '${(9 + index).toString().padLeft(2, '0')}:00';

class _StudioOwnerReservation {
  final String id;
  final String userId;
  final String userNo;
  final String userName;
  final String avatarUrl;
  final int startIndex;
  final int durationHours;
  final StudioReservationStatus status;
  final DateTime startsAt;
  final bool completed;
  final int version;
  final int? totalPriceMinor;
  final String? currency;

  const _StudioOwnerReservation({
    required this.id,
    required this.userId,
    required this.userNo,
    required this.userName,
    required this.avatarUrl,
    required this.startIndex,
    required this.durationHours,
    required this.status,
    required this.startsAt,
    required this.completed,
    required this.version,
    required this.totalPriceMinor,
    required this.currency,
  });

  factory _StudioOwnerReservation.fromDomain(StudioReservation reservation) {
    final startHour = _StudioRoomDetailScreenState._localHour(
      reservation.localStartTime,
      reservation.startsAt,
    );
    final endHour = _StudioRoomDetailScreenState._localHour(
      reservation.localEndTime,
      reservation.endsAt,
    );
    return _StudioOwnerReservation(
      id: reservation.id,
      userId: reservation.requesterId ?? '',
      userNo: reservation.requesterPhone == null
          ? reservation.requesterPublicCode ?? '—'
          : _formatReservationPhone(reservation.requesterPhone!),
      userName: reservation.requesterUsername ?? 'SoundConnect Kullanıcısı',
      avatarUrl: reservation.requesterAvatarUrl ?? '',
      startIndex: startHour - 9,
      durationHours: endHour - startHour,
      status: reservation.status,
      startsAt: reservation.startsAt,
      completed: reservation.completed,
      version: reservation.version,
      totalPriceMinor: reservation.totalPriceMinor,
      currency: reservation.currency,
    );
  }

  bool get approved => status.isConfirmed;

  StudioReservationOwnerCapabilities capabilitiesAt(DateTime now) =>
      StudioReservationOwnerCapabilities.evaluate(
        status: status,
        startsAt: startsAt,
        completed: completed,
        now: now,
      );

  String statusLabelAt(DateTime now) {
    if (completed) return 'Tamamlandı';
    if (!startsAt.toUtc().isAfter(now.toUtc())) {
      return status.isConfirmed ? 'Devam Ediyor' : 'Süresi Geçti';
    }
    return status.isConfirmed ? 'Onaylı' : 'Onay Bekliyor';
  }

  String? get totalPriceLabel {
    final minor = totalPriceMinor;
    if (minor == null) return null;
    final whole = minor ~/ 100;
    final fraction = minor.remainder(100);
    final grouped = whole.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );
    final amount = fraction == 0
        ? grouped
        : '$grouped,${fraction.toString().padLeft(2, '0')}';
    return currency == 'TRY' || currency == null
        ? '₺$amount'
        : '$amount $currency';
  }
}

const _studioReservationApprovedColor = Color(0xFF49C98A);
const _studioReservationPendingColor = Color(0xFFB58A4E);
const _studioManualBusyColor = Color(0xFFB96873);

class _StudioOwnerReservationTimeline extends StatelessWidget {
  final List<String> times;
  final List<_StudioOwnerReservation> reservations;
  final List<_StudioManualBusyRange> manualBusyRanges;
  final bool Function(String time) isTimeAvailable;
  final bool Function(String time) canEditTime;
  final ValueChanged<_StudioOwnerReservation> onReservationTap;
  final ValueChanged<int> onEmptyTimeTap;
  final ValueChanged<_StudioManualBusyRange> onManualBusyTap;

  const _StudioOwnerReservationTimeline({
    required this.times,
    required this.reservations,
    required this.manualBusyRanges,
    required this.isTimeAvailable,
    required this.canEditTime,
    required this.onReservationTap,
    required this.onEmptyTimeTap,
    required this.onManualBusyTap,
  });

  static const _columns = 4;
  static const _gap = 8.0;
  static const _tileHeight = 65.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = (constraints.maxWidth - (_gap * 3)) / _columns;
        final rowCount = (times.length / _columns).ceil();
        final timelineHeight =
            (rowCount * _tileHeight) + ((rowCount - 1) * _gap);
        return SizedBox(
          height: timelineHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var index = 0; index < times.length; index++)
                Positioned(
                  left: (index % _columns) * (tileWidth + _gap),
                  top: (index ~/ _columns) * (_tileHeight + _gap),
                  width: tileWidth,
                  height: _tileHeight,
                  child: Builder(
                    builder: (context) {
                      final matchingReservations = _reservationsAt(index);
                      final manualBusyRange = _manualBusyRangeAt(index);
                      if (manualBusyRange != null) {
                        final startLabel = _manualHourLabel(
                          manualBusyRange.startIndex,
                        ).substring(0, 2);
                        final endLabel = _manualHourLabel(
                          manualBusyRange.endIndex,
                        ).substring(0, 2);
                        return _StudioRoomTimeChip(
                          time: times[index],
                          available: false,
                          selected: false,
                          width: tileWidth,
                          verticalPadding: 0,
                          accentColor: _studioManualBusyColor,
                          statusLabel: 'Dolu · $startLabel–$endLabel',
                          statusColor: _studioManualBusyColor,
                          statusFontSize: 8,
                          onTap: () => onManualBusyTap(manualBusyRange),
                        );
                      }
                      final available =
                          matchingReservations.isEmpty &&
                          isTimeAvailable(times[index]);
                      final editable = available && canEditTime(times[index]);
                      return _StudioOwnerReservationTimeTile(
                        time: times[index],
                        available: available,
                        editable: editable,
                        width: tileWidth,
                        reservations: matchingReservations,
                        onTap: matchingReservations.isEmpty
                            ? editable
                                  ? () => onEmptyTimeTap(index)
                                  : null
                            : () => _openReservationsForTime(
                                context,
                                times[index],
                                matchingReservations,
                              ),
                      );
                    },
                  ),
                ),
              Positioned(
                left: 2 * (tileWidth + _gap),
                top: 3 * (_tileHeight + _gap),
                child: _StudioRoomBrandTile(width: (tileWidth * 2) + _gap),
              ),
            ],
          ),
        );
      },
    );
  }

  List<_StudioOwnerReservation> _reservationsAt(int index) {
    return reservations
        .where(
          (reservation) =>
              index >= reservation.startIndex &&
              index < reservation.startIndex + reservation.durationHours,
        )
        .toList(growable: false);
  }

  _StudioManualBusyRange? _manualBusyRangeAt(int index) {
    for (final range in manualBusyRanges) {
      if (range.contains(index)) return range;
    }
    return null;
  }

  Future<void> _openReservationsForTime(
    BuildContext context,
    String time,
    List<_StudioOwnerReservation> matchingReservations,
  ) async {
    if (matchingReservations.length == 1) {
      onReservationTap(matchingReservations.first);
      return;
    }
    final selected = await showModalBottomSheet<_StudioOwnerReservation>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _StudioReservationsAtTimeSheet(
        time: time,
        reservations: matchingReservations,
      ),
    );
    if (selected != null) onReservationTap(selected);
  }
}

class _StudioOwnerReservationTimeTile extends StatelessWidget {
  final String time;
  final bool available;
  final bool editable;
  final double width;
  final List<_StudioOwnerReservation> reservations;
  final VoidCallback? onTap;

  const _StudioOwnerReservationTimeTile({
    required this.time,
    required this.available,
    required this.editable,
    required this.width,
    required this.reservations,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (reservations.isEmpty && available && !editable) {
      return _StudioRoomTimeChip(
        time: time,
        available: false,
        selected: false,
        width: width,
        verticalPadding: 0,
        statusLabel: 'Geçti',
        statusColor: const Color(0xFF6F7A8B),
        onTap: null,
      );
    }
    final accentColor = reservations.isEmpty
        ? null
        : reservations.every((reservation) => reservation.approved)
        ? _studioReservationApprovedColor
        : reservations.every((reservation) => !reservation.approved)
        ? _studioReservationPendingColor
        : _studioReservationApprovedColor;
    final statusLabel = reservations.isEmpty
        ? null
        : reservations.length == 1
        ? '${_initials(reservations.first.userName)} · ${_range(reservations.first)}'
        : '${reservations.length} talep';
    return Stack(
      fit: StackFit.expand,
      children: [
        _StudioRoomTimeChip(
          time: time,
          available: available,
          selected: false,
          width: width,
          verticalPadding: 0,
          accentColor: accentColor,
          statusLabel: statusLabel,
          statusColor: accentColor,
          statusFontSize: reservations.length == 1 ? 8 : 9,
          onTap: onTap,
        ),
        if (reservations.length > 1) ...[
          Positioned(
            top: 5,
            right: 5,
            child: Container(
              width: 17,
              height: 17,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF17202D),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF59677A)),
              ),
              child: Text(
                '${reservations.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          Positioned(
            left: 9,
            right: 9,
            bottom: 5,
            height: 3,
            child: Row(
              children: [
                for (var index = 0; index < reservations.length; index++) ...[
                  if (index > 0) const SizedBox(width: 3),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: reservations[index].approved
                            ? _studioReservationApprovedColor
                            : _studioReservationPendingColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _range(_StudioOwnerReservation reservation) {
    final start = 9 + reservation.startIndex;
    final end = start + reservation.durationHours;
    return '${start.toString().padLeft(2, '0')}–${end.toString().padLeft(2, '0')}';
  }

  String _initials(String name) {
    return name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.substring(0, 1).toUpperCase())
        .join();
  }
}

Future<DmProfileTarget?> _resolveStudioReservationGuestTarget(
  _StudioOwnerReservation reservation,
) async {
  final userId = reservation.userId.trim();
  if (userId.isEmpty) return null;
  final targets = await serviceLocator<DmUserProfileResolver>().resolveByUserId(
    userId: userId,
    usernameHint: reservation.userName,
  );
  for (final target in targets) {
    if (dmProfileRouteFor(target) != null) return target;
  }
  return null;
}

class _StudioReservationsAtTimeSheet extends StatelessWidget {
  final String time;
  final List<_StudioOwnerReservation> reservations;

  const _StudioReservationsAtTimeSheet({
    required this.time,
    required this.reservations,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        decoration: const BoxDecoration(
          color: Color(0xFF0E1622),
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          border: Border(top: BorderSide(color: Color(0xFF2A3546))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF465267),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              '$time Saatindeki Rezervasyonlar',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '${reservations.length} farklı rezervasyon bu saatle çakışıyor.',
              style: const TextStyle(color: Color(0xFF9EA8B7), fontSize: 11),
            ),
            const SizedBox(height: 14),
            for (var index = 0; index < reservations.length; index++) ...[
              _StudioReservationPickerTile(
                reservation: reservations[index],
                onTap: () => Navigator.of(context).pop(reservations[index]),
              ),
              if (index < reservations.length - 1) const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _StudioReservationPickerTile extends StatefulWidget {
  final _StudioOwnerReservation reservation;
  final VoidCallback onTap;

  const _StudioReservationPickerTile({
    required this.reservation,
    required this.onTap,
  });

  @override
  State<_StudioReservationPickerTile> createState() =>
      _StudioReservationPickerTileState();
}

class _StudioReservationPickerTileState
    extends State<_StudioReservationPickerTile> {
  late Future<DmProfileTarget?> _profileTarget;

  @override
  void initState() {
    super.initState();
    _profileTarget = _resolveProfileTarget();
  }

  @override
  void didUpdateWidget(covariant _StudioReservationPickerTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reservation.userId != widget.reservation.userId) {
      _profileTarget = _resolveProfileTarget();
    }
  }

  Future<DmProfileTarget?> _resolveProfileTarget() =>
      _resolveStudioReservationGuestTarget(widget.reservation);

  @override
  Widget build(BuildContext context) {
    final reservation = widget.reservation;
    final color = reservation.approved
        ? _studioReservationApprovedColor
        : _studioReservationPendingColor;
    final startHour = 9 + reservation.startIndex;
    final endHour = startHour + reservation.durationHours;
    return Material(
      color: const Color(0xFF101A28),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.42)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: FutureBuilder<DmProfileTarget?>(
                  future: _profileTarget,
                  builder: (context, snapshot) => _StudioReservationAvatar(
                    reservation: reservation,
                    onTap: widget.onTap,
                    avatarUrlOverride: snapshot.data?.imageUrl,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reservation.userName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${startHour.toString().padLeft(2, '0')}:00–${endHour.toString().padLeft(2, '0')}:00 • ${reservation.durationHours} saat',
                      style: const TextStyle(
                        color: Color(0xFF9EA8B7),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                reservation.approved ? 'Onaylı' : 'Bekliyor',
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 5),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF8F99A9),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudioReservationAvatar extends StatelessWidget {
  final _StudioOwnerReservation reservation;
  final VoidCallback? onTap;
  final String? avatarUrlOverride;

  const _StudioReservationAvatar({
    required this.reservation,
    required this.onTap,
    this.avatarUrlOverride,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedAvatarUrl = avatarUrlOverride?.trim().isNotEmpty == true
        ? avatarUrlOverride!.trim()
        : reservation.avatarUrl.trim();
    final now = DateTime.now().toUtc();
    final capabilities = reservation.capabilitiesAt(now);
    final statusColor = capabilities.hasMutation
        ? reservation.approved
              ? _studioReservationApprovedColor
              : _studioReservationPendingColor
        : const Color(0xFF9EA8B7);
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.28),
            blurRadius: 11,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Material(
        color: const Color(0xFF101722),
        shape: CircleBorder(
          side: BorderSide(color: statusColor.withValues(alpha: 0.9), width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: ClipOval(
              child: resolvedAvatarUrl.isEmpty
                  ? _StudioReservationAvatarFallback(
                      userName: reservation.userName,
                    )
                  : Image.network(
                      resolvedAvatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _StudioReservationAvatarFallback(
                            userName: reservation.userName,
                          ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StudioReservationAvatarFallback extends StatelessWidget {
  const _StudioReservationAvatarFallback({required this.userName});

  final String userName;

  @override
  Widget build(BuildContext context) {
    final normalized = userName.trim();
    return ColoredBox(
      color: const Color(0xFF252E3D),
      child: Center(
        child: Text(
          normalized.isEmpty ? '?' : normalized.substring(0, 1).toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _StudioRoomTimeChip extends StatelessWidget {
  final String time;
  final bool available;
  final bool selected;
  final double width;
  final double verticalPadding;
  final Color? accentColor;
  final String? statusLabel;
  final Color? statusColor;
  final double statusFontSize;
  final VoidCallback? onTap;

  const _StudioRoomTimeChip({
    required this.time,
    required this.available,
    required this.selected,
    this.width = 72,
    this.verticalPadding = 10,
    this.accentColor,
    this.statusLabel,
    this.statusColor,
    this.statusFontSize = 9,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: width,
        padding: EdgeInsets.symmetric(vertical: verticalPadding),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF2A172A)
              : available
              ? const Color(0xFF0A101A)
              : const Color(0xFF090D14),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                accentColor?.withValues(alpha: 0.82) ??
                (selected
                    ? AppColors.socialPink
                    : available
                    ? const Color(0xFF263244)
                    : const Color(0xFF1A2230)),
          ),
          boxShadow: accentColor == null
              ? null
              : [
                  BoxShadow(
                    color: accentColor!.withValues(alpha: 0.16),
                    blurRadius: 8,
                  ),
                ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              time,
              style: TextStyle(
                color: accentColor != null
                    ? Colors.white
                    : available
                    ? Colors.white
                    : const Color(0xFF596271),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              statusLabel ?? (available ? 'Müsait' : 'Dolu'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color:
                    statusColor ??
                    (available
                        ? const Color(0xFF1EAF4D)
                        : const Color(0xFF7D4248)),
                fontSize: statusFontSize,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudioRoomBrandTile extends StatelessWidget {
  final double width;

  const _StudioRoomBrandTile({required this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 65,
      decoration: BoxDecoration(
        color: const Color(0xFF090F18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF263244)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ClipRect(
            child: Image.asset(
              'assets/logotransparent.png',
              fit: BoxFit.fitWidth,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      ),
    );
  }
}

class _StudioManualBusySheet extends StatefulWidget {
  final String roomName;
  final DateTime date;
  final int startIndex;
  final List<int> endOptions;

  const _StudioManualBusySheet({
    required this.roomName,
    required this.date,
    required this.startIndex,
    required this.endOptions,
  });

  @override
  State<_StudioManualBusySheet> createState() => _StudioManualBusySheetState();
}

class _StudioManualBusySheetState extends State<_StudioManualBusySheet> {
  late int _selectedEndIndex;

  @override
  void initState() {
    super.initState();
    _selectedEndIndex = widget.endOptions.first;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        decoration: const BoxDecoration(
          color: Color(0xFF0E1622),
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          border: Border(top: BorderSide(color: Color(0xFF2A3546))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF465267),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Dolu Olarak İşaretle',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '${widget.roomName} • ${_studioReservationDateLabel(widget.date)}',
              style: const TextStyle(color: Color(0xFF9EA8B7), fontSize: 11),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFF101A28),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: const Color(0xFF263244)),
              ),
              child: Row(
                children: [
                  const Text(
                    'Başlangıç',
                    style: TextStyle(color: Color(0xFF8F99A9), fontSize: 12),
                  ),
                  const Spacer(),
                  Text(
                    _manualHourLabel(widget.startIndex),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Bitiş Saatini Seç',
              style: TextStyle(
                color: Color(0xFFCDD3DE),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 9),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final endIndex in widget.endOptions)
                  _StudioManualEndTimeChip(
                    label: _manualHourLabel(endIndex),
                    selected: _selectedEndIndex == endIndex,
                    onTap: () => setState(() => _selectedEndIndex = endIndex),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: AppColors.brandGradient),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(_selectedEndIndex),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.block_outlined, size: 18),
                label: const Text(
                  'Dolu Olarak İşaretle',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudioManualEndTimeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _StudioManualEndTimeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? _studioManualBusyColor.withValues(alpha: 0.14)
              : const Color(0xFF0A101A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? _studioManualBusyColor : const Color(0xFF263244),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFFFFB5BD) : Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _StudioReservationActionSheet extends StatelessWidget {
  final _StudioOwnerReservation reservation;
  final String roomName;
  final DateTime date;
  final String startTime;
  final String endTime;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onShowDetails;
  final Future<DmProfileTarget?> profileTarget;
  final ValueChanged<DmProfileTarget> onShowProfile;
  final VoidCallback onSendMessage;
  final VoidCallback onCancel;

  const _StudioReservationActionSheet({
    required this.reservation,
    required this.roomName,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.onApprove,
    required this.onReject,
    required this.onShowDetails,
    required this.profileTarget,
    required this.onShowProfile,
    required this.onSendMessage,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc();
    final capabilities = reservation.capabilitiesAt(now);
    final statusColor = capabilities.hasMutation
        ? reservation.approved
              ? _studioReservationApprovedColor
              : _studioReservationPendingColor
        : const Color(0xFF9EA8B7);
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        decoration: const BoxDecoration(
          color: Color(0xFF0E1622),
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          border: Border(top: BorderSide(color: Color(0xFF2A3546))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF465267),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            _StudioReservationGuestHeader(
              reservation: reservation,
              roomName: roomName,
              startTime: startTime,
              endTime: endTime,
              statusLabel: reservation.statusLabelAt(now),
              statusColor: statusColor,
              profileTarget: profileTarget,
              onShowProfile: (target) =>
                  _closeThen(context, () => onShowProfile(target)),
            ),
            const SizedBox(height: 18),
            if (capabilities.canApprove) ...[
              _StudioReservationSheetAction(
                icon: Icons.check_circle_outline_rounded,
                label: 'Rezervasyonu Onayla',
                color: _studioReservationApprovedColor,
                emphasized: true,
                onTap: () => _closeThen(context, onApprove),
              ),
              const SizedBox(height: 8),
            ],
            _StudioReservationSheetAction(
              icon: Icons.receipt_long_outlined,
              label: 'Rezervasyon Bilgileri',
              onTap: () => _closeThen(context, onShowDetails),
            ),
            const SizedBox(height: 8),
            _StudioReservationSheetAction(
              icon: Icons.chat_bubble_outline_rounded,
              label: 'Kullanıcıya Mesaj Gönder',
              onTap: () => _closeThen(context, onSendMessage),
            ),
            if (capabilities.canReject ||
                (reservation.approved && capabilities.canCancel)) ...[
              const SizedBox(height: 14),
              const Divider(color: Color(0xFF263244), height: 1),
              const SizedBox(height: 14),
              if (capabilities.canReject)
                _StudioReservationSheetAction(
                  icon: Icons.cancel_outlined,
                  label: 'Talebi Reddet',
                  color: const Color(0xFFFF7373),
                  onTap: () => _closeThen(context, onReject),
                )
              else
                _StudioReservationSheetAction(
                  icon: Icons.event_busy_outlined,
                  label: 'Rezervasyonu İptal Et',
                  color: const Color(0xFFFF7373),
                  onTap: () => _closeThen(context, onCancel),
                ),
            ],
          ],
        ),
      ),
    );
  }

  void _closeThen(BuildContext context, VoidCallback callback) {
    Navigator.of(context).pop();
    Future<void>.delayed(Duration.zero, callback);
  }
}

class _StudioReservationGuestHeader extends StatelessWidget {
  const _StudioReservationGuestHeader({
    required this.reservation,
    required this.roomName,
    required this.startTime,
    required this.endTime,
    required this.statusLabel,
    required this.statusColor,
    required this.profileTarget,
    required this.onShowProfile,
  });

  final _StudioOwnerReservation reservation;
  final String roomName;
  final String startTime;
  final String endTime;
  final String statusLabel;
  final Color statusColor;
  final Future<DmProfileTarget?> profileTarget;
  final ValueChanged<DmProfileTarget> onShowProfile;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DmProfileTarget?>(
      future: profileTarget,
      builder: (context, snapshot) {
        final target = snapshot.data;
        final onProfileTap = target == null
            ? null
            : () => onShowProfile(target);
        return Row(
          children: [
            SizedBox(
              width: 52,
              height: 52,
              child: _StudioReservationAvatar(
                reservation: reservation,
                onTap: onProfileTap,
                avatarUrlOverride: target?.imageUrl,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onProfileTap,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reservation.userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$roomName • $startTime–$endTime',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFA2ACBA),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: statusColor.withValues(alpha: 0.45)),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StudioReservationSheetAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool emphasized;
  final VoidCallback onTap;

  const _StudioReservationSheetAction({
    required this.icon,
    required this.label,
    this.color = const Color(0xFFD7DCE5),
    this.emphasized = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: emphasized
          ? color.withValues(alpha: 0.10)
          : const Color(0xFF101A28),
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: emphasized
                  ? color.withValues(alpha: 0.42)
                  : const Color(0xFF263244),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: color, size: 19),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudioReservationDetailsDialog extends StatelessWidget {
  final _StudioOwnerReservation reservation;
  final String roomName;
  final DateTime date;
  final String startTime;
  final String endTime;

  const _StudioReservationDetailsDialog({
    required this.reservation,
    required this.roomName,
    required this.date,
    required this.startTime,
    required this.endTime,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF101722),
      title: const Text('Rezervasyon Bilgileri'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StudioReservationDetailRow(
            label: 'Kullanıcı',
            value: reservation.userName,
          ),
          _StudioReservationDetailRow(
            label: 'Telefon Numarası',
            value: reservation.userNo,
          ),
          _StudioReservationDetailRow(label: 'Oda', value: roomName),
          _StudioReservationDetailRow(
            label: 'Tarih',
            value: _studioReservationDateLabel(date),
          ),
          _StudioReservationDetailRow(
            label: 'Saat',
            value: '$startTime–$endTime',
          ),
          _StudioReservationDetailRow(
            label: 'Süre',
            value: '${reservation.durationHours} saat',
          ),
          if (reservation.totalPriceLabel != null)
            _StudioReservationDetailRow(
              label: 'Toplam',
              value: reservation.totalPriceLabel!,
            ),
          _StudioReservationDetailRow(
            label: 'Durum',
            value: reservation.statusLabelAt(DateTime.now().toUtc()),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Kapat'),
        ),
      ],
    );
  }
}

class _StudioReservationDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _StudioReservationDetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF8F99A9), fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _studioReservationDateLabel(DateTime date) {
  const months = [
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

class _StudioRoomDurationChip extends StatelessWidget {
  final int hours;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  const _StudioRoomDurationChip({
    required this.hours,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF2A172A)
              : enabled
              ? const Color(0xFF0A101A)
              : const Color(0xFF090D14),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? AppColors.socialPink
                : enabled
                ? const Color(0xFF263244)
                : const Color(0xFF1A2230),
          ),
        ),
        child: Text(
          '$hours sa',
          style: TextStyle(
            color: selected
                ? const Color(0xFFFF9AAE)
                : enabled
                ? Colors.white
                : const Color(0xFF596271),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _StudioRoomReservationRow extends StatelessWidget {
  final String label;
  final String value;

  const _StudioRoomReservationRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF8E98A7), fontSize: 12),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _StudioRoomReserveButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _StudioRoomReserveButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: enabled
            ? LinearGradient(colors: AppColors.brandGradient)
            : null,
        color: enabled ? null : const Color(0xFF252B35),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ElevatedButton.icon(
        onPressed: enabled ? onTap : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        icon: const Icon(Icons.event_available_outlined, size: 19),
        label: const Text(
          'Rezervasyon Oluştur',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _StudioRoomSwipeCue extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _StudioRoomSwipeCue({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 32, height: 40),
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Icon(
        icon,
        size: 23,
        color: const Color(0xFFAEB7C5),
        shadows: const [Shadow(color: Color(0xCC05080D), blurRadius: 7)],
      ),
    );
  }
}

class _StudioOwnerRoomSummaryCard extends StatelessWidget {
  final _StudioRoomItem room;
  final int reservationCount;
  final int occupiedHours;

  const _StudioOwnerRoomSummaryCard({
    required this.room,
    required this.reservationCount,
    required this.occupiedHours,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1622),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF263244)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: room.gradient),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(room.icon, color: Colors.white, size: 23),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (room.type.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        room.type,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF9EA8B7),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StudioOwnerRoomMetric(
                  value: '$reservationCount',
                  label: 'Rezervasyon',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StudioOwnerRoomMetric(
                  value: '$occupiedHours saat',
                  label: 'Dolu Süre',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StudioOwnerRoomMetric extends StatelessWidget {
  final String value;
  final String label;

  const _StudioOwnerRoomMetric({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFF090F18),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFF263244)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF8F99A9), fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _StudioOwnerReservationDateCard extends StatelessWidget {
  final DateTime date;
  final int reservationCount;
  final bool selected;
  final VoidCallback onTap;

  const _StudioOwnerReservationDateCard({
    required this.date,
    required this.reservationCount,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 70,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF17202D) : const Color(0xFF0D141F),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? const Color(0xFFFF8A8A) : const Color(0xFF263244),
          ),
        ),
        child: Column(
          children: [
            Text(
              _ownerOverviewWeekday(date.weekday),
              style: const TextStyle(color: Color(0xFF9EA8B7), fontSize: 10),
            ),
            const SizedBox(height: 3),
            Text(
              date.day.toString(),
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFFD5DBE5),
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              reservationCount == 0 ? 'Boş' : '$reservationCount kayıt',
              style: TextStyle(
                color: reservationCount == 0
                    ? const Color(0xFF7F8998)
                    : const Color(0xFF67D6A1),
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

bool _sameRoomOverviewDate(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

String _ownerOverviewWeekday(int weekday) =>
    const ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'][weekday - 1];
