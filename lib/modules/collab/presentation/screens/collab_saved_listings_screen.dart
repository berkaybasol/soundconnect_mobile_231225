import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../profile/presentation/screens/profile_public_bottom_bar.dart';
import '../../domain/collab_types.dart';
import '../../domain/entities/collab_listing.dart';
import '../cubit/collab_async_state.dart';
import '../cubit/collab_paged_cubit.dart';
import '../cubit/collab_saved_listings_cubit.dart';
import '../theme/collab_visual_theme.dart';
import '../widgets/collab_discovery_widgets.dart';
import '../widgets/collab_management_widgets.dart';
import 'collab_listing_detail_screen.dart';

class CollabSavedListingsScreen extends StatefulWidget {
  const CollabSavedListingsScreen({
    this.showBottomNavigation = true,
    this.cubit,
    super.key,
  });

  final bool showBottomNavigation;
  final CollabSavedListingsCubit? cubit;

  @override
  State<CollabSavedListingsScreen> createState() =>
      _CollabSavedListingsScreenState();
}

class _CollabSavedListingsScreenState extends State<CollabSavedListingsScreen> {
  late final CollabSavedListingsCubit _cubit;
  late final bool _ownsCubit;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _ownsCubit = widget.cubit == null;
    _cubit = widget.cubit ?? serviceLocator<CollabSavedListingsCubit>();
    _scrollController = ScrollController()..addListener(_onScroll);
    unawaited(_cubit.loadInitial());
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    if (_ownsCubit) unawaited(_cubit.close());
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 320) {
      unawaited(_cubit.loadMore());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CollabSavedListingsCubit>.value(
      value: _cubit,
      child:
          BlocConsumer<
            CollabSavedListingsCubit,
            CollabPagedState<CollabListing>
          >(
            listenWhen: (previous, current) =>
                (previous.actionError != current.actionError &&
                    current.actionError != null) ||
                (previous.error != current.error &&
                    current.error != null &&
                    current.items.isNotEmpty),
            listener: (_, state) =>
                _showMessage((state.actionError ?? state.error)!.message),
            builder: (context, state) => Scaffold(
              appBar: AppBar(title: const Text('Kaydedilen ilanlar')),
              body: SafeArea(
                top: false,
                bottom: false,
                child: RefreshIndicator(
                  onRefresh: _cubit.refresh,
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 5, 16, 14),
                          child: Text(
                            '${state.totalElements} kaydedilen ilan',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ),
                      ..._content(state),
                    ],
                  ),
                ),
              ),
              bottomNavigationBar: widget.showBottomNavigation
                  ? ProfilePublicBottomBar(currentIndex: 1)
                  : null,
            ),
          ),
    );
  }

  List<Widget> _content(CollabPagedState<CollabListing> state) {
    if (state.status == CollabLoadStatus.loading && state.items.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (state.status == CollabLoadStatus.failure && state.items.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _LoadError(
            message: state.error?.message,
            onRetry: _cubit.loadInitial,
          ),
        ),
      ];
    }
    if (state.items.isEmpty) {
      return const [
        SliverFillRemaining(hasScrollBody: false, child: _EmptyState()),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        sliver: SliverList.separated(
          itemCount: state.items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 11),
          itemBuilder: (context, index) {
            final listing = state.items[index];
            final busy = state.actionIds.contains(listing.id);
            return _SavedListingCard(
              listing: listing,
              busy: busy,
              onDetail: () => _openDetail(listing),
              onUnsave: () => _cubit.unsave(listing),
            );
          },
        ),
      ),
      SliverToBoxAdapter(
        child: CollabPagedFooter(
          loading: state.isLoadingMore,
          hasError: state.loadMoreError != null,
          onRetry: _cubit.loadMore,
        ),
      ),
    ];
  }

  Future<void> _openDetail(CollabListing listing) async {
    await Navigator.of(context).push<void>(
      collabPageRoute(
        builder: (_) => CollabListingDetailScreen(
          listingId: listing.id,
          showBottomNavigation: widget.showBottomNavigation,
        ),
      ),
    );
    if (mounted) await _cubit.refresh();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SavedListingCard extends StatelessWidget {
  const _SavedListingCard({
    required this.listing,
    required this.busy,
    required this.onDetail,
    required this.onUnsave,
  });

  final CollabListing listing;
  final bool busy;
  final VoidCallback onDetail;
  final VoidCallback onUnsave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CollabGradientFrame(
      radius: 19,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CollabActorHeader(actor: listing.publisher),
          const SizedBox(height: 12),
          Text(
            listing.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 15.5,
              height: 1.22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              CollabStatusPill(
                label: listing.cadence.label,
                color: AppColors.socialPink,
              ),
              CollabStatusPill(
                label: '${listing.wantedType.label} arayan',
                color: AppColors.socialOrange,
              ),
            ],
          ),
          const SizedBox(height: 11),
          Wrap(
            spacing: 10,
            runSpacing: 9,
            children: [
              CollabTinyMeta(
                icon: Icons.location_on_outlined,
                label: listing.city.name,
              ),
              CollabTinyMeta(
                icon: Icons.schedule_rounded,
                label: collabListingSchedule(listing),
              ),
            ],
          ),
          const SizedBox(height: 13),
          CollabActionsWrap(
            actions: [
              CollabCardAction(
                label: 'İlan detayı',
                icon: Icons.open_in_new_rounded,
                onPressed: busy ? null : onDetail,
              ),
              CollabCardAction(
                label: 'Kaydı kaldır',
                icon: Icons.bookmark_remove_outlined,
                tone: CollabCardActionTone.danger,
                busy: busy,
                onPressed: busy ? null : onUnsave,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bookmarks_outlined,
            size: 38,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          const Text('Henüz kaydettiğin bir ilan yok.'),
        ],
      ),
    ),
  );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message ?? 'Kaydedilen ilanlar yüklenemedi.'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Yeniden dene'),
          ),
        ],
      ),
    ),
  );
}
