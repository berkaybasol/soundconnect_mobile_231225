part of 'weekly_event_detail_screen.dart';

extension _EventCommentsView on _WeeklyEventDetailScreenState {
  void _resetReplyThreads() {
    _commentIdentityRevision++;
    _repliesByCommentId.clear();
    _loadedReplyParents.clear();
    _expandedReplyParents.clear();
    _replyHasMore.clear();
    _loadingReplyParents.clear();
    _replyPages.clear();
    _replyTotals.clear();
    _replyErrors.clear();
    _replyRequestVersions.clear();
    _replyRootSnapshots.clear();
    final deleteRoute = _deleteCommentRoute;
    if (deleteRoute != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (deleteRoute.isActive) {
          deleteRoute.navigator?.removeRoute(deleteRoute);
        }
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    }
  }

  void _pruneReplyThreads(List<CommentItem> roots) {
    for (final entry in _replyRootSnapshots.entries.toList()) {
      if (roots.any((item) => identical(item, entry.value))) continue;
      _repliesByCommentId.remove(entry.key);
      _loadedReplyParents.remove(entry.key);
      _expandedReplyParents.remove(entry.key);
      _replyHasMore.remove(entry.key);
      _loadingReplyParents.remove(entry.key);
      _replyPages.remove(entry.key);
      _replyTotals.remove(entry.key);
      _replyErrors.remove(entry.key);
      _replyRootSnapshots.remove(entry.key);
      _replyRequestVersions[entry.key] =
          (_replyRequestVersions[entry.key] ?? 0) + 1;
    }
  }

  void _dismissReplyRoute() {
    for (final route in [_replyRoute, _deleteCommentRoute]) {
      if (route == null) continue;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (route.isActive) route.navigator?.removeRoute(route);
      });
    }
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _deleteEventComment(
    CommentItem item,
    CommentItem root,
    AuthSession? expectedSession,
  ) async {
    final eventId = widget.event.id;
    bool valid() =>
        _isCurrentCommentSession(expectedSession) &&
        eventId == widget.event.id &&
        !item.deleted &&
        !item.anonymousAuthor &&
        item.user.id == expectedSession?.userId &&
        _commentCubit.state.comments.any(
          (current) => identical(current, root),
        ) &&
        (identical(item, root) ||
            (_repliesByCommentId[root.id]?.any(
                  (current) => identical(current, item),
                ) ??
                false));
    if (!valid() ||
        _confirmingCommentDelete ||
        _commentCubit.state.submitting ||
        _commentCubit.state.deletingCommentId != null ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    _confirmingCommentDelete = true;
    var answered = false;
    late final DialogRoute<bool> dialog;
    void respond(bool delete) {
      if (answered || !mounted || !dialog.isCurrent || (delete && !valid())) {
        return;
      }
      answered = true;
      dialog.navigator?.pop(delete);
    }

    dialog = DialogRoute<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.navBlue,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: AppColors.border, width: .7),
        ),
        icon: const BrandGradientIcon.social(
          Icons.delete_outline_rounded,
          size: 28,
        ),
        title: const Text('Yorumunu silmek istiyor musun?'),
        actions: [
          TextButton(
            onPressed: () => respond(false),
            child: const Text('Vazgeç'),
          ),
          GradientOutlineButton(
            label: 'Sil',
            onPressed: () => respond(true),
            strokeWidth: .7,
          ),
        ],
      ),
    );
    _deleteCommentRoute = dialog;
    try {
      final confirmed = await Navigator.of(context).push(dialog);
      await dialog.completed;
      if (!mounted ||
          !valid() ||
          confirmed != true ||
          ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
      final deleted = await _commentCubit.delete(commentId: item.id);
      if (!mounted ||
          !_isCurrentCommentSession(expectedSession) ||
          widget.event.id != eventId) {
        return;
      }
      if (deleted) {
        _updateState(_resetReplyThreads);
      }
      if (ModalRoute.of(context)?.isCurrent != true) return;
      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar(
          context,
          tone: deleted ? AppSnackBarTone.success : AppSnackBarTone.error,
          content: Text(
            deleted
                ? 'Yorum silindi.'
                : _commentCubit.state.error?.message ?? 'Yorum silinemedi.',
          ),
        ),
      );
    } finally {
      if (identical(_deleteCommentRoute, dialog)) _deleteCommentRoute = null;
      _confirmingCommentDelete = false;
    }
  }

  Widget _commentSliver(CommentThreadState state) {
    final expectedSession = _commentSessionManager?.session;
    final eventId = widget.event.id;
    bool current() =>
        mounted &&
        widget.event.id == eventId &&
        identical(expectedSession, _commentSessionManager?.session) &&
        ModalRoute.of(context)?.isCurrent == true;
    return SliverList.builder(
      itemCount: state.comments.length + 1,
      itemBuilder: (context, index) {
        if (index == state.comments.length) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (state.loading || state.loadingMore)
                  const LinearProgressIndicator(minHeight: 2)
                else if (state.error != null || state.reloadError != null) ...[
                  Text(
                    state.error?.message ??
                        'İşlem tamamlandı, yorumlar yenilenemedi.',
                  ),
                  TextButton.icon(
                    onPressed: () {
                      if (!current()) return;
                      if (state.hasMore &&
                          state.error != null &&
                          state.comments.isNotEmpty) {
                        _commentCubit.loadMore();
                      } else {
                        _resetReplyThreads();
                        _loadComments(clearExisting: true);
                      }
                    },
                    icon: const BrandGradientIcon.social(
                      Icons.refresh_rounded,
                      size: 18,
                    ),
                    label: const Text('Tekrar dene'),
                  ),
                ] else if (state.comments.isEmpty)
                  Text(
                    _canComment
                        ? 'Henüz yorum yok. İlk yorumu sen yaz.'
                        : 'Henüz yorum yok.',
                    style: TextStyle(color: AppColors.textMuted),
                  )
                else if (state.hasMore)
                  TextButton.icon(
                    key: const Key('event-comments-more'),
                    onPressed: () {
                      if (current()) _commentCubit.loadMore();
                    },
                    icon: const BrandGradientIcon.social(
                      Icons.expand_more_rounded,
                      size: 19,
                    ),
                    label: const Text('Daha fazla yorum'),
                  ),
              ],
            ),
          );
        }
        final comment = state.comments[index];
        final replies =
            _repliesByCommentId[comment.id] ?? const <CommentItem>[];
        final totalReplies = _replyTotals[comment.id] ?? comment.replyCount;
        final hasMore = !_loadedReplyParents.contains(comment.id)
            ? comment.replyCount > 0
            : _replyHasMore[comment.id] == true;
        bool currentRow() =>
            current() &&
            _commentCubit.state.comments.any(
              (item) => identical(item, comment),
            );
        return Padding(
          key: ValueKey('event-comment-${comment.id}'),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: _CommentTile(
            comment: comment,
            timeLabel: _timeLabel(comment.createdAt),
            replies: replies,
            replyTotal: totalReplies,
            repliesExpanded: _expandedReplyParents.contains(comment.id),
            replyTimeLabelBuilder: _timeLabel,
            repliesLoading: _loadingReplyParents.contains(comment.id),
            repliesError: _replyErrors.contains(comment.id),
            hasMoreReplies: hasMore,
            viewerId: _canComment ? expectedSession?.userId : null,
            deletingCommentId: state.deletingCommentId,
            actionsEnabled:
                !state.submitting && state.deletingCommentId == null,
            likeButtonBuilder: (item, compact) => CommentLikeButton(
              key: ValueKey('event-comment-like-${item.id}'),
              comment: item,
              compact: compact,
              sessions: _commentSessionManager,
              memory: _commentLikeMemory,
              repository: _engagementRepository,
              enabled:
                  _canComment &&
                  !state.submitting &&
                  state.deletingCommentId == null,
              isCurrent: () =>
                  currentRow() &&
                  (identical(item, comment) ||
                      (_expandedReplyParents.contains(comment.id) &&
                          (_repliesByCommentId[comment.id]?.any(
                                (reply) => identical(reply, item),
                              ) ??
                              false))),
            ),
            onDeleteTap: (item) =>
                _deleteEventComment(item, comment, expectedSession),
            onRepliesTap: () {
              if (currentRow() && _expandedReplyParents.contains(comment.id)) {
                _loadReplies(comment.id);
              }
            },
            onToggleReplies: () {
              if (!currentRow()) return;
              final expanded = _expandedReplyParents.contains(comment.id);
              _updateState(() {
                if (expanded) {
                  _expandedReplyParents.remove(comment.id);
                } else {
                  _expandedReplyParents.add(comment.id);
                }
              });
              if (!expanded &&
                  !_loadedReplyParents.contains(comment.id) &&
                  !_loadingReplyParents.contains(comment.id)) {
                _loadReplies(comment.id);
              }
            },
            onAuthorTap: !_canComment
                ? null
                : (authorComment) {
                    bool currentAuthor() =>
                        currentRow() &&
                        (identical(authorComment, comment) ||
                            (_repliesByCommentId[comment.id]?.any(
                                  (item) => identical(item, authorComment),
                                ) ??
                                false));
                    if (!currentAuthor()) return;
                    openCommentAuthorProfile(
                      context,
                      authorComment,
                      sessions: _commentSessionManager,
                      isCurrent: currentAuthor,
                    );
                  },
            onReplyTap: _canComment && !comment.deleted
                ? () {
                    if (currentRow()) _showReplySheet(comment, expectedSession);
                  }
                : null,
          ),
        );
      },
    );
  }
}
