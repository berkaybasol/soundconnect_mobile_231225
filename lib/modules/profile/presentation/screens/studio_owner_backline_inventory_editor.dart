part of 'studio_profile_screen.dart';

class _NewBacklineInventoryItemSheet extends StatefulWidget {
  final String studioProfileId;
  final StudioEquipmentRepository repository;
  final List<_BacklineCategory> categories;

  const _NewBacklineInventoryItemSheet({
    required this.studioProfileId,
    required this.repository,
    required this.categories,
  });

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
  final Map<String, String> _photoMediaIdsByPath = {};
  final ImagePicker _imagePicker = ImagePicker();
  late final DraftMediaCleanupCoordinator _draftMediaCleanup;
  String _clientRequestId = const Uuid().v4();
  _BacklineCategory? _selectedCategory;
  String? _selectedSubcategory;
  String? _featureError;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _draftMediaCleanup = DraftMediaCleanupCoordinator(
      repository: serviceLocator<ProfileMediaUploadRepository>(),
      ownerType: 'STUDIO_PROFILE',
      ownerId: widget.studioProfileId,
    );
  }

  @override
  void dispose() {
    _draftMediaCleanup.close().ignore();
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
                      onPressed: _isSubmitting ? null : _discardAndClose,
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
                          for (final category in widget.categories)
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
                        icon: _isSubmitting
                            ? Icons.hourglass_top_rounded
                            : Icons.add_business_outlined,
                        label: _isSubmitting
                            ? 'Ekipman Ekleniyor...'
                            : 'Ekipmanı Envantere Ekle',
                        outlined: true,
                        onTap: _isSubmitting ? () {} : _submit,
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

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (_formKey.currentState?.validate() != true) return;
    final category = _selectedCategory!;
    final subcategory = _selectedSubcategory!;
    final leafCategoryId = category.childId(subcategory);
    if (leafCategoryId == null || leafCategoryId.isEmpty) {
      _showMessage(
        'Seçilen alt kategori güncel değil. Kategorileri yenileyip tekrar dene.',
      );
      return;
    }
    final quantity = int.parse(_quantityController.text.trim());
    final brand = _capitalizeStudioRoomText(_brandController.text);
    final model = _capitalizeStudioRoomText(_modelController.text);
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
    final command = CreateStudioEquipmentCommand(
      clientRequestId: _clientRequestId,
      leafCategoryId: leafCategoryId,
      name: _capitalizeStudioRoomText(_nameController.text),
      brand: brand,
      model: model,
      description: _capitalizeStudioRoomText(_descriptionController.text),
      totalQuantity: quantity,
      features: List.unmodifiable(_features),
      photoMediaIds: submittedPhotoIds,
    );
    final result = await widget.repository.createEquipment(command);
    if (!mounted) return;
    if (!result.isSuccess || result.data == null) {
      if (!studioMutationOutcomeMayBeAmbiguous(result.error)) {
        await _cleanupDeterministicCreateFailure();
        if (!mounted) return;
      }
      setState(() => _isSubmitting = false);
      _showMessage(result.error?.message ?? 'Ekipman eklenemedi.');
      return;
    }
    await _draftMediaCleanup.markCommitted(submittedPhotoIds);
    await _draftMediaCleanup.close();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pop(_StudioBacklineInventoryItem.fromDomain(result.data!));
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
      } catch (error) {
        for (final assetId in uploadedThisAttempt) {
          await _draftMediaCleanup.discard(assetId);
        }
        _removeMediaMappings(uploadedThisAttempt);
        if (mounted) {
          _showMessage('Fotoğraf yüklenemedi. Lütfen tekrar dene.');
        }
        return false;
      }
    }
    return true;
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
    final replacedMediaId = _photoMediaIdsByPath[_photoPaths[index]];
    setState(() {
      _photoMediaIdsByPath.remove(_photoPaths[index]);
      _photoPaths[index] = selected.path;
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
    });
    if (removedMediaId != null &&
        _draftMediaCleanup.isTracked(removedMediaId)) {
      _draftMediaCleanup.discard(removedMediaId).ignore();
    }
  }

  Future<void> _cleanupDeterministicCreateFailure() async {
    final pendingIds = _draftMediaCleanup.pendingAssetIds;
    final report = await _draftMediaCleanup.discardAll();
    if (report.hasFailures || report.hasProtectedReferences) return;
    _removeMediaMappings(pendingIds);
    _clientRequestId = const Uuid().v4();
  }

  void _removeMediaMappings(Iterable<String> assetIds) {
    final ids = assetIds.toSet();
    _photoMediaIdsByPath.removeWhere((_, assetId) => ids.contains(assetId));
  }

  Future<void> _discardAndClose() async {
    await _draftMediaCleanup.close();
    if (mounted) Navigator.of(context).pop();
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

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
