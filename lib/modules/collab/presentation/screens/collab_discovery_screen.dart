import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/gradient_text.dart';
import '../../../../shared/widgets/gradient_text_field.dart';
import '../../../profile/presentation/screens/profile_public_bottom_bar.dart';
import '../../data/collab_discovery_mock_data.dart';
import '../../data/collab_mock_controller.dart';
import '../../domain/collab_discovery_models.dart';
import '../theme/collab_visual_theme.dart';
import '../widgets/collab_discovery_widgets.dart';
import 'collab_create_listing_screen.dart';
import 'collab_filters_screen.dart';
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
  CollabCadence _cadence = CollabCadence.extra;
  CollabDirection? _direction;
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
          (listing) => _direction == null || listing.direction == _direction,
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
                          activeFilterCount: _filter.activeCount,
                          onFilterTap: _openFilters,
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
                        setState(() {
                          _direction = null;
                          _filter = const CollabDiscoveryFilter();
                        });
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
            label: 'Tümü',
            selected: _direction == null,
            onTap: () => setState(() => _direction = null),
          ),
          const SizedBox(width: 8),
          CollabChoiceChip(
            label: 'Arıyorum',
            selected: _direction == CollabDirection.seeking,
            onTap: () => setState(() => _direction = CollabDirection.seeking),
          ),
          const SizedBox(width: 8),
          CollabChoiceChip(
            label: 'Müsaitim',
            selected: _direction == CollabDirection.available,
            onTap: () => setState(() => _direction = CollabDirection.available),
          ),
          const SizedBox(width: 8),
          CollabChoiceChip(
            label: _filter.city ?? 'Şehir',
            icon: Icons.location_on_outlined,
            selected: _filter.city != null,
            onTap: _openFilters,
          ),
          const SizedBox(width: 8),
          CollabChoiceChip(
            label: _filter.role ?? 'Rol',
            icon: Icons.music_note_outlined,
            selected: _filter.role != null,
            onTap: _openFilters,
          ),
          if (_cadence == CollabCadence.extra) ...[
            const SizedBox(width: 8),
            CollabChoiceChip(
              label: 'Tarih',
              icon: Icons.calendar_month_outlined,
              selected: _filter.dateRange != null,
              onTap: _openFilters,
            ),
          ],
          const SizedBox(width: 8),
          CollabChoiceChip(
            label: switch (_filter.fee) {
              CollabFeeFilter.all => 'Ücret',
              CollabFeeFilter.paid => 'Ücretli',
              CollabFeeFilter.unspecified => 'Belirtilmemiş',
            },
            icon: Icons.payments_outlined,
            selected: _filter.fee != CollabFeeFilter.all,
            onTap: _openFilters,
          ),
        ],
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

  Future<void> _openFilters() async {
    final result = await Navigator.of(context).push<CollabDiscoveryFilter>(
      collabPageRoute(
        builder: (_) => CollabFiltersScreen(
          cadence: _cadence,
          direction: _direction,
          initialFilter: _filter,
          searchQuery: _searchController.text,
          sourceListings: _allListings,
          controller: _controller,
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() => _filter = result);
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
    required this.activeFilterCount,
    required this.onFilterTap,
    required this.onApplicationsTap,
    required this.onListingsTap,
  });

  final int activeFilterCount;
  final VoidCallback onFilterTap;
  final VoidCallback onApplicationsTap;
  final VoidCallback onListingsTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GradientText(
                text: 'Collab',
                gradient: LinearGradient(colors: AppColors.brandGradient),
                style: const TextStyle(
                  fontSize: 26,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Backstage iş ve ekip bulma',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
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
        const SizedBox(width: 8),
        Stack(
          clipBehavior: Clip.none,
          children: [
            InkWell(
              onTap: onFilterTap,
              borderRadius: BorderRadius.circular(999),
              child: CollabGradientFrame(
                highlighted: true,
                radius: 999,
                strokeWidth: 1.2,
                padding: const EdgeInsets.all(11),
                child: Icon(
                  Icons.tune_rounded,
                  color: theme.colorScheme.onSurface,
                  size: 22,
                ),
              ),
            ),
            if (activeFilterCount > 0)
              Positioned(
                right: -4,
                top: -5,
                child: Container(
                  width: 19,
                  height: 19,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.coral,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$activeFilterCount',
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
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
          children: CollabCadence.values
              .map((cadence) {
                final isSelected = cadence == selected;
                return Expanded(
                  child: Semantics(
                    button: true,
                    selected: isSelected,
                    label: cadence.label,
                    child: InkWell(
                      key: ValueKey<String>('collab-cadence-${cadence.name}'),
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
