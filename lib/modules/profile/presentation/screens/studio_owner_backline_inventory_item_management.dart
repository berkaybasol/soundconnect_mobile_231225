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
  final String studioProfileId;
  final StudioEquipmentRepository repository;
  final List<_BacklineCategory> categories;

  const _BacklineInventoryItemManagementScreen({
    required this.item,
    required this.studioProfileId,
    required this.repository,
    required this.categories,
  });

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
  late final DraftMediaCleanupCoordinator _draftMediaCleanup;
  late final List<String> _features;
  late final List<String> _photoPaths;
  final Map<String, String> _photoMediaIdsByPath = {};
  late _BacklineCategory _selectedCategory;
  late String _selectedSubcategory;
  bool _isDirty = false;
  bool _allowPop = false;
  bool _exitDialogOpen = false;
  bool _isSubmitting = false;
  String? _featureError;

  int get _total => int.tryParse(_totalController.text.trim()) ?? 0;
  int get _maintenance => widget.item.maintenance;
  int get _busy => widget.item.reserved;
  int get _maximumAllocatedCount =>
      widget.item.reserved + widget.item.maintenance;

  int get _available {
    final value = _total - _busy - _maintenance;
    return value < 0 ? 0 : value;
  }

  @override
  void initState() {
    super.initState();
    _draftMediaCleanup = DraftMediaCleanupCoordinator(
      repository: serviceLocator<ProfileMediaUploadRepository>(),
      ownerType: 'STUDIO_PROFILE',
      ownerId: widget.studioProfileId,
    );
    _nameController = TextEditingController(text: widget.item.name);
    _brandController = TextEditingController(text: widget.item.brand);
    _modelController = TextEditingController(text: widget.item.modelName);
    _descriptionController = TextEditingController(
      text: widget.item.description,
    );
    _totalController = TextEditingController(text: '${widget.item.total}');
    _features = List.of(widget.item.features);
    _photoPaths = List.of(
      widget.item.photoUrls.take(_maximumBacklineEquipmentPhotoCount),
    );
    for (var index = 0; index < _photoPaths.length; index++) {
      if (index < widget.item.photoMediaIds.length) {
        _photoMediaIdsByPath[_photoPaths[index]] =
            widget.item.photoMediaIds[index];
      }
    }
    _selectedCategory = widget.categories.firstWhere(
      (category) =>
          category.id == widget.item.categoryId ||
          category.name == widget.item.category,
      orElse: () => widget.categories.first,
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
    _draftMediaCleanup.close().ignore();
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
                    for (final category in widget.categories)
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
                  icon: _isSubmitting
                      ? Icons.hourglass_top_rounded
                      : Icons.save_outlined,
                  label: _isSubmitting
                      ? 'Değişiklikler Kaydediliyor...'
                      : 'Değişiklikleri Kaydet',
                  outlined: true,
                  onTap: _isSubmitting ? () {} : _save,
                ),
                const SizedBox(height: 12),
                _BacklineInventoryDeleteButton(
                  onTap: _isSubmitting ? () {} : _confirmDelete,
                ),
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
    final replacedMediaId = _photoMediaIdsByPath[_photoPaths[index]];
    setState(() {
      _photoMediaIdsByPath.remove(_photoPaths[index]);
      _photoPaths[index] = selected.path;
      _isDirty = true;
    });
    if (replacedMediaId != null &&
        _draftMediaCleanup.isTracked(replacedMediaId)) {
      _draftMediaCleanup.discard(replacedMediaId).ignore();
    }
  }

  void _deletePhoto(int index) {
    if (index < 0 || index >= _photoPaths.length) return;
    final removedMediaId = _photoMediaIdsByPath[_photoPaths[index]];
    setState(() {
      _photoMediaIdsByPath.remove(_photoPaths[index]);
      _photoPaths.removeAt(index);
      _isDirty = true;
    });
    if (removedMediaId != null &&
        _draftMediaCleanup.isTracked(removedMediaId)) {
      _draftMediaCleanup.discard(removedMediaId).ignore();
    }
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

  Future<void> _save() async {
    if (_formKey.currentState?.validate() != true) return;
    final brand = _capitalizeStudioRoomText(_brandController.text);
    final model = _capitalizeStudioRoomText(_modelController.text);
    final leafCategoryId = _selectedCategory.childId(_selectedSubcategory);
    if (leafCategoryId == null || leafCategoryId.isEmpty) {
      _showMessage(
        'Seçilen alt kategori güncel değil. Sayfayı yenileyip tekrar dene.',
      );
      return;
    }
    setState(() => _isSubmitting = true);
    final uploaded = await _uploadPendingPhotos();
    if (!mounted) return;
    if (!uploaded) {
      setState(() => _isSubmitting = false);
      return;
    }
    final submittedPhotoIds = _photoPaths
        .map((path) => _photoMediaIdsByPath[path])
        .whereType<String>()
        .toList(growable: false);
    final submittedPhotoIdSet = submittedPhotoIds.toSet();
    final potentiallyDetachedIds = widget.item.photoMediaIds.where(
      (id) => id.trim().isNotEmpty && !submittedPhotoIdSet.contains(id.trim()),
    );
    final cleanupPrepared = await _draftMediaCleanup.trackPotentiallyDetached(
      potentiallyDetachedIds,
    );
    if (!mounted) return;
    if (!cleanupPrepared.isSuccess) {
      final report = await _draftMediaCleanup.discardAll();
      _removeMediaMappings(report.deletedOrAbsentAssetIds);
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showMessage(
        cleanupPrepared.error?.message ??
            'Fotoğraf değişikliği güvenli biçimde hazırlanamadı.',
      );
      return;
    }
    final result = await widget.repository.updateEquipment(
      equipmentId: widget.item.id,
      command: UpdateStudioEquipmentCommand(
        expectedVersion: widget.item.version,
        leafCategoryId: leafCategoryId,
        name: _capitalizeStudioRoomText(_nameController.text),
        brand: brand,
        model: model,
        description: _capitalizeStudioRoomText(_descriptionController.text),
        totalQuantity: _total,
        features: List.unmodifiable(_features),
        photoMediaIds: submittedPhotoIds,
      ),
    );
    if (!mounted) return;
    if (!result.isSuccess || result.data == null) {
      final cleanupReport = await _draftMediaCleanup.discardAll();
      if (!mounted) return;
      if (cleanupReport.hasProtectedReferences) {
        final latest = await widget.repository.getOwnerEquipment(
          widget.item.id,
        );
        if (!mounted) return;
        final latestItem = latest.data;
        if (latest.isSuccess &&
            latestItem != null &&
            _sameEquipmentMediaIds(latestItem, submittedPhotoIds)) {
          await _finishSuccessfulEquipmentUpdate(latestItem);
          return;
        }
      }
      _removeMediaMappings(cleanupReport.deletedOrAbsentAssetIds);
      setState(() => _isSubmitting = false);
      if (result.error?.code == '9804') {
        await _handleStaleEquipment();
        return;
      }
      _showMessage(result.error?.message ?? 'Ekipman güncellenemedi.');
      return;
    }
    await _finishSuccessfulEquipmentUpdate(result.data!);
  }

  Future<void> _finishSuccessfulEquipmentUpdate(
    StudioEquipment equipment,
  ) async {
    final savedPhotoIds = equipment.photos
        .map((photo) => photo.mediaAssetId?.trim() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    await _draftMediaCleanup.markCommitted(savedPhotoIds);
    await _draftMediaCleanup.close();
    if (!mounted) return;
    _closeWithResult(
      _BacklineInventoryItemManagementResult.updated(
        _StudioBacklineInventoryItem.fromDomain(equipment),
      ),
    );
  }

  bool _sameEquipmentMediaIds(
    StudioEquipment equipment,
    List<String> expectedIds,
  ) {
    final actualIds = equipment.photos
        .map((photo) => photo.mediaAssetId?.trim() ?? '')
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    if (actualIds.length != expectedIds.length) return false;
    for (var index = 0; index < actualIds.length; index++) {
      if (actualIds[index] != expectedIds[index]) return false;
    }
    return true;
  }

  Future<bool> _uploadPendingPhotos() async {
    final uploadedThisAttempt = <String>[];
    for (final path in List<String>.of(_photoPaths)) {
      if (_photoMediaIdsByPath.containsKey(path)) continue;
      try {
        final fileName = fileNameFromPath(path, fallback: 'equipment.jpg');
        final uploaded = await uploadProfileMediaAsset(
          source: await createProfileUploadSource(filePath: path),
          ownerType: 'STUDIO_PROFILE',
          ownerId: widget.studioProfileId,
          mediaKind: 'IMAGE',
          mimeType: inferImageMimeType(fileName),
          originalFileName: fileName,
          attachmentIntent: const ProfileUploadAttachmentIntent.draft(),
        );
        final id = uploaded.uuid.trim();
        if (id.isEmpty) throw StateError('Media asset id is empty');
        final tracked = await _draftMediaCleanup.trackUploaded(id);
        if (!tracked.isSuccess) {
          throw StateError('Draft media cleanup could not be persisted');
        }
        uploadedThisAttempt.add(id);
        if (!mounted) {
          await _draftMediaCleanup.discard(id);
          return false;
        }
        _photoMediaIdsByPath[path] = id;
      } catch (_) {
        for (final assetId in uploadedThisAttempt) {
          await _draftMediaCleanup.discard(assetId);
        }
        _removeMediaMappings(uploadedThisAttempt);
        if (mounted) _showMessage('Fotoğraf yüklenemedi. Lütfen tekrar dene.');
        return false;
      }
    }
    return true;
  }

  void _removeMediaMappings(Iterable<String> assetIds) {
    final ids = assetIds.toSet();
    _photoMediaIdsByPath.removeWhere((_, assetId) => ids.contains(assetId));
  }

  Future<void> _handleStaleEquipment() async {
    final refresh = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ekipman başka bir oturumda değişti'),
        content: const Text(
          'Çakışan bir kaydı ezmemek için değişikliklerin gönderilmedi. '
          'Sunucudaki güncel ekipmanı yüklemek ister misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Bu Ekranda Kal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Güncel Kaydı Yükle'),
          ),
        ],
      ),
    );
    if (!mounted || refresh != true) return;
    await _draftMediaCleanup.discardAll();
    if (!mounted) return;
    final latest = await widget.repository.getOwnerEquipment(widget.item.id);
    if (!mounted) return;
    if (!latest.isSuccess || latest.data == null) {
      _showMessage(latest.error?.message ?? 'Güncel ekipman yüklenemedi.');
      return;
    }
    _closeWithResult(
      _BacklineInventoryItemManagementResult.updated(
        _StudioBacklineInventoryItem.fromDomain(latest.data!),
      ),
    );
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
          'gelecek müsaitlik planı artık kullanılamaz. Geçmiş değişiklik '
          'kayıtları denetim için korunur. Yine de devam etmek istiyor musunuz?',
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
      setState(() => _isSubmitting = true);
      final result = await widget.repository.archiveEquipment(
        equipmentId: widget.item.id,
        expectedVersion: widget.item.version,
      );
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      if (!result.isSuccess) {
        if (result.error?.code == '9804') {
          await _handleStaleEquipment();
          return;
        }
        _showMessage(result.error?.message ?? 'Ekipman kaldırılamadı.');
        return;
      }
      await _draftMediaCleanup.close();
      if (!mounted) return;
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
    if (shouldDiscard == true && mounted) {
      await _draftMediaCleanup.close();
      if (mounted) _closeWithResult(null);
    }
  }

  void _closeWithResult(_BacklineInventoryItemManagementResult? result) {
    if (!mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(result);
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
