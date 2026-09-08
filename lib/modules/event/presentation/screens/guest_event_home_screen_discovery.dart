part of 'guest_event_home_screen.dart';

/// An isolated, reversible guest entry. Search never requires a user session.
class GuestEventDiscoveryScreen extends StatefulWidget {
  const GuestEventDiscoveryScreen({
    super.key,
    this.locationRepository,
    this.searchRepository,
    this.suggestionRepository,
    this.now,
    this.watchClock = true,
    this.showGuestFooter = true,
    this.bottomNavigationBar,
    this.onTableTap,
    this.tableHint = 'Masa açmak için\ndokunun',
  });

  final LocationRepository? locationRepository;
  final EventDiscoverySearchRepository? searchRepository;
  final VenueSuggestionRepository? suggestionRepository;
  final DateTime Function()? now;
  final bool watchClock;
  final bool showGuestFooter;
  final Widget? bottomNavigationBar;
  final VoidCallback? onTableTap;
  final String tableHint;

  @override
  State<GuestEventDiscoveryScreen> createState() => _GuestDiscoveryState();
}

class _GuestDiscoveryState extends State<GuestEventDiscoveryScreen>
    with WidgetsBindingObserver {
  late final LocationRepository _locations;
  late final EventDiscoverySearchRepository _searchRepository;
  late DateTime _today;
  late DateTime _date;
  late final ValueNotifier<DateTime> _dayNotifier;
  Timer? _midnightTimer;
  Timer? _searchDebounce;
  List<City> _cities = [];
  List<District> _districts = [];
  List<Neighborhood> _neighborhoods = [];
  List<DiscoveryEvent> _events = [];
  City? _city;
  District? _district;
  Neighborhood? _neighborhood;
  bool _locationDetailsExpanded = false;
  bool _openingSuggestion = false;
  bool _loadingCities = true;
  bool _loadingDistricts = false;
  bool _loadingNeighborhoods = false;
  bool _searched = false;
  bool _loading = false;
  bool _loadingMore = false;
  bool _last = true;
  int _nextPage = 0;
  int _total = 0;
  int _searchGeneration = 0;
  int _cityGeneration = 0;
  int _districtGeneration = 0;
  int _neighborhoodGeneration = 0;
  String? _cityError;
  String? _districtError;
  String? _neighborhoodError;
  String? _searchError;
  String? _pageError;

  DateTime _now() => widget.now?.call() ?? DateTime.now();

  Future<void> _suggestVenue() async {
    if (_openingSuggestion) return;
    setState(() => _openingSuggestion = true);
    try {
      final submitted = await showVenueSuggestionSheet(
        context,
        locationRepository: _locations,
        repository:
            widget.suggestionRepository ??
            VenueSuggestionRepositoryImpl(serviceLocator<ApiClient>()),
        initialCity: _city,
        initialDistrict: _district,
      );
      if (!mounted || submitted != true) return;
      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar(
          context,
          content: const Text('Önerin bize ulaştı. Teşekkür ederiz!'),
          tone: AppSnackBarTone.success,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar(
          context,
          content: const Text('Öneri formu açılamadı. Lütfen yeniden dene.'),
          tone: AppSnackBarTone.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _openingSuggestion = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _locations =
        widget.locationRepository ?? serviceLocator<LocationRepository>();
    _searchRepository =
        widget.searchRepository ??
        EventDiscoverySearchRepositoryImpl(serviceLocator<ApiClient>());
    _today = EventDiscoveryDatePolicy.today(_now());
    _date = _today;
    _dayNotifier = ValueNotifier(_today);
    WidgetsBinding.instance.addObserver(this);
    _scheduleMidnight();
    // Existing app-launch smoke tests deliberately have no network fixture.
    if (widget.locationRepository == null &&
        Platform.environment.containsKey('FLUTTER_TEST')) {
      _loadingCities = false;
    } else {
      unawaited(_loadCities());
    }
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    _searchDebounce?.cancel();
    _dayNotifier.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncDay();
      _scheduleMidnight();
    }
  }

  void _scheduleMidnight() {
    _midnightTimer?.cancel();
    if (!widget.watchClock) return;
    final now = _now().toUtc();
    final today = EventDiscoveryDatePolicy.today(now);
    final next = DateTime.utc(
      today.year,
      today.month,
      today.day + 1,
    ).subtract(const Duration(hours: 3));
    _midnightTimer = Timer(
      next.difference(now) + const Duration(seconds: 1),
      () {
        if (!mounted) return;
        _syncDay();
        _scheduleMidnight();
      },
    );
  }

  void _syncDay() {
    final today = EventDiscoveryDatePolicy.today(_now());
    if (today == _today) return;
    setState(() {
      _today = today;
      if (!EventDiscoveryDatePolicy.contains(_date, today)) _date = today;
      _dayNotifier.value = today;
      _scheduleSearch();
    });
  }

  void _invalidateSearch() {
    _searchDebounce?.cancel();
    _searchDebounce = null;
    _searchGeneration++;
    _events = [];
    _searched = false;
    _loading = false;
    _loadingMore = false;
    _searchError = null;
    _pageError = null;
    _nextPage = 0;
    _last = true;
    _total = 0;
  }

  // Called inside setState when query inputs change. Invalidate immediately
  // so an older in-flight response cannot appear during the debounce window.
  void _scheduleSearch() {
    _invalidateSearch();
    if (_city == null) return;
    _loading = true;
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _searchDebounce = null;
      if (mounted) unawaited(_search());
    });
  }

  Future<void> _loadCities() async {
    final generation = ++_cityGeneration;
    setState(() {
      _loadingCities = true;
      _cityError = null;
    });
    final result = await _locations.getCities();
    if (!mounted || generation != _cityGeneration) return;
    setState(() {
      _loadingCities = false;
      if (result.isSuccess && result.data != null) {
        _cities = sortByTurkishName(result.data!, (city) => city.name);
        if (_cities.isEmpty) _cityError = 'Şehirler şu an listelenemiyor.';
      } else {
        _cityError = 'Şehirler yüklenemedi. Tekrar deneyebilirsin.';
      }
    });
  }

  Future<void> _selectCity(City city) async {
    if (_city?.id == city.id) return;
    setState(() {
      _city = city;
      _locationDetailsExpanded = false;
      _district = null;
      _neighborhood = null;
      _districts = [];
      _neighborhoods = [];
      _districtError = null;
      _neighborhoodError = null;
      _neighborhoodGeneration++;
      _loadingNeighborhoods = false;
      _scheduleSearch();
    });
    await _loadDistricts();
  }

  Future<void> _loadDistricts() async {
    final cityId = _city?.id;
    if (cityId == null) return;
    final generation = ++_districtGeneration;
    setState(() {
      _loadingDistricts = true;
      _districtError = null;
    });
    final result = await _locations.getDistricts(cityId);
    if (!mounted || generation != _districtGeneration || _city?.id != cityId) {
      return;
    }
    setState(() {
      _loadingDistricts = false;
      if (result.isSuccess && result.data != null) {
        _districts = sortByTurkishName(
          result.data!,
          (district) => district.name,
        );
      } else {
        _districtError = 'İlçeler yüklenemedi.';
      }
    });
  }

  Future<void> _selectDistrict(District? district) async {
    if (_district?.id == district?.id) return;
    setState(() {
      _district = district;
      _neighborhood = null;
      _neighborhoods = [];
      _neighborhoodGeneration++;
      _loadingNeighborhoods = false;
      _neighborhoodError = null;
      _scheduleSearch();
    });
    if (district != null) await _loadNeighborhoods();
  }

  Future<void> _loadNeighborhoods() async {
    final districtId = _district?.id;
    if (districtId == null) return;
    final generation = ++_neighborhoodGeneration;
    setState(() {
      _loadingNeighborhoods = true;
      _neighborhoodError = null;
    });
    final result = await _locations.getNeighborhoods(districtId);
    if (!mounted ||
        generation != _neighborhoodGeneration ||
        _district?.id != districtId) {
      return;
    }
    setState(() {
      _loadingNeighborhoods = false;
      if (result.isSuccess && result.data != null) {
        _neighborhoods = sortByTurkishName(result.data!, (item) => item.name);
      } else {
        _neighborhoodError = 'Mahalleler yüklenemedi.';
      }
    });
  }

  Future<void> _search({bool more = false}) async {
    final cityId = _city?.id;
    if (cityId == null || (more && (_loading || _loadingMore || _last))) return;
    _searchDebounce?.cancel();
    _searchDebounce = null;
    final today = EventDiscoveryDatePolicy.today(_now());
    if (today != _today) {
      _today = today;
      if (!EventDiscoveryDatePolicy.contains(_date, today)) _date = today;
      _dayNotifier.value = today;
      if (more) {
        await _search();
        return;
      }
    }
    final generation = more ? _searchGeneration : ++_searchGeneration;
    final page = more ? _nextPage : 0;
    setState(() {
      _searched = true;
      _pageError = null;
      if (more) {
        _loadingMore = true;
      } else {
        _loading = true;
        _loadingMore = false;
        _searchError = null;
        _events = [];
        _total = 0;
        _nextPage = 0;
        _last = true;
      }
    });
    final result = await _searchRepository.search(
      date: _date,
      cityId: cityId,
      districtId: _district?.id,
      neighborhoodId: _neighborhood?.id,
      page: page,
    );
    if (!mounted || generation != _searchGeneration) return;
    setState(() {
      _loading = false;
      _loadingMore = false;
      if (result.isSuccess && result.data != null) {
        final data = result.data!;
        final seen = more
            ? _events.map((event) => event.id).toSet()
            : <String>{};
        final incoming = data.content.where((event) => seen.add(event.id));
        _events = [if (more) ..._events, ...incoming];
        _total = data.totalElements;
        _nextPage = data.number + 1;
        _last = data.last || data.content.isEmpty || _nextPage > 1000;
      } else if (more) {
        _pageError = 'Diğer etkinlikler yüklenemedi.';
      } else {
        _searchError = result.error?.message ?? 'Etkinlikler yüklenemedi.';
      }
    });
  }

  void _selectDate(DateTime date) {
    _syncDay();
    if (!EventDiscoveryDatePolicy.contains(date, _today) || date == _date) {
      return;
    }
    setState(() {
      _date = date;
      _scheduleSearch();
    });
  }

  Future<void> _pickDate() async {
    _syncDay();
    final selected = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppColors.navBlueDeep,
      builder: (_) => ValueListenableBuilder<DateTime>(
        valueListenable: _dayNotifier,
        builder: (_, today, _) =>
            _DiscoveryDateSheet(today: today, selected: _date),
      ),
    );
    if (mounted && selected != null) _selectDate(selected);
  }

  Future<void> _pickLocation(String level) async {
    final cityId = _city?.id;
    final districtId = _district?.id;
    final options = switch (level) {
      'city' =>
        _cities.map((c) => _FilterOption(value: c.id, label: c.name)).toList(),
      'district' =>
        _districts
            .map((d) => _FilterOption(value: d.id, label: d.name))
            .toList(),
      _ =>
        _neighborhoods
            .map((n) => _FilterOption(value: n.id, label: n.name))
            .toList(),
    };
    final selectedId = switch (level) {
      'city' => _city?.id,
      'district' => _district?.id,
      _ => _neighborhood?.id,
    };
    final selected = await showModalBottomSheet<_FilterOption>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppColors.navBlueDeep,
      builder: (_) => _DiscoveryLocationSheet(
        title: switch (level) {
          'city' => 'Şehir seç',
          'district' => 'İlçe seç',
          _ => 'Mahalle seç',
        },
        options: options,
        selectedId: selectedId,
        allowAll: level != 'city',
      ),
    );
    if (!mounted || selected == null) return;
    if (level == 'city') {
      final matches = _cities.where((c) => c.id == selected.value);
      if (matches.isNotEmpty) await _selectCity(matches.first);
    } else if (level == 'district' && _city?.id == cityId) {
      final matches = _districts.where((d) => d.id == selected.value);
      await _selectDistrict(matches.isEmpty ? null : matches.first);
    } else if (level == 'neighborhood' &&
        _district?.id == districtId &&
        _city?.id == cityId) {
      final matches = _neighborhoods.where((n) => n.id == selected.value);
      final neighborhood = matches.isEmpty ? null : matches.first;
      if (_neighborhood?.id == neighborhood?.id) return;
      setState(() {
        _neighborhood = neighborhood;
        _scheduleSearch();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tomorrow = DateTime(_today.year, _today.month, _today.day + 1);
    final later = _date.isAfter(tomorrow);
    return Scaffold(
      bottomNavigationBar: widget.bottomNavigationBar,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _DiscoveryTableOverlay(
                onTap: widget.onTableTap,
                hint: widget.tableHint,
                child: CustomScrollView(
                  key: const PageStorageKey('guest-discovery-scroll'),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              // Compensate for the existing asset's transparent
                              // left margin proportionally so the enlarged mark
                              // keeps its alignment with the heading.
                              child: Transform.translate(
                                offset: const Offset(-204 * 10 / 190, 0),
                                child: ClipRect(
                                  child: SizedBox(
                                    width: 204,
                                    height: 42,
                                    child: Image.asset(
                                      'assets/Logoyanyana.png',
                                      fit: BoxFit.fitWidth,
                                      alignment: Alignment.center,
                                      filterQuality: FilterQuality.high,
                                      semanticLabel: 'SoundConnect',
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Canlı müzik nerede?',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 29,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.8,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Şehrindeki sahneleri keşfet.',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 26),
                            _DiscoverySurface(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Wrap(
                                    alignment: WrapAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    spacing: 12,
                                    runSpacing: 8,
                                    children: [
                                      const _DiscoveryLabel('NE ZAMAN?'),
                                      Text(
                                        'Önümüzdeki 7 gün',
                                        style: TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      final large =
                                          MediaQuery.textScalerOf(
                                                context,
                                              ).scale(13) >
                                              17 ||
                                          constraints.maxWidth < 260;
                                      final todayButton = _DiscoveryChoice(
                                        label: 'Bugün',
                                        selected: _date == _today,
                                        onTap: () => _selectDate(_today),
                                      );
                                      final tomorrowButton = _DiscoveryChoice(
                                        label:
                                            'Yarın (${EventDiscoveryDatePolicy.shortDate(tomorrow)})',
                                        selected: _date == tomorrow,
                                        onTap: () => _selectDate(tomorrow),
                                      );
                                      final dateButton = _DiscoveryChoice(
                                        label: later
                                            ? EventDiscoveryDatePolicy.shortDate(
                                                _date,
                                              )
                                            : 'Tarih seç',
                                        icon: Icons.calendar_today_outlined,
                                        selected: later,
                                        onTap: _pickDate,
                                      );
                                      return large
                                          ? Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                todayButton,
                                                const SizedBox(height: 8),
                                                tomorrowButton,
                                                const SizedBox(height: 8),
                                                dateButton,
                                              ],
                                            )
                                          : Row(
                                              children: [
                                                Expanded(
                                                  flex: 7,
                                                  child: todayButton,
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  flex: 12,
                                                  child: tomorrowButton,
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  flex: 11,
                                                  child: dateButton,
                                                ),
                                              ],
                                            );
                                    },
                                  ),
                                  const SizedBox(height: 20),
                                  const _DiscoveryLabel('NEREDE?'),
                                  const SizedBox(height: 10),
                                  _DiscoveryField(
                                    label: _loadingCities
                                        ? 'Şehirler yükleniyor'
                                        : (_city?.name ?? 'Şehir seç'),
                                    icon: Icons.location_on_outlined,
                                    loading: _loadingCities,
                                    onTap: _loadingCities || _cities.isEmpty
                                        ? null
                                        : () => _pickLocation('city'),
                                  ),
                                  if (_cityError != null)
                                    _DiscoveryRetry(
                                      message: _cityError!,
                                      onRetry: _loadCities,
                                    ),
                                  if (_city != null) ...[
                                    const SizedBox(height: 2),
                                    Semantics(
                                      button: true,
                                      expanded: _locationDetailsExpanded,
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          key: const ValueKey(
                                            'discovery-location-details-toggle',
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          onTap: () => setState(
                                            () => _locationDetailsExpanded =
                                                !_locationDetailsExpanded,
                                          ),
                                          child: ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              minHeight: 48,
                                            ),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 2,
                                                    vertical: 12,
                                                  ),
                                              child: Row(
                                                children: [
                                                  const BrandGradientIcon.social(
                                                    Icons.tune_rounded,
                                                    size: 16,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      _district == null
                                                          ? 'İlçe veya mahalle seç'
                                                          : [
                                                              _district!.name,
                                                              if (_neighborhood !=
                                                                  null)
                                                                _neighborhood!
                                                                    .name,
                                                            ].join(' · '),
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        color:
                                                            AppColors.textMuted,
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  BrandGradientIcon.social(
                                                    _locationDetailsExpanded
                                                        ? Icons
                                                              .keyboard_arrow_up_rounded
                                                        : Icons
                                                              .keyboard_arrow_down_rounded,
                                                    size: 18,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (_city != null &&
                                      _locationDetailsExpanded) ...[
                                    const SizedBox(height: 6),
                                    LayoutBuilder(
                                      builder: (context, constraints) {
                                        final stacked =
                                            constraints.maxWidth < 270 ||
                                            MediaQuery.textScalerOf(
                                                  context,
                                                ).scale(12) >
                                                16;
                                        final district = _DiscoveryField(
                                          label:
                                              _district?.name ?? 'Tüm ilçeler',
                                          icon: Icons.place_outlined,
                                          compact: !stacked,
                                          loading: _loadingDistricts,
                                          onTap:
                                              _city == null ||
                                                  _loadingDistricts ||
                                                  _districtError != null
                                              ? null
                                              : () => _pickLocation('district'),
                                        );
                                        final neighborhood = _DiscoveryField(
                                          label:
                                              _neighborhood?.name ??
                                              'Tüm mahalleler',
                                          icon: Icons.near_me_outlined,
                                          compact: !stacked,
                                          loading: _loadingNeighborhoods,
                                          onTap:
                                              _district == null ||
                                                  _loadingNeighborhoods ||
                                                  _neighborhoodError != null
                                              ? null
                                              : () => _pickLocation(
                                                  'neighborhood',
                                                ),
                                        );
                                        return stacked
                                            ? Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.stretch,
                                                children: [
                                                  district,
                                                  const SizedBox(height: 10),
                                                  neighborhood,
                                                ],
                                              )
                                            : IntrinsicHeight(
                                                child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .stretch,
                                                  children: [
                                                    Expanded(child: district),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: neighborhood,
                                                    ),
                                                  ],
                                                ),
                                              );
                                      },
                                    ),
                                    if (_districtError != null)
                                      _DiscoveryRetry(
                                        message: _districtError!,
                                        onRetry: _loadDistricts,
                                      ),
                                    if (_neighborhoodError != null)
                                      _DiscoveryRetry(
                                        message: _neighborhoodError!,
                                        onRetry: _loadNeighborhoods,
                                      ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            _DiscoveryBetaNotice(
                              onSuggest: _openingSuggestion
                                  ? null
                                  : _suggestVenue,
                            ),
                            const SizedBox(height: 16),
                            if (_searched &&
                                !_loading &&
                                _searchError == null) ...[
                              const SizedBox(height: 8),
                              Text(
                                [
                                      EventDiscoveryDatePolicy.longDate(_date),
                                      _city?.name,
                                      _district?.name,
                                      _neighborhood?.name,
                                    ]
                                    .whereType<String>()
                                    .map((part) => part.trim())
                                    .where((part) => part.isNotEmpty)
                                    .join(' · '),
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '$_total etkinlik',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            if (_loading)
                              const Padding(
                                padding: EdgeInsets.all(30),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            if (_searchError != null)
                              _DiscoveryRetry(
                                message: _searchError!,
                                onRetry: () => _search(),
                              ),
                            if (_searched &&
                                !_loading &&
                                _searchError == null &&
                                _events.isEmpty)
                              _DiscoverySurface(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Bu gün için etkinlik bulunamadı.',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Başka bir gün seçebilir veya konumunu genişletebilirsin.',
                                      style: TextStyle(
                                        color: AppColors.textMuted,
                                        height: 1.5,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                      sliver: SliverList.builder(
                        itemCount: _events.length,
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: TrackEventImpression(
                            eventId: _events[index].id,
                            child: _DiscoveryEventTile(item: _events[index]),
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          0,
                          20,
                          128 + MediaQuery.textScalerOf(context).scale(12) * 3,
                        ),
                        child: Column(
                          children: [
                            if (_pageError != null)
                              _DiscoveryRetry(
                                message: _pageError!,
                                onRetry: () => _search(more: true),
                              ),
                            if (!_last && _pageError == null)
                              _DiscoveryPrimaryButton(
                                label: 'Daha fazla etkinlik',
                                loading: _loadingMore,
                                onTap: _loadingMore
                                    ? null
                                    : () => _search(more: true),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (widget.showGuestFooter) const _DiscoveryAuthFooter(),
          ],
        ),
      ),
    );
  }
}

class _DiscoveryTableOverlay extends StatefulWidget {
  const _DiscoveryTableOverlay({
    required this.child,
    required this.hint,
    this.onTap,
  });
  final Widget child;
  final String hint;
  final VoidCallback? onTap;

  @override
  State<_DiscoveryTableOverlay> createState() => _DiscoveryTableOverlayState();
}

class _DiscoveryTableOverlayState extends State<_DiscoveryTableOverlay> {
  Offset _offset = Offset.zero;

  Future<void> _openTables() async {
    if (widget.onTap != null) {
      widget.onTap!();
    } else {
      await _openDiscoveryTableGate(context);
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scaler = MediaQuery.textScalerOf(context);
      final maxWidth = (constraints.maxWidth - 24).clamp(72.0, double.infinity);
      final width = (130 * scaler.scale(12) / 12).clamp(72.0, maxWidth);
      final hintStyle = DefaultTextStyle.of(context).style.merge(
        const TextStyle(
          fontSize: 12,
          height: 1.15,
          fontWeight: FontWeight.w500,
        ),
      );
      final painter = TextPainter(
        text: TextSpan(text: widget.hint, style: hintStyle),
        textDirection: Directionality.of(context),
        textScaler: scaler,
      )..layout(maxWidth: width - 24);
      final fullHeight = painter.height + 16 + 8 + 72;
      painter.dispose();
      final showHint = constraints.maxHeight >= fullHeight + 24;
      final height = showHint ? fullHeight : 72.0;
      final fabWidth = showHint ? width : 88.0;
      final maxLeft = (constraints.maxWidth - fabWidth - 12).clamp(
        0.0,
        double.infinity,
      );
      final maxTop = (constraints.maxHeight - height - 12).clamp(
        0.0,
        double.infinity,
      );
      return Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          Positioned(
            left: (maxLeft + _offset.dx).clamp(0.0, maxLeft),
            top: (maxTop + _offset.dy).clamp(0.0, maxTop),
            width: fabWidth,
            child: Tooltip(
              message: 'Masalar',
              excludeFromSemantics: true,
              child: Semantics(
                container: true,
                excludeSemantics: true,
                button: true,
                label: 'Masalar',
                onTap: _openTables,
                child: _GuestTableAccessFab(
                  hintText: widget.hint,
                  showHint: showHint,
                  onTap: _openTables,
                  onDragDelta: (delta) => setState(() {
                    final left = (maxLeft + _offset.dx).clamp(0.0, maxLeft);
                    final top = (maxTop + _offset.dy).clamp(0.0, maxTop);
                    _offset = Offset(
                      (left + delta.dx).clamp(0.0, maxLeft) - maxLeft,
                      (top + delta.dy).clamp(0.0, maxTop) - maxTop,
                    );
                  }),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}
