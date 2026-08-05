part of 'studio_profile_screen.dart';

class _StudioRoomSettingsResult {
  final _StudioRoomItem? updatedRoom;
  final bool deleted;

  const _StudioRoomSettingsResult.updated(this.updatedRoom) : deleted = false;

  const _StudioRoomSettingsResult.deleted()
    : updatedRoom = null,
      deleted = true;
}

class _StudioRoomSettingsScreen extends StatefulWidget {
  final _StudioRoomItem room;
  final String studioProfileId;

  const _StudioRoomSettingsScreen({
    required this.room,
    required this.studioProfileId,
  });

  @override
  State<_StudioRoomSettingsScreen> createState() =>
      _StudioRoomSettingsScreenState();
}

class _StudioRoomSettingsScreenState extends State<_StudioRoomSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final StudioRoomRepository _repository =
      serviceLocator<StudioRoomRepository>();
  final ImagePicker _imagePicker = ImagePicker();
  late final DraftMediaCleanupCoordinator _draftMediaCleanup;
  late _StudioRoomItem _currentRoom;
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _capacityController;
  late final TextEditingController _hourlyPriceController;
  final _featureController = TextEditingController();
  late final List<String> _features;
  late final List<StudioRoomPhoto> _photos;
  late bool _approvalRequired;
  late bool _initialApprovalSelection;
  bool _isDirty = false;
  bool _allowPop = false;
  bool _isExitDialogOpen = false;
  String? _featureError;
  bool _saving = false;
  bool _deleting = false;
  bool _deleteDialogOpen = false;
  bool _photoUploading = false;
  bool _synchronizing = false;

  @override
  void initState() {
    super.initState();
    _draftMediaCleanup = DraftMediaCleanupCoordinator(
      repository: serviceLocator<ProfileMediaUploadRepository>(),
      ownerType: 'STUDIO_PROFILE',
      ownerId: widget.studioProfileId,
    );
    _currentRoom = widget.room;
    _nameController = TextEditingController(text: _currentRoom.name);
    _descriptionController = TextEditingController(text: _currentRoom.type);
    _capacityController = TextEditingController(
      text: _StudioRoomCapacityRange(
        minimum: _currentRoom.minimumCapacityCount,
        maximum: _currentRoom.capacityCount,
      ).label,
    );
    _hourlyPriceController = TextEditingController(
      text: _currentRoom.hourlyPriceMinor == null
          ? ''
          : (_currentRoom.hourlyPriceMinor! ~/ 100).toString(),
    );
    _features = List.of(_currentRoom.features);
    _photos = _currentRoom.photos.take(10).toList();
    _approvalRequired =
        _currentRoom.pendingReservationApprovalRequired ??
        _currentRoom.reservationApprovalRequired;
    _initialApprovalSelection = _approvalRequired;
    for (final controller in [
      _nameController,
      _descriptionController,
      _capacityController,
      _hourlyPriceController,
      _featureController,
    ]) {
      controller.addListener(_markDirty);
    }
  }

  @override
  void dispose() {
    _draftMediaCleanup.close().ignore();
    _nameController.dispose();
    _descriptionController.dispose();
    _capacityController.dispose();
    _hourlyPriceController.dispose();
    _featureController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<_StudioRoomSettingsResult>(
      canPop: _allowPop || !_isDirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscardChanges();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Oda Ayarları'), centerTitle: true),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
              children: [
                _StudioRoomSettingsPhotoSection(
                  room: _currentRoom,
                  photos: _photos,
                  uploading: _photoUploading,
                  onPickPhoto: _pickPhoto,
                  onDeletePhoto: _deletePhoto,
                  onMovePhoto: _movePhoto,
                ),
                const SizedBox(height: 16),
                _StudioRoomApprovalPolicyCard(
                  value: _approvalRequired,
                  effectiveLocalDate:
                      _currentRoom.reservationApprovalPolicyEffectiveAt == null
                      ? null
                      : studioAddCivilDays(_currentRoom.todayLocalDate, 1),
                  onChanged: _requestApprovalPolicyChange,
                ),
                const SizedBox(height: 12),
                const _StudioRoomOnlinePaymentCard(),
                const SizedBox(height: 20),
                const _RoomFormSectionLabel(
                  icon: Icons.tune_outlined,
                  label: 'Temel Bilgiler',
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  maxLength: 100,
                  decoration: const InputDecoration(
                    labelText: 'Oda adı',
                    prefixIcon: Icon(
                      Icons.meeting_room_outlined,
                      color: _roomFormIconColor,
                    ),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Oda adı zorunludur.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  maxLength: 60,
                  decoration: const InputDecoration(
                    labelText: 'Kısa açıklama (opsiyonel)',
                    hintText: 'Örn. Prova',
                    prefixIcon: Icon(
                      Icons.short_text_rounded,
                      color: _roomFormIconColor,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _capacityController,
                  keyboardType: TextInputType.text,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9\-–— ]')),
                  ],
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Kapasite',
                    hintText: 'Örn. 4-6',
                    prefixIcon: Icon(
                      Icons.people_outline,
                      color: _roomFormIconColor,
                    ),
                    suffixText: 'kişi',
                  ),
                  validator: (value) {
                    if (_StudioRoomCapacityRange.tryParse(value ?? '') ==
                        null) {
                      return '1-100 arasında tek sayı veya 4-6 gibi bir aralık gir.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _hourlyPriceController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Saatlik ücret (opsiyonel)',
                    prefixIcon: Icon(
                      Icons.payments_outlined,
                      color: _roomFormIconColor,
                    ),
                    prefixText: '₺ ',
                    suffixText: '/ saat',
                  ),
                  validator: (value) {
                    final raw = value?.trim() ?? '';
                    if (raw.isEmpty) return null;
                    final price = int.tryParse(raw);
                    if (price == null || price < 1) {
                      return 'Geçerli bir saatlik ücret gir.';
                    }
                    if (price > 1000000) {
                      return 'Saatlik ücret en fazla 1.000.000 ₺ olabilir.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                const _RoomFormSectionLabel(
                  icon: Icons.sell_outlined,
                  label: 'Oda Özellikleri',
                ),
                const SizedBox(height: 6),
                const Text(
                  'Bir özellik yazıp Enter’a veya ekle butonuna bas.',
                  style: TextStyle(color: Color(0xFF8F99A9), fontSize: 12),
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
                          hintText: 'Örn. Akustik izolasyon',
                          prefixIcon: const Icon(
                            Icons.add_circle_outline,
                            color: _roomFormIconColor,
                          ),
                          errorText: _featureError,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: _StudioCircularOutlineButton(
                        tooltip: 'Özellik ekle',
                        icon: Icons.add,
                        onTap: _addFeature,
                      ),
                    ),
                  ],
                ),
                if (_features.isNotEmpty) ...[
                  const SizedBox(height: 12),
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
                  label: _saving ? 'Kaydediliyor...' : 'Değişiklikleri Kaydet',
                  outlined: true,
                  onTap: _saving || _deleting ? () {} : _save,
                ),
                const SizedBox(height: 12),
                _StudioRoomDeleteButton(
                  onTap: _saving || _deleting ? () {} : _confirmDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _addFeature() {
    final feature = _capitalizeStudioRoomText(_featureController.text);
    if (feature.isEmpty) {
      setState(() => _featureError = 'Eklemek istediğin özelliği yaz.');
      return;
    }
    if (_features.any((item) => item.toLowerCase() == feature.toLowerCase())) {
      setState(() => _featureError = 'Bu özellik zaten eklendi.');
      return;
    }
    if (_features.length >= 8) {
      setState(() => _featureError = 'En fazla 8 özellik ekleyebilirsin.');
      return;
    }
    if (feature.length > 60) {
      setState(() => _featureError = 'Özellik en fazla 60 karakter olabilir.');
      return;
    }
    setState(() {
      _features.add(feature);
      _featureController.clear();
      _featureError = null;
      _isDirty = true;
    });
  }

  Future<void> _save() async {
    final formIsValid = _formKey.currentState?.validate() == true;
    if (!formIsValid || _saving || _deleting) return;

    final capacityRange = _StudioRoomCapacityRange.tryParse(
      _capacityController.text,
    )!;
    final hourlyPrice = int.tryParse(_hourlyPriceController.text.trim());
    final photoIds = _photos
        .map((photo) => photo.mediaAssetId?.trim() ?? '')
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    if (photoIds.length != _photos.length) {
      _showError('Fotoğraflardan biri henüz yüklenmeye hazır değil.');
      return;
    }
    final submittedPhotoIdSet = photoIds.toSet();
    final potentiallyDetachedIds = _currentRoom.photos
        .map((photo) => photo.mediaAssetId?.trim() ?? '')
        .where((id) => id.isNotEmpty && !submittedPhotoIdSet.contains(id));
    final cleanupPrepared = await _draftMediaCleanup.trackPotentiallyDetached(
      potentiallyDetachedIds,
    );
    if (!mounted) return;
    if (!cleanupPrepared.isSuccess) {
      await _draftMediaCleanup.discardAll();
      if (!mounted) return;
      setState(() {
        _photos
          ..clear()
          ..addAll(_currentRoom.photos.take(10));
      });
      _showError(
        cleanupPrepared.error?.message ??
            'Fotoğraf değişikliği güvenli biçimde hazırlanamadı.',
      );
      return;
    }
    setState(() => _saving = true);
    final result = await _repository.updateRoom(
      _currentRoom.id,
      StudioRoomDraft(
        name: _capitalizeStudioRoomText(_nameController.text),
        shortDescription: _capitalizeStudioRoomText(
          _descriptionController.text,
        ),
        capacity: capacityRange.maximum,
        minimumCapacity: capacityRange.minimum,
        hourlyPriceMinor: hourlyPrice == null ? null : hourlyPrice * 100,
        currency: hourlyPrice == null ? null : 'TRY',
        reservationApprovalRequired: _approvalRequired,
        features: List.unmodifiable(_features),
        photoMediaIds: photoIds,
      ),
      expectedVersion: _currentRoom.version,
    );
    if (!mounted) return;
    final room = result.data;
    if (!result.isSuccess || room == null) {
      final cleanupReport = await _draftMediaCleanup.discardAll();
      if (!mounted) return;
      if (cleanupReport.hasProtectedReferences) {
        final latest = await _repository.getOwnerRoom(_currentRoom.id);
        if (!mounted) return;
        final latestRoom = latest.data;
        if (latest.isSuccess &&
            latestRoom != null &&
            _sameMediaIds(latestRoom.photos, photoIds)) {
          await _finishSuccessfulRoomUpdate(latestRoom);
          return;
        }
      }
      if (cleanupReport.deletedOrAbsentAssetIds.isNotEmpty) {
        setState(() {
          _photos
            ..clear()
            ..addAll(_currentRoom.photos.take(10));
          _isDirty = true;
        });
        _showError(
          'Kaydedilemeyen yeni fotoğraflar güvenle kaldırıldı. Tekrar ekleyebilirsin.',
        );
      }
      setState(() => _saving = false);
      if (isStudioStaleError(result.error)) {
        await _refreshAfterConflict();
      } else {
        _showError(result.error?.message ?? 'Oda güncellenemedi.');
      }
      return;
    }
    await _finishSuccessfulRoomUpdate(room);
  }

  Future<void> _finishSuccessfulRoomUpdate(StudioRoom room) async {
    final savedPhotoIds = room.photos
        .map((photo) => photo.mediaAssetId?.trim() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    await _draftMediaCleanup.markCommitted(savedPhotoIds);
    await _draftMediaCleanup.close();
    if (!mounted) return;
    _closeWithResult(
      _StudioRoomSettingsResult.updated(_StudioRoomItem.fromDomain(room)),
    );
  }

  Future<void> _requestApprovalPolicyChange(bool value) async {
    if (value == _approvalRequired) return;
    if (value == _initialApprovalSelection) {
      setState(() {
        _approvalRequired = value;
        _isDirty = true;
      });
      return;
    }
    final confirmed = await _confirmApprovalPolicyChange(value);
    if (!mounted || !confirmed) return;
    setState(() {
      _approvalRequired = value;
      _isDirty = true;
    });
  }

  Future<bool> _confirmApprovalPolicyChange(bool requestedValue) async {
    final cancellingScheduledChange =
        _currentRoom.pendingReservationApprovalRequired != null &&
        requestedValue == _currentRoom.reservationApprovalRequired;
    final studioToday = _currentRoom.todayLocalDate;
    final effectiveDate = studioAddCivilDays(studioToday, 1);
    final effectiveDateLabel =
        '${effectiveDate.day.toString().padLeft(2, '0')}.'
        '${effectiveDate.month.toString().padLeft(2, '0')}.'
        '${effectiveDate.year}';
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: const Color(0xFF101722),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Color(0xFF2B3546)),
            ),
            title: Row(
              children: [
                const Icon(Icons.schedule_rounded, color: _roomFormIconColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    cancellingScheduledChange
                        ? 'Planlanan değişikliği iptal et'
                        : 'Değişikliğin geçerlilik tarihi',
                  ),
                ),
              ],
            ),
            content: Text(
              cancellingScheduledChange
                  ? 'Değişiklikleri Kaydet butonuna bastığınızda daha önce '
                        'planlanan onay politikası değişikliği iptal edilecek.'
                  : 'Bu ayar Değişiklikleri Kaydet butonuna bastığınızda '
                        '$effectiveDateLabel saat 00:00’dan itibaren geçerli '
                        'olacak. Mevcut rezervasyon ve talepler oluşturuldukları '
                        'andaki onay kuralını koruyacak.',
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
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(
                  cancellingScheduledChange ? 'Planı İptal Et' : 'Anladım',
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  bool _sameMediaIds(List<StudioRoomPhoto> photos, List<String> expectedIds) {
    final actualIds = photos
        .map((photo) => photo.mediaAssetId?.trim() ?? '')
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    if (actualIds.length != expectedIds.length) return false;
    for (var index = 0; index < actualIds.length; index++) {
      if (actualIds[index] != expectedIds[index]) return false;
    }
    return true;
  }

  Future<void> _confirmDelete() async {
    if (_saving || _deleting || _deleteDialogOpen) return;
    _deleteDialogOpen = true;
    bool? shouldDelete;
    try {
      shouldDelete = await showDialog<bool>(
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
              Expanded(child: Text('Odayı silmek istiyor musunuz?')),
            ],
          ),
          content: Text(
            '“${_currentRoom.name}” odasını silerseniz oda erişime kapanır; '
            'gelecek rezervasyonlar iptal edilir, müsaitlik kayıtları kaldırılır '
            've fotoğraf bağlantıları çözülür. Geçmiş işlem kayıtları güvenlik '
            've denetim amacıyla korunur. Bu işlem geri alınamaz. Yine de devam '
            'etmek istiyor musunuz?',
            style: const TextStyle(
              color: Color(0xFFB8C0CC),
              fontSize: 14,
              height: 1.45,
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Vazgeç'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD84A5A),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.delete_outline_rounded, size: 19),
              label: const Text('Odayı Sil'),
            ),
          ],
        ),
      );
    } finally {
      _deleteDialogOpen = false;
    }
    if (shouldDelete != true || !mounted) return;
    setState(() => _deleting = true);
    final result = await _repository.archiveRoom(
      _currentRoom.id,
      expectedVersion: _currentRoom.version,
    );
    if (!mounted) return;
    setState(() => _deleting = false);
    if (!result.isSuccess) {
      if (isStudioStaleError(result.error)) {
        await _refreshAfterConflict();
      } else {
        _showError(result.error?.message ?? 'Oda silinemedi.');
      }
      return;
    }
    await _draftMediaCleanup.close();
    if (!mounted) return;
    _closeWithResult(const _StudioRoomSettingsResult.deleted());
  }

  void _markDirty() {
    if (_synchronizing || _isDirty || !mounted) return;
    setState(() => _isDirty = true);
  }

  Future<void> _confirmDiscardChanges() async {
    if (_isExitDialogOpen) return;
    _isExitDialogOpen = true;
    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF101722),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF293548)),
        ),
        title: const Text('Değişiklikler kaydedilmedi'),
        content: const Text(
          'Bu ekrandan çıkarsanız oda ayarlarında yaptığınız değişiklikler '
          'kaybolacak. Yine de çıkmak istiyor musunuz?',
          style: TextStyle(
            color: Color(0xFFB8C0CC),
            fontSize: 14,
            height: 1.45,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
    _isExitDialogOpen = false;
    if (shouldDiscard == true && mounted) {
      await _draftMediaCleanup.close();
      if (mounted) _closeWithResult(null);
    }
  }

  void _closeWithResult(_StudioRoomSettingsResult? result) {
    if (!mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(result);
    });
  }

  void _deletePhoto(int index) {
    if (index < 0 || index >= _photos.length) return;
    final removedPhoto = _photos[index];
    var restored = false;
    setState(() {
      _photos.removeAt(index);
      _isDirty = true;
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(
          SnackBar(
            content: const Text('Fotoğraf kaldırıldı.'),
            action: SnackBarAction(
              label: 'Geri Al',
              onPressed: () {
                if (!mounted) return;
                restored = true;
                final restoreIndex = index > _photos.length
                    ? _photos.length
                    : index;
                setState(() => _photos.insert(restoreIndex, removedPhoto));
              },
            ),
          ),
        )
        .closed
        .then((_) {
          final mediaId = removedPhoto.mediaAssetId?.trim() ?? '';
          if (!restored && _draftMediaCleanup.isTracked(mediaId)) {
            _draftMediaCleanup.discard(mediaId).ignore();
          }
        });
  }

  void _movePhoto(int fromIndex, int toIndex) {
    if (_photoUploading ||
        fromIndex < 0 ||
        fromIndex >= _photos.length ||
        toIndex < 0 ||
        toIndex >= _photos.length ||
        fromIndex == toIndex) {
      return;
    }
    setState(() {
      final photo = _photos.removeAt(fromIndex);
      _photos.insert(toIndex, photo);
      _isDirty = true;
    });
  }

  Future<void> _pickPhoto(int? replaceIndex) async {
    if (_photoUploading || (replaceIndex == null && _photos.length >= 10)) {
      return;
    }
    CroppedFile? cropped;
    try {
      cropped = await pickAndCropProfileImage(
        imagePicker: _imagePicker,
        cropTitle: 'Oda fotoğrafını kırp',
        aspectRatio: const CropAspectRatio(ratioX: 16, ratioY: 10),
      );
    } catch (error) {
      if (mounted) {
        _showError(error.toString().replaceFirst('Exception: ', ''));
      }
      return;
    }
    if (cropped == null || !mounted) return;
    setState(() => _photoUploading = true);
    String? uploadedMediaId;
    try {
      final fileName = fileNameFromPath(
        cropped.path,
        fallback: 'room-photo.jpg',
      );
      final source = await createProfileUploadSource(filePath: cropped.path);
      final uploaded = await uploadProfileMediaAsset(
        source: source,
        ownerType: 'STUDIO_PROFILE',
        ownerId: widget.studioProfileId,
        mediaKind: 'IMAGE',
        mimeType: inferImageMimeType(fileName),
        originalFileName: fileName,
        attachmentIntent: const ProfileUploadAttachmentIntent.draft(),
      );
      final mediaId = uploaded.uuid.trim();
      uploadedMediaId = mediaId;
      final url = (uploaded.sourceUrl ?? uploaded.playbackUrl)?.trim() ?? '';
      if (mediaId.isNotEmpty) {
        final tracked = await _draftMediaCleanup.trackUploaded(mediaId);
        if (!tracked.isSuccess) {
          throw Exception(
            tracked.error?.message ??
                'Fotoğraf güvenli temizleme sırasına alınamadı.',
          );
        }
      }
      if (mediaId.isEmpty || url.isEmpty) {
        throw Exception('Yüklenen fotoğrafın medya bilgisi alınamadı.');
      }
      if (!mounted) {
        await _draftMediaCleanup.discard(mediaId);
        return;
      }
      final replacedMediaId =
          replaceIndex != null && replaceIndex < _photos.length
          ? _photos[replaceIndex].mediaAssetId?.trim() ?? ''
          : '';
      setState(() {
        final photo = StudioRoomPhoto(
          mediaAssetId: mediaId,
          url: url,
          orderIndex: replaceIndex ?? _photos.length,
        );
        if (replaceIndex != null && replaceIndex < _photos.length) {
          _photos[replaceIndex] = photo;
        } else {
          _photos.add(photo);
        }
        _isDirty = true;
      });
      if (_draftMediaCleanup.isTracked(replacedMediaId)) {
        _draftMediaCleanup.discard(replacedMediaId).ignore();
      }
    } catch (error) {
      final mediaId = uploadedMediaId?.trim() ?? '';
      if (_draftMediaCleanup.isTracked(mediaId)) {
        await _draftMediaCleanup.discard(mediaId);
      }
      if (mounted) {
        _showError(error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _photoUploading = false);
    }
  }

  Future<void> _refreshAfterConflict() async {
    final result = await _repository.getOwnerRoom(_currentRoom.id);
    if (!mounted) return;
    final refreshed = result.data;
    if (!result.isSuccess || refreshed == null) {
      _showError(
        result.error?.message ??
            'Oda başka bir oturumda değişti. Güncel kayıt alınamadı.',
      );
      return;
    }
    final shouldReload = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF101722),
        title: const Text('Oda bilgileri değişti'),
        content: const Text(
          'Bu oda başka bir oturumda güncellendi. Güncel bilgileri yükleyip '
          'düzenlemeye devam edebilirsin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Şimdi Değil'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Güncel Bilgileri Yükle'),
          ),
        ],
      ),
    );
    if (shouldReload == true && mounted) {
      _applyRefreshedRoom(_StudioRoomItem.fromDomain(refreshed));
    }
  }

  void _applyRefreshedRoom(_StudioRoomItem room) {
    _synchronizing = true;
    _nameController.text = room.name;
    _descriptionController.text = room.type;
    _capacityController.text = _StudioRoomCapacityRange(
      minimum: room.minimumCapacityCount,
      maximum: room.capacityCount,
    ).label;
    _hourlyPriceController.text = room.hourlyPriceMinor == null
        ? ''
        : (room.hourlyPriceMinor! ~/ 100).toString();
    _synchronizing = false;
    setState(() {
      _currentRoom = room;
      _features
        ..clear()
        ..addAll(room.features);
      _photos
        ..clear()
        ..addAll(room.photos);
      _approvalRequired =
          room.pendingReservationApprovalRequired ??
          room.reservationApprovalRequired;
      _initialApprovalSelection = _approvalRequired;
      _isDirty = false;
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
