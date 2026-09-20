import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../shared/images/app_cached_network_image.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/gradient_outline_button.dart';
import '../../../dm/presentation/screens/dm_chat_screen.dart';
import '../../../location/domain/entities/city.dart';
import '../../../location/domain/entities/district.dart';
import '../../../location/domain/location_repository.dart';
import '../../../location/presentation/widgets/location_picker_sheet.dart';
import '../../../profile/domain/draft_media_cleanup_coordinator.dart';
import '../../../profile/domain/profile_media_upload_repository.dart';
import '../../../profile/presentation/screens/profile_route_args.dart';
import '../../domain/marketplace_models.dart';
import '../../domain/marketplace_repository.dart';
import '../marketplace_access_gate.dart';
import '../marketplace_browse_controller.dart';
import '../marketplace_category_picker.dart';
import '../marketplace_photo.dart';
import '../marketplace_visual_theme.dart';

part 'marketplace_collection_screen.dart';
part 'marketplace_detail_screen.dart';
part 'marketplace_editor_screen.dart';
part 'marketplace_widgets.dart';

class MarketplaceScreen extends StatelessWidget {
  const MarketplaceScreen({
    this.bottomNavigationBar,
    this.initialListingId,
    this.repository,
    this.locationRepository,
    super.key,
  });
  final Widget? bottomNavigationBar;
  final String? initialListingId;
  final MarketplaceRepository? repository;
  final LocationRepository? locationRepository;
  @override
  Widget build(BuildContext context) => MarketplaceThemeScope(
    child: MarketplaceAccessGate(
      builder: (_) => _MarketplaceHome(
        bottomNavigationBar: bottomNavigationBar,
        initialListingId: initialListingId,
        repository: repository ?? serviceLocator<MarketplaceRepository>(),
        locationRepository:
            locationRepository ?? serviceLocator<LocationRepository>(),
      ),
    ),
  );
}

class _MarketplaceHome extends StatefulWidget {
  const _MarketplaceHome({
    required this.repository,
    required this.locationRepository,
    this.bottomNavigationBar,
    this.initialListingId,
  });
  final MarketplaceRepository repository;
  final LocationRepository locationRepository;
  final Widget? bottomNavigationBar;
  final String? initialListingId;
  @override
  State<_MarketplaceHome> createState() => _MarketplaceHomeState();
}

class _MarketplaceHomeState extends State<_MarketplaceHome> {
  late final _browse = MarketplaceBrowseController(
    widget.repository,
    canAct: () => marketplaceCanAct(context),
  );
  final _search = TextEditingController();
  Timer? _debounce;
  List<MarketplaceCategory> _categories = const [];
  List<City> _cities = const [];
  bool _catalogLoading = true;
  String? _catalogError;
  @override
  void initState() {
    super.initState();
    unawaited(_browse.refresh());
    unawaited(_loadCatalogs());
    final initialId = widget.initialListingId;
    if (initialId != null && initialId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && marketplaceCanAct(context)) unawaited(_open(initialId));
      });
    }
  }

  Future<void> _loadCatalogs() async {
    if (!marketplaceCanAct(context)) return;
    setState(() {
      _catalogLoading = true;
      _catalogError = null;
    });
    final results = await Future.wait([
      widget.repository.getCategories(),
      widget.locationRepository.getCities(),
    ]);
    if (!mounted || !marketplaceCanAct(context)) return;
    final categories = results[0];
    final cities = results[1];
    setState(() {
      _catalogLoading = false;
      if (categories.isSuccess && cities.isSuccess) {
        _categories = categories.data! as List<MarketplaceCategory>;
        _cities = cities.data! as List<City>;
      } else {
        _catalogError =
            categories.error?.message ??
            cities.error?.message ??
            'Filtreler yüklenemedi.';
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _browse.dispose();
    super.dispose();
  }

  void _searchChanged(String value) {
    if (!marketplaceCanAct(context)) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted && marketplaceCanAct(context)) {
        _browse.query = _browse.query.withSearch(value);
        unawaited(_browse.refresh());
      }
    });
  }

  Future<void> _open(String id) async {
    if (!marketplaceCanAct(context)) return;
    FocusManager.instance.primaryFocus?.unfocus();
    await Navigator.of(context).push<void>(
      marketplaceRoute(
        context,
        (_) => _MarketplaceDetail(
          repository: widget.repository,
          locationRepository: widget.locationRepository,
          listingId: id,
        ),
      ),
    );
    if (mounted && marketplaceCanAct(context)) unawaited(_browse.refresh());
  }

  Future<void> _create() async {
    if (!marketplaceCanAct(context)) return;
    FocusManager.instance.primaryFocus?.unfocus();
    await Navigator.of(context).push<void>(
      marketplaceRoute(
        context,
        (_) => _MarketplaceEditor(
          repository: widget.repository,
          locationRepository: widget.locationRepository,
        ),
      ),
    );
    if (mounted && marketplaceCanAct(context)) unawaited(_browse.refresh());
  }

  Future<void> _collection(MarketplaceCollection collection) async {
    if (!marketplaceCanAct(context)) return;
    FocusManager.instance.primaryFocus?.unfocus();
    await Navigator.of(context).push<void>(
      marketplaceRoute(
        context,
        (_) => _MarketplaceCollectionScreen(
          repository: widget.repository,
          locationRepository: widget.locationRepository,
          collection: collection,
        ),
      ),
    );
    if (mounted && marketplaceCanAct(context)) unawaited(_browse.refresh());
  }

  Future<void> _filters() async {
    if (!marketplaceCanAct(context)) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final query = await marketplaceSheet<MarketplaceQuery>(
      context,
      (_) => _MarketplaceFilters(
        query: _browse.query.withSearch(_search.text),
        categories: _categories,
        cities: _cities,
        locationRepository: widget.locationRepository,
      ),
    );
    if (!mounted || !marketplaceCanAct(context) || query == null) return;
    _debounce?.cancel();
    _browse.query = query;
    unawaited(_browse.refresh());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      titleSpacing: 20,
      title: const Text(
        'Ekipman Pazarı',
        maxLines: 2,
        style: TextStyle(height: 1.1),
      ),
      toolbarHeight: 68,
      actions: [
        _MarketplaceIconAction(
          tooltip: 'Kaydettiklerim',
          onPressed: () => _collection(MarketplaceCollection.saved),
          icon: Icons.bookmark_border_rounded,
        ),
        const SizedBox(width: 8),
        _MarketplaceIconAction(
          tooltip: 'İlanlarım',
          onPressed: () => _collection(MarketplaceCollection.mine),
          icon: Icons.inventory_2_outlined,
        ),
        const SizedBox(width: 18),
      ],
    ),
    bottomNavigationBar: widget.bottomNavigationBar,
    floatingActionButton: _MarketplaceCreateButton(onPressed: _create),
    body: AnimatedBuilder(
      animation: _browse,
      builder: (context, _) => RefreshIndicator(
        onRefresh: _browse.refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _MarketplaceIntro(),
                    const SizedBox(height: 10),
                    Text(
                      'Enstrüman, ses ve sahne ekipmanı',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _search,
                            onChanged: _searchChanged,
                            maxLength: 100,
                            style: const TextStyle(fontSize: 14),
                            textInputAction: TextInputAction.search,
                            decoration:
                                _decoration(
                                  'Ekipman ara',
                                  icon: Icons.search_rounded,
                                ).copyWith(
                                  labelText: null,
                                  hintText: 'Ürün, marka veya model',
                                  counterText: '',
                                  suffixIcon: _search.text.isEmpty
                                      ? null
                                      : IconButton(
                                          tooltip: 'Aramayı temizle',
                                          onPressed: () {
                                            _search.clear();
                                            _searchChanged('');
                                          },
                                          icon: const Icon(Icons.close_rounded),
                                        ),
                                ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Badge(
                          isLabelVisible: _browse.query.hasFilters,
                          child: _MarketplaceIconAction(
                            tooltip: 'Filtreler ve sıralama',
                            onPressed: _catalogLoading || _catalogError != null
                                ? null
                                : _filters,
                            icon: Icons.tune_rounded,
                            highlighted: _browse.query.hasFilters,
                            size: 54,
                          ),
                        ),
                      ],
                    ),
                    if (_catalogLoading)
                      const Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: LinearProgressIndicator(),
                      ),
                    if (_catalogError != null)
                      _MarketplaceError(
                        message: _catalogError!,
                        retry: _loadCatalogs,
                      ),
                    if (!_catalogLoading && _catalogError == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: LayoutBuilder(
                          builder: (context, constraints) => Row(
                            children: [
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: constraints.maxWidth * .58,
                                ),
                                child: ChoiceChip(
                                  key: const Key('marketplace-all-categories'),
                                  tooltip: 'Tüm kategorileri aç',
                                  avatar: const Icon(
                                    Icons.grid_view_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Kategoriler'),
                                  showCheckmark: false,
                                  selected: _browse.query.categoryId != null,
                                  onSelected: (_) => _openCategory(),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: SingleChildScrollView(
                                  key: const Key(
                                    'marketplace-quick-categories',
                                  ),
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      for (final category in _categories)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            right: 8,
                                          ),
                                          child: ChoiceChip(
                                            label: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(category.name),
                                                const SizedBox(width: 5),
                                                const Icon(
                                                  Icons.expand_more_rounded,
                                                  size: 17,
                                                ),
                                              ],
                                            ),
                                            selected:
                                                _browse.query.categoryId ==
                                                    category.id ||
                                                category.children.any(
                                                  (child) =>
                                                      child.id ==
                                                      _browse.query.categoryId,
                                                ),
                                            onSelected: (_) =>
                                                _openCategory(category),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (_selectedLeafPath != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          _selectedLeafPath!,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    if (_browse.query.hasFilters)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: TextButton.icon(
                          onPressed: () {
                            _browse.query = MarketplaceQuery(
                              search: _search.text,
                            );
                            unawaited(_browse.refresh());
                          },
                          icon: const Icon(Icons.filter_alt_off_outlined),
                          label: const Text('Filtreleri temizle'),
                        ),
                      ),
                    if (!_browse.loading &&
                        _browse.error == null &&
                        _browse.items.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 24, bottom: 10),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'İlanları keşfet',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Text(
                              '${_browse.totalElements} ilan',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            ..._listingSlivers(
              context,
              _browse,
              onOpen: _open,
              empty: _browse.query.search.isNotEmpty || _browse.query.hasFilters
                  ? 'Bu aramaya uygun ilan bulunamadı.'
                  : 'Pazarın ilk ilanı senin olabilir.',
              onEmptyAction: _create,
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 110)),
          ],
        ),
      ),
    ),
  );
  String? get _selectedLeafPath =>
      _categories.any(
        (root) =>
            root.children.any((leaf) => leaf.id == _browse.query.categoryId),
      )
      ? marketplaceCategoryLabel(_categories, _browse.query.categoryId)
      : null;

  Future<void> _openCategory([MarketplaceCategory? category]) async {
    if (!marketplaceCanAct(context)) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final id = await showMarketplaceCategoryPicker(
      context,
      categories: _categories,
      selectedId: _browse.query.categoryId,
      initialRootId: category?.id,
      startAtRoot: category == null,
    );
    if (!mounted || !marketplaceCanAct(context) || id == null) return;
    _selectCategory(id.isEmpty ? null : id);
  }

  void _selectCategory(String? id) {
    if (!marketplaceCanAct(context)) return;
    _debounce?.cancel();
    final q = _browse.query;
    _browse.query = MarketplaceQuery(
      search: _search.text,
      categoryId: id,
      cityId: q.cityId,
      districtId: q.districtId,
      condition: q.condition,
      minPriceMinor: q.minPriceMinor,
      maxPriceMinor: q.maxPriceMinor,
      sort: q.sort,
    );
    unawaited(_browse.refresh());
  }
}
