part of 'studio_profile_screen.dart';

const _roomFormIconColor = Color(0xFFD4D9E2);

String _capitalizeStudioRoomText(String rawValue) {
  final value = rawValue.trim();
  if (value.isEmpty) return value;

  final characters = value.runes.toList(growable: false);
  final firstCharacter = String.fromCharCode(characters.first);
  final capitalizedFirstCharacter = switch (firstCharacter) {
    'i' => 'İ',
    'ı' => 'I',
    _ => firstCharacter.toUpperCase(),
  };

  return '$capitalizedFirstCharacter${String.fromCharCodes(characters.skip(1))}';
}

class _StudioRoomCapacityRange {
  const _StudioRoomCapacityRange({
    required this.minimum,
    required this.maximum,
  });

  final int minimum;
  final int maximum;

  String get label => minimum == maximum ? '$maximum' : '$minimum-$maximum';

  static _StudioRoomCapacityRange? tryParse(String rawValue) {
    final normalized = rawValue
        .trim()
        .replaceAll('–', '-')
        .replaceAll('—', '-');
    final match = RegExp(
      r'^(\d{1,3})(?:\s*-\s*(\d{1,3}))?$',
    ).firstMatch(normalized);
    if (match == null) return null;

    final minimum = int.tryParse(match.group(1) ?? '');
    final maximum = int.tryParse(match.group(2) ?? match.group(1) ?? '');
    if (minimum == null ||
        maximum == null ||
        minimum < 1 ||
        maximum > 100 ||
        minimum > maximum) {
      return null;
    }
    return _StudioRoomCapacityRange(minimum: minimum, maximum: maximum);
  }
}

class _StudioRoomsManagementScreen extends StatefulWidget {
  const _StudioRoomsManagementScreen({required this.studioProfileId});

  final String studioProfileId;

  @override
  State<_StudioRoomsManagementScreen> createState() =>
      _StudioRoomsManagementScreenState();
}

class _StudioRoomsManagementScreenState
    extends State<_StudioRoomsManagementScreen> {
  final StudioRoomRepository _repository =
      serviceLocator<StudioRoomRepository>();
  List<_StudioRoomItem> _rooms = const [];
  bool _loading = true;
  String? _errorMessage;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _createRoom() async {
    if (_rooms.length >= _maximumStudioRoomCount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('En fazla 10 oda oluşturabilirsin.')),
      );
      return;
    }
    final room = await showModalBottomSheet<_StudioRoomItem>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NewStudioRoomSheet(
        repository: _repository,
        studioProfileId: widget.studioProfileId,
      ),
    );
    if (!mounted || room == null) return;
    await _loadRooms(showLoading: false);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${room.name} oluşturuldu.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Odalar'), centerTitle: true),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Oda Yönetimi',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${_rooms.length} oda listeleniyor',
                        style: const TextStyle(
                          color: Color(0xFFA3ABB8),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF101722),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFF263244)),
                  ),
                  child: Text(
                    '${_rooms.length} / 10',
                    style: const TextStyle(
                      color: Color(0xFFD5DBE5),
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _StudioActionButton(
              icon: Icons.add_business_outlined,
              label: 'Yeni Oda Oluştur',
              outlined: true,
              onTap: _createRoom,
            ),
            const SizedBox(height: 20),
            const Text(
              'Mevcut Odalar',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 42),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null)
              _StudioRoomsErrorState(
                message: _errorMessage!,
                onRetry: _loadRooms,
              )
            else if (_rooms.isEmpty)
              _StudioRoomsEmptyState(onCreateRoom: _createRoom, ownerMode: true)
            else
              for (final room in _rooms)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _StudioRoomCard(
                    room: room,
                    profileId: widget.studioProfileId,
                    canReserve: false,
                    ownerMode: true,
                    onRoomUpdated: (_) => _loadRooms(showLoading: false),
                    onRoomDeleted: () => _loadRooms(showLoading: false),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadRooms({bool showLoading = true}) async {
    final generation = ++_loadGeneration;
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }
    final result = await _repository.listOwnerRooms(
      size: _maximumStudioRoomCount,
    );
    if (!mounted || generation != _loadGeneration) return;
    final page = result.data;
    if (!result.isSuccess || page == null) {
      setState(() {
        _loading = false;
        _errorMessage = result.error?.message ?? 'Odalar getirilemedi.';
      });
      return;
    }
    setState(() {
      _rooms = page.items
          .map(_StudioRoomItem.fromDomain)
          .toList(growable: false);
      _loading = false;
      _errorMessage = null;
    });
  }
}

class _StudioRoomsEmptyState extends StatelessWidget {
  final VoidCallback? onCreateRoom;
  final bool ownerMode;
  final bool ownerTabMode;

  const _StudioRoomsEmptyState({
    this.onCreateRoom,
    this.ownerMode = false,
    this.ownerTabMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1622),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF263244)),
      ),
      child: Column(
        children: [
          if (ownerTabMode)
            Semantics(
              button: true,
              label: 'İlk odayı oluştur',
              child: Material(
                color: Colors.transparent,
                child: Ink(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF172336),
                    border: Border.all(color: const Color(0xFF334158)),
                  ),
                  child: InkWell(
                    key: const Key('studio-owner-empty-room-create'),
                    customBorder: const CircleBorder(),
                    onTap: onCreateRoom,
                    child: const Icon(
                      Icons.add_rounded,
                      color: _roomFormIconColor,
                      size: 32,
                    ),
                  ),
                ),
              ),
            )
          else
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF172336),
                border: Border.all(color: const Color(0xFF334158)),
              ),
              child: const Icon(
                Icons.meeting_room_outlined,
                color: _roomFormIconColor,
                size: 29,
              ),
            ),
          const SizedBox(height: 14),
          const Text(
            'Henüz bir oda yok',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            ownerMode
                ? ownerTabMode
                      ? 'Henüz bir oda oluşturmadın. İlk odanı oluşturmak için + butonuna dokun.'
                      : 'Stüdyonun rezervasyona açılacak ilk odasını oluşturarak başla.'
                : 'Bu stüdyo henüz rezervasyona açık bir oda eklememiş.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF98A3B3),
              fontSize: 12,
              height: 1.4,
            ),
          ),
          if (onCreateRoom != null && !ownerTabMode) ...[
            const SizedBox(height: 18),
            SizedBox(
              width: 190,
              child: _StudioActionButton(
                icon: Icons.add_business_outlined,
                label: 'İlk Odayı Oluştur',
                outlined: true,
                onTap: onCreateRoom!,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NewStudioRoomSheet extends StatefulWidget {
  const _NewStudioRoomSheet({
    required this.repository,
    required this.studioProfileId,
  });

  final StudioRoomRepository repository;
  final String studioProfileId;

  @override
  State<_NewStudioRoomSheet> createState() => _NewStudioRoomSheetState();
}

class _NewStudioRoomSheetState extends State<_NewStudioRoomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _capacityController = TextEditingController();
  final _hourlyPriceController = TextEditingController();
  final _featureController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final List<String> _features = [];
  final List<StudioRoomPhoto> _photos = [];
  final String _clientRequestId = const Uuid().v4();
  late final DraftMediaCleanupCoordinator _draftMediaCleanup;
  String? _featureError;
  String? _submitError;
  bool _submitting = false;
  bool _photoUploading = false;
  bool _reservationApprovalRequired = true;

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
    _descriptionController.dispose();
    _capacityController.dispose();
    _hourlyPriceController.dispose();
    _featureController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return PopScope(
      canPop: !_submitting && !_photoUploading,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0B111B),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: Color(0xFF293548))),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF445064),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: const Color(0xFF151E2C),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF2D394C)),
                        ),
                        child: const Icon(
                          Icons.add_business_outlined,
                          color: _roomFormIconColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Yeni Oda Oluştur',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Odanı tanımla ve öne çıkan özelliklerini etiketle.',
                              style: TextStyle(
                                color: Color(0xFF9EA8B7),
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Kapat',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Color(0xFFB5BDCA)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _StudioRoomSettingsPhotoSection(
                    photos: _photos,
                    uploading: _photoUploading,
                    onPickPhoto: _pickPhoto,
                    onDeletePhoto: _deletePhoto,
                  ),
                  const SizedBox(height: 20),
                  const _RoomFormSectionLabel(
                    icon: Icons.meeting_room_outlined,
                    label: 'Oda Bilgileri',
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    maxLength: 100,
                    decoration: const InputDecoration(
                      labelText: 'Oda adı',
                      hintText: 'Örn. Davul Odası',
                      prefixIcon: Icon(
                        Icons.edit_outlined,
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
                      hintText: 'Örn. 750',
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
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _StudioRoomApprovalPolicyCard(
                    value: _reservationApprovalRequired,
                    onChanged: (value) {
                      setState(() => _reservationApprovalRequired = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  const _StudioRoomOnlinePaymentCard(),
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
                            onDeleted: () =>
                                setState(() => _features.remove(feature)),
                          ),
                      ],
                    ),
                  ],
                  if (_submitError != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _submitError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFFF8A94),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _submitting
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: const Text('Vazgeç'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: _StudioActionButton(
                          icon: Icons.add_business_outlined,
                          label: _submitting
                              ? 'Oluşturuluyor...'
                              : 'Odayı Oluştur',
                          outlined: true,
                          onTap: _submitting ? () {} : _submit,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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
        setState(() {
          _submitError = error.toString().replaceFirst('Exception: ', '');
        });
      }
      return;
    }
    if (cropped == null || !mounted) return;

    setState(() {
      _photoUploading = true;
      _submitError = null;
    });
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
      });
      if (_draftMediaCleanup.isTracked(replacedMediaId)) {
        await _draftMediaCleanup.discard(replacedMediaId);
      }
    } catch (error) {
      final mediaId = uploadedMediaId?.trim() ?? '';
      if (_draftMediaCleanup.isTracked(mediaId)) {
        await _draftMediaCleanup.discard(mediaId);
      }
      if (mounted) {
        setState(() {
          _submitError = error.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _photoUploading = false);
    }
  }

  void _deletePhoto(int index) {
    if (_photoUploading || index < 0 || index >= _photos.length) return;
    final removed = _photos.removeAt(index);
    setState(() {});
    final mediaId = removed.mediaAssetId?.trim() ?? '';
    if (_draftMediaCleanup.isTracked(mediaId)) {
      _draftMediaCleanup.discard(mediaId).ignore();
    }
  }

  Future<void> _submit() async {
    final formIsValid = _formKey.currentState?.validate() == true;
    if (!formIsValid || _submitting || _photoUploading) return;
    final capacityRange = _StudioRoomCapacityRange.tryParse(
      _capacityController.text,
    )!;
    final hourlyPrice = int.tryParse(_hourlyPriceController.text.trim());
    final photoIds = _photos
        .map((photo) => photo.mediaAssetId?.trim() ?? '')
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    if (photoIds.length != _photos.length) {
      setState(() {
        _submitError = 'Fotoğraflardan biri henüz yüklenmeye hazır değil.';
      });
      return;
    }
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    final result = await widget.repository.createRoom(
      StudioRoomDraft(
        name: _capitalizeStudioRoomText(_nameController.text),
        shortDescription: _capitalizeStudioRoomText(
          _descriptionController.text,
        ),
        capacity: capacityRange.maximum,
        minimumCapacity: capacityRange.minimum,
        hourlyPriceMinor: hourlyPrice == null ? null : hourlyPrice * 100,
        currency: hourlyPrice == null ? null : 'TRY',
        reservationApprovalRequired: _reservationApprovalRequired,
        features: List.unmodifiable(_features),
        photoMediaIds: photoIds,
      ),
      clientRequestId: _clientRequestId,
    );
    final room = result.data;
    if (!result.isSuccess || room == null) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = result.error?.message ?? 'Oda oluşturulamadı.';
      });
      return;
    }
    await _draftMediaCleanup.markCommitted(photoIds);
    if (!mounted) return;
    Navigator.of(context).pop(_StudioRoomItem.fromDomain(room));
  }
}

class _StudioCircularOutlineButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  const _StudioCircularOutlineButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 44,
          height: 44,
          padding: const EdgeInsets.all(0.7),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: AppColors.brandGradient),
          ),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            child: Icon(icon, color: Colors.white, size: 19),
          ),
        ),
      ),
    );
  }
}

class _RoomFormSectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;

  const _RoomFormSectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _roomFormIconColor, size: 18),
        const SizedBox(width: 7),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFE5E9F0),
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
