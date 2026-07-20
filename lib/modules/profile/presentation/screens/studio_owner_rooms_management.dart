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

class _StudioRoomsManagementScreen extends StatefulWidget {
  const _StudioRoomsManagementScreen();

  @override
  State<_StudioRoomsManagementScreen> createState() =>
      _StudioRoomsManagementScreenState();
}

class _StudioRoomsManagementScreenState
    extends State<_StudioRoomsManagementScreen> {
  List<_StudioRoomItem> get _rooms => _studioRoomMockItems;

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
      builder: (_) => const _NewStudioRoomSheet(),
    );
    if (!mounted || room == null) return;
    _rooms.add(room);
    _notifyStudioRoomInventoryChanged();
    setState(() {});
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
            if (_rooms.isEmpty)
              _StudioRoomsEmptyState(onCreateRoom: _createRoom)
            else
              for (final room in _rooms)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _StudioRoomCard(
                    room: room,
                    canReserve: false,
                    ownerMode: true,
                    onRoomUpdated: (updated) => _replaceRoom(room, updated),
                    onRoomDeleted: () => _removeRoom(room),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  void _replaceRoom(_StudioRoomItem current, _StudioRoomItem updated) {
    final index = _rooms.indexWhere((room) => identical(room, current));
    if (index < 0) return;
    _rooms[index] = updated;
    _notifyStudioRoomInventoryChanged();
    setState(() {});
  }

  void _removeRoom(_StudioRoomItem room) {
    _rooms.removeWhere((item) => identical(item, room));
    _notifyStudioRoomInventoryChanged();
    setState(() {});
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${room.name} silindi.')));
  }
}

class _StudioRoomsEmptyState extends StatelessWidget {
  final VoidCallback? onCreateRoom;

  const _StudioRoomsEmptyState({this.onCreateRoom});

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
          const Text(
            'Stüdyonun rezervasyona açılacak ilk odasını oluşturarak başla.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF98A3B3),
              fontSize: 12,
              height: 1.4,
            ),
          ),
          if (onCreateRoom != null) ...[
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
  const _NewStudioRoomSheet();

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
  final List<String> _features = [];
  String? _featureError;

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
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
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
                const _RoomFormSectionLabel(
                  icon: Icons.meeting_room_outlined,
                  label: 'Oda Bilgileri',
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
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
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Kapasite',
                    hintText: 'Örn. 6',
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
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Vazgeç'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: _StudioActionButton(
                        icon: Icons.add_business_outlined,
                        label: 'Odayı Oluştur',
                        outlined: true,
                        onTap: _submit,
                      ),
                    ),
                  ],
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
    setState(() {
      _features.add(feature);
      _featureController.clear();
      _featureError = null;
    });
  }

  void _submit() {
    final formIsValid = _formKey.currentState?.validate() == true;
    if (_features.isEmpty) {
      setState(() => _featureError = 'En az bir oda özelliği ekle.');
    }
    if (!formIsValid || _features.isEmpty) return;
    final capacity = int.parse(_capacityController.text.trim());
    final hourlyPrice = int.tryParse(_hourlyPriceController.text.trim());
    Navigator.of(context).pop(
      _StudioRoomItem(
        name: _capitalizeStudioRoomText(_nameController.text),
        type: _capitalizeStudioRoomText(_descriptionController.text),
        capacity: '$capacity kişi',
        price: hourlyPrice == null
            ? 'Fiyat belirtilmedi'
            : '₺$hourlyPrice / saat',
        status: 'Müsait',
        statusColor: const Color(0xFF0E8F2F),
        icon: Icons.meeting_room_outlined,
        gradient: const [Color(0xFF1C2B3F), Color(0xFF4B2D52)],
        features: List.unmodifiable(_features),
      ),
    );
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
