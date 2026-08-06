import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/gradient_text.dart';
import '../../../profile/presentation/screens/profile_public_bottom_bar.dart';
import '../../data/collab_mock_controller.dart';
import '../../domain/collab_discovery_models.dart';
import '../theme/collab_visual_theme.dart';
import '../../domain/collab_listing_draft.dart';
import '../../domain/collab_management_models.dart';
import '../widgets/collab_discovery_widgets.dart';
import '../widgets/collab_management_widgets.dart';
import 'collab_create_listing_screen.dart';
import 'collab_incoming_applications_screen.dart';
import 'collab_listing_detail_screen.dart';

enum _OwnedListingSort { newest, oldest, mostApplications }

extension on _OwnedListingSort {
  String get label => switch (this) {
    _OwnedListingSort.newest => 'En Yeni',
    _OwnedListingSort.oldest => 'En Eski',
    _OwnedListingSort.mostApplications => 'En Çok Başvuru',
  };
}

class CollabMyListingsScreen extends StatefulWidget {
  const CollabMyListingsScreen({
    this.controller,
    this.showBottomNavigation = true,
    this.onCreateListing,
    super.key,
  });

  final CollabMockController? controller;
  final bool showBottomNavigation;
  final VoidCallback? onCreateListing;

  @override
  State<CollabMyListingsScreen> createState() => _CollabMyListingsScreenState();
}

class _CollabMyListingsScreenState extends State<CollabMyListingsScreen> {
  CollabOwnedListingStatus _status = CollabOwnedListingStatus.open;
  _OwnedListingSort _sort = _OwnedListingSort.newest;

  CollabMockController get _controller =>
      widget.controller ?? collabMockController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final listings = _sortedListings();
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 15, 16, 0),
                    child: _MyListingsHeader(
                      onBack: Navigator.of(context).canPop()
                          ? () => Navigator.of(context).pop()
                          : null,
                      draftCount: _controller.drafts.length,
                      onDrafts: _openDrafts,
                      onCreate:
                          widget.onCreateListing ?? () => _openCreateListing(),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 18, 14, 0),
                    child: _OwnedStatusSelector(
                      selected: _status,
                      onSelected: (status) => setState(() => _status = status),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 17, 16, 11),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Toplam ${listings.length} ilan',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                        _OwnedSortMenu(
                          selected: _sort,
                          onSelected: (sort) => setState(() => _sort = sort),
                        ),
                      ],
                    ),
                  ),
                ),
                if (listings.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: CollabGradientFrame(
                        radius: 18,
                        padding: const EdgeInsets.all(22),
                        child: Text(
                          '${_status.label} durumda bir ilanın bulunmuyor.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 34),
                    sliver: SliverList.separated(
                      itemCount: listings.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final owned = listings[index];
                        return _OwnedListingCard(
                          owned: owned,
                          onApplications: () => _openApplications(owned),
                          onDetail: () => _openDetail(owned),
                          onEdit: () => _showMessage(
                            'İlan düzenleme formu mock akışta açılacak.',
                          ),
                          onClose:
                              owned.status == CollabOwnedListingStatus.closed
                              ? null
                              : () => _confirmClose(owned),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: widget.showBottomNavigation
          ? ProfilePublicBottomBar(currentIndex: 1)
          : null,
    );
  }

  List<CollabOwnedListingRecord> _sortedListings() {
    final listings = _controller.ownedListings
        .where((record) => record.status == _status)
        .toList(growable: true);
    listings.sort(switch (_sort) {
      _OwnedListingSort.newest => (a, b) => b.createdAt.compareTo(a.createdAt),
      _OwnedListingSort.oldest => (a, b) => a.createdAt.compareTo(b.createdAt),
      _OwnedListingSort.mostApplications =>
        (a, b) => b.applicationCount.compareTo(a.applicationCount),
    });
    return listings;
  }

  void _openApplications(CollabOwnedListingRecord owned) {
    Navigator.of(context).push<void>(
      collabPageRoute(
        builder: (_) => CollabIncomingApplicationsScreen(
          ownedListing: owned,
          controller: _controller,
          showBottomNavigation: widget.showBottomNavigation,
        ),
      ),
    );
  }

  Future<void> _openCreateListing({CollabListingDraft? initialDraft}) async {
    final result = await Navigator.of(context).push<CollabCreateListingResult>(
      collabPageRoute(
        builder: (_) => CollabCreateListingScreen(
          controller: _controller,
          initialDraft: initialDraft,
          showBottomNavigation: widget.showBottomNavigation,
        ),
      ),
    );
    if (!mounted || result == null) return;
    if (result == CollabCreateListingResult.published) {
      setState(() => _status = CollabOwnedListingStatus.open);
      _showMessage('İlanın yayınlandı.');
    } else {
      _showMessage('Taslağın mock olarak kaydedildi.');
    }
  }

  Future<void> _openDrafts() async {
    if (_controller.drafts.isEmpty) {
      _showMessage('Henüz kaydedilmiş bir taslağın yok.');
      return;
    }
    final draft = await showModalBottomSheet<CollabListingDraft>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _DraftsSheet(drafts: _controller.drafts),
    );
    if (!mounted || draft == null) return;
    await _openCreateListing(initialDraft: draft);
  }

  void _openDetail(CollabOwnedListingRecord owned) {
    Navigator.of(context).push<void>(
      collabPageRoute(
        builder: (_) => CollabListingDetailScreen(
          listing: owned.listing,
          showBottomNavigation: widget.showBottomNavigation,
          controller: _controller,
          isOwnListing: true,
          isListingClosed: owned.status == CollabOwnedListingStatus.closed,
        ),
      ),
    );
  }

  Future<void> _confirmClose(CollabOwnedListingRecord owned) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('İlanı kapat'),
        content: const Text(
          'İlan kapandığında bekleyen başvurular geçersizleşir. Kabul edilmiş '
          'başvurular ve işler etkilenmez.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'İlanı Kapat',
              style: TextStyle(color: AppColors.coral),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _controller.closeListing(owned.listing.id);
    _showMessage('İlan kapatıldı.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _MyListingsHeader extends StatelessWidget {
  const _MyListingsHeader({
    required this.onBack,
    required this.draftCount,
    required this.onDrafts,
    required this.onCreate,
  });

  final VoidCallback? onBack;
  final int draftCount;
  final VoidCallback onDrafts;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'İlanlarım',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
        ),
        if (draftCount > 0)
          IconButton(
            onPressed: onDrafts,
            tooltip: 'Taslaklar ($draftCount)',
            icon: Badge.count(
              count: draftCount,
              child: const Icon(Icons.description_outlined),
            ),
          ),
        IconButton(
          onPressed: onCreate,
          tooltip: 'Yeni ilan oluştur',
          icon: const Icon(Icons.add_circle_outline_rounded),
        ),
      ],
    );
  }
}

class _DraftsSheet extends StatelessWidget {
  const _DraftsSheet({required this.drafts});

  final List<CollabListingDraft> drafts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
      itemCount: drafts.length + 1,
      separatorBuilder: (_, index) =>
          index == 0 ? const SizedBox(height: 10) : const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Taslaklarım',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Devam etmek istediğin ilan taslağını seç.',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          );
        }
        final draft = drafts[index - 1];
        return CollabGradientFrame(
          radius: 17,
          child: Material(
            color: Colors.transparent,
            child: ListTile(
              onTap: () => Navigator.of(context).pop(draft),
              leading: Icon(
                draft.direction == CollabDirection.seeking
                    ? Icons.person_search_outlined
                    : Icons.campaign_outlined,
                color: AppColors.coralLight,
              ),
              title: Text(
                draft.title.trim().isEmpty ? 'İsimsiz taslak' : draft.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                '${draft.cadence.label} · ${draft.direction.label}',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
            ),
          ),
        );
      },
    );
  }
}

class _OwnedStatusSelector extends StatelessWidget {
  const _OwnedStatusSelector({
    required this.selected,
    required this.onSelected,
  });

  final CollabOwnedListingStatus selected;
  final ValueChanged<CollabOwnedListingStatus> onSelected;

  @override
  Widget build(BuildContext context) {
    return CollabGradientFrame(
      radius: 16,
      child: SizedBox(
        height: 49,
        child: Row(
          children: CollabOwnedListingStatus.values
              .map((status) {
                final isSelected = status == selected;
                return Expanded(
                  child: InkWell(
                    onTap: () => onSelected(status),
                    borderRadius: BorderRadius.circular(15),
                    child: isSelected
                        ? CollabGradientFrame(
                            highlighted: true,
                            radius: 15,
                            strokeWidth: 1.3,
                            child: Center(
                              child: _StatusText(
                                label: status.label,
                                selected: true,
                              ),
                            ),
                          )
                        : Center(
                            child: _StatusText(
                              label: status.label,
                              selected: false,
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

class _StatusText extends StatelessWidget {
  const _StatusText({required this.label, required this.selected});

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
        fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
        fontSize: 13.5,
      ),
    );
  }
}

class _OwnedSortMenu extends StatelessWidget {
  const _OwnedSortMenu({required this.selected, required this.onSelected});

  final _OwnedListingSort selected;
  final ValueChanged<_OwnedListingSort> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_OwnedListingSort>(
      tooltip: 'İlanları sırala',
      initialValue: selected,
      onSelected: onSelected,
      itemBuilder: (_) => _OwnedListingSort.values
          .map((sort) => PopupMenuItem(value: sort, child: Text(sort.label)))
          .toList(growable: false),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            selected.label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down_rounded, size: 19),
        ],
      ),
    );
  }
}

class _OwnedListingCard extends StatelessWidget {
  const _OwnedListingCard({
    required this.owned,
    required this.onApplications,
    required this.onDetail,
    required this.onEdit,
    required this.onClose,
  });

  final CollabOwnedListingRecord owned;
  final VoidCallback onApplications;
  final VoidCallback onDetail;
  final VoidCallback onEdit;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final listing = owned.listing;
    final isClosed = owned.status == CollabOwnedListingStatus.closed;
    return Opacity(
      opacity: isClosed ? 0.74 : 1,
      child: CollabGradientFrame(
        highlighted: owned.status == CollabOwnedListingStatus.open,
        radius: 20,
        strokeWidth: owned.status == CollabOwnedListingStatus.open ? 1.25 : 1,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CollabProfileAvatar(listing: listing, size: 53),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        listing.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 15.5,
                          height: 1.2,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          CollabStatusPill(
                            label: listing.cadence.label,
                            color: AppColors.socialPink,
                          ),
                          CollabStatusPill(
                            label: listing.direction.label,
                            color: listing.direction == CollabDirection.seeking
                                ? AppColors.socialOrange
                                : AppColors.spotifyGreen,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 7),
                CollabOwnedStatusPill(status: owned.status),
              ],
            ),
            const SizedBox(height: 13),
            Wrap(
              spacing: 14,
              runSpacing: 8,
              children: [
                CollabTinyMeta(
                  icon: Icons.location_on_outlined,
                  label: listing.location,
                ),
                CollabTinyMeta(
                  icon: Icons.music_note_rounded,
                  label: listing.role,
                ),
                CollabTinyMeta(
                  icon: Icons.calendar_month_outlined,
                  label: collabScheduleText(listing),
                ),
              ],
            ),
            const SizedBox(height: 13),
            Divider(height: 1, color: theme.dividerColor),
            const SizedBox(height: 11),
            Row(
              children: [
                Expanded(
                  child: _OwnedMetric(
                    icon: Icons.groups_2_outlined,
                    label: listing.direction == CollabDirection.seeking
                        ? 'Başvuru'
                        : 'İş Teklifi',
                    value: '${owned.applicationCount}',
                  ),
                ),
                if (listing.direction == CollabDirection.seeking)
                  Expanded(
                    child: _OwnedMetric(
                      icon: Icons.people_outline_rounded,
                      label: 'Kalan Kontenjan',
                      value: '${owned.remainingPositions}/${owned.capacity}',
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 13),
            if (!isClosed) ...[
              CollabCardAction(
                label: 'Öne Çıkar · Yakında',
                icon: Icons.star_outline_rounded,
                tone: CollabCardActionTone.brand,
                onPressed: null,
              ),
              const SizedBox(height: 8),
            ],
            CollabActionsWrap(
              actions: [
                if (!isClosed)
                  CollabCardAction(
                    label: 'Başvuruları Gör',
                    icon: Icons.people_alt_outlined,
                    tone: CollabCardActionTone.brand,
                    onPressed: onApplications,
                  )
                else
                  CollabCardAction(
                    label: 'Detayı Gör',
                    icon: Icons.open_in_new_rounded,
                    onPressed: onDetail,
                  ),
                if (owned.status == CollabOwnedListingStatus.open)
                  CollabCardAction(
                    label: 'Düzenle',
                    icon: Icons.edit_outlined,
                    onPressed: onEdit,
                  ),
                if (!isClosed)
                  CollabCardAction(
                    label: owned.status == CollabOwnedListingStatus.full
                        ? 'Arşive Taşı'
                        : 'Kapat',
                    icon: owned.status == CollabOwnedListingStatus.full
                        ? Icons.archive_outlined
                        : Icons.close_rounded,
                    tone: CollabCardActionTone.danger,
                    onPressed: onClose,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OwnedMetric extends StatelessWidget {
  const _OwnedMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 19, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 7),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 9.5,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: AppColors.coralLight,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
