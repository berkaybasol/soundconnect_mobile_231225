import 'dart:async';

import 'package:flutter/material.dart' hide Page;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/error/result.dart';
import '../../../../core/pagination/page.dart';
import '../../../../core/policy/stage_mode.dart';
import '../../../../shared/widgets/app_snack_bar.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/ghost_profile_badge.dart';
import '../../../engagement/domain/engagement_repository.dart';
import '../../../engagement/presentation/cubit/comment_thread_cubit.dart';
import '../../../engagement/presentation/widgets/comment_thread_view.dart';
import '../../../profile/presentation/screens/profile_public_bottom_bar.dart';
import '../../domain/entities/overthinking_post.dart';
import '../../domain/entities/overthinking_reveal_request.dart';
import '../../domain/overthinking_repository.dart';
import '../../domain/trusted_spotify_artwork.dart';
import '../cubit/overthinking_incoming_unread_binding.dart';
import '../cubit/overthinking_incoming_unread_scope.dart';
import 'overthinking_design.dart';
import 'overthinking_feed_screen.dart';
import 'overthinking_profile_link.dart';
import 'overthinking_session_guard.dart';

part 'overthinking_manage_cards.dart';
part 'overthinking_manage_sheets.dart';

class OverthinkingManageScreen extends StatefulWidget {
  final StageMode bottomBarStageMode;
  final int initialTabIndex;

  const OverthinkingManageScreen({
    super.key,
    this.bottomBarStageMode = StageMode.mainstage,
    this.initialTabIndex = 0,
  });

  @override
  State<OverthinkingManageScreen> createState() =>
      _OverthinkingManageScreenState();
}

class _OverthinkingManageScreenState extends State<OverthinkingManageScreen>
    with
        SingleTickerProviderStateMixin,
        OverthinkingSessionBoundState<OverthinkingManageScreen>,
        WidgetsBindingObserver {
  late final OverthinkingRepository _repository =
      serviceLocator<OverthinkingRepository>();
  final _posts = _ManagePage<OverthinkingPost>((post) => post.id);
  final _incoming = _ManagePage<OverthinkingRevealRequest>(
    (request) => request.id,
  );
  final _sent = _ManagePage<OverthinkingRevealRequest>((request) => request.id);
  final Set<String> _busyPosts = {};
  final Set<String> _busyRequests = {};
  late final OverthinkingIncomingUnreadScope _incomingUnread;
  late final TabController _tabs;
  late int _lastSelectedTab;

  @override
  void initState() {
    super.initState();
    _incomingUnread = requireOverthinkingIncomingUnreadScope();
    _tabs = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 2),
    );
    _lastSelectedTab = _tabs.index;
    _tabs.addListener(_tabChanged);
    if (_tabs.index == 1) _markIncomingSeen();
    WidgetsBinding.instance.addObserver(this);
    _loadPosts();
    _loadIncoming();
    _loadSent();
  }

  @override
  void dispose() {
    _tabs.removeListener(_tabChanged);
    _tabs.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _tabChanged() {
    if (_tabs.index == _lastSelectedTab) return;
    _lastSelectedTab = _tabs.index;
    if (_tabs.index == 1) _markIncomingSeen();
  }

  void _markIncomingSeen() {
    if (!overthinkingSession.canWrite) return;
    unawaited(_incomingUnread.markSeen());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_loadIncoming());
  }

  @override
  void onOverthinkingSessionEnded() {
    _posts.invalidateRead();
    _incoming.invalidateRead();
    _sent.invalidateRead();
    _posts.items = [];
    _incoming.items = [];
    _sent.items = [];
    _busyPosts.clear();
    _busyRequests.clear();
  }

  Future<void> _loadPage<T>(
    _ManagePage<T> target,
    Future<Result<Page<T>>> Function(int page) fetch,
    String failureMessage, {
    bool append = false,
  }) async {
    if (!overthinkingSession.canWrite ||
        target.loading ||
        (append && !target.hasNext)) {
      return;
    }
    final page = append ? target.page + 1 : 0;
    final revision = ++target.revision;
    setState(() {
      target.loading = true;
      target.error = null;
    });
    try {
      final result = await fetch(page);
      if (!overthinkingSession.canWrite ||
          !mounted ||
          revision != target.revision) {
        return;
      }
      setState(() {
        target.loading = false;
        if (result.isSuccess && result.data != null) {
          final data = result.data!;
          target.items = <String, T>{
            if (append)
              for (final item in target.items) target.idOf(item): item,
            for (final item in data.items) target.idOf(item): item,
          }.values.toList();
          target.page = page;
          target.hasNext = data.hasNext;
          target.total = data.totalElements;
        } else {
          target.error = result.error?.message ?? failureMessage;
        }
      });
    } catch (_) {
      if (!overthinkingSession.canWrite ||
          !mounted ||
          revision != target.revision) {
        return;
      }
      setState(() {
        target.loading = false;
        target.error = failureMessage;
      });
    }
  }

  Future<void> _loadPosts({bool append = false}) => _loadPage(
    _posts,
    (page) => _repository.getMyPosts(page: page, size: 30),
    'Yazıların yüklenemedi. Birazdan yeniden deneyebilirsin.',
    append: append,
  );

  Future<void> _loadIncoming({bool append = false}) async {
    if (!overthinkingSession.canWrite) return;
    await Future.wait([
      if (!append) _incomingUnread.refresh(),
      _loadPage(
        _incoming,
        (page) => _repository.getIncomingRevealRequests(page: page, size: 30),
        'Gelen isteklerin yüklenemedi. Birazdan yeniden deneyebilirsin.',
        append: append,
      ),
    ]);
  }

  Future<void> _loadSent({bool append = false}) => _loadPage(
    _sent,
    (page) => _repository.getSentRevealRequests(page: page, size: 30),
    'Gönderdiğin istekler yüklenemedi. Birazdan yeniden deneyebilirsin.',
    append: append,
  );

  void _message(String message, {bool error = false}) {
    if (!overthinkingSession.canWrite || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      appSnackBar(
        context,
        tone: error ? AppSnackBarTone.error : AppSnackBarTone.success,
        content: Text(message),
      ),
    );
  }

  Future<void> _openPostPreview(OverthinkingPost post) async {
    if (!overthinkingSession.canWrite || _busyPosts.isNotEmpty) return;
    _busyPosts.add(post.id);
    setState(() {});
    try {
      final result = await _repository.getDetail(postId: post.id);
      if (!overthinkingSession.canWrite || !mounted) return;
      if (!result.isSuccess || result.data == null) {
        _message(result.error?.message ?? 'Yazı açılamadı.', error: true);
        return;
      }
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: OverthinkingPalette.surface,
        shape: _manageSheetShape,
        builder: (_) => OverthinkingSessionBoundary(
          session: overthinkingSession,
          child: _PostPreviewSheet(post: result.data!),
        ),
      );
    } catch (_) {
      _message('Yazı açılamadı. Yeniden deneyebilirsin.', error: true);
    } finally {
      if (mounted && overthinkingSession.canWrite) {
        setState(() => _busyPosts.remove(post.id));
      }
    }
  }

  Future<void> _deletePost(OverthinkingPost post) async {
    if (!overthinkingSession.canWrite || _busyPosts.isNotEmpty) return;
    _busyPosts.add(post.id);
    setState(() {});
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => OverthinkingSessionBoundary(
          session: overthinkingSession,
          child: AlertDialog(
            backgroundColor: OverthinkingPalette.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Text('Bu yazıyı sil?', style: _manageHeading),
            content: Text(
              '“${post.title}” kaleminden ve akıştan kaldırılacak. Bu işlemi geri alamazsın.',
              style: _manageBody,
            ),
            actions: [
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: OverthinkingPalette.muted,
                ),
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                style: _managePrimaryButton(context).copyWith(
                  backgroundColor: WidgetStatePropertyAll(AppColors.coral),
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Yazıyı sil'),
              ),
            ],
          ),
        ),
      );
      if (confirmed != true || !mounted || !overthinkingSession.canWrite) {
        return;
      }
      final result = await _repository.deletePost(postId: post.id);
      if (!overthinkingSession.canWrite || !mounted) return;
      if (result.isSuccess) {
        setState(() {
          _posts.invalidateRead();
          _posts.items = _posts.items
              .where((item) => item.id != post.id)
              .toList();
          _posts.page = 0;
          _posts.hasNext = false;
          final total = _posts.total;
          if (total != null && total > 0) _posts.total = total - 1;
        });
        // Page offsets shift after deletion; reload before allowing another page.
        await _loadPosts();
        _incoming.invalidateRead();
        await _loadIncoming();
        _message('Yazın silindi.');
      } else {
        _message(result.error?.message ?? 'Yazı silinemedi.', error: true);
      }
    } catch (_) {
      _message('Yazı silinemedi. Yeniden deneyebilirsin.', error: true);
    } finally {
      if (mounted && overthinkingSession.canWrite) {
        setState(() => _busyPosts.remove(post.id));
      }
    }
  }

  Future<void> _toggleLike(OverthinkingPost post) async {
    if (!overthinkingSession.canWrite || _busyPosts.isNotEmpty) return;
    _busyPosts.add(post.id);
    setState(() {});
    try {
      final engagement = serviceLocator<EngagementRepository>();
      final result = post.likedByMe
          ? await engagement.unlike(
              targetType: 'OVERTHINKING',
              targetId: post.id,
            )
          : await engagement.like(
              targetType: 'OVERTHINKING',
              targetId: post.id,
            );
      if (!mounted || !overthinkingSession.canWrite) return;
      if (result.isSuccess) {
        setState(() {
          _posts.invalidateRead();
          _posts.items = _posts.items
              .map(
                (item) => item.id == post.id
                    ? item.copyWith(
                        likedByMe: !post.likedByMe,
                        likeCount:
                            (item.likeCount +
                                    (item.likedByMe == post.likedByMe
                                        ? (post.likedByMe ? -1 : 1)
                                        : 0))
                                .clamp(0, 1 << 30),
                      )
                    : item,
              )
              .toList();
        });
      } else {
        _message(
          result.error?.message ?? 'Beğeni güncellenemedi.',
          error: true,
        );
      }
    } catch (_) {
      _message('Beğeni güncellenemedi. Yeniden deneyebilirsin.', error: true);
    } finally {
      if (mounted && overthinkingSession.canWrite) {
        setState(() => _busyPosts.remove(post.id));
      }
    }
  }

  Future<void> _openComments(OverthinkingPost post) async {
    if (!overthinkingSession.canWrite || _busyPosts.isNotEmpty) return;
    _busyPosts.add(post.id);
    setState(() {});
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: OverthinkingPalette.surface,
        shape: _manageSheetShape,
        builder: (context) => OverthinkingSessionBoundary(
          session: overthinkingSession,
          child: Theme(
            data: OverthinkingPalette.theme(context),
            child: BlocProvider(
              create: (_) => serviceLocator<CommentThreadCubit>(),
              child: CommentThreadSheet(
                targetType: 'OVERTHINKING',
                targetId: post.id,
              ),
            ),
          ),
        ),
      );
      if (mounted && overthinkingSession.canWrite) await _loadPosts();
    } finally {
      if (mounted && overthinkingSession.canWrite) {
        setState(() => _busyPosts.remove(post.id));
      }
    }
  }

  Future<void> _decideReveal(
    OverthinkingRevealRequest request,
    bool approve,
  ) async {
    if (!overthinkingSession.canWrite ||
        request.status != 'PENDING' ||
        !_busyRequests.add(request.id)) {
      return;
    }
    setState(() {});
    try {
      final result = approve
          ? await _repository.approveRevealRequest(requestId: request.id)
          : await _repository.rejectRevealRequest(requestId: request.id);
      if (!overthinkingSession.canWrite || !mounted) return;
      if (result.isSuccess && result.data != null) {
        setState(() {
          _incoming.invalidateRead();
          _incoming.items = _incoming.items
              .map((item) => item.id == request.id ? result.data! : item)
              .toList();
        });
        _message(
          approve
              ? 'Kimlik isteğini kabul ettin.'
              : 'Kimlik isteğini reddettin.',
        );
        await _incomingUnread.refresh();
      } else {
        _message(result.error?.message ?? 'İstek yanıtlanamadı.', error: true);
      }
    } catch (_) {
      _message('İstek yanıtlanamadı. Yeniden deneyebilirsin.', error: true);
    } finally {
      if (mounted && overthinkingSession.canWrite) {
        setState(() => _busyRequests.remove(request.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!overthinkingSession.canWrite) {
      return const OverthinkingUnavailableScreen();
    }
    return Theme(
      data: OverthinkingPalette.theme(context),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: OverthinkingPalette.background,
        appBar: AppBar(
          backgroundColor: OverthinkingPalette.background,
          foregroundColor: OverthinkingPalette.text,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            'Overthinking',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          centerTitle: false,
        ),
        body: TableGroupOverviewBackdrop(
          child: SafeArea(
            top: false,
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(22, 10, 22, 22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Yazıların ve kimlik isteklerin',
                            style: _manageEyebrow,
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Yazılar ve istekler',
                            style: TextStyle(
                              color: OverthinkingPalette.text,
                              fontSize: 30,
                              height: 1.1,
                              letterSpacing: -1,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Paylaşımlarını ve kimlik isteklerini yönet.',
                            style: _manageBody,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 18),
                      padding: const EdgeInsets.all(4),
                      decoration: _manageCardDecoration(),
                      child: TabBar(
                        controller: _tabs,
                        onTap: (index) {
                          if (index == 1 && !_tabs.indexIsChanging) {
                            _markIncomingSeen();
                          }
                        },
                        dividerColor: Colors.transparent,
                        labelColor: OverthinkingPalette.text,
                        unselectedLabelColor: OverthinkingPalette.muted,
                        labelStyle: Theme.of(context).textTheme.labelLarge
                            ?.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicator: BoxDecoration(
                          color: OverthinkingPalette.surfaceRaised,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        tabs: const [
                          Tab(text: 'Yazılarım'),
                          Tab(text: 'Gelen istekler'),
                          Tab(text: 'Gönderilen'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: TabBarView(
                        controller: _tabs,
                        children: [
                          _ManageList<OverthinkingPost>(
                            state: _posts,
                            title: 'Yazıların',
                            emptyIcon: Icons.edit_note_rounded,
                            emptyTitle: 'İlk satır seni bekliyor.',
                            emptyMessage:
                                'Bir şarkının sende bıraktığını yaz. Paylaştığın düşünceler burada birikir.',
                            onRefresh: _loadPosts,
                            onLoadMore: () => _loadPosts(append: true),
                            itemBuilder: (post) => OverthinkingPostCard(
                              key: ValueKey('manage-post-${post.id}'),
                              post: post,
                              isOwnPost: true,
                              busy: _busyPosts.isNotEmpty,
                              onTap: () => _openPostPreview(post),
                              onLike: () => _toggleLike(post),
                              onComments: () => _openComments(post),
                              onDelete: () => _deletePost(post),
                            ),
                          ),
                          _ManageList<OverthinkingRevealRequest>(
                            state: _incoming,
                            title: 'Gelen kimlik istekleri',
                            emptyIcon: Icons.mark_email_unread_outlined,
                            emptyTitle: 'Şimdilik sessiz.',
                            emptyMessage:
                                'Anonim yazılarında kim olduğunu merak edenlerin istekleri burada görünür.',
                            onRefresh: _loadIncoming,
                            onLoadMore: () => _loadIncoming(append: true),
                            itemBuilder: (request) => _RevealRequestCard(
                              request: request,
                              incoming: true,
                              busy: _busyRequests.contains(request.id),
                              onApprove: () => _decideReveal(request, true),
                              onReject: () => _decideReveal(request, false),
                            ),
                          ),
                          _ManageList<OverthinkingRevealRequest>(
                            state: _sent,
                            title: 'Gönderdiğin istekler',
                            emptyIcon: Icons.send_outlined,
                            emptyTitle: 'Henüz bir istek yok.',
                            emptyMessage:
                                'Bir yazının ardındaki kişiyi merak ettiğinde gönderdiğin isteği buradan takip edebilirsin.',
                            onRefresh: _loadSent,
                            onLoadMore: () => _loadSent(append: true),
                            itemBuilder: (request) => _RevealRequestCard(
                              request: request,
                              incoming: false,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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
    );
  }
}

class _ManagePage<T> {
  final String Function(T item) idOf;
  _ManagePage(this.idOf);

  List<T> items = [];
  bool loading = false;
  bool hasNext = false;
  int page = 0;
  int? total;
  String? error;
  int revision = 0;

  void invalidateRead() {
    revision++;
    loading = false;
    error = null;
  }
}

class _ManageList<T> extends StatelessWidget {
  final _ManagePage<T> state;
  final String title;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyMessage;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onLoadMore;
  final Widget Function(T item) itemBuilder;

  const _ManageList({
    required this.state,
    required this.title,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.onRefresh,
    required this.onLoadMore,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (state.loading && state.items.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          color: OverthinkingPalette.accent,
          strokeWidth: 2,
        ),
      );
    }
    final hasItems = state.items.isNotEmpty;
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: OverthinkingPalette.accent,
      backgroundColor: OverthinkingPalette.surfaceRaised,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (!hasItems)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _ManageEmptyState(
                icon: state.error == null ? emptyIcon : Icons.wifi_off_rounded,
                title: state.error == null ? emptyTitle : 'Şu an yükleyemedik.',
                message: state.error ?? emptyMessage,
                onRetry: state.error == null ? null : onRefresh,
              ),
            )
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: _manageEyebrow.copyWith(
                          color: OverthinkingPalette.muted,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    Text(
                      '${state.total ?? state.items.length}${state.total == null && state.hasNext ? '+' : ''}',
                      style: const TextStyle(
                        color: OverthinkingPalette.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              sliver: SliverList.separated(
                itemCount: state.items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, index) => itemBuilder(state.items[index]),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 30),
                child: Column(
                  children: [
                    if (state.error != null) ...[
                      Text(
                        state.error!,
                        style: _manageBody.copyWith(
                          color: OverthinkingPalette.accent,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      TextButton(
                        onPressed: onRefresh,
                        style: TextButton.styleFrom(
                          foregroundColor: OverthinkingPalette.text,
                        ),
                        child: const Text('Yeniden yükle'),
                      ),
                    ],
                    if (state.loading)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: OverthinkingPalette.accent,
                            strokeWidth: 2,
                          ),
                        ),
                      )
                    else if (state.hasNext)
                      OutlinedButton.icon(
                        onPressed: onLoadMore,
                        style: _manageSecondaryButton(context),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Daha fazla göster'),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
