import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../location/domain/entities/city.dart';
import '../../../location/domain/entities/district.dart';
import '../../../location/domain/entities/neighborhood.dart';
import '../../../location/domain/location_repository.dart';
import '../../domain/entities/discovery_event.dart';
import '../../domain/event_discovery_repository.dart';
import '../../../profile/presentation/screens/weekly_event_detail_screen.dart';

class GuestEventHomeScreen extends StatefulWidget {
  GuestEventHomeScreen({super.key});

  @override
  State<GuestEventHomeScreen> createState() => _GuestEventHomeScreenState();
}

class _GuestEventHomeScreenState extends State<GuestEventHomeScreen> {
  final LocationRepository _locationRepository =
      serviceLocator<LocationRepository>();
  final EventDiscoveryRepository _eventDiscoveryRepository =
      serviceLocator<EventDiscoveryRepository>();

  List<City> _cities = const <City>[];
  List<District> _districts = const <District>[];
  List<Neighborhood> _neighborhoods = const <Neighborhood>[];
  List<DiscoveryEvent> _events = const <DiscoveryEvent>[];

  String? _selectedCityId;
  String? _selectedDistrictId;
  String? _selectedNeighborhoodId;

  bool _isInitialLoading = true;
  bool _isEventsLoading = false;
  bool _showResults = false;
  String? _initialError;
  String? _eventsError;
  Offset _tableFabOffset = Offset.zero;

  @override
  void initState() {
    super.initState();
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      _isInitialLoading = false;
      return;
    }
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isInitialLoading = true;
      _initialError = null;
    });

    final citiesResult = await _locationRepository.getCities();

    if (!mounted) return;

    final hasCities = citiesResult.isSuccess && citiesResult.data != null;

    setState(() {
      _cities = hasCities ? _sortCities(citiesResult.data!) : const <City>[];
      _isInitialLoading = false;
      _initialError = citiesResult.error?.message;
    });
  }

  List<City> _sortCities(List<City> input) {
    final list = List<City>.from(input);
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  Future<void> _onCityChanged(String? cityId) async {
    setState(() {
      _selectedCityId = cityId;
      _selectedDistrictId = null;
      _selectedNeighborhoodId = null;
      _districts = const <District>[];
      _neighborhoods = const <Neighborhood>[];
      _showResults = false;
      _events = const <DiscoveryEvent>[];
      _eventsError = null;
    });
    if (cityId == null || cityId.isEmpty) {
      return;
    }
    await _loadDistricts(cityId);
  }

  Future<void> _onDistrictChanged(String? districtId) async {
    setState(() {
      _selectedDistrictId = districtId;
      _selectedNeighborhoodId = null;
      _neighborhoods = const <Neighborhood>[];
      _showResults = false;
      _events = const <DiscoveryEvent>[];
      _eventsError = null;
    });
    if (districtId == null || districtId.isEmpty) {
      return;
    }
    await _loadNeighborhoods(districtId);
  }

  void _onNeighborhoodChanged(String? neighborhoodId) {
    setState(() {
      _selectedNeighborhoodId = neighborhoodId;
      _showResults = false;
      _events = const <DiscoveryEvent>[];
      _eventsError = null;
    });
  }

  Future<void> _loadDistricts(String cityId) async {
    final result = await _locationRepository.getDistricts(cityId);
    if (!mounted) return;
    setState(() {
      _districts = result.isSuccess && result.data != null
          ? _sortDistricts(result.data!)
          : const <District>[];
    });
  }

  List<District> _sortDistricts(List<District> input) {
    final list = List<District>.from(input);
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  Future<void> _loadNeighborhoods(String districtId) async {
    final result = await _locationRepository.getNeighborhoods(districtId);
    if (!mounted) return;
    setState(() {
      _neighborhoods = result.isSuccess && result.data != null
          ? _sortNeighborhoods(result.data!)
          : const <Neighborhood>[];
    });
  }

  List<Neighborhood> _sortNeighborhoods(List<Neighborhood> input) {
    final list = List<Neighborhood>.from(input);
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  Future<void> _onSearchTap() async {
    setState(() {
      _showResults = true;
    });
    await _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isEventsLoading = true;
      _eventsError = null;
      _events = const <DiscoveryEvent>[];
    });

    final result = await _fetchEvents();
    if (!mounted) return;

    setState(() {
      _isEventsLoading = false;
      if (result.isSuccess && result.data != null) {
        _events = _filterUpcoming24Hours(result.data!);
        _eventsError = null;
      } else {
        _events = const <DiscoveryEvent>[];
        _eventsError = result.error?.message ?? 'Etkinlikler alınamadı.';
      }
    });
  }

  Future<Result<List<DiscoveryEvent>>> _fetchEvents() {
    if (_selectedNeighborhoodId != null && _selectedNeighborhoodId!.isNotEmpty) {
      return _eventDiscoveryRepository.getEventsByNeighborhood(
        _selectedNeighborhoodId!,
      );
    }
    if (_selectedDistrictId != null && _selectedDistrictId!.isNotEmpty) {
      return _eventDiscoveryRepository.getEventsByDistrict(_selectedDistrictId!);
    }
    if (_selectedCityId != null && _selectedCityId!.isNotEmpty) {
      return _eventDiscoveryRepository.getEventsByCity(_selectedCityId!);
    }
    return _eventDiscoveryRepository.getTodayEvents();
  }

  List<DiscoveryEvent> _filterUpcoming24Hours(List<DiscoveryEvent> input) {
    final now = DateTime.now();
    final windowEnd = now.add(const Duration(hours: 24));

    bool isInWindow(DiscoveryEvent event) {
      final date = event.eventDate;
      if (date == null) {
        return false;
      }

      final startTime = event.startTime ?? const TimeOfDay(hour: 0, minute: 0);
      final endTime = event.endTime ?? startTime;

      final start = DateTime(
        date.year,
        date.month,
        date.day,
        startTime.hour,
        startTime.minute,
      );
      var end = DateTime(
        date.year,
        date.month,
        date.day,
        endTime.hour,
        endTime.minute,
      );

      if (end.isBefore(start)) {
        end = end.add(const Duration(days: 1));
      }

      // Event is included if it overlaps with the next 24-hour window.
      return start.isBefore(windowEnd) && end.isAfter(now);
    }

    final filtered = input.where(isInWindow).toList();
    filtered.sort((a, b) {
      final ad = a.eventDate;
      final bd = b.eventDate;
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;

      final at = a.startTime ?? const TimeOfDay(hour: 0, minute: 0);
      final bt = b.startTime ?? const TimeOfDay(hour: 0, minute: 0);

      final aDateTime = DateTime(ad.year, ad.month, ad.day, at.hour, at.minute);
      final bDateTime = DateTime(bd.year, bd.month, bd.day, bt.hour, bt.minute);
      return aDateTime.compareTo(bDateTime);
    });
    return filtered;
  }

  void _clearAll() {
    setState(() {
      _selectedCityId = null;
      _selectedDistrictId = null;
      _selectedNeighborhoodId = null;
      _districts = const <District>[];
      _neighborhoods = const <Neighborhood>[];
      _showResults = false;
      _events = const <DiscoveryEvent>[];
      _eventsError = null;
    });
  }

  Future<void> _showTableAccessGate() async {
    if (!mounted) return;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Kapat',
      barrierColor: Colors.black.withValues(alpha: 0.28),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, _, __) {
        return Stack(
          children: [
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 7.5, sigmaY: 7.5),
                child: const SizedBox.expand(),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Theme.of(context).dividerColor),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.pureBlack.withValues(alpha: 0.24),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) {
                            return LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: AppColors.brandGradient,
                            ).createShader(bounds);
                          },
                          blendMode: BlendMode.srcIn,
                          child: const Icon(
                            Icons.lock_outline_rounded,
                            color: AppColors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Masaları görüntülemek veya masa açabilmek için üye olun.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 52,
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    Navigator.of(
                                      context,
                                    ).pushNamed(AppRoutes.login);
                                  },
                                  child: const Text('Giriş Yap'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _GradientActionButton(
                                  label: 'Üye Ol',
                                  backgroundColor: AppColors.navBlueDeep,
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    Navigator.of(
                                      context,
                                    ).pushNamed(AppRoutes.register);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (context, animation, _, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cityOptions = _cities
        .map((e) => _FilterOption(value: e.id, label: e.name))
        .toList();
    final districtOptions = _districts
        .map((e) => _FilterOption(value: e.id, label: e.name))
        .toList();
    final neighborhoodOptions = _neighborhoods
        .map((e) => _FilterOption(value: e.id, label: e.name))
        .toList();

    final screenSize = MediaQuery.sizeOf(context);
    const fabSize = Size(130, 126);
    final baseFab = Offset(
      screenSize.width - fabSize.width - 16,
      screenSize.height - fabSize.height - 98,
    );
    final fabLeft = (baseFab.dx + _tableFabOffset.dx).clamp(
      8.0,
      screenSize.width - fabSize.width - 8,
    );
    final fabTop = (baseFab.dy + _tableFabOffset.dy).clamp(
      72.0,
      screenSize.height - fabSize.height - 8,
    );

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: _HeroPanel(count: _events.length),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                          child: _InlineFilterPanel(
                            selectedCityId: _selectedCityId,
                            selectedDistrictId: _selectedDistrictId,
                            selectedNeighborhoodId: _selectedNeighborhoodId,
                            cityOptions: cityOptions,
                            districtOptions: districtOptions,
                            neighborhoodOptions: neighborhoodOptions,
                            onCityChanged: _onCityChanged,
                            onDistrictChanged: _onDistrictChanged,
                            onNeighborhoodChanged: _onNeighborhoodChanged,
                            onSearchTap: _onSearchTap,
                            onClearAll: _clearAll,
                          ),
                        ),
                      ),
                      if (_isInitialLoading)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: _CenteredLoadingState(),
                        )
                      else if (_initialError != null &&
                          _initialError!.trim().isNotEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _ErrorState(
                            message: _initialError!,
                            actionLabel: 'Tekrar dene',
                            onAction: _loadInitial,
                          ),
                        )
                      else if (!_showResults)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: _SearchFirstState(),
                        )
                      else if (_isEventsLoading)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: _CenteredLoadingState(),
                        )
                      else if (_eventsError != null &&
                          _eventsError!.trim().isNotEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _ErrorState(
                            message: _eventsError!,
                            actionLabel: 'Yenile',
                            onAction: _loadEvents,
                          ),
                        )
                      else if (_events.isEmpty)
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
                                child: _EventCard(item: _events[index]),
                              );
                            }, childCount: _events.length),
                          ),
                        ),
                    ],
                  ),
                ),
                _GuestLockFooter(),
              ],
            ),
            Positioned(
              left: fabLeft,
              top: fabTop,
              child: _GuestTableAccessFab(
                onTap: _showTableAccessGate,
                onDragDelta: (delta) {
                  setState(() {
                    _tableFabOffset += delta;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  final int count;

  const _HeroPanel({required this.count});

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
                child: const Icon(
                  Icons.music_note,
                  color: AppColors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Bugün Nerede Canlı Müzik Var?',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Filtreye göre $count etkinlik bulundu',
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
  final String? selectedCityId;
  final String? selectedDistrictId;
  final String? selectedNeighborhoodId;
  final List<_FilterOption> cityOptions;
  final List<_FilterOption> districtOptions;
  final List<_FilterOption> neighborhoodOptions;
  final ValueChanged<String?> onCityChanged;
  final ValueChanged<String?> onDistrictChanged;
  final ValueChanged<String?> onNeighborhoodChanged;
  final Future<void> Function() onSearchTap;
  final VoidCallback onClearAll;

  const _InlineFilterPanel({
    required this.selectedCityId,
    required this.selectedDistrictId,
    required this.selectedNeighborhoodId,
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
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Lokasyona göre ara',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
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
            value: selectedCityId,
            items: cityOptions,
            allLabel: 'Şehir',
            onChanged: onCityChanged,
          ),
          const SizedBox(height: 8),
          _FilterDropdown(
            label: 'İlçe seç',
            value: selectedDistrictId,
            items: districtOptions,
            allLabel: 'İlçe',
            onChanged: onDistrictChanged,
          ),
          const SizedBox(height: 8),
          _FilterDropdown(
            label: 'Mahalle seç',
            value: selectedNeighborhoodId,
            items: neighborhoodOptions,
            allLabel: 'Mahalle',
            onChanged: onNeighborhoodChanged,
          ),
          const SizedBox(height: 8),
          _GradientActionButton(
            label: 'Ara',
            icon: Icons.search,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            onPressed: onSearchTap,
          ),
        ],
      ),
    );
  }
}

class _FilterOption {
  final String value;
  final String label;

  const _FilterOption({required this.value, required this.label});
}

class _FilterDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<_FilterOption> items;
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
      dropdownColor: Theme.of(context).colorScheme.surfaceContainer,
      items: [
        DropdownMenuItem<String?>(value: null, child: Text(allLabel)),
        ...items.map(
          (item) => DropdownMenuItem<String?>(
            value: item.value,
            child: Text(item.label),
          ),
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
  final DiscoveryEvent item;

  const _EventCard({required this.item});

  String _twoDigits(int value) => value.toString().padLeft(2, '0');

  String _formatTime(TimeOfDay time) =>
      '${_twoDigits(time.hour)}:${_twoDigits(time.minute)}';

  String _timeLabel() {
    final start = item.startTime == null ? null : _formatTime(item.startTime!);
    final end = item.endTime == null ? null : _formatTime(item.endTime!);
    if (start == null && end == null) return '--:--';
    if (start != null && end == null) return start;
    if (start == null && end != null) return end;
    return '$start - $end';
  }

  bool _isNetworkImage(String? value) {
    final raw = value?.trim();
    if (raw == null || raw.isEmpty) return false;
    final uri = Uri.tryParse(raw);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  String _dateLabel() {
    final date = item.eventDate;
    if (date == null) {
      return '-';
    }
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }

  void _openDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WeeklyEventDetailScreen(
          event: WeeklyCalendarEvent(
            id: item.id,
            title: item.title,
            artistName: item.performerName,
            artistProfileId: item.musicianProfileId,
            venueName: item.venueName,
            venueId: item.venueId,
            city: item.venueCity ?? '-',
            district: item.venueDistrict ?? '-',
            neighborhood: item.venueNeighborhood ?? '-',
            eventDate: _dateLabel(),
            startTime: item.startTime == null ? '--:--' : _formatTime(item.startTime!),
            endTime: item.endTime == null ? '--:--' : _formatTime(item.endTime!),
            imageAssetPath: item.posterImageUrl,
            description: item.description.trim().isEmpty
                ? 'Etkinlik açıklaması bulunmuyor.'
                : item.description,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final location = [
      item.venueDistrict ?? '',
      item.venueNeighborhood ?? '',
    ].where((e) => e.trim().isNotEmpty).join(' / ');

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _openDetail(context),
      child: Container(
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
                  CircleAvatar(
                    radius: 19,
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                    backgroundImage: _isNetworkImage(item.venueImageUrl)
                        ? NetworkImage(item.venueImageUrl!)
                        : null,
                    child: _isNetworkImage(item.venueImageUrl)
                        ? null
                        : Text(
                            item.venueName.trim().isEmpty
                                ? '?'
                                : item.venueName.trim()[0].toUpperCase(),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
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
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          location.isEmpty ? '-' : location,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: LinearGradient(colors: AppColors.brandGradient),
                    ),
                    child: Text(
                      _timeLabel(),
                      style: const TextStyle(
                        color: AppColors.white,
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
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                    backgroundImage: _isNetworkImage(item.performerImageUrl)
                        ? NetworkImage(item.performerImageUrl!)
                        : null,
                    child: _isNetworkImage(item.performerImageUrl)
                        ? null
                        : Icon(
                            Icons.person_outline,
                            size: 16,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                  ),
                  const SizedBox(width: 8),
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
                  Text(
                    'Detaylar için tıkla',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              if (item.description.trim().isNotEmpty) ...[
                const SizedBox(height: 7),
                Text(
                  item.description,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                            color: Theme.of(context).colorScheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Theme.of(context).dividerColor),
                          ),
                          child: Text(
                            member,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
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
              const SizedBox(height: 10),
              Text(
                'Bu filtrede etkinlik yok.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Farklı şehir, ilçe, mahalle veya mekan seçerek tekrar dene.',
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
  const _SearchFirstState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(18),
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
              const SizedBox(height: 10),
              Text(
                'Henüz bir konum seçmedin.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Yakındaki canlı müzik mekanlarını görmek için konumunu seçip arama yap.',
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

class _CenteredLoadingState extends StatelessWidget {
  const _CenteredLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final String actionLabel;
  final Future<void> Function() onAction;

  const _ErrorState({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: 32,
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onAction,
                child: Text(actionLabel),
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
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
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
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Giriş Yap'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _GradientActionButton(
              label: 'Üye Ol',
              backgroundColor: AppColors.navBlueDeep,
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

class _GradientActionButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color backgroundColor;
  final VoidCallback? onPressed;

  const _GradientActionButton({
    required this.label,
    this.icon,
    required this.backgroundColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;
    final gradientColors = isEnabled
        ? AppColors.brandGradient
        : <Color>[
            Theme.of(context).dividerColor.withValues(alpha: 0.7),
            Theme.of(context).dividerColor.withValues(alpha: 0.7),
          ];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onPressed,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradientColors),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.all(1),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(17),
              ),
              child: icon == null
                  ? Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isEnabled
                            ? Theme.of(context).colorScheme.onSurface
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          icon,
                          size: 18,
                          color: isEnabled
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          label,
                          style: TextStyle(
                            color: isEnabled
                                ? Theme.of(context).colorScheme.onSurface
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GuestTableAccessFab extends StatefulWidget {
  final Future<void> Function() onTap;
  final ValueChanged<Offset> onDragDelta;

  const _GuestTableAccessFab({required this.onTap, required this.onDragDelta});

  @override
  State<_GuestTableAccessFab> createState() => _GuestTableAccessFabState();
}

class _GuestTableAccessFabState extends State<_GuestTableAccessFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final bool _disablePulseForTest;

  @override
  void initState() {
    super.initState();
    _disablePulseForTest = Platform.environment.containsKey('FLUTTER_TEST');
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1150),
    );
    if (_disablePulseForTest) {
      _scale = const AlwaysStoppedAnimation<double>(1.0);
    } else {
      _scale = Tween<double>(
        begin: 0.98,
        end: 1.03,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onPanUpdate: (details) => widget.onDragDelta(details.delta),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).dividerColor),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.pureBlack.withValues(alpha: 0.14),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                'Masa açmak için\ndokunun',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 12,
                  height: 1.15,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: AppColors.brandGradient,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brandGradient.last.withValues(alpha: 0.42),
                    blurRadius: 16,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: const Icon(
                Icons.groups_2_rounded,
                color: AppColors.white,
                size: 34,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
