part of 'marketplace_screen.dart';

final _money = NumberFormat.currency(
  locale: 'tr_TR',
  symbol: '₺',
  decimalDigits: 2,
);
String _price(int? minor) =>
    minor == null ? 'Fiyat eklenmedi' : _money.format(minor / 100);
InputDecoration _decoration(String label, {IconData? icon}) => InputDecoration(
  labelText: label,
  filled: true,
  prefixIcon: icon == null ? null : Icon(icon),
);

class _MarketplaceIntro extends StatelessWidget {
  const _MarketplaceIntro();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 38,
        height: 3,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: AppColors.decorativeGradient),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      Text(
        'Ekipmanına yeni\nbir sahne aç.',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 29,
          fontWeight: FontWeight.w800,
          letterSpacing: -.9,
          height: 1.16,
        ),
      ),
    ],
  );
}

class _MarketplaceIconAction extends StatelessWidget {
  const _MarketplaceIconAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.highlighted = false,
    this.size = 44,
  });
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool highlighted;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GradientOutline(
      enabled: highlighted,
      radius: 16,
      strokeWidth: 1.2,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: 21),
        style: IconButton.styleFrom(
          minimumSize: Size.square(size),
          backgroundColor: scheme.surfaceContainer,
          foregroundColor: scheme.onSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          side: highlighted
              ? BorderSide.none
              : BorderSide(color: scheme.outline),
        ),
      ),
    );
  }
}

class _MarketplaceCreateButton extends StatelessWidget {
  const _MarketplaceCreateButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GradientOutline(
      enabled: !dark,
      radius: 18,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: dark
              ? LinearGradient(colors: AppColors.actionGradient)
              : null,
          color: dark ? null : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: dark
              ? [
                  BoxShadow(
                    color: AppColors.socialPurple.withValues(alpha: .16),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: FloatingActionButton.extended(
          onPressed: onPressed,
          elevation: 0,
          focusElevation: 0,
          hoverElevation: 0,
          highlightElevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: dark
              ? Colors.white
              : Theme.of(context).colorScheme.onSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          icon: const Icon(Icons.add_rounded, size: 22),
          label: const Text(
            'İlan ver',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
        ),
      ),
    );
  }
}

void _message(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

/// A delayed or repeated completion must never pop the page below its route.
void _popMarketplaceRoute<T>(BuildContext context, [T? result]) {
  if (!marketplaceCanAct(context) ||
      ModalRoute.of(context)?.isCurrent != true) {
    return;
  }
  Navigator.of(context).pop(result);
}

class _MarketplaceError extends StatelessWidget {
  const _MarketplaceError({required this.message, required this.retry});
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.all(20),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainer,
      border: Border.all(color: Theme.of(context).colorScheme.outline),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      children: [
        Icon(
          Icons.cloud_off_outlined,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          size: 28,
        ),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: retry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Tekrar dene'),
        ),
      ],
    ),
  );
}

List<Widget> _listingSlivers(
  BuildContext context,
  MarketplaceBrowseController browse, {
  required ValueChanged<String> onOpen,
  required String empty,
  VoidCallback? onEmptyAction,
}) => [
  if (browse.loading)
    const SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.all(50),
        child: Center(child: CircularProgressIndicator()),
      ),
    )
  else if (browse.items.isEmpty && browse.error == null)
    SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 22, 20, 8),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            GradientOutline(
              radius: 20,
              strokeWidth: 1,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.queue_music_rounded,
                  size: 30,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              empty,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
            if (onEmptyAction != null &&
                !browse.query.hasFilters &&
                browse.query.search.isEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Yeni seslere yer aç. Ekipmanını Backstage ile buluştur.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.55,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (onEmptyAction != null)
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: GradientOutlineButton(
                  label: 'İlan ver',
                  leading: const Icon(Icons.add_rounded, size: 18),
                  onPressed: onEmptyAction,
                  horizontalPadding: 24,
                ),
              ),
          ],
        ),
      ),
    )
  else
    SliverLayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.crossAxisExtent < 370
            ? 1
            : constraints.crossAxisExtent < 720
            ? 2
            : 3;
        final rows = (browse.items.length / columns).ceil();
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.builder(
            itemCount: rows,
            itemBuilder: (context, row) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var column = 0; column < columns; column++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: row * columns + column >= browse.items.length
                            ? const SizedBox.shrink()
                            : _MarketplaceCard(
                                listing: browse.items[row * columns + column],
                                onTap: () => onOpen(
                                  browse.items[row * columns + column].id,
                                ),
                              ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  if (browse.error != null)
    SliverToBoxAdapter(
      child: _MarketplaceError(
        message: browse.error!,
        retry: browse.items.isEmpty ? browse.refresh : browse.loadMore,
      ),
    ),
  if (browse.hasNext)
    SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Center(
          child: browse.loadingMore
              ? const CircularProgressIndicator()
              : TextButton.icon(
                  onPressed: browse.loadMore,
                  icon: const Icon(Icons.expand_more_rounded),
                  label: const Text('Daha fazla ilan'),
                ),
        ),
      ),
    ),
];

class _MarketplaceCard extends StatelessWidget {
  const _MarketplaceCard({required this.listing, required this.onTap});
  final MarketplaceListing listing;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    margin: EdgeInsets.zero,
    child: InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.25,
            child: listing.photoIds.isEmpty
                ? ColoredBox(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    child: Center(
                      child: Icon(
                        Icons.music_note_outlined,
                        size: 38,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant.withValues(alpha: .45),
                      ),
                    ),
                  )
                : MarketplacePhoto(assetId: listing.photoIds.first),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.textScalerOf(context).scale(13) * 2.8,
                  ),
                  child: Text(
                    listing.displayTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _price(listing.priceMinor),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    letterSpacing: -.4,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (listing.condition != null)
                      _tag(listing.condition!.label),
                    if (listing.isOwner &&
                        listing.status != MarketplaceStatus.published)
                      _tag(listing.status.label),
                  ],
                ),
                if (listing.locationLabel.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            listing.locationLabel,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.3,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _tag(String text) => Builder(
  builder: (context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Theme.of(context).colorScheme.outline),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  ),
);

Future<String?> _pick(
  BuildContext context, {
  required String title,
  required Map<String, String> options,
  String? selected,
}) {
  if (!marketplaceCanAct(context)) return Future<String?>.value();
  final entry = marketplaceSessionFor(context);
  return showLocationPickerSheet(
    context,
    title: title,
    options: options,
    selected: selected,
    routeWrapper: (child) =>
        MarketplaceAccessGate(expectedSession: entry, builder: (_) => child),
  );
}

Widget _selectField({
  required String label,
  required String? value,
  required VoidCallback? onTap,
  String? error,
  bool loading = false,
}) => Padding(
  padding: const EdgeInsets.only(bottom: 14),
  child: InkWell(
    borderRadius: BorderRadius.circular(16),
    onTap: onTap,
    child: InputDecorator(
      decoration: _decoration(
        label,
      ).copyWith(errorText: error, enabled: onTap != null),
      child: Row(
        children: [
          Expanded(
            child: Builder(
              builder: (context) => Text(
                value ?? 'Seç',
                style: TextStyle(
                  fontSize: 14,
                  color: value == null
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
          loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.keyboard_arrow_down_rounded),
        ],
      ),
    ),
  ),
);

class _MarketplaceFilters extends StatefulWidget {
  const _MarketplaceFilters({
    required this.query,
    required this.categories,
    required this.cities,
    required this.locationRepository,
  });
  final MarketplaceQuery query;
  final List<MarketplaceCategory> categories;
  final List<City> cities;
  final LocationRepository locationRepository;
  @override
  State<_MarketplaceFilters> createState() => _MarketplaceFiltersState();
}

class _MarketplaceFiltersState extends State<_MarketplaceFilters> {
  late String? _categoryId = widget.query.categoryId,
      _cityId = widget.query.cityId,
      _districtId = widget.query.districtId;
  List<District> _districts = const [];
  bool _districtLoading = false;
  String? _districtError;
  int _districtEpoch = 0;
  @override
  void initState() {
    super.initState();
    if (_cityId != null) unawaited(_loadDistricts(_cityId!));
  }

  Future<void> _loadDistricts(String cityId) async {
    if (!marketplaceCanAct(context)) return;
    final epoch = ++_districtEpoch;
    setState(() {
      _districtLoading = true;
      _districtError = null;
      _districts = const [];
    });
    final result = await widget.locationRepository.getDistricts(cityId);
    if (!mounted ||
        !marketplaceCanAct(context) ||
        epoch != _districtEpoch ||
        cityId != _cityId) {
      return;
    }
    setState(() {
      _districtLoading = false;
      _districts = result.data ?? const [];
      _districtError = result.error?.message;
    });
  }

  Future<void> _district() async {
    if (!marketplaceCanAct(context)) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final id = await _pick(
      context,
      title: 'İlçe',
      options: {
        '': 'Tüm ilçeler',
        for (final district in _districts) district.id: district.name,
      },
      selected: _districtId ?? '',
    );
    if (mounted && marketplaceCanAct(context) && id != null) {
      setState(() => _districtId = id.isEmpty ? null : id);
    }
  }

  late MarketplaceCondition? _condition = widget.query.condition;
  late MarketplaceSort _sort = widget.query.sort;
  late final _minimum = TextEditingController(
    text: marketplacePriceInput(widget.query.minPriceMinor),
  );
  late final _maximum = TextEditingController(
    text: marketplacePriceInput(widget.query.maxPriceMinor),
  );
  String? _error;
  @override
  void dispose() {
    _minimum.dispose();
    _maximum.dispose();
    super.dispose();
  }

  Future<void> _category() async {
    if (!marketplaceCanAct(context)) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final id = await showMarketplaceCategoryPicker(
      context,
      categories: widget.categories,
      selectedId: _categoryId,
    );
    if (mounted && marketplaceCanAct(context) && id != null) {
      setState(() => _categoryId = id.isEmpty ? null : id);
    }
  }

  Future<void> _city() async {
    if (!marketplaceCanAct(context)) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final id = await _pick(
      context,
      title: 'İl',
      options: {
        '': 'Tüm iller',
        for (final city in widget.cities) city.id: city.name,
      },
      selected: _cityId ?? '',
    );
    if (!mounted || !marketplaceCanAct(context) || id == null) return;
    final next = id.isEmpty ? null : id;
    if (next == _cityId) return;
    _districtEpoch++;
    setState(() {
      _cityId = next;
      _districtId = null;
      _districts = const [];
      _districtLoading = false;
      _districtError = null;
    });
    if (next != null) await _loadDistricts(next);
  }

  void _apply() {
    if (!marketplaceCanAct(context)) return;
    final minimum = _minimum.text.trim().isEmpty
        ? null
        : parseMarketplacePriceMinor(_minimum.text);
    final maximum = _maximum.text.trim().isEmpty
        ? null
        : parseMarketplacePriceMinor(_maximum.text);
    if ((_minimum.text.trim().isNotEmpty && minimum == null) ||
        (_maximum.text.trim().isNotEmpty && maximum == null) ||
        (minimum != null && maximum != null && minimum > maximum)) {
      setState(() => _error = 'Geçerli bir fiyat aralığı gir.');
      return;
    }
    _popMarketplaceRoute(
      context,
      MarketplaceQuery(
        search: widget.query.search,
        categoryId: _categoryId,
        cityId: _cityId,
        districtId: _districtId,
        condition: _condition,
        minPriceMinor: minimum,
        maxPriceMinor: maximum,
        sort: _sort,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .8,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 2, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Filtrele ve sırala',
              style: const TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w800,
                letterSpacing: -.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Aradığın ekipmanı daralt.',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            _selectField(
              label: 'Kategori',
              value:
                  marketplaceCategoryLabel(widget.categories, _categoryId) ??
                  'Tüm kategoriler',
              onTap: _category,
            ),
            _selectField(
              label: 'İl',
              value: _cityId == null
                  ? 'Tüm iller'
                  : widget.cities
                        .where((city) => city.id == _cityId)
                        .firstOrNull
                        ?.name,
              onTap: _city,
            ),
            if (_cityId != null)
              _selectField(
                label: 'İlçe',
                value: _districtId == null
                    ? 'Tüm ilçeler'
                    : _districts
                          .where((district) => district.id == _districtId)
                          .firstOrNull
                          ?.name,
                loading: _districtLoading,
                onTap: _districtLoading || _districtError != null
                    ? null
                    : _district,
              ),
            if (_districtError != null)
              _MarketplaceError(
                message: _districtError!,
                retry: () => _loadDistricts(_cityId!),
              ),
            const Text(
              'Ürün durumu',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ChoiceChip(
                  label: const Text('Tümü'),
                  selected: _condition == null,
                  onSelected: (_) => setState(() => _condition = null),
                ),
                for (final condition in MarketplaceCondition.values)
                  ChoiceChip(
                    label: Text(condition.label),
                    selected: _condition == condition,
                    onSelected: (_) => setState(() => _condition = condition),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minimum,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: _decoration('En az ₺'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _maximum,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: _decoration('En çok ₺'),
                  ),
                ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 20),
            const Divider(height: 20),
            const Text(
              'Sıralama',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            for (final sort in MarketplaceSort.values)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                selected: _sort == sort,
                selectedTileColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHigh,
                selectedColor: Theme.of(context).colorScheme.onSurface,
                title: Text(sort.label, style: const TextStyle(fontSize: 14)),
                leading: Icon(
                  _sort == sort
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  size: 21,
                  color: _sort == sort
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                onTap: () => setState(() => _sort = sort),
              ),
            const SizedBox(height: 18),
            GradientOutlineButton(label: 'Sonuçları göster', onPressed: _apply),
          ],
        ),
      ),
    ),
  );
}
