part of 'studio_profile_screen.dart';

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

class _BacklineCategoryRequestSheet extends StatefulWidget {
  final List<_BacklineCategory> categories;

  const _BacklineCategoryRequestSheet({required this.categories});

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
  final String _clientRequestId = const Uuid().v4();
  _BacklineCategoryRequestType _type = _BacklineCategoryRequestType.category;
  _BacklineCategory? _parentCategory;
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
                  DropdownButtonFormField<_BacklineCategory>(
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
                      for (final category in widget.categories)
                        DropdownMenuItem(
                          value: category,
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
      CreateBacklineCategoryRequestCommand(
        clientRequestId: _clientRequestId,
        type: _type == _BacklineCategoryRequestType.category
            ? BacklineCategoryRequestType.rootCategory
            : BacklineCategoryRequestType.subcategory,
        name: _capitalizeStudioRoomText(_nameController.text),
        parentCategoryId: _parentCategory?.id,
        proposedChildren: List.unmodifiable(_proposedSubcategories),
        requesterNote: _capitalizeStudioRoomText(_noteController.text),
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
  final BacklineCategoryRequest request;
  final VoidCallback? onWithdraw;

  const _BacklineSubmittedCategoryRequestCard({
    required this.request,
    required this.onWithdraw,
  });

  @override
  Widget build(BuildContext context) {
    final isSubcategory =
        request.type == BacklineCategoryRequestType.subcategory;
    final statusColor = switch (request.status) {
      BacklineCategoryRequestStatus.pending => const Color(0xFFF09BC7),
      BacklineCategoryRequestStatus.approved => const Color(0xFF75D7A3),
      BacklineCategoryRequestStatus.rejected => const Color(0xFFFF8792),
      BacklineCategoryRequestStatus.withdrawn => const Color(0xFF9EA8B7),
      BacklineCategoryRequestStatus.unknown => const Color(0xFF9EA8B7),
    };
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
                  request.requestedName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (request.parentCategoryName != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    request.parentCategoryName!,
                    style: const TextStyle(
                      color: Color(0xFF8F9AAA),
                      fontSize: 11,
                    ),
                  ),
                ],
                if (request.proposedChildren.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    '${request.proposedChildren.length} alt kategori önerisi',
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  _categoryRequestStatusLabel(request.status),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (onWithdraw != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Talebi geri çek',
                  onPressed: onWithdraw,
                  icon: const Icon(Icons.undo_rounded, size: 18),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _categoryRequestStatusLabel(
    BacklineCategoryRequestStatus status,
  ) => switch (status) {
    BacklineCategoryRequestStatus.pending => 'İncelemede',
    BacklineCategoryRequestStatus.approved => 'Onaylandı',
    BacklineCategoryRequestStatus.rejected => 'Reddedildi',
    BacklineCategoryRequestStatus.withdrawn => 'Geri Çekildi',
    BacklineCategoryRequestStatus.unknown => 'Bilinmiyor',
  };
}
