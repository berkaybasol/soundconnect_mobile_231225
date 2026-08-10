import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/gradient_text.dart';
import '../../../profile/presentation/screens/profile_public_bottom_bar.dart';
import '../../data/collab_mock_controller.dart';
import '../../domain/collab_application_models.dart';
import '../../domain/collab_discovery_models.dart';
import '../theme/collab_visual_theme.dart';
import '../../domain/collab_management_models.dart';
import '../widgets/collab_action_widgets.dart';
import '../widgets/collab_discovery_widgets.dart';
import '../widgets/collab_management_widgets.dart';
import 'collab_listing_detail_screen.dart';

class CollabMyApplicationsScreen extends StatefulWidget {
  const CollabMyApplicationsScreen({
    this.controller,
    this.showBottomNavigation = true,
    super.key,
  });

  final CollabMockController? controller;
  final bool showBottomNavigation;

  @override
  State<CollabMyApplicationsScreen> createState() =>
      _CollabMyApplicationsScreenState();
}

class _CollabMyApplicationsScreenState
    extends State<CollabMyApplicationsScreen> {
  CollabApplicationStatus? _filter;

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
            final applications =
                _controller.outgoingApplications
                    .where((item) => _filter == null || item.status == _filter)
                    .toList(growable: false)
                  ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
            final completedJobs = _filter == null
                ? _controller.jobs
                      .where((job) => job.status == CollabJobStatus.completed)
                      .toList(growable: false)
                : const <CollabJobRecord>[];
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 15, 16, 0),
                    child: _ApplicationsHeader(
                      onBack: Navigator.of(context).canPop()
                          ? () => Navigator.of(context).pop()
                          : null,
                      filterActive: _filter != null,
                      onClearFilter: () => setState(() => _filter = null),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: _StatusFilterRail(
                      selected: _filter,
                      onSelected: (status) => setState(() => _filter = status),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 19, 16, 10),
                    child: CollabSectionTitle(
                      'Başvurular (${applications.length})',
                    ),
                  ),
                ),
                if (applications.isEmpty)
                  const SliverToBoxAdapter(child: _NoApplicationsCard())
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    sliver: SliverList.separated(
                      itemCount: applications.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 11),
                      itemBuilder: (context, index) {
                        final application = applications[index];
                        return _OutgoingApplicationCard(
                          application: application,
                          saved: _controller.isListingSaved(
                            application.listing.id,
                          ),
                          onSaved: () => _controller.toggleListingSaved(
                            application.listing.id,
                          ),
                          onDetail: () => _openDetail(application),
                          onMessage: () => _showMessage(
                            '${application.listing.ownerName} ile DM açılacak.',
                          ),
                          onWithdraw:
                              application.status ==
                                  CollabApplicationStatus.pending
                              ? () => _confirmWithdraw(application)
                              : null,
                        );
                      },
                    ),
                  ),
                if (completedJobs.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
                      child: CollabSectionTitle(
                        'Tamamlanan İşler (${completedJobs.length})',
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 28),
                    sliver: SliverList.separated(
                      itemCount: completedJobs.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 11),
                      itemBuilder: (context, index) {
                        final job = completedJobs[index];
                        return _CompletedJobCard(
                          job: job,
                          onReview: job.isReviewed
                              ? null
                              : () => _openReview(job),
                        );
                      },
                    ),
                  ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 30)),
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

  void _openDetail(CollabApplicationRecord application) {
    Navigator.of(context).push<void>(
      collabPageRoute(
        builder: (_) => CollabListingDetailScreen(
          listing: application.listing,
          initiallySaved: _controller.isListingSaved(application.listing.id),
          showBottomNavigation: widget.showBottomNavigation,
          controller: _controller,
          initialActionSent: true,
        ),
      ),
    );
  }

  Future<void> _confirmWithdraw(CollabApplicationRecord application) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Başvuruyu geri çek'),
        content: const Text(
          'Bu başvuruyu geri çekmek istediğine emin misin? Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Geri Çek', style: TextStyle(color: AppColors.coral)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final changed = _controller.withdraw(application.id);
    if (changed) _showMessage('Başvurun geri çekildi.');
  }

  Future<void> _openReview(CollabJobRecord job) async {
    final result = await showModalBottomSheet<({int rating, String review})>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _JobReviewSheet(),
    );
    if (!mounted || result == null) return;
    _controller.reviewJob(job.id, rating: result.rating, review: result.review);
    _showMessage('Puanın ve yorumun mock olarak kaydedildi.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ApplicationsHeader extends StatelessWidget {
  const _ApplicationsHeader({
    required this.onBack,
    required this.filterActive,
    required this.onClearFilter,
  });

  final VoidCallback? onBack;
  final bool filterActive;
  final VoidCallback onClearFilter;

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
                'Başvurularım',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: filterActive ? onClearFilter : null,
          tooltip: filterActive ? 'Durum filtresini temizle' : 'Durum filtresi',
          icon: Icon(
            filterActive ? Icons.filter_alt_off_rounded : Icons.tune_rounded,
          ),
        ),
      ],
    );
  }
}

class _StatusFilterRail extends StatelessWidget {
  const _StatusFilterRail({required this.selected, required this.onSelected});

  final CollabApplicationStatus? selected;
  final ValueChanged<CollabApplicationStatus?> onSelected;

  @override
  Widget build(BuildContext context) {
    const options = <(CollabApplicationStatus?, String)>[
      (null, 'Tümü'),
      (CollabApplicationStatus.pending, 'Bekliyor'),
      (CollabApplicationStatus.accepted, 'Kabul Edildi'),
      (CollabApplicationStatus.rejected, 'Reddedildi'),
      (CollabApplicationStatus.withdrawnByApplicant, 'Başvuran geri çekti'),
      (
        CollabApplicationStatus.invalidatedByListingClosure,
        'İlan kapanınca geçersizleşti',
      ),
    ];
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
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

class _OutgoingApplicationCard extends StatelessWidget {
  const _OutgoingApplicationCard({
    required this.application,
    required this.saved,
    required this.onSaved,
    required this.onDetail,
    required this.onMessage,
    required this.onWithdraw,
  });

  final CollabApplicationRecord application;
  final bool saved;
  final VoidCallback onSaved;
  final VoidCallback onDetail;
  final VoidCallback onMessage;
  final VoidCallback? onWithdraw;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final listing = application.listing;
    return CollabGradientFrame(
      highlighted: application.status == CollabApplicationStatus.pending,
      radius: 19,
      strokeWidth: application.status == CollabApplicationStatus.pending
          ? 1.25
          : 1,
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CollabProfileAvatar(listing: listing, size: 51),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.ownerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      listing.ownerSubtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 7),
              Flexible(
                child: CollabApplicationStatusPill(status: application.status),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onSaved,
                tooltip: saved ? 'Kaydı kaldır' : 'İlanı kaydet',
                icon: Icon(
                  saved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: saved ? AppColors.coralLight : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Text(
            listing.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 15,
              height: 1.22,
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
                label: listing.wantedSummary,
                color: listing.direction == CollabDirection.seeking
                    ? AppColors.socialOrange
                    : AppColors.spotifyGreen,
              ),
            ],
          ),
          const SizedBox(height: 11),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth - 8) / 2;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  CollabTinyMeta(
                    width: width,
                    icon: Icons.location_on_outlined,
                    label: listing.location,
                  ),
                  CollabTinyMeta(
                    width: width,
                    icon: Icons.calendar_month_outlined,
                    label: collabScheduleText(listing),
                  ),
                  CollabTinyMeta(
                    width: width,
                    icon: Icons.music_note_rounded,
                    label: listing.role,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 13),
          CollabActionsWrap(
            actions: [
              CollabCardAction(
                label: 'Detayı Gör',
                icon: Icons.open_in_new_rounded,
                onPressed: onDetail,
              ),
              if (application.status == CollabApplicationStatus.pending ||
                  application.status == CollabApplicationStatus.accepted)
                CollabCardAction(
                  label: 'Mesaja Git',
                  icon: Icons.chat_bubble_outline_rounded,
                  tone: CollabCardActionTone.brand,
                  onPressed: onMessage,
                ),
              if (onWithdraw != null)
                CollabCardAction(
                  label: 'Geri Çek',
                  icon: Icons.undo_rounded,
                  tone: CollabCardActionTone.danger,
                  onPressed: onWithdraw,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompletedJobCard extends StatelessWidget {
  const _CompletedJobCard({required this.job, required this.onReview});

  final CollabJobRecord job;
  final VoidCallback? onReview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final listing = job.application.listing;
    return CollabGradientFrame(
      radius: 19,
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CollabProfileAvatar(listing: listing, size: 48),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.ownerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      listing.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              CollabStatusPill(
                label: 'Tamamlandı',
                color: AppColors.spotifyGreen,
              ),
            ],
          ),
          const SizedBox(height: 13),
          CollabPrimaryAction(
            label: job.isReviewed ? 'Değerlendirildi' : 'Puanla & Yorum Yap',
            icon: job.isReviewed ? Icons.check_rounded : Icons.star_outline,
            onPressed: onReview,
          ),
        ],
      ),
    );
  }
}

class _JobReviewSheet extends StatefulWidget {
  const _JobReviewSheet();

  @override
  State<_JobReviewSheet> createState() => _JobReviewSheetState();
}

class _JobReviewSheetState extends State<_JobReviewSheet> {
  final TextEditingController _reviewController = TextEditingController();
  int _rating = 0;

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        4,
        16,
        18 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CollabSectionTitle('İşi değerlendir'),
          const SizedBox(height: 6),
          Text(
            'Collab deneyimini 5 üzerinden puanla ve kısa bir yorum bırak.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              5,
              (index) => IconButton(
                onPressed: () => setState(() => _rating = index + 1),
                tooltip: '${index + 1} yıldız',
                icon: Icon(
                  index < _rating ? Icons.star_rounded : Icons.star_border,
                  color: AppColors.socialPurple,
                  size: 31,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _reviewController,
            maxLength: 300,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Deneyimini kısaca anlat (isteğe bağlı)',
            ),
          ),
          const SizedBox(height: 10),
          CollabPrimaryAction(
            label: 'Değerlendirmeyi Kaydet',
            onPressed: _rating == 0
                ? null
                : () => Navigator.of(context).pop((
                    rating: _rating,
                    review: _reviewController.text.trim(),
                  )),
          ),
        ],
      ),
    );
  }
}

class _NoApplicationsCard extends StatelessWidget {
  const _NoApplicationsCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: CollabGradientFrame(
        radius: 18,
        padding: const EdgeInsets.all(22),
        child: Text(
          'Bu durumda bir başvurun bulunmuyor.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
