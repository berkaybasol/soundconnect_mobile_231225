import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/gradient_text.dart';
import '../../../profile/presentation/screens/profile_public_bottom_bar.dart';
import '../../domain/collab_commands.dart';
import '../../domain/collab_types.dart';
import '../../domain/entities/collab_actor.dart';
import '../../domain/entities/collab_application.dart';
import '../../domain/entities/collab_job.dart';
import '../collab_deep_link_scroll.dart';
import '../collab_navigation.dart';
import '../cubit/collab_async_state.dart';
import '../cubit/collab_jobs_cubit.dart';
import '../cubit/collab_my_applications_cubit.dart';
import '../cubit/collab_paged_cubit.dart';
import '../theme/collab_visual_theme.dart';
import '../widgets/collab_action_widgets.dart';
import '../widgets/collab_discovery_widgets.dart';
import '../widgets/collab_management_widgets.dart';
import 'collab_actor_reviews_screen.dart';
import 'collab_listing_detail_screen.dart';

enum CollabApplicationsSection { applications, jobs }

class CollabMyApplicationsScreen extends StatefulWidget {
  const CollabMyApplicationsScreen({
    this.showBottomNavigation = true,
    this.applicationsCubit,
    this.jobsCubit,
    this.initialSection = CollabApplicationsSection.applications,
    this.initialApplicationId,
    this.initialJobId,
    this.initialReviewId,
    this.initialAction,
    super.key,
  });

  final bool showBottomNavigation;
  final CollabMyApplicationsCubit? applicationsCubit;
  final CollabJobsCubit? jobsCubit;
  final CollabApplicationsSection initialSection;
  final String? initialApplicationId;
  final String? initialJobId;
  final String? initialReviewId;
  final String? initialAction;

  @override
  State<CollabMyApplicationsScreen> createState() =>
      _CollabMyApplicationsScreenState();
}

class _CollabMyApplicationsScreenState
    extends State<CollabMyApplicationsScreen> {
  late final CollabMyApplicationsCubit _applicationsCubit;
  late final CollabJobsCubit _jobsCubit;
  late final bool _ownsApplicationsCubit;
  late final bool _ownsJobsCubit;
  late final ScrollController _scrollController;
  late CollabApplicationsSection _section;
  final GlobalKey _initialApplicationKey = GlobalKey();
  final GlobalKey _initialJobKey = GlobalKey();
  bool _initialApplicationTargetHandled = false;
  bool _initialApplicationTargetScheduled = false;
  bool _initialApplicationRevealDeferred = false;
  bool _initialJobTargetHandled = false;
  bool _initialJobTargetScheduled = false;
  bool _initialJobRevealDeferred = false;
  bool _initialJobCompletedFallbackAttempted = false;

  @override
  void initState() {
    super.initState();
    _section = widget.initialSection;
    _ownsApplicationsCubit = widget.applicationsCubit == null;
    _ownsJobsCubit = widget.jobsCubit == null;
    _applicationsCubit =
        widget.applicationsCubit ?? serviceLocator<CollabMyApplicationsCubit>();
    _jobsCubit = widget.jobsCubit ?? serviceLocator<CollabJobsCubit>();
    _scrollController = ScrollController()..addListener(_onScroll);
    unawaited(_applicationsCubit.loadInitial());
    final action = widget.initialAction?.trim().toUpperCase();
    final completedTarget =
        widget.initialReviewId?.trim().isNotEmpty == true ||
        action == 'REVIEW_RECEIVED' ||
        action == 'JOB_COMPLETED';
    unawaited(
      _jobsCubit.setStatusFilter(
        completedTarget ? CollabJobStatus.completed : CollabJobStatus.active,
      ),
    );
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    if (_ownsApplicationsCubit) unawaited(_applicationsCubit.close());
    if (_ownsJobsCubit) unawaited(_jobsCubit.close());
    super.dispose();
  }

  void _onScroll() {
    if (_section == CollabApplicationsSection.applications) {
      if (_initialApplicationRevealDeferred &&
          _initialApplicationKey.currentContext != null) {
        _initialApplicationRevealDeferred = false;
        _scheduleInitialApplicationTarget(_applicationsCubit.state);
      }
      if (_scrollController.position.extentAfter >= 320) return;
      if (_applicationsCubit.state.loadMoreError != null) return;
      unawaited(_applicationsCubit.loadMore());
    } else {
      if (_initialJobRevealDeferred && _initialJobKey.currentContext != null) {
        _initialJobRevealDeferred = false;
        _scheduleInitialJobTarget(_jobsCubit.state);
      }
      if (_scrollController.position.extentAfter >= 320) return;
      if (_jobsCubit.state.loadMoreError != null) return;
      unawaited(_jobsCubit.loadMore());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<CollabMyApplicationsCubit>.value(
          value: _applicationsCubit,
        ),
        BlocProvider<CollabJobsCubit>.value(value: _jobsCubit),
      ],
      child: MultiBlocListener(
        listeners: [
          BlocListener<
            CollabMyApplicationsCubit,
            CollabPagedState<CollabApplication>
          >(
            listenWhen: (previous, current) =>
                (previous.actionError != current.actionError &&
                    current.actionError != null) ||
                (previous.loadMoreError != current.loadMoreError &&
                    current.loadMoreError != null) ||
                (previous.error != current.error &&
                    current.error != null &&
                    current.items.isNotEmpty),
            listener: (_, state) => _showMessage(
              (state.actionError ?? state.loadMoreError ?? state.error)!
                  .message,
            ),
          ),
          BlocListener<CollabJobsCubit, CollabPagedState<CollabJob>>(
            listenWhen: (previous, current) =>
                (previous.actionError != current.actionError &&
                    current.actionError != null) ||
                (previous.loadMoreError != current.loadMoreError &&
                    current.loadMoreError != null) ||
                (previous.error != current.error &&
                    current.error != null &&
                    current.items.isNotEmpty),
            listener: (_, state) => _showMessage(
              (state.actionError ?? state.loadMoreError ?? state.error)!
                  .message,
            ),
          ),
        ],
        child:
            BlocBuilder<
              CollabMyApplicationsCubit,
              CollabPagedState<CollabApplication>
            >(
              builder: (context, applicationsState) =>
                  BlocBuilder<CollabJobsCubit, CollabPagedState<CollabJob>>(
                    builder: (context, jobsState) =>
                        _buildScaffold(context, applicationsState, jobsState),
                  ),
            ),
      ),
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    CollabPagedState<CollabApplication> applicationsState,
    CollabPagedState<CollabJob> jobsState,
  ) {
    _scheduleInitialApplicationTarget(applicationsState);
    _scheduleInitialJobTarget(jobsState);
    final state = _section == CollabApplicationsSection.applications
        ? applicationsState
        : jobsState;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _section == CollabApplicationsSection.applications
              ? _applicationsCubit.refresh
              : _jobsCubit.refresh,
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
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                  child: _SectionSelector(
                    selected: _section,
                    onSelected: (section) {
                      setState(() => _section = section);
                      if (_scrollController.hasClients) {
                        _scrollController.jumpTo(0);
                      }
                    },
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 15),
                  child: _section == CollabApplicationsSection.applications
                      ? _ApplicationStatusRail(
                          selected: _applicationsCubit.statusFilter,
                          onSelected: (status) => unawaited(
                            _applicationsCubit.setStatusFilter(status),
                          ),
                        )
                      : _JobStatusRail(
                          selected: _jobsCubit.statusFilter,
                          onSelected: (status) =>
                              unawaited(_jobsCubit.setStatusFilter(status)),
                        ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 17, 16, 11),
                  child: Text(
                    '${state.totalElements} ${_section == CollabApplicationsSection.applications ? 'başvuru' : 'iş'}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ),
              if (_section == CollabApplicationsSection.applications)
                ..._applicationSlivers(applicationsState)
              else
                ..._jobSlivers(jobsState),
            ],
          ),
        ),
      ),
      bottomNavigationBar: widget.showBottomNavigation
          ? ProfilePublicBottomBar(currentIndex: 1)
          : null,
    );
  }

  List<Widget> _applicationSlivers(CollabPagedState<CollabApplication> state) {
    final placeholder = _pagedPlaceholder<CollabApplication>(
      state,
      emptyMessage: 'Bu filtreye uygun başvurun bulunmuyor.',
      retry: _applicationsCubit.loadInitial,
    );
    if (placeholder != null) return [placeholder];
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        sliver: SliverList.separated(
          itemCount: state.items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 11),
          itemBuilder: (context, index) {
            final application = state.items[index];
            final busy = state.actionIds.contains(application.id);
            return KeyedSubtree(
              key: application.id == widget.initialApplicationId?.trim()
                  ? _initialApplicationKey
                  : ValueKey<String>('collab-application-${application.id}'),
              child: _OutgoingApplicationCard(
                application: application,
                busy: busy,
                onSave: application.listing.isOpen
                    ? () => _applicationsCubit.toggleSaved(application)
                    : null,
                onDetail: () => _openDetail(application.listing.id),
                onMessage:
                    application.listing.publisher.contactUserId.trim().isEmpty
                    ? null
                    : () => openCollabActorConversation(
                        context,
                        application.listing.publisher,
                      ),
                onWithdraw: application.isPending
                    ? () => _confirmWithdraw(application)
                    : null,
              ),
            );
          },
        ),
      ),
      SliverToBoxAdapter(
        child: CollabPagedFooter(
          key: const ValueKey<String>(
            'collab-my-applications-load-more-footer',
          ),
          loading: state.isLoadingMore,
          hasError: state.loadMoreError != null,
          onRetry: _applicationsCubit.loadMore,
        ),
      ),
    ];
  }

  List<Widget> _jobSlivers(CollabPagedState<CollabJob> state) {
    final placeholder = _pagedPlaceholder<CollabJob>(
      state,
      emptyMessage: _jobsCubit.statusFilter == CollabJobStatus.completed
          ? 'Henüz tamamlanan bir Collab işin yok.'
          : 'Aktif bir Collab işin bulunmuyor.',
      retry: _jobsCubit.loadInitial,
    );
    if (placeholder != null) return [placeholder];
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        sliver: SliverList.separated(
          itemCount: state.items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 11),
          itemBuilder: (context, index) {
            final job = state.items[index];
            final busy = state.actionIds.contains(job.id);
            final other = _otherActor(job);
            return KeyedSubtree(
              key: job.id == widget.initialJobId?.trim()
                  ? _initialJobKey
                  : ValueKey<String>('collab-job-${job.id}'),
              child: _JobCard(
                job: job,
                other: other,
                busy: busy,
                otherConfirmed: _otherConfirmed(job),
                onProfile: () => openCollabActorProfile(context, other),
                onMessage: other.contactUserId.trim().isEmpty
                    ? null
                    : () => openCollabActorConversation(context, other),
                onDetail: () => _openDetail(job.listing.id),
                onConfirm: !job.isCompleted && !job.confirmedByMe
                    ? () => _confirmCompletion(job)
                    : null,
                onReview: job.isCompleted && !job.reviewedByMe
                    ? () => _openReview(job)
                    : null,
              ),
            );
          },
        ),
      ),
      SliverToBoxAdapter(
        child: CollabPagedFooter(
          key: const ValueKey<String>('collab-jobs-load-more-footer'),
          loading: state.isLoadingMore,
          hasError: state.loadMoreError != null,
          onRetry: _jobsCubit.loadMore,
        ),
      ),
    ];
  }

  Widget? _pagedPlaceholder<T>(
    CollabPagedState<T> state, {
    required String emptyMessage,
    required VoidCallback retry,
  }) {
    if (state.status == CollabLoadStatus.loading && state.items.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.status == CollabLoadStatus.failure && state.items.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _LoadError(message: state.error?.message, onRetry: retry),
      );
    }
    if (state.items.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _EmptyState(message: emptyMessage),
      );
    }
    return null;
  }

  CollabActor _otherActor(CollabJob job) =>
      job.listing.ownedByMe ? job.applicant : job.publisher;

  bool _otherConfirmed(CollabJob job) => job.listing.ownedByMe
      ? job.applicantConfirmedCompletion
      : job.publisherConfirmedCompletion;

  void _scheduleInitialApplicationTarget(
    CollabPagedState<CollabApplication> state,
  ) {
    final targetId = widget.initialApplicationId?.trim() ?? '';
    if (_initialApplicationTargetHandled ||
        _initialApplicationTargetScheduled ||
        _section != CollabApplicationsSection.applications ||
        targetId.isEmpty ||
        state.status == CollabLoadStatus.initial ||
        state.status == CollabLoadStatus.loading ||
        state.status == CollabLoadStatus.failure) {
      return;
    }
    final targetIndex = state.items.indexWhere(
      (application) => application.id == targetId,
    );
    if (targetIndex >= 0) {
      if (_initialApplicationRevealDeferred &&
          _initialApplicationKey.currentContext == null) {
        return;
      }
      _initialApplicationTargetScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final revealed = await revealCollabPagedTarget(
          controller: _scrollController,
          targetKey: _initialApplicationKey,
          targetIndex: targetIndex,
          itemCount: state.items.length,
          estimatedItemExtent: 260,
        );
        if (!mounted) return;
        _initialApplicationTargetScheduled = false;
        _initialApplicationTargetHandled = revealed;
        _initialApplicationRevealDeferred = !revealed;
        if (!revealed) {
          _showMessage(
            'Hedef başvuru yüklendi ancak otomatik kaydırılamadı. '
            'Listede elle kaydırarak açabilirsin.',
          );
        }
      });
      return;
    }
    if (state.loadMoreError != null) return;
    if (state.hasNext && !state.isLoadingMore) {
      _initialApplicationTargetScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await _applicationsCubit.loadMore();
        _initialApplicationTargetScheduled = false;
        if (mounted) {
          _scheduleInitialApplicationTarget(_applicationsCubit.state);
        }
      });
      return;
    }
    if (!state.isLoadingMore) {
      _initialApplicationTargetHandled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showMessage('Bildirimdeki başvuru artık listede bulunamıyor.');
        }
      });
    }
  }

  void _scheduleInitialJobTarget(CollabPagedState<CollabJob> state) {
    final targetId = widget.initialJobId?.trim() ?? '';
    if (_initialJobTargetHandled ||
        _initialJobTargetScheduled ||
        _section != CollabApplicationsSection.jobs ||
        targetId.isEmpty ||
        state.status == CollabLoadStatus.initial ||
        state.status == CollabLoadStatus.loading ||
        state.status == CollabLoadStatus.failure) {
      return;
    }

    final target = state.items.where((job) => job.id == targetId).firstOrNull;
    if (target != null) {
      if (widget.initialReviewId?.trim().isNotEmpty == true ||
          widget.initialAction?.trim().toUpperCase() == 'REVIEW_RECEIVED') {
        _initialJobTargetHandled = true;
        _initialJobTargetScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final reviewedActor = target.listing.ownedByMe
              ? target.publisher
              : target.applicant;
          unawaited(
            Navigator.of(context).push<void>(
              collabPageRoute(
                builder: (_) => CollabActorReviewsScreen(
                  actor: reviewedActor,
                  initialReviewId: widget.initialReviewId,
                  showBottomNavigation: widget.showBottomNavigation,
                ),
              ),
            ),
          );
        });
      } else {
        final targetIndex = state.items.indexOf(target);
        if (_initialJobRevealDeferred &&
            _initialJobKey.currentContext == null) {
          return;
        }
        _initialJobTargetScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          final revealed = await revealCollabPagedTarget(
            controller: _scrollController,
            targetKey: _initialJobKey,
            targetIndex: targetIndex,
            itemCount: state.items.length,
            estimatedItemExtent: 280,
          );
          if (!mounted) return;
          _initialJobTargetScheduled = false;
          _initialJobTargetHandled = revealed;
          _initialJobRevealDeferred = !revealed;
          if (!revealed) {
            _showMessage(
              'Hedef Collab işi yüklendi ancak otomatik kaydırılamadı. '
              'Listede elle kaydırarak açabilirsin.',
            );
          }
        });
      }
      return;
    }

    if (state.loadMoreError != null) return;
    if (state.hasNext && !state.isLoadingMore) {
      _initialJobTargetScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await _jobsCubit.loadMore();
        _initialJobTargetScheduled = false;
        if (mounted) _scheduleInitialJobTarget(_jobsCubit.state);
      });
      return;
    }

    final action = widget.initialAction?.trim().toUpperCase();
    final canFallbackToCompleted =
        !_initialJobCompletedFallbackAttempted &&
        _jobsCubit.statusFilter == CollabJobStatus.active &&
        (action == 'APPLICATION_ACCEPTED' ||
            action == 'JOB_COMPLETION_REQUESTED');
    if (canFallbackToCompleted && !state.isLoadingMore) {
      _initialJobCompletedFallbackAttempted = true;
      _initialJobTargetScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await _jobsCubit.setStatusFilter(CollabJobStatus.completed);
        _initialJobTargetScheduled = false;
        if (mounted) _scheduleInitialJobTarget(_jobsCubit.state);
      });
      return;
    }

    if (!state.isLoadingMore) {
      _initialJobTargetHandled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showMessage('Bildirimdeki Collab işi artık listede bulunamıyor.');
        }
      });
    }
  }

  Future<void> _openDetail(String listingId) async {
    await Navigator.of(context).push<void>(
      collabPageRoute(
        builder: (_) => CollabListingDetailScreen(
          listingId: listingId,
          showBottomNavigation: widget.showBottomNavigation,
        ),
      ),
    );
    if (mounted && _section == CollabApplicationsSection.applications) {
      await _applicationsCubit.refresh();
    }
  }

  Future<void> _confirmWithdraw(CollabApplication application) async {
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
            child: Text('Geri çek', style: TextStyle(color: AppColors.coral)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _applicationsCubit.withdraw(application);
    }
  }

  Future<void> _confirmCompletion(CollabJob job) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('İş tamamlandı mı?'),
        content: const Text(
          'Tamamlanma iki tarafın ayrı onayıyla kesinleşir. Onayını daha sonra geri alamazsın.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Tamamlandı',
              style: TextStyle(color: AppColors.spotifyGreen),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _jobsCubit.confirmCompletion(job);
  }

  Future<void> _openReview(CollabJob job) async {
    final input = await showModalBottomSheet<CollabReviewInput>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _ReviewSheet(),
    );
    if (input == null || !mounted) return;
    await _jobsCubit.review(job, input);
    if (mounted && _jobsCubit.state.actionError == null) {
      _showMessage('Puanın ve yorumun kaydedildi.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => Row(
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
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            Text(
              'Başvurularım ve işlerim',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13.5,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _SectionSelector extends StatelessWidget {
  const _SectionSelector({required this.selected, required this.onSelected});

  final CollabApplicationsSection selected;
  final ValueChanged<CollabApplicationsSection> onSelected;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: CollabChoiceChip(
          label: 'Başvurularım',
          icon: Icons.outbox_outlined,
          selected: selected == CollabApplicationsSection.applications,
          onTap: () => onSelected(CollabApplicationsSection.applications),
        ),
      ),
      const SizedBox(width: 9),
      Expanded(
        child: CollabChoiceChip(
          label: 'İşlerim',
          icon: Icons.handshake_outlined,
          selected: selected == CollabApplicationsSection.jobs,
          onTap: () => onSelected(CollabApplicationsSection.jobs),
        ),
      ),
    ],
  );
}

class _ApplicationStatusRail extends StatelessWidget {
  const _ApplicationStatusRail({
    required this.selected,
    required this.onSelected,
  });

  final CollabApplicationStatus? selected;
  final ValueChanged<CollabApplicationStatus?> onSelected;

  @override
  Widget build(BuildContext context) {
    const options = <(CollabApplicationStatus?, String)>[
      (null, 'Tümü'),
      (CollabApplicationStatus.pending, 'Bekliyor'),
      (CollabApplicationStatus.accepted, 'Kabul edildi'),
      (CollabApplicationStatus.rejected, 'Reddedildi'),
      (CollabApplicationStatus.withdrawnByApplicant, 'Geri çekildi'),
      (CollabApplicationStatus.invalidatedByListingClosure, 'Geçersizleşti'),
    ];
    return _FilterRail<CollabApplicationStatus>(
      options: options,
      selected: selected,
      onSelected: onSelected,
    );
  }
}

class _JobStatusRail extends StatelessWidget {
  const _JobStatusRail({required this.selected, required this.onSelected});

  final CollabJobStatus? selected;
  final ValueChanged<CollabJobStatus?> onSelected;

  @override
  Widget build(BuildContext context) => _FilterRail<CollabJobStatus>(
    options: const [
      (CollabJobStatus.active, 'Aktif'),
      (CollabJobStatus.completed, 'Tamamlandı'),
      (null, 'Tümü'),
    ],
    selected: selected,
    onSelected: onSelected,
  );
}

class _FilterRail<T> extends StatelessWidget {
  const _FilterRail({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<(T?, String)> options;
  final T? selected;
  final ValueChanged<T?> onSelected;

  @override
  Widget build(BuildContext context) => SizedBox(
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

class _OutgoingApplicationCard extends StatelessWidget {
  const _OutgoingApplicationCard({
    required this.application,
    required this.busy,
    required this.onSave,
    required this.onDetail,
    required this.onMessage,
    required this.onWithdraw,
  });

  final CollabApplication application;
  final bool busy;
  final VoidCallback? onSave;
  final VoidCallback onDetail;
  final VoidCallback? onMessage;
  final VoidCallback? onWithdraw;

  @override
  Widget build(BuildContext context) {
    final listing = application.listing;
    final theme = Theme.of(context);
    return CollabGradientFrame(
      highlighted: application.isPending,
      radius: 19,
      strokeWidth: application.isPending ? 1.25 : 1,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CollabActorHeader(
            actor: listing.publisher,
            onTap: () => openCollabActorProfile(context, listing.publisher),
            trailing: CollabApplicationStatusPill(status: application.status),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  listing.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (onSave != null)
                IconButton(
                  onPressed: busy ? null : onSave,
                  tooltip: listing.savedByMe
                      ? 'Kaydedilenlerden çıkar'
                      : 'İlanı kaydet',
                  icon: Icon(
                    listing.savedByMe
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    color: listing.savedByMe ? AppColors.coralLight : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 9,
            runSpacing: 8,
            children: [
              CollabTinyMeta(
                icon: Icons.location_on_outlined,
                label: listing.city.name,
              ),
              CollabTinyMeta(
                icon: Icons.schedule_rounded,
                label: collabListingSchedule(listing),
              ),
              CollabTinyMeta(
                icon: Icons.send_outlined,
                label: collabShortDate(application.submittedAt),
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
                label: 'Mesaj',
                icon: Icons.chat_bubble_outline_rounded,
                tone: CollabCardActionTone.brand,
                onPressed: busy ? null : onMessage,
              ),
              if (onWithdraw != null)
                CollabCardAction(
                  label: 'Geri çek',
                  icon: Icons.undo_rounded,
                  tone: CollabCardActionTone.danger,
                  busy: busy,
                  onPressed: busy ? null : onWithdraw,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({
    required this.job,
    required this.other,
    required this.busy,
    required this.otherConfirmed,
    required this.onProfile,
    required this.onMessage,
    required this.onDetail,
    required this.onConfirm,
    required this.onReview,
  });

  final CollabJob job;
  final CollabActor other;
  final bool busy;
  final bool otherConfirmed;
  final VoidCallback onProfile;
  final VoidCallback? onMessage;
  final VoidCallback onDetail;
  final VoidCallback? onConfirm;
  final VoidCallback? onReview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final confirmationText = job.isCompleted
        ? 'İki taraf da işi tamamladı.'
        : job.confirmedByMe
        ? 'Sen onayladın · Karşı taraf bekleniyor.'
        : otherConfirmed
        ? 'Karşı taraf onayladı · Senin onayın bekleniyor.'
        : 'Tamamlanması için iki tarafın da onayı gerekir.';
    return CollabGradientFrame(
      highlighted: !job.isCompleted,
      radius: 19,
      strokeWidth: job.isCompleted ? 1 : 1.25,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CollabActorHeader(
            actor: other,
            onTap: onProfile,
            trailing: CollabJobStatusPill(status: job.status),
          ),
          const SizedBox(height: 12),
          Text(
            job.listing.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 15.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  job.isCompleted
                      ? Icons.verified_rounded
                      : Icons.check_circle_outline_rounded,
                  size: 18,
                  color: job.isCompleted
                      ? AppColors.spotifyGreen
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    confirmationText,
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
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
                label: 'Mesaj',
                icon: Icons.chat_bubble_outline_rounded,
                tone: CollabCardActionTone.brand,
                onPressed: busy ? null : onMessage,
              ),
              if (onConfirm != null)
                CollabCardAction(
                  label: 'İşi tamamladım',
                  icon: Icons.task_alt_rounded,
                  tone: CollabCardActionTone.success,
                  busy: busy,
                  onPressed: busy ? null : onConfirm,
                ),
              if (job.isCompleted)
                CollabCardAction(
                  label: job.reviewedByMe
                      ? 'Değerlendirildi'
                      : 'Puanla ve yorumla',
                  icon: job.reviewedByMe
                      ? Icons.star_rounded
                      : Icons.star_outline,
                  tone: CollabCardActionTone.success,
                  busy: busy,
                  onPressed: busy ? null : onReview,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet();

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  final TextEditingController _commentController = TextEditingController();
  int _rating = 5;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Collab deneyimini değerlendir',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          Semantics(
            label: '$_rating üzerinden 5 yıldız',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final value = index + 1;
                return IconButton(
                  onPressed: () => setState(() => _rating = value),
                  tooltip: '$value yıldız',
                  iconSize: 34,
                  color: AppColors.socialOrange,
                  icon: Icon(
                    value <= _rating
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _commentController,
            maxLength: 500,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Yorum (isteğe bağlı)',
              hintText: 'Birlikte çalışma deneyimini paylaş...',
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: CollabOutlineAction(
              key: const ValueKey<String>('collab-review-submit'),
              onPressed: () {
                final comment = _commentController.text.trim();
                Navigator.of(context).pop(
                  CollabReviewInput(
                    rating: _rating,
                    comment: comment.isEmpty ? null : comment,
                  ),
                );
              },
              icon: Icons.star_rounded,
              label: 'Değerlendirmeyi gönder',
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
          Text(message ?? 'Veriler yüklenemedi.', textAlign: TextAlign.center),
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
