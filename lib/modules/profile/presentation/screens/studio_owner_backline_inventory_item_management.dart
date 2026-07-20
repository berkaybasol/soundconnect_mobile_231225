part of 'studio_profile_screen.dart';

class _BacklineInventoryItemManagementResult {
  final _StudioBacklineInventoryItem? updatedItem;
  final bool deleted;

  const _BacklineInventoryItemManagementResult.updated(this.updatedItem)
    : deleted = false;

  const _BacklineInventoryItemManagementResult.deleted()
    : updatedItem = null,
      deleted = true;
}

class _BacklineInventoryItemManagementScreen extends StatefulWidget {
  final _StudioBacklineInventoryItem item;

  const _BacklineInventoryItemManagementScreen({required this.item});

  @override
  State<_BacklineInventoryItemManagementScreen> createState() =>
      _BacklineInventoryItemManagementScreenState();
}

class _BacklineInventoryItemManagementScreenState
    extends State<_BacklineInventoryItemManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _brandController;
  late final TextEditingController _modelController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _totalController;
  final _featureController = TextEditingController();
  final _imagePicker = ImagePicker();
  late final List<String> _features;
  late final List<String> _photoPaths;
  late _BacklineCategory _selectedCategory;
  late String _selectedSubcategory;
  bool _isDirty = false;
  bool _allowPop = false;
  bool _exitDialogOpen = false;
  String? _featureError;

  int get _total => int.tryParse(_totalController.text.trim()) ?? 0;
  _BacklineDayAvailability? get _todayAvailability =>
      _studioBacklineAvailabilityMockValues[widget.item.name]?[_dateOnly(
        DateTime.now(),
      )];
  int get _maintenance =>
      _todayAvailability?.maintenanceCount ?? widget.item.maintenance;
  int get _busy => _todayAvailability?.busyCount ?? widget.item.reserved;
  int get _maximumAllocatedCount {
    var maximum = widget.item.reserved + widget.item.maintenance;
    final scheduledValues =
        _studioBacklineAvailabilityMockValues[widget.item.name]?.values;
    if (scheduledValues == null) return maximum;
    for (final state in scheduledValues) {
      final allocated = state.busyCount + state.maintenanceCount;
      if (allocated > maximum) maximum = allocated;
    }
    return maximum;
  }

  int get _available {
    final value = _total - _busy - _maintenance;
    return value < 0 ? 0 : value;
  }

  @override
  void initState() {
    super.initState();
    final modelParts = widget.item.model == 'Marka/model belirtilmedi'
        ? const <String>[]
        : widget.item.model.split(' • ');
    _nameController = TextEditingController(text: widget.item.name);
    _brandController = TextEditingController(
      text: modelParts.isEmpty ? '' : modelParts.first,
    );
    _modelController = TextEditingController(
      text: modelParts.length < 2 ? '' : modelParts.skip(1).join(' • '),
    );
    _descriptionController = TextEditingController(
      text: widget.item.description,
    );
    _totalController = TextEditingController(text: '${widget.item.total}');
    _features = List.of(widget.item.features);
    _photoPaths = List.of(
      widget.item.photoUrls.take(_maximumBacklineEquipmentPhotoCount),
    );
    _selectedCategory = _backlineCategories.firstWhere(
      (category) => category.name == widget.item.category,
      orElse: () => _backlineCategories.first,
    );
    _selectedSubcategory =
        _selectedCategory.children.contains(widget.item.subcategory)
        ? widget.item.subcategory
        : _selectedCategory.children.first;
    for (final controller in [
      _nameController,
      _brandController,
      _modelController,
      _descriptionController,
      _featureController,
    ]) {
      controller.addListener(_markDirty);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _descriptionController.dispose();
    _totalController.dispose();
    _featureController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<_BacklineInventoryItemManagementResult>(
      canPop: _allowPop || !_isDirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscardChanges();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Ekipmanı Yönet'), centerTitle: true),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
              children: [
                _BacklineInventoryManagementHero(
                  item: widget.item,
                  category: _selectedCategory.name,
                ),
                const SizedBox(height: 16),
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
                  label: 'Envanter Durumu',
                ),
                const SizedBox(height: 10),
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
                      value: _total,
                      icon: Icons.inventory_2_outlined,
                    ),
                    _BacklineInventorySummaryCard(
                      label: 'Müsait',
                      value: _available,
                      icon: Icons.check_circle_outline_rounded,
                      accent: const Color(0xFF62C98B),
                    ),
                    _BacklineInventorySummaryCard(
                      label: 'Dolu',
                      value: _busy,
                      icon: Icons.event_busy_outlined,
                      accent: const Color(0xFFF0C75E),
                    ),
                    _BacklineInventorySummaryCard(
                      label: 'Bakımda',
                      value: _maintenance,
                      icon: Icons.build_outlined,
                      accent: const Color(0xFFE47B86),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _totalController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Toplam adet',
                    suffixText: 'adet',
                    prefixIcon: Icon(
                      Icons.numbers_outlined,
                      color: _roomFormIconColor,
                    ),
                  ),
                  onChanged: (_) => _markDirtyAndRebuild(),
                  validator: _validateTotal,
                ),
                const SizedBox(height: 8),
                const _BacklineAvailabilitySourceInfo(),
                const SizedBox(height: 22),
                const _RoomFormSectionLabel(
                  icon: Icons.tune_outlined,
                  label: 'Ekipman Bilgileri',
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  maxLength: 100,
                  decoration: const InputDecoration(
                    labelText: 'Ekipman adı',
                    prefixIcon: Icon(
                      Icons.edit_outlined,
                      color: _roomFormIconColor,
                    ),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
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
                  onChanged: (category) {
                    if (category == null) return;
                    setState(() {
                      _selectedCategory = category;
                      _selectedSubcategory = category.children.first;
                      _isDirty = true;
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey(_selectedCategory.name),
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
                    for (final subcategory in _selectedCategory.children)
                      DropdownMenuItem(
                        value: subcategory,
                        child: Text(
                          subcategory,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (subcategory) {
                    if (subcategory == null) return;
                    setState(() {
                      _selectedSubcategory = subcategory;
                      _isDirty = true;
                    });
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _brandController,
                        textCapitalization: TextCapitalization.words,
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
                  controller: _descriptionController,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 300,
                  decoration: const InputDecoration(
                    labelText: 'Kısa açıklama (opsiyonel)',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(
                      Icons.notes_outlined,
                      color: _roomFormIconColor,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const _RoomFormSectionLabel(
                  icon: Icons.sell_outlined,
                  label: 'Teknik Özellikler (opsiyonel)',
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
                          hintText: 'Yeni özellik ekle',
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
                          onDeleted: () => setState(() {
                            _features.remove(feature);
                            _isDirty = true;
                          }),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                _StudioActionButton(
                  icon: Icons.save_outlined,
                  label: 'Değişiklikleri Kaydet',
                  outlined: true,
                  onTap: _save,
                ),
                const SizedBox(height: 12),
                _BacklineInventoryDeleteButton(onTap: _confirmDelete),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _validateTotal(String? value) {
    final total = int.tryParse(value?.trim() ?? '');
    if (total == null || total < 1) return 'Geçerli bir adet gir.';
    if (total > 999) return 'En fazla 999 olabilir.';
    if (total < _maximumAllocatedCount) {
      return 'Takvimde ayrılmış $_maximumAllocatedCount adetten az olamaz.';
    }
    return null;
  }

  void _markDirty() {
    if (_isDirty || !mounted) return;
    setState(() => _isDirty = true);
  }

  void _markDirtyAndRebuild() {
    if (!mounted) return;
    setState(() => _isDirty = true);
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
      _isDirty = true;
    });
  }

  Future<void> _pickPhotos() async {
    final remaining = _maximumBacklineEquipmentPhotoCount - _photoPaths.length;
    if (remaining <= 0) {
      _showPhotoLimitMessage();
      return;
    }
    final selected = await _imagePicker.pickMultiImage(imageQuality: 88);
    if (!mounted || selected.isEmpty) return;
    setState(() {
      _photoPaths.addAll(selected.take(remaining).map((photo) => photo.path));
      _isDirty = true;
    });
    if (selected.length > remaining) _showPhotoLimitMessage();
  }

  Future<void> _replacePhoto(int index) async {
    final selected = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (!mounted || selected == null || index >= _photoPaths.length) return;
    setState(() {
      _photoPaths[index] = selected.path;
      _isDirty = true;
    });
  }

  void _deletePhoto(int index) {
    if (index < 0 || index >= _photoPaths.length) return;
    setState(() {
      _photoPaths.removeAt(index);
      _isDirty = true;
    });
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
      _isDirty = true;
    });
  }

  void _showPhotoLimitMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('En fazla 5 ekipman fotoğrafı ekleyebilirsin.'),
      ),
    );
  }

  void _save() {
    if (_formKey.currentState?.validate() != true) return;
    final brand = _capitalizeStudioRoomText(_brandController.text);
    final model = _capitalizeStudioRoomText(_modelController.text);
    final brandAndModel = [
      if (brand.isNotEmpty) brand,
      if (model.isNotEmpty) model,
    ].join(' • ');
    final updated = widget.item.copyWith(
      name: _capitalizeStudioRoomText(_nameController.text),
      category: _selectedCategory.name,
      subcategory: _selectedSubcategory,
      model: brandAndModel.isEmpty ? 'Marka/model belirtilmedi' : brandAndModel,
      description: _capitalizeStudioRoomText(_descriptionController.text),
      features: List.unmodifiable(_features),
      photoUrls: List.unmodifiable(_photoPaths),
      icon: _selectedCategory.icon,
      total: _total,
      available: _available,
    );
    _closeWithResult(_BacklineInventoryItemManagementResult.updated(updated));
  }

  Future<void> _confirmDelete() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF101722),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF3A2630)),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFFF7B88)),
            SizedBox(width: 10),
            Expanded(child: Text('Ekipman envanterden kaldırılsın mı?')),
          ],
        ),
        content: Text(
          '“${widget.item.name}” ekipmanını kaldırırsanız ekipmana bağlı '
          'müsaitlik kayıtları ve kiralama talepleri de silinecek. Bu işlem '
          'geri alınamaz. Yine de devam etmek istiyor musunuz?',
          style: const TextStyle(
            color: Color(0xFFB8C0CC),
            fontSize: 14,
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD84A5A),
            ),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Envanterden Kaldır'),
          ),
        ],
      ),
    );
    if (shouldDelete == true && mounted) {
      _closeWithResult(const _BacklineInventoryItemManagementResult.deleted());
    }
  }

  Future<void> _confirmDiscardChanges() async {
    if (_exitDialogOpen) return;
    _exitDialogOpen = true;
    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF101722),
        title: const Text('Değişiklikler kaydedilmedi'),
        content: const Text(
          'Bu ekrandan çıkarsanız ekipmanda yaptığınız değişiklikler '
          'kaybolacak. Yine de çıkmak istiyor musunuz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Düzenlemeye Devam Et'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Kaydetmeden Çık'),
          ),
        ],
      ),
    );
    _exitDialogOpen = false;
    if (shouldDiscard == true && mounted) _closeWithResult(null);
  }

  void _closeWithResult(_BacklineInventoryItemManagementResult? result) {
    if (!mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(result);
    });
  }
}

class _BacklineInventoryManagementHero extends StatelessWidget {
  final _StudioBacklineInventoryItem item;
  final String category;

  const _BacklineInventoryManagementHero({
    required this.item,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _ownerManagementCardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _ownerManagementCardBorderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _ownerManagementInsetColor,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: _ownerManagementInsetBorderColor),
            ),
            child: Icon(item.icon, color: _roomFormIconColor, size: 27),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF9FA9B8),
                    fontSize: 11,
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

class _BacklineAvailabilitySourceInfo extends StatelessWidget {
  const _BacklineAvailabilitySourceInfo();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _ownerManagementInsetColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _ownerManagementInsetBorderColor),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: _roomFormIconColor, size: 19),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              'Dolu ve bakımda adetleri Ekipman Takvimi üzerinden '
              'düzenlenir. Burada yalnızca toplam envanter adedini '
              'değiştirebilirsin.',
              style: TextStyle(
                color: Color(0xFFAAB3C1),
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BacklineInventoryDeleteButton extends StatelessWidget {
  final VoidCallback onTap;

  const _BacklineInventoryDeleteButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFFF7B88),
          side: const BorderSide(color: Color(0xFF7D3541)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: const Icon(Icons.delete_outline_rounded, size: 19),
        label: const Text(
          'Envanterden Kaldır',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        ),
      ),
    );
  }
}
