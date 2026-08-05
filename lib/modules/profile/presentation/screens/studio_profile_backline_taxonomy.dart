part of 'studio_profile_screen.dart';

const _backlineQuickFilters = <String>[
  'Tümü',
  'Davul, Bateri & Zil',
  'Gitar Amfileri',
  'Bas Amfileri',
  'Piyano & Klavye',
  'Perküsyon',
];

class _BacklineCategory {
  final String id;
  final String code;
  final String? iconKey;
  final String name;
  final IconData icon;
  final String? assetPath;
  final List<String> children;
  final Map<String, String> childIdsByName;

  const _BacklineCategory({
    this.id = '',
    this.code = '',
    this.iconKey,
    required this.name,
    required this.icon,
    this.assetPath,
    required this.children,
    this.childIdsByName = const {},
  });

  factory _BacklineCategory.fromDomain(BacklineCatalogCategory category) {
    final visual = _backlineCategoryVisual(
      code: category.code,
      iconKey: category.iconKey,
      name: category.name,
    );
    return _BacklineCategory(
      id: category.id,
      code: category.code,
      iconKey: category.iconKey,
      name: category.name,
      icon: visual.icon,
      assetPath: visual.assetPath,
      children: category.children.map((child) => child.name).toList(),
      childIdsByName: {
        for (final child in category.children) child.name: child.id,
      },
    );
  }

  String? childId(String name) => childIdsByName[name];
}

class _BacklineCategoryVisual {
  final IconData icon;
  final String? assetPath;

  const _BacklineCategoryVisual(this.icon, [this.assetPath]);
}

_BacklineCategoryVisual _backlineCategoryVisual({
  required String code,
  required String? iconKey,
  required String name,
}) {
  final key = '${code.trim()} ${iconKey?.trim() ?? ''} ${name.trim()}'
      .toLowerCase();
  if (key.contains('drum') || key.contains('davul') || key.contains('zil')) {
    return const _BacklineCategoryVisual(
      Icons.album_outlined,
      'assets/backline_icons/drum-kit.png',
    );
  }
  if (key.contains('bass') || key.contains('bas gitar amfi')) {
    return const _BacklineCategoryVisual(
      Icons.speaker_group_outlined,
      'assets/backline_icons/bassamps.png',
    );
  }
  if (key.contains('guitar_amp') || key.contains('gitar amfi')) {
    return const _BacklineCategoryVisual(Icons.speaker_outlined);
  }
  if (key.contains('keyboard') ||
      key.contains('piyano') ||
      key.contains('synth')) {
    return const _BacklineCategoryVisual(
      Icons.keyboard_outlined,
      'assets/backline_icons/pianokeyboardsynth.png',
    );
  }
  if (key.contains('percussion') || key.contains('perk')) {
    return const _BacklineCategoryVisual(
      Icons.blur_circular_outlined,
      'assets/backline_icons/percussion.png',
    );
  }
  if (key.contains('guitar') ||
      key.contains('gitar') ||
      key.contains('baslar')) {
    return const _BacklineCategoryVisual(
      Icons.music_note_outlined,
      'assets/backline_icons/guitarsandbasses.png',
    );
  }
  if (key.contains('orchestra') ||
      key.contains('yaylı') ||
      key.contains('orkestra')) {
    return const _BacklineCategoryVisual(
      Icons.queue_music_outlined,
      'assets/backline_icons/stringinstruments.png',
    );
  }
  if (key.contains('dj')) {
    return const _BacklineCategoryVisual(
      Icons.graphic_eq_outlined,
      'assets/backline_icons/dj-turntable.png',
    );
  }
  if (key.contains('audio') || key.contains('stüdyo')) {
    return const _BacklineCategoryVisual(Icons.mic_none_outlined);
  }
  if (key.contains('accessor') || key.contains('aksesuar')) {
    return const _BacklineCategoryVisual(Icons.handyman_outlined);
  }
  return const _BacklineCategoryVisual(Icons.inventory_2_outlined);
}

IconData _backlineIconFor({
  required String code,
  required String? iconKey,
  required String name,
}) => _backlineCategoryVisual(code: code, iconKey: iconKey, name: name).icon;

Future<(List<_BacklineCategory>?, String?)> _loadCompleteBacklineCatalog(
  BacklineCatalogRepository repository,
) async {
  const pageSize = 100;
  const maximumPages = 100;
  final categories = <_BacklineCategory>[];
  final seenIds = <String>{};
  for (var page = 0; page < maximumPages; page++) {
    final result = await repository.listCatalog(page: page, size: pageSize);
    if (!result.isSuccess || result.data == null) {
      return (null, result.error?.message ?? 'Kategoriler yüklenemedi.');
    }
    final response = result.data!;
    for (final category in response.items) {
      if (seenIds.add(category.id)) {
        categories.add(_BacklineCategory.fromDomain(category));
      }
    }
    if (!response.hasNext) {
      return (List<_BacklineCategory>.unmodifiable(categories), null);
    }
  }
  return (
    null,
    'Kategori listesi güvenli sayfalama sınırını aştı. Lütfen tekrar dene.',
  );
}

class _BacklineCategoriesScreen extends StatefulWidget {
  final String? allSelectionValue;

  const _BacklineCategoriesScreen({this.allSelectionValue});

  @override
  State<_BacklineCategoriesScreen> createState() =>
      _BacklineCategoriesScreenState();
}

class _BacklineCategoriesScreenState extends State<_BacklineCategoriesScreen> {
  static const _pageSize = 20;
  late final BacklineCatalogRepository _repository;
  List<_BacklineCategory> _categories = const [];
  int _pageIndex = 0;
  int _totalPages = 0;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = serviceLocator<BacklineCatalogRepository>();
    _load(0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Geri',
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Tüm Backline Kategorileri',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(_pageIndex),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            if (widget.allSelectionValue != null) ...[
              _BacklineAllCategoriesTile(
                onTap: () =>
                    Navigator.of(context).pop(widget.allSelectionValue),
              ),
              const SizedBox(height: 10),
            ],
            if (_isLoading && _categories.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null && _categories.isEmpty)
              _StudioOwnerBacklineErrorState(
                message: _error!,
                onRetry: () => _load(_pageIndex),
              )
            else if (_categories.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: Text(
                    'Yayınlanmış backline kategorisi bulunmuyor.',
                    style: TextStyle(color: Color(0xFF9AA4B2)),
                  ),
                ),
              )
            else
              for (var index = 0; index < _categories.length; index++) ...[
                _BacklineCategoryTile(category: _categories[index]),
                if (index != _categories.length - 1) const SizedBox(height: 10),
              ],
            if (_isLoading && _categories.isNotEmpty) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(minHeight: 2),
            ],
            if (_totalPages > 1) ...[
              const SizedBox(height: 14),
              _StudioOwnerBacklinePagination(
                pageIndex: _pageIndex,
                totalPages: _totalPages,
                enabled: !_isLoading,
                onPrevious: _pageIndex > 0 ? () => _load(_pageIndex - 1) : null,
                onNext: _pageIndex + 1 < _totalPages
                    ? () => _load(_pageIndex + 1)
                    : null,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _load(int page) async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    final result = await _repository.listCatalog(page: page, size: _pageSize);
    if (!mounted) return;
    if (!result.isSuccess || result.data == null) {
      setState(() {
        _isLoading = false;
        _error = result.error?.message ?? 'Kategoriler yüklenemedi.';
      });
      return;
    }
    setState(() {
      _categories = result.data!.items
          .map(_BacklineCategory.fromDomain)
          .toList(growable: false);
      _pageIndex = result.data!.pageIndex;
      _totalPages = result.data!.totalPages;
      _isLoading = false;
      _error = null;
    });
  }
}

class _BacklineAllCategoriesTile extends StatelessWidget {
  final VoidCallback onTap;

  const _BacklineAllCategoriesTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF101722),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF202B3A)),
          ),
          child: const Row(
            children: [
              _StudioSocialGradientIcon(Icons.apps_rounded, size: 22),
              SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Tüm Kategoriler',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: Color(0xFF758092), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _BacklineCategoryTile extends StatelessWidget {
  final _BacklineCategory category;

  const _BacklineCategoryTile({required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF101722),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF202B3A)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        iconColor: const Color(0xFFFF8A8A),
        collapsedIconColor: const Color(0xFF9AA4B2),
        leading: _BacklineCategoryIcon(category: category),
        title: Text(
          category.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        children: [
          const Divider(height: 1, color: Color(0xFF202B3A)),
          ListTile(
            dense: true,
            contentPadding: const EdgeInsets.only(left: 54, right: 12),
            leading: const Icon(
              Icons.select_all_rounded,
              color: Color(0xFF758092),
              size: 18,
            ),
            title: Text(
              '${category.name} içindeki tüm ekipmanlar',
              style: const TextStyle(
                color: Color(0xFFD4D9E2),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            trailing: const Icon(
              Icons.chevron_right,
              color: Color(0xFF758092),
              size: 18,
            ),
            onTap: () => Navigator.of(context).pop(category.name),
          ),
          for (final subcategory in category.children)
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.only(left: 54, right: 12),
              title: Text(
                subcategory,
                style: const TextStyle(
                  color: Color(0xFFB5BDCA),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: const Icon(
                Icons.chevron_right,
                color: Color(0xFF758092),
                size: 18,
              ),
              onTap: () => Navigator.of(context).pop(subcategory),
            ),
        ],
      ),
    );
  }
}

class _BacklineCategoryIcon extends StatelessWidget {
  final _BacklineCategory category;

  const _BacklineCategoryIcon({required this.category});

  @override
  Widget build(BuildContext context) {
    final assetPath = category.assetPath;
    if (assetPath == null) {
      return _StudioSocialGradientIcon(category.icon, size: 20);
    }

    final image = Image.asset(
      assetPath,
      width: 26,
      height: 26,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) =>
          Icon(category.icon, size: 22, color: Colors.white),
    );
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) =>
          LinearGradient(colors: AppColors.brandGradient).createShader(bounds),
      child: image,
    );
  }
}
