part of 'studio_profile_screen.dart';

const _ownerManagementCardColor = Color(0xFF101722);
const _ownerManagementCardBorderColor = Color(0xFF202B3A);
const _ownerManagementInsetColor = Color(0xFF0A101A);
const _ownerManagementInsetBorderColor = Color(0xFF263244);
const _maximumBacklineEquipmentPhotoCount = 5;

enum _BacklineInventoryStatusFilter { all, available, busy, maintenance }

class _StudioBacklineInventoryItem {
  final String id;
  final String categoryId;
  final String subcategoryId;
  final String categoryCode;
  final String subcategoryCode;
  final String categoryIconKey;
  final String name;
  final String category;
  final String subcategory;
  final String brand;
  final String modelName;
  final String model;
  final String description;
  final List<String> features;
  final List<String> photoUrls;
  final List<String> photoMediaIds;
  final IconData icon;
  final int total;
  final int available;
  final int reserved;
  final int maintenance;
  final int version;
  final DateTime? todayLocalDate;

  const _StudioBacklineInventoryItem({
    this.id = '',
    this.categoryId = '',
    this.subcategoryId = '',
    this.categoryCode = '',
    this.subcategoryCode = '',
    this.categoryIconKey = '',
    required this.name,
    required this.category,
    this.subcategory = '',
    this.brand = '',
    this.modelName = '',
    required this.model,
    this.description = '',
    this.features = const [],
    this.photoUrls = const [],
    this.photoMediaIds = const [],
    required this.icon,
    required this.total,
    required this.available,
    required this.reserved,
    required this.maintenance,
    this.version = 0,
    this.todayLocalDate,
  });

  factory _StudioBacklineInventoryItem.fromDomain(StudioEquipment equipment) {
    final brand = equipment.brand?.trim() ?? '';
    final modelName = equipment.model?.trim() ?? '';
    final model = [
      if (brand.isNotEmpty) brand,
      if (modelName.isNotEmpty) modelName,
    ].join(' • ');
    return _StudioBacklineInventoryItem(
      id: equipment.id,
      categoryId: equipment.categoryId,
      subcategoryId: equipment.subcategoryId,
      categoryCode: equipment.categoryCode,
      subcategoryCode: equipment.subcategoryCode,
      categoryIconKey: equipment.categoryIconKey,
      name: equipment.name,
      category: equipment.categoryName,
      subcategory: equipment.subcategoryName,
      brand: brand,
      modelName: modelName,
      model: model.isEmpty ? 'Marka/model belirtilmedi' : model,
      description: equipment.description ?? '',
      features: equipment.features,
      photoUrls: equipment.photos.map((photo) => photo.url).toList(),
      photoMediaIds: equipment.photos
          .map((photo) => photo.mediaAssetId)
          .whereType<String>()
          .toList(),
      icon: _backlineIconFor(
        code: equipment.categoryCode,
        iconKey: equipment.categoryIconKey,
        name: equipment.categoryName,
      ),
      total: equipment.totalQuantity,
      available: equipment.todayAvailability.availableQuantity,
      reserved: equipment.todayAvailability.busyQuantity,
      maintenance: equipment.todayAvailability.maintenanceQuantity,
      version: equipment.version ?? 0,
      todayLocalDate: equipment.todayAvailability.date,
    );
  }

  _StudioBacklineInventoryItem copyWith({
    String? id,
    String? categoryId,
    String? subcategoryId,
    String? categoryCode,
    String? subcategoryCode,
    String? categoryIconKey,
    String? name,
    String? category,
    String? subcategory,
    String? brand,
    String? modelName,
    String? model,
    String? description,
    List<String>? features,
    List<String>? photoUrls,
    List<String>? photoMediaIds,
    IconData? icon,
    int? total,
    int? available,
    int? reserved,
    int? maintenance,
    int? version,
    DateTime? todayLocalDate,
  }) {
    return _StudioBacklineInventoryItem(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      subcategoryId: subcategoryId ?? this.subcategoryId,
      categoryCode: categoryCode ?? this.categoryCode,
      subcategoryCode: subcategoryCode ?? this.subcategoryCode,
      categoryIconKey: categoryIconKey ?? this.categoryIconKey,
      name: name ?? this.name,
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
      brand: brand ?? this.brand,
      modelName: modelName ?? this.modelName,
      model: model ?? this.model,
      description: description ?? this.description,
      features: features ?? this.features,
      photoUrls: photoUrls ?? this.photoUrls,
      photoMediaIds: photoMediaIds ?? this.photoMediaIds,
      icon: icon ?? this.icon,
      total: total ?? this.total,
      available: available ?? this.available,
      reserved: reserved ?? this.reserved,
      maintenance: maintenance ?? this.maintenance,
      version: version ?? this.version,
      todayLocalDate: todayLocalDate ?? this.todayLocalDate,
    );
  }
}

class _StudioBacklineInventoryScreen extends StatefulWidget {
  final String studioProfileId;

  const _StudioBacklineInventoryScreen({required this.studioProfileId});

  @override
  State<_StudioBacklineInventoryScreen> createState() =>
      _StudioBacklineInventoryScreenState();
}

class _StudioBacklineInventoryScreenState
    extends State<_StudioBacklineInventoryScreen> {
  static const _allCategoriesFilterValue = '__all_categories__';
  static const _pageSize = 20;
  late final StudioEquipmentRepository _equipmentRepository;
  late final BacklineCatalogRepository _catalogRepository;

  List<_StudioBacklineInventoryItem> _items = const [];
  List<_BacklineCategory> _categories = const [];
  StudioEquipmentInventorySummary? _summary;
  int _pageIndex = 0;
  int _totalItems = 0;
  int _totalPages = 0;
  bool _isLoading = true;
  bool _isCatalogLoading = true;
  String? _loadError;
  String? _catalogError;
  String? _summaryError;
  int _searchGeneration = 0;
  int _loadGeneration = 0;
  int _catalogLoadGeneration = 0;

  String _searchQuery = '';
  String? _selectedCategoryId;
  String? _selectedCategoryLabel;
  _BacklineInventoryStatusFilter _statusFilter =
      _BacklineInventoryStatusFilter.all;

  @override
  void initState() {
    super.initState();
    _equipmentRepository = serviceLocator<StudioEquipmentRepository>();
    _catalogRepository = serviceLocator<BacklineCatalogRepository>();
    _loadInitialData();
  }

  int get _totalCount => _summary?.totalQuantity ?? 0;
  int get _availableCount => _summary?.availableQuantity ?? 0;
  int get _busyCount => _summary?.busyQuantity ?? 0;
  int get _maintenanceCount => _summary?.maintenanceQuantity ?? 0;
  List<_BacklineCategory> get _assignableCategories => _categories
      .where((category) => category.children.isNotEmpty)
      .toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      appBar: AppBar(title: const Text('Envanter Yönetimi'), centerTitle: true),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshInventory,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            children: [
              const Text(
                'Envanter Özeti',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Ekipman adetlerini ve mevcut durumlarını tek yerden takip et.',
                style: TextStyle(color: Color(0xFF969FAA), fontSize: 12),
              ),
              const SizedBox(height: 14),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.15,
                children: [
                  _BacklineInventorySummaryCard(
                    label: 'Toplam',
                    value: _totalCount,
                    icon: Icons.inventory_2_outlined,
                  ),
                  _BacklineInventorySummaryCard(
                    label: 'Müsait',
                    value: _availableCount,
                    icon: Icons.check_circle_outline_rounded,
                    accent: const Color(0xFF62C98B),
                  ),
                  _BacklineInventorySummaryCard(
                    label: 'Dolu',
                    value: _busyCount,
                    icon: Icons.event_busy_outlined,
                    accent: const Color(0xFFF0C75E),
                  ),
                  _BacklineInventorySummaryCard(
                    label: 'Bakımda',
                    value: _maintenanceCount,
                    icon: Icons.build_outlined,
                    accent: const Color(0xFFE47B86),
                  ),
                ],
              ),
              if (_summaryError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _summaryError!,
                  style: const TextStyle(
                    color: Color(0xFFE47B86),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              _StudioActionButton(
                icon: Icons.add_business_outlined,
                label: _isCatalogLoading
                    ? 'Kategoriler Yükleniyor...'
                    : 'Yeni Ekipman Ekle',
                outlined: true,
                onTap: _isCatalogLoading || _assignableCategories.isEmpty
                    ? () => _showMessage(
                        _catalogError ?? 'Kategori listesi henüz hazır değil.',
                      )
                    : _showAddEquipmentInfo,
              ),
              const SizedBox(height: 18),
              TextField(
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Ekipman, marka veya kategori ara...',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _BacklineInventoryFilterButton(
                      icon: Icons.category_outlined,
                      label: _selectedCategoryLabel ?? 'Tüm Kategoriler',
                      active: _selectedCategoryId != null,
                      onTap: _selectCategory,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _BacklineInventoryFilterButton(
                      icon: Icons.tune_rounded,
                      label: _statusFilterLabel(_statusFilter),
                      active:
                          _statusFilter != _BacklineInventoryStatusFilter.all,
                      onTap: _selectStatus,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Ekipmanlar',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    '$_totalItems kayıt',
                    style: const TextStyle(
                      color: Color(0xFF9099A7),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_isLoading && items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 42),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_loadError != null && items.isEmpty)
                _StudioOwnerBacklineErrorState(
                  message: _loadError!,
                  onRetry: () => _loadPage(_pageIndex),
                )
              else if (items.isEmpty)
                const _BacklineInventoryEmptyState()
              else
                for (final item in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _BacklineInventoryManagementCard(
                      key: ObjectKey(item),
                      item: item,
                      onManage: () => _manageEquipment(item),
                    ),
                  ),
              if (_isLoading && items.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
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
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadInitialData() async {
    await Future.wait<void>([_loadCatalog(), _loadPage(0), _loadSummary()]);
  }

  Future<void> _refreshInventory() async {
    await Future.wait<void>([
      _loadPage(_pageIndex, preserveItems: true),
      _loadSummary(),
    ]);
  }

  Future<void> _loadSummary() async {
    final result = await _equipmentRepository.getOwnerInventorySummary();
    if (!mounted) return;
    if (!result.isSuccess || result.data == null) {
      setState(() {
        _summaryError =
            result.error?.message ?? 'Envanter özeti yüklenemedi.';
      });
      return;
    }
    setState(() {
      _summary = result.data;
      _summaryError = null;
    });
  }

  Future<void> _loadCatalog() async {
    final generation = ++_catalogLoadGeneration;
    if (mounted) {
      setState(() {
        _isCatalogLoading = true;
        _catalogError = null;
      });
    }
    final result = await _loadCompleteBacklineCatalog(_catalogRepository);
    if (!mounted || generation != _catalogLoadGeneration) return;
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
  }

  Future<void> _loadPage(int page, {bool preserveItems = false}) async {
    final generation = ++_loadGeneration;
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
        if (!preserveItems) _items = const [];
      });
    }
    final result = await _equipmentRepository.listOwnerEquipment(
      query: _searchQuery,
      categoryId: _selectedCategoryId,
      availabilityBucket: _availabilityBucketForFilter(_statusFilter),
      page: page,
      size: _pageSize,
    );
    if (!mounted || generation != _loadGeneration) return;
    if (!result.isSuccess || result.data == null) {
      setState(() {
        _isLoading = false;
        _loadError = result.error?.message ?? 'Ekipmanlar yüklenemedi.';
      });
      return;
    }
    final response = result.data!;
    setState(() {
      _items = response.items
          .map(_StudioBacklineInventoryItem.fromDomain)
          .toList(growable: false);
      _pageIndex = response.pageIndex;
      _totalItems = response.totalItems;
      _totalPages = response.totalPages;
      _isLoading = false;
      _loadError = null;
    });
  }

  void _onSearchChanged(String value) {
    _searchQuery = value;
    final generation = ++_searchGeneration;
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      if (!mounted || generation != _searchGeneration) return;
      _loadPage(0);
    });
  }

  StudioEquipmentAvailabilityBucket? _availabilityBucketForFilter(
    _BacklineInventoryStatusFilter filter,
  ) => switch (filter) {
    _BacklineInventoryStatusFilter.all => null,
    _BacklineInventoryStatusFilter.available =>
      StudioEquipmentAvailabilityBucket.available,
    _BacklineInventoryStatusFilter.busy =>
      StudioEquipmentAvailabilityBucket.busy,
    _BacklineInventoryStatusFilter.maintenance =>
      StudioEquipmentAvailabilityBucket.maintenance,
  };

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _selectCategory() async {
    final selected = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => const _BacklineCategoriesScreen(
          allSelectionValue: _allCategoriesFilterValue,
        ),
      ),
    );
    if (!mounted || selected == null) return;
    String? categoryId;
    String? categoryLabel;
    if (selected != _allCategoriesFilterValue) {
      for (final category in _categories) {
        if (category.name == selected) {
          categoryId = category.id;
          categoryLabel = category.name;
          break;
        }
        for (final child in category.children) {
          if (child == selected) {
            categoryId = category.childId(child);
            categoryLabel = child;
            break;
          }
        }
        if (categoryId != null) break;
      }
    }
    if (categoryId == _selectedCategoryId) return;
    setState(() {
      _selectedCategoryId = categoryId;
      _selectedCategoryLabel = categoryLabel;
    });
    await _loadPage(0);
  }

  Future<void> _selectStatus() async {
    final selected =
        await _showInventoryFilterSheet<_BacklineInventoryStatusFilter>(
          title: 'Durum Seç',
          currentValue: _statusFilter,
          options: [
            for (final status in _BacklineInventoryStatusFilter.values)
              _BacklineInventoryFilterOption(
                value: status,
                label: _statusFilterLabel(status),
              ),
          ],
        );
    if (!mounted || selected == null || selected == _statusFilter) return;
    setState(() => _statusFilter = selected);
    await _loadPage(0);
  }

  Future<T?> _showInventoryFilterSheet<T>({
    required String title,
    required T currentValue,
    required List<_BacklineInventoryFilterOption<T>> options,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: const Color(0xFF0B1321),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              for (final option in options)
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: Icon(
                    option.value == currentValue
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: option.value == currentValue
                        ? Colors.white
                        : const Color(0xFF737A86),
                  ),
                  title: Text(option.label),
                  onTap: () => Navigator.of(sheetContext).pop(option.value),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAddEquipmentInfo() async {
    final item = await showModalBottomSheet<_StudioBacklineInventoryItem>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NewBacklineInventoryItemSheet(
        studioProfileId: widget.studioProfileId,
        repository: _equipmentRepository,
        categories: _assignableCategories,
      ),
    );
    if (!mounted || item == null) return;
    await Future.wait<void>([
      _loadPage(0, preserveItems: true),
      _loadSummary(),
    ]);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${item.name} envantere eklendi.')));
  }

  Future<void> _manageEquipment(_StudioBacklineInventoryItem item) async {
    final result = await Navigator.of(context)
        .push<_BacklineInventoryItemManagementResult>(
          MaterialPageRoute<_BacklineInventoryItemManagementResult>(
            builder: (_) => _BacklineInventoryItemManagementScreen(
              item: item,
              studioProfileId: widget.studioProfileId,
              repository: _equipmentRepository,
              categories: _assignableCategories,
            ),
          ),
        );
    if (!mounted || result == null) return;
    if (result.deleted) {
      final targetPage = _items.length == 1 && _pageIndex > 0
          ? _pageIndex - 1
          : _pageIndex;
      await Future.wait<void>([
        _loadPage(targetPage, preserveItems: true),
        _loadSummary(),
      ]);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item.name} envanterden kaldırıldı.')),
      );
      return;
    }
    final updatedItem = result.updatedItem;
    if (updatedItem == null) return;
    await Future.wait<void>([
      _loadPage(_pageIndex, preserveItems: true),
      _loadSummary(),
    ]);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${updatedItem.name} güncellendi.')));
  }

  static String _statusFilterLabel(_BacklineInventoryStatusFilter status) {
    return switch (status) {
      _BacklineInventoryStatusFilter.all => 'Tüm Durumlar',
      _BacklineInventoryStatusFilter.available => 'Müsait',
      _BacklineInventoryStatusFilter.busy => 'Dolu',
      _BacklineInventoryStatusFilter.maintenance => 'Bakımda',
    };
  }
}
