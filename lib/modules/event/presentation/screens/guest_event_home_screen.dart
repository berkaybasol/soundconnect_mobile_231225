import 'package:flutter/material.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../shared/theme/app_colors.dart';

class GuestEventHomeScreen extends StatefulWidget {
  const GuestEventHomeScreen({super.key});

  @override
  State<GuestEventHomeScreen> createState() => _GuestEventHomeScreenState();
}

class _GuestEventHomeScreenState extends State<GuestEventHomeScreen> {
  static final DateTime _today = DateTime.now();

  final List<_GuestEventItem> _events = [
    _GuestEventItem(
      id: '1',
      performerName: 'Luna Echo',
      performerType: 'MUSICIAN',
      bandMembers: const [],
      venueName: 'Sahil Sahne',
      venueCity: 'Istanbul',
      venueDistrict: 'Besiktas',
      venueNeighborhood: 'Sinanpasa',
      eventDate: DateTime(_today.year, _today.month, _today.day),
      startTime: const TimeOfDay(hour: 20, minute: 30),
      endTime: const TimeOfDay(hour: 22, minute: 0),
      description: 'Akustik pop ve indie seckiler.',
    ),
    _GuestEventItem(
      id: '2',
      performerName: 'Neon Tide',
      performerType: 'BAND',
      bandMembers: const ['Mert', 'Ece', 'Can'],
      venueName: 'Ritim Klub',
      venueCity: 'Istanbul',
      venueDistrict: 'Kadikoy',
      venueNeighborhood: 'Moda',
      eventDate: DateTime(_today.year, _today.month, _today.day),
      startTime: const TimeOfDay(hour: 21, minute: 0),
      endTime: const TimeOfDay(hour: 23, minute: 15),
      description: 'Alternatif rock gecesi.',
    ),
    _GuestEventItem(
      id: '3',
      performerName: 'Aegean Jazz Trio',
      performerType: 'BAND',
      bandMembers: const ['Baris', 'Deniz', 'Selin'],
      venueName: 'Blue Note Izmir',
      venueCity: 'Izmir',
      venueDistrict: 'Konak',
      venueNeighborhood: 'Alsancak',
      eventDate: DateTime(_today.year, _today.month, _today.day),
      startTime: const TimeOfDay(hour: 19, minute: 45),
      endTime: const TimeOfDay(hour: 21, minute: 30),
      description: 'Canlı jazz standartları.',
    ),
    _GuestEventItem(
      id: '4',
      performerName: 'Sokak Ritim',
      performerType: 'MUSICIAN',
      bandMembers: const [],
      venueName: 'Kiyi Sahne',
      venueCity: 'Istanbul',
      venueDistrict: 'Besiktas',
      venueNeighborhood: 'Levent',
      eventDate: DateTime(_today.year, _today.month, _today.day),
      startTime: const TimeOfDay(hour: 18, minute: 30),
      endTime: const TimeOfDay(hour: 20, minute: 0),
      description: 'Perkusion ve dunya muzikleri.',
    ),
  ];

  String? _selectedCity;
  String? _selectedDistrict;
  String? _selectedNeighborhood;
  String? _selectedVenueKey;
  bool _showVenueOptions = false;

  @override
  Widget build(BuildContext context) {
    final venues =
        _events
            .map(
              (e) => _VenueFilterOption(
                venueKey: e.venueKey,
                venueName: e.venueName,
                city: e.venueCity,
                district: e.venueDistrict,
                neighborhood: e.venueNeighborhood,
              ),
            )
            .toSet()
            .toList()
          ..sort((a, b) => a.venueName.compareTo(b.venueName));

    final cityOptions = venues.map((e) => e.city).toSet().toList()..sort();
    final districtOptions =
        venues
            .where((e) => _selectedCity == null || e.city == _selectedCity)
            .map((e) => e.district)
            .toSet()
            .toList()
          ..sort();
    final neighborhoodOptions =
        venues
            .where(
              (e) =>
                  (_selectedCity == null || e.city == _selectedCity) &&
                  (_selectedDistrict == null ||
                      e.district == _selectedDistrict),
            )
            .map((e) => e.neighborhood)
            .toSet()
            .toList()
          ..sort();
    final venueOptions = venues.where((e) {
      final cityOk = _selectedCity == null || e.city == _selectedCity;
      final districtOk =
          _selectedDistrict == null || e.district == _selectedDistrict;
      final neighborhoodOk =
          _selectedNeighborhood == null ||
          e.neighborhood == _selectedNeighborhood;
      return cityOk && districtOk && neighborhoodOk;
    }).toList();

    final filteredEvents = _events.where((event) {
      final sameDay =
          event.eventDate.year == _today.year &&
          event.eventDate.month == _today.month &&
          event.eventDate.day == _today.day;
      final sameCity =
          _selectedCity == null || event.venueCity == _selectedCity;
      final sameDistrict =
          _selectedDistrict == null || event.venueDistrict == _selectedDistrict;
      final sameNeighborhood =
          _selectedNeighborhood == null ||
          event.venueNeighborhood == _selectedNeighborhood;
      final sameVenue =
          _selectedVenueKey == null || event.venueKey == _selectedVenueKey;
      return sameDay &&
          sameCity &&
          sameDistrict &&
          sameNeighborhood &&
          sameVenue;
    }).toList();
    final visibleEvents = _showVenueOptions
        ? filteredEvents
        : const <_GuestEventItem>[];
    final selectedVenue = venues
        .where((v) => v.venueKey == _selectedVenueKey)
        .cast<_VenueFilterOption?>()
        .firstWhere((_) => true, orElse: () => null);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: _HeroPanel(count: visibleEvents.length),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                      child: _InlineFilterPanel(
                        selectedCity: _selectedCity,
                        selectedDistrict: _selectedDistrict,
                        selectedNeighborhood: _selectedNeighborhood,
                        selectedVenueName: selectedVenue?.venueName,
                        cityOptions: cityOptions,
                        districtOptions: districtOptions,
                        neighborhoodOptions: neighborhoodOptions,
                        onCityChanged: (value) {
                          setState(() {
                            _selectedCity = value;
                            _selectedDistrict = null;
                            _selectedNeighborhood = null;
                            _selectedVenueKey = null;
                            _showVenueOptions = false;
                          });
                        },
                        onDistrictChanged: (value) {
                          setState(() {
                            _selectedDistrict = value;
                            _selectedNeighborhood = null;
                            _selectedVenueKey = null;
                            _showVenueOptions = false;
                          });
                        },
                        onNeighborhoodChanged: (value) {
                          setState(() {
                            _selectedNeighborhood = value;
                            _selectedVenueKey = null;
                            _showVenueOptions = false;
                          });
                        },
                        onSearchTap: () async {
                          final selected = await Navigator.of(context)
                              .push<String?>(
                                MaterialPageRoute(
                                  builder: (_) => _VenueListScreen(
                                    venues: venueOptions,
                                    selectedVenueKey: _selectedVenueKey,
                                  ),
                                ),
                              );
                          if (!mounted) return;
                          if (selected == null) {
                            return;
                          }
                          setState(() {
                            _selectedVenueKey = selected == '__all__'
                                ? null
                                : selected;
                            _showVenueOptions = true;
                          });
                        },
                        onClearAll: () {
                          setState(() {
                            _selectedCity = null;
                            _selectedDistrict = null;
                            _selectedNeighborhood = null;
                            _selectedVenueKey = null;
                            _showVenueOptions = false;
                          });
                        },
                      ),
                    ),
                  ),
                  if (!_showVenueOptions)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _SearchFirstState(),
                    )
                  else if (visibleEvents.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _GuestEmptyState(),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _EventCard(item: visibleEvents[index]),
                          );
                        }, childCount: visibleEvents.length),
                      ),
                    ),
                ],
              ),
            ),
            const _GuestLockFooter(),
          ],
        ),
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  final int count;

  const _HeroPanel({required this.count});

  String _dateLabel() {
    final now = DateTime.now();
    final d = now.day.toString().padLeft(2, '0');
    final m = now.month.toString().padLeft(2, '0');
    return '$d.$m.${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A2740), Color(0xFF10243B), Color(0xFF1B1E37)],
        ),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: AppColors.brandGradient,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.brandGradient[2].withValues(alpha: 0.35),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.music_note,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Bugün Nerede Canlı Müzik Var?',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${_dateLabel()} tarihinde yakında $count etkinlik bulundu',
            style: const TextStyle(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _InlineFilterPanel extends StatelessWidget {
  final String? selectedCity;
  final String? selectedDistrict;
  final String? selectedNeighborhood;
  final String? selectedVenueName;
  final List<String> cityOptions;
  final List<String> districtOptions;
  final List<String> neighborhoodOptions;
  final ValueChanged<String?> onCityChanged;
  final ValueChanged<String?> onDistrictChanged;
  final ValueChanged<String?> onNeighborhoodChanged;
  final Future<void> Function() onSearchTap;
  final VoidCallback onClearAll;

  const _InlineFilterPanel({
    required this.selectedCity,
    required this.selectedDistrict,
    required this.selectedNeighborhood,
    required this.selectedVenueName,
    required this.cityOptions,
    required this.districtOptions,
    required this.neighborhoodOptions,
    required this.onCityChanged,
    required this.onDistrictChanged,
    required this.onNeighborhoodChanged,
    required this.onSearchTap,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.tune, color: AppColors.textMuted, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Lokasyona göre ara',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              TextButton(onPressed: onClearAll, child: const Text('Temizle')),
            ],
          ),
          _FilterDropdown(
            label: 'Şehir seç',
            value: selectedCity,
            items: cityOptions,
            allLabel: 'Şehir',
            onChanged: onCityChanged,
          ),
          const SizedBox(height: 8),
          _FilterDropdown(
            label: 'İlçe seç',
            value: selectedDistrict,
            items: districtOptions,
            allLabel: 'İlçe',
            onChanged: onDistrictChanged,
          ),
          const SizedBox(height: 8),
          _FilterDropdown(
            label: 'Mahalle seç',
            value: selectedNeighborhood,
            items: neighborhoodOptions,
            allLabel: 'Mahalle',
            onChanged: onNeighborhoodChanged,
          ),
          const SizedBox(height: 8),
          if (selectedVenueName != null && selectedVenueName!.trim().isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.navBlueSoft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                'Seçilen mekan: $selectedVenueName',
                style: const TextStyle(color: AppColors.textMuted),
              ),
            ),
          if (selectedVenueName != null && selectedVenueName!.trim().isNotEmpty)
            const SizedBox(height: 8),
          _GradientActionButton(
            label: 'Ara',
            icon: Icons.search,
            onPressed: () {
              onSearchTap();
            },
          ),
        ],
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final String allLabel;
  final ValueChanged<String?> onChanged;

  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.allLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _GradientDropdownField(
      hint: label,
      value: value,
      dropdownColor: AppColors.navBlueSoft,
      items: [
        DropdownMenuItem<String?>(value: null, child: Text(allLabel)),
        ...items.map(
          (item) => DropdownMenuItem<String?>(value: item, child: Text(item)),
        ),
      ],
      onChanged: onChanged,
    );
  }
}

class _GradientDropdownField extends StatefulWidget {
  final String hint;
  final String? value;
  final List<DropdownMenuItem<String?>> items;
  final ValueChanged<String?> onChanged;
  final Color dropdownColor;

  const _GradientDropdownField({
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.dropdownColor,
  });

  @override
  State<_GradientDropdownField> createState() => _GradientDropdownFieldState();
}

class _GradientDropdownFieldState extends State<_GradientDropdownField> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (!mounted) return;
    setState(() => _isFocused = _focusNode.hasFocus);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(12);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.all(1.2),
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: _isFocused
            ? const LinearGradient(colors: AppColors.brandGradient)
            : null,
        color: _isFocused ? null : AppColors.border,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.inputFill,
          borderRadius: BorderRadius.circular(10.8),
        ),
        child: DropdownButtonFormField<String?>(
          focusNode: _focusNode,
          value: widget.value,
          isExpanded: true,
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: const TextStyle(color: AppColors.textMuted),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.8),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.8),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.8),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: AppColors.inputFill,
          ),
          dropdownColor: widget.dropdownColor,
          items: widget.items,
          onChanged: widget.onChanged,
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final _GuestEventItem item;

  const _EventCard({required this.item});

  String _twoDigits(int value) => value.toString().padLeft(2, '0');

  String _formatTime(TimeOfDay time) =>
      '${_twoDigits(time.hour)}:${_twoDigits(time.minute)}';

  String _timeLabel() {
    final start = _formatTime(item.startTime);
    final end = item.endTime == null ? null : _formatTime(item.endTime!);
    if (end == null) return start;
    return '$start - $end';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(1.2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0x40F07A5E), Color(0x20E062A9), Color(0x409A58F4)],
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.inputFill,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: AppColors.navBlueSoft,
                    border: Border.all(color: AppColors.border),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    item.venueName.trim().isEmpty
                        ? '?'
                        : item.venueName.trim()[0].toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.venueName,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.venueDistrict} / ${item.venueNeighborhood}',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: const LinearGradient(
                      colors: AppColors.brandGradient,
                    ),
                  ),
                  child: Text(
                    _timeLabel(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.performerName,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: AppColors.navBlueSoft,
                  ),
                  child: Text(
                    item.performerType,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (item.description.trim().isNotEmpty) ...[
              const SizedBox(height: 7),
              Text(
                item.description,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  height: 1.35,
                ),
              ),
            ],
            if (item.bandMembers.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: item.bandMembers
                    .map(
                      (member) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.navBlueSoft,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          member,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GuestEmptyState extends StatelessWidget {
  const _GuestEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.inputFill,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.music_off, color: AppColors.textMuted, size: 32),
              SizedBox(height: 10),
              Text(
                'Bugün bu filtrede etkinlik yok.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Farklı şehir, ilçe, mahalle veya mekan seçerek tekrar dene.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchFirstState extends StatelessWidget {
  const _SearchFirstState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.inputFill,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search, color: AppColors.textMuted, size: 32),
              SizedBox(height: 10),
              Text(
                "Mekanları görmek için önce 'Ara' butonuna bas.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuestLockFooter extends StatelessWidget {
  const _GuestLockFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: const BoxDecoration(
        color: AppColors.navBlueDeep,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                Navigator.of(context).pushNamed(AppRoutes.login);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Giriş Yap'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _GradientActionButton(
              label: 'Üye Ol',
              onPressed: () {
                Navigator.of(context).pushNamed(AppRoutes.register);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _GuestEventItem {
  final String id;
  final String performerName;
  final String performerType;
  final List<String> bandMembers;
  final String venueName;
  final String venueCity;
  final String venueDistrict;
  final String venueNeighborhood;
  final DateTime eventDate;
  final TimeOfDay startTime;
  final TimeOfDay? endTime;
  final String description;

  String get venueKey =>
      '$venueName|$venueCity|$venueDistrict|$venueNeighborhood';

  const _GuestEventItem({
    required this.id,
    required this.performerName,
    required this.performerType,
    required this.bandMembers,
    required this.venueName,
    required this.venueCity,
    required this.venueDistrict,
    required this.venueNeighborhood,
    required this.eventDate,
    required this.startTime,
    required this.endTime,
    required this.description,
  });
}

class _VenueFilterOption {
  final String venueKey;
  final String venueName;
  final String city;
  final String district;
  final String neighborhood;

  const _VenueFilterOption({
    required this.venueKey,
    required this.venueName,
    required this.city,
    required this.district,
    required this.neighborhood,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _VenueFilterOption && other.venueKey == venueKey;
  }

  @override
  int get hashCode => venueKey.hashCode;
}

class _VenueListScreen extends StatelessWidget {
  final List<_VenueFilterOption> venues;
  final String? selectedVenueKey;

  const _VenueListScreen({
    required this.venues,
    required this.selectedVenueKey,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mekanlar')),
      body: venues.isEmpty
          ? const Center(
              child: Text(
                'Bu filtrelere uygun mekan bulunamadı.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              itemCount: venues.length + 1,
              separatorBuilder: (_, __) =>
                  const Divider(color: AppColors.border, height: 1),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return ListTile(
                    onTap: () => Navigator.of(context).pop('__all__'),
                    leading: const Icon(
                      Icons.public,
                      color: AppColors.textMuted,
                    ),
                    title: const Text(
                      'Tüm mekanlar',
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                    trailing: selectedVenueKey == null
                        ? const Icon(Icons.check, color: AppColors.coralLight)
                        : null,
                  );
                }

                final venue = venues[index - 1];
                final isSelected = venue.venueKey == selectedVenueKey;
                return ListTile(
                  onTap: () => Navigator.of(context).pop(venue.venueKey),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.navBlueSoft,
                    child: Text(
                      venue.venueName.isEmpty ? '?' : venue.venueName[0],
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  title: Text(
                    venue.venueName,
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                  subtitle: Text(
                    '${venue.city} / ${venue.district} / ${venue.neighborhood}',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: AppColors.coralLight)
                      : null,
                );
              },
            ),
    );
  }
}

class _GradientActionButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  const _GradientActionButton({
    required this.label,
    this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: AppColors.brandGradient),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: icon == null
            ? Text(label)
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18),
                  const SizedBox(width: 8),
                  Text(label),
                ],
              ),
      ),
    );
  }
}
