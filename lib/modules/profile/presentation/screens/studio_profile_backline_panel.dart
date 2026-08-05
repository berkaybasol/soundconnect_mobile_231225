part of 'studio_profile_screen.dart';

class _StudioBacklinePanel extends StatefulWidget {
  final String profileId;
  final bool ownerMode;
  final String? phone;
  final int contentRevision;
  final VoidCallback? onMessage;

  const _StudioBacklinePanel({
    required this.profileId,
    required this.ownerMode,
    required this.phone,
    required this.contentRevision,
    required this.onMessage,
  });

  @override
  State<_StudioBacklinePanel> createState() => _StudioBacklinePanelState();
}

class _StudioBacklinePanelState extends State<_StudioBacklinePanel> {
  static const _pageSize = 20;
  late final StudioEquipmentRepository _repository;
  late final BacklineCatalogRepository _catalogRepository;
  List<_BacklineItem> _items = const [];
  List<_BacklineCategory> _categories = const [];
  String _selectedFilter = 'Tümü';
  String _searchQuery = '';
  int _pageIndex = 0;
  int _totalItems = 0;
  int _totalPages = 0;
  int _loadGeneration = 0;
  int _searchGeneration = 0;
  bool _isLoading = true;
  bool _isCatalogLoading = true;
  String? _error;
  String? _catalogError;

  @override
  void initState() {
    super.initState();
    _repository = serviceLocator<StudioEquipmentRepository>();
    _catalogRepository = serviceLocator<BacklineCatalogRepository>();
    _loadCatalog();
    _loadPage(0);
  }

  @override
  void didUpdateWidget(covariant _StudioBacklinePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profileId != widget.profileId ||
        oldWidget.ownerMode != widget.ownerMode ||
        oldWidget.contentRevision != widget.contentRevision) {
      _loadPage(oldWidget.profileId == widget.profileId ? _pageIndex : 0);
    }
  }

  int get _pageTotal => _items.fold(0, (sum, item) => sum + item.total);
  int get _pageAvailable => _items.fold(0, (sum, item) => sum + item.available);
  int get _pageMaintenance =>
      _items.fold(0, (sum, item) => sum + item.maintenance);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: _StudioPanel(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  'Backline Envanteri',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  'Stüdyo içi ve kiralanabilir ekipmanlar',
                  style: TextStyle(color: Color(0xFF9AA4B2), fontSize: 12),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _BacklineSummary(
                      icon: Icons.inventory_2_outlined,
                      value: _pageTotal.toString(),
                      label: 'Bu Sayfa',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _BacklineSummary(
                      icon: Icons.check_circle_outline,
                      value: _pageAvailable.toString(),
                      label: 'Müsait',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _BacklineSummary(
                      icon: Icons.build_outlined,
                      value: _pageMaintenance.toString(),
                      label: 'Bakımda',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _BacklineFilters(
                selectedFilter: _selectedFilter,
                onChanged: (value) {
                  if (value == _selectedFilter) return;
                  if (value != 'Tümü' && _categories.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          _catalogError ??
                              (_isCatalogLoading
                                  ? 'Kategoriler yükleniyor.'
                                  : 'Kategori filtresi kullanılamıyor.'),
                        ),
                      ),
                    );
                    return;
                  }
                  setState(() => _selectedFilter = value);
                  _loadPage(0);
                },
              ),
              const SizedBox(height: 10),
              _BacklineSearch(onChanged: _onSearchChanged),
              const SizedBox(height: 10),
              if (_isLoading && _items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null && _items.isEmpty)
                _StudioOwnerBacklineErrorState(
                  message: _error!,
                  onRetry: () => _loadPage(_pageIndex),
                )
              else if (_items.isEmpty)
                const _BacklineSearchEmptyState()
              else
                ..._items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _BacklineItemCard(
                      item: item,
                      ownerMode: widget.ownerMode,
                      phone: widget.phone,
                      onMessage: widget.onMessage,
                      onReturn: widget.ownerMode
                          ? () => _loadPage(_pageIndex)
                          : null,
                    ),
                  ),
                ),
              if (_isLoading && _items.isNotEmpty)
                const LinearProgressIndicator(minHeight: 2),
              if (_totalPages > 1) ...[
                const SizedBox(height: 8),
                _StudioOwnerBacklinePagination(
                  pageIndex: _pageIndex,
                  totalPages: _totalPages,
                  enabled: !_isLoading,
                  onPrevious: _pageIndex > 0
                      ? () => _loadPage(_pageIndex - 1)
                      : null,
                  onNext: _pageIndex + 1 < _totalPages
                      ? () => _loadPage(_pageIndex + 1)
                      : null,
                ),
              ],
              if (_totalItems > 0) ...[
                const SizedBox(height: 6),
                Text(
                  'Toplam $_totalItems ekipman kaydı',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF7F8998),
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _onSearchChanged(String value) {
    _searchQuery = value;
    final generation = ++_searchGeneration;
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      if (!mounted || generation != _searchGeneration) return;
      _loadPage(0);
    });
  }

  Future<void> _loadCatalog() async {
    final result = await _loadCompleteBacklineCatalog(_catalogRepository);
    if (!mounted) return;
    if (result.$1 == null) {
      setState(() {
        _isCatalogLoading = false;
        _catalogError = result.$2 ?? 'Kategoriler yüklenemedi.';
      });
      return;
    }
    setState(() {
      _categories = result.$1!;
      _isCatalogLoading = false;
      _catalogError = null;
    });
    if (_selectedFilter != 'Tümü') await _loadPage(0);
  }

  Future<void> _loadPage(int page) async {
    final generation = ++_loadGeneration;
    setState(() {
      _isLoading = true;
      _error = null;
      _items = const [];
    });
    final selectedCategoryId = _selectedCategoryId;
    final result = widget.ownerMode
        ? await _repository.listOwnerEquipment(
            query: _searchQuery,
            categoryId: selectedCategoryId,
            page: page,
            size: _pageSize,
          )
        : await _repository.listPublicEquipment(
            studioProfileId: widget.profileId,
            query: _searchQuery,
            categoryId: selectedCategoryId,
            page: page,
            size: _pageSize,
          );
    if (!mounted || generation != _loadGeneration) return;
    if (!result.isSuccess || result.data == null) {
      setState(() {
        _isLoading = false;
        _error = result.error?.message ?? 'Backline envanteri yüklenemedi.';
      });
      return;
    }
    setState(() {
      _items = result.data!.items
          .map(
            (equipment) => _BacklineItem.fromDomain(
              equipment,
              studioProfileId: widget.profileId,
            ),
          )
          .toList(growable: false);
      _pageIndex = result.data!.pageIndex;
      _totalItems = result.data!.totalItems;
      _totalPages = result.data!.totalPages;
      _isLoading = false;
      _error = null;
    });
  }

  String? get _selectedCategoryId {
    if (_selectedFilter == 'Tümü') return null;
    final selectedName = switch (_selectedFilter) {
      'Bas Amfileri' => 'Bas Gitar Amfileri',
      'Piyano & Klavye' => 'Piyano, Klavye & Synth',
      _ => _selectedFilter,
    };
    for (final category in _categories) {
      if (category.name == selectedName) return category.id;
      for (final child in category.children) {
        if (child == selectedName) return category.childId(child);
      }
    }
    return null;
  }
}

class _StudioPanel extends StatelessWidget {
  final Widget child;

  const _StudioPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B111B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1E2836)),
      ),
      child: child,
    );
  }
}

class _BacklineSummary extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _BacklineSummary({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFF101722),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF202B3A)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StudioSocialGradientIcon(icon, size: 15),
              const SizedBox(width: 6),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF9AA4B2), fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _BacklineFilters extends StatelessWidget {
  final String selectedFilter;
  final ValueChanged<String> onChanged;

  const _BacklineFilters({
    required this.selectedFilter,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const filters = _backlineQuickFilters;
    final hasCustomSelection = !filters.contains(selectedFilter);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < filters.length; i++) ...[
            _BacklineFilterChip(
              label: filters[i],
              selected: selectedFilter == filters[i],
              onTap: () => onChanged(filters[i]),
            ),
            const SizedBox(width: 8),
          ],
          _BacklineFilterChip(
            label: hasCustomSelection ? selectedFilter : 'Tüm Kategoriler',
            selected: hasCustomSelection,
            trailingIcon: Icons.chevron_right,
            onTap: () async {
              final selected = await Navigator.of(context).push<String>(
                MaterialPageRoute(
                  builder: (_) => const _BacklineCategoriesScreen(),
                ),
              );
              if (selected == null) return;
              onChanged(selected);
            },
          ),
        ],
      ),
    );
  }
}

class _BacklineFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final IconData? trailingIcon;
  final VoidCallback onTap;

  const _BacklineFilterChip({
    required this.label,
    required this.selected,
    this.trailingIcon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(8);
    return InkWell(
      borderRadius: radius,
      onTap: onTap,
      child: Container(
        height: 34,
        padding: const EdgeInsets.all(0.8),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [Color(0xFFFF7A45), Color(0xFF8B2CFF)],
                )
              : null,
          borderRadius: radius,
          border: selected ? null : Border.all(color: const Color(0xFF263244)),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF101722),
            borderRadius: BorderRadius.circular(7.2),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? const Color(0xFFFF8A8A)
                      : const Color(0xFFB5BDCA),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (trailingIcon != null) ...[
                const SizedBox(width: 4),
                Icon(trailingIcon, color: const Color(0xFFB5BDCA), size: 15),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BacklineSearch extends StatelessWidget {
  final ValueChanged<String> onChanged;

  const _BacklineSearch({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: TextField(
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: const InputDecoration(
          hintText: 'Ekipman ara...',
          prefixIcon: Icon(Icons.search, size: 18),
          contentPadding: EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }
}

class _BacklineSearchEmptyState extends StatelessWidget {
  const _BacklineSearchEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      decoration: BoxDecoration(
        color: const Color(0xFF101722),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF202B3A)),
      ),
      child: const Column(
        children: [
          Icon(Icons.search_off_rounded, color: Color(0xFF8C95A3), size: 28),
          SizedBox(height: 8),
          Text(
            'Eşleşen ekipman bulunamadı.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFB5BDCA),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _BacklineItem {
  final String id;
  final String studioProfileId;
  final String title;
  final String type;
  final String subcategory;
  final String model;
  final String description;
  final List<String> features;
  final List<String> photoUrls;
  final String status;
  final Color statusColor;
  final IconData icon;
  final int total;
  final int available;
  final int busy;
  final int maintenance;
  final DateTime referenceDate;

  const _BacklineItem({
    required this.id,
    required this.studioProfileId,
    required this.title,
    required this.type,
    required this.subcategory,
    required this.model,
    required this.description,
    required this.features,
    required this.photoUrls,
    required this.status,
    required this.statusColor,
    required this.icon,
    required this.total,
    required this.available,
    required this.busy,
    required this.maintenance,
    required this.referenceDate,
  });

  factory _BacklineItem.fromDomain(
    StudioEquipment equipment, {
    required String studioProfileId,
  }) {
    final availability = equipment.todayAvailability;
    final status = switch (availability.status) {
      StudioEquipmentAvailabilityStatus.available => 'Müsait',
      StudioEquipmentAvailabilityStatus.partiallyAvailable => 'Kısmen Müsait',
      StudioEquipmentAvailabilityStatus.busy => 'Dolu',
      StudioEquipmentAvailabilityStatus.maintenance => 'Bakımda',
      StudioEquipmentAvailabilityStatus.mixedUnavailable => 'Müsait Değil',
      StudioEquipmentAvailabilityStatus.unknown =>
        availability.availableQuantity > 0 ? 'Kısmen Müsait' : 'Müsait Değil',
    };
    final brand = equipment.brand?.trim() ?? '';
    final model = equipment.model?.trim() ?? '';
    return _BacklineItem(
      id: equipment.id,
      studioProfileId: studioProfileId,
      title: equipment.name,
      type: equipment.categoryName,
      subcategory: equipment.subcategoryName,
      model: [
        if (brand.isNotEmpty) brand,
        if (model.isNotEmpty) model,
      ].join(' • '),
      description: equipment.description?.trim() ?? '',
      features: equipment.features,
      photoUrls: equipment.photos.map((photo) => photo.url).toList(),
      status: status,
      statusColor: _availabilityColor(
        availability.availableQuantity,
        availability.totalQuantity,
        maintenanceCount: availability.maintenanceQuantity,
      ),
      icon: _backlineIconFor(
        code: equipment.categoryCode,
        iconKey: equipment.categoryIconKey,
        name: equipment.categoryName,
      ),
      total: availability.totalQuantity,
      available: availability.availableQuantity,
      busy: availability.busyQuantity,
      maintenance: availability.maintenanceQuantity,
      referenceDate: availability.date,
    );
  }
}

class _BacklineItemCard extends StatelessWidget {
  final _BacklineItem item;
  final bool ownerMode;
  final String? phone;
  final VoidCallback? onMessage;
  final VoidCallback? onReturn;

  const _BacklineItemCard({
    required this.item,
    required this.ownerMode,
    required this.phone,
    required this.onMessage,
    required this.onReturn,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => _BacklineItemDetailScreen(
              item: item,
              ownerMode: ownerMode,
              phone: phone,
              onMessage: onMessage,
            ),
          ),
        );
        onReturn?.call();
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF101722),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF202B3A)),
        ),
        child: Row(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF080D15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF263244)),
              ),
              clipBehavior: Clip.antiAlias,
              child: item.photoUrls.isNotEmpty
                  ? AppCachedNetworkImage(
                      imageUrl: item.photoUrls.first,
                      fit: BoxFit.cover,
                      cacheWidth: 216,
                      cacheHeight: 216,
                      errorBuilder: (_) => Icon(
                        item.icon,
                        color: const Color(0xFFD4D9E2),
                        size: 34,
                      ),
                    )
                  : Icon(item.icon, color: const Color(0xFFD4D9E2), size: 34),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _BacklineStatus(
                        label: item.status,
                        color: item.statusColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.type,
                    style: const TextStyle(
                      color: Color(0xFFB7C0CE),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _MiniMeta(label: 'Toplam', value: item.total.toString()),
                      const SizedBox(width: 6),
                      _MiniMeta(
                        label: 'Müsait',
                        value: item.available.toString(),
                        dotColor: const Color(0xFF15C46B),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: const [
                      _TinyButton(icon: Icons.info_outline, label: 'Detay'),
                      SizedBox(width: 8),
                      _TinyButton(
                        icon: Icons.calendar_month_outlined,
                        label: 'Takvimi Gör',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: Color(0xFF7B8493), size: 20),
          ],
        ),
      ),
    );
  }
}
