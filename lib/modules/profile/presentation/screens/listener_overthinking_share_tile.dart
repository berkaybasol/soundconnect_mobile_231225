import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/error/app_error.dart';
import '../../../../shared/widgets/app_snack_bar.dart';
import '../../../engagement/domain/engagement_repository.dart';
import '../../../overthinking/domain/entities/overthinking_post.dart';
import '../../../overthinking/domain/overthinking_profile_share_repository.dart';
import '../../../overthinking/domain/overthinking_repository.dart';
import '../../../overthinking/presentation/screens/overthinking_open_source.dart';
import '../share/overthinking_share_flow.dart';
import 'listener_event_post_comments_sheet.dart';
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
    this.sourceRepository,
    this.onSourceChanged,
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
  final OverthinkingRepository? sourceRepository;
  final ValueChanged<OverthinkingPost>? onSourceChanged;

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
  bool _engagementBusy = false;
  bool _engagementUncertain = false;
  bool _sourceUnavailable = false;
  late OverthinkingPost _post;
  EngagementRepository? _engagement;
  OverthinkingRepository? _sources;
  ValueNotifier<bool>? _commentsAvailable;
  DialogRoute<bool>? _confirmation;

  // Retain pending/uncertain operations when their card leaves the viewport.
  // Once a confirmed source is saved by the parent, idle cards recycle again.
  @override
  bool get wantKeepAlive => _busy || _engagementBusy || _engagementUncertain;

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
    _engagementBusy = false;
    _commentsAvailable?.value = false;
    _dismissConfirmation();
    updateKeepAlive();
  }

  void _bindEngagement() {
    _post = widget.share.post;
    _engagementUncertain = false;
    _sourceUnavailable = false;
    _engagement =
        widget.engagementRepository ??
        (serviceLocator.isRegistered<EngagementRepository>()
            ? serviceLocator<EngagementRepository>()
            : null);
    _sources =
        widget.sourceRepository ??
        (serviceLocator.isRegistered<OverthinkingRepository>()
            ? serviceLocator<OverthinkingRepository>()
            : null);
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
        !identical(oldWidget.sourceRepository, widget.sourceRepository) ||
        oldWidget.ownerUserId != widget.ownerUserId) {
      _invalidate();
      _session = widget.sessions.session;
      _bindEngagement();
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

  Future<void> _toggleLike(_ShareOperation operation) async {
    if (_busy ||
        _engagementBusy ||
        _sourceUnavailable ||
        !_current(operation)) {
      return;
    }
    final engagement = _engagement;
    if (engagement == null || _sources == null) {
      _showError(
        operation,
        'Beğeni şu anda güncellenemiyor. Yeniden deneyebilirsin.',
      );
      return;
    }
    final previous = _post;
    final reconcileOnly = _engagementUncertain;
    _setState(() {
      _engagementBusy = true;
      if (!reconcileOnly) {
        _post = previous.copyWith(
          likedByMe: !previous.likedByMe,
          likeCount: (previous.likeCount + (previous.likedByMe ? -1 : 1)).clamp(
            0,
            9007199254740991,
          ),
        );
      }
    });
    try {
      // An uncertain request may already have reached the server. Reconcile
      // before deciding which direction the user's next toggle should take.
      if (!reconcileOnly) {
        final result = previous.likedByMe
            ? await engagement.unlike(
                targetType: 'OVERTHINKING',
                targetId: previous.id,
              )
            : await engagement.like(
                targetType: 'OVERTHINKING',
                targetId: previous.id,
              );
        if (!_same(operation)) return;
        if (!result.isSuccess) {
          _setState(() {
            _post = previous;
            _engagementUncertain = true;
          });
          if (_isUnavailable(result.error)) {
            await _revokeSource(operation);
          } else {
            _showError(
              operation,
              result.error?.message ??
                  'Beğeni doğrulanamadı. Yenilemek için tekrar dene.',
            );
          }
          return;
        }
      }
      await _refreshSource(operation);
    } catch (_) {
      if (_same(operation)) {
        _setState(() {
          _post = previous;
          _engagementUncertain = true;
        });
        _showError(
          operation,
          'Beğeni doğrulanamadı. Yenilemek için tekrar dene.',
        );
      }
    } finally {
      if (_same(operation)) _setState(() => _engagementBusy = false);
    }
  }

  bool _isUnavailable(AppError? error) =>
      const {'9401', '9700', '1102', '403', '404', '410'}.contains(error?.code);

  Future<void> _revokeSource(_ShareOperation operation) async {
    if (!_same(operation)) return;
    _setState(() => _sourceUnavailable = true);
    _commentsAvailable?.value = false;
    _showError(operation, 'Bu yazı artık görüntülenemiyor.');
    await _refresh(operation);
  }

  Future<void> _refreshSource(_ShareOperation operation) async {
    final sources = _sources;
    if (!_same(operation) || sources == null) return;
    final result = await sources.getDetail(postId: operation.share.post.id);
    if (!_same(operation)) return;
    if (result.isSuccess && result.data?.id == operation.share.post.id) {
      _setState(() {
        _post = result.data!;
        _engagementUncertain = false;
      });
      widget.onSourceChanged?.call(result.data!);
    } else if (_isUnavailable(result.error)) {
      await _revokeSource(operation);
    } else {
      _setState(() => _engagementUncertain = true);
      _showError(
        operation,
        'Etkileşimler doğrulanamadı. Yenilemek için beğeniye tekrar dokunabilirsin.',
      );
    }
  }

  Future<void> _openComments(_ShareOperation operation) async {
    if (_busy ||
        _engagementBusy ||
        _sourceUnavailable ||
        !_current(operation)) {
      return;
    }
    final engagement = _engagement;
    if (engagement == null || _sources == null) {
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
          postId: operation.share.post.id,
          repository: engagement,
          sessions: operation.sessions,
          expectedSession: operation.session,
          publicationAvailable: availability,
        ),
      );
      if (_current(operation)) {
        // Source DTO counts include replies. A root-comments page total is not
        // the source's commentCount, and reloading the feed would jump scroll.
        await _refreshSource(operation);
      }
    } catch (_) {
      if (_same(operation)) _setState(() => _engagementUncertain = true);
      _showError(operation, 'Yorumlar doğrulanamadı. Yeniden deneyebilirsin.');
    } finally {
      if (identical(_commentsAvailable, availability)) {
        _commentsAvailable = null;
      }
      availability.dispose();
      if (_same(operation)) _setState(() => _busy = false);
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
    if (!_allowed || _sourceUnavailable) return const SizedBox.shrink();
    final operation = _capture();
    return KeyedSubtree(
      // PopupMenuButton resolves onSelected from its latest widget after the
      // overlay closes. Recreate its state for a fresh projection so an old
      // open menu cannot silently acquire the replacement row's callbacks.
      key: ValueKey(_generation),
      child: ListenerOverthinkingShareCard(
        share: OverthinkingProfileShare(
          shareId: widget.share.shareId,
          note: widget.share.note,
          publishedAt: widget.share.publishedAt,
          post: _post,
        ),
        username: widget.username,
        avatarUrl: widget.avatarUrl,
        busy: _busy || _engagementBusy,
        likeBusy: _engagementBusy,
        engagementUnknown: _engagementUncertain,
        isCurrent: () => _current(operation),
        onOpen: _busy ? null : () => unawaited(_open(operation)),
        onRemove: _owner ? () => unawaited(_remove(operation)) : null,
        onShare: () => unawaited(_share(operation)),
        onLike: () => unawaited(_toggleLike(operation)),
        onComments: () => unawaited(_openComments(operation)),
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
