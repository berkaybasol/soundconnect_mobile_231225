part of 'studio_profile_screen.dart';

const _ownerManagementCardColor = Color(0xFF101722);
const _ownerManagementCardBorderColor = Color(0xFF202B3A);
const _ownerManagementInsetColor = Color(0xFF0A101A);
const _ownerManagementInsetBorderColor = Color(0xFF263244);
const _maximumBacklineEquipmentPhotoCount = 5;

enum _BacklineInventoryStatusFilter { all, available, busy, maintenance }

class _StudioBacklineInventoryItem {
  final String name;
  final String category;
  final String subcategory;
  final String model;
  final String description;
  final List<String> features;
  final List<String> photoUrls;
  final IconData icon;
  final int total;
  final int available;
  final int reserved;
  final int maintenance;

  const _StudioBacklineInventoryItem({
    required this.name,
    required this.category,
    this.subcategory = '',
    required this.model,
    this.description = '',
    this.features = const [],
    this.photoUrls = const [],
    required this.icon,
    required this.total,
    required this.available,
    required this.reserved,
    required this.maintenance,
  });

  _StudioBacklineInventoryItem copyWith({
    String? name,
    String? category,
    String? subcategory,
    String? model,
    String? description,
    List<String>? features,
    List<String>? photoUrls,
    IconData? icon,
    int? total,
    int? available,
    int? reserved,
    int? maintenance,
  }) {
    return _StudioBacklineInventoryItem(
      name: name ?? this.name,
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
      model: model ?? this.model,
      description: description ?? this.description,
      features: features ?? this.features,
      photoUrls: photoUrls ?? this.photoUrls,
      icon: icon ?? this.icon,
      total: total ?? this.total,
      available: available ?? this.available,
      reserved: reserved ?? this.reserved,
      maintenance: maintenance ?? this.maintenance,
    );
  }
}

const _backlineInventorySeedItems = [
  _StudioBacklineInventoryItem(
    name: 'Marshall DSL40',
    category: 'Gitar Amfileri',
    model: 'Marshall • DSL40CR',
    icon: Icons.speaker_outlined,
    total: 2,
    available: 1,
    reserved: 1,
    maintenance: 0,
  ),
  _StudioBacklineInventoryItem(
    name: 'Shure SM58',
    category: 'Pro Audio & Stüdyo',
    model: 'Shure • SM58-LCE',
    icon: Icons.mic_none_outlined,
    total: 6,
    available: 4,
    reserved: 1,
    maintenance: 1,
  ),
  _StudioBacklineInventoryItem(
    name: 'Yamaha Stage Custom',
    category: 'Davul, Bateri & Zil',
    model: 'Yamaha • Stage Custom Birch',
    icon: Icons.album_outlined,
    total: 1,
    available: 0,
    reserved: 0,
    maintenance: 1,
  ),
  _StudioBacklineInventoryItem(
    name: 'Nord Stage 3',
    category: 'Piyano, Klavye & Synth',
    model: 'Nord • Stage 3 Compact',
    icon: Icons.keyboard_outlined,
    total: 1,
    available: 1,
    reserved: 0,
    maintenance: 0,
  ),
  _StudioBacklineInventoryItem(
    name: 'Fender Hot Rod Deluxe IV',
    category: 'Gitar Amfileri',
    model: 'Fender • Hot Rod Deluxe IV',
    icon: Icons.speaker_group_outlined,
    total: 2,
    available: 0,
    reserved: 2,
    maintenance: 0,
  ),
];

final List<_StudioBacklineInventoryItem> _studioBacklineInventoryMockItems =
    List.of(_backlineInventorySeedItems);
final ValueNotifier<int> _studioBacklineInventoryRevision = ValueNotifier(0);

void _notifyStudioBacklineInventoryChanged() {
  _studioBacklineInventoryRevision.value++;
}

class _StudioBacklineInventoryScreen extends StatefulWidget {
  const _StudioBacklineInventoryScreen();

  @override
  State<_StudioBacklineInventoryScreen> createState() =>
      _StudioBacklineInventoryScreenState();
}

class _StudioBacklineInventoryScreenState
    extends State<_StudioBacklineInventoryScreen> {
  static const _allCategoriesFilterValue = '__all_categories__';
  late final List<_StudioBacklineInventoryItem> _items;

  String _searchQuery = '';
  String? _selectedCategory;
  _BacklineInventoryStatusFilter _statusFilter =
      _BacklineInventoryStatusFilter.all;

  @override
  void initState() {
    super.initState();
    _items = _studioBacklineInventoryMockItems;
  }

  List<String> get _categories =>
      _items.map((item) => item.category).toSet().toList()..sort();

  List<_StudioBacklineInventoryItem> get _filteredItems {
    final normalizedQuery = _searchQuery.trim().toLowerCase();
    return _items
        .where((item) {
          final matchesSearch =
              normalizedQuery.isEmpty ||
              item.name.toLowerCase().contains(normalizedQuery) ||
              item.model.toLowerCase().contains(normalizedQuery) ||
              item.category.toLowerCase().contains(normalizedQuery) ||
              item.subcategory.toLowerCase().contains(normalizedQuery);
          final matchesCategory =
              _selectedCategory == null || item.category == _selectedCategory;
          final matchesStatus = switch (_statusFilter) {
            _BacklineInventoryStatusFilter.all => true,
            _BacklineInventoryStatusFilter.available =>
              _mockBacklineAvailableToday(item) > 0,
            _BacklineInventoryStatusFilter.busy =>
              _mockBacklineBusyToday(item) > 0,
            _BacklineInventoryStatusFilter.maintenance =>
              _mockBacklineMaintenanceToday(item) > 0,
          };
          return matchesSearch && matchesCategory && matchesStatus;
        })
        .toList(growable: false);
  }

  int get _totalCount => _items.fold(0, (total, item) => total + item.total);
  int get _availableCount => _items.fold(
    0,
    (total, item) => total + _mockBacklineAvailableToday(item),
  );
  int get _busyCount =>
      _items.fold(0, (total, item) => total + _mockBacklineBusyToday(item));
  int get _maintenanceCount => _items.fold(
    0,
    (total, item) => total + _mockBacklineMaintenanceToday(item),
  );

  @override
  Widget build(BuildContext context) {
    final items = _filteredItems;
    return Scaffold(
      appBar: AppBar(title: const Text('Envanter Yönetimi'), centerTitle: true),
      body: SafeArea(
        child: ListView(
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
                  label: 'Toplam Ekipman',
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
            const SizedBox(height: 14),
            _StudioActionButton(
              icon: Icons.add_business_outlined,
              label: 'Yeni Ekipman Ekle',
              outlined: true,
              onTap: _showAddEquipmentInfo,
            ),
            const SizedBox(height: 18),
            TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
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
                    label: _selectedCategory ?? 'Tüm Kategoriler',
                    active: _selectedCategory != null,
                    onTap: _selectCategory,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _BacklineInventoryFilterButton(
                    icon: Icons.tune_rounded,
                    label: _statusFilterLabel(_statusFilter),
                    active: _statusFilter != _BacklineInventoryStatusFilter.all,
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
                  '${items.length} kayıt',
                  style: const TextStyle(
                    color: Color(0xFF9099A7),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (items.isEmpty)
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
          ],
        ),
      ),
    );
  }

  Future<void> _selectCategory() async {
    final selected = await _showInventoryFilterSheet<String>(
      title: 'Kategori Seç',
      currentValue: _selectedCategory ?? _allCategoriesFilterValue,
      options: [
        const _BacklineInventoryFilterOption(
          value: _allCategoriesFilterValue,
          label: 'Tüm Kategoriler',
        ),
        for (final category in _categories)
          _BacklineInventoryFilterOption(value: category, label: category),
      ],
    );
    if (!mounted || selected == null) return;
    final category = selected == _allCategoriesFilterValue ? null : selected;
    if (category == _selectedCategory) return;
    setState(() => _selectedCategory = category);
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
      builder: (_) => const _NewBacklineInventoryItemSheet(),
    );
    if (!mounted || item == null) return;
    setState(() => _items.insert(0, item));
    _notifyStudioBacklineInventoryChanged();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${item.name} envantere eklendi.')));
  }

  Future<void> _manageEquipment(_StudioBacklineInventoryItem item) async {
    final result = await Navigator.of(context)
        .push<_BacklineInventoryItemManagementResult>(
          MaterialPageRoute<_BacklineInventoryItemManagementResult>(
            builder: (_) => _BacklineInventoryItemManagementScreen(item: item),
          ),
        );
    if (!mounted || result == null) return;
    final index = _items.indexWhere((candidate) => identical(candidate, item));
    if (index < 0) return;
    if (result.deleted) {
      setState(() {
        _items.removeAt(index);
        _studioBacklineAvailabilityMockValues.remove(item.name);
      });
      _notifyStudioBacklineInventoryChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item.name} envanterden kaldırıldı.')),
      );
      return;
    }
    final updatedItem = result.updatedItem;
    if (updatedItem == null) return;
    setState(() {
      if (updatedItem.name != item.name) {
        final availability = _studioBacklineAvailabilityMockValues.remove(
          item.name,
        );
        if (availability != null) {
          _studioBacklineAvailabilityMockValues[updatedItem.name] =
              availability;
        }
      }
      _items[index] = updatedItem;
    });
    _notifyStudioBacklineInventoryChanged();
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

class _BacklineInventoryFilterOption<T> {
  final T value;
  final String label;

  const _BacklineInventoryFilterOption({
    required this.value,
    required this.label,
  });
}

class _NewBacklineInventoryItemSheet extends StatefulWidget {
  const _NewBacklineInventoryItemSheet();

  @override
  State<_NewBacklineInventoryItemSheet> createState() =>
      _NewBacklineInventoryItemSheetState();
}

class _NewBacklineInventoryItemSheetState
    extends State<_NewBacklineInventoryItemSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _descriptionController = TextEditingController();
  final _featureController = TextEditingController();
  final List<String> _features = [];
  final List<String> _photoPaths = [];
  final ImagePicker _imagePicker = ImagePicker();
  _BacklineCategory? _selectedCategory;
  String? _selectedSubcategory;
  String? _featureError;

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _quantityController.dispose();
    _descriptionController.dispose();
    _featureController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        child: Material(
          color: const Color(0xFF0B1321),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF445064),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _ownerManagementCardColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _ownerManagementInsetBorderColor,
                        ),
                      ),
                      child: Icon(
                        _selectedCategory?.icon ?? Icons.add_business_outlined,
                        color: _roomFormIconColor,
                        size: 25,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Yeni Ekipman Ekle',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Ekipmanı tanımla ve başlangıç adedini belirle.',
                            style: TextStyle(
                              color: Color(0xFF98A3B3),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Kapat',
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: _ownerManagementInsetBorderColor),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
                    children: [
                      _BacklineInventoryPhotosEditor(
                        photoPaths: _photoPaths,
                        onAddPhotos: _pickPhotos,
                        onReplacePhoto: _replacePhoto,
                        onDeletePhoto: _deletePhoto,
                        onMovePhoto: _movePhoto,
                      ),
                      const SizedBox(height: 20),
                      const _RoomFormSectionLabel(
                        icon: Icons.inventory_2_outlined,
                        label: 'Ekipman Bilgileri',
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _nameController,
                        autofocus: true,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.next,
                        maxLength: 100,
                        decoration: const InputDecoration(
                          labelText: 'Ekipman adı',
                          hintText: 'Örn. Shure SM58',
                          prefixIcon: Icon(
                            Icons.edit_outlined,
                            color: _roomFormIconColor,
                          ),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Ekipman adı zorunludur.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<_BacklineCategory>(
                        initialValue: _selectedCategory,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Ana kategori',
                          prefixIcon: Icon(
                            Icons.category_outlined,
                            color: _roomFormIconColor,
                          ),
                        ),
                        items: [
                          for (final category in _backlineCategories)
                            DropdownMenuItem(
                              value: category,
                              child: Text(
                                category.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (category) => setState(() {
                          _selectedCategory = category;
                          _selectedSubcategory = null;
                        }),
                        validator: (value) => value == null
                            ? 'Bir ana kategori seçmelisin.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        key: ValueKey(_selectedCategory?.name),
                        initialValue: _selectedSubcategory,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Alt kategori',
                          prefixIcon: Icon(
                            Icons.account_tree_outlined,
                            color: _roomFormIconColor,
                          ),
                        ),
                        items: [
                          for (final subcategory
                              in _selectedCategory?.children ??
                                  const <String>[])
                            DropdownMenuItem(
                              value: subcategory,
                              child: Text(
                                subcategory,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: _selectedCategory == null
                            ? null
                            : (value) => _selectedSubcategory = value,
                        validator: (value) => value == null
                            ? 'Bir alt kategori seçmelisin.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _brandController,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              maxLength: 60,
                              decoration: const InputDecoration(
                                labelText: 'Marka (opsiyonel)',
                                prefixIcon: Icon(
                                  Icons.label_outline_rounded,
                                  color: _roomFormIconColor,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _modelController,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              maxLength: 60,
                              decoration: const InputDecoration(
                                labelText: 'Model (opsiyonel)',
                                prefixIcon: Icon(
                                  Icons.numbers_rounded,
                                  color: _roomFormIconColor,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _quantityController,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Toplam adet',
                          prefixIcon: Icon(
                            Icons.numbers_outlined,
                            color: _roomFormIconColor,
                          ),
                          suffixText: 'adet',
                        ),
                        validator: (value) {
                          final quantity = int.tryParse(value?.trim() ?? '');
                          if (quantity == null || quantity < 1) {
                            return 'Geçerli bir adet gir.';
                          }
                          if (quantity > 999) {
                            return 'Tek kayıtta en fazla 999 adet ekleyebilirsin.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _descriptionController,
                        textCapitalization: TextCapitalization.sentences,
                        minLines: 2,
                        maxLines: 4,
                        maxLength: 300,
                        decoration: const InputDecoration(
                          labelText: 'Kısa açıklama (opsiyonel)',
                          hintText: 'Ekipmanın öne çıkan bilgilerini yaz.',
                          alignLabelWithHint: true,
                          prefixIcon: Icon(
                            Icons.notes_outlined,
                            color: _roomFormIconColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const _RoomFormSectionLabel(
                        icon: Icons.sell_outlined,
                        label: 'Teknik Özellikler (opsiyonel)',
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Özellikleri tek tek ekle; ekipman detayında etiket olarak gösterilir.',
                        style: TextStyle(
                          color: Color(0xFF8F99A9),
                          fontSize: 11,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _featureController,
                              textCapitalization: TextCapitalization.sentences,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _addFeature(),
                              decoration: InputDecoration(
                                hintText: 'Örn. Kardioid polar pattern',
                                errorText: _featureError,
                                prefixIcon: const Icon(
                                  Icons.add_circle_outline,
                                  color: _roomFormIconColor,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(top: 7),
                            child: _StudioCircularOutlineButton(
                              tooltip: 'Özellik ekle',
                              icon: Icons.add_rounded,
                              onTap: _addFeature,
                            ),
                          ),
                        ],
                      ),
                      if (_features.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final feature in _features)
                              InputChip(
                                label: Text(feature),
                                avatar: const Icon(Icons.check, size: 16),
                                deleteIcon: const Icon(Icons.close, size: 17),
                                onDeleted: () =>
                                    setState(() => _features.remove(feature)),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 24),
                      _StudioActionButton(
                        icon: Icons.add_business_outlined,
                        label: 'Ekipmanı Envantere Ekle',
                        outlined: true,
                        onTap: _submit,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addFeature() {
    final feature = _capitalizeStudioRoomText(_featureController.text);
    if (feature.isEmpty) {
      setState(() => _featureError = 'Özellik adını yaz.');
      return;
    }
    if (_features.any((item) => item.toLowerCase() == feature.toLowerCase())) {
      setState(() => _featureError = 'Bu özellik zaten eklendi.');
      return;
    }
    if (_features.length >= 12) {
      setState(() => _featureError = 'En fazla 12 özellik ekleyebilirsin.');
      return;
    }
    setState(() {
      _features.add(feature);
      _featureController.clear();
      _featureError = null;
    });
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    final category = _selectedCategory!;
    final quantity = int.parse(_quantityController.text.trim());
    final brand = _capitalizeStudioRoomText(_brandController.text);
    final model = _capitalizeStudioRoomText(_modelController.text);
    final brandAndModel = [
      if (brand.isNotEmpty) brand,
      if (model.isNotEmpty) model,
    ].join(' • ');

    Navigator.of(context).pop(
      _StudioBacklineInventoryItem(
        name: _capitalizeStudioRoomText(_nameController.text),
        category: category.name,
        subcategory: _selectedSubcategory!,
        model: brandAndModel.isEmpty
            ? 'Marka/model belirtilmedi'
            : brandAndModel,
        description: _capitalizeStudioRoomText(_descriptionController.text),
        features: List.unmodifiable(_features),
        photoUrls: List.unmodifiable(_photoPaths),
        icon: category.icon,
        total: quantity,
        available: quantity,
        reserved: 0,
        maintenance: 0,
      ),
    );
  }

  Future<void> _pickPhotos() async {
    final remaining = _maximumBacklineEquipmentPhotoCount - _photoPaths.length;
    if (remaining <= 0) {
      _showPhotoLimitMessage();
      return;
    }
    final selected = await _imagePicker.pickMultiImage(imageQuality: 88);
    if (!mounted || selected.isEmpty) return;
    final accepted = selected.take(remaining).map((photo) => photo.path);
    setState(() => _photoPaths.addAll(accepted));
    if (selected.length > remaining) _showPhotoLimitMessage();
  }

  Future<void> _replacePhoto(int index) async {
    final selected = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (!mounted || selected == null || index >= _photoPaths.length) return;
    setState(() => _photoPaths[index] = selected.path);
  }

  void _deletePhoto(int index) {
    if (index < 0 || index >= _photoPaths.length) return;
    setState(() => _photoPaths.removeAt(index));
  }

  void _movePhoto(int fromIndex, int toIndex) {
    if (fromIndex < 0 ||
        fromIndex >= _photoPaths.length ||
        toIndex < 0 ||
        toIndex >= _photoPaths.length ||
        fromIndex == toIndex) {
      return;
    }
    setState(() {
      final photo = _photoPaths.removeAt(fromIndex);
      _photoPaths.insert(toIndex, photo);
    });
  }

  void _showPhotoLimitMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('En fazla 5 ekipman fotoğrafı ekleyebilirsin.'),
      ),
    );
  }
}

class _BacklineInventoryPhotosEditor extends StatefulWidget {
  final List<String> photoPaths;
  final Future<void> Function() onAddPhotos;
  final Future<void> Function(int index) onReplacePhoto;
  final ValueChanged<int> onDeletePhoto;
  final void Function(int fromIndex, int toIndex) onMovePhoto;

  const _BacklineInventoryPhotosEditor({
    required this.photoPaths,
    required this.onAddPhotos,
    required this.onReplacePhoto,
    required this.onDeletePhoto,
    required this.onMovePhoto,
  });

  @override
  State<_BacklineInventoryPhotosEditor> createState() =>
      _BacklineInventoryPhotosEditorState();
}

class _BacklineInventoryPhotosEditorState
    extends State<_BacklineInventoryPhotosEditor> {
  static const _maximumPhotoCount = _maximumBacklineEquipmentPhotoCount;
  final _pageController = PageController();
  int _activeIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photoPaths;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _ownerManagementCardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _ownerManagementInsetBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Ekipman Fotoğrafları',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${photos.length} / $_maximumPhotoCount',
                style: const TextStyle(
                  color: Color(0xFF9EA8B7),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AspectRatio(
            aspectRatio: 16 / 8,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: PageView.builder(
                controller: _pageController,
                itemCount: _maximumPhotoCount,
                onPageChanged: (index) => setState(() => _activeIndex = index),
                itemBuilder: (_, index) => index < photos.length
                    ? _BacklineInventoryPhotoSlot(
                        path: photos[index],
                        onReplace: () => widget.onReplacePhoto(index),
                        onDelete: () => _deletePhoto(index, photos.length),
                        onMoveLeft: index > 0
                            ? () => _movePhoto(index, index - 1)
                            : null,
                        onMoveRight: index < photos.length - 1
                            ? () => _movePhoto(index, index + 1)
                            : null,
                      )
                    : _EmptyStudioRoomPhotoSlot(
                        slotNumber: index + 1,
                        onAddPhoto: widget.onAddPhotos,
                      ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _maximumPhotoCount,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                width: index == _activeIndex ? 18 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: index == _activeIndex
                      ? const Color(0xFFE87587)
                      : index < photos.length
                      ? const Color(0xFF69758A)
                      : const Color(0xFF344052),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _deletePhoto(int index, int photoCount) {
    widget.onDeletePhoto(index);
    final lastRemainingIndex = photoCount - 2;
    final targetIndex = lastRemainingIndex < 0
        ? 0
        : index > lastRemainingIndex
        ? lastRemainingIndex
        : index;
    _pageController.animateToPage(
      targetIndex,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _movePhoto(int fromIndex, int toIndex) {
    widget.onMovePhoto(fromIndex, toIndex);
    _pageController.animateToPage(
      toIndex,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }
}

class _BacklineInventoryPhotoSlot extends StatelessWidget {
  final String path;
  final VoidCallback onReplace;
  final VoidCallback onDelete;
  final VoidCallback? onMoveLeft;
  final VoidCallback? onMoveRight;

  const _BacklineInventoryPhotoSlot({
    required this.path,
    required this.onReplace,
    required this.onDelete,
    required this.onMoveLeft,
    required this.onMoveRight,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(
          File(path),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const ColoredBox(
            color: _ownerManagementInsetColor,
            child: Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: Color(0xFF929BA8),
                size: 38,
              ),
            ),
          ),
        ),
        Positioned(
          top: 10,
          left: 10,
          child: _StudioPhotoOverlayIconButton(
            icon: Icons.delete_outline_rounded,
            tooltip: 'Fotoğrafı kaldır',
            color: const Color(0xFFFF8792),
            onPressed: onDelete,
          ),
        ),
        Positioned(
          top: 10,
          right: 10,
          child: _StudioPhotoOverlayIconButton(
            icon: Icons.edit_outlined,
            tooltip: 'Fotoğrafı değiştir',
            onPressed: onReplace,
          ),
        ),
        Positioned(
          left: 10,
          bottom: 10,
          child: Material(
            color: const Color(0xD90A111B),
            borderRadius: BorderRadius.circular(999),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: onMoveLeft,
                  tooltip: 'Sola taşı',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                ),
                Container(width: 1, height: 20, color: const Color(0x667E8CA2)),
                IconButton(
                  onPressed: onMoveRight,
                  tooltip: 'Sağa taşı',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BacklineInventorySummaryCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color accent;

  const _BacklineInventorySummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    this.accent = const Color(0xFFD4D9E2),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: _ownerManagementCardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _ownerManagementCardBorderColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF979FAA),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BacklineInventoryFilterButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _BacklineInventoryFilterButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _BacklineOutlineChoice(
      icon: icon,
      label: label,
      selected: active,
      onTap: onTap,
    );
  }
}

class _BacklineInventoryManagementCard extends StatefulWidget {
  final _StudioBacklineInventoryItem item;
  final VoidCallback onManage;

  const _BacklineInventoryManagementCard({
    super.key,
    required this.item,
    required this.onManage,
  });

  @override
  State<_BacklineInventoryManagementCard> createState() =>
      _BacklineInventoryManagementCardState();
}

class _BacklineInventoryManagementCardState
    extends State<_BacklineInventoryManagementCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final available = _mockBacklineAvailableToday(item);
    final busy = _mockBacklineBusyToday(item);
    final maintenance = _mockBacklineMaintenanceToday(item);
    final status = _statusFor(
      item,
      available: available,
      maintenance: maintenance,
    );
    return Container(
      decoration: BoxDecoration(
        color: _ownerManagementCardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _ownerManagementCardBorderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: EdgeInsets.fromLTRB(14, _expanded ? 12 : 14, 12, 14),
              child: Row(
                crossAxisAlignment: _expanded
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.center,
                children: [
                  if (_expanded) ...[
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: _ownerManagementInsetColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _ownerManagementInsetBorderColor,
                        ),
                      ),
                      child: Icon(
                        item.icon,
                        color: _roomFormIconColor,
                        size: 29,
                      ),
                    ),
                    const SizedBox(width: 11),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                item.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            if (_expanded) ...[
                              const SizedBox(width: 7),
                              _BacklineInventoryStatusPill(
                                label: status.$1,
                                color: status.$2,
                              ),
                            ],
                          ],
                        ),
                        if (_expanded) ...[
                          const SizedBox(height: 3),
                          Text(
                            item.category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFAAB1BC),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item.model,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF7F8793),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF929BA8),
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            _BacklineInventoryCountCell(
                              label: 'Toplam',
                              value: item.total,
                            ),
                            const SizedBox(width: 7),
                            _BacklineInventoryCountCell(
                              label: 'Müsait',
                              value: available,
                              accent: const Color(0xFF62C98B),
                            ),
                            const SizedBox(width: 7),
                            _BacklineInventoryCountCell(
                              label: 'Dolu',
                              value: busy,
                              accent: const Color(0xFFF0C75E),
                            ),
                            const SizedBox(width: 7),
                            _BacklineInventoryCountCell(
                              label: 'Bakımda',
                              value: maintenance,
                              accent: const Color(0xFFE47B86),
                            ),
                          ],
                        ),
                        const SizedBox(height: 11),
                        _StudioActionButton(
                          icon: Icons.tune_rounded,
                          label: 'Ekipmanı Yönet',
                          outlined: true,
                          onTap: widget.onManage,
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  static (String, Color) _statusFor(
    _StudioBacklineInventoryItem item, {
    required int available,
    required int maintenance,
  }) {
    if (maintenance == item.total) {
      return ('Bakımda', const Color(0xFFE47B86));
    }
    if (available == item.total) {
      return ('Müsait', const Color(0xFF62C98B));
    }
    if (available > 0) {
      return ('Kısmen Müsait', const Color(0xFFF0C75E));
    }
    return ('Dolu', const Color(0xFFC9A0E8));
  }
}

class _BacklineInventoryCountCell extends StatelessWidget {
  final String label;
  final int value;
  final Color accent;

  const _BacklineInventoryCountCell({
    required this.label,
    required this.value,
    this.accent = const Color(0xFFD4D9E2),
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: _ownerManagementInsetColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _ownerManagementInsetBorderColor),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(
                color: accent,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF858D98),
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

class _BacklineInventoryStatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _BacklineInventoryStatusPill({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _BacklineInventoryEmptyState extends StatelessWidget {
  const _BacklineInventoryEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1622),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _ownerManagementInsetBorderColor),
      ),
      child: const Column(
        children: [
          Icon(Icons.search_off_rounded, color: Color(0xFF89919D), size: 34),
          SizedBox(height: 10),
          Text(
            'Eşleşen ekipman bulunamadı',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Arama metnini veya filtreleri değiştirerek tekrar dene.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF929AA6), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _StudioBacklineCategoryManagementScreen extends StatefulWidget {
  const _StudioBacklineCategoryManagementScreen();

  @override
  State<_StudioBacklineCategoryManagementScreen> createState() =>
      _StudioBacklineCategoryManagementScreenState();
}

class _StudioBacklineCategoryManagementScreenState
    extends State<_StudioBacklineCategoryManagementScreen> {
  final List<_BacklineCategoryRequest> _submittedRequests = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kategori Talep Et'), centerTitle: true),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          children: [
            const _BacklineCategoryRequestInfoCard(),
            const SizedBox(height: 14),
            _StudioActionButton(
              icon: Icons.add_rounded,
              label: 'Yeni Kategori / Alt Kategori Talep Et',
              outlined: true,
              onTap: _openRequestSheet,
            ),
            if (_submittedRequests.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                'Talepleriniz',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              for (final request in _submittedRequests)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _BacklineSubmittedCategoryRequestCard(
                    request: request,
                  ),
                ),
            ],
            const SizedBox(height: 20),
            const Text(
              'SoundConnect Kategorileri',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${_backlineCategories.length} ana kategori • '
              '${_backlineCategories.fold<int>(0, (sum, item) => sum + item.children.length)} alt kategori',
              style: const TextStyle(color: Color(0xFF929DAC), fontSize: 12),
            ),
            const SizedBox(height: 10),
            for (final category in _backlineCategories)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _BacklineManagementCategoryTile(category: category),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openRequestSheet() async {
    final request = await showModalBottomSheet<_BacklineCategoryRequest>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _BacklineCategoryRequestSheet(),
    );
    if (request == null || !mounted) return;
    setState(() => _submittedRequests.insert(0, request));
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF101722),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF2D394C)),
        ),
        title: const Row(
          children: [
            Icon(Icons.mark_email_read_outlined, color: Color(0xFF75D7A3)),
            SizedBox(width: 10),
            Expanded(child: Text('Talebiniz iletildi')),
          ],
        ),
        content: const Text(
          'Talep ettiğiniz kategori veya alt kategori SoundConnect '
          'yetkililerine ulaştırıldı. İnceleme ve onay sonrasında yalnızca '
          'bu stüdyo için değil, tüm SoundConnect kullanıcıları için '
          'geçerli olacaktır.',
          style: TextStyle(
            color: Color(0xFFB8C0CC),
            fontSize: 14,
            height: 1.45,
          ),
        ),
        actions: [
          SizedBox(
            width: 120,
            child: _StudioActionButton(
              icon: Icons.check_rounded,
              label: 'Tamam',
              outlined: true,
              onTap: () => Navigator.of(dialogContext).pop(),
            ),
          ),
        ],
      ),
    );
  }
}

class _BacklineCategoryRequestInfoCard extends StatelessWidget {
  const _BacklineCategoryRequestInfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF101722),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF343842)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: Color(0xFFD4D9E2), size: 21),
          SizedBox(width: 11),
          Expanded(
            child: Text(
              'Kategori yapısı SoundConnect genelinde ortaktır. Yeni talepler '
              'yetkili incelemesinden sonra tüm platform için yayınlanır.',
              style: TextStyle(
                color: Color(0xFFB6C0CF),
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BacklineManagementCategoryTile extends StatelessWidget {
  final _BacklineCategory category;

  const _BacklineManagementCategoryTile({required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF101722),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF263244)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        iconColor: const Color(0xFFFF8A8A),
        collapsedIconColor: const Color(0xFF8E99A9),
        leading: _BacklineCategoryIcon(category: category),
        title: Text(
          category.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          '${category.children.length} alt kategori',
          style: const TextStyle(color: Color(0xFF8F9AAA), fontSize: 11),
        ),
        children: [
          const Divider(height: 1, color: Color(0xFF263244)),
          for (final subcategory in category.children)
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.only(left: 56, right: 14),
              leading: const Icon(
                Icons.subdirectory_arrow_right_rounded,
                color: Color(0xFF718096),
                size: 17,
              ),
              title: Text(
                subcategory,
                style: const TextStyle(
                  color: Color(0xFFB8C0CC),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

enum _BacklineCategoryRequestType { category, subcategory }

class _BacklineOutlineChoice extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _BacklineOutlineChoice({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 170),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(0.8),
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: selected
            ? LinearGradient(colors: AppColors.brandGradient)
            : null,
        color: selected ? null : _ownerManagementInsetBorderColor,
      ),
      child: Material(
        color: _ownerManagementCardColor,
        borderRadius: BorderRadius.circular(13.2),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13.2),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: subtitle == null ? 12 : 14,
              vertical: subtitle == null ? 13 : 12,
            ),
            child: Row(
              children: [
                Icon(icon, color: const Color(0xFFD4D9E2), size: 20),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        maxLines: subtitle == null ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            color: Color(0xFF979DA8),
                            fontSize: 10,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  selected
                      ? Icons.check_circle_outline_rounded
                      : Icons.circle_outlined,
                  color: selected ? Colors.white : const Color(0xFF6F747D),
                  size: 19,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BacklineCategoryRequest {
  final _BacklineCategoryRequestType type;
  final String name;
  final String? parentCategory;
  final List<String> proposedSubcategories;
  final String note;

  const _BacklineCategoryRequest({
    required this.type,
    required this.name,
    required this.parentCategory,
    required this.proposedSubcategories,
    required this.note,
  });
}

class _BacklineCategoryRequestSheet extends StatefulWidget {
  const _BacklineCategoryRequestSheet();

  @override
  State<_BacklineCategoryRequestSheet> createState() =>
      _BacklineCategoryRequestSheetState();
}

class _BacklineCategoryRequestSheetState
    extends State<_BacklineCategoryRequestSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _noteController = TextEditingController();
  final _subcategoryController = TextEditingController();
  final List<String> _proposedSubcategories = [];
  _BacklineCategoryRequestType _type = _BacklineCategoryRequestType.category;
  String? _parentCategory;
  bool _includeSubcategories = false;
  String? _subcategoryError;

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    _subcategoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Material(
        color: const Color(0xFF0B1321),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A4D55),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Kategori Talebi Oluştur',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Eksik olduğunu düşündüğün kategori yapısını bize ilet.',
                  style: TextStyle(color: Color(0xFF9CA7B7), fontSize: 12),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _BacklineOutlineChoice(
                        icon: Icons.folder_outlined,
                        label: 'Ana Kategori',
                        selected:
                            _type == _BacklineCategoryRequestType.category,
                        onTap: () =>
                            _selectType(_BacklineCategoryRequestType.category),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _BacklineOutlineChoice(
                        icon: Icons.account_tree_outlined,
                        label: 'Alt Kategori',
                        selected:
                            _type == _BacklineCategoryRequestType.subcategory,
                        onTap: () => _selectType(
                          _BacklineCategoryRequestType.subcategory,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_type == _BacklineCategoryRequestType.subcategory) ...[
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _parentCategory,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Bağlı olacağı ana kategori',
                      prefixIcon: Icon(
                        Icons.folder_open_outlined,
                        color: _roomFormIconColor,
                      ),
                    ),
                    items: [
                      for (final category in _backlineCategories)
                        DropdownMenuItem(
                          value: category.name,
                          child: Text(
                            category.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) => _parentCategory = value,
                    validator: (value) =>
                        value == null ? 'Bir ana kategori seçmelisin.' : null,
                  ),
                ],
                const SizedBox(height: 14),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  maxLength: 80,
                  decoration: InputDecoration(
                    labelText: _type == _BacklineCategoryRequestType.category
                        ? 'Önerilen kategori adı'
                        : 'Önerilen alt kategori adı',
                    prefixIcon: const Icon(
                      Icons.edit_outlined,
                      color: _roomFormIconColor,
                    ),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Talep ettiğin kategorinin adını yaz.'
                      : null,
                ),
                if (_type == _BacklineCategoryRequestType.category) ...[
                  const SizedBox(height: 4),
                  _BacklineOutlineChoice(
                    icon: Icons.account_tree_outlined,
                    label: 'Alt kategorileri de talebe ekle',
                    subtitle:
                        'Yeni ana kategoriyle birlikte alt kategori önerileri gönder.',
                    selected: _includeSubcategories,
                    onTap: _toggleIncludedSubcategories,
                  ),
                  if (_includeSubcategories) ...[
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _subcategoryController,
                            textCapitalization: TextCapitalization.sentences,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _addProposedSubcategory(),
                            decoration: InputDecoration(
                              labelText: 'Alt kategori adı',
                              hintText: 'Örn. Dijital mikserler',
                              errorText: _subcategoryError,
                              prefixIcon: const Icon(
                                Icons.subdirectory_arrow_right_rounded,
                                color: _roomFormIconColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(top: 7),
                          child: _StudioCircularOutlineButton(
                            tooltip: 'Alt kategori ekle',
                            icon: Icons.add_rounded,
                            onTap: _addProposedSubcategory,
                          ),
                        ),
                      ],
                    ),
                    if (_proposedSubcategories.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final subcategory in _proposedSubcategories)
                            InputChip(
                              label: Text(subcategory),
                              avatar: const Icon(
                                Icons.account_tree_outlined,
                                size: 16,
                              ),
                              deleteIcon: const Icon(Icons.close, size: 17),
                              onDeleted: () => setState(
                                () =>
                                    _proposedSubcategories.remove(subcategory),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ],
                const SizedBox(height: 10),
                TextFormField(
                  controller: _noteController,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 300,
                  decoration: const InputDecoration(
                    labelText: 'Açıklama (opsiyonel)',
                    hintText: 'Bu kategoriye neden ihtiyaç duyulduğunu anlat.',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(
                      Icons.notes_outlined,
                      color: _roomFormIconColor,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _StudioActionButton(
                  icon: Icons.send_outlined,
                  label: 'Talebi SoundConnect’e Gönder',
                  outlined: true,
                  onTap: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    final formIsValid = _formKey.currentState?.validate() == true;
    if (_type == _BacklineCategoryRequestType.category &&
        _includeSubcategories &&
        _proposedSubcategories.isEmpty) {
      setState(() => _subcategoryError = 'En az bir alt kategori eklemelisin.');
    }
    if (!formIsValid ||
        (_type == _BacklineCategoryRequestType.category &&
            _includeSubcategories &&
            _proposedSubcategories.isEmpty)) {
      return;
    }
    Navigator.of(context).pop(
      _BacklineCategoryRequest(
        type: _type,
        name: _capitalizeStudioRoomText(_nameController.text),
        parentCategory: _parentCategory,
        proposedSubcategories: List.unmodifiable(_proposedSubcategories),
        note: _capitalizeStudioRoomText(_noteController.text),
      ),
    );
  }

  void _selectType(_BacklineCategoryRequestType type) {
    if (_type == type) return;
    setState(() {
      _type = type;
      if (_type == _BacklineCategoryRequestType.category) {
        _parentCategory = null;
      } else {
        _includeSubcategories = false;
        _proposedSubcategories.clear();
        _subcategoryController.clear();
        _subcategoryError = null;
      }
    });
  }

  void _toggleIncludedSubcategories() {
    setState(() {
      _includeSubcategories = !_includeSubcategories;
      if (!_includeSubcategories) {
        _proposedSubcategories.clear();
        _subcategoryController.clear();
        _subcategoryError = null;
      }
    });
  }

  void _addProposedSubcategory() {
    final subcategory = _capitalizeStudioRoomText(_subcategoryController.text);
    if (subcategory.isEmpty) {
      setState(() => _subcategoryError = 'Alt kategori adını yaz.');
      return;
    }
    if (_proposedSubcategories.any(
      (item) => item.toLowerCase() == subcategory.toLowerCase(),
    )) {
      setState(() => _subcategoryError = 'Bu alt kategori zaten eklendi.');
      return;
    }
    if (_proposedSubcategories.length >= 10) {
      setState(
        () => _subcategoryError = 'En fazla 10 alt kategori ekleyebilirsin.',
      );
      return;
    }
    setState(() {
      _proposedSubcategories.add(subcategory);
      _subcategoryController.clear();
      _subcategoryError = null;
    });
  }
}

class _BacklineSubmittedCategoryRequestCard extends StatelessWidget {
  final _BacklineCategoryRequest request;

  const _BacklineSubmittedCategoryRequestCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final isSubcategory =
        request.type == _BacklineCategoryRequestType.subcategory;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFF101722),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A374A)),
      ),
      child: Row(
        children: [
          Icon(
            isSubcategory ? Icons.account_tree_outlined : Icons.folder_outlined,
            color: const Color(0xFFB9C3D2),
            size: 22,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (request.parentCategory != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    request.parentCategory!,
                    style: const TextStyle(
                      color: Color(0xFF8F9AAA),
                      fontSize: 11,
                    ),
                  ),
                ],
                if (request.proposedSubcategories.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    '${request.proposedSubcategories.length} alt kategori önerisi',
                    style: const TextStyle(
                      color: Color(0xFFB5BAC4),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0x33E062A9),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0x66E062A9)),
            ),
            child: const Text(
              'İncelemede',
              style: TextStyle(
                color: Color(0xFFF09BC7),
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
