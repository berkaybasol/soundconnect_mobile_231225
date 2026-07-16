part of 'studio_profile_screen.dart';

class _StudioRoomDetailScreen extends StatefulWidget {
  final _StudioRoomItem room;
  final bool canReserve;

  const _StudioRoomDetailScreen({required this.room, required this.canReserve});

  @override
  State<_StudioRoomDetailScreen> createState() =>
      _StudioRoomDetailScreenState();
}

class _StudioRoomDetailScreenState extends State<_StudioRoomDetailScreen> {
  final PageController _pageController = PageController();
  DateTime _selectedDate = _dateOnly(DateTime.now());
  int _activePhoto = 0;
  String? _selectedTime;
  int _durationHours = 1;

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

  List<String> get _photos => widget.room.photoUrls.take(5).toList();

  @override
  void dispose() {
    _pageController.dispose();
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
              title: widget.room.name,
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildGallery(),
                    const SizedBox(height: 18),
                    _buildIdentity(),
                    const SizedBox(height: 14),
                    _buildFeatures(),
                    const SizedBox(height: 16),
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
                  return _StudioRoomPhotoPlaceholder(room: widget.room);
                }
                return Image.network(
                  _photos[index],
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      _StudioRoomPhotoPlaceholder(room: widget.room),
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
                widget.room.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                widget.room.type,
                style: const TextStyle(
                  color: Color(0xFFB5BDCA),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StudioRoomDetailMeta(
                    icon: Icons.people_outline,
                    label: widget.room.capacity,
                  ),
                  _StudioRoomDetailMeta(
                    icon: Icons.payments_outlined,
                    label: widget.room.price,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _StudioRoomStatusPill(room: widget.room),
      ],
    );
  }

  Widget _buildFeatures() {
    return _StudioRoomDetailCard(
      title: 'Oda Özellikleri',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: widget.room.features
            .map((feature) => _StudioRoomFeatureChip(label: feature))
            .toList(growable: false),
      ),
    );
  }

  Widget _buildAvailability() {
    return _StudioRoomDetailCard(
      title: 'Müsaitlik ve Rezervasyon',
      subtitle: 'Tarih ve başlangıç saati seç',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StudioRoomDateSelector(
            date: _selectedDate,
            canGoBack: _selectedDate.isAfter(_dateOnly(DateTime.now())),
            onPrevious: () => _changeDate(-1),
            onNext: () => _changeDate(1),
            onPick: _pickDate,
          ),
          const SizedBox(height: 16),
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
          ),
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
    return (_selectedDate.day + hour + widget.room.name.length) % 5 != 0;
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
          '${widget.room.name}\n${_formatDate(_selectedDate)} • $time\n$_durationHours saat',
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

class _StudioRoomTimeChip extends StatelessWidget {
  final String time;
  final bool available;
  final bool selected;
  final VoidCallback? onTap;

  const _StudioRoomTimeChip({
    required this.time,
    required this.available,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 72,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF2A172A)
              : available
              ? const Color(0xFF0A101A)
              : const Color(0xFF090D14),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? AppColors.socialPink
                : available
                ? const Color(0xFF263244)
                : const Color(0xFF1A2230),
          ),
        ),
        child: Column(
          children: [
            Text(
              time,
              style: TextStyle(
                color: available ? Colors.white : const Color(0xFF596271),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              available ? 'Müsait' : 'Dolu',
              style: TextStyle(
                color: available
                    ? const Color(0xFF1EAF4D)
                    : const Color(0xFF7D4248),
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
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
