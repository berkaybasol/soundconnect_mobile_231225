part of 'studio_profile_screen.dart';

class _StudioRoomDetailScreen extends StatefulWidget {
  final _StudioRoomItem room;
  final bool canReserve;
  final List<_StudioRoomItem> ownerRooms;

  const _StudioRoomDetailScreen({
    required this.room,
    required this.canReserve,
    this.ownerRooms = const [],
  });

  @override
  State<_StudioRoomDetailScreen> createState() =>
      _StudioRoomDetailScreenState();
}

class _StudioRoomDetailScreenState extends State<_StudioRoomDetailScreen> {
  final PageController _pageController = PageController();
  final PageController _ownerRoomPageController = PageController();
  DateTime _selectedDate = _dateOnly(DateTime.now());
  DateTime _selectedOwnerOverviewDate = _dateOnly(DateTime.now());
  DateTime _ownerDateWindowStart = _dateOnly(DateTime.now());
  int _activePhoto = 0;
  String? _selectedTime;
  int _durationHours = 1;
  late int _selectedRoomIndex;
  final Map<String, bool> _reservationApprovalOverrides = {};
  final Set<String> _cancelledReservationIds = {};
  final Map<String, List<_StudioManualBusyRange>> _manualBusyRanges = {};

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

  @override
  void initState() {
    super.initState();
    _selectedRoomIndex = 0;
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
    );
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
                    reservationCount: room.reservationCount,
                    occupiedHours:
                        room.reservedHours + _manualBusyHoursFor(room),
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
              onPressed: _pickDate,
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
              final count = switch (index) {
                0 => _room.reservationCount,
                1 when _room.reservationCount > 0 => 1,
                _ => 0,
              };
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
    final today = _dateOnly(DateTime.now());
    setState(() {
      _selectedRoomIndex = index;
      _selectedOwnerOverviewDate = today;
      _ownerDateWindowStart = today;
      _selectedDate = today;
      _selectedTime = null;
      _durationHours = 1;
    });
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.canReserve) ...[
            _StudioRoomDateSelector(
              date: _selectedDate,
              canGoBack: _selectedDate.isAfter(_dateOnly(DateTime.now())),
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
              children: _times
                  .map((time) {
                    final available = _isTimeAvailable(time);
                    return _StudioRoomTimeChip(
                      time: time,
                      available: available,
                      selected: _selectedTime == time,
                      onTap: available
                          ? () => setState(() => _selectedTime = time)
                          : null,
                    );
                  })
                  .toList(growable: false),
            )
          else
            _StudioOwnerReservationTimeline(
              times: _times,
              reservations: _ownerReservationsForSelection(),
              manualBusyRanges: _manualBusyRangesForSelection,
              isTimeAvailable: _isTimeAvailable,
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
            const SizedBox(height: 8),
            Row(
              children: [1, 2, 3, 4]
                  .map(
                    (hours) => Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: hours == 4 ? 0 : 8),
                        child: _StudioRoomDurationChip(
                          hours: hours,
                          selected: _durationHours == hours,
                          onTap: () => _selectDuration(hours),
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReservationSummary() {
    final ready = _selectedTime != null;
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
          _StudioRoomReserveButton(enabled: ready, onTap: _confirmReservation),
        ],
      ),
    );
  }

  List<_StudioOwnerReservation> _ownerReservationsForSelection() {
    final today = _dateOnly(DateTime.now());
    final dayOffset = _selectedDate.difference(today).inDays;
    if (dayOffset < 0 || dayOffset > 1 || _room.reservationCount == 0) {
      return const [];
    }

    final dateKey =
        '${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}';
    late final List<_StudioOwnerReservation> reservations;
    if (dayOffset == 1) {
      reservations = [
        _StudioOwnerReservation(
          id: '${_room.name}-$dateKey-mert',
          userId: 'mock-user-mert',
          userNo: 'SC-10483',
          profileId: 'mock-profile-mert',
          userName: 'Mert Yalçın',
          profileType: 'Müzisyen',
          avatarUrl: 'https://i.pravatar.cc/160?img=12',
          startIndex: 5,
          durationHours: 4,
          approved: !_room.reservationApprovalRequired,
        ),
      ];
    } else if (!_room.reservationApprovalRequired &&
        _room.reservationCount > 1) {
      reservations = [
        _StudioOwnerReservation(
          id: '${_room.name}-$dateKey-deniz',
          userId: 'mock-user-deniz',
          userNo: 'SC-10247',
          profileId: 'mock-profile-deniz',
          userName: 'Deniz Aksoy',
          profileType: 'Müzisyen',
          avatarUrl: 'https://i.pravatar.cc/160?img=47',
          startIndex: 1,
          durationHours: 2,
          approved: true,
        ),
        _StudioOwnerReservation(
          id: '${_room.name}-$dateKey-ece',
          userId: 'mock-user-ece',
          userNo: 'SC-10931',
          profileId: 'mock-profile-ece',
          userName: 'Ece Kaya',
          profileType: 'Vokalist',
          avatarUrl: 'https://i.pravatar.cc/160?img=32',
          startIndex: 3,
          durationHours: 1,
          approved: true,
        ),
        _StudioOwnerReservation(
          id: '${_room.name}-$dateKey-mert',
          userId: 'mock-user-mert',
          userNo: 'SC-10483',
          profileId: 'mock-profile-mert',
          userName: 'Mert Yalçın',
          profileType: 'Müzisyen',
          avatarUrl: 'https://i.pravatar.cc/160?img=12',
          startIndex: 4,
          durationHours: 2,
          approved: true,
        ),
      ];
    } else if (_room.reservationCount > 1) {
      reservations = [
        _StudioOwnerReservation(
          id: '${_room.name}-$dateKey-deniz',
          userId: 'mock-user-deniz',
          userNo: 'SC-10247',
          profileId: 'mock-profile-deniz',
          userName: 'Deniz Aksoy',
          profileType: 'Müzisyen',
          avatarUrl: 'https://i.pravatar.cc/160?img=47',
          startIndex: 1,
          durationHours: 4,
          approved: false,
        ),
        _StudioOwnerReservation(
          id: '${_room.name}-$dateKey-ece',
          userId: 'mock-user-ece',
          userNo: 'SC-10931',
          profileId: 'mock-profile-ece',
          userName: 'Ece Kaya',
          profileType: 'Vokalist',
          avatarUrl: 'https://i.pravatar.cc/160?img=32',
          startIndex: 1,
          durationHours: 2,
          approved: false,
        ),
      ];
    } else {
      reservations = [
        _StudioOwnerReservation(
          id: '${_room.name}-$dateKey-selin',
          userId: 'mock-user-selin',
          userNo: 'SC-10664',
          profileId: 'mock-profile-selin',
          userName: 'Selin Aras',
          profileType: 'Müzisyen',
          avatarUrl: 'https://i.pravatar.cc/160?img=25',
          startIndex: 3,
          durationHours: 2,
          approved: true,
        ),
      ];
    }

    return reservations
        .where(
          (reservation) => !_cancelledReservationIds.contains(reservation.id),
        )
        .map(
          (reservation) => reservation.copyWith(
            approved:
                _reservationApprovalOverrides[reservation.id] ??
                reservation.approved,
          ),
        )
        .toList(growable: false);
  }

  String _manualBusyKey(_StudioRoomItem room) {
    return '${room.name}|${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}';
  }

  List<_StudioManualBusyRange> get _manualBusyRangesForSelection =>
      _manualBusyRanges[_manualBusyKey(_room)] ?? const [];

  int _manualBusyHoursFor(_StudioRoomItem room) {
    return (_manualBusyRanges[_manualBusyKey(room)] ?? const []).fold(
      0,
      (total, range) => total + range.durationHours,
    );
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
    return _isBaseSlotAvailable(_times[index]);
  }

  Future<void> _openManualBusyEditor(int startIndex) async {
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
    setState(() {
      final key = _manualBusyKey(_room);
      final ranges =
          List<_StudioManualBusyRange>.of(
            _manualBusyRanges[key] ?? const [],
          )..add(
            _StudioManualBusyRange(startIndex: startIndex, endIndex: endIndex),
          );
      _manualBusyRanges[key] = ranges;
    });
  }

  Future<void> _removeManualBusyRange(_StudioManualBusyRange range) async {
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
    setState(() {
      final key = _manualBusyKey(_room);
      _manualBusyRanges[key] = List<_StudioManualBusyRange>.of(
        _manualBusyRanges[key] ?? const [],
      )..remove(range);
    });
  }

  Future<void> _showOwnerReservationActions(
    _StudioOwnerReservation reservation,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _StudioReservationActionSheet(
        reservation: reservation,
        roomName: _room.name,
        date: _selectedDate,
        startTime: _times[reservation.startIndex],
        endTime:
            _times[(reservation.startIndex + reservation.durationHours).clamp(
              0,
              _times.length - 1,
            )],
        onApprove: () => _approveReservation(reservation),
        onShowDetails: () => _showReservationDetails(reservation),
        onShowProfile: () => _showReservationGuestProfile(reservation),
        onSendMessage: () => _messageReservationGuest(reservation),
        onCancel: () => _confirmReservationCancellation(reservation),
      ),
    );
  }

  Future<void> _approveReservation(_StudioOwnerReservation reservation) async {
    if (!mounted) return;
    _StudioOwnerReservation? conflict;
    final candidateStart = reservation.startIndex;
    final candidateEnd = candidateStart + reservation.durationHours;
    for (final current in _ownerReservationsForSelection()) {
      if (current.id == reservation.id || !current.approved) continue;
      final currentStart = current.startIndex;
      final currentEnd = currentStart + current.durationHours;
      if (candidateStart < currentEnd && currentStart < candidateEnd) {
        conflict = current;
        break;
      }
    }
    if (conflict != null) {
      final startHour = 9 + conflict.startIndex;
      final endHour = startHour + conflict.durationHours;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: const Color(0xFF101722),
          title: const Text('Rezervasyon çakışması'),
          content: Text(
            '${conflict!.userName} için ${startHour.toString().padLeft(2, '0')}:00–${endHour.toString().padLeft(2, '0')}:00 arasında onaylanmış rezervasyon bulunuyor. Önce mevcut rezervasyonu iptal etmelisin.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Anladım'),
            ),
          ],
        ),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _reservationApprovalOverrides[reservation.id] = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${reservation.userName} rezervasyonu onaylandı.'),
      ),
    );
  }

  Future<void> _confirmReservationCancellation(
    _StudioOwnerReservation reservation,
  ) async {
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
    setState(() => _cancelledReservationIds.add(reservation.id));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Rezervasyon iptal edildi.')));
  }

  Future<void> _showReservationDetails(_StudioOwnerReservation reservation) {
    return showDialog<void>(
      context: context,
      builder: (_) => _StudioReservationDetailsDialog(
        reservation: reservation,
        roomName: _room.name,
        date: _selectedDate,
        startTime: _times[reservation.startIndex],
        endTime:
            _times[(reservation.startIndex + reservation.durationHours).clamp(
              0,
              _times.length - 1,
            )],
      ),
    );
  }

  Future<void> _showReservationGuestProfile(
    _StudioOwnerReservation reservation,
  ) async {
    await Navigator.of(context).pushNamed(
      AppRoutes.musicianPublicProfile,
      arguments: PublicProfileArgs(profileId: reservation.profileId),
    );
  }

  Future<void> _messageReservationGuest(
    _StudioOwnerReservation reservation,
  ) async {
    await Navigator.of(context).pushNamed(
      AppRoutes.dmChat,
      arguments: DmChatScreenArgs(
        otherUserId: reservation.userId,
        otherUsername: reservation.userName,
        otherUserProfilePicture: reservation.avatarUrl,
        otherMusicianProfileId: reservation.profileId,
      ),
    );
  }

  Future<void> _pickDate() async {
    final today = _dateOnly(DateTime.now());
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
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
      if (!widget.canReserve) {
        _selectedOwnerOverviewDate = _selectedDate;
        _ownerDateWindowStart = _selectedDate;
      }
    });
  }

  void _changeDate(int days) {
    final next = _selectedDate.add(Duration(days: days));
    if (next.isBefore(_dateOnly(DateTime.now()))) return;
    setState(() {
      _selectedDate = next;
      _selectedTime = null;
    });
  }

  bool _isTimeAvailable(String time) {
    final startIndex = _times.indexOf(time);
    if (startIndex < 0 || startIndex + _durationHours > _times.length) {
      return false;
    }
    for (var offset = 0; offset < _durationHours; offset++) {
      if (!_isBaseSlotAvailable(_times[startIndex + offset])) return false;
    }
    return true;
  }

  bool _isBaseSlotAvailable(String time) {
    final hour = int.parse(time.substring(0, 2));
    final now = DateTime.now();
    final isToday = _selectedDate == _dateOnly(now);
    if (isToday && hour <= now.hour) return false;
    return (_selectedDate.day + hour + _room.name.length) % 5 != 0;
  }

  void _selectDuration(int hours) {
    setState(() {
      _durationHours = hours;
      final time = _selectedTime;
      if (time != null && !_isTimeAvailable(time)) {
        _selectedTime = null;
      }
    });
  }

  Future<void> _confirmReservation() async {
    final time = _selectedTime;
    if (time == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF101722),
        title: const Text('Rezervasyonu Onayla'),
        content: Text(
          '${_room.name}\n${_formatDate(_selectedDate)} • $time\n$_durationHours saat',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Rezervasyon Oluştur'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Rezervasyon talebin oluşturuldu.')),
    );
  }

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
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPick;

  const _StudioRoomDateSelector({
    required this.date,
    required this.canGoBack,
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
        _CalendarArrowButton(icon: Icons.arrow_forward, onTap: onNext),
      ],
    );
  }
}

class _StudioManualBusyRange {
  final int startIndex;
  final int endIndex;

  const _StudioManualBusyRange({
    required this.startIndex,
    required this.endIndex,
  });

  int get durationHours => endIndex - startIndex;

  bool contains(int index) => index >= startIndex && index < endIndex;
}

String _manualHourLabel(int index) =>
    '${(9 + index).toString().padLeft(2, '0')}:00';

class _StudioOwnerReservation {
  final String id;
  final String userId;
  final String userNo;
  final String profileId;
  final String userName;
  final String profileType;
  final String avatarUrl;
  final int startIndex;
  final int durationHours;
  final bool approved;

  const _StudioOwnerReservation({
    required this.id,
    required this.userId,
    required this.userNo,
    required this.profileId,
    required this.userName,
    required this.profileType,
    required this.avatarUrl,
    required this.startIndex,
    required this.durationHours,
    required this.approved,
  });

  _StudioOwnerReservation copyWith({bool? approved}) {
    return _StudioOwnerReservation(
      id: id,
      userId: userId,
      userNo: userNo,
      profileId: profileId,
      userName: userName,
      profileType: profileType,
      avatarUrl: avatarUrl,
      startIndex: startIndex,
      durationHours: durationHours,
      approved: approved ?? this.approved,
    );
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
  final ValueChanged<_StudioOwnerReservation> onReservationTap;
  final ValueChanged<int> onEmptyTimeTap;
  final ValueChanged<_StudioManualBusyRange> onManualBusyTap;

  const _StudioOwnerReservationTimeline({
    required this.times,
    required this.reservations,
    required this.manualBusyRanges,
    required this.isTimeAvailable,
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
                      return _StudioOwnerReservationTimeTile(
                        time: times[index],
                        available: available,
                        width: tileWidth,
                        reservations: matchingReservations,
                        onTap: matchingReservations.isEmpty
                            ? available
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
  final double width;
  final List<_StudioOwnerReservation> reservations;
  final VoidCallback? onTap;

  const _StudioOwnerReservationTimeTile({
    required this.time,
    required this.available,
    required this.width,
    required this.reservations,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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

class _StudioReservationPickerTile extends StatelessWidget {
  final _StudioOwnerReservation reservation;
  final VoidCallback onTap;

  const _StudioReservationPickerTile({
    required this.reservation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = reservation.approved
        ? _studioReservationApprovedColor
        : _studioReservationPendingColor;
    final startHour = 9 + reservation.startIndex;
    final endHour = startHour + reservation.durationHours;
    return Material(
      color: const Color(0xFF101A28),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
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
                child: _StudioReservationAvatar(
                  reservation: reservation,
                  onTap: onTap,
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
  final VoidCallback onTap;

  const _StudioReservationAvatar({
    required this.reservation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = reservation.approved
        ? _studioReservationApprovedColor
        : _studioReservationPendingColor;
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
              child: Image.network(
                reservation.avatarUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => ColoredBox(
                  color: const Color(0xFF252E3D),
                  child: Center(
                    child: Text(
                      reservation.userName.substring(0, 1),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ),
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
  final VoidCallback onShowDetails;
  final VoidCallback onShowProfile;
  final VoidCallback onSendMessage;
  final VoidCallback onCancel;

  const _StudioReservationActionSheet({
    required this.reservation,
    required this.roomName,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.onApprove,
    required this.onShowDetails,
    required this.onShowProfile,
    required this.onSendMessage,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = reservation.approved
        ? _studioReservationApprovedColor
        : _studioReservationPendingColor;
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
            Row(
              children: [
                SizedBox(
                  width: 52,
                  height: 52,
                  child: _StudioReservationAvatar(
                    reservation: reservation,
                    onTap: () => _closeThen(context, onShowProfile),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _closeThen(context, onShowProfile),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Text(
                    reservation.approved ? 'Onaylı' : 'Onay Bekliyor',
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (!reservation.approved) ...[
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
            if (reservation.approved) ...[
              const SizedBox(height: 14),
              const Divider(color: Color(0xFF263244), height: 1),
              const SizedBox(height: 14),
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
            label: 'Kullanıcı No',
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
          _StudioReservationDetailRow(
            label: 'Durum',
            value: reservation.approved ? 'Onaylı' : 'Onay bekliyor',
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
  final VoidCallback onTap;

  const _StudioRoomDurationChip({
    required this.hours,
    required this.selected,
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
          color: selected ? const Color(0xFF2A172A) : const Color(0xFF0A101A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.socialPink : const Color(0xFF263244),
          ),
        ),
        child: Text(
          '$hours sa',
          style: TextStyle(
            color: selected ? const Color(0xFFFF9AAE) : Colors.white,
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
