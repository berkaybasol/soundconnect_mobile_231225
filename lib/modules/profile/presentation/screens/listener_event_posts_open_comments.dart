part of 'listener_event_posts.dart';

extension _ListenerEventFeedStateOpenCommentsMethods
    on _ListenerEventFeedState {
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
    _updateView(() => _opening = true);
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
        backgroundColor: AppColors.legacy(const Color(0xFF101722)),
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
    _updateView(() => _opening = true);
    final dialog = DialogRoute<bool>(
      context: context,
      builder: (_) => const ListenerShareDeleteDialog.event(
        confirmKey: Key('listener-event-post-delete-confirm'),
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
        await _reloadFeed(feed);
      } else {
        await _reloadFeed(feed);
      }
    } catch (_) {
      if (_currentAction(feed, expectedSession)) {
        _feedback('Paylaşım silinemedi. Tekrar deneyebilirsin.');
        await _reloadFeed(feed);
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
    _updateView(() => _opening = true);
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
    _updateView(() => _opening = true);
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
      await _reloadFeed(feed);
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
    _updateView(() => _opening = true);
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
    _updateView(() => _opening = true);
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
        await _reloadFeed(feed);
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
    _updateView(() => _opening = true);
    try {
      await Navigator.of(
        context,
      ).push<void>(MaterialPageRoute(builder: (_) => destination));
    } finally {
      _finishAction(feed);
      if (_currentAction(feed, expectedSession)) {
        await _reloadFeed(feed);
      }
    }
  }
}
