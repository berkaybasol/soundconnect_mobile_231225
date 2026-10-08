import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/network/api_client.dart';
import '../../../../shared/widgets/app_snack_bar.dart';
import '../../../../shared/widgets/brand_gradient_icon.dart';
import '../../../analytics/presentation/widgets/analytics_exposure.dart';
import '../../../analytics/data/analytics_tracker.dart';
import '../../../engagement/data/engagement_repository_impl.dart';
import '../../../engagement/presentation/cubit/comment_thread_cubit.dart';
import '../../../engagement/presentation/widgets/comment_thread_view.dart';
import '../../../engagement/domain/engagement_repository.dart';
import '../../../engagement/presentation/widgets/like_users_sheet.dart';
import '../../domain/musician_feed_like_users_target.dart';
import '../../domain/musician_feed_models.dart';
import '../../domain/backstage_feed_session.dart';
import '../musician_feed_visual_theme.dart';
import '../cubit/musician_feed_cubit.dart';
import '../cubit/musician_feed_state.dart';
import '../navigation/musician_feed_navigation_coordinator.dart';
import '../widgets/musician_feed_card_registry.dart';

export '../navigation/musician_feed_navigation_coordinator.dart'
    show
        musicianFeedOverthinkingSourceId,
        parseMusicianFeedExternalPromotionUri;

typedef MusicianFeedActionsBuilder =
    MusicianFeedCardActions Function(
      BuildContext context,
      MusicianFeedCubit cubit,
      MusicianFeedCardRegistry registry,
    );

class MusicianFeedView extends StatefulWidget {
  const MusicianFeedView({super.key, this.registry, this.actionsBuilder});

  final MusicianFeedCardRegistry? registry;
  final MusicianFeedActionsBuilder? actionsBuilder;

  @override
  State<MusicianFeedView> createState() => _MusicianFeedViewState();
}

class _MusicianFeedViewState extends State<MusicianFeedView> {
  final _scrollController = ScrollController();
  bool _likesSheetOpen = false;
  late final MusicianFeedCardRegistry _registry =
      widget.registry ?? MusicianFeedCardRegistry.standard();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 560) {
      unawaited(context.read<MusicianFeedCubit>().loadMore());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MusicianFeedThemeScope(
      child: BlocConsumer<MusicianFeedCubit, MusicianFeedState>(
        listenWhen: (previous, current) =>
            previous.noticeSerial != current.noticeSerial,
        listener: (context, state) {
          final error = state.actionError ?? state.loadMoreError;
          if (error == null) return;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              appSnackBar(
                context,
                tone: AppSnackBarTone.error,
                content: Text(error.message),
              ),
            );
        },
        builder: (context, state) {
          if (state.isInitialLoading) return const _FeedLoadingView();
          if (state.status == MusicianFeedStatus.failure && !state.hasContent) {
            return _FeedFailureView(
              message: state.error?.message ?? 'Akış yüklenemedi.',
              onRetry: context.read<MusicianFeedCubit>().retry,
            );
          }
          final actions =
              widget.actionsBuilder?.call(
                context,
                context.read<MusicianFeedCubit>(),
                _registry,
              ) ??
              _actions(context);
          return RefreshIndicator(
            onRefresh: context.read<MusicianFeedCubit>().refresh,
            child: ListView.separated(
              key: const PageStorageKey('musician-feed-list'),
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(0, 4, 0, 118),
              itemCount: _itemCount(state),
              separatorBuilder: (context, _) => Divider(
                height: 26,
                thickness: 1,
                indent: 16,
                endIndent: 16,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              itemBuilder: (context, index) {
                if (state.items.isEmpty && index == 0) {
                  final listener =
                      context.read<MusicianFeedCubit>().audience ==
                      BackstageFeedAudience.listener;
                  return state.status == MusicianFeedStatus.featureUnavailable
                      ? _FeedFeatureUnavailableView(listener: listener)
                      : _FeedEmptyView(listener: listener);
                }
                if (index >= state.items.length) {
                  return _FeedPagingFooter(
                    loading: state.status == MusicianFeedStatus.loadingMore,
                    error: state.loadMoreError?.message,
                    onRetry: context.read<MusicianFeedCubit>().loadMore,
                  );
                }
                final item = state.items[index];
                final pending = state.pendingItemIds.contains(item.id);
                return AnalyticsExposure(
                  key: ValueKey(
                    'musician-feed-exposure-${state.feedSessionId}-'
                    '${item.position}-${item.id}',
                  ),
                  onExposed: () {
                    unawaited(
                      context.read<MusicianFeedCubit>().recordEvent(
                        item,
                        MusicianFeedTelemetryEventType.impression,
                      ),
                    );
                    final payload = item.payload;
                    if (payload is AnnouncementFeedPayload &&
                        serviceLocator.isRegistered<AnalyticsTracker>()) {
                      serviceLocator<AnalyticsTracker>()
                          .recordAnnouncementImpression(
                            announcementId: payload.announcement.id,
                            source: 'FEED',
                            impressionToken: item.impressionToken,
                          );
                    }
                  },
                  child: IgnorePointer(
                    ignoring: pending,
                    child: AnimatedOpacity(
                      opacity: pending ? .58 : 1,
                      duration: const Duration(milliseconds: 160),
                      child: _registry.build(context, item, actions),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  int _itemCount(MusicianFeedState state) {
    if (state.items.isEmpty) {
      return 1 + ((state.hasMore || state.loadMoreError != null) ? 1 : 0);
    }
    return state.items.length +
        ((state.hasMore || state.loadMoreError != null) ? 1 : 0);
  }

  MusicianFeedCardActions _actions(BuildContext feedContext) {
    final cubit = feedContext.read<MusicianFeedCubit>();
    final navigation = MusicianFeedNavigationCoordinator(
      context: feedContext,
      cubit: cubit,
    );
    return MusicianFeedCardActions(
      openItem: (item) => unawaited(_registry.open(navigation, item)),
      openAuthor: (item, author) =>
          unawaited(navigation.openAuthor(item, author)),
      toggleLike: (item) => unawaited(cubit.toggleLike(item.id)),
      openComments: (item) => unawaited(_openComments(feedContext, item)),
      openLikes: (item) => unawaited(_openLikes(feedContext, item)),
      feedback: (item, action) =>
          unawaited(_sendFeedback(feedContext, item, action)),
      muteAuthor: (item, author) =>
          unawaited(_muteAuthor(feedContext, item, author)),
      openCompletionTask: (task) =>
          unawaited(_registry.openCompletionTask(navigation, task)),
      openPromotion: (item) =>
          unawaited(_registry.openPromotion(navigation, item)),
      toggleCollabSaved: (item, saved) =>
          unawaited(cubit.toggleCollabSaved(item.id, saved)),
      followProfile: (item) => unawaited(cubit.followProfile(item.id)),
    );
  }

  Future<void> _openLikes(
    BuildContext feedContext,
    MusicianFeedItem item,
  ) async {
    final target = musicianFeedLikeUsersTarget(item);
    if (_likesSheetOpen || target == null || !feedContext.mounted) return;
    final cubit = feedContext.read<MusicianFeedCubit>();
    final fence = cubit.captureSessionFence();
    bool isCurrent() =>
        mounted &&
        feedContext.mounted &&
        cubit.acceptsSessionFence(fence) &&
        identical(feedContext.read<MusicianFeedCubit>(), cubit);
    if (!isCurrent()) return;
    _likesSheetOpen = true;
    try {
      await showModalBottomSheet<void>(
        context: feedContext,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        backgroundColor: Theme.of(feedContext).colorScheme.surfaceContainerHigh,
        builder: (_) => MusicianFeedThemeScope(
          child: FractionallySizedBox(
            heightFactor: .75,
            child: LikeUsersSheet(
              targetType: target.targetType,
              targetId: target.targetId,
              repository: serviceLocator<EngagementRepository>(),
              sessions: serviceLocator<AuthSessionManager>(),
              isCurrent: isCurrent,
            ),
          ),
        ),
      );
    } finally {
      _likesSheetOpen = false;
    }
  }

  Future<void> _openComments(
    BuildContext feedContext,
    MusicianFeedItem item,
  ) async {
    final engagement = item.engagement;
    if (engagement == null || !engagement.commentable) return;
    final cubit = feedContext.read<MusicianFeedCubit>();
    unawaited(cubit.recordEvent(item, MusicianFeedTelemetryEventType.open));
    await showModalBottomSheet<void>(
      context: feedContext,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(feedContext).colorScheme.surfaceContainerHigh,
      builder: (_) => BlocProvider(
        create: (_) => engagement.targetType == 'ANNOUNCEMENT'
            ? CommentThreadCubit(
                EngagementRepositoryImpl(
                  serviceLocator<ApiClient>(),
                  sessions: serviceLocator<AuthSessionManager>(),
                  announcementSource: 'FEED',
                ),
                sessions: serviceLocator<AuthSessionManager>(),
              )
            : serviceLocator<CommentThreadCubit>(),
        child: CommentThreadSheet(
          targetType: engagement.targetType,
          targetId: engagement.targetId,
          onCommentCreated: () => cubit.adjustCommentCount(item.id, 1),
          onCommentDeleted: () => cubit.adjustCommentCount(item.id, -1),
        ),
      ),
    );
  }

  Future<void> _sendFeedback(
    BuildContext feedContext,
    MusicianFeedItem item,
    MusicianFeedFeedbackAction action,
  ) async {
    String? reason;
    if (action == MusicianFeedFeedbackAction.report) {
      reason = await _selectReportReason(feedContext);
      if (reason == null || !mounted || !feedContext.mounted) return;
    }
    final success = await feedContext.read<MusicianFeedCubit>().dismiss(
      item.id,
      action,
      reason: reason,
    );
    if (!mounted || !feedContext.mounted || !success) return;
    if (action == MusicianFeedFeedbackAction.report) {
      _showInfo(feedContext, 'Bildirimin alındı. Teşekkür ederiz.');
    } else if (action == MusicianFeedFeedbackAction.hide &&
        item.type == MusicianFeedItemType.announcement) {
      _showInfo(
        feedContext,
        'Bu duyuru akışında tekrar gösterilmeyecek. Tüm duyurular bölümünden açabilirsin.',
      );
    }
  }

  Future<String?> _selectReportReason(BuildContext feedContext) =>
      showModalBottomSheet<String>(
        context: feedContext,
        useSafeArea: true,
        showDragHandle: true,
        backgroundColor: Theme.of(feedContext).colorScheme.surfaceContainerHigh,
        builder: (sheetContext) => SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(12, 4, 12, 8),
                  child: Text(
                    'Neden bildiriyorsun?',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ),
                for (final reason in const [
                  ('SPAM', 'Spam veya yanıltıcı'),
                  ('INAPPROPRIATE', 'Uygunsuz içerik'),
                  ('HARASSMENT', 'Taciz veya zorbalık'),
                  ('OTHER', 'Diğer'),
                ])
                  ListTile(
                    minTileHeight: 48,
                    title: Text(reason.$2),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.pop(sheetContext, reason.$1),
                  ),
              ],
            ),
          ),
        ),
      );

  Future<void> _muteAuthor(
    BuildContext feedContext,
    MusicianFeedItem item,
    MusicianFeedActor author,
  ) async {
    final identity = musicianFeedAuthorProfileIdentity(author);
    if (identity == null) return;
    final cubit = feedContext.read<MusicianFeedCubit>();
    final fence = cubit.captureSessionFence();
    if (!cubit.acceptsSessionFence(fence)) return;
    final confirmed = await showDialog<bool>(
      context: feedContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Paylaşımları sessize al'),
        content: Text(
          '${author.visibleName} tarafından paylaşılan içerikler akışında gösterilmeyecek.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sessize al'),
          ),
        ],
      ),
    );
    if (confirmed != true ||
        !mounted ||
        !feedContext.mounted ||
        !cubit.acceptsSessionFence(fence) ||
        !identical(feedContext.read<MusicianFeedCubit>(), cubit)) {
      return;
    }
    final success = await cubit.muteAuthor(
      sourceItemId: item.id,
      profileType: identity.profileType,
      profileId: identity.profileId,
    );
    if (!mounted ||
        !feedContext.mounted ||
        !success ||
        !cubit.acceptsSessionFence(fence) ||
        !identical(feedContext.read<MusicianFeedCubit>(), cubit)) {
      return;
    }
    ScaffoldMessenger.of(feedContext)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        appSnackBar(
          feedContext,
          tone: AppSnackBarTone.info,
          content: Text('${author.visibleName} sessize alındı.'),
          action: SnackBarAction(
            label: 'Geri al',
            onPressed: () {
              if (!mounted ||
                  !feedContext.mounted ||
                  !cubit.acceptsSessionFence(fence) ||
                  !identical(feedContext.read<MusicianFeedCubit>(), cubit)) {
                return;
              }
              unawaited(
                cubit.unmuteAuthor(
                  profileType: identity.profileType,
                  profileId: identity.profileId,
                ),
              );
            },
          ),
        ),
      );
  }

  void _showInfo(BuildContext feedContext, String message) {
    if (!mounted || !feedContext.mounted) return;
    ScaffoldMessenger.of(feedContext)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        appSnackBar(
          feedContext,
          tone: AppSnackBarTone.info,
          content: Text(message),
        ),
      );
  }
}

class _FeedLoadingView extends StatelessWidget {
  const _FeedLoadingView();

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: true,
    label: 'Akış yükleniyor',
    child: ExcludeSemantics(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 118),
        itemCount: 3,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, index) => _FeedSkeleton(tall: index == 1),
      ),
    ),
  );
}

class _FeedSkeleton extends StatelessWidget {
  const _FeedSkeleton({required this.tall});
  final bool tall;

  @override
  Widget build(BuildContext context) => Container(
    height: tall ? 310 : 220,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Theme.of(context).colorScheme.outline),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _block(context, width: 44, height: 44, radius: 22),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _block(context, width: 150, height: 12),
                  const SizedBox(height: 8),
                  _block(context, width: 92, height: 9),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _block(
          context,
          width: double.infinity,
          height: tall ? 168 : 78,
          radius: 15,
        ),
        const SizedBox(height: 12),
        _block(context, width: 180, height: 11),
      ],
    ),
  );

  Widget _block(
    BuildContext context, {
    required double width,
    required double height,
    double radius = 7,
  }) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

class _FeedFailureView extends StatelessWidget {
  const _FeedFailureView({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const BrandGradientIcon.social(Icons.wifi_off_rounded, size: 42),
          const SizedBox(height: 15),
          const Text(
            'Akışına ulaşamadık',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Tekrar dene'),
          ),
        ],
      ),
    ),
  );
}

class _FeedEmptyView extends StatelessWidget {
  const _FeedEmptyView({this.listener = false});
  final bool listener;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(
      minHeight: MediaQuery.sizeOf(context).height * .56,
    ),
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandGradientIcon.social(
              Icons.auto_awesome_rounded,
              size: 43,
            ),
            const SizedBox(height: 14),
            Text(
              listener ? 'Akışın henüz sessiz' : 'Backstage sessiz görünüyor',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 7),
            Text(
              listener
                  ? 'Yeni müzikler, etkinlikler ve takip ettiğin kişilerin paylaşımları burada buluşacak.'
                  : 'Yeni paylaşımlar ve sana uygun fırsatlar geldikçe burada göreceksin.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _FeedFeatureUnavailableView extends StatelessWidget {
  const _FeedFeatureUnavailableView({this.listener = false});
  final bool listener;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    key: const Key('musician-feed-feature-unavailable'),
    constraints: BoxConstraints(
      minHeight: MediaQuery.sizeOf(context).height * .56,
    ),
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandGradientIcon.social(
              Icons.auto_awesome_rounded,
              size: 43,
            ),
            const SizedBox(height: 14),
            Text(
              listener
                  ? 'Akışın hazırlanıyor'
                  : 'Backstage akışın hazırlanıyor',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 7),
            Text(
              listener
                  ? 'Bu sırada Keşfet ile etkinliklere göz atabilirsin.'
                  : 'Akış açılana kadar Backstage araçlarını kullanmaya devam edebilirsin.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _FeedPagingFooter extends StatelessWidget {
  const _FeedPagingFooter({
    required this.loading,
    required this.error,
    required this.onRetry,
  });
  final bool loading;
  final String? error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (error != null) {
      return Center(
        child: TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Devamını tekrar yükle'),
        ),
      );
    }
    return Center(
      child: TextButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.expand_more_rounded),
        label: const Text('Daha fazla göster'),
      ),
    );
  }
}
