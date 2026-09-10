import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/policy/stage_mode.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/app_snack_bar.dart';
import '../../../../shared/widgets/ghost_profile_badge.dart';
import '../../../engagement/presentation/cubit/comment_thread_cubit.dart';
import '../../../engagement/presentation/widgets/comment_thread_view.dart';
import '../../../profile/presentation/screens/profile_public_bottom_bar.dart';
import '../../../spotify/domain/entities/spotify_track_preview.dart';
import '../../../spotify/domain/spotify_repository.dart';
import '../../domain/entities/overthinking_post.dart';
import '../../domain/overthinking_feed_sort.dart';
import '../../domain/trusted_spotify_artwork.dart';
import '../cubit/overthinking_feed_cubit.dart';
import '../cubit/overthinking_feed_state.dart';
import '../cubit/overthinking_incoming_unread_binding.dart';
import '../cubit/overthinking_incoming_unread_scope.dart';
import '../widgets/overthinking_incoming_request_icon.dart';
import 'overthinking_design.dart';
import 'overthinking_manage_screen.dart';
import 'overthinking_profile_link.dart';
import 'overthinking_profile_share_button.dart';
import 'overthinking_session_guard.dart';

part 'overthinking_feed_widgets.dart';
part 'overthinking_create_screen.dart';
part 'overthinking_detail_screen.dart';
part 'overthinking_music_widgets.dart';

class OverthinkingFeedArgs {
  final StageMode bottomBarStageMode;
  const OverthinkingFeedArgs({this.bottomBarStageMode = StageMode.mainstage});
}

class OverthinkingFeedScreen extends StatelessWidget {
  final StageMode bottomBarStageMode;
  const OverthinkingFeedScreen({
    super.key,
    this.bottomBarStageMode = StageMode.mainstage,
  });

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => serviceLocator<OverthinkingFeedCubit>()..load(),
    child: _OverthinkingFeedView(bottomBarStageMode: bottomBarStageMode),
  );
}

class _OverthinkingFeedView extends StatefulWidget {
  final StageMode bottomBarStageMode;
  const _OverthinkingFeedView({required this.bottomBarStageMode});
  @override
  State<_OverthinkingFeedView> createState() => _OverthinkingFeedViewState();
}

class _OverthinkingFeedViewState extends State<_OverthinkingFeedView>
    with OverthinkingSessionBoundState<_OverthinkingFeedView> {
  final ScrollController _scrollController = ScrollController();
  bool _openingDetail = false;
  String? _deletingPostId;
  late final OverthinkingIncomingUnreadScope _incomingUnread;

  @override
  void initState() {
    super.initState();
    _incomingUnread = requireOverthinkingIncomingUnreadScope();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!overthinkingSession.isCurrent) return;
    await Future.wait([
      context.read<OverthinkingFeedCubit>().load(),
      _incomingUnread.refresh(),
    ]);
  }

  Future<void> _changeSort(OverthinkingFeedSort sort) async {
    if (!overthinkingSession.isCurrent) return;
    final cubit = context.read<OverthinkingFeedCubit>();
    if (cubit.state.sort == sort) return;
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    await cubit.setSort(sort);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 260 &&
        context.read<OverthinkingFeedCubit>().state.status !=
            OverthinkingFeedStatus.failure) {
      context.read<OverthinkingFeedCubit>().loadMore();
    }
  }

  bool _isOwnPost(OverthinkingPost post) =>
      context.read<OverthinkingFeedCubit>().canWrite &&
      serviceLocator.isRegistered<AuthSessionManager>() &&
      post.authorId != null &&
      post.authorId == serviceLocator<AuthSessionManager>().session.userId;

  Future<void> _deletePost(OverthinkingPost post) async {
    if (!_isOwnPost(post) || _deletingPostId != null) return;
    final cubit = context.read<OverthinkingFeedCubit>();
    setState(() => _deletingPostId = post.id);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => OverthinkingSessionBoundary(
          session: overthinkingSession,
          child: AlertDialog(
            title: const Text('Bu yazıyı sil?'),
            content: Text(
              '“${post.title}” akıştan kaldırılacak. Bu işlemi geri alamazsın.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Yazıyı sil'),
              ),
            ],
          ),
        ),
      );
      if (confirmed != true || !mounted || !cubit.canWrite) return;
      final deleted = await cubit.deletePost(post.id);
      if (!mounted || !cubit.isSessionCurrent) return;
      if (deleted) {
        ScaffoldMessenger.of(context).showSnackBar(
          appSnackBar(
            context,
            tone: AppSnackBarTone.success,
            content: const Text('Yazın silindi.'),
          ),
        );
        await _incomingUnread.refresh();
      }
    } finally {
      if (mounted) setState(() => _deletingPostId = null);
    }
  }

  Future<void> _openCreate() async {
    final cubit = context.read<OverthinkingFeedCubit>();
    if (!cubit.canWrite) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: const OverthinkingCreateScreen(),
        ),
      ),
    );
  }

  Future<void> _openManage({int initialTabIndex = 0}) async {
    if (!context.read<OverthinkingFeedCubit>().canWrite) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => OverthinkingSessionBoundary(
          session: overthinkingSession,
          child: OverthinkingManageScreen(
            bottomBarStageMode: widget.bottomBarStageMode,
            initialTabIndex: initialTabIndex,
          ),
        ),
      ),
    );
    if (mounted) await _refresh();
  }

  Future<void> _openDetail(OverthinkingPost post) async {
    if (_openingDetail ||
        !context.read<OverthinkingFeedCubit>().isSessionCurrent) {
      return;
    }
    _openingDetail = true;
    final cubit = context.read<OverthinkingFeedCubit>();
    // Open immediately; refresh in the detail route without freezing the feed.
    unawaited(cubit.refreshPost(post.id));
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => MultiBlocProvider(
            providers: [
              BlocProvider.value(value: cubit),
              BlocProvider(
                create: (_) => serviceLocator<CommentThreadCubit>()
                  ..load(
                    targetType: OverthinkingFeedCubit.targetType,
                    targetId: post.id,
                  ),
              ),
            ],
            child: OverthinkingDetailScreen(
              post: post,
              revealRequesting: false,
            ),
          ),
        ),
      );
    } finally {
      _openingDetail = false;
    }
  }

  Future<void> _openComments(OverthinkingPost post) async {
    final cubit = context.read<OverthinkingFeedCubit>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: OverthinkingPalette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) => Theme(
        data: OverthinkingPalette.theme(context),
        child: BlocProvider(
          create: (_) => serviceLocator<CommentThreadCubit>(),
          child: CommentThreadSheet(
            targetType: OverthinkingFeedCubit.targetType,
            targetId: post.id,
            onCommentCreated: () => cubit.incrementCommentCount(post.id),
            onCommentDeleted: () => cubit.refreshPost(post.id),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: OverthinkingPalette.theme(context),
    child: Builder(
      builder: (context) => BlocConsumer<OverthinkingFeedCubit, OverthinkingFeedState>(
        listenWhen: (previous, current) =>
            current.error != null &&
            previous.error != current.error &&
            current.posts.isNotEmpty,
        listener: (context, state) =>
            ScaffoldMessenger.of(context).showSnackBar(
              appSnackBar(
                context,
                tone: AppSnackBarTone.error,
                content: Text(state.error!.message),
              ),
            ),
        builder: (context, state) =>
            !context.read<OverthinkingFeedCubit>().isSessionCurrent
            ? const OverthinkingUnavailableScreen()
            : Scaffold(
                body: TableGroupOverviewBackdrop(
                  child: SafeArea(
                    bottom: false,
                    child: RefreshIndicator(
                      color: OverthinkingPalette.accent,
                      onRefresh: _refresh,
                      child: CustomScrollView(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverToBoxAdapter(
                            child: _FeedHeading(onCreate: _openCreate),
                          ),
                          SliverToBoxAdapter(
                            child:
                                BlocBuilder<
                                  OverthinkingIncomingUnreadScope,
                                  bool?
                                >(
                                  bloc: _incomingUnread,
                                  builder: (context, hasUnread) =>
                                      _FeedShortcuts(
                                        hasUnread: hasUnread,
                                        onMine: () => _openManage(),
                                        onIncoming: () =>
                                            _openManage(initialTabIndex: 1),
                                        onSent: () =>
                                            _openManage(initialTabIndex: 2),
                                      ),
                                ),
                          ),
                          SliverToBoxAdapter(
                            child: _FeedSection(
                              sort: state.sort,
                              onSortChanged: _changeSort,
                            ),
                          ),
                          if (state.status == OverthinkingFeedStatus.loading &&
                              state.posts.isEmpty)
                            const SliverToBoxAdapter(child: _FeedLoadingState())
                          else if (state.posts.isEmpty)
                            SliverToBoxAdapter(
                              child: OverthinkingEmptyState(
                                icon:
                                    state.status ==
                                        OverthinkingFeedStatus.failure
                                    ? Icons.cloud_off_rounded
                                    : Icons.edit_note_rounded,
                                title:
                                    state.status ==
                                        OverthinkingFeedStatus.failure
                                    ? 'Akışa ulaşamadık'
                                    : 'İlk satır senden gelsin.',
                                message:
                                    state.status ==
                                        OverthinkingFeedStatus.failure
                                    ? state.error?.message ??
                                          'Bağlantını kontrol edip yeniden deneyebilirsin.'
                                    : 'Bazen bir şarkı, bazen tek bir cümle.\nAklından geçenlere burada yer var.',
                                action: FilledButton.icon(
                                  onPressed:
                                      state.status ==
                                          OverthinkingFeedStatus.failure
                                      ? () => context
                                            .read<OverthinkingFeedCubit>()
                                            .load()
                                      : _openCreate,
                                  icon: Icon(
                                    state.status ==
                                            OverthinkingFeedStatus.failure
                                        ? Icons.refresh_rounded
                                        : Icons.edit_outlined,
                                    size: 18,
                                  ),
                                  label: Text(
                                    state.status ==
                                            OverthinkingFeedStatus.failure
                                        ? 'Yeniden dene'
                                        : 'Bir şeyler yaz',
                                  ),
                                ),
                              ),
                            )
                          else
                            SliverPadding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                              ),
                              sliver: SliverList.builder(
                                itemCount: state.posts.length,
                                itemBuilder: (context, index) {
                                  final post = state.posts[index];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: OverthinkingPostCard(
                                      key: ValueKey(
                                        'overthinking-post-${post.id}',
                                      ),
                                      post: post,
                                      onTap: () => _openDetail(post),
                                      onLike: () => context
                                          .read<OverthinkingFeedCubit>()
                                          .toggleLike(post),
                                      onComments: () => _openComments(post),
                                      onDelete: _isOwnPost(post)
                                          ? () => _deletePost(post)
                                          : null,
                                      busy: _deletingPostId == post.id,
                                    ),
                                  );
                                },
                              ),
                            ),
                          if (state.posts.isNotEmpty)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  4,
                                  20,
                                  28,
                                ),
                                child: Center(
                                  child:
                                      state.status ==
                                              OverthinkingFeedStatus
                                                  .loadingMore ||
                                          state.status ==
                                              OverthinkingFeedStatus.loading
                                      ? const Padding(
                                          padding: EdgeInsets.all(12),
                                          child: SizedBox.square(
                                            dimension: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        )
                                      : state.hasNext
                                      ? TextButton.icon(
                                          onPressed: () => context
                                              .read<OverthinkingFeedCubit>()
                                              .loadMore(),
                                          icon: Icon(
                                            state.status ==
                                                    OverthinkingFeedStatus
                                                        .failure
                                                ? Icons.refresh_rounded
                                                : Icons.arrow_downward_rounded,
                                            size: 16,
                                          ),
                                          label: Text(
                                            state.status ==
                                                    OverthinkingFeedStatus
                                                        .failure
                                                ? 'Yüklenemedi · Yeniden dene'
                                                : 'Daha fazla yazı',
                                          ),
                                        )
                                      : const Text(
                                          'Şimdilik bütün satırlar bu kadar.',
                                          style: TextStyle(
                                            color: OverthinkingPalette.muted,
                                            fontSize: 12,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          const SliverToBoxAdapter(child: SizedBox(height: 24)),
                        ],
                      ),
                    ),
                  ),
                ),
                bottomNavigationBar: ProfilePublicBottomBar(
                  mainstageCurrentIndex: 1,
                  currentIndex: widget.bottomBarStageMode == StageMode.mainstage
                      ? 1
                      : 2,
                  stageMode: widget.bottomBarStageMode,
                ),
              ),
      ),
    ),
  );
}
