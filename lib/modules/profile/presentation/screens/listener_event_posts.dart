import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/app_snack_bar.dart';
import '../../../../shared/widgets/gradient_outline_button.dart';
import '../../../engagement/domain/engagement_repository.dart';
import '../../../engagement/presentation/cubit/interaction_stats_state.dart';
import '../../../event_audience/domain/event_audience_repository.dart';
import '../../../event_audience/presentation/event_audience_controller.dart';
import '../../domain/entities/venue_event_detail.dart';
import '../cubit/listener_event_feed_controller.dart';
import '../share/event_share_flow.dart';
import 'listener_event_post_card.dart';
import 'listener_event_post_comments_sheet.dart';
import 'listener_event_post_engagement.dart';
import 'listener_event_post_participation.dart';
import 'listener_event_post_note_editor.dart';
import 'listener_profile_theme.dart';
import 'weekly_event_detail_screen.dart';

class ListenerEventPostsSection extends StatelessWidget {
  const ListenerEventPostsSection({
    super.key,
    required this.listenerProfileId,
    required this.username,
    this.avatarUrl,
    this.ownerUserId,
    this.repository,
    this.sessions,
    this.refreshSignal,
    this.showHeading = false,
    this.onOpenEvent,
  });
  final String listenerProfileId;
  final String username;
  final String? avatarUrl;
  final String? ownerUserId;
  final EventAudienceRepository? repository;
  final AuthSessionManager? sessions;
  final ValueListenable<int>? refreshSignal;
  final bool showHeading;
  final Future<void> Function(VenueEventDetail event)? onOpenEvent;

  @override
  Widget build(BuildContext context) => _ListenerEventFeed(
    listenerProfileId: listenerProfileId,
    username: username,
    avatarUrl: avatarUrl,
    ownerUserId: ownerUserId,
    repository: repository,
    sessions: sessions,
    refreshSignal: refreshSignal,
    showHeading: showHeading,
    onOpenEvent: onOpenEvent,
  );
}

class ListenerEventPlansButton extends StatelessWidget {
  const ListenerEventPlansButton({
    super.key,
    required this.listenerProfileId,
    required this.userId,
    required this.username,
    this.avatarUrl,
    this.repository,
    this.sessions,
  });
  final String listenerProfileId;
  final String userId;
  final String username;
  final String? avatarUrl;
  final EventAudienceRepository? repository;
  final AuthSessionManager? sessions;

  @override
  Widget build(BuildContext context) => GradientOutlineButton(
    key: const Key('listener-my-event-plans'),
    label: 'Planlarım',
    leading: const Icon(Icons.event_note_outlined, size: 19),
    backgroundColor: const Color(0xFF101722),
    onPressed: () {
      if (!context.mounted || ModalRoute.of(context)?.isCurrent != true) return;
      final manager = sessions ?? _registered<AuthSessionManager>();
      if (manager == null ||
          manager.session.userId != userId ||
          !manager.session.isAuthenticated ||
          !manager.session.isActive ||
          !canUseEventAudience(manager.session) ||
          manager.session.requiresListenerProfileChoice ||
          !manager.session.hasAnyRole(const ['LISTENER', 'ROLE_LISTENER'])) {
        return;
      }
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => ListenerEventPlansScreen(
            listenerProfileId: listenerProfileId,
            userId: userId,
            username: username,
            avatarUrl: avatarUrl,
            repository: repository,
            sessions: manager,
          ),
        ),
      );
    },
  );
}

class ListenerEventPlansScreen extends StatelessWidget {
  const ListenerEventPlansScreen({
    super.key,
    required this.listenerProfileId,
    required this.userId,
    required this.username,
    this.avatarUrl,
    this.repository,
    this.sessions,
    this.onOpenEvent,
  });
  final String listenerProfileId;
  final String userId;
  final String username;
  final String? avatarUrl;
  final EventAudienceRepository? repository;
  final AuthSessionManager? sessions;
  final Future<void> Function(VenueEventDetail event)? onOpenEvent;

  @override
  Widget build(BuildContext context) => ListenerProfileTheme(
    child: _ListenerEventFeed(
      listenerProfileId: listenerProfileId,
      username: username,
      avatarUrl: avatarUrl,
      ownerUserId: userId,
      repository: repository,
      sessions: sessions,
      privatePlans: true,
      fullPage: true,
      onOpenEvent: onOpenEvent,
    ),
  );
}

class _ListenerEventFeed extends StatefulWidget {
  const _ListenerEventFeed({
    required this.listenerProfileId,
    required this.username,
    this.avatarUrl,
    this.ownerUserId,
    this.repository,
    this.sessions,
    this.refreshSignal,
    this.privatePlans = false,
    this.fullPage = false,
    this.showHeading = false,
    this.onOpenEvent,
  });
  final String listenerProfileId;
  final String username;
  final String? avatarUrl;
  final String? ownerUserId;
  final EventAudienceRepository? repository;
  final AuthSessionManager? sessions;
  final ValueListenable<int>? refreshSignal;
  final bool privatePlans;
  final bool fullPage;
  final bool showHeading;
  final Future<void> Function(VenueEventDetail event)? onOpenEvent;

  @override
  State<_ListenerEventFeed> createState() => _ListenerEventFeedState();
}

class _ListenerEventFeedState extends State<_ListenerEventFeed>
    with WidgetsBindingObserver {
  ListenerEventFeedController? _feed;
  bool _opening = false;
  DialogRoute<void>? _noteDialog;
  AuthSession? _noteSession;
  ListenerEventFeedRow? _noteRow;
  bool _noteSaving = false;
  DialogRoute<bool>? _deleteDialog;
  AuthSession? _deleteSession;
  String? _deletePostId;
  ValueNotifier<bool>? _commentsAvailable;
  AuthSession? _commentsSession;
  String? _commentsPostId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.refreshSignal?.addListener(_refresh);
    _bind();
  }

  void _bind() {
    _dismissNoteDialog();
    _dismissDeleteDialog();
    _invalidateComments();
    _feed?.removeListener(_changed);
    _feed?.dispose();
    _opening = false;
    final repository =
        widget.repository ?? _registered<EventAudienceRepository>();
    final sessions = widget.sessions ?? _registered<AuthSessionManager>();
    _feed = repository == null || sessions == null
        ? null
        : ListenerEventFeedController(
            repository: repository,
            sessions: sessions,
            listenerProfileId: widget.listenerProfileId,
            ownerUserId: widget.ownerUserId,
            privatePlans: widget.privatePlans,
            pageSize: widget.fullPage ? 20 : 2,
          );
    _feed?.addListener(_changed);
    unawaited(_feed?.reload());
  }

  @override
  void didUpdateWidget(covariant _ListenerEventFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshSignal != widget.refreshSignal) {
      oldWidget.refreshSignal?.removeListener(_refresh);
      widget.refreshSignal?.addListener(_refresh);
    }
    if (oldWidget.listenerProfileId != widget.listenerProfileId ||
        oldWidget.ownerUserId != widget.ownerUserId ||
        oldWidget.repository != widget.repository ||
        oldWidget.sessions != widget.sessions) {
      _bind();
    }
  }

  void _changed() {
    final feed = _feed;
    if (_noteDialog != null &&
        (feed == null ||
            !feed.allowed ||
            !identical(feed.sessions.session, _noteSession) ||
            (!_noteSaving &&
                (feed.loading ||
                    !feed.rows.any((row) => identical(row, _noteRow)))))) {
      _dismissNoteDialog();
    }
    if (_commentsAvailable != null &&
        (feed == null ||
            !feed.allowed ||
            !identical(feed.sessions.session, _commentsSession) ||
            (!feed.loading &&
                !feed.rows.any(
                  (row) =>
                      row.postId == _commentsPostId &&
                      (!widget.privatePlans ||
                          row.privateState?.publicationVisible == true),
                )))) {
      _invalidateComments();
    }
    if (_deleteDialog != null &&
        (feed == null ||
            !feed.allowed ||
            feed.loading ||
            !identical(feed.sessions.session, _deleteSession) ||
            !feed.rows.any((row) => row.postId == _deletePostId))) {
      _dismissDeleteDialog();
    }
    if (mounted) setState(() {});
  }

  void _dismissDeleteDialog() {
    final dialog = _deleteDialog;
    _deleteDialog = null;
    _deleteSession = null;
    _deletePostId = null;
    if (dialog == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (dialog.isActive) dialog.navigator?.removeRoute(dialog);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _dismissNoteDialog() {
    final dialog = _noteDialog;
    _noteDialog = null;
    _noteSession = null;
    _noteRow = null;
    _noteSaving = false;
    if (dialog == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (dialog.isActive) dialog.navigator?.removeRoute(dialog);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _invalidateComments() {
    final availability = _commentsAvailable;
    if (availability == null || !availability.value) return;
    // Feed rebinding can happen during a parent build. Update the separately
    // mounted modal after that frame, and never re-enable a revoked thread.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (identical(_commentsAvailable, availability)) {
        availability.value = false;
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _refresh() => unawaited(_feed?.reload());

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  @override
  void dispose() {
    _dismissNoteDialog();
    _dismissDeleteDialog();
    _invalidateComments();
    WidgetsBinding.instance.removeObserver(this);
    widget.refreshSignal?.removeListener(_refresh);
    _feed?.removeListener(_changed);
    _feed?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feed = _feed;
    final available = feed != null && feed.allowed;
    final body = !available
        ? widget.fullPage
              ? const Center(
                  child: Text(
                    'Planlarını görmek için kendi hesabına giriş yap.',
                  ),
                )
              : const SizedBox.shrink()
        : _body(feed);
    if (!widget.fullPage) return body;
    return Scaffold(
      backgroundColor: const Color(0xFF070B13),
      appBar: AppBar(
        title: Text(widget.privatePlans ? 'Planlarım' : 'Paylaşımlar'),
      ),
      body: body,
    );
  }

  Widget _body(ListenerEventFeedController feed) {
    final expectedSession = feed.sessions.session;
    if (!widget.fullPage &&
        !feed.loading &&
        feed.error == null &&
        feed.rows.isEmpty) {
      return const SizedBox.shrink();
    }
    final content = <Widget>[
      if (widget.showHeading) ...[
        const Text(
          'Paylaşımlar',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
      ],
      if (widget.fullPage)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              for (final period in [
                EventAudiencePeriod.upcoming,
                EventAudiencePeriod.past,
              ])
                _PlanPeriodChoice(
                  key: ValueKey('listener-plans-period-${period.name}'),
                  label: period == EventAudiencePeriod.upcoming
                      ? 'Güncel planlar'
                      : 'Geçmiş planlar',
                  selected: feed.period == period,
                  onPressed: () => unawaited(feed.selectPeriod(period)),
                ),
              if (!widget.privatePlans)
                _PlanPeriodChoice(
                  label: 'Tümü',
                  selected: feed.period == EventAudiencePeriod.all,
                  onPressed: () =>
                      unawaited(feed.selectPeriod(EventAudiencePeriod.all)),
                ),
            ],
          ),
        ),
      if (feed.loading)
        const Padding(
          key: Key('listener-event-posts-loading'),
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (feed.error != null)
        Column(
          key: const Key('listener-event-posts-error'),
          children: [
            Text(feed.error!, style: const TextStyle(color: Color(0xFFA0A9B6))),
            TextButton.icon(
              onPressed: () => unawaited(feed.retry()),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tekrar dene'),
            ),
          ],
        )
      else if (feed.rows.isEmpty && widget.fullPage)
        Padding(
          key: const Key('listener-event-posts-empty'),
          padding: const EdgeInsets.symmetric(vertical: 36),
          child: Text(
            feed.period == EventAudiencePeriod.past
                ? widget.privatePlans
                      ? 'Henüz geçmiş bir planın yok.'
                      : 'Bu bölümde paylaşılmış geçmiş bir etkinlik yok.'
                : widget.privatePlans
                ? 'Bir etkinlikte Gidiyorum veya Düşünüyorum seçerek planını kaydedebilirsin.'
                : 'Bu bölümde paylaşılmış bir etkinlik yok.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFA0A9B6), height: 1.5),
          ),
        ),
      // The full-page branch below builds these lazily. Only two compact
      // preview posts are ever inserted into the parent profile's list.
      if (!widget.fullPage)
        for (final row in feed.rows) ...[
          _card(feed, row),
          const SizedBox(height: 12),
        ],
      if (!widget.fullPage && feed.hasNext)
        TextButton(
          key: const Key('listener-event-posts-all'),
          onPressed: _opening
              ? null
              : () => unawaited(_openAll(feed, expectedSession)),
          child: const Text('Tüm etkinlik paylaşımları'),
        ),
    ];
    if (!widget.fullPage) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: content,
      );
    }
    return RefreshIndicator(
      onRefresh: feed.reload,
      child: ListView.builder(
        key: const Key('listener-event-plans-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        itemCount: feed.rows.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: content,
            );
          }
          if (index <= feed.rows.length) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _card(feed, feed.rows[index - 1]),
            );
          }
          return Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            children: [
              if (feed.page > 0)
                TextButton.icon(
                  key: const Key('listener-plans-previous'),
                  onPressed: feed.loading
                      ? null
                      : () => unawaited(feed.previous()),
                  icon: const Icon(Icons.chevron_left_rounded),
                  label: const Text('Önceki'),
                ),
              if (feed.hasNext)
                TextButton.icon(
                  key: const Key('listener-plans-next'),
                  onPressed: feed.loading ? null : () => unawaited(feed.next()),
                  icon: const Icon(Icons.chevron_right_rounded),
                  label: const Text('Sonraki'),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _card(ListenerEventFeedController feed, ListenerEventFeedRow row) {
    final expectedSession = feed.sessions.session;
    final own = widget.ownerUserId != null;
    final private = row.privateState;
    final ended = row.ended;
    final engagement = _registered<EngagementRepository>();
    final publicationVisible =
        row.postId != null && (private == null || private.publicationVisible);
    Widget buildCard({
      bool going = false,
      bool participationBusy = false,
      VoidCallback? onToggle,
    }) {
      Widget card({
        InteractionStatsItemState? stats,
        VoidCallback? onLike,
        AsyncCallback? refreshStats,
      }) => ListenerEventPostCard(
        event: row.event,
        username: widget.username,
        avatarUrl: widget.avatarUrl,
        intentLabel: row.intent.label,
        note: row.note,
        owner: own,
        ended: ended,
        isParticipating: going,
        intentBusy: participationBusy,
        onLike: onLike,
        isLiked: stats?.error == null && stats?.isLiked == true,
        likeBusy: onLike != null && (_opening || stats?.loading == true),
        likeCount: stats?.visibleLikeCount,
        commentCount: stats?.visibleCommentCount,
        visibilityLabel: private == null
            ? null
            : private.publicationVisible
            ? 'Profilinde paylaşıldı'
            : private.publishedOnProfile
            ? 'Hayalet modda gizli'
            : 'Yalnızca sen',
        onOpen: _opening
            ? null
            : () => unawaited(_openEvent(feed, row, expectedSession)),
        onIntent: own ? null : onToggle,
        onChangeIntent:
            _opening || !own || ended || !canUseEventAudience(expectedSession)
            ? null
            : () => unawaited(_changeOwnerIntent(feed, row, expectedSession)),
        onEditNote:
            _opening ||
                !own ||
                ended ||
                row.postId == null ||
                !canUseEventAudience(expectedSession)
            ? null
            : () => unawaited(_editOwnerNote(feed, row, expectedSession)),
        onShare: _opening
            ? null
            : () => unawaited(_share(feed, row, expectedSession)),
        onComments:
            _opening ||
                row.postId == null ||
                (private != null && !private.publicationVisible)
            ? null
            : () => unawaited(
                _openComments(
                  feed,
                  row,
                  expectedSession,
                  refreshStats: refreshStats,
                ),
              ),
        onDelete: _opening || !own || row.postId == null
            ? null
            : () => unawaited(_deletePost(feed, row, expectedSession)),
      );
      if (!publicationVisible || engagement == null) return card();
      return ListenerEventPostEngagement(
        key: ValueKey('listener-event-engagement-${row.postId}'),
        postId: row.postId!,
        repository: engagement,
        sessions: feed.sessions,
        canInteract: () =>
            !_opening && _currentAction(feed, expectedSession, row),
        onError: _feedback,
        builder: (stats, onLike, refresh) =>
            card(stats: stats, onLike: onLike, refreshStats: refresh),
      );
    }

    if (!own && !ended && canUseEventAudience(expectedSession)) {
      return ListenerEventPostParticipation(
        key: ValueKey('listener-event-participation-${row.postId}'),
        eventId: row.event.id,
        refreshKey: row,
        repository: feed.repository,
        sessions: feed.sessions,
        canInteract: () =>
            !_opening && _currentAction(feed, expectedSession, row),
        onError: _feedback,
        builder: (going, busy, onToggle) => buildCard(
          going: going,
          participationBusy: busy,
          onToggle: onToggle,
        ),
      );
    }
    return buildCard();
  }

  bool _currentAction(
    ListenerEventFeedController feed,
    AuthSession expectedSession, [
    ListenerEventFeedRow? row,
  ]) =>
      mounted &&
      identical(_feed, feed) &&
      feed.allowed &&
      !feed.loading &&
      identical(feed.sessions.session, expectedSession) &&
      ModalRoute.of(context)?.isCurrent == true &&
      (row == null || feed.rows.any((item) => identical(item, row)));

  void _finishAction(ListenerEventFeedController feed) {
    if (mounted && identical(_feed, feed)) {
      setState(() => _opening = false);
    }
  }

  Future<void> _openComments(
    ListenerEventFeedController feed,
    ListenerEventFeedRow row,
    AuthSession expectedSession, {
    AsyncCallback? refreshStats,
  }) async {
    if (_opening || !_currentAction(feed, expectedSession, row)) return;
    final postId = row.postId;
    if (postId == null) return;
    final repository = _registered<EngagementRepository>();
    if (repository == null) {
      _feedback('Yorumlar şu anda açılamıyor. Tekrar deneyebilirsin.');
      return;
    }
    setState(() => _opening = true);
    final availability = ValueNotifier<bool>(true);
    _commentsAvailable = availability;
    _commentsSession = expectedSession;
    _commentsPostId = postId;
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: false,
        backgroundColor: const Color(0xFF101722),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        clipBehavior: Clip.antiAlias,
        builder: (_) => ListenerEventPostCommentsSheet(
          postId: postId,
          repository: repository,
          sessions: feed.sessions,
          expectedSession: expectedSession,
          publicationAvailable: availability,
        ),
      );
    } finally {
      if (identical(_commentsAvailable, availability)) {
        _commentsAvailable = null;
        _commentsSession = null;
        _commentsPostId = null;
      }
      availability.dispose();
      _finishAction(feed);
      // Updating counters must not clear the whole feed and jump the profile's
      // scroll position when a comment sheet closes.
      if (_currentAction(feed, expectedSession, row)) {
        await refreshStats?.call();
      }
    }
  }

  Future<void> _deletePost(
    ListenerEventFeedController feed,
    ListenerEventFeedRow row,
    AuthSession expectedSession,
  ) async {
    if (_opening ||
        !_currentAction(feed, expectedSession, row) ||
        widget.ownerUserId != expectedSession.userId ||
        row.postId == null) {
      return;
    }
    final postId = row.postId!;
    setState(() => _opening = true);
    final dialog = DialogRoute<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Paylaşım silinsin mi?'),
        content: const Text(
          'Bu paylaşım profilinden kaldırılacak ve yorumları kapanacak. '
          'Etkinlik planın korunacak.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            key: const Key('listener-event-post-delete-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Paylaşımı sil'),
          ),
        ],
      ),
    );
    _deleteDialog = dialog;
    _deleteSession = expectedSession;
    _deletePostId = postId;
    try {
      final confirmed = await Navigator.of(context).push<bool>(dialog);
      if (identical(_deleteDialog, dialog)) {
        _deleteDialog = null;
        _deleteSession = null;
        _deletePostId = null;
      }
      if (confirmed != true || !_currentAction(feed, expectedSession, row)) {
        return;
      }
      final result = await feed.repository.deletePost(
        postId: postId,
        expectedSessionKey: expectedSession.userId!,
      );
      // A successful delete triggers the repository's feed refresh. The old
      // row is expected to disappear; session/route identity still must match.
      if (!mounted ||
          !identical(_feed, feed) ||
          !identical(feed.sessions.session, expectedSession) ||
          ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
      if (!result.isSuccess) {
        _feedback(
          result.error?.message ??
              'Paylaşım silinemedi. Tekrar deneyebilirsin.',
        );
        await feed.reload();
      } else {
        await feed.reload();
      }
    } catch (_) {
      if (_currentAction(feed, expectedSession)) {
        _feedback('Paylaşım silinemedi. Tekrar deneyebilirsin.');
        await feed.reload();
      }
    } finally {
      if (identical(_deleteDialog, dialog)) _dismissDeleteDialog();
      _finishAction(feed);
    }
  }

  void _feedback(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      appSnackBar(context, content: Text(message), tone: AppSnackBarTone.error),
    );
  }

  Future<void> _share(
    ListenerEventFeedController feed,
    ListenerEventFeedRow row,
    AuthSession expectedSession,
  ) async {
    if (_opening || !_currentAction(feed, expectedSession, row)) return;
    setState(() => _opening = true);
    try {
      await shareAudienceEvent(
        context,
        eventId: row.event.id,
        sessions: feed.sessions,
        expectedSession: expectedSession,
      );
    } finally {
      _finishAction(feed);
    }
  }

  bool _ownerActionAllowed(
    ListenerEventFeedController feed,
    ListenerEventFeedRow row,
    AuthSession session,
  ) =>
      !_opening &&
      widget.ownerUserId == session.userId &&
      !row.ended &&
      canUseEventAudience(session) &&
      _currentAction(feed, session, row);

  bool _matchesOwnerPlan(EventAudienceState? state, ListenerEventFeedRow row) =>
      state != null &&
      state.eventId == row.event.id &&
      state.postId == row.postId &&
      state.intent != EventAudienceStatus.none &&
      state.eventAvailable &&
      state.canSetIntent;

  Future<void> _changeOwnerIntent(
    ListenerEventFeedController feed,
    ListenerEventFeedRow row,
    AuthSession expectedSession,
  ) async {
    if (!_ownerActionAllowed(feed, row, expectedSession)) return;
    setState(() => _opening = true);
    try {
      final read = await feed.repository.getIntent(
        eventId: row.event.id,
        expectedSessionKey: expectedSession.userId!,
      );
      if (!_currentAction(feed, expectedSession, row)) return;
      final current = read.data;
      if (!read.isSuccess || !_matchesOwnerPlan(current, row)) {
        _feedback(
          'Planın güncel durumu doğrulanamadı. Sayfayı yenileyip tekrar dene.',
        );
        return;
      }
      final target = row.intent == EventAudienceStatus.thinking
          ? EventAudienceStatus.going
          : EventAudienceStatus.thinking;
      final result = await feed.repository.setIntent(
        eventId: row.event.id,
        intent: target,
        publishedOnProfile: current!.publishedOnProfile,
        note: current.note,
        expectedVersion: current.version,
        expectedSessionKey: expectedSession.userId!,
      );
      if (!mounted ||
          !identical(_feed, feed) ||
          !identical(feed.sessions.session, expectedSession) ||
          ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
      if (!result.isSuccess ||
          result.data?.postId != row.postId ||
          result.data?.intent != target) {
        _feedback(
          'Katılım durumu değiştirilemedi. Güncel durumu kontrol edip tekrar dene.',
        );
      }
      await feed.reload();
    } catch (_) {
      if (_currentAction(feed, expectedSession)) {
        _feedback('Katılım durumu değiştirilemedi. Tekrar deneyebilirsin.');
      }
    } finally {
      _finishAction(feed);
    }
  }

  Future<void> _editOwnerNote(
    ListenerEventFeedController feed,
    ListenerEventFeedRow row,
    AuthSession expectedSession,
  ) async {
    if (!_ownerActionAllowed(feed, row, expectedSession) ||
        row.postId == null) {
      return;
    }
    setState(() => _opening = true);
    try {
      final read = await feed.repository.getIntent(
        eventId: row.event.id,
        expectedSessionKey: expectedSession.userId!,
      );
      if (!mounted || !_currentAction(feed, expectedSession, row)) return;
      final current = read.data;
      if (!read.isSuccess ||
          !_matchesOwnerPlan(current, row) ||
          !current!.publishedOnProfile) {
        _feedback(
          'Paylaşımın güncel durumu doğrulanamadı. Sayfayı yenileyip tekrar dene.',
        );
        return;
      }
      late final DialogRoute<void> dialog;
      bool available() =>
          mounted &&
          identical(_feed, feed) &&
          feed.allowed &&
          identical(feed.sessions.session, expectedSession) &&
          identical(_noteDialog, dialog) &&
          dialog.isCurrent;
      dialog = DialogRoute<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => ListenerEventPostNoteEditor(
          note: current.note,
          onSave: (note) async {
            if (!available() ||
                feed.loading ||
                !feed.rows.any((item) => identical(item, row))) {
              return 'Paylaşım değişmiş. Editörü kapatıp yeniden aç.';
            }
            final normalized = note.isEmpty ? null : note;
            if (normalized == current.note) return null;
            _noteSaving = true;
            try {
              final result = await feed.repository.setIntent(
                eventId: row.event.id,
                intent: current.intent,
                publishedOnProfile: current.publishedOnProfile,
                note: normalized,
                expectedVersion: current.version,
                expectedSessionKey: expectedSession.userId!,
              );
              if (!available()) return 'Paylaşım artık düzenlenemiyor.';
              if (!result.isSuccess ||
                  result.data?.postId != row.postId ||
                  result.data?.note != normalized ||
                  result.data?.intent != current.intent) {
                return 'Açıklama kaydedilemedi. Paylaşım değişmişse editörü kapatıp yeniden aç.';
              }
              return null;
            } finally {
              if (identical(_noteDialog, dialog)) _noteSaving = false;
            }
          },
        ),
      );
      _noteDialog = dialog;
      _noteSession = expectedSession;
      _noteRow = row;
      await Navigator.of(context).push<void>(dialog);
      if (identical(_noteDialog, dialog)) _dismissNoteDialog();
    } catch (_) {
      if (_currentAction(feed, expectedSession)) {
        _feedback('Açıklama açılamadı. Tekrar deneyebilirsin.');
      }
    } finally {
      _finishAction(feed);
    }
  }

  Future<void> _openEvent(
    ListenerEventFeedController feed,
    ListenerEventFeedRow row,
    AuthSession expectedSession,
  ) async {
    if (_opening || !_currentAction(feed, expectedSession, row)) return;
    final event = row.event;
    setState(() => _opening = true);
    try {
      if (widget.onOpenEvent != null) {
        await widget.onOpenEvent!(event);
      } else {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => WeeklyEventDetailScreen(
              event: WeeklyCalendarEvent(
                id: event.id,
                title: event.title ?? 'Etkinlik',
                artistName: event.performerName ?? '',
                artistProfileId: event.musicianProfileId,
                bandProfileId: event.bandId,
                performerType: event.performerType,
                venueName: event.venueName ?? '',
                venueId: event.venueId,
                city: event.venueCity ?? '',
                district: event.venueDistrict ?? '',
                neighborhood: event.venueNeighborhood ?? '',
                eventDate:
                    event.eventDate?.toIso8601String().split('T').first ?? '',
                startTime: event.startTime ?? '',
                endTime: event.endTime ?? '',
                imageAssetPath: event.posterImage,
                description: event.description ?? '',
              ),
            ),
          ),
        );
      }
    } finally {
      _finishAction(feed);
      if (_currentAction(feed, expectedSession)) {
        await feed.reload();
      }
    }
  }

  Future<void> _openAll(
    ListenerEventFeedController feed,
    AuthSession expectedSession,
  ) async {
    if (_opening || !_currentAction(feed, expectedSession)) return;
    final destination = ListenerProfileTheme(
      child: _ListenerEventFeed(
        listenerProfileId: widget.listenerProfileId,
        username: widget.username,
        avatarUrl: widget.avatarUrl,
        ownerUserId: widget.ownerUserId,
        repository: feed.repository,
        sessions: feed.sessions,
        fullPage: true,
        onOpenEvent: widget.onOpenEvent,
      ),
    );
    setState(() => _opening = true);
    try {
      await Navigator.of(
        context,
      ).push<void>(MaterialPageRoute(builder: (_) => destination));
    } finally {
      _finishAction(feed);
      if (_currentAction(feed, expectedSession)) {
        await feed.reload();
      }
    }
  }
}

T? _registered<T extends Object>() =>
    serviceLocator.isRegistered<T>() ? serviceLocator<T>() : null;

class _PlanPeriodChoice extends StatelessWidget {
  const _PlanPeriodChoice({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
  });
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: Container(
      padding: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: selected
            ? LinearGradient(colors: AppColors.brandGradient)
            : null,
        color: selected ? null : const Color(0xFF293447),
      ),
      child: Material(
        color: selected ? const Color(0xFF101722) : const Color(0xFF0B1220),
        borderRadius: BorderRadius.circular(17),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? Colors.white : const Color(0xFFA0A9B6),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
