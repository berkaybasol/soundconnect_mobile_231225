import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/gradient_text_field.dart';
import '../../../profile/presentation/screens/profile_public_bottom_bar.dart';
import '../../data/collab_discovery_mock_data.dart';
import '../../data/collab_mock_controller.dart';
import '../../domain/collab_discovery_models.dart';
import '../theme/collab_visual_theme.dart';
import '../widgets/collab_discovery_widgets.dart';
import 'collab_create_listing_screen.dart';
import 'collab_listing_detail_screen.dart';
import 'collab_my_applications_screen.dart';
import 'collab_my_listings_screen.dart';

class CollabDiscoveryScreen extends StatefulWidget {
  const CollabDiscoveryScreen({
    this.showBottomNavigation = true,
    this.controller,
    super.key,
  });

  final bool showBottomNavigation;
  final CollabMockController? controller;

  @override
  State<CollabDiscoveryScreen> createState() => _CollabDiscoveryScreenState();
}

class _CollabDiscoveryScreenState extends State<CollabDiscoveryScreen> {
  final TextEditingController _searchController = TextEditingController();
  CollabCadence _cadence = CollabCadence.regular;
  CollabDiscoveryFilter _filter = const CollabDiscoveryFilter();

  CollabMockController get _controller =>
      widget.controller ?? collabMockController;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_refreshSearch);
  }

  @override
  void dispose() {
    _searchController.removeListener(_refreshSearch);
    _searchController.dispose();
    super.dispose();
  }

  void _refreshSearch() {
    if (mounted) setState(() {});
  }

  List<CollabDiscoveryListing> get _allListings => <CollabDiscoveryListing>[
    ..._controller.createdListings,
    ...collabDiscoveryMockListings,
  ];

  List<CollabDiscoveryListing> get _visibleListings {
    final query = _searchController.text;
    return _allListings
        .where((listing) => listing.cadence == _cadence)
        .where(
          (listing) =>
              listing.cadence == CollabCadence.regular ||
              CollabPublishedWithin.last7Days.includes(listing.publishedAt),
        )
        .where(_filter.matches)
        .where((listing) => listing.matches(query))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final listings = _visibleListings;
          return SafeArea(
            bottom: false,
            child: CustomScrollView(
              key: const PageStorageKey<String>('collab-discovery-scroll'),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _DiscoveryHeader(
                          onApplicationsTap: _openMyApplications,
                          onListingsTap: _openMyListings,
                        ),
                        const SizedBox(height: 18),
                        _CadenceSelector(
                          selected: _cadence,
                          onSelected: _selectCadence,
                        ),
                        const SizedBox(height: 13),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(child: _buildQuickFilters()),
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
                            _cadence == CollabCadence.extra
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
                          '${listings.length} ilan',
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
                if (listings.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyDiscoveryState(
                      onClear: () {
                        _searchController.clear();
                        setState(() => _filter = const CollabDiscoveryFilter());
                      },
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 112),
                    sliver: SliverList.separated(
                      itemCount: listings.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final listing = listings[index];
                        return CollabListingCard(
                          key: ValueKey(listing.id),
                          listing: listing,
                          saved: _controller.isListingSaved(listing.id),
                          showCadence: false,
                          onSave: () => _toggleSaved(listing.id),
                          onTap: () => _openListing(listing),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _CreateListingButton(onPressed: _openCreateListing),
      bottomNavigationBar: widget.showBottomNavigation
          ? ProfilePublicBottomBar(currentIndex: 1)
          : null,
    );
  }

  Widget _buildQuickFilters() {
    return SizedBox(
      height: 43,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          CollabChoiceChip(
            key: const ValueKey<String>('collab-quick-city'),
            label: _filter.city ?? 'Şehir',
            icon: Icons.location_on_outlined,
            selected: _filter.city != null,
            onTap: _pickCity,
          ),
          const SizedBox(width: 8),
          CollabChoiceChip(
            key: const ValueKey<String>('collab-quick-wanted'),
            label: _filter.wantedKind?.wantedLabel ?? 'Aranan',
            icon: Icons.manage_search_rounded,
            selected: _filter.wantedKind != null,
            onTap: _pickWantedKind,
          ),
          if (_filter.wantedKind == CollabProfileKind.musician) ...[
            const SizedBox(width: 8),
            CollabChoiceChip(
              key: const ValueKey<String>('collab-quick-specialty'),
              label: _specialtyChipLabel,
              icon: Icons.music_note_outlined,
              selected: _filter.specialties.isNotEmpty,
              onTap: _pickSpecialties,
            ),
          ],
          const SizedBox(width: 8),
          CollabChoiceChip(
            key: const ValueKey<String>('collab-quick-publisher'),
            label: _publisherChipLabel,
            icon: Icons.person_search_outlined,
            selected: _filter.profileKinds.isNotEmpty,
            onTap: _pickPublisherKinds,
          ),
          const SizedBox(width: 8),
          CollabChoiceChip(
            key: const ValueKey<String>('collab-quick-published'),
            label: _filter.publishedWithin == CollabPublishedWithin.all
                ? 'Yayınlanma'
                : _filter.publishedWithin.label,
            icon: Icons.schedule_rounded,
            selected: _filter.publishedWithin != CollabPublishedWithin.all,
            onTap: _pickPublishedWithin,
          ),
        ],
      ),
    );
  }

  String get _specialtyChipLabel {
    if (_filter.specialties.isEmpty) return 'Enstrüman / Branş';
    if (_filter.specialties.length == 1) return _filter.specialties.first;
    return '${_filter.specialties.length} branş';
  }

  String get _publisherChipLabel {
    if (_filter.profileKinds.isEmpty) return 'Kimden';
    if (_filter.profileKinds.length == 1) {
      return _filter.profileKinds.first.publisherLabel;
    }
    return '${_filter.profileKinds.length} profil türü';
  }

  List<String> get _availableCities {
    final values = _allListings.map((listing) => listing.city).toSet().toList();
    values.sort();
    return values;
  }

  List<String> get _availableSpecialties {
    final values = _allListings
        .where((listing) => listing.wantedKind == CollabProfileKind.musician)
        .map((listing) => listing.role)
        .toSet()
        .toList();
    values.sort();
    return values;
  }

  Future<void> _pickCity() async {
    final result = await _showQuickSingleSelect<String>(
      title: 'Şehir seç',
      options: _availableCities,
      selected: _filter.city,
      labelFor: (value) => value,
    );
    if (!mounted || !result.didChoose) return;
    setState(() {
      _filter = result.value == null
          ? _filter.copyWith(clearCity: true)
          : _filter.copyWith(city: result.value);
    });
  }

  Future<void> _pickWantedKind() async {
    final result = await _showQuickSingleSelect<CollabProfileKind>(
      title: 'Ne aranıyor?',
      options: CollabProfileKind.values,
      selected: _filter.wantedKind,
      labelFor: (value) => value.wantedLabel,
    );
    if (!mounted || !result.didChoose) return;
    setState(() {
      if (result.value == null) {
        _filter = _filter.copyWith(
          clearWantedKind: true,
          specialties: const <String>{},
        );
      } else {
        _filter = _filter.copyWith(
          wantedKind: result.value,
          specialties: result.value == CollabProfileKind.musician
              ? _filter.specialties
              : const <String>{},
        );
      }
    });
  }

  Future<void> _pickSpecialties() async {
    final result = await _showQuickMultiSelect<String>(
      title: 'Enstrüman / Branş',
      options: _availableSpecialties,
      selected: _filter.specialties,
      labelFor: (value) => value,
    );
    if (!mounted || result == null) return;
    setState(() => _filter = _filter.copyWith(specialties: result));
  }

  Future<void> _pickPublisherKinds() async {
    final result = await _showQuickMultiSelect<CollabProfileKind>(
      title: 'İlan kimden?',
      options: CollabProfileKind.values,
      selected: _filter.profileKinds,
      labelFor: (value) => value.publisherLabel,
    );
    if (!mounted || result == null) return;
    setState(() => _filter = _filter.copyWith(profileKinds: result));
  }

  Future<void> _pickPublishedWithin() async {
    final result = await _showQuickSingleSelect<CollabPublishedWithin>(
      title: 'Ne zaman yayınlandı?',
      options: _publishedWithinOptions,
      selected: _filter.publishedWithin == CollabPublishedWithin.all
          ? null
          : _filter.publishedWithin,
      labelFor: (value) => value.label,
    );
    if (!mounted || !result.didChoose) return;
    setState(() {
      _filter = _filter.copyWith(
        publishedWithin: result.value ?? CollabPublishedWithin.all,
      );
    });
  }

  List<CollabPublishedWithin> get _publishedWithinOptions =>
      CollabPublishedWithin.values
          .where((value) => value != CollabPublishedWithin.all)
          .where(
            (value) =>
                _cadence == CollabCadence.regular ||
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

  void _toggleSaved(String listingId) {
    _controller.toggleListingSaved(listingId);
  }

  void _selectCadence(CollabCadence cadence) {
    setState(() {
      _cadence = cadence;
      if (cadence == CollabCadence.regular && _filter.dateRange != null) {
        _filter = _filter.copyWith(clearDateRange: true);
      }
      if (cadence == CollabCadence.extra &&
          (_filter.publishedWithin == CollabPublishedWithin.last30Days ||
              _filter.publishedWithin ==
                  CollabPublishedWithin.olderThan30Days)) {
        _filter = _filter.copyWith(publishedWithin: CollabPublishedWithin.all);
      }
    });
  }

  void _openListing(CollabDiscoveryListing listing) {
    Navigator.of(context).push<void>(
      collabPageRoute(
        builder: (_) => CollabListingDetailScreen(
          listing: listing,
          controller: _controller,
          initiallySaved: _controller.isListingSaved(listing.id),
          showBottomNavigation: widget.showBottomNavigation,
          onSavedChanged: (saved) {
            if (!mounted) return;
            _controller.setListingSaved(listing.id, saved: saved);
          },
        ),
      ),
    );
  }

  void _openMyApplications() {
    Navigator.of(context).push<void>(
      collabPageRoute(
        builder: (_) => CollabMyApplicationsScreen(
          controller: _controller,
          showBottomNavigation: widget.showBottomNavigation,
        ),
      ),
    );
  }

  void _openMyListings() {
    Navigator.of(context).push<void>(
      collabPageRoute(
        builder: (_) => CollabMyListingsScreen(
          controller: _controller,
          showBottomNavigation: widget.showBottomNavigation,
        ),
      ),
    );
  }

  Future<void> _openCreateListing() async {
    final result = await Navigator.of(context).push<CollabCreateListingResult>(
      collabPageRoute(
        builder: (_) => CollabCreateListingScreen(
          controller: _controller,
          showBottomNavigation: widget.showBottomNavigation,
        ),
      ),
    );
    if (!mounted || result == null) return;
    if (result == CollabCreateListingResult.published) {
      final created = _controller.createdListings.first;
      setState(() => _cadence = created.cadence);
      _showMessage('İlanın yayınlandı.');
    } else {
      _showMessage('Taslağın mock olarak kaydedildi.');
    }
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
    required this.onListingsTap,
  });

  final VoidCallback onApplicationsTap;
  final VoidCallback onListingsTap;

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
            } else if (value == 'listings') {
              onListingsTap();
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
              value: 'listings',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.work_outline_rounded),
                title: Text('İlanlarım'),
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

  @override
  void initState() {
    super.initState();
    _selected = Set<T>.of(widget.selected);
  }

  @override
  Widget build(BuildContext context) {
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
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: widget.options
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
