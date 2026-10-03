part of 'overthinking_feed_screen.dart';

class OverthinkingDetailScreen extends StatefulWidget {
  final OverthinkingPost post;
  final bool revealRequesting;
  final bool requireAuthorVisibility;
  const OverthinkingDetailScreen({
    super.key,
    required this.post,
    required this.revealRequesting,
    this.requireAuthorVisibility = false,
  });

  @override
  State<OverthinkingDetailScreen> createState() => _OverthinkingDetailState();
}

class _OverthinkingDetailState extends State<OverthinkingDetailScreen>
    with WidgetsBindingObserver, RouteAware {
  OverthinkingPost get post => widget.post;
  bool get requireAuthorVisibility => widget.requireAuthorVisibility;
  ModalRoute<dynamic>? _route;
  OverthinkingFeedCubit? _cubit;
  Future<void>? _detailFlight;
  int _visibilityRevision = 0;
  bool _started = false, _freshDetailReady = false, _targetFailed = false;
  bool _scheduled = false;
  _OverthinkingDetailRetry? _retry;

  bool get _current => mounted && _cubit?.isSessionCurrent == true &&
      _route?.isActive == true && _route?.isCurrent == true &&
      TickerMode.of(context) &&
      (_route?.secondaryAnimation == null ||
          _route!.secondaryAnimation!.status == AnimationStatus.dismissed) &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cubit = context.read<OverthinkingFeedCubit>();
    final route = ModalRoute.of(context);
    if (!identical(route, _route)) {
      _suspend();
      notificationTargetRouteObserver.unsubscribe(this);
      _route?.secondaryAnimation?.removeStatusListener(_coverChanged);
      _route = route;
      if (route != null) {
        notificationTargetRouteObserver.subscribe(this, route);
        route.secondaryAnimation?.addStatusListener(_coverChanged);
      }
    }
    if (!_current) _suspend();
    _schedule();
  }

  void _schedule() {
    if (_scheduled || !mounted || !requireAuthorVisibility) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted) return;
      if (!_current) { _hideRetry(); return; }
      if (!_started) {
        unawaited(_loadDetail());
      } else if (_targetFailed && _detailFlight == null) {
        _showRetry();
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _loadDetail() {
    final flight = _detailFlight;
    if (flight != null) return flight;
    if (!_current) return Future.value();
    _started = true;
    _hideRetry();
    final revision = _visibilityRevision;
    setState(() { _freshDetailReady = false; _targetFailed = false; });
    final pending = _performDetailLoad(revision);
    _detailFlight = pending;
    return pending;
  }

  Future<void> _performDetailLoad(int revision) async {
    var loaded = false;
    try {
      loaded = await _cubit!.refreshNotificationPost(post.id,
        acceptResult: () => _current && revision == _visibilityRevision);
    } catch (_) {
      // A transport exception is still an explicit target failure, never ACK.
    } finally {
      _detailFlight = null;
      if (mounted) {
        final exact = _cubit!.state.posts.where((p) => p.id == post.id).firstOrNull;
        setState(() {
          _freshDetailReady = loaded && _current &&
              revision == _visibilityRevision && exact?.hasVisibleAuthor == true;
          _targetFailed = !_freshDetailReady;
        });
        _schedule();
      }
    }
  }

  void _hideRetry() {
    final retry = _retry;
    _retry = null;
    retry?.retire();
  }

  void _showRetry() {
    if (_retry != null || !_current) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    final retry = _OverthinkingDetailRetry(messenger);
    _retry = retry;
    retry.controller = messenger.showSnackBar(appSnackBar(context,
      content: const Text('İçerik güncellenemedi.'),
      tone: AppSnackBarTone.info,
      inlineAction: true,
      duration: const Duration(days: 1),
      onVisible: () {
        retry.painted = true;
        if (retry.retired || !identical(_retry, retry) || !_current) retry.retire();
      },
      action: SnackBarAction(label: 'Tekrar dene', onPressed: () {
        if (identical(_retry, retry) && _current) unawaited(_loadDetail());
      }),
    ));
    unawaited(retry.controller.closed.then((_) {
      retry.closed = true;
      if (!identical(_retry, retry)) return;
      _retry = null;
      _schedule();
    }));
  }

  void _suspend() {
    ++_visibilityRevision;
    _hideRetry();
  }
  void _coverChanged(AnimationStatus status) {
    if (status != AnimationStatus.dismissed) _suspend();
    _schedule();
  }
  @override
  void didPushNext() => _suspend();
  @override
  void didPop() => _suspend();
  @override
  void didPopNext() => _schedule();
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _suspend();
    _schedule();
  }
  @override
  void dispose() {
    _suspend();
    notificationTargetRouteObserver.unsubscribe(this);
    _route?.secondaryAnimation?.removeStatusListener(_coverChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _requestReveal(
    BuildContext context,
    OverthinkingPost currentPost,
  ) async {
    final cubit = context.read<OverthinkingFeedCubit>();
    if (!cubit.canWrite ||
        cubit.state.revealRequestingIds.contains(currentPost.id)) {
      return;
    }
    var latestPost = currentPost;
    for (final item in cubit.state.posts) {
      if (item.id == currentPost.id) {
        latestPost = item;
        break;
      }
    }
    final wasPending = latestPost.revealRequestPending;
    final ok = await cubit.toggleReveal(latestPost);
    if (!context.mounted || !cubit.isSessionCurrent) return;
    ScaffoldMessenger.of(context).showSnackBar(
      appSnackBar(
        context,
        tone: ok ? AppSnackBarTone.success : AppSnackBarTone.error,
        content: Text(
          ok
              ? wasPending
                    ? 'Kimlik isteğin geri çekildi.'
                    : 'Kimlik isteğin gönderildi.'
              : cubit.state.error?.message ?? 'Kimlik isteği güncellenemedi.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Theme(
      data: OverthinkingPalette.theme(context),
      child: Builder(
        builder: (context) => BlocBuilder<OverthinkingFeedCubit, OverthinkingFeedState>(
          builder: (context, state) {
            final cubit = context.read<OverthinkingFeedCubit>();
            _schedule();
            if (!cubit.isSessionCurrent) {
              return const OverthinkingUnavailableScreen();
            }
            if (cubit.isPostUnavailable(post.id)) {
              return const OverthinkingUnavailableScreen(postMissing: true);
            }
            var current = post;
            var destinationDetailLoaded = false;
            for (final item in state.posts) {
              if (item.id == post.id) {
                current = item;
                destinationDetailLoaded = true;
                break;
              }
            }
            final currentPost = current;
            final hidden =
                currentPost.anonymous && !currentPost.hasVisibleAuthor;
            final requesting = state.revealRequestingIds.contains(
              currentPost.id,
            );
            return Scaffold(
              appBar: AppBar(
                title: const Text(
                  'Overthinking',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                actions: [
                  OverthinkingProfileShareButton(
                    post: currentPost,
                    enabled: cubit.canWrite,
                  ),
                  Padding(
                    padding: EdgeInsets.only(right: 20),
                    child: Icon(
                      Icons.all_inclusive_rounded,
                      color: OverthinkingPalette.lilac,
                    ),
                  ),
                ],
              ),
              body: NotificationTargetReady(
                ready: currentPost.id == post.id &&
                    (!requireAuthorVisibility ||
                        (_freshDetailReady && destinationDetailLoaded &&
                            currentPost.hasVisibleAuthor)),
                contentIdentity: currentPost,
                child: TableGroupSurfaceBackdrop(
                  child: SafeArea(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(22, 20, 22, 32),
                      children: [
                        OverthinkingEyebrow(
                          'Overthinking',
                          color: OverthinkingPalette.accent,
                        ),
                        const SizedBox(height: 16),
                        SelectableText(
                          currentPost.title,
                          style: TextStyle(
                            fontSize: 28,
                            height: 1.18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.9,
                            color: OverthinkingPalette.text,
                          ),
                        ),
                        const SizedBox(height: 23),
                        _AuthorLine(post: currentPost),
                        const SizedBox(height: 24),
                        Divider(height: 1, color: OverthinkingPalette.border),
                        if (_hasMusic(currentPost)) ...[
                          const SizedBox(height: 22),
                          const OverthinkingEyebrow('BU YAZIYA EŞLİK EDEN'),
                          const SizedBox(height: 12),
                          _MusicChip(
                            key: ValueKey('detail-music-${currentPost.id}'),
                            post: currentPost,
                          ),
                        ],
                        const SizedBox(height: 27),
                        SelectableText(
                          currentPost.content,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.9,
                            color: TableGroupSurfaceStyle.of(context).bodyMuted,
                          ),
                        ),
                        const SizedBox(height: 26),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _PostAction(
                            icon: currentPost.likedByMe
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            label: currentPost.likeCount == 0
                                ? 'İlk beğenen sen ol'
                                : '${currentPost.likeCount} beğeni',
                            tooltip: currentPost.likedByMe
                                ? 'Beğeniyi kaldır'
                                : 'Beğen',
                            active: currentPost.likedByMe,
                            iconColor: AppColors.likeHeart,
                            onTap: () => context
                                .read<OverthinkingFeedCubit>()
                                .toggleLike(currentPost),
                          ),
                        ),
                        if (hidden) ...[
                          const SizedBox(height: 20),
                          OverthinkingSurface(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.lock_outline_rounded,
                                  color: OverthinkingPalette.lilac,
                                  size: 23,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Bu satırların arkasında kim var?',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: OverthinkingPalette.text,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  currentPost.revealRequestPending
                                      ? 'Yanıt bekleniyor. İsteğini geri çekmek için butona yeniden dokunabilirsin.'
                                      : 'Yazara bir kimlik isteği gönderebilirsin. İsteklerini Overthinking ana sayfasından takip et.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.6,
                                    color: OverthinkingPalette.muted,
                                  ),
                                ),
                                const SizedBox(height: 13),
                                OutlinedButton.icon(
                                  key: const ValueKey(
                                    'overthinking-reveal-toggle',
                                  ),
                                  onPressed: requesting || !cubit.canWrite
                                      ? null
                                      : () => _requestReveal(
                                          context,
                                          currentPost,
                                        ),
                                  icon: Icon(
                                    requesting
                                        ? Icons.hourglass_top_rounded
                                        : currentPost.revealRequestPending
                                        ? Icons.check_rounded
                                        : Icons.person_search_outlined,
                                    size: 17,
                                  ),
                                  label: Text(
                                    requesting
                                        ? currentPost.revealRequestPending
                                              ? 'Geri çekiliyor...'
                                              : 'Gönderiliyor...'
                                        : currentPost.revealRequestPending
                                        ? 'Kimlik isteği gönderildi'
                                        : 'Kimlik isteği gönder',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 30),
                        Divider(height: 1, color: OverthinkingPalette.border),
                        const SizedBox(height: 25),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Yorumlar',
                                style: TextStyle(
                                  color: OverthinkingPalette.text,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -.4,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${currentPost.commentCount}',
                              style: TextStyle(
                                color: OverthinkingPalette.muted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        CommentThreadView(
                          useThemeColors: true,
                          targetType: OverthinkingFeedCubit.targetType,
                          targetId: currentPost.id,
                          autoLoad: false,
                          onCommentCreated: () => context
                              .read<OverthinkingFeedCubit>()
                              .incrementCommentCount(currentPost.id),
                          onCommentDeleted: () => context
                              .read<OverthinkingFeedCubit>()
                              .refreshPost(currentPost.id),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _OverthinkingDetailRetry {
  _OverthinkingDetailRetry(this.messenger);
  final ScaffoldMessengerState messenger;
  late final ScaffoldFeatureController<SnackBar, SnackBarClosedReason> controller;
  bool painted = false, retired = false, closed = false;
  void retire() {
    retired = true;
    scheduleMicrotask(() {
      if (painted && !closed && messenger.mounted) {
        // Background routes may mute animation tickers. Retire the owned
        // painted bar immediately so it cannot remain on a hidden destination.
        messenger.removeCurrentSnackBar(reason: SnackBarClosedReason.hide);
      }
    });
  }
}
