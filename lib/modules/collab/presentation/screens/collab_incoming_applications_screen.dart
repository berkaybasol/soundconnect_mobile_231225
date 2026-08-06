import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../profile/presentation/screens/profile_public_bottom_bar.dart';
import '../../data/collab_mock_controller.dart';
import '../../domain/collab_application_models.dart';
import '../../domain/collab_discovery_models.dart';
import '../../domain/collab_management_models.dart';
import '../widgets/collab_action_widgets.dart';
import '../widgets/collab_discovery_widgets.dart';
import '../widgets/collab_management_widgets.dart';

enum _IncomingSort { newest, oldest, rating, completedJobs }

extension on _IncomingSort {
  String get label => switch (this) {
    _IncomingSort.newest => 'En Yeni',
    _IncomingSort.oldest => 'En Eski',
    _IncomingSort.rating => 'En Yüksek Puan',
    _IncomingSort.completedJobs => 'En Çok Tamamlanan İş',
  };
}

class CollabIncomingApplicationsScreen extends StatefulWidget {
  const CollabIncomingApplicationsScreen({
    required this.ownedListing,
    this.controller,
    this.showBottomNavigation = true,
    super.key,
  });

  final CollabOwnedListingRecord ownedListing;
  final CollabMockController? controller;
  final bool showBottomNavigation;

  @override
  State<CollabIncomingApplicationsScreen> createState() =>
      _CollabIncomingApplicationsScreenState();
}

class _CollabIncomingApplicationsScreenState
    extends State<CollabIncomingApplicationsScreen> {
  _IncomingSort _sort = _IncomingSort.newest;
  CollabApplicationStatus? _statusFilter;

  CollabMockController get _controller =>
      widget.controller ?? collabMockController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Başvurular')),
      body: SafeArea(
        top: false,
        bottom: false,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final owned = _currentOwnedListing();
            final applications = _sortedApplications();
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 2, 14, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          owned.listing.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 15),
                        _IncomingListingSummary(owned: owned),
                        const SizedBox(height: 19),
                        Row(
                          children: [
                            Expanded(
                              child: CollabSectionTitle(
                                'Başvurular (${applications.length})',
                              ),
                            ),
                            _SortMenu(
                              selected: _sort,
                              onSelected: (sort) =>
                                  setState(() => _sort = sort),
                            ),
                            const SizedBox(width: 7),
                            _StatusMenu(
                              selected: _statusFilter,
                              onSelected: (status) =>
                                  setState(() => _statusFilter = status),
                            ),
                          ],
                        ),
                        if (_statusFilter != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              CollabApplicationStatusPill(
                                status: _statusFilter!,
                              ),
                              const SizedBox(width: 7),
                              TextButton(
                                onPressed: () =>
                                    setState(() => _statusFilter = null),
                                child: const Text('Filtreyi temizle'),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
                if (applications.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: CollabGradientFrame(
                        radius: 18,
                        padding: const EdgeInsets.all(22),
                        child: Text(
                          'Bu filtreye uygun başvuru bulunmuyor.',
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
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 30),
                    sliver: SliverList.separated(
                      itemCount: applications.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 11),
                      itemBuilder: (context, index) {
                        final application = applications[index];
                        final canAccept =
                            application.status ==
                                CollabApplicationStatus.pending &&
                            owned.status == CollabOwnedListingStatus.open &&
                            (owned.listing.direction ==
                                    CollabDirection.available ||
                                owned.remainingPositions > 0);
                        return _IncomingApplicationCard(
                          application: application,
                          onProfile: () => _showMessage(
                            '${application.applicantProfile.name} profili açılacak.',
                          ),
                          onMessage: () => _showMessage(
                            '${application.applicantProfile.name} ile DM açılacak.',
                          ),
                          onReject:
                              application.status ==
                                  CollabApplicationStatus.pending
                              ? () => _confirmStatusChange(
                                  application,
                                  accept: false,
                                )
                              : null,
                          onAccept: canAccept
                              ? () => _confirmStatusChange(
                                  application,
                                  accept: true,
                                )
                              : null,
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

  CollabOwnedListingRecord _currentOwnedListing() {
    for (final record in _controller.ownedListings) {
      if (record.listing.id == widget.ownedListing.listing.id) return record;
    }
    return widget.ownedListing;
  }

  List<CollabApplicationRecord> _sortedApplications() {
    final items = _controller.incomingApplications
        .where((item) => item.listing.id == widget.ownedListing.listing.id)
        .where((item) => _statusFilter == null || item.status == _statusFilter)
        .toList(growable: true);
    items.sort(switch (_sort) {
      _IncomingSort.newest => (a, b) => b.submittedAt.compareTo(a.submittedAt),
      _IncomingSort.oldest => (a, b) => a.submittedAt.compareTo(b.submittedAt),
      _IncomingSort.rating => (a, b) => b.applicantProfile.rating.compareTo(
        a.applicantProfile.rating,
      ),
      _IncomingSort.completedJobs =>
        (a, b) => b.applicantProfile.completedJobs.compareTo(
          a.applicantProfile.completedJobs,
        ),
    });
    return items;
  }

  Future<void> _confirmStatusChange(
    CollabApplicationRecord application, {
    required bool accept,
  }) async {
    final action = accept ? 'kabul etmek' : 'reddetmek';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(accept ? 'Başvuruyu kabul et' : 'Başvuruyu reddet'),
        content: Text(
          '${application.applicantProfile.name} başvurusunu $action istediğine '
          'emin misin?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(accept ? 'Kabul Et' : 'Reddet'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final changed = accept
        ? _controller.accept(application.id)
        : _controller.reject(application.id);
    _showMessage(
      changed
          ? (accept ? 'Başvuru kabul edildi.' : 'Başvuru reddedildi.')
          : 'Bu başvurunun durumu değiştirilemedi.',
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _IncomingListingSummary extends StatelessWidget {
  const _IncomingListingSummary({required this.owned});

  final CollabOwnedListingRecord owned;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final listing = owned.listing;
    final capacity = owned.capacity;
    final progress = capacity == 0 ? 0.0 : owned.filledPositions / capacity;
    return CollabGradientFrame(
      highlighted: true,
      radius: 20,
      strokeWidth: 1.3,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CollabProfileAvatar(listing: listing, size: 55),
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
                        fontSize: 15,
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
          if (listing.direction == CollabDirection.seeking) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 7,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.socialPink),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _SummaryMetric(
                    value: '${owned.filledPositions}/$capacity',
                    label: 'Kontenjan Dolu',
                  ),
                ),
                Expanded(
                  child: _SummaryMetric(
                    value: '${owned.applicationCount}',
                    label: 'Başvuru',
                  ),
                ),
                Expanded(
                  child: _SummaryMetric(
                    value: '${owned.remainingPositions}',
                    label: 'Kalan Kontenjan',
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _SummaryMetric(
                    value: '${owned.applicationCount}',
                    label: 'İş Teklifi',
                  ),
                ),
                Expanded(
                  child: _SummaryMetric(
                    value: owned.status.label,
                    label: 'İlan Durumu',
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: AppColors.coralLight,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 9.5,
            height: 1.15,
          ),
        ),
      ],
    );
  }
}

class _IncomingApplicationCard extends StatelessWidget {
  const _IncomingApplicationCard({
    required this.application,
    required this.onProfile,
    required this.onMessage,
    required this.onReject,
    required this.onAccept,
  });

  final CollabApplicationRecord application;
  final VoidCallback onProfile;
  final VoidCallback onMessage;
  final VoidCallback? onReject;
  final VoidCallback? onAccept;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = application.applicantProfile;
    return CollabGradientFrame(
      highlighted: application.status == CollabApplicationStatus.pending,
      radius: 19,
      strokeWidth: application.status == CollabApplicationStatus.pending
          ? 1.3
          : 1,
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CollabIdentityAvatar(
                initials: profile.initials,
                profileKind: profile.profileKind,
                avatarAsset: profile.avatarAsset,
                size: 52,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      profile.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Icon(
                          Icons.phone_outlined,
                          color: theme.colorScheme.onSurfaceVariant,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: SelectableText(
                            application.phoneNumber,
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: CollabApplicationStatusPill(status: application.status),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Text(
            application.message,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 11.5,
              height: 1.42,
            ),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: theme.dividerColor),
          const SizedBox(height: 11),
          Row(
            children: [
              Icon(Icons.star_rounded, color: AppColors.socialPurple, size: 20),
              const SizedBox(width: 6),
              Text(
                '${profile.rating.toStringAsFixed(1)} / 5',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w900,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  '${profile.reviewCount} yorum',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ),
              const Spacer(),
              Icon(
                Icons.work_outline_rounded,
                color: theme.colorScheme.onSurfaceVariant,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                '${profile.completedJobs}',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'iş',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          CollabActionsWrap(
            actions: [
              CollabCardAction(
                label: 'Profili Gör',
                icon: Icons.account_circle_outlined,
                onPressed: onProfile,
              ),
              if (application.status == CollabApplicationStatus.pending ||
                  application.status == CollabApplicationStatus.accepted)
                CollabCardAction(
                  label: application.status == CollabApplicationStatus.accepted
                      ? 'Mesaja Git'
                      : 'Mesaj Gönder',
                  icon: Icons.chat_bubble_outline_rounded,
                  tone: CollabCardActionTone.brand,
                  onPressed: onMessage,
                ),
              if (onReject != null)
                CollabCardAction(
                  label: 'Reddet',
                  icon: Icons.close_rounded,
                  tone: CollabCardActionTone.danger,
                  onPressed: onReject,
                ),
              if (onAccept != null)
                CollabCardAction(
                  label: 'Kabul Et',
                  icon: Icons.check_rounded,
                  tone: CollabCardActionTone.success,
                  onPressed: onAccept,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SortMenu extends StatelessWidget {
  const _SortMenu({required this.selected, required this.onSelected});

  final _IncomingSort selected;
  final ValueChanged<_IncomingSort> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_IncomingSort>(
      tooltip: 'Başvuruları sırala',
      initialValue: selected,
      onSelected: onSelected,
      itemBuilder: (_) => _IncomingSort.values
          .map((sort) => PopupMenuItem(value: sort, child: Text(sort.label)))
          .toList(growable: false),
      child: CollabGradientFrame(
        radius: 13,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selected.label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 17),
          ],
        ),
      ),
    );
  }
}

class _StatusMenu extends StatelessWidget {
  const _StatusMenu({required this.selected, required this.onSelected});

  final CollabApplicationStatus? selected;
  final ValueChanged<CollabApplicationStatus?> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Başvuru durumunu filtrele',
      onSelected: (value) {
        if (value == 'all') {
          onSelected(null);
          return;
        }
        onSelected(
          CollabApplicationStatus.values.firstWhere(
            (status) => status.name == value,
          ),
        );
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'all', child: Text('Tümü')),
        ...CollabApplicationStatus.values.map(
          (status) =>
              PopupMenuItem(value: status.name, child: Text(status.label)),
        ),
      ],
      icon: Icon(
        selected == null ? Icons.tune_rounded : Icons.filter_alt_rounded,
        color: selected == null ? null : AppColors.coralLight,
      ),
    );
  }
}
