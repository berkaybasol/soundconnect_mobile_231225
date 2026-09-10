import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/auth/listener_profile_publication_access.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/policy/stage_mode.dart';
import '../../../../shared/widgets/app_snack_bar.dart';
import '../../../engagement/domain/engagement_repository.dart';
import '../../../engagement/presentation/cubit/interaction_stats_state.dart';
import '../../../tablegroup/domain/table_group_profile_share_repository.dart';
import '../../../tablegroup/presentation/screens/table_group_detail_screen.dart';
import 'listener_event_post_comments_sheet.dart';
import 'listener_event_post_engagement.dart';
import 'listener_share_delete_dialog.dart';
import 'listener_table_group_share_card.dart';

class ListenerTableGroupShareTile extends StatefulWidget {
  const ListenerTableGroupShareTile({
    super.key,
    required this.share,
    required this.username,
    this.avatarUrl,
    this.ownerUserId,
    required this.repository,
    required this.sessions,
    required this.isCurrent,
    required this.onRefresh,
    this.onSourceRefresh,
    required this.onRemoved,
    this.onOpenSource,
    this.onError,
    this.engagementRepository,
    this.onEngagementChanged,
    this.now,
  });

  final TableGroupProfileShare share;
  final String username;
  final String? avatarUrl;
  final String? ownerUserId;
  final TableGroupProfileShareRepository repository;
  final AuthSessionManager sessions;
  final bool Function() isCurrent;
  final Future<void> Function() onRefresh;
  final Future<void> Function()? onSourceRefresh;
  final ValueChanged<String> onRemoved;
  final Future<void> Function(String tableGroupId)? onOpenSource;
  final ValueChanged<String>? onError;
  final EngagementRepository? engagementRepository;
  final ValueChanged<InteractionStatsItemState>? onEngagementChanged;
  final DateTime Function()? now;

  @override
  State<ListenerTableGroupShareTile> createState() =>
      _ListenerTableGroupShareTileState();
}

class _ListenerTableGroupShareTileState
    extends State<ListenerTableGroupShareTile>
    with AutomaticKeepAliveClientMixin {
  late AuthSession _session;
  EngagementRepository? _engagement;
  int _generation = 0;
  bool _busy = false;
  bool _retainEngagement = false;
  bool _engagementBusy = false;
  InteractionStatsItemState? _reportedStats;
  late InteractionStatsItemState _initialStats;
  Timer? _expiryTimer;
  bool _requestedFinalSnapshot = false;
  ValueNotifier<bool>? _commentsAvailable;
  ModalRoute<dynamic>? _commentsRoute;
  DialogRoute<bool>? _confirmation;

  @override
  bool get wantKeepAlive => _busy || _retainEngagement;

  bool get _allowed =>
      _session.isAuthenticated &&
      _session.isActive &&
      _session.userId?.trim().isNotEmpty == true &&
      !_session.requiresListenerProfileChoice &&
      identical(widget.sessions.session, _session);

  DateTime get _now => (widget.now ?? DateTime.now)();

  bool get _active => widget.share.tableGroup.isActiveAt(_now);

  bool get _owner =>
      widget.ownerUserId == _session.userId &&
      canPublishListenerProfile(_session);

  @override
  void initState() {
    super.initState();
    _session = widget.sessions.session;
    _bind();
    widget.sessions.addListener(_sessionChanged);
    widget.repository.changes.addListener(_publicationChanged);
  }

  void _bind() {
    _engagement =
        widget.engagementRepository ??
        (serviceLocator.isRegistered<EngagementRepository>()
            ? serviceLocator<EngagementRepository>()
            : null);
    _retainEngagement = false;
    _engagementBusy = false;
    _reportedStats = null;
    _initialStats = _projectionStats();
    _requestedFinalSnapshot = false;
    _scheduleExpiry();
  }

  InteractionStatsItemState _projectionStats() => InteractionStatsItemState(
    loading: false,
    likeCount: widget.share.likeCount,
    commentCount: widget.share.commentCount,
    isLiked: widget.share.likedByMe,
  );

  void _scheduleExpiry() {
    _expiryTimer?.cancel();
    final expiresAt = widget.share.tableGroup.expiresAt;
    if (_active && expiresAt != null) {
      _expiryTimer = Timer(expiresAt.difference(_now), () {
        if (!mounted) return;
        setState(() {});
        _requestFinalSnapshot();
      });
    } else if (widget.share.tableGroup.needsFinalSnapshotAt(_now)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _requestFinalSnapshot();
      });
    }
  }

  void _requestFinalSnapshot() {
    if (_requestedFinalSnapshot ||
        !_allowed ||
        !widget.isCurrent() ||
        (ModalRoute.of(context)?.isCurrent != true &&
            !(_commentsAvailable?.value == true &&
                _commentsRoute?.isCurrent == true))) {
      return;
    }
    _requestedFinalSnapshot = true;
    unawaited(_refreshExpired(_session));
  }

  Future<void> _refreshExpired(AuthSession session) async {
    if (!mounted || !identical(widget.sessions.session, session)) return;
    try {
      await (widget.onSourceRefresh ?? widget.onRefresh)();
    } catch (_) {
      // The publication and its conversation remain available. The parent's
      // next live, foreground or explicit refresh retries the final snapshot.
    }
  }

  void _setState(VoidCallback update) {
    setState(update);
    updateKeepAlive();
  }

  void _invalidate() {
    ++_generation;
    _busy = false;
    _retainEngagement = false;
    _engagementBusy = false;
    _reportedStats = null;
    _commentsAvailable?.value = false;
    _dismissConfirmation();
    updateKeepAlive();
  }

  void _sessionChanged() {
    if (identical(_session, widget.sessions.session)) return;
    _invalidate();
    if (mounted) setState(() {});
  }

  void _publicationChanged() {
    // Invalidation can precede the replacement page. A thread cannot keep
    // accepting input based on a projection that is being revalidated.
    _commentsAvailable?.value = false;
    _dismissConfirmation();
  }

  @override
  void didUpdateWidget(ListenerTableGroupShareTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.sessions, widget.sessions)) {
      oldWidget.sessions.removeListener(_sessionChanged);
      widget.sessions.addListener(_sessionChanged);
    }
    if (!identical(oldWidget.repository, widget.repository)) {
      oldWidget.repository.changes.removeListener(_publicationChanged);
      widget.repository.changes.addListener(_publicationChanged);
    }
    if (!_samePublication(oldWidget.share, widget.share) ||
        !identical(oldWidget.repository, widget.repository) ||
        !identical(oldWidget.sessions, widget.sessions) ||
        !identical(
          oldWidget.engagementRepository,
          widget.engagementRepository,
        ) ||
        oldWidget.ownerUserId != widget.ownerUserId) {
      _invalidate();
      _session = widget.sessions.session;
      _bind();
    } else {
      // A live count or final snapshot does not create another publication.
      // Keep an open comment draft and a pending like bound to their original
      // share while accepting fresh source details from the profile feed.
      if (!_engagementBusy && !_retainEngagement) {
        _initialStats = _projectionStats();
      }
      _scheduleExpiry();
      if (!widget.isCurrent()) _publicationChanged();
    }
  }

  _TableShareOperation _capture() => _TableShareOperation(
    _generation,
    _session,
    widget.sessions,
    widget.repository,
    widget.share,
  );

  bool _same(_TableShareOperation operation) =>
      mounted &&
      operation.generation == _generation &&
      identical(operation.session, _session) &&
      identical(operation.sessions, widget.sessions) &&
      identical(operation.repository, widget.repository) &&
      _samePublication(operation.share, widget.share) &&
      _allowed;

  bool _samePublication(
    TableGroupProfileShare first,
    TableGroupProfileShare second,
  ) =>
      first.shareId == second.shareId &&
      first.tableGroup.id == second.tableGroup.id &&
      first.publishedAt == second.publishedAt &&
      first.note == second.note;

  bool _current(_TableShareOperation operation) =>
      _same(operation) &&
      widget.isCurrent() &&
      ModalRoute.of(context)?.isCurrent == true;

  Future<void> _share(_TableShareOperation operation) async {
    if (_busy || _engagementBusy || !_current(operation)) return;
    _setState(() => _busy = true);
    try {
      // Replace the placeholder once canonical public table links are ready.
      await Clipboard.setData(const ClipboardData(text: 'Buraya link gelecek'));
      if (!mounted || !_current(operation)) return;
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          appSnackBar(
            context,
            tone: AppSnackBarTone.success,
            duration: const Duration(seconds: 2),
            content: const Text('Kopyalandı'),
          ),
        );
    } catch (_) {
      _showError(operation, 'Kopyalanamadı. Yeniden deneyebilirsin.');
    } finally {
      if (_same(operation)) _setState(() => _busy = false);
    }
  }

  Future<void> _open(_TableShareOperation operation) async {
    if (_busy || _engagementBusy || !_active || !_current(operation)) return;
    _setState(() => _busy = true);
    try {
      if (widget.onOpenSource case final open?) {
        await open(operation.share.tableGroup.id);
      } else {
        await Navigator.of(context).pushNamed<void>(
          AppRoutes.tableGroupDetail,
          arguments: TableGroupDetailArgs(
            tableGroupId: operation.share.tableGroup.id,
            openChat: false,
            bottomBarStageMode: StageModeResolver.fromRoles(
              operation.session.roles,
            ),
          ),
        );
      }
    } catch (_) {
      _showError(operation, 'Masa açılamadı. Yeniden deneyebilirsin.');
    } finally {
      if (_same(operation)) _setState(() => _busy = false);
      await _refresh(operation);
    }
  }

  Future<void> _comments(_TableShareOperation operation) async {
    if (_busy || _engagementBusy || !_current(operation)) return;
    final engagement = _engagement;
    if (engagement == null) return;
    _setState(() => _busy = true);
    final availability = ValueNotifier<bool>(true);
    _commentsAvailable = availability;
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
        builder: (sheetContext) {
          _commentsRoute = ModalRoute.of(sheetContext);
          return ListenerEventPostCommentsSheet.tableGroup(
            postId: operation.share.shareId,
            repository: engagement,
            sessions: operation.sessions,
            expectedSession: operation.session,
            publicationAvailable: availability,
          );
        },
      );
    } catch (_) {
      _showError(operation, 'Yorumlar açılamadı. Yeniden deneyebilirsin.');
    } finally {
      if (identical(_commentsAvailable, availability)) {
        _commentsAvailable = null;
        _commentsRoute = null;
      }
      availability.dispose();
      if (_same(operation)) _setState(() => _busy = false);
      // The public projection includes replies in its comment count. A root
      // comment page is not an authoritative replacement for that count.
      await _refresh(operation);
    }
  }

  Future<void> _remove(_TableShareOperation operation) async {
    if (!_owner || _busy || _engagementBusy || !_current(operation)) return;
    final onError = widget.onError;
    final route = ModalRoute.of(context);
    _setState(() => _busy = true);
    final dialog = DialogRoute<bool>(
      context: context,
      builder: (_) => const ListenerShareDeleteDialog.tableGroup(
        confirmKey: Key('listener-table-group-remove-confirm'),
      ),
    );
    _confirmation = dialog;
    var attempted = false;
    try {
      final confirmed = await Navigator.of(context).push<bool>(dialog);
      if (identical(_confirmation, dialog)) _confirmation = null;
      if (confirmed != true || !_current(operation) || !_owner) return;
      attempted = true;
      final result = await operation.repository.deleteShare(
        shareId: operation.share.shareId,
        expectedSession: operation.session,
      );
      if (result.isSuccess) {
        if (_current(operation) && _owner) {
          widget.onRemoved(operation.share.shareId);
        }
      } else {
        _mutationError(
          operation,
          result.error?.message ?? 'Paylaşım kaldırılamadı.',
          onError,
          route,
        );
      }
    } catch (_) {
      _mutationError(
        operation,
        'Paylaşım kaldırılamadı. Yeniden deneyebilirsin.',
        attempted ? onError : null,
        route,
      );
    } finally {
      if (identical(_confirmation, dialog)) _dismissConfirmation();
      if (_same(operation)) _setState(() => _busy = false);
      if (attempted) await _refresh(operation);
    }
  }

  Future<void> _refresh(_TableShareOperation operation) async {
    if (!_same(operation) ||
        !widget.isCurrent() ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    try {
      await widget.onRefresh();
    } catch (_) {
      _showError(
        operation,
        'Paylaşımlar yenilenemedi. Yeniden deneyebilirsin.',
      );
    }
  }

  void _showError(_TableShareOperation operation, String message) {
    if (!_current(operation)) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      appSnackBar(context, tone: AppSnackBarTone.error, content: Text(message)),
    );
  }

  void _mutationError(
    _TableShareOperation operation,
    String message,
    ValueChanged<String>? parentError,
    ModalRoute<dynamic>? route,
  ) {
    if (_current(operation)) {
      _showError(operation, message);
    } else if (identical(operation.sessions.session, operation.session) &&
        (!mounted ||
            (identical(operation.sessions, widget.sessions) &&
                identical(operation.repository, widget.repository))) &&
        route?.isCurrent == true) {
      parentError?.call(message);
    }
  }

  void _dismissConfirmation() {
    final dialog = _confirmation;
    _confirmation = null;
    if (dialog == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (dialog.isActive) dialog.navigator?.removeRoute(dialog);
    });
  }

  void _retainStats(
    InteractionStatsItemState stats,
    _TableShareOperation operation,
  ) {
    _engagementBusy = stats.loading;
    final retain =
        stats.loading ||
        stats.error != null ||
        stats.likeCount != widget.share.likeCount ||
        stats.isLiked != widget.share.likedByMe;
    if (retain != _retainEngagement) {
      _retainEngagement = retain;
      // The engagement builder runs while Flutter is building its descendant.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) updateKeepAlive();
      });
    }
    if (!retain ||
        stats.loading ||
        stats.error != null ||
        widget.onEngagementChanged == null ||
        (_reportedStats?.likeCount == stats.likeCount &&
            _reportedStats?.isLiked == stats.isLiked)) {
      return;
    }
    _reportedStats = stats;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_same(operation) || !widget.isCurrent()) return;
      // Preserve the reply-inclusive count from the public batch projection.
      // Persist confirmed likes in the feed so idle lazy tiles recycle again.
      widget.onEngagementChanged?.call(
        stats.copyWith(
          commentCount: widget.share.commentCount,
          hasCommentCount: true,
        ),
      );
    });
  }

  Widget _card(
    _TableShareOperation operation,
    InteractionStatsItemState stats,
    VoidCallback? onLike,
  ) {
    return ListenerTableGroupShareCard(
      share: operation.share,
      username: widget.username,
      avatarUrl: widget.avatarUrl,
      busy: _busy,
      likeBusy: stats.loading,
      likeCount: stats.visibleLikeCount,
      commentCount: stats.error == null ? operation.share.commentCount : null,
      isLiked: stats.error == null && stats.isLiked,
      now: _now,
      isCurrent: () => _current(operation),
      onOpen: _active ? () => unawaited(_open(operation)) : null,
      onRemove: _owner ? () => unawaited(_remove(operation)) : null,
      onLike: onLike,
      onShare: () => unawaited(_share(operation)),
      onComments: _engagement == null
          ? null
          : () => unawaited(_comments(operation)),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (!_allowed) return const SizedBox.shrink();
    final operation = _capture();
    final engagement = _engagement;
    return KeyedSubtree(
      key: ValueKey(_generation),
      child: engagement == null
          ? _card(operation, _initialStats, null)
          : ListenerEventPostEngagement(
              targetType: 'TABLE_GROUP_POST',
              postId: operation.share.shareId,
              repository: engagement,
              sessions: operation.sessions,
              projectionKey: _generation,
              initialStats: _initialStats,
              canInteract: () => !_busy && _current(operation),
              onError: (message) => _showError(operation, message),
              builder: (stats, onLike, refresh) {
                _retainStats(stats, operation);
                return _card(operation, stats, onLike);
              },
            ),
    );
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    _invalidate();
    widget.sessions.removeListener(_sessionChanged);
    widget.repository.changes.removeListener(_publicationChanged);
    super.dispose();
  }
}

class _TableShareOperation {
  const _TableShareOperation(
    this.generation,
    this.session,
    this.sessions,
    this.repository,
    this.share,
  );
  final int generation;
  final AuthSession session;
  final AuthSessionManager sessions;
  final TableGroupProfileShareRepository repository;
  final TableGroupProfileShare share;
}
