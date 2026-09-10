import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../shared/widgets/app_snack_bar.dart';
import '../../../overthinking/domain/overthinking_profile_share_repository.dart';
import '../../../overthinking/presentation/screens/overthinking_open_source.dart';
import '../share/overthinking_share_flow.dart';
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

  /// Parent-scoped feedback for a mutation whose repository invalidation has
  /// already removed this tile. Must fence the profile and viewer session.
  final ValueChanged<String>? onError;

  @override
  State<ListenerOverthinkingShareTile> createState() =>
      _ListenerOverthinkingShareTileState();
}

class _ListenerOverthinkingShareTileState
    extends State<ListenerOverthinkingShareTile> {
  late AuthSession _session;
  int _generation = 0;
  final _shareValidity = ValueNotifier<int>(0);
  bool _busy = false;
  DialogRoute<bool>? _confirmation;

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
    widget.sessions.addListener(_sessionChanged);
  }

  void _invalidate() {
    ++_generation;
    _shareValidity.value = _generation;
    _busy = false;
    _dismissConfirmation();
  }

  void _sessionChanged() {
    if (identical(widget.sessions.session, _session)) return;
    // Keep the old session fence until the parent supplies a fresh row. An
    // account or token change cannot reuse the previous viewer's projection.
    _invalidate();
    if (mounted) setState(() {});
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
        oldWidget.ownerUserId != widget.ownerUserId) {
      _invalidate();
      _session = widget.sessions.session;
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
    if (_busy || !_current(operation)) return;
    setState(() => _busy = true);
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
      if (_same(operation)) setState(() => _busy = false);
      await _refresh(operation);
    }
  }

  Future<void> _remove(_ShareOperation operation) async {
    if (!_owner || _busy || !_current(operation)) return;
    final parentError = widget.onError;
    final profileRoute = ModalRoute.of(context);
    setState(() => _busy = true);
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
      if (_same(operation)) setState(() => _busy = false);
      if (attempted) await _refresh(operation);
    }
  }

  Future<void> _share(_ShareOperation operation) async {
    if (_busy || !_current(operation)) return;
    final revision = operation.repository.changes.value;
    setState(() => _busy = true);
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
      if (_same(operation)) setState(() => _busy = false);
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
    if (!_allowed) return const SizedBox.shrink();
    final operation = _capture();
    return KeyedSubtree(
      // PopupMenuButton resolves onSelected from its latest widget after the
      // overlay closes. Recreate its state for a fresh projection so an old
      // open menu cannot silently acquire the replacement row's callbacks.
      key: ValueKey(_generation),
      child: ListenerOverthinkingShareCard(
        share: widget.share,
        username: widget.username,
        avatarUrl: widget.avatarUrl,
        busy: _busy,
        isCurrent: () => _current(operation),
        onOpen: _busy ? null : () => unawaited(_open(operation)),
        onRemove: _owner ? () => unawaited(_remove(operation)) : null,
        onShare: () => unawaited(_share(operation)),
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
