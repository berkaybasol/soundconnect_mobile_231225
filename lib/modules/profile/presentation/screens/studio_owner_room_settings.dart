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

  const _StudioRoomSettingsScreen({required this.room});

  @override
  State<_StudioRoomSettingsScreen> createState() =>
      _StudioRoomSettingsScreenState();
}

class _StudioRoomSettingsScreenState extends State<_StudioRoomSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _capacityController;
  late final TextEditingController _hourlyPriceController;
  final _featureController = TextEditingController();
  late final List<String> _features;
  late final List<String> _photos;
  late bool _approvalRequired;
  bool _isDirty = false;
  bool _allowPop = false;
  bool _isExitDialogOpen = false;
  String? _featureError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.room.name);
    _descriptionController = TextEditingController(text: widget.room.type);
    _capacityController = TextEditingController(
      text: _firstNumber(widget.room.capacity),
    );
    _hourlyPriceController = TextEditingController(
      text: widget.room.price == 'Fiyat belirtilmedi'
          ? ''
          : _digitsOnly(widget.room.price),
    );
    _features = List.of(widget.room.features);
    _photos = widget.room.photoUrls.take(10).toList();
    _approvalRequired = widget.room.reservationApprovalRequired;
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
                  room: widget.room,
                  photos: _photos,
                  onAddPhoto: _showPhotoInfo,
                  onDeletePhoto: _deletePhoto,
                  onMovePhoto: _movePhoto,
                ),
                const SizedBox(height: 16),
                _StudioRoomApprovalPolicyCard(
                  value: _approvalRequired,
                  onChanged: (value) => setState(() {
                    _approvalRequired = value;
                    _isDirty = true;
                  }),
                ),
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
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Kapasite',
                    prefixIcon: Icon(
                      Icons.people_outline,
                      color: _roomFormIconColor,
                    ),
                    suffixText: 'kişi',
                  ),
                  validator: (value) {
                    final capacity = int.tryParse(value?.trim() ?? '');
                    if (capacity == null || capacity < 1) {
                      return 'Geçerli bir kapasite gir.';
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
                  label: 'Değişiklikleri Kaydet',
                  outlined: true,
                  onTap: _save,
                ),
                const SizedBox(height: 12),
                _StudioRoomDeleteButton(onTap: _confirmDelete),
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
    setState(() {
      _features.add(feature);
      _featureController.clear();
      _featureError = null;
      _isDirty = true;
    });
  }

  void _save() {
    final formIsValid = _formKey.currentState?.validate() == true;
    if (_features.isEmpty) {
      setState(() => _featureError = 'En az bir oda özelliği ekle.');
    }
    if (!formIsValid || _features.isEmpty) return;

    final capacity = int.parse(_capacityController.text.trim());
    final hourlyPrice = int.tryParse(_hourlyPriceController.text.trim());
    _closeWithResult(
      _StudioRoomSettingsResult.updated(
        widget.room.copyWith(
          name: _capitalizeStudioRoomText(_nameController.text),
          type: _capitalizeStudioRoomText(_descriptionController.text),
          capacity: '$capacity kişi',
          price: hourlyPrice == null
              ? 'Fiyat belirtilmedi'
              : '₺$hourlyPrice / saat',
          features: List.unmodifiable(_features),
          photoUrls: List.unmodifiable(_photos),
          reservationApprovalRequired: _approvalRequired,
        ),
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
            Expanded(child: Text('Odayı silmek istiyor musunuz?')),
          ],
        ),
        content: Text(
          '“${widget.room.name}” odasını silerseniz bu odaya bağlı '
          'rezervasyonlar, müsaitlik ayarları ve fotoğraflar da kalıcı '
          'olarak silinecek. Bu işlem geri alınamaz. Yine de devam etmek '
          'istiyor musunuz?',
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
    if (shouldDelete != true || !mounted) return;
    _closeWithResult(const _StudioRoomSettingsResult.deleted());
  }

  void _markDirty() {
    if (_isDirty || !mounted) return;
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
    if (shouldDiscard == true && mounted) _closeWithResult(null);
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
    setState(() {
      _photos.removeAt(index);
      _isDirty = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Fotoğraf kaldırıldı.'),
        action: SnackBarAction(
          label: 'Geri Al',
          onPressed: () {
            if (!mounted) return;
            final restoreIndex = index > _photos.length
                ? _photos.length
                : index;
            setState(() => _photos.insert(restoreIndex, removedPhoto));
          },
        ),
      ),
    );
  }

  void _movePhoto(int fromIndex, int toIndex) {
    if (fromIndex < 0 ||
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

  void _showPhotoInfo() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Oda fotoğrafı yükleme backend bağlantısında açılacak.'),
      ),
    );
  }

  static String _firstNumber(String value) =>
      RegExp(r'\d+').firstMatch(value)?.group(0) ?? '';

  static String _digitsOnly(String value) =>
      value.replaceAll(RegExp(r'[^0-9]'), '');
}

class _StudioRoomDeleteButton extends StatelessWidget {
  final VoidCallback onTap;

  const _StudioRoomDeleteButton({required this.onTap});

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
          'Odayı Sil',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        ),
      ),
    );
  }
}

class _StudioRoomSettingsPhotoSection extends StatefulWidget {
  final _StudioRoomItem room;
  final List<String> photos;
  final VoidCallback onAddPhoto;
  final ValueChanged<int> onDeletePhoto;
  final void Function(int fromIndex, int toIndex) onMovePhoto;

  const _StudioRoomSettingsPhotoSection({
    required this.room,
    required this.photos,
    required this.onAddPhoto,
    required this.onDeletePhoto,
    required this.onMovePhoto,
  });

  @override
  State<_StudioRoomSettingsPhotoSection> createState() =>
      _StudioRoomSettingsPhotoSectionState();
}

class _StudioRoomSettingsPhotoSectionState
    extends State<_StudioRoomSettingsPhotoSection> {
  static const _maximumPhotoCount = 10;
  final _pageController = PageController();
  int _activePhotoIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos.take(_maximumPhotoCount).toList();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1622),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF263244)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Oda Fotoğrafları',
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
                onPageChanged: (index) =>
                    setState(() => _activePhotoIndex = index),
                itemBuilder: (_, index) => index < photos.length
                    ? _StudioRoomPhotoSlot(
                        imageUrl: photos[index],
                        room: widget.room,
                        onChangePhoto: widget.onAddPhoto,
                        onDeletePhoto: () => _deletePhoto(index, photos.length),
                        onMoveLeft: index > 0
                            ? () => _movePhoto(index, index - 1)
                            : null,
                        onMoveRight: index < photos.length - 1
                            ? () => _movePhoto(index, index + 1)
                            : null,
                        onOpenPhoto: () => _openFullScreenGallery(
                          context,
                          photos: List.of(photos),
                          initialIndex: index,
                        ),
                      )
                    : _EmptyStudioRoomPhotoSlot(
                        slotNumber: index + 1,
                        onAddPhoto: widget.onAddPhoto,
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
                width: index == _activePhotoIndex ? 18 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: index == _activePhotoIndex
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

  void _openFullScreenGallery(
    BuildContext context, {
    required List<String> photos,
    required int initialIndex,
  }) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, __, ___) => _StudioRoomFullScreenGallery(
          photos: photos,
          room: widget.room,
          initialIndex: initialIndex,
        ),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
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

class _StudioRoomPhotoSlot extends StatelessWidget {
  final String imageUrl;
  final _StudioRoomItem room;
  final VoidCallback onChangePhoto;
  final VoidCallback onDeletePhoto;
  final VoidCallback? onMoveLeft;
  final VoidCallback? onMoveRight;
  final VoidCallback onOpenPhoto;

  const _StudioRoomPhotoSlot({
    required this.imageUrl,
    required this.room,
    required this.onChangePhoto,
    required this.onDeletePhoto,
    required this.onMoveLeft,
    required this.onMoveRight,
    required this.onOpenPhoto,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onTap: onOpenPhoto,
          behavior: HitTestBehavior.opaque,
          child: Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                _StudioRoomPhotoPlaceholder(room: room),
          ),
        ),
        Positioned(
          top: 10,
          left: 10,
          child: _StudioPhotoOverlayIconButton(
            icon: Icons.delete_outline_rounded,
            tooltip: 'Fotoğrafı kaldır',
            color: const Color(0xFFFF8792),
            onPressed: onDeletePhoto,
          ),
        ),
        Positioned(
          top: 10,
          right: 10,
          child: _StudioPhotoOverlayIconButton(
            icon: Icons.edit_outlined,
            tooltip: 'Fotoğrafı değiştir',
            onPressed: onChangePhoto,
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

class _StudioPhotoOverlayIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onPressed;

  const _StudioPhotoOverlayIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xD90A111B),
      shape: const CircleBorder(side: BorderSide(color: Color(0x667E8CA2))),
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        icon: Icon(icon, color: color, size: 19),
      ),
    );
  }
}

class _StudioRoomFullScreenGallery extends StatefulWidget {
  final List<String> photos;
  final _StudioRoomItem room;
  final int initialIndex;

  const _StudioRoomFullScreenGallery({
    required this.photos,
    required this.room,
    required this.initialIndex,
  });

  @override
  State<_StudioRoomFullScreenGallery> createState() =>
      _StudioRoomFullScreenGalleryState();
}

class _StudioRoomFullScreenGalleryState
    extends State<_StudioRoomFullScreenGallery> {
  late final PageController _pageController;
  late int _activeIndex;

  @override
  void initState() {
    super.initState();
    _activeIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: widget.photos.length,
              onPageChanged: (index) => setState(() => _activeIndex = index),
              itemBuilder: (_, index) => Center(
                child: Image.network(
                  widget.photos[index],
                  width: double.infinity,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      _StudioRoomPhotoPlaceholder(room: widget.room),
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: _StudioGalleryOverlayButton(
                tooltip: 'Kapat',
                icon: Icons.close_rounded,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xB30A0E15),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0x667E8CA2)),
                ),
                child: Text(
                  '${_activeIndex + 1} / ${widget.photos.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudioGalleryOverlayButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  const _StudioGalleryOverlayButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xB30A0E15),
      shape: const CircleBorder(side: BorderSide(color: Color(0x667E8CA2))),
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

class _EmptyStudioRoomPhotoSlot extends StatelessWidget {
  final int slotNumber;
  final VoidCallback onAddPhoto;

  const _EmptyStudioRoomPhotoSlot({
    required this.slotNumber,
    required this.onAddPhoto,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF111B29),
      child: InkWell(
        onTap: onAddPhoto,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF172336),
                  border: Border.all(color: const Color(0xFF3B4A60)),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                '$slotNumber. fotoğrafı ekle',
                style: const TextStyle(
                  color: Color(0xFFAAB3C2),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudioRoomApprovalPolicyCard extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _StudioRoomApprovalPolicyCard({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1622),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF263244)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.approval_outlined,
            color: _roomFormIconColor,
            size: 21,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Rezervasyonlar onay gerektirsin',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value
                      ? 'Yeni talepler onayına düşer.'
                      : 'Müsait saatler otomatik onaylanır.',
                  style: const TextStyle(
                    color: Color(0xFF98A2B1),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: const Color(0xFFFF7F87),
          ),
        ],
      ),
    );
  }
}
