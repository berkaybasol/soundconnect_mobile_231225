part of 'studio_profile_screen.dart';

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
