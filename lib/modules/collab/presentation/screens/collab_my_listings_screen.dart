import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/gradient_text.dart';
import '../../../profile/presentation/screens/profile_public_bottom_bar.dart';
import '../../domain/collab_types.dart';
import '../../domain/entities/collab_listing.dart';
import '../cubit/collab_async_state.dart';
import '../cubit/collab_my_listings_cubit.dart';
import '../cubit/collab_paged_cubit.dart';
import '../theme/collab_visual_theme.dart';
import '../widgets/collab_discovery_widgets.dart';
import '../widgets/collab_management_widgets.dart';
import 'collab_create_listing_screen.dart';
import 'collab_incoming_applications_screen.dart';
import 'collab_listing_detail_screen.dart';

class CollabMyListingsScreen extends StatefulWidget {
  const CollabMyListingsScreen({
    this.showBottomNavigation = true,
    this.onCreateListing,
    this.cubit,
    super.key,
  });

  final bool showBottomNavigation;
  final VoidCallback? onCreateListing;
  final CollabMyListingsCubit? cubit;

  @override
  State<CollabMyListingsScreen> createState() => _CollabMyListingsScreenState();
}

class _CollabMyListingsScreenState extends State<CollabMyListingsScreen> {
  late final CollabMyListingsCubit _cubit;
  late final bool _ownsCubit;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _ownsCubit = widget.cubit == null;
    _cubit = widget.cubit ?? serviceLocator<CollabMyListingsCubit>();
    _scrollController = ScrollController()..addListener(_onScroll);
    unawaited(_cubit.setStatusFilter(CollabListingStatus.open));
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
    return BlocProvider<CollabMyListingsCubit>.value(
      value: _cubit,
      child:
          BlocConsumer<CollabMyListingsCubit, CollabPagedState<CollabListing>>(
            listenWhen: (previous, current) =>
                (previous.actionError != current.actionError &&
                    current.actionError != null) ||
                (previous.error != current.error &&
                    current.error != null &&
                    current.items.isNotEmpty),
            listener: (context, state) =>
                _showMessage((state.actionError ?? state.error)!.message),
            builder: (context, state) {
              return Scaffold(
                body: SafeArea(
                  bottom: false,
                  child: RefreshIndicator(
                    onRefresh: _cubit.refresh,
                    child: CustomScrollView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 15, 16, 0),
                            child: _Header(
                              onBack: Navigator.of(context).canPop()
                                  ? () => Navigator.of(context).pop()
                                  : null,
                              onCreate: widget.onCreateListing ?? _openCreate,
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 18),
                            child: _StatusRail(
                              selected: _cubit.statusFilter,
                              onSelected: (status) =>
                                  unawaited(_cubit.setStatusFilter(status)),
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 18, 16, 11),
                            child: Text(
                              '${state.totalElements} ilan',
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ),
                        ..._contentSlivers(state),
                      ],
                    ),
                  ),
                ),
                bottomNavigationBar: widget.showBottomNavigation
                    ? ProfilePublicBottomBar(currentIndex: 1)
                    : null,
              );
            },
          ),
    );
  }

  List<Widget> _contentSlivers(CollabPagedState<CollabListing> state) {
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
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
        sliver: SliverList.separated(
          itemCount: state.items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final listing = state.items[index];
            return _OwnedListingCard(
              listing: listing,
              busy: state.actionIds.contains(listing.id),
              onApplications: listing.isDraft
                  ? null
                  : () => _openApplications(listing),
              onDetail: () => _openDetail(listing),
              onEdit:
                  listing.status == CollabListingStatus.closed ||
                      listing.status == CollabListingStatus.expired
                  ? null
                  : () => _openEditor(listing),
              onClose: listing.isOpen ? () => _confirmClose(listing) : null,
              onDelete: listing.isDraft ? () => _confirmDelete(listing) : null,
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

  Future<void> _openCreate() async {
    final result = await Navigator.of(context).push<CollabCreateListingResult>(
      collabPageRoute(
        builder: (_) => CollabCreateListingScreen(
          showBottomNavigation: widget.showBottomNavigation,
        ),
      ),
    );
    if (!mounted || result == null) return;
    await _cubit.refresh();
    if (!mounted) return;
    _showMessage(
      result == CollabCreateListingResult.published
          ? 'İlanın yayınlandı.'
          : 'Taslağın kaydedildi.',
    );
  }

  Future<void> _openEditor(CollabListing listing) async {
    final result = await Navigator.of(context).push<CollabCreateListingResult>(
      collabPageRoute(
        builder: (_) => CollabCreateListingScreen(
          initialListing: listing,
          showBottomNavigation: widget.showBottomNavigation,
        ),
      ),
    );
    if (!mounted || result == null) return;
    await _cubit.refresh();
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

  Future<void> _openApplications(CollabListing listing) async {
    await Navigator.of(context).push<void>(
      collabPageRoute(
        builder: (_) => CollabIncomingApplicationsScreen(
          listingId: listing.id,
          listingTitle: listing.title,
          showBottomNavigation: widget.showBottomNavigation,
        ),
      ),
    );
    if (mounted) await _cubit.refresh();
  }

  Future<void> _confirmClose(CollabListing listing) async {
    final confirmed = await _confirm(
      title: 'İlanı kapat',
      message:
          'İlan kapanacak ve bekleyen başvurular geçersizleşecek. Devam edilsin mi?',
      action: 'İlanı kapat',
    );
    if (confirmed && mounted) await _cubit.closeListing(listing);
  }

  Future<void> _confirmDelete(CollabListing listing) async {
    final confirmed = await _confirm(
      title: 'Taslağı sil',
      message: 'Bu taslak kalıcı olarak silinecek. Devam edilsin mi?',
      action: 'Taslağı sil',
    );
    if (confirmed && mounted) await _cubit.deleteDraft(listing);
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Vazgeç'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(action, style: TextStyle(color: AppColors.coral)),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack, required this.onCreate});

  final VoidCallback? onBack;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onBack != null) ...[
          IconButton(
            onPressed: onBack,
            tooltip: 'Geri',
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 2),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GradientText(
                text: 'Collab',
                gradient: LinearGradient(colors: AppColors.brandGradient),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'İlanlarım',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          onPressed: onCreate,
          tooltip: 'Yeni ilan oluştur',
          icon: const Icon(Icons.add_rounded),
        ),
      ],
    );
  }
}

class _StatusRail extends StatelessWidget {
  const _StatusRail({required this.selected, required this.onSelected});

  final CollabListingStatus? selected;
  final ValueChanged<CollabListingStatus?> onSelected;

  @override
  Widget build(BuildContext context) {
    const options = <(CollabListingStatus?, String)>[
      (CollabListingStatus.open, 'Yayında'),
      (CollabListingStatus.draft, 'Taslaklar'),
      (CollabListingStatus.closed, 'Kapalı'),
      (CollabListingStatus.expired, 'Süresi doldu'),
      (null, 'Tümü'),
    ];
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final option = options[index];
          return CollabChoiceChip(
            label: option.$2,
            selected: selected == option.$1,
            onTap: () => onSelected(option.$1),
          );
        },
      ),
    );
  }
}

class _OwnedListingCard extends StatelessWidget {
  const _OwnedListingCard({
    required this.listing,
    required this.busy,
    required this.onApplications,
    required this.onDetail,
    required this.onEdit,
    required this.onClose,
    required this.onDelete,
  });

  final CollabListing listing;
  final bool busy;
  final VoidCallback? onApplications;
  final VoidCallback onDetail;
  final VoidCallback? onEdit;
  final VoidCallback? onClose;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CollabGradientFrame(
      highlighted: listing.isOpen,
      radius: 19,
      strokeWidth: listing.isOpen ? 1.25 : 1,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  listing.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 16,
                    height: 1.22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CollabListingStatusPill(status: listing.status),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              CollabStatusPill(
                label: listing.cadence.label,
                color: AppColors.socialPink,
              ),
              CollabStatusPill(
                label: '${listing.wantedType.label} arayan',
                color: AppColors.socialOrange,
              ),
              if (listing.specialtyLabel case final specialty?)
                CollabStatusPill(
                  label: specialty,
                  color: AppColors.socialPurple,
                ),
            ],
          ),
          const SizedBox(height: 13),
          LayoutBuilder(
            builder: (_, constraints) {
              final width = (constraints.maxWidth - 8) / 2;
              return Wrap(
                spacing: 8,
                runSpacing: 9,
                children: [
                  CollabTinyMeta(
                    width: width,
                    icon: Icons.location_on_outlined,
                    label: listing.city.name,
                  ),
                  CollabTinyMeta(
                    width: width,
                    icon: Icons.schedule_rounded,
                    label: collabListingSchedule(listing),
                  ),
                  if (listing.feeStatus != CollabFeeStatus.notApplicable)
                    CollabTinyMeta(
                      width: width,
                      icon: Icons.payments_outlined,
                      label: collabFeeText(listing),
                    ),
                  CollabTinyMeta(
                    width: width,
                    icon: Icons.people_alt_outlined,
                    label: '${listing.applicationCount} başvuru',
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 13),
          CollabActionsWrap(
            actions: [
              CollabCardAction(
                label: 'Detay',
                icon: Icons.open_in_new_rounded,
                onPressed: busy ? null : onDetail,
              ),
              CollabCardAction(
                label: 'Başvurular (${listing.applicationCount})',
                icon: Icons.people_alt_outlined,
                tone: CollabCardActionTone.brand,
                onPressed: busy ? null : onApplications,
              ),
              if (onEdit != null)
                CollabCardAction(
                  label: 'Düzenle',
                  icon: Icons.edit_outlined,
                  onPressed: busy ? null : onEdit,
                ),
              if (onClose != null)
                CollabCardAction(
                  label: 'İlanı kapat',
                  icon: Icons.lock_outline_rounded,
                  tone: CollabCardActionTone.danger,
                  busy: busy,
                  onPressed: busy ? null : onClose,
                ),
              if (onDelete != null)
                CollabCardAction(
                  label: 'Taslağı sil',
                  icon: Icons.delete_outline_rounded,
                  tone: CollabCardActionTone.danger,
                  busy: busy,
                  onPressed: busy ? null : onDelete,
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
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: CollabGradientFrame(
          radius: 18,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.campaign_outlined,
                size: 34,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              const Text('Bu durumda bir ilanın bulunmuyor.'),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message ?? 'İlanların yüklenemedi.',
              textAlign: TextAlign.center,
            ),
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
}
