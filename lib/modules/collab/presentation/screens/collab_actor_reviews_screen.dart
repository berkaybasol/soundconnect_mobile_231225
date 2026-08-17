import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../profile/presentation/screens/profile_public_bottom_bar.dart';
import '../../domain/entities/collab_actor.dart';
import '../../domain/entities/collab_review.dart';
import '../collab_deep_link_scroll.dart';
import '../collab_navigation.dart';
import '../cubit/collab_actor_reviews_cubit.dart';
import '../cubit/collab_async_state.dart';
import '../cubit/collab_paged_cubit.dart';
import '../widgets/collab_discovery_widgets.dart';
import '../widgets/collab_management_widgets.dart';

class CollabActorReviewsScreen extends StatefulWidget {
  const CollabActorReviewsScreen({
    required this.actor,
    this.initialReviewId,
    this.showBottomNavigation = true,
    this.cubit,
    super.key,
  });

  final CollabActor actor;
  final String? initialReviewId;
  final bool showBottomNavigation;
  final CollabActorReviewsCubit? cubit;

  @override
  State<CollabActorReviewsScreen> createState() =>
      _CollabActorReviewsScreenState();
}

class _CollabActorReviewsScreenState extends State<CollabActorReviewsScreen> {
  late final CollabActorReviewsCubit _cubit;
  late final bool _ownsCubit;
  late final ScrollController _scrollController;
  final GlobalKey _initialReviewKey = GlobalKey();
  bool _initialTargetHandled = false;
  bool _initialTargetScheduled = false;
  bool _initialTargetRevealDeferred = false;

  @override
  void initState() {
    super.initState();
    _ownsCubit = widget.cubit == null;
    _cubit = widget.cubit ?? serviceLocator<CollabActorReviewsCubit>();
    _scrollController = ScrollController()..addListener(_onScroll);
    unawaited(_cubit.loadForActor(widget.actor.actorId));
  }

  @override
  void didUpdateWidget(covariant CollabActorReviewsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.actor.actorId != widget.actor.actorId) {
      unawaited(_cubit.loadForActor(widget.actor.actorId));
    }
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
    if (_initialTargetRevealDeferred &&
        _initialReviewKey.currentContext != null) {
      _initialTargetRevealDeferred = false;
      _scheduleInitialTarget(_cubit.state);
    }
    if (_scrollController.position.extentAfter < 320 &&
        _cubit.state.loadMoreError == null) {
      unawaited(_cubit.loadMore());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CollabActorReviewsCubit>.value(
      value: _cubit,
      child:
          BlocConsumer<CollabActorReviewsCubit, CollabPagedState<CollabReview>>(
            listenWhen: (previous, current) =>
                (previous.loadMoreError != current.loadMoreError &&
                    current.loadMoreError != null) ||
                (previous.error != current.error &&
                    current.error != null &&
                    current.items.isNotEmpty),
            listener: (_, state) =>
                _showMessage((state.loadMoreError ?? state.error)!.message),
            builder: (context, state) {
              _scheduleInitialTarget(state);
              return Scaffold(
                appBar: AppBar(title: const Text('Collab Değerlendirmeleri')),
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
                            padding: const EdgeInsets.fromLTRB(14, 5, 14, 17),
                            child: _ActorReviewSummary(
                              actor: widget.actor,
                              totalElements: state.totalElements,
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

  List<Widget> _contentSlivers(CollabPagedState<CollabReview> state) {
    if (state.status == CollabLoadStatus.loading && state.items.isEmpty) {
      return const <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (state.status == CollabLoadStatus.failure && state.items.isEmpty) {
      return <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: _ReviewsError(
            message: state.error?.message,
            onRetry: () => unawaited(_cubit.loadForActor(widget.actor.actorId)),
          ),
        ),
      ];
    }
    if (state.items.isEmpty) {
      return const <Widget>[
        SliverFillRemaining(hasScrollBody: false, child: _NoReviews()),
      ];
    }
    return <Widget>[
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        sliver: SliverList.separated(
          itemCount: state.items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 11),
          itemBuilder: (context, index) {
            final review = state.items[index];
            return KeyedSubtree(
              key: review.id == widget.initialReviewId?.trim()
                  ? _initialReviewKey
                  : ValueKey<String>('collab-review-${review.id}'),
              child: _ReviewCard(
                review: review,
                onReviewerTap: () =>
                    openCollabActorProfile(context, review.reviewer),
              ),
            );
          },
        ),
      ),
      SliverToBoxAdapter(
        child: CollabPagedFooter(
          key: const ValueKey<String>('collab-actor-reviews-load-more-footer'),
          loading: state.isLoadingMore,
          hasError: state.loadMoreError != null,
          onRetry: _cubit.loadMore,
        ),
      ),
    ];
  }

  void _scheduleInitialTarget(CollabPagedState<CollabReview> state) {
    final targetId = widget.initialReviewId?.trim() ?? '';
    if (_initialTargetHandled ||
        _initialTargetScheduled ||
        targetId.isEmpty ||
        state.status == CollabLoadStatus.initial ||
        state.status == CollabLoadStatus.loading ||
        state.status == CollabLoadStatus.failure) {
      return;
    }
    final targetIndex = state.items.indexWhere(
      (review) => review.id == targetId,
    );
    if (targetIndex >= 0) {
      if (_initialTargetRevealDeferred &&
          _initialReviewKey.currentContext == null) {
        return;
      }
      _initialTargetScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final revealed = await revealCollabPagedTarget(
          controller: _scrollController,
          targetKey: _initialReviewKey,
          targetIndex: targetIndex,
          itemCount: state.items.length,
          estimatedItemExtent: 190,
        );
        if (!mounted) return;
        _initialTargetScheduled = false;
        _initialTargetHandled = revealed;
        _initialTargetRevealDeferred = !revealed;
        if (!revealed) {
          _showMessage(
            'Hedef değerlendirme yüklendi ancak otomatik kaydırılamadı. '
            'Listede elle kaydırarak açabilirsin.',
          );
        }
      });
      return;
    }
    if (state.loadMoreError != null) return;
    if (state.hasNext && !state.isLoadingMore) {
      _initialTargetScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await _cubit.loadMore();
        _initialTargetScheduled = false;
        if (mounted) _scheduleInitialTarget(_cubit.state);
      });
      return;
    }
    if (!state.isLoadingMore) {
      _initialTargetHandled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showMessage('Bildirimdeki değerlendirme artık bulunamıyor.');
        }
      });
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ActorReviewSummary extends StatelessWidget {
  const _ActorReviewSummary({required this.actor, required this.totalElements});

  final CollabActor actor;
  final int totalElements;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CollabGradientFrame(
      highlighted: true,
      radius: 20,
      strokeWidth: 1.2,
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          CollabIdentityAvatar(
            initials: actor.initials,
            profileKind: actor.profileType,
            avatarUrl: actor.avatarUrl,
            size: 62,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  actor.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Icon(
                      Icons.star_rounded,
                      color: AppColors.socialOrange,
                      size: 22,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      actor.reviewCount == 0
                          ? 'Yeni'
                          : actor.rating.toStringAsFixed(1),
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$totalElements değerlendirme',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              Text(
                '${actor.completedJobCount}',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'tamamlanan iş',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 9.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review, required this.onReviewerTap});

  final CollabReview review;
  final VoidCallback onReviewerTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final comment = review.comment?.trim();
    return CollabGradientFrame(
      radius: 18,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CollabActorHeader(actor: review.reviewer, onTap: onReviewerTap),
          const SizedBox(height: 12),
          Row(
            children: [
              _RatingStars(rating: review.rating),
              const Spacer(),
              Text(
                collabShortDate(review.createdAt),
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            comment == null || comment.isEmpty
                ? 'Yalnızca puan verildi.'
                : comment,
            style: TextStyle(
              color: comment == null || comment.isEmpty
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.onSurface,
              fontSize: 12.5,
              height: 1.45,
              fontStyle: comment == null || comment.isEmpty
                  ? FontStyle.italic
                  : FontStyle.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingStars extends StatelessWidget {
  const _RatingStars({required this.rating});

  final int rating;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '5 üzerinden $rating yıldız',
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(
        5,
        (index) => Icon(
          index < rating ? Icons.star_rounded : Icons.star_border_rounded,
          size: 18,
          color: AppColors.socialOrange,
        ),
      ),
    ),
  );
}

class _NoReviews extends StatelessWidget {
  const _NoReviews();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star_outline_rounded,
            size: 42,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          const Text(
            'Henüz Collab değerlendirmesi yok.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class _ReviewsError extends StatelessWidget {
  const _ReviewsError({required this.message, required this.onRetry});

  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message ?? 'Değerlendirmeler yüklenemedi.',
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
