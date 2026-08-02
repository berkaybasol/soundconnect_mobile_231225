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
  String? _loadError;
  int _loadGeneration = 0;

  DateTime get _today => _dateOnly(widget.referenceDate ?? DateTime.now());

  @override
  void initState() {
    super.initState();
    final today = _today;
    _selectedDate = today;
    _visibleMonth = DateTime(today.year, today.month);
    _values = <DateTime, _BacklineDayAvailability>{};
    if (_hasRemoteSource) _loadVisibleMonth();
  }

  @override
  void didUpdateWidget(covariant _BacklineDateAvailabilityCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.equipmentId != oldWidget.equipmentId && _hasRemoteSource) {
      _values = <DateTime, _BacklineDayAvailability>{};
      _loadVisibleMonth();
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
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Row(
      children: [
        _CalendarArrowButton(
          icon: Icons.arrow_back,
          onTap: _canMoveBackward ? () => _moveMonth(-1) : null,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _openCalendarPicker,
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
          onTap: _canMoveForward ? () => _moveMonth(1) : null,
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
            date.isAfter(today.add(const Duration(days: 730)));
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
          onTap: outsideRange ? null : () => _handleDateTap(date),
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
    });
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;
    await _editDateRange(_rangeStart!, _rangeEnd!);
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
    final dayCount =
        _dateOnly(endDate).difference(_dateOnly(startDate)).inDays + 1;
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
      date = date.add(const Duration(days: 1));
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
    if (!_hasRemoteSource) return;
    final generation = ++_loadGeneration;
    final today = _today;
    final monthStart = DateTime(_visibleMonth.year, _visibleMonth.month);
    final monthEnd = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0);
    final allowedEnd = today.add(const Duration(days: 730));
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
        date = date.add(const Duration(days: 1));
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
    final today = _today;
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(today) ? today : _selectedDate,
      firstDate: today,
      lastDate: today.add(const Duration(days: 730)),
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
    final lastDate = _today.add(const Duration(days: 730));
    final lastMonth = DateTime(lastDate.year, lastDate.month);
    return _visibleMonth.isBefore(lastMonth);
  }
}

class _BacklineAvailabilityDayCell extends StatelessWidget {
  final DateTime date;
  final int value;
  final int maximum;
  final bool selected;
  final bool rangeStart;
  final bool rangeEnd;
  final bool inRange;
  final int maintenanceCount;
  final bool disabled;
  final VoidCallback? onTap;

  const _BacklineAvailabilityDayCell({
    required this.date,
    required this.value,
    required this.maximum,
    required this.selected,
    required this.rangeStart,
    required this.rangeEnd,
    required this.inRange,
    required this.maintenanceCount,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = disabled
        ? const Color(0xFF596272)
        : _availabilityColor(
            value,
            maximum,
            maintenanceCount: maintenanceCount,
          );
    final radius = BorderRadius.circular(7);
    final endpoint = rangeStart || rangeEnd;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(0.8),
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: selected && !endpoint && !inRange && !disabled
                  ? LinearGradient(colors: AppColors.brandGradient)
                  : null,
              border: Border.all(
                color: endpoint && !disabled
                    ? const Color(0xFF7D8A9D)
                    : const Color(0xFF263244),
                width: endpoint ? 1.1 : 1,
              ),
            ),
            child: Material(
              color: disabled
                  ? const Color(0xFF090D14)
                  : const Color(0xFF0A101A),
              borderRadius: BorderRadius.circular(6.2),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(6.2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${date.day}',
                      style: TextStyle(
                        color: disabled
                            ? const Color(0xFF66707E)
                            : Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '$value',
                        style: TextStyle(
                          color: color,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (inRange && !(rangeStart && rangeEnd) && !disabled)
          Positioned(
            left: rangeStart ? 20 : -3,
            right: rangeEnd ? 20 : -3,
            top: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Center(
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(color: const Color(0xFF7D8A9D)),
                ),
              ),
            ),
          ),
        if (endpoint && !disabled)
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF9AA6B7),
                    border: Border.all(
                      color: const Color(0xFF101722),
                      width: 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _BacklineAvailabilityRangeUpdate {
  final String clientRequestId;
  final _BacklineAvailabilityBucket source;
  final _BacklineAvailabilityBucket target;
  final int quantity;

  const _BacklineAvailabilityRangeUpdate({
    required this.clientRequestId,
    required this.source,
    required this.target,
    required this.quantity,
  });
}

enum _BacklineAvailabilityBucket { available, busy, maintenance }

class _BacklineAvailabilityRangeStats {
  final int minimumAvailable;
  final int maximumAvailable;
  final int minimumBusy;
  final int maximumBusy;
  final int minimumMaintenance;
  final int maximumMaintenance;

  const _BacklineAvailabilityRangeStats({
    required this.minimumAvailable,
    required this.maximumAvailable,
    required this.minimumBusy,
    required this.maximumBusy,
    required this.minimumMaintenance,
    required this.maximumMaintenance,
  });

  int minimumFor(_BacklineAvailabilityBucket bucket) => switch (bucket) {
    _BacklineAvailabilityBucket.available => minimumAvailable,
    _BacklineAvailabilityBucket.busy => minimumBusy,
    _BacklineAvailabilityBucket.maintenance => minimumMaintenance,
  };

  int maximumFor(_BacklineAvailabilityBucket bucket) => switch (bucket) {
    _BacklineAvailabilityBucket.available => maximumAvailable,
    _BacklineAvailabilityBucket.busy => maximumBusy,
    _BacklineAvailabilityBucket.maintenance => maximumMaintenance,
  };
}

class _BacklineAvailabilityRangeSheet extends StatefulWidget {
  final String equipmentName;
  final int total;
  final DateTime startDate;
  final DateTime endDate;
  final _BacklineAvailabilityRangeStats stats;

  const _BacklineAvailabilityRangeSheet({
    required this.equipmentName,
    required this.total,
    required this.startDate,
    required this.endDate,
    required this.stats,
  });

  @override
  State<_BacklineAvailabilityRangeSheet> createState() =>
      _BacklineAvailabilityRangeSheetState();
}

class _BacklineAvailabilityRangeSheetState
    extends State<_BacklineAvailabilityRangeSheet> {
  final String _clientRequestId = const Uuid().v4();
  late _BacklineAvailabilityBucket _source;
  late _BacklineAvailabilityBucket _target;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    _source = _firstAvailableSource();
    _target = _targetsFor(_source).first;
    if (_maximumQuantity == 0) _quantity = 0;
  }

  int get _maximumQuantity => widget.stats.minimumFor(_source);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0B1321),
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF465165),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              const Text(
                'Seçili Aralığı İşaretle',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${_shortDateLabel(widget.startDate)} – ${_shortDateLabel(widget.endDate)} • ${widget.equipmentName}',
                style: const TextStyle(color: Color(0xFF919BA9), fontSize: 11),
              ),
              const SizedBox(height: 16),
              const _BacklineAvailabilityFormLabel('İşlem yapılacak grup'),
              const SizedBox(height: 8),
              for (final bucket in _BacklineAvailabilityBucket.values) ...[
                _BacklineOutlineChoice(
                  icon: _bucketIcon(bucket),
                  label: _bucketRangeLabel(bucket),
                  subtitle: _bucketSubtitle(bucket),
                  selected: _source == bucket,
                  onTap: () => _selectSource(bucket),
                ),
                if (bucket != _BacklineAvailabilityBucket.maintenance)
                  const SizedBox(height: 8),
              ],
              const SizedBox(height: 15),
              const _BacklineAvailabilityFormLabel('Yeni durum'),
              const SizedBox(height: 8),
              for (final target in _targetsFor(_source)) ...[
                _BacklineOutlineChoice(
                  icon: _bucketIcon(target),
                  label: _bucketLabel(target),
                  selected: _target == target,
                  onTap: () => setState(() => _target = target),
                ),
                if (target != _targetsFor(_source).last)
                  const SizedBox(height: 8),
              ],
              const SizedBox(height: 15),
              const _BacklineAvailabilityFormLabel('Etkilenen adet'),
              const SizedBox(height: 8),
              _BacklineAvailabilityQuantitySelector(
                value: _quantity,
                maximum: _maximumQuantity,
                onChanged: (value) => setState(() => _quantity = value),
              ),
              const SizedBox(height: 16),
              _StudioActionButton(
                icon: Icons.check_rounded,
                label: 'Takvimi Güncelle',
                outlined: true,
                onTap: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (_maximumQuantity == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Bu grup seçili aralığın her gününde bulunmuyor. Daha kısa bir aralık seçin.',
          ),
        ),
      );
      return;
    }
    Navigator.of(context).pop(
      _BacklineAvailabilityRangeUpdate(
        clientRequestId: _clientRequestId,
        source: _source,
        target: _target,
        quantity: _quantity,
      ),
    );
  }

  _BacklineAvailabilityBucket _firstAvailableSource() {
    for (final bucket in _BacklineAvailabilityBucket.values) {
      if (widget.stats.minimumFor(bucket) > 0) return bucket;
    }
    return _BacklineAvailabilityBucket.available;
  }

  List<_BacklineAvailabilityBucket> _targetsFor(
    _BacklineAvailabilityBucket source,
  ) => _BacklineAvailabilityBucket.values
      .where((bucket) => bucket != source)
      .toList(growable: false);

  void _selectSource(_BacklineAvailabilityBucket source) {
    final minimum = widget.stats.minimumFor(source);
    if (minimum == 0) {
      final existsOnSomeDays = widget.stats.maximumFor(source) > 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existsOnSomeDays
                ? 'Bu grup bazı günlerde bulunmuyor. Daha kısa bir tarih aralığı seçin.'
                : 'Seçili aralıkta bu durumda ekipman bulunmuyor.',
          ),
        ),
      );
      return;
    }
    setState(() {
      _source = source;
      _target = _targetsFor(source).first;
      if (_quantity > minimum) _quantity = minimum;
      if (_quantity < 1) _quantity = 1;
    });
  }

  String _bucketRangeLabel(_BacklineAvailabilityBucket bucket) {
    final minimum = widget.stats.minimumFor(bucket);
    final maximum = widget.stats.maximumFor(bucket);
    final count = minimum == maximum
        ? '$minimum adet'
        : '$minimum–$maximum adet/gün';
    return '${_bucketLabel(bucket)} • $count';
  }

  String _bucketSubtitle(_BacklineAvailabilityBucket bucket) {
    final minimum = widget.stats.minimumFor(bucket);
    final maximum = widget.stats.maximumFor(bucket);
    if (maximum == 0) return 'Seçili aralıkta bu gruptan yok';
    if (minimum == 0) return 'Bazı günlerde yok; daha kısa aralık seçin';
    if (minimum != maximum) {
      return 'Günlere göre değişiyor; ortak $minimum adet düzenlenebilir';
    }
    return 'Bu gruptaki ekipmanları başka duruma taşı';
  }

  static String _bucketLabel(_BacklineAvailabilityBucket bucket) =>
      switch (bucket) {
        _BacklineAvailabilityBucket.available => 'Müsait',
        _BacklineAvailabilityBucket.busy => 'Dolu',
        _BacklineAvailabilityBucket.maintenance => 'Bakımda',
      };

  static IconData _bucketIcon(_BacklineAvailabilityBucket bucket) =>
      switch (bucket) {
        _BacklineAvailabilityBucket.available => Icons.event_available_outlined,
        _BacklineAvailabilityBucket.busy => Icons.event_busy_outlined,
        _BacklineAvailabilityBucket.maintenance => Icons.build_outlined,
      };
}

class _BacklineAvailabilityQuantitySelector extends StatelessWidget {
  final int value;
  final int maximum;
  final ValueChanged<int> onChanged;

  const _BacklineAvailabilityQuantitySelector({
    required this.value,
    required this.maximum,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _ownerManagementCardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _ownerManagementInsetBorderColor),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: value > 1 ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_rounded),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  '$value adet',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'Toplam $maximum ekipmandan',
                  style: const TextStyle(color: Color(0xFF8F9AAA), fontSize: 9),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: value < maximum ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

class _BacklineAvailabilityFormLabel extends StatelessWidget {
  final String label;

  const _BacklineAvailabilityFormLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFFD4D9E2),
        fontSize: 12,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _BacklineAvailabilityEquipmentPicker extends StatefulWidget {
  final StudioEquipmentRepository repository;
  final _StudioBacklineInventoryItem? selected;

  const _BacklineAvailabilityEquipmentPicker({
    required this.repository,
    required this.selected,
  });

  @override
  State<_BacklineAvailabilityEquipmentPicker> createState() =>
      _BacklineAvailabilityEquipmentPickerState();
}

class _BacklineAvailabilityEquipmentPickerState
    extends State<_BacklineAvailabilityEquipmentPicker> {
  static const _pageSize = 10;
  List<_StudioBacklineInventoryItem> _items = const [];
  String _query = '';
  int _pageIndex = 0;
  int _totalPages = 0;
  int _totalItems = 0;
  int _searchGeneration = 0;
  int _loadGeneration = 0;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(0);
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.76,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF465165),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Ekipman Seç',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(
                hintText: 'Ekipman, marka veya kategori ara...',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _isLoading && _items.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null && _items.isEmpty
                  ? _StudioOwnerBacklineErrorState(
                      message: _error!,
                      onRetry: () => _load(_pageIndex),
                    )
                  : _items.isEmpty
                  ? const Center(
                      child: Text(
                        'Aramanızla eşleşen ekipman bulunamadı.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF929CAA),
                          fontSize: 12,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 7),
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        final selected = item.id == widget.selected?.id;
                        return ListTile(
                          onTap: () => Navigator.of(context).pop(item),
                          tileColor: _ownerManagementCardColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: selected
                                  ? const Color(0xFF767E8C)
                                  : _ownerManagementCardBorderColor,
                            ),
                          ),
                          leading: Icon(
                            item.icon,
                            color: const Color(0xFFD6DCE6),
                          ),
                          title: Text(
                            item.name,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            '${item.category} • ${item.total} adet',
                          ),
                          trailing: Icon(
                            selected
                                ? Icons.check_circle_outline_rounded
                                : Icons.chevron_right_rounded,
                            color: selected
                                ? Colors.white
                                : const Color(0xFF7F8998),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 44,
              decoration: BoxDecoration(
                color: _ownerManagementCardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _ownerManagementCardBorderColor),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Önceki sayfa',
                    onPressed: !_isLoading && _pageIndex > 0
                        ? () => _load(_pageIndex - 1)
                        : null,
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: Text(
                      '${_totalPages == 0 ? 0 : _pageIndex + 1} / '
                      '${_totalPages == 0 ? 1 : _totalPages} • '
                      '$_totalItems ekipman',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFB8C0CC),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Sonraki sayfa',
                    onPressed: !_isLoading && _pageIndex + 1 < _totalPages
                        ? () => _load(_pageIndex + 1)
                        : null,
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onSearchChanged(String value) {
    _query = value;
    final generation = ++_searchGeneration;
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      if (!mounted || generation != _searchGeneration) return;
      _load(0);
    });
  }

  Future<void> _load(int page) async {
    final generation = ++_loadGeneration;
    setState(() {
      _isLoading = true;
      _error = null;
      _items = const [];
    });
    final result = await widget.repository.listOwnerEquipment(
      query: _query,
      page: page,
      size: _pageSize,
    );
    if (!mounted || generation != _loadGeneration) return;
    if (!result.isSuccess || result.data == null) {
      setState(() {
        _isLoading = false;
        _error = result.error?.message ?? 'Ekipmanlar yüklenemedi.';
      });
      return;
    }
    setState(() {
      _items = result.data!.items
          .map(_StudioBacklineInventoryItem.fromDomain)
          .toList(growable: false);
      _pageIndex = result.data!.pageIndex;
      _totalPages = result.data!.totalPages;
      _totalItems = result.data!.totalItems;
      _isLoading = false;
      _error = null;
    });
  }
}

Color _availabilityColor(int value, int maximum, {int maintenanceCount = 0}) {
  if (value == 0 && maintenanceCount >= maximum) {
    return const Color(0xFF6B7280);
  }
  if (value == 0) return const Color(0xFFB8323B);
  if (value >= maximum) return const Color(0xFF1EAF4D);
  if (maximum <= 0) return const Color(0xFFB8323B);

  final ratio = (value / maximum).clamp(0.0, 1.0).toDouble();
  if (ratio >= 0.5) {
    return Color.lerp(
      AppColors.socialOrange,
      const Color(0xFF1EAF4D),
      (ratio - 0.5) / 0.5,
    )!;
  }
  return Color.lerp(
    const Color(0xFFD85B47),
    AppColors.socialOrange,
    ratio / 0.5,
  )!;
}

String _availabilityLabel(
  int value,
  int maximum, {
  int maintenanceCount = 0,
  int busyCount = 0,
}) {
  if (value == 0 && maintenanceCount >= maximum) return 'Bakımda';
  if (value == 0 && busyCount >= maximum) return 'Dolu';
  if (value == 0) {
    return 'Müsait Değil • $busyCount dolu • $maintenanceCount bakımda';
  }
  if (value >= maximum) return 'Müsait';
  final details = <String>['$value müsait'];
  if (busyCount > 0) details.add('$busyCount dolu');
  if (maintenanceCount > 0) details.add('$maintenanceCount bakımda');
  return 'Kısmen Müsait • ${details.join(' • ')}';
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

String _monthYearLabel(DateTime date) {
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
  return '${months[date.month - 1]} ${date.year}';
}

String _fullDateLabel(DateTime date) {
  const weekdays = [
    'Pazartesi',
    'Salı',
    'Çarşamba',
    'Perşembe',
    'Cuma',
    'Cumartesi',
    'Pazar',
  ];
  return '${date.day} ${_monthYearLabel(date)}, ${weekdays[date.weekday - 1]}';
}

String _shortDateLabel(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
