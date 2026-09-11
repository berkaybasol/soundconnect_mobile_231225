import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/app_snack_bar.dart';
import '../../../../shared/widgets/brand_gradient_icon.dart';
import '../../../analytics/presentation/widgets/analytics_exposure.dart';
import '../../../engagement/presentation/cubit/comment_thread_cubit.dart';
import '../../../engagement/presentation/widgets/comment_thread_view.dart';
import '../../domain/musician_feed_models.dart';
import '../cubit/musician_feed_cubit.dart';
import '../cubit/musician_feed_state.dart';
import '../navigation/musician_feed_navigation_coordinator.dart';
import '../widgets/musician_feed_card_registry.dart';

export '../navigation/musician_feed_navigation_coordinator.dart'
    show
        musicianFeedOverthinkingSourceId,
        parseMusicianFeedExternalPromotionUri;

class MusicianFeedView extends StatefulWidget {
  const MusicianFeedView({super.key, this.registry});

  final MusicianFeedCardRegistry? registry;

  @override
  State<MusicianFeedView> createState() => _MusicianFeedViewState();
}

class _MusicianFeedViewState extends State<MusicianFeedView> {
  final _scrollController = ScrollController();
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
    return ColoredBox(
      color: AppColors.navBlueDeep,
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
          return RefreshIndicator(
            onRefresh: context.read<MusicianFeedCubit>().refresh,
            child: ListView.separated(
              key: const PageStorageKey('musician-feed-list'),
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 118),
              itemCount: _itemCount(state),
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (state.items.isEmpty && index == 0) {
                  return state.status == MusicianFeedStatus.featureUnavailable
                      ? const _FeedFeatureUnavailableView()
                      : const _FeedEmptyView();
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
                  onExposed: () => unawaited(
                    context.read<MusicianFeedCubit>().recordEvent(
                      item,
                      MusicianFeedTelemetryEventType.impression,
                    ),
                  ),
                  child: IgnorePointer(
                    ignoring: pending,
                    child: AnimatedOpacity(
                      opacity: pending ? .58 : 1,
                      duration: const Duration(milliseconds: 160),
                      child: _registry.build(context, item, _actions()),
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

  MusicianFeedCardActions _actions() {
    final cubit = context.read<MusicianFeedCubit>();
    final navigation = MusicianFeedNavigationCoordinator(
      context: context,
      cubit: cubit,
    );
    return MusicianFeedCardActions(
      openItem: (item) => unawaited(_registry.open(navigation, item)),
      openAuthor: (item, author) =>
          unawaited(navigation.openAuthor(item, author)),
      toggleLike: (item) => unawaited(cubit.toggleLike(item.id)),
      openComments: (item) => unawaited(_openComments(item)),
      feedback: (item, action) => unawaited(_sendFeedback(item, action)),
      muteAuthor: (item, author) => unawaited(_muteAuthor(item, author)),
      openCompletionTask: (task) =>
          unawaited(_registry.openCompletionTask(navigation, task)),
      openPromotion: (item) =>
          unawaited(_registry.openPromotion(navigation, item)),
      toggleCollabSaved: (item, saved) =>
          unawaited(cubit.toggleCollabSaved(item.id, saved)),
      followProfile: (item) => unawaited(cubit.followProfile(item.id)),
    );
  }

  Future<void> _openComments(MusicianFeedItem item) async {
    final engagement = item.engagement;
    if (engagement == null || !engagement.commentable) return;
    final cubit = context.read<MusicianFeedCubit>();
    unawaited(cubit.recordEvent(item, MusicianFeedTelemetryEventType.open));
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppColors.navBlueDeep,
      builder: (_) => BlocProvider(
        create: (_) => serviceLocator<CommentThreadCubit>(),
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
    MusicianFeedItem item,
    MusicianFeedFeedbackAction action,
  ) async {
    String? reason;
    if (action == MusicianFeedFeedbackAction.report) {
      reason = await _selectReportReason();
      if (reason == null || !mounted) return;
    }
    final success = await context.read<MusicianFeedCubit>().dismiss(
      item.id,
      action,
      reason: reason,
    );
    if (!mounted || !success) return;
    if (action == MusicianFeedFeedbackAction.report) {
      _showInfo('Bildirimin alındı. Teşekkür ederiz.');
    }
  }

  Future<String?> _selectReportReason() => showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: AppColors.navBlue,
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
    MusicianFeedItem item,
    MusicianFeedActor author,
  ) async {
    final identity = musicianFeedAuthorProfileIdentity(author);
    if (identity == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Paylaşımları sessize al'),
        content: Text(
          '${author.displayName} tarafından paylaşılan içerikler akışında gösterilmeyecek.',
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
    if (confirmed != true || !mounted) return;
    final cubit = context.read<MusicianFeedCubit>();
    final success = await cubit.muteAuthor(
      sourceItemId: item.id,
      profileType: identity.profileType,
      profileId: identity.profileId,
    );
    if (!mounted || !success) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        appSnackBar(
          context,
          tone: AppSnackBarTone.info,
          content: Text('${author.displayName} sessize alındı.'),
          action: SnackBarAction(
            label: 'Geri al',
            onPressed: () => unawaited(
              cubit.unmuteAuthor(
                profileType: identity.profileType,
                profileId: identity.profileId,
              ),
            ),
          ),
        ),
      );
  }

  void _showInfo(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        appSnackBar(
          context,
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
      color: AppColors.navBlue,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _block(width: 44, height: 44, radius: 22),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _block(width: 150, height: 12),
                  const SizedBox(height: 8),
                  _block(width: 92, height: 9),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _block(width: double.infinity, height: tall ? 168 : 78, radius: 15),
        const SizedBox(height: 12),
        _block(width: 180, height: 11),
      ],
    ),
  );

  Widget _block({
    required double width,
    required double height,
    double radius = 7,
  }) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: AppColors.navBlueSoft,
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
            style: TextStyle(color: AppColors.textMuted, height: 1.4),
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
  const _FeedEmptyView();

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
            const Text(
              'Backstage sessiz görünüyor',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 7),
            Text(
              'Yeni paylaşımlar ve sana uygun fırsatlar geldikçe burada göreceksin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, height: 1.4),
            ),
          ],
        ),
      ),
    ),
  );
}

class _FeedFeatureUnavailableView extends StatelessWidget {
  const _FeedFeatureUnavailableView();

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
            const Text(
              'Backstage akışın hazırlanıyor',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 7),
            Text(
              'Akış açılana kadar Backstage araçlarını kullanmaya devam edebilirsin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, height: 1.4),
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
