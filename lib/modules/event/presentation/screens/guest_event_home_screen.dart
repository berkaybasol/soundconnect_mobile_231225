import 'package:flutter/material.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../shared/theme/app_colors.dart';

class GuestEventHomeScreen extends StatefulWidget {
  GuestEventHomeScreen({super.key});

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
      bandMembers: [],
      venueName: 'Sahil Sahne',
      venueCity: 'Istanbul',
      venueDistrict: 'Besiktas',
      venueNeighborhood: 'Sinanpasa',
      eventDate: DateTime(_today.year, _today.month, _today.day),
      startTime: TimeOfDay(hour: 20, minute: 30),
      endTime: TimeOfDay(hour: 22, minute: 0),
      description: 'Akustik pop ve indie seckiler.',
    ),
    _GuestEventItem(
      id: '2',
      performerName: 'Neon Tide',
      performerType: 'BAND',
      bandMembers: ['Mert', 'Ece', 'Can'],
      venueName: 'Ritim Klub',
      venueCity: 'Istanbul',
      venueDistrict: 'Kadikoy',
      venueNeighborhood: 'Moda',
      eventDate: DateTime(_today.year, _today.month, _today.day),
      startTime: TimeOfDay(hour: 21, minute: 0),
      endTime: TimeOfDay(hour: 23, minute: 15),
      description: 'Alternatif rock gecesi.',
    ),
    _GuestEventItem(
      id: '3',
      performerName: 'Aegean Jazz Trio',
      performerType: 'BAND',
      bandMembers: ['Baris', 'Deniz', 'Selin'],
      venueName: 'Blue Note Izmir',
      venueCity: 'Izmir',
      venueDistrict: 'Konak',
      venueNeighborhood: 'Alsancak',
      eventDate: DateTime(_today.year, _today.month, _today.day),
      startTime: TimeOfDay(hour: 19, minute: 45),
      endTime: TimeOfDay(hour: 21, minute: 30),
      description: 'Canli jazz standartlari.',
    ),
    _GuestEventItem(
      id: '4',
      performerName: 'Sokak Ritim',
      performerType: 'MUSICIAN',
      bandMembers: [],
      venueName: 'Kiyi Sahne',
      venueCity: 'Istanbul',
      venueDistrict: 'Besiktas',
      venueNeighborhood: 'Levent',
      eventDate: DateTime(_today.year, _today.month, _today.day),
      startTime: TimeOfDay(hour: 18, minute: 30),
      endTime: TimeOfDay(hour: 20, minute: 0),
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
        : <_GuestEventItem>[];
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
                      padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: _HeroPanel(count: visibleEvents.length),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 12, 16, 10),
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
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _SearchFirstState(),
                    )
                  else if (visibleEvents.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _GuestEmptyState(),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          return Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: _EventCard(item: visibleEvents[index]),
                          );
                        }, childCount: visibleEvents.length),
                      ),
                    ),
                ],
              ),
            ),
            _GuestLockFooter(),
          ],
        ),
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  final int count;

  _HeroPanel({required this.count});

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
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A2740), Color(0xFF10243B), Color(0xFF1B1E37)],
        ),
        border: Border.all(color: Theme.of(context).dividerColor),
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
                  gradient: LinearGradient(colors: AppColors.brandGradient),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.brandGradient[2].withValues(alpha: 0.35),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Icon(Icons.music_note, color: AppColors.white, size: 18),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Bugun Nerede Canli Muzik Var?',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            '${_dateLabel()} tarihinde yakinda $count etkinlik bulundu',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
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

  _InlineFilterPanel({
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
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.tune,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: 18,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Lokasyona gore ara',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              TextButton(onPressed: onClearAll, child: Text('Temizle')),
            ],
          ),
          _FilterDropdown(
            label: 'Sehir sec',
            value: selectedCity,
            items: cityOptions,
            allLabel: 'Sehir',
            onChanged: onCityChanged,
          ),
          SizedBox(height: 8),
          _FilterDropdown(
            label: 'Ilce sec',
            value: selectedDistrict,
            items: districtOptions,
            allLabel: 'Ilce',
            onChanged: onDistrictChanged,
          ),
          SizedBox(height: 8),
          _FilterDropdown(
            label: 'Mahalle sec',
            value: selectedNeighborhood,
            items: neighborhoodOptions,
            allLabel: 'Mahalle',
            onChanged: onNeighborhoodChanged,
          ),
          SizedBox(height: 8),
          if (selectedVenueName != null && selectedVenueName!.trim().isNotEmpty)
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Text(
                'Secilen mekan: $selectedVenueName',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          if (selectedVenueName != null && selectedVenueName!.trim().isNotEmpty)
            SizedBox(height: 8),
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

  _FilterDropdown({
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
      dropdownColor: Theme.of(context).colorScheme.surfaceContainer,
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

  _GradientDropdownField({
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
      duration: Duration(milliseconds: 160),
      padding: EdgeInsets.all(1.2),
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: _isFocused
            ? LinearGradient(colors: AppColors.brandGradient)
            : null,
        color: _isFocused ? null : Theme.of(context).dividerColor,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10.8),
        ),
        child: DropdownButtonFormField<String?>(
          focusNode: _focusNode,
          value: widget.value,
          isExpanded: true,
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
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

  _EventCard({required this.item});

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
      padding: EdgeInsets.all(1.2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [Color(0x40F07A5E), Color(0x20E062A9), Color(0x409A58F4)],
        ),
      ),
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
          ),
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
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    item.venueName.trim().isEmpty
                        ? '?'
                        : item.venueName.trim()[0].toUpperCase(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.venueName,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '${item.venueDistrict} / ${item.venueNeighborhood}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: LinearGradient(colors: AppColors.brandGradient),
                  ),
                  child: Text(
                    _timeLabel(),
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.performerName,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: Theme.of(context).colorScheme.surfaceContainer,
                  ),
                  child: Text(
                    item.performerType,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (item.description.trim().isNotEmpty) ...[
              SizedBox(height: 7),
              Text(
                item.description,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
            if (item.bandMembers.isNotEmpty) ...[
              SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: item.bandMembers
                    .map(
                      (member) => Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                        child: Text(
                          member,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
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
  _GuestEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.music_off,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: 32,
              ),
              SizedBox(height: 10),
              Text(
                'Bugun bu filtrede etkinlik yok.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Farkli sehir, ilce, mahalle veya mekan secerek tekrar dene.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchFirstState extends StatelessWidget {
  _SearchFirstState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: 32,
              ),
              SizedBox(height: 10),
              Text(
                "Mekanlari gormek icin once 'Ara' butonuna bas.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
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
  _GuestLockFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.navBlueDeep,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                Navigator.of(context).pushNamed(AppRoutes.login);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                side: BorderSide(color: Theme.of(context).dividerColor),
                padding: EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text('Giris Yap'),
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: _GradientActionButton(
              label: 'Uye Ol',
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

  _GuestEventItem({
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

  _VenueFilterOption({
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

  _VenueListScreen({required this.venues, required this.selectedVenueKey});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Mekanlar')),
      body: venues.isEmpty
          ? Center(
              child: Text(
                'Bu filtrelere uygun mekan bulunamadi.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : ListView.separated(
              padding: EdgeInsets.only(top: 8, bottom: 16),
              itemCount: venues.length + 1,
              separatorBuilder: (_, __) =>
                  Divider(color: Theme.of(context).dividerColor, height: 1),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return ListTile(
                    onTap: () => Navigator.of(context).pop('__all__'),
                    leading: Icon(
                      Icons.public,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    title: Text(
                      'Tum mekanlar',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    trailing: selectedVenueKey == null
                        ? Icon(Icons.check, color: AppColors.coralLight)
                        : null,
                  );
                }

                final venue = venues[index - 1];
                final isSelected = venue.venueKey == selectedVenueKey;
                return ListTile(
                  onTap: () => Navigator.of(context).pop(venue.venueKey),
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainer,
                    child: Text(
                      venue.venueName.isEmpty ? '?' : venue.venueName[0],
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  title: Text(
                    venue.venueName,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    '${venue.city} / ${venue.district} / ${venue.neighborhood}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check, color: AppColors.coralLight)
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

  _GradientActionButton({
    required this.label,
    this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: AppColors.brandGradient),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: AppColors.white,
          padding: EdgeInsets.symmetric(vertical: 14),
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
                  SizedBox(width: 8),
                  Text(label),
                ],
              ),
      ),
    );
  }
}
