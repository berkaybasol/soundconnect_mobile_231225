import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/utils/turkish_alphabetical.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/gradient_text_field.dart';
import '../../../instrument/domain/entities/instrument.dart';
import '../../../instrument/domain/instrument_repository.dart';
import '../../../location/domain/entities/city.dart';
import '../../../location/domain/location_repository.dart';
import '../../../profile/presentation/screens/profile_public_bottom_bar.dart';
import '../../domain/collab_commands.dart';
import '../../domain/collab_discovery_models.dart';
import '../../domain/collab_types.dart';
import '../../domain/entities/collab_listing.dart';
import '../collab_route_args.dart';
import '../cubit/collab_async_state.dart';
import '../cubit/collab_discovery_cubit.dart';
import '../cubit/collab_discovery_state.dart';
import '../theme/collab_visual_theme.dart';
import '../widgets/collab_discovery_widgets.dart';
import 'collab_create_listing_screen.dart';
import 'collab_incoming_applications_screen.dart';
import 'collab_listing_detail_screen.dart';
import 'collab_my_applications_screen.dart';
import 'collab_my_listings_screen.dart';
import 'collab_saved_listings_screen.dart';

class CollabDiscoveryScreen extends StatefulWidget {
  const CollabDiscoveryScreen({
    this.showBottomNavigation = true,
    this.initialListingId,
    this.initialRouteArgs,
    this.cubit,
    this.locationRepository,
    this.instrumentRepository,
    super.key,
  });

  final bool showBottomNavigation;
  final String? initialListingId;
  final CollabDiscoveryRouteArgs? initialRouteArgs;
  final CollabDiscoveryCubit? cubit;
  final LocationRepository? locationRepository;
  final InstrumentRepository? instrumentRepository;

  @override
  State<CollabDiscoveryScreen> createState() => _CollabDiscoveryScreenState();
}

class _CollabDiscoveryScreenState extends State<CollabDiscoveryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final CollabDiscoveryCubit _cubit;
  late final bool _ownsCubit;
  late final LocationRepository _locationRepository;
  late final InstrumentRepository _instrumentRepository;
  List<City> _cities = const <City>[];
  List<Instrument> _instruments = const <Instrument>[];
  bool _catalogsLoading = true;
  String? _cityCatalogError;
  String? _instrumentCatalogError;
  String? _openedInitialTargetSignature;

  @override
  void initState() {
    super.initState();
    _ownsCubit = widget.cubit == null;
    _cubit = widget.cubit ?? serviceLocator<CollabDiscoveryCubit>();
    _locationRepository =
        widget.locationRepository ?? serviceLocator<LocationRepository>();
    _instrumentRepository =
        widget.instrumentRepository ?? serviceLocator<InstrumentRepository>();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
    unawaited(_cubit.loadInitial());
    _scheduleInitialDetail();
    unawaited(_loadCatalogs());
  }

  @override
  void didUpdateWidget(covariant CollabDiscoveryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_routeArgsFor(oldWidget).signature != _routeArgsFor(widget).signature) {
      _scheduleInitialDetail();
    }
  }

  void _scheduleInitialDetail() {
    final args = _routeArgsFor(widget);
    if (args.target == CollabDeepLinkTarget.discovery) return;
    if (_openedInitialTargetSignature == args.signature) return;
    _openedInitialTargetSignature = args.signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_openInitialTarget(args));
    });
  }

  CollabDiscoveryRouteArgs _routeArgsFor(CollabDiscoveryScreen screen) =>
      screen.initialRouteArgs ??
      CollabDiscoveryRouteArgs(initialListingId: screen.initialListingId);

  Future<void> _openInitialTarget(CollabDiscoveryRouteArgs args) async {
    switch (args.target) {
      case CollabDeepLinkTarget.discovery:
        return;
      case CollabDeepLinkTarget.listing:
        final listingId = args.initialListingId;
        if (listingId != null) await _openListingId(listingId);
        return;
      case CollabDeepLinkTarget.incomingApplications:
        final listingId = args.initialListingId;
        if (listingId != null) {
          await Navigator.of(context).push<void>(
            collabPageRoute(
              builder: (_) => CollabIncomingApplicationsScreen(
                listingId: listingId,
                initialApplicationId: args.applicationId,
                showBottomNavigation: widget.showBottomNavigation,
              ),
            ),
          );
        }
        return;
      case CollabDeepLinkTarget.myApplications:
        await _openMyApplicationsTarget(
          initialSection: CollabApplicationsSection.applications,
          initialApplicationId: args.applicationId,
        );
        return;
      case CollabDeepLinkTarget.jobs:
        await _openMyApplicationsTarget(
          initialSection: CollabApplicationsSection.jobs,
          initialJobId: args.jobId,
          initialAction: args.action,
        );
        return;
      case CollabDeepLinkTarget.reviews:
        await _openMyApplicationsTarget(
          initialSection: CollabApplicationsSection.jobs,
          initialJobId: args.jobId,
          initialReviewId: args.reviewId,
          initialAction: args.action,
        );
        return;
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    if (_ownsCubit) unawaited(_cubit.close());
    super.dispose();
  }

  void _onSearchChanged() {
    _cubit.setSearchQuery(_searchController.text);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 420) {
      unawaited(_cubit.loadMore());
    }
  }

  Future<void> _loadCatalogs() async {
    if (mounted) {
      setState(() {
        _catalogsLoading = true;
        _cityCatalogError = null;
        _instrumentCatalogError = null;
      });
    }
    final citiesFuture = _locationRepository.getCities();
    final instrumentsFuture = _instrumentRepository.getAll();
    final cityResult = await citiesFuture;
    final instrumentResult = await instrumentsFuture;
    if (!mounted) return;
    setState(() {
      _catalogsLoading = false;
      if (cityResult.isSuccess) {
        _cities = List<City>.unmodifiable(
          sortByTurkishName(cityResult.data!, (city) => city.name),
        );
      } else {
        _cityCatalogError =
            cityResult.error?.message ?? 'Şehir seçenekleri yüklenemedi.';
      }
      if (instrumentResult.isSuccess) {
        _instruments = List<Instrument>.unmodifiable(
          <Instrument>[...instrumentResult.data!]
            ..sort((a, b) => a.name.compareTo(b.name)),
        );
      } else {
        _instrumentCatalogError =
            instrumentResult.error?.message ??
            'Enstrüman seçenekleri yüklenemedi.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CollabDiscoveryCubit>.value(
      value: _cubit,
      child: BlocConsumer<CollabDiscoveryCubit, CollabDiscoveryState>(
        listenWhen: (previous, current) =>
            previous.actionError != current.actionError ||
            previous.loadMoreError != current.loadMoreError ||
            (previous.error != current.error && current.items.isNotEmpty),
        listener: (context, state) {
          final error = state.actionError ?? state.loadMoreError ?? state.error;
          if (error != null) _showMessage(error.message);
        },
        builder: (context, state) => Scaffold(
          body: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: _cubit.refresh,
              child: CustomScrollView(
                controller: _scrollController,
                key: const PageStorageKey<String>('collab-discovery-scroll'),
                physics: const AlwaysScrollableScrollPhysics(),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _DiscoveryHeader(
                            onApplicationsTap: _openMyApplications,
                            onJobsTap: _openMyJobs,
                            onListingsTap: _openMyListings,
                            onSavedTap: _openSavedListings,
                          ),
                          const SizedBox(height: 18),
                          _CadenceSelector(
                            selected: state.query.cadence,
                            onSelected: _selectCadence,
                          ),
                          const SizedBox(height: 13),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(child: _buildQuickFilters(state.query)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 13, 16, 0),
                      child: GradientTextField(
                        controller: _searchController,
                        label: 'İlan, rol veya anahtar kelime ara...',
                        prefixIcon: Icons.search_rounded,
                        textInputAction: TextInputAction.search,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(17, 16, 17, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              state.query.cadence == CollabCadence.extra
                                  ? 'Yakındaki ekstralar'
                                  : 'Düzenli fırsatlar',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Text(
                            '${state.totalElements} ilan',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (state.status == CollabLoadStatus.loading &&
                      state.items.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (state.status == CollabLoadStatus.failure &&
                      state.items.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _DiscoveryFailureState(
                        message: state.error?.message ?? 'İlanlar yüklenemedi.',
                        onRetry: () => unawaited(_cubit.refresh()),
                      ),
                    )
                  else if (state.items.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyDiscoveryState(onClear: _clearFilters),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                      sliver: SliverList.separated(
                        itemCount: state.items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final listing = state.items[index];
                          return CollabListingCard(
                            key: ValueKey(listing.id),
                            listing: _toDiscoveryCardModel(listing),
                            saved: listing.savedByMe,
                            showCadence: false,
                            onSave: () => _toggleSaved(listing.id),
                            onTap: () => _openListing(listing),
                          );
                        },
                      ),
                    ),
                  if (state.items.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _LoadMoreFooter(
                        loading: state.isLoadingMore,
                        hasNext: state.hasNext,
                        hasError: state.loadMoreError != null,
                        onRetry: () => unawaited(_cubit.loadMore()),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 112)),
                ],
              ),
            ),
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
          floatingActionButton: _CreateListingButton(
            onPressed: _openCreateListing,
          ),
          bottomNavigationBar: widget.showBottomNavigation
              ? ProfilePublicBottomBar(currentIndex: 1)
              : null,
        ),
      ),
    );
  }

  Widget _buildQuickFilters(CollabDiscoveryQuery query) {
    return SizedBox(
      height: 43,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          CollabChoiceChip(
            key: const ValueKey<String>('collab-quick-city'),
            label: _cityLabel(query.cityId),
            icon: Icons.location_on_outlined,
            selected: query.cityId != null,
            onTap: () => _pickCity(query),
          ),
          const SizedBox(width: 8),
          CollabChoiceChip(
            key: const ValueKey<String>('collab-quick-wanted'),
            label: query.wantedType?.wantedLabel ?? 'Aranan',
            icon: Icons.manage_search_rounded,
            selected: query.wantedType != null,
            onTap: () => _pickWantedKind(query),
          ),
          if (query.wantedType == CollabProfileKind.musician) ...[
            const SizedBox(width: 8),
            CollabChoiceChip(
              key: const ValueKey<String>('collab-quick-specialty'),
              label: _specialtyChipLabel(query),
              icon: Icons.music_note_outlined,
              selected:
                  query.instrumentIds.isNotEmpty || query.branches.isNotEmpty,
              onTap: () => _pickSpecialties(query),
            ),
          ],
          const SizedBox(width: 8),
          CollabChoiceChip(
            key: const ValueKey<String>('collab-quick-publisher'),
            label: _publisherChipLabel(query),
            icon: Icons.person_search_outlined,
            selected: query.publisherTypes.isNotEmpty,
            onTap: () => _pickPublisherKinds(query),
          ),
          const SizedBox(width: 8),
          CollabChoiceChip(
            key: const ValueKey<String>('collab-quick-published'),
            label: query.publishedWithin == CollabPublishedWithin.all
                ? 'Yayınlanma'
                : query.publishedWithin.label,
            icon: Icons.schedule_rounded,
            selected: query.publishedWithin != CollabPublishedWithin.all,
            onTap: () => _pickPublishedWithin(query),
          ),
        ],
      ),
    );
  }

  String _specialtyChipLabel(CollabDiscoveryQuery query) {
    final count = query.instrumentIds.length + query.branches.length;
    if (count == 0) return 'Enstrüman / Branş';
    if (count == 1) {
      if (query.instrumentIds.isNotEmpty) {
        final id = query.instrumentIds.first;
        return _instruments.where((item) => item.id == id).firstOrNull?.name ??
            'Enstrüman';
      }
      return query.branches.first.label;
    }
    return '$count seçim';
  }

  String _publisherChipLabel(CollabDiscoveryQuery query) {
    if (query.publisherTypes.isEmpty) return 'Kimden';
    if (query.publisherTypes.length == 1) {
      return query.publisherTypes.first.publisherLabel;
    }
    return '${query.publisherTypes.length} profil türü';
  }

  String _cityLabel(String? cityId) {
    if (cityId == null) return 'Şehir';
    return _cities.where((city) => city.id == cityId).firstOrNull?.name ??
        'Şehir';
  }

  List<_SpecialtyOption> get _availableSpecialties {
    final branches = CollabBranch.values
        .map(_SpecialtyOption.branch)
        .toList(growable: false);
    final branchLabels = branches
        .map((option) => option.label.trim().toLowerCase())
        .toSet();
    final options = <_SpecialtyOption>[
      ..._instruments
          .where(
            (instrument) =>
                !branchLabels.contains(instrument.name.trim().toLowerCase()),
          )
          .map(_SpecialtyOption.instrument),
      ...branches,
    ]..sort((a, b) => a.label.compareTo(b.label));
    return List<_SpecialtyOption>.unmodifiable(options);
  }

  bool _citiesReadyOrExplain() {
    if (!_catalogsLoading && _cityCatalogError == null) return true;
    _showMessage(_cityCatalogError ?? 'Şehir seçenekleri yükleniyor.');
    if (_cityCatalogError != null) unawaited(_loadCatalogs());
    return false;
  }

  bool _specialtiesReadyOrExplain() {
    if (_catalogsLoading) {
      _showMessage('Enstrüman seçenekleri yükleniyor.');
      return false;
    }
    if (_instrumentCatalogError != null) {
      _showMessage(
        '$_instrumentCatalogError Branş seçenekleriyle devam edebilirsin.',
      );
      unawaited(_loadCatalogs());
    }
    return true;
  }

  Future<void> _pickCity(CollabDiscoveryQuery query) async {
    if (!_citiesReadyOrExplain()) return;
    final result = await _showQuickSingleSelect<String>(
      title: 'Şehir seç',
      options: _cities.map((city) => city.id).toList(growable: false),
      selected: query.cityId,
      labelFor: _cityLabel,
    );
    if (!mounted || !result.didChoose) return;
    unawaited(
      _cubit.setFilters(
        result.value == null
            ? query.copyWith(clearCityId: true)
            : query.copyWith(cityId: result.value),
      ),
    );
  }

  Future<void> _pickWantedKind(CollabDiscoveryQuery query) async {
    final result = await _showQuickSingleSelect<CollabProfileKind>(
      title: 'Ne aranıyor?',
      options: CollabProfileKind.values,
      selected: query.wantedType,
      labelFor: (value) => value.wantedLabel,
    );
    if (!mounted || !result.didChoose) return;
    unawaited(
      _cubit.setFilters(
        result.value == null
            ? query.copyWith(clearWantedType: true)
            : query.copyWith(wantedType: result.value),
      ),
    );
  }

  Future<void> _pickSpecialties(CollabDiscoveryQuery query) async {
    if (!_specialtiesReadyOrExplain()) return;
    final selected = <_SpecialtyOption>{
      ..._availableSpecialties.where(
        (option) =>
            option.instrumentId != null &&
            query.instrumentIds.contains(option.instrumentId),
      ),
      ..._availableSpecialties.where(
        (option) =>
            option.branch != null && query.branches.contains(option.branch),
      ),
    };
    final result = await _showQuickMultiSelect<_SpecialtyOption>(
      title: 'Enstrüman / Branş',
      options: _availableSpecialties,
      selected: selected,
      labelFor: (value) => value.label,
    );
    if (!mounted || result == null) return;
    unawaited(
      _cubit.setFilters(
        query.copyWith(
          instrumentIds: result
              .map((option) => option.instrumentId)
              .whereType<String>()
              .toSet(),
          branches: result
              .map((option) => option.branch)
              .whereType<CollabBranch>()
              .toSet(),
        ),
      ),
    );
  }

  Future<void> _pickPublisherKinds(CollabDiscoveryQuery query) async {
    final result = await _showQuickMultiSelect<CollabProfileKind>(
      title: 'İlan kimden?',
      options: CollabProfileKind.values,
      selected: query.publisherTypes,
      labelFor: (value) => value.publisherLabel,
    );
    if (!mounted || result == null) return;
    unawaited(_cubit.setFilters(query.copyWith(publisherTypes: result)));
  }

  Future<void> _pickPublishedWithin(CollabDiscoveryQuery query) async {
    final result = await _showQuickSingleSelect<CollabPublishedWithin>(
      title: 'Ne zaman yayınlandı?',
      options: _publishedWithinOptions(query.cadence),
      selected: query.publishedWithin == CollabPublishedWithin.all
          ? null
          : query.publishedWithin,
      labelFor: (value) => value.label,
    );
    if (!mounted || !result.didChoose) return;
    unawaited(
      _cubit.setFilters(
        query.copyWith(
          publishedWithin: result.value ?? CollabPublishedWithin.all,
        ),
      ),
    );
  }

  List<CollabPublishedWithin> _publishedWithinOptions(CollabCadence cadence) =>
      CollabPublishedWithin.values
          .where((value) => value != CollabPublishedWithin.all)
          .where(
            (value) =>
                cadence == CollabCadence.regular ||
                value == CollabPublishedWithin.last24Hours ||
                value == CollabPublishedWithin.last3Days ||
                value == CollabPublishedWithin.last7Days,
          )
          .toList(growable: false);

  Future<_QuickSelection<T>> _showQuickSingleSelect<T>({
    required String title,
    required List<T> options,
    required T? selected,
    required String Function(T value) labelFor,
  }) async {
    final result = await showModalBottomSheet<_QuickSelection<T>>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _QuickSingleSelectSheet<T>(
        title: title,
        options: options,
        selected: selected,
        labelFor: labelFor,
      ),
    );
    return result ?? const _QuickSelection.cancelled();
  }

  Future<Set<T>?> _showQuickMultiSelect<T>({
    required String title,
    required List<T> options,
    required Set<T> selected,
    required String Function(T value) labelFor,
  }) {
    return showModalBottomSheet<Set<T>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _QuickMultiSelectSheet<T>(
        title: title,
        options: options,
        selected: selected,
        labelFor: labelFor,
      ),
    );
  }

  CollabDiscoveryListing _toDiscoveryCardModel(CollabListing listing) =>
      CollabDiscoveryListing(
        id: listing.id,
        ownerName: listing.publisher.displayName,
        ownerInitials: listing.publisher.initials,
        profileKind: listing.publisher.profileType,
        wantedKind: listing.wantedType,
        ownerSpecialty: null,
        avatarUrl: listing.publisher.avatarUrl,
        title: listing.title,
        cadence: listing.cadence,
        location: listing.city.name,
        role: listing.specialtyLabel ?? '',
        scheduledAt: listing.scheduledAt,
        feeAmountMinor: listing.feeAmountMinor,
        feeCurrency: listing.currency,
      );

  void _toggleSaved(String listingId) {
    unawaited(_cubit.toggleSaved(listingId));
  }

  void _selectCadence(CollabCadence cadence) {
    unawaited(_cubit.setFilters(_cubit.state.query.copyWith(cadence: cadence)));
  }

  void _openListing(CollabListing listing) {
    unawaited(_openListingId(listing.id));
  }

  Future<void> _openListingId(String listingId) async {
    await Navigator.of(context).push<void>(
      collabPageRoute(
        builder: (_) => CollabListingDetailScreen(
          listingId: listingId,
          showBottomNavigation: widget.showBottomNavigation,
          onListingChanged: _cubit.upsertListing,
        ),
      ),
    );
    if (mounted) await _cubit.refresh();
  }

  void _openMyApplications() {
    unawaited(_openMyApplicationsTarget());
  }

  void _openMyJobs() {
    unawaited(
      _openMyApplicationsTarget(initialSection: CollabApplicationsSection.jobs),
    );
  }

  Future<void> _openMyApplicationsTarget({
    CollabApplicationsSection initialSection =
        CollabApplicationsSection.applications,
    String? initialApplicationId,
    String? initialJobId,
    String? initialReviewId,
    String? initialAction,
  }) => Navigator.of(context).push<void>(
    collabPageRoute(
      builder: (_) => CollabMyApplicationsScreen(
        showBottomNavigation: widget.showBottomNavigation,
        initialSection: initialSection,
        initialApplicationId: initialApplicationId,
        initialJobId: initialJobId,
        initialReviewId: initialReviewId,
        initialAction: initialAction,
      ),
    ),
  );

  void _openMyListings() {
    Navigator.of(context).push<void>(
      collabPageRoute(
        builder: (_) => CollabMyListingsScreen(
          showBottomNavigation: widget.showBottomNavigation,
        ),
      ),
    );
  }

  void _openSavedListings() {
    Navigator.of(context).push<void>(
      collabPageRoute(
        builder: (_) => CollabSavedListingsScreen(
          showBottomNavigation: widget.showBottomNavigation,
        ),
      ),
    );
  }

  Future<void> _openCreateListing() async {
    final result = await Navigator.of(context).push<CollabCreateListingResult>(
      collabPageRoute(
        builder: (_) => CollabCreateListingScreen(
          showBottomNavigation: widget.showBottomNavigation,
        ),
      ),
    );
    if (!mounted || result == null) return;
    if (result == CollabCreateListingResult.published) {
      await _cubit.refresh();
      if (!mounted) return;
      _showMessage('İlanın yayınlandı.');
    } else {
      _showMessage('Taslağın kaydedildi.');
    }
  }

  void _clearFilters() {
    _searchController.clear();
    final current = _cubit.state.query;
    unawaited(
      _cubit.setFilters(
        CollabDiscoveryQuery(cadence: current.cadence, size: current.size),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _DiscoveryHeader extends StatelessWidget {
  const _DiscoveryHeader({
    required this.onApplicationsTap,
    required this.onJobsTap,
    required this.onListingsTap,
    required this.onSavedTap,
  });

  final VoidCallback onApplicationsTap;
  final VoidCallback onJobsTap;
  final VoidCallback onListingsTap;
  final VoidCallback onSavedTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 178,
              height: 52,
              child: ClipRect(
                child: Transform.scale(
                  scale: 3.1,
                  child: Image.asset(
                    'assets/logotransparent.png',
                    key: const ValueKey<String>('collab-brand-logo'),
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    semanticLabel: 'SoundConnect',
                  ),
                ),
              ),
            ),
          ),
        ),
        PopupMenuButton<String>(
          tooltip: 'Collab işlerim',
          onSelected: (value) {
            if (value == 'applications') {
              onApplicationsTap();
            } else if (value == 'jobs') {
              onJobsTap();
            } else if (value == 'listings') {
              onListingsTap();
            } else if (value == 'saved') {
              onSavedTap();
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'applications',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.outbox_outlined),
                title: Text('Başvurularım'),
              ),
            ),
            PopupMenuItem(
              value: 'jobs',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.handshake_outlined),
                title: Text('İşlerim'),
              ),
            ),
            PopupMenuItem(
              value: 'listings',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.work_outline_rounded),
                title: Text('İlanlarım'),
              ),
            ),
            PopupMenuItem(
              value: 'saved',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.bookmarks_outlined),
                title: Text('Kaydedilen ilanlar'),
              ),
            ),
          ],
          child: CollabGradientFrame(
            radius: 999,
            padding: const EdgeInsets.all(11),
            child: Icon(
              Icons.dashboard_customize_outlined,
              color: theme.colorScheme.onSurface,
              size: 21,
            ),
          ),
        ),
      ],
    );
  }
}

class _CadenceSelector extends StatelessWidget {
  const _CadenceSelector({required this.selected, required this.onSelected});

  final CollabCadence selected;
  final ValueChanged<CollabCadence> onSelected;

  @override
  Widget build(BuildContext context) {
    return CollabGradientFrame(
      radius: 17,
      strokeWidth: 1,
      child: SizedBox(
        height: 51,
        child: Row(
          children:
              const <CollabCadence>[CollabCadence.regular, CollabCadence.extra]
                  .map((cadence) {
                    final isSelected = cadence == selected;
                    return Expanded(
                      child: Semantics(
                        button: true,
                        selected: isSelected,
                        label: cadence.label,
                        child: InkWell(
                          key: ValueKey<String>(
                            'collab-cadence-${cadence.name}',
                          ),
                          onTap: () => onSelected(cadence),
                          borderRadius: BorderRadius.circular(16),
                          child: isSelected
                              ? CollabGradientFrame(
                                  highlighted: true,
                                  radius: 16,
                                  strokeWidth: 1.4,
                                  child: Center(
                                    child: _CadenceLabel(
                                      label: cadence.label,
                                      selected: true,
                                    ),
                                  ),
                                )
                              : Center(
                                  child: _CadenceLabel(
                                    label: cadence.label,
                                    selected: false,
                                  ),
                                ),
                        ),
                      ),
                    );
                  })
                  .toList(growable: false),
        ),
      ),
    );
  }
}

class _CadenceLabel extends StatelessWidget {
  const _CadenceLabel({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: selected
            ? Theme.of(context).colorScheme.onSurface
            : Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: 15,
        fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
      ),
    );
  }
}

class _CreateListingButton extends StatelessWidget {
  const _CreateListingButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(colors: AppColors.brandGradient),
        boxShadow: [
          BoxShadow(
            color: AppColors.socialPurple.withValues(alpha: 0.26),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 26, vertical: 13),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, color: AppColors.white, size: 23),
                SizedBox(width: 8),
                Text(
                  'İlan Ver',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickSelection<T> {
  const _QuickSelection(this.value) : didChoose = true;
  const _QuickSelection.cancelled() : value = null, didChoose = false;

  final T? value;
  final bool didChoose;
}

class _QuickSingleSelectSheet<T> extends StatelessWidget {
  const _QuickSingleSelectSheet({
    required this.title,
    required this.options,
    required this.selected,
    required this.labelFor,
  });

  final String title;
  final List<T> options;
  final T? selected;
  final String Function(T value) labelFor;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.72,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 9),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  RadioListTile<T?>(
                    value: null,
                    groupValue: selected,
                    title: const Text('Tümü'),
                    onChanged: (_) =>
                        Navigator.of(context).pop(_QuickSelection<T>(null)),
                  ),
                  ...options.map(
                    (option) => RadioListTile<T?>(
                      value: option,
                      groupValue: selected,
                      title: Text(labelFor(option)),
                      onChanged: (_) =>
                          Navigator.of(context).pop(_QuickSelection<T>(option)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickMultiSelectSheet<T> extends StatefulWidget {
  const _QuickMultiSelectSheet({
    required this.title,
    required this.options,
    required this.selected,
    required this.labelFor,
  });

  final String title;
  final List<T> options;
  final Set<T> selected;
  final String Function(T value) labelFor;

  @override
  State<_QuickMultiSelectSheet<T>> createState() =>
      _QuickMultiSelectSheetState<T>();
}

class _QuickMultiSelectSheetState<T> extends State<_QuickMultiSelectSheet<T>> {
  late Set<T> _selected;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selected = Set<T>.of(widget.selected);
  }

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = _query.trim().toLowerCase();
    final visibleOptions = normalizedQuery.isEmpty
        ? widget.options
        : widget.options
              .where(
                (option) => widget
                    .labelFor(option)
                    .toLowerCase()
                    .contains(normalizedQuery),
              )
              .toList(growable: false);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.72,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _selected.clear()),
                  child: const Text('Temizle'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (widget.options.length > 12) ...[
              TextField(
                key: const ValueKey('collab-multi-select-search'),
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Seçeneklerde ara',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 8),
            ],
            Flexible(
              child: visibleOptions.isEmpty
                  ? const Center(child: Text('Eşleşen seçenek bulunamadı.'))
                  : ListView(
                      shrinkWrap: true,
                      children: visibleOptions
                          .map(
                            (option) => CheckboxListTile(
                              value: _selected.contains(option),
                              title: Text(widget.labelFor(option)),
                              onChanged: (checked) {
                                setState(() {
                                  if (checked == true) {
                                    _selected.add(option);
                                  } else {
                                    _selected.remove(option);
                                  }
                                });
                              },
                            ),
                          )
                          .toList(growable: false),
                    ),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(_selected),
              child: const Text('Uygula'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpecialtyOption {
  const _SpecialtyOption._({
    required this.label,
    this.instrumentId,
    this.branch,
  });

  factory _SpecialtyOption.instrument(Instrument instrument) =>
      _SpecialtyOption._(label: instrument.name, instrumentId: instrument.id);

  factory _SpecialtyOption.branch(CollabBranch branch) =>
      _SpecialtyOption._(label: branch.label, branch: branch);

  final String label;
  final String? instrumentId;
  final CollabBranch? branch;

  @override
  bool operator ==(Object other) =>
      other is _SpecialtyOption &&
      other.instrumentId == instrumentId &&
      other.branch == branch;

  @override
  int get hashCode => Object.hash(instrumentId, branch);
}

class _DiscoveryFailureState extends StatelessWidget {
  const _DiscoveryFailureState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              color: theme.colorScheme.onSurfaceVariant,
              size: 42,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              key: const ValueKey('collab-discovery-retry'),
              onPressed: onRetry,
              child: const Text('Tekrar dene'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadMoreFooter extends StatelessWidget {
  const _LoadMoreFooter({
    required this.loading,
    required this.hasNext,
    required this.hasError,
    required this.onRetry,
  });

  final bool loading;
  final bool hasNext;
  final bool hasError;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
        ),
      );
    }
    if (hasError) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: TextButton.icon(
            key: const ValueKey('collab-discovery-load-more-retry'),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Devamını tekrar yükle'),
          ),
        ),
      );
    }
    return SizedBox(height: hasNext ? 12 : 4);
  }
}

class _EmptyDiscoveryState extends StatelessWidget {
  const _EmptyDiscoveryState({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              color: theme.colorScheme.onSurfaceVariant,
              size: 42,
            ),
            const SizedBox(height: 12),
            Text(
              'Bu seçimlere uygun ilan bulunamadı.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: onClear,
              child: const Text('Filtreleri temizle'),
            ),
          ],
        ),
      ),
    );
  }
}
