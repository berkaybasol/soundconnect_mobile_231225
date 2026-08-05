part of 'studio_profile_screen.dart';

class _BacklineDayAvailability {
  final int busyCount;
  final int maintenanceCount;

  const _BacklineDayAvailability({
    this.busyCount = 0,
    this.maintenanceCount = 0,
  });

  int availableCount(int total) =>
      (total - busyCount - maintenanceCount).clamp(0, total).toInt();

  factory _BacklineDayAvailability.fromDomain(
    StudioEquipmentAvailabilityDay day,
  ) => _BacklineDayAvailability(
    busyCount: day.busyQuantity,
    maintenanceCount: day.maintenanceQuantity,
  );
}

class _BacklineAvailabilityManagementScreen extends StatefulWidget {
  const _BacklineAvailabilityManagementScreen();

  @override
  State<_BacklineAvailabilityManagementScreen> createState() =>
      _BacklineAvailabilityManagementScreenState();
}

class _BacklineAvailabilityManagementScreenState
    extends State<_BacklineAvailabilityManagementScreen> {
  late final StudioEquipmentRepository _repository;
  _StudioBacklineInventoryItem? _selectedEquipment;

  @override
  void initState() {
    super.initState();
    _repository = serviceLocator<StudioEquipmentRepository>();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ekipman Takvimi'), centerTitle: true),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
          children: [
            _buildEquipmentSelector(),
            const SizedBox(height: 14),
            if (_selectedEquipment == null)
              const _BacklineAvailabilityEmptyState()
            else
              _BacklineDateAvailabilityCalendar(
                key: ValueKey(_selectedEquipment!.id),
                repository: _repository,
                equipmentId: _selectedEquipment!.id,
                equipmentName: _selectedEquipment!.name,
                total: _selectedEquipment!.total,
                referenceDate: _selectedEquipment!.todayLocalDate,
                initiallyAvailable: _selectedEquipment!.total,
                editable: true,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEquipmentSelector() {
    return Material(
      color: _ownerManagementCardColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: _selectEquipment,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _ownerManagementCardBorderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _ownerManagementInsetColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _ownerManagementInsetBorderColor),
                ),
                child: Icon(
                  _selectedEquipment?.icon ?? Icons.add_business_outlined,
                  color: const Color(0xFFD6DCE6),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedEquipment == null
                          ? 'Müsaitlik yönetimine başlamak için'
                          : 'Takvimi düzenlenen ekipman',
                      style: TextStyle(
                        color: Color(0xFF8F9AAA),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _selectedEquipment?.name ?? 'Ekipman Seç',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (_selectedEquipment != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${_selectedEquipment!.category} • ${_selectedEquipment!.total} adet',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFA5ADBA),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.unfold_more_rounded, color: Color(0xFFAAB2BF)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectEquipment() async {
    final selected = await showModalBottomSheet<_StudioBacklineInventoryItem>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF0B1321),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _BacklineAvailabilityEquipmentPicker(
        repository: _repository,
        selected: _selectedEquipment,
      ),
    );
    if (!mounted || selected == null || selected == _selectedEquipment) return;
    setState(() => _selectedEquipment = selected);
  }
}

class _BacklineAvailabilityEmptyState extends StatelessWidget {
  const _BacklineAvailabilityEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 34),
      decoration: BoxDecoration(
        color: _ownerManagementCardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _ownerManagementCardBorderColor),
      ),
      child: const Column(
        children: [
          Icon(Icons.touch_app_outlined, color: Color(0xFF7F8998), size: 34),
          SizedBox(height: 10),
          Text(
            'Önce bir ekipman seçin',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Seçtiğiniz ekipmanın müsaitlik takvimi burada açılacak.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF929CAA), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _BacklineDateAvailabilityCalendar extends StatefulWidget {
  final StudioEquipmentRepository? repository;
  final String? equipmentId;
  final String? studioProfileId;
  final DateTime? referenceDate;
  final String equipmentName;
  final int total;
  final int initiallyAvailable;
  final int initiallyMaintenance;
  final bool editable;

  const _BacklineDateAvailabilityCalendar({
    super.key,
    this.repository,
    this.equipmentId,
    this.studioProfileId,
    this.referenceDate,
    required this.equipmentName,
    required this.total,
    required this.initiallyAvailable,
    this.initiallyMaintenance = 0,
    required this.editable,
  });

  @override
  State<_BacklineDateAvailabilityCalendar> createState() =>
      _BacklineDateAvailabilityCalendarState();
}

class _BacklineDateAvailabilityCalendarState
    extends State<_BacklineDateAvailabilityCalendar> {
  late DateTime _selectedDate;
  late DateTime _visibleMonth;
  late Map<DateTime, _BacklineDayAvailability> _values;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  bool _isLoading = false;
  bool _rangeDialogOpen = false;
  String? _loadError;
  int _loadGeneration = 0;

  DateTime? get _resolvedToday => studioCalendarReferenceDate(
    serverDate: widget.referenceDate,
    editable: widget.editable,
    hasRemoteRepository: widget.repository != null,
    presentationFallback: !widget.editable && widget.repository == null
        ? DateTime.now()
        : null,
  );

  // The sentinel is never rendered or submitted: invalid production
  // configurations are hidden behind [_configurationError].
  DateTime get _today => _resolvedToday ?? DateTime(2000);

  String? get _configurationError {
    if (_resolvedToday == null) {
      return 'Stüdyo yerel tarihi doğrulanamadı. Takvim güvenli şekilde kapatıldı.';
    }
    if (widget.editable && widget.repository == null) {
      return 'Müsaitlik takvimi düzenleme servisi hazır değil.';
    }
    if (widget.repository != null &&
        (widget.equipmentId?.trim().isEmpty ?? true)) {
      return 'Ekipman kimliği doğrulanamadı.';
    }
    if (widget.repository != null &&
        !widget.editable &&
        (widget.studioProfileId?.trim().isEmpty ?? true)) {
      return 'Stüdyo kimliği doğrulanamadı.';
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    final today = _today;
    _selectedDate = today;
    _visibleMonth = DateTime(today.year, today.month);
    _values = <DateTime, _BacklineDayAvailability>{};
    _loadError = _configurationError;
    if (_configurationError == null && _hasRemoteSource) _loadVisibleMonth();
  }

  @override
  void didUpdateWidget(covariant _BacklineDateAvailabilityCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.equipmentId != oldWidget.equipmentId ||
        widget.studioProfileId != oldWidget.studioProfileId ||
        widget.referenceDate != oldWidget.referenceDate ||
        widget.repository != oldWidget.repository ||
        widget.editable != oldWidget.editable) {
      final today = _today;
      _values = <DateTime, _BacklineDayAvailability>{};
      _selectedDate = today;
      _visibleMonth = DateTime(today.year, today.month);
      _rangeStart = null;
      _rangeEnd = null;
      _loadError = _configurationError;
      if (_configurationError == null && _hasRemoteSource) {
        _loadVisibleMonth();
      }
    }
  }

  bool get _hasRemoteSource =>
      widget.repository != null &&
      (widget.equipmentId?.trim().isNotEmpty ?? false) &&
      (widget.editable || (widget.studioProfileId?.trim().isNotEmpty ?? false));

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF101722),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF202B3A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Müsaitlik Takvimi',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.equipmentName,
            style: const TextStyle(color: Color(0xFFB5BDCA), fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            widget.editable
                ? 'İlk dokunuş başlangıç, ikinci dokunuş bitiş tarihidir.'
                : 'Günlük, haftalık ve aylık kiralama müsaitliğini inceleyin.',
            style: const TextStyle(color: Color(0xFF7F8998), fontSize: 11),
          ),
          const SizedBox(height: 16),
          if (_isLoading) ...[
            const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: 12),
          ],
          if (_loadError != null) ...[
            _StudioOwnerBacklineErrorState(
              message: _loadError!,
              onRetry: _loadVisibleMonth,
            ),
            const SizedBox(height: 12),
          ],
          if (_configurationError == null) ...[
            _buildMonthSelector(),
            const SizedBox(height: 14),
            Row(
              children: [
                for (final label in [
                  'Pzt',
                  'Sal',
                  'Çar',
                  'Per',
                  'Cum',
                  'Cmt',
                  'Paz',
                ])
                  Expanded(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF8993A2),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 7),
            _buildMonthGrid(),
            const SizedBox(height: 14),
            const _CalendarLegend(),
            const SizedBox(height: 14),
            _buildSelectedDaySummary(),
          ],
        ],
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Row(
      children: [
        _CalendarArrowButton(
          icon: Icons.arrow_back,
          onTap: !_isLoading && !_rangeDialogOpen && _canMoveBackward
              ? () => _moveMonth(-1)
              : null,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _isLoading || _rangeDialogOpen ? null : _openCalendarPicker,
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
                  Text(
                    _monthYearLabel(_visibleMonth),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
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
          onTap: !_isLoading && !_rangeDialogOpen && _canMoveForward
              ? () => _moveMonth(1)
              : null,
        ),
      ],
    );
  }

  Widget _buildMonthGrid() {
    final firstDay = DateTime(_visibleMonth.year, _visibleMonth.month);
    final leadingDays = firstDay.weekday - DateTime.monday;
    final daysInMonth = DateUtils.getDaysInMonth(
      _visibleMonth.year,
      _visibleMonth.month,
    );
    final cellCount = ((leadingDays + daysInMonth + 6) ~/ 7) * 7;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cellCount,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 5,
        crossAxisSpacing: 5,
        childAspectRatio: 0.82,
      ),
      itemBuilder: (context, index) {
        final day = index - leadingDays + 1;
        if (day < 1 || day > daysInMonth) return const SizedBox.shrink();
        final date = DateTime(_visibleMonth.year, _visibleMonth.month, day);
        final today = _today;
        final outsideRange =
            date.isBefore(today) ||
            date.isAfter(studioAddCivilDays(today, 730));
        final availability = _availabilityFor(date);
        final value = availability.availableCount(widget.total);
        return _BacklineAvailabilityDayCell(
          date: date,
          value: value,
          maximum: widget.total,
          selected: DateUtils.isSameDay(date, _selectedDate),
          rangeStart: DateUtils.isSameDay(date, _rangeStart),
          rangeEnd: DateUtils.isSameDay(date, _rangeEnd),
          inRange: _rangeEnd != null && _isInSelectedRange(date),
          maintenanceCount: availability.maintenanceCount,
          disabled: outsideRange,
          onTap: outsideRange || _isLoading || _rangeDialogOpen
              ? null
              : () => _handleDateTap(date),
        );
      },
    );
  }

  Widget _buildSelectedDaySummary() {
    final availability = _availabilityFor(_selectedDate);
    final value = availability.availableCount(widget.total);
    final color = _availabilityColor(
      value,
      widget.total,
      maintenanceCount: availability.maintenanceCount,
    );
    final label = _availabilityLabel(
      value,
      widget.total,
      maintenanceCount: availability.maintenanceCount,
      busyCount: availability.busyCount,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0A101A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF263244)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _fullDateLabel(_selectedDate),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$value/${widget.total}',
            style: const TextStyle(
              color: Color(0xFFDCE1E9),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  _BacklineDayAvailability _availabilityFor(DateTime date) {
    final normalized = _dateOnly(date);
    final stored = _values[normalized];
    if (stored != null) return stored;
    final initial = widget.initiallyAvailable.clamp(0, widget.total).toInt();
    if (widget.editable) return const _BacklineDayAvailability();
    final initialMaintenance = widget.initiallyMaintenance
        .clamp(0, widget.total - initial)
        .toInt();
    return _BacklineDayAvailability(
      busyCount: widget.total - initial - initialMaintenance,
      maintenanceCount: initialMaintenance,
    );
  }

  bool _isInSelectedRange(DateTime date) {
    if (_rangeStart == null) return false;
    final end = _rangeEnd ?? _rangeStart!;
    return !date.isBefore(_rangeStart!) && !date.isAfter(end);
  }

  Future<void> _handleDateTap(DateTime date) async {
    if (_configurationError != null || _isLoading || _rangeDialogOpen) return;
    if (!widget.editable) {
      setState(() => _selectedDate = date);
      return;
    }
    if (_rangeStart == null || _rangeEnd != null) {
      setState(() {
        _rangeStart = date;
        _rangeEnd = null;
        _selectedDate = date;
      });
      return;
    }
    setState(() {
      if (date.isBefore(_rangeStart!)) {
        _rangeEnd = _rangeStart;
        _rangeStart = date;
      } else {
        _rangeEnd = date;
      }
      _selectedDate = date;
      _rangeDialogOpen = true;
    });
    try {
      await Future<void>.delayed(const Duration(milliseconds: 180));
      if (!mounted) return;
      await _editDateRange(_rangeStart!, _rangeEnd!);
    } finally {
      if (mounted) setState(() => _rangeDialogOpen = false);
    }
  }

  Future<void> _editDateRange(DateTime startDate, DateTime endDate) async {
    final rangeStats = _rangeStats(startDate, endDate);
    final result = await showModalBottomSheet<_BacklineAvailabilityRangeUpdate>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BacklineAvailabilityRangeSheet(
        equipmentName: widget.equipmentName,
        total: widget.total,
        startDate: startDate,
        endDate: endDate,
        stats: rangeStats,
      ),
    );
    if (!mounted) return;
    if (result == null) {
      setState(() {
        _rangeStart = null;
        _rangeEnd = null;
      });
      return;
    }
    final dayCount = studioCivilRangeLength(startDate, endDate);
    if (dayCount >= 30) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Uzun tarih aralığı'),
          content: Text(
            '$dayCount günlük bir aralığı güncellemek üzeresiniz. Devam etmek istiyor musunuz?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Vazgeç'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Güncelle'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) {
        if (mounted) {
          setState(() {
            _rangeStart = null;
            _rangeEnd = null;
          });
        }
        return;
      }
    }
    if (!_hasRemoteSource) return;
    await _applyAvailabilityUpdate(startDate, endDate, result);
  }

  Future<void> _applyAvailabilityUpdate(
    DateTime startDate,
    DateTime endDate,
    _BacklineAvailabilityRangeUpdate update,
  ) async {
    if (_configurationError != null || !_hasRemoteSource) return;
    setState(() => _isLoading = true);
    final result = await widget.repository!.moveAvailability(
      equipmentId: widget.equipmentId!,
      command: MoveStudioEquipmentAvailabilityCommand(
        clientRequestId: update.clientRequestId,
        startDate: startDate,
        endDate: endDate,
        sourceBucket: _domainBucket(update.source),
        targetBucket: _domainBucket(update.target),
        quantity: update.quantity,
      ),
    );
    if (!mounted) return;
    if (!result.isSuccess) {
      setState(() => _isLoading = false);
      if (result.error?.code == '9821' || result.error?.code == '9804') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.error?.message ??
                  'Takvim başka bir işlemde değişti. Güncel veriler yüklendi.',
            ),
          ),
        );
        await _loadVisibleMonth();
        return;
      }
      final retry = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Takvim güncellenemedi'),
          content: Text(
            result.error?.message ?? 'Bağlantıyı kontrol edip tekrar deneyin.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      );
      if (mounted && retry == true) {
        await _applyAvailabilityUpdate(startDate, endDate, update);
      }
      return;
    }
    setState(() {
      _selectedDate = _dateOnly(startDate);
      _rangeStart = null;
      _rangeEnd = null;
    });
    await _loadVisibleMonth();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Müsaitlik takvimi güncellendi.')),
    );
  }

  StudioEquipmentAvailabilityBucket _domainBucket(
    _BacklineAvailabilityBucket bucket,
  ) => switch (bucket) {
    _BacklineAvailabilityBucket.available =>
      StudioEquipmentAvailabilityBucket.available,
    _BacklineAvailabilityBucket.busy => StudioEquipmentAvailabilityBucket.busy,
    _BacklineAvailabilityBucket.maintenance =>
      StudioEquipmentAvailabilityBucket.maintenance,
  };

  _BacklineAvailabilityRangeStats _rangeStats(
    DateTime startDate,
    DateTime endDate,
  ) {
    var minimumAvailable = widget.total;
    var maximumAvailable = 0;
    var minimumBusy = widget.total;
    var maximumBusy = 0;
    var minimumMaintenance = widget.total;
    var maximumMaintenance = 0;
    var date = _dateOnly(startDate);
    final normalizedEnd = _dateOnly(endDate);
    while (!date.isAfter(normalizedEnd)) {
      final current = _availabilityFor(date);
      final available = current.availableCount(widget.total);
      if (available < minimumAvailable) minimumAvailable = available;
      if (available > maximumAvailable) maximumAvailable = available;
      if (current.busyCount < minimumBusy) minimumBusy = current.busyCount;
      if (current.busyCount > maximumBusy) maximumBusy = current.busyCount;
      if (current.maintenanceCount < minimumMaintenance) {
        minimumMaintenance = current.maintenanceCount;
      }
      if (current.maintenanceCount > maximumMaintenance) {
        maximumMaintenance = current.maintenanceCount;
      }
      date = studioAddCivilDays(date, 1);
    }
    return _BacklineAvailabilityRangeStats(
      minimumAvailable: minimumAvailable,
      maximumAvailable: maximumAvailable,
      minimumBusy: minimumBusy,
      maximumBusy: maximumBusy,
      minimumMaintenance: minimumMaintenance,
      maximumMaintenance: maximumMaintenance,
    );
  }

  Future<void> _loadVisibleMonth() async {
    final configurationError = _configurationError;
    if (configurationError != null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = configurationError;
        });
      }
      return;
    }
    if (!_hasRemoteSource) return;
    final generation = ++_loadGeneration;
    final today = _today;
    final monthStart = DateTime(_visibleMonth.year, _visibleMonth.month);
    final monthEnd = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0);
    final allowedEnd = studioAddCivilDays(today, 730);
    final startDate = monthStart.isBefore(today) ? today : monthStart;
    final endDate = monthEnd.isAfter(allowedEnd) ? allowedEnd : monthEnd;
    if (endDate.isBefore(startDate)) return;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    final repository = widget.repository!;
    final result = widget.editable
        ? await repository.getOwnerAvailability(
            equipmentId: widget.equipmentId!,
            startDate: startDate,
            endDate: endDate,
          )
        : await repository.getPublicAvailability(
            studioProfileId: widget.studioProfileId!,
            equipmentId: widget.equipmentId!,
            startDate: startDate,
            endDate: endDate,
          );
    if (!mounted || generation != _loadGeneration) return;
    if (!result.isSuccess || result.data == null) {
      setState(() {
        _isLoading = false;
        _loadError = result.error?.message ?? 'Uygunluk takvimi yüklenemedi.';
      });
      return;
    }
    setState(() {
      var date = startDate;
      while (!date.isAfter(endDate)) {
        _values.remove(_dateOnly(date));
        date = studioAddCivilDays(date, 1);
      }
      for (final day in result.data!.days) {
        final availability = _BacklineDayAvailability.fromDomain(day);
        if (availability.busyCount > 0 || availability.maintenanceCount > 0) {
          _values[_dateOnly(day.date)] = availability;
        }
      }
      _isLoading = false;
      _loadError = null;
    });
  }

  Future<void> _openCalendarPicker() async {
    if (_configurationError != null) return;
    final today = _today;
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(today) ? today : _selectedDate,
      firstDate: today,
      lastDate: studioAddCivilDays(today, 730),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.dark(
            primary: AppColors.socialPink,
            onPrimary: Colors.white,
            surface: const Color(0xFF101722),
            onSurface: Colors.white,
          ),
          dialogTheme: const DialogThemeData(
            backgroundColor: Color(0xFF101722),
          ),
        ),
        child: child!,
      ),
    );
    if (!mounted || picked == null) return;
    setState(() {
      _selectedDate = _dateOnly(picked);
      _visibleMonth = DateTime(picked.year, picked.month);
    });
    await _loadVisibleMonth();
  }

  void _moveMonth(int offset) {
    final month = DateTime(_visibleMonth.year, _visibleMonth.month + offset);
    setState(() {
      _visibleMonth = month;
      _selectedDate = DateTime(month.year, month.month, 1);
      if (_selectedDate.isBefore(_today)) {
        _selectedDate = _today;
      }
    });
    _loadVisibleMonth();
  }

  bool get _canMoveBackward {
    final today = DateTime(_today.year, _today.month);
    return _visibleMonth.isAfter(today);
  }

  bool get _canMoveForward {
    final lastDate = studioAddCivilDays(_today, 730);
    final lastMonth = DateTime(lastDate.year, lastDate.month);
    return _visibleMonth.isBefore(lastMonth);
  }
}
