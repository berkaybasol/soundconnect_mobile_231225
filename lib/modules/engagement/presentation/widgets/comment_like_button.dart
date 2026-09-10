import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/app_snack_bar.dart';
import '../../domain/engagement_repository.dart';
import '../../domain/entities/comment_item.dart';
import '../../domain/entities/comment_like_state.dart';
import 'comment_like_memory.dart';

/// Counts arrive with the paged comment payload. No per-row reads on mount.
/// Writes set an explicit desired state; an uncertain result is read back,
/// never blindly toggled/reposted. Every completion belongs to its row/session.
class CommentLikeButton extends StatefulWidget {
  const CommentLikeButton({
    super.key,
    required this.comment,
    required this.isCurrent,
    this.sessions,
    this.repository,
    this.compact = false,
    this.enabled = true,
    this.memory,
  });

  final CommentItem comment;
  final bool Function() isCurrent;
  final AuthSessionManager? sessions;
  final EngagementRepository? repository;
  final bool compact;
  final bool enabled;
  final CommentLikeMemory? memory;

  @override
  State<CommentLikeButton> createState() => _CommentLikeButtonState();
}

class _CommentLikeButtonState extends State<CommentLikeButton> {
  AuthSessionManager? _sessions;
  final _localMemory = CommentLikeMemory();
  CommentLikeRecord? _record;
  CommentLikeMemory get _memory => widget.memory ?? _localMemory;
  CommentLikeState get _value => _record!.value;
  bool get _busy => _record!.busy;
  bool get _uncertain => _record!.uncertain;
  int _generation = 0;

  EngagementRepository get _repository =>
      widget.repository ?? serviceLocator<EngagementRepository>();
  bool get _allowed =>
      _sessions?.session.isAuthenticated == true &&
      _sessions?.session.isActive == true &&
      _sessions?.session.requiresListenerProfileChoice != true &&
      _sessions?.session.userId?.trim().isNotEmpty == true;

  AuthSessionManager? _resolveSessions() =>
      widget.sessions ??
      (serviceLocator.isRegistered<AuthSessionManager>()
          ? serviceLocator<AuthSessionManager>()
          : null);

  void _reset({bool clearPersonalization = false}) {
    _generation++;
    _record?.removeListener(_projectionChanged);
    _record = _memory.acquire(
      widget.comment,
      _sessions?.session,
      widget.repository,
      CommentLikeState(
        likeCount: widget.comment.deleted ? 0 : widget.comment.likeCount,
        likedByMe:
            !clearPersonalization &&
            _allowed &&
            !widget.comment.deleted &&
            widget.comment.likedByMe,
      ),
    );
    _record!.addListener(_projectionChanged);
  }

  void _projectionChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _sessions = _resolveSessions();
    _sessions?.addListener(_sessionChanged);
    _reset();
  }

  @override
  void didUpdateWidget(covariant CommentLikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextSessions = _resolveSessions();
    final sessionManagerChanged = !identical(nextSessions, _sessions);
    if (sessionManagerChanged) {
      _sessions?.removeListener(_sessionChanged);
      _sessions = nextSessions;
      _sessions?.addListener(_sessionChanged);
    }
    if (sessionManagerChanged ||
        !identical(oldWidget.comment, widget.comment) ||
        !identical(oldWidget.memory, widget.memory) ||
        !identical(oldWidget.repository, widget.repository)) {
      _reset(clearPersonalization: sessionManagerChanged);
    }
  }

  void _sessionChanged() {
    if (!mounted) return;
    setState(() {
      _reset(clearPersonalization: true);
    });
  }

  @override
  void dispose() {
    _generation++;
    _sessions?.removeListener(_sessionChanged);
    _record?.removeListener(_projectionChanged);
    super.dispose();
  }

  bool _sameSource(int generation, AuthSession? expected, String id) =>
      mounted &&
      generation == _generation &&
      identical(expected, _sessions?.session) &&
      _allowed &&
      !widget.comment.deleted &&
      widget.comment.id == id;

  Future<void> _act() async {
    final generation = _generation;
    final expected = _sessions?.session;
    final id = widget.comment.id;
    if (_busy ||
        !_sameSource(generation, expected, id) ||
        !widget.enabled ||
        !widget.isCurrent() ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    final readOnly = _uncertain;
    final desired = !_value.likedByMe;
    final memory = _memory;
    final record = _record!;
    final item = widget.comment;
    final sessions = _sessions;
    final repository = _repository;
    // A folded/unmounted row may finish its single in-flight request. Only its
    // exact thread snapshot/session receives the result, including on remount.
    bool currentOperation() =>
        identical(record, _record) &&
        identical(expected, sessions?.session) &&
        memory.contains(item, record) &&
        expected?.isAuthenticated == true &&
        expected?.isActive == true &&
        expected?.requiresListenerProfileChoice != true;
    void error(String message) {
      if (mounted && identical(record, _record)) _showError(message);
    }

    record.update(busy: true);
    Result<CommentLikeState>? result;
    try {
      result = readOnly
          ? await repository.readCommentLike(commentId: id)
          : await repository.setCommentLike(commentId: id, liked: desired);
    } catch (_) {
      // A transport failure does not prove the write failed to commit.
    }
    if (!currentOperation()) return;
    if (result?.isSuccess == true && result?.data != null) {
      record.update(value: result!.data!, busy: false, uncertain: false);
      return;
    }
    if (!readOnly) {
      try {
        result = await repository.readCommentLike(commentId: id);
      } catch (_) {
        result = null;
      }
      if (!currentOperation()) return;
      if (result?.isSuccess == true && result?.data != null) {
        record.update(value: result!.data!, busy: false, uncertain: false);
        if (_value.likedByMe != desired) {
          error('Beğeni güncellenemedi. Yeniden deneyebilirsin.');
        }
        return;
      }
    }
    record.update(busy: false, uncertain: true);
    error('Beğeni durumu doğrulanamadı. Yenilemek için tekrar dokun.');
  }

  void _showError(String message) {
    if (!widget.isCurrent() || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      appSnackBar(context, tone: AppSnackBarTone.error, content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.comment.deleted) return const SizedBox.shrink();
    final expectedGeneration = _generation;
    final expectedSession = _sessions?.session;
    final label = !_allowed
        ? 'Beğenmek için giriş yap'
        : _uncertain
        ? 'Beğeni durumunu yenile'
        : _value.likedByMe
        ? 'Beğeniyi kaldır'
        : 'Beğen';
    final count = _uncertain
        ? '—'
        : _value.likeCount == 0
        ? (widget.compact ? '' : 'Beğen')
        : NumberFormat.compact(locale: 'tr').format(_value.likeCount);
    final icon = _busy
        ? const SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 1.5),
          )
        : _uncertain
        ? const Icon(Icons.refresh_rounded, size: 18)
        : Icon(
            _value.likedByMe
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            size: 18,
            color: AppColors.likeHeart,
          );
    return Semantics(
      label: _uncertain ? label : '$label, ${_value.likeCount} beğeni',
      toggled: !_uncertain && _value.likedByMe,
      child: Tooltip(
        message: label,
        child: TextButton(
          key: ValueKey('comment-like-${widget.comment.id}'),
          onPressed: _busy || !_allowed || !widget.enabled
              ? null
              : () {
                  if (_generation != expectedGeneration ||
                      !identical(expectedSession, _sessions?.session)) {
                    return;
                  }
                  _act();
                },
          style: TextButton.styleFrom(
            minimumSize: const Size(44, 44),
            padding: EdgeInsets.symmetric(horizontal: widget.compact ? 4 : 8),
            foregroundColor: _value.likedByMe
                ? AppColors.gradientB
                : AppColors.textMuted,
          ),
          child: ExcludeSemantics(
            child: widget.compact
                ? ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 56),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        icon,
                        if (count.isNotEmpty)
                          Text(
                            count,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10),
                          ),
                      ],
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      icon,
                      if (count.isNotEmpty) ...[
                        const SizedBox(width: 5),
                        Text(count, style: const TextStyle(fontSize: 12)),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
