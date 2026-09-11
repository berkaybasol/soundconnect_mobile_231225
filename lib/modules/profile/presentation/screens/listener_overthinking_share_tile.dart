import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/error/app_error.dart';
import '../../../../shared/widgets/app_snack_bar.dart';
import '../../../engagement/domain/engagement_repository.dart';
import '../../../engagement/presentation/cubit/interaction_stats_state.dart';
import '../../../overthinking/domain/overthinking_profile_share_repository.dart';
import '../../../overthinking/presentation/screens/overthinking_open_source.dart';
import '../share/overthinking_share_flow.dart';
import 'listener_event_post_comments_sheet.dart';
import 'listener_event_post_engagement.dart';
import 'listener_overthinking_share_card.dart';
import 'listener_share_delete_dialog.dart';

/// Actions for one authoritative row in the listener's mixed profile feed.
/// Loading and ordering belong to the parent, so a tile never fetches a list.
class ListenerOverthinkingShareTile extends StatefulWidget {
  const ListenerOverthinkingShareTile({
    super.key,
    required this.share,
    required this.username,
    this.avatarUrl,
    this.ownerUserId,
    required this.repository,
    required this.sessions,
    required this.isCurrent,
    required this.onRefresh,
    required this.onRemoved,
    this.onOpenSource,
    this.onError,
    this.engagementRepository,
    this.onEngagementChanged,
  });

  final OverthinkingProfileShare share;
  final String username;
  final String? avatarUrl;
  final String? ownerUserId;
  final OverthinkingProfileShareRepository repository;
  final AuthSessionManager sessions;
  final bool Function() isCurrent;
  final Future<void> Function() onRefresh;
  final ValueChanged<String> onRemoved;
  final Future<void> Function(String postId)? onOpenSource;
  final EngagementRepository? engagementRepository;
  final ValueChanged<InteractionStatsItemState>? onEngagementChanged;

  /// Parent-scoped feedback for a mutation whose repository invalidation has
  /// already removed this tile. Must fence the profile and viewer session.
  final ValueChanged<String>? onError;

  @override
  State<ListenerOverthinkingShareTile> createState() =>
      _ListenerOverthinkingShareTileState();
}

class _ListenerOverthinkingShareTileState
    extends State<ListenerOverthinkingShareTile>
    with AutomaticKeepAliveClientMixin {
  late AuthSession _session;
  int _generation = 0;
  final _shareValidity = ValueNotifier<int>(0);
  bool _busy = false;
  bool _retainEngagement = false;
  bool _engagementBusy = false;
  bool _publicationUnavailable = false;
  InteractionStatsItemState? _reportedStats;
  late InteractionStatsItemState _initialStats;
  EngagementRepository? _engagement;
  ValueNotifier<bool>? _commentsAvailable;
  DialogRoute<bool>? _confirmation;

  // Retain pending/uncertain operations when their card leaves the viewport.
  // Once confirmed wrapper stats are saved by the parent, idle cards recycle.
  @override
  bool get wantKeepAlive => _busy || _retainEngagement;

  void _setState(VoidCallback change) {
    setState(change);
    updateKeepAlive();
  }

  bool get _allowed =>
      _session.isAuthenticated &&
      _session.isActive &&
      !_session.requiresListenerProfileChoice &&
      identical(widget.sessions.session, _session);

  bool get _owner =>
      widget.ownerUserId == _session.userId &&
      canShareOverthinkingOnProfile(_session);

  @override
  void initState() {
    super.initState();
    _session = widget.sessions.session;
    _bindEngagement();
    widget.sessions.addListener(_sessionChanged);
  }

  void _invalidate() {
    ++_generation;
    _shareValidity.value = _generation;
    _busy = false;
    _retainEngagement = false;
    _engagementBusy = false;
    _publicationUnavailable = false;
    _reportedStats = null;
    _commentsAvailable?.value = false;
    _dismissConfirmation();
    updateKeepAlive();
  }

  void _bindEngagement() {
    _engagement =
        widget.engagementRepository ??
        (serviceLocator.isRegistered<EngagementRepository>()
            ? serviceLocator<EngagementRepository>()
            : null);
    _retainEngagement = false;
    _engagementBusy = false;
    _publicationUnavailable = false;
    _reportedStats = null;
    _initialStats = InteractionStatsItemState(
      loading: false,
      likeCount: widget.share.likeCount,
      commentCount: widget.share.commentCount,
      isLiked: widget.share.likedByMe,
    );
  }

  void _sessionChanged() {
    if (identical(widget.sessions.session, _session)) return;
    // Keep the old session fence until the parent supplies a fresh row. An
    // account or token change cannot reuse the previous viewer's projection.
    _invalidate();
    if (mounted) _setState(() {});
  }

  @override
  void didUpdateWidget(ListenerOverthinkingShareTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.sessions, widget.sessions)) {
      oldWidget.sessions.removeListener(_sessionChanged);
      widget.sessions.addListener(_sessionChanged);
    }
    if (!identical(oldWidget.share, widget.share) ||
        !identical(oldWidget.repository, widget.repository) ||
        !identical(oldWidget.sessions, widget.sessions) ||
        !identical(
          oldWidget.engagementRepository,
          widget.engagementRepository,
        ) ||
        oldWidget.ownerUserId != widget.ownerUserId) {
      final preserveUnavailable =
          _publicationUnavailable &&
          oldWidget.share.shareId == widget.share.shareId &&
          oldWidget.share.post.id == widget.share.post.id &&
          oldWidget.share.publishedAt == widget.share.publishedAt;
      _invalidate();
      _session = widget.sessions.session;
      _bindEngagement();
      _publicationUnavailable = preserveUnavailable;
    }
  }

  bool _same(_ShareOperation operation) =>
      mounted &&
      operation.generation == _generation &&
      identical(operation.session, _session) &&
      identical(operation.sessions, widget.sessions) &&
      identical(operation.repository, widget.repository) &&
      identical(operation.share, widget.share) &&
      _allowed;

  bool _current(_ShareOperation operation) =>
      _same(operation) &&
      ModalRoute.of(context)?.isCurrent == true &&
      widget.isCurrent();

  _ShareOperation _capture() => _ShareOperation(
    generation: _generation,
    session: _session,
    sessions: widget.sessions,
    repository: widget.repository,
    share: widget.share,
  );

  Future<void> _open(_ShareOperation operation) async {
    if (_busy || _engagementBusy || !_current(operation)) return;
    _setState(() => _busy = true);
    try {
      if (widget.onOpenSource case final open?) {
        await open(operation.share.post.id);
      } else {
        await openOverthinkingSource(
          context,
          operation.share.post.id,
          isCurrent: () => _current(operation),
        );
      }
    } catch (_) {
      _showError(operation, 'Yazı açılamadı. Yeniden deneyebilirsin.');
    } finally {
      if (_same(operation)) _setState(() => _busy = false);
      await _refresh(operation);
    }
  }

  Future<void> _openComments(_ShareOperation operation) async {
    if (_busy || _engagementBusy || !_current(operation)) {
      return;
    }
    final engagement = _engagement;
    if (engagement == null) {
      _showError(
        operation,
        'Yorumlar şu anda açılamıyor. Yeniden deneyebilirsin.',
      );
      return;
    }
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
        builder: (_) => ListenerEventPostCommentsSheet.overthinking(
          postId: operation.share.shareId,
          repository: engagement,
          sessions: operation.sessions,
          expectedSession: operation.session,
          publicationAvailable: availability,
        ),
      );
    } catch (_) {
      _showError(operation, 'Yorumlar doğrulanamadı. Yeniden deneyebilirsin.');
    } finally {
      if (identical(_commentsAvailable, availability)) {
        _commentsAvailable = null;
      }
      availability.dispose();
      if (_same(operation)) _setState(() => _busy = false);
      // The profile projection counts both roots and replies; the comments
      // page total only counts roots, so refresh the authoritative batch row.
      await _refresh(operation);
    }
  }

  Future<void> _remove(_ShareOperation operation) async {
    if (!_owner || _busy || _engagementBusy || !_current(operation)) return;
    final parentError = widget.onError;
    final profileRoute = ModalRoute.of(context);
    _setState(() => _busy = true);
    final dialog = DialogRoute<bool>(
      context: context,
      builder: (_) => const ListenerShareDeleteDialog.overthinking(
        confirmKey: Key('listener-overthinking-remove-confirm'),
      ),
    );
    _confirmation = dialog;
    var attempted = false;
    try {
      final confirmed = await Navigator.of(context).push<bool>(dialog);
      if (identical(_confirmation, dialog)) _confirmation = null;
      // The profile route is covered while the dialog is visible. Validate
      // current-route and parent privacy fences after the dialog returns.
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
        _showMutationError(
          operation,
          result.error?.message ?? 'Paylaşım kaldırılamadı.',
          parentError: parentError,
          profileRoute: profileRoute,
        );
      }
    } catch (_) {
      _showMutationError(
        operation,
        'Paylaşım kaldırılamadı. Yeniden deneyebilirsin.',
        parentError: attempted ? parentError : null,
        profileRoute: profileRoute,
      );
    } finally {
      if (identical(_confirmation, dialog)) _dismissConfirmation();
      if (_same(operation)) _setState(() => _busy = false);
      if (attempted) await _refresh(operation);
    }
  }

  Future<void> _share(_ShareOperation operation) async {
    if (_busy || _engagementBusy || !_current(operation)) return;
    final revision = operation.repository.changes.value;
    _setState(() => _busy = true);
    try {
      await shareOverthinkingPost(
        context,
        postId: operation.share.post.id,
        sessions: operation.sessions,
        expectedSession: operation.session,
        validityChanges: Listenable.merge([
          operation.repository.changes,
          _shareValidity,
        ]),
        isValid: () =>
            _same(operation) && operation.repository.changes.value == revision,
      );
    } finally {
      if (_same(operation)) _setState(() => _busy = false);
    }
  }

  Future<void> _refresh(_ShareOperation operation) async {
    if (!_current(operation)) return;
    try {
      await widget.onRefresh();
    } catch (_) {
      _showError(
        operation,
        'Paylaşımlar yenilenemedi. Yeniden deneyebilirsin.',
      );
    }
  }

  void _showError(_ShareOperation operation, String message) {
    if (!_current(operation)) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      appSnackBar(context, tone: AppSnackBarTone.error, content: Text(message)),
    );
  }

  void _engagementFailure(_ShareOperation operation, AppError error) {
    if (!_same(operation) ||
        !const {'9700', '1102', '403', '404', '410'}.contains(error.code)) {
      return;
    }
    _setState(() => _publicationUnavailable = true);
    _commentsAvailable?.value = false;
    unawaited(_refresh(operation));
  }

  void _showMutationError(
    _ShareOperation operation,
    String message, {
    required ValueChanged<String>? parentError,
    required ModalRoute<dynamic>? profileRoute,
  }) {
    if (_current(operation)) {
      _showError(operation, message);
      return;
    }
    // Every write invalidates the feed, including an uncertain/failed write.
    // Let the still-current parent report its result after this row is gone.
    if (identical(operation.sessions.session, operation.session) &&
        (!mounted ||
            (identical(operation.sessions, widget.sessions) &&
                identical(operation.repository, widget.repository))) &&
        profileRoute?.isCurrent == true) {
      parentError?.call(message);
    }
  }

  void _dismissConfirmation() {
    final dialog = _confirmation;
    _confirmation = null;
    if (dialog == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Remove this exact overlay even if another route now covers it.
      if (dialog.isActive) dialog.navigator?.removeRoute(dialog);
    });
  }

  void _retainStats(
    InteractionStatsItemState stats,
    _ShareOperation operation,
  ) {
    _engagementBusy = stats.loading;
    final changed =
        stats.likeCount != widget.share.likeCount ||
        stats.isLiked != widget.share.likedByMe;
    final retain =
        stats.loading ||
        stats.error != null ||
        (changed && widget.onEngagementChanged != null);
    if (retain != _retainEngagement) {
      _retainEngagement = retain;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) updateKeepAlive();
      });
    }
    if (!changed ||
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
      // The batched profile projection includes replies. A like refresh reads
      // only the root page total, so never replace that authoritative count.
      widget.onEngagementChanged?.call(
        stats.copyWith(
          commentCount: widget.share.commentCount,
          hasCommentCount: true,
        ),
      );
    });
  }

  Widget _card(
    _ShareOperation operation,
    InteractionStatsItemState stats,
    VoidCallback? onLike,
  ) {
    final projected = operation.share.copyWithEngagement(
      likeCount: stats.likeCount,
      commentCount: operation.share.commentCount,
      likedByMe: stats.error == null && stats.isLiked,
    );
    return ListenerOverthinkingShareCard(
      share: projected,
      username: widget.username,
      avatarUrl: widget.avatarUrl,
      busy: _busy,
      likeBusy: stats.loading,
      engagementUnknown:
          stats.error != null || !stats.hasLikeCount || !stats.hasCommentCount,
      isCurrent: () => _current(operation),
      onOpen: _busy ? null : () => unawaited(_open(operation)),
      onRemove: _owner ? () => unawaited(_remove(operation)) : null,
      onShare: () => unawaited(_share(operation)),
      onLike: onLike,
      onComments: _engagement == null
          ? null
          : () => unawaited(_openComments(operation)),
    );
  }

  @override
  void dispose() {
    _invalidate();
    _shareValidity.dispose();
    widget.sessions.removeListener(_sessionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (!_allowed || _publicationUnavailable) return const SizedBox.shrink();
    final operation = _capture();
    final engagement = _engagement;
    return KeyedSubtree(
      // PopupMenuButton resolves onSelected from its latest widget after the
      // overlay closes. Recreate its state for a fresh projection so an old
      // open menu cannot silently acquire the replacement row's callbacks.
      key: ValueKey(_generation),
      child: engagement == null
          ? _card(operation, _initialStats, null)
          : ListenerEventPostEngagement(
              targetType: 'OVERTHINKING_PROFILE_SHARE',
              postId: operation.share.shareId,
              repository: engagement,
              sessions: operation.sessions,
              projectionKey: _generation,
              initialStats: _initialStats,
              canInteract: () => !_busy && _current(operation),
              onError: (message) => _showError(operation, message),
              onFailure: (error) => _engagementFailure(operation, error),
              builder: (stats, onLike, refresh) {
                _retainStats(stats, operation);
                return _card(operation, stats, onLike);
              },
            ),
    );
  }
}

class _ShareOperation {
  const _ShareOperation({
    required this.generation,
    required this.session,
    required this.sessions,
    required this.repository,
    required this.share,
  });

  final int generation;
  final AuthSession session;
  final AuthSessionManager sessions;
  final OverthinkingProfileShareRepository repository;
  final OverthinkingProfileShare share;
}
