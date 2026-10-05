part of 'listener_event_posts.dart';

extension _ListenerEventFeedStateBindMethods on _ListenerEventFeedState {
  void _bind() {
    _cancelTableRefresh();
    _tableRefreshFlight = null;
    _visibleTableShares.clear();
    _tableRefreshDelay = const Duration(seconds: 15);
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
        : widget.overthinkingRepository != null
        ? ListenerProfileFeedController(
            eventsRepository: repository,
            overthinkingRepository: widget.overthinkingRepository!,
            tableGroupRepository: widget.tableGroupRepository,
            sessions: sessions,
            listenerProfileId: widget.listenerProfileId,
            ownerUserId: widget.ownerUserId,
          )
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

  bool get _canRefreshTables {
    final feed = _feed;
    return mounted &&
        _foreground &&
        _routeCurrent &&
        _tickersEnabled &&
        feed is ListenerProfileFeedController &&
        feed.allowed &&
        !feed.loading &&
        feed.entries.any(
          (entry) =>
              entry.tableShare?.tableGroup.status == 'ACTIVE' &&
              _visibleTableShares.contains(entry.tableShare?.shareId),
        );
  }

  void _setTableVisible(String shareId, bool visible) {
    if (!mounted) return;
    if (visible) {
      _visibleTableShares.add(shareId);
    } else {
      _visibleTableShares.remove(shareId);
    }
    _scheduleTableRefresh();
  }

  void _cancelTableRefresh() {
    _tableRefreshTimer?.cancel();
    _tableRefreshTimer = null;
    ++_tableRefreshGeneration;
  }

  void _scheduleTableRefresh({bool immediate = false}) {
    if (!_canRefreshTables) {
      _cancelTableRefresh();
      return;
    }
    if (_tableRefreshFlight != null || _tableRefreshTimer != null) return;
    _tableRefreshTimer = Timer(
      immediate ? Duration.zero : _tableRefreshDelay,
      () => unawaited(_refreshVisibleTables()),
    );
  }

  Future<void> _refreshVisibleTables() async {
    _tableRefreshTimer = null;
    final feed = _feed;
    if (!_canRefreshTables || feed is! ListenerProfileFeedController) return;
    final flight = Object();
    _tableRefreshFlight = flight;
    final generation = _tableRefreshGeneration;
    final success = await feed.refreshTableShares(
      shareIds: Set.of(_visibleTableShares),
      isCurrent: () =>
          _canRefreshTables &&
          identical(_feed, feed) &&
          generation == _tableRefreshGeneration,
    );
    if (!identical(_tableRefreshFlight, flight)) return;
    _tableRefreshFlight = null;
    if (!mounted) return;
    if (generation == _tableRefreshGeneration) {
      _tableRefreshDelay = success
          ? const Duration(seconds: 15)
          : Duration(
              seconds: (_tableRefreshDelay.inSeconds * 2).clamp(15, 120),
            );
    }
    _scheduleTableRefresh();
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
    if (mounted) _updateView(() {});
    _scheduleTableRefresh();
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

  Future<void> _reloadFeed(ListenerEventFeedController feed) =>
      feed is ListenerProfileFeedController ? feed.revalidate() : feed.reload();

  void _refresh() {
    final feed = _feed;
    if (feed != null) unawaited(_reloadFeed(feed));
  }

  Widget _body(ListenerEventFeedController feed) {
    if (feed is ListenerProfileFeedController) return _profileBody(feed);
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
            Text(
              feed.error!,
              style: TextStyle(color: AppColors.legacy(Color(0xFFA0A9B6))),
            ),
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
            style: TextStyle(
              color: AppColors.legacy(Color(0xFFA0A9B6)),
              height: 1.5,
            ),
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

  Widget _tableCard(
    ListenerProfileFeedController feed,
    TableGroupProfileShare share,
    AuthSession expectedSession,
  ) {
    bool profileCurrent() =>
        mounted &&
        identical(_feed, feed) &&
        feed.allowed &&
        identical(feed.sessions.session, expectedSession);
    return _VisibleTablePublication(
      onVisibilityChanged: (visible) {
        if (profileCurrent()) _setTableVisible(share.shareId, visible);
      },
      child: ListenerTableGroupShareTile(
        share: share,
        username: widget.username,
        avatarUrl: widget.avatarUrl,
        ownerUserId: widget.ownerUserId,
        repository: widget.tableGroupRepository!,
        sessions: feed.sessions,
        isCurrent: () =>
            profileCurrent() && feed.containsTableShare(expectedSession, share),
        onSourceRefresh: () async {
          bool sourceCurrent() =>
              profileCurrent() && _foreground && _tickersEnabled;
          if (!sourceCurrent()) return;
          await feed.refreshTableShares(
            shareIds: {share.shareId, ..._visibleTableShares},
            isCurrent: sourceCurrent,
            afterPending: true,
          );
        },
        onOpenSource: widget.onOpenTable,
        onEngagementChanged: (stats) {
          if (!profileCurrent()) return;
          feed.updateTableGroupEngagement(
            expectedSession: expectedSession,
            expectedShare: share,
            stats: stats,
          );
        },
        onRefresh: () async {
          if (profileCurrent()) await feed.revalidate();
        },
        onRemoved: (shareId) {
          if (!profileCurrent()) return;
          feed.forgetTableShare(shareId);
          unawaited(feed.revalidate());
        },
        onError: (message) {
          if (profileCurrent() && ModalRoute.of(context)?.isCurrent == true) {
            _feedback(message);
          }
        },
      ),
    );
  }

  Widget _profileBody(ListenerProfileFeedController feed) {
    final expectedSession = feed.sessions.session;
    Widget rowAt(int index) {
      final entry = feed.entries[index];
      return Visibility(
        key: ValueKey('listener-profile-post-${entry.key}'),
        visible: !feed.loading,
        maintainState: true,
        maintainAnimation: true,
        maintainSize: true,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: entry.eventRow != null
              ? _card(feed, entry.eventRow!)
              : entry.tableShare != null
              ? _tableCard(feed, entry.tableShare!, expectedSession)
              : ListenerOverthinkingShareTile(
                  share: entry.share!,
                  username: widget.username,
                  avatarUrl: widget.avatarUrl,
                  ownerUserId: widget.ownerUserId,
                  repository: widget.overthinkingRepository!,
                  sessions: feed.sessions,
                  isCurrent: () =>
                      mounted &&
                      identical(_feed, feed) &&
                      feed.containsShare(expectedSession, entry.share!) &&
                      ModalRoute.of(context)?.isCurrent == true,
                  onEngagementChanged: (stats) {
                    // The feed can still own this publication after its tile
                    // is recycled. Validate the parent lifetime independently.
                    if (mounted &&
                        identical(_feed, feed) &&
                        widget.listenerProfileId == feed.listenerProfileId &&
                        identical(feed.sessions.session, expectedSession)) {
                      feed.updateOverthinkingEngagement(
                        expectedSession: expectedSession,
                        expectedShare: entry.share!,
                        stats: stats,
                      );
                    }
                  },
                  onRefresh: () async {
                    if (mounted &&
                        identical(_feed, feed) &&
                        identical(feed.sessions.session, expectedSession)) {
                      await feed.revalidate();
                    }
                  },
                  onRemoved: (shareId) {
                    if (mounted &&
                        identical(_feed, feed) &&
                        identical(feed.sessions.session, expectedSession)) {
                      feed.forgetShare(shareId);
                      unawaited(feed.revalidate());
                    }
                  },
                  onError: (message) {
                    if (mounted &&
                        identical(_feed, feed) &&
                        feed.allowed &&
                        identical(feed.sessions.session, expectedSession) &&
                        ModalRoute.of(context)?.isCurrent == true) {
                      _feedback(message);
                    }
                  },
                  onOpenSource: widget.onOpenSource,
                ),
        ),
      );
    }

    final footer = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (feed.loading)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        if (feed.error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                Text(
                  feed.error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.legacy(listenerProfileMuted),
                  ),
                ),
                TextButton.icon(
                  key: const Key('listener-profile-posts-retry'),
                  onPressed:
                      _currentAction(feed, expectedSession) && !feed.loadingMore
                      ? () => unawaited(feed.retry())
                      : null,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Tekrar dene'),
                ),
              ],
            ),
          )
        else if (feed.hasNext)
          TextButton.icon(
            key: const Key('listener-profile-posts-more'),
            onPressed:
                _currentAction(feed, expectedSession) &&
                    !feed.loadingMore &&
                    !_opening
                ? () => unawaited(feed.next())
                : null,
            icon: feed.loadingMore
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.expand_more_rounded),
            label: const Text('Daha fazla göster'),
          ),
      ],
    );
    if (widget.asSliver) {
      return SliverList.builder(
        key: const Key('listener-profile-posts'),
        itemCount: feed.entries.length + 1,
        // Tiles retain themselves only while an interaction is in flight.
        // Idle publications still recycle outside the viewport.
        addAutomaticKeepAlives: true,
        findChildIndexCallback: (key) {
          if (key == const ValueKey('listener-profile-posts-footer')) {
            return feed.entries.length;
          }
          final index = feed.entries.indexWhere(
            (entry) => key == ValueKey('listener-profile-post-${entry.key}'),
          );
          return index < 0 ? null : index;
        },
        itemBuilder: (context, index) {
          if (index == feed.entries.length) {
            return KeyedSubtree(
              key: const ValueKey('listener-profile-posts-footer'),
              child: footer,
            );
          }
          return rowAt(index);
        },
      );
    }
    return Column(
      key: const Key('listener-profile-posts'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < feed.entries.length; index++) rowAt(index),
        footer,
      ],
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
        projectionKey: row,
        repository: engagement,
        sessions: feed.sessions,
        initialStats: row.engagement == null
            ? null
            : InteractionStatsItemState(
                loading: false,
                likeCount: row.engagement!.likeCount,
                commentCount: row.engagement!.commentCount,
                isLiked: row.engagement!.likedByMe,
              ),
        canInteract: () =>
            !_opening && _currentAction(feed, expectedSession, row),
        onError: _feedback,
        builder: (stats, onLike, refresh) =>
            card(stats: stats, onLike: onLike, refreshStats: refresh),
      );
    }

    if (!own &&
        !ended &&
        canUseEventAudience(expectedSession) &&
        (row.engagement == null || row.viewerIntentState != null)) {
      return ListenerEventPostParticipation(
        key: ValueKey('listener-event-participation-${row.postId}'),
        eventId: row.event.id,
        refreshKey: row,
        initialIntent: row.viewerIntentState,
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
      _updateView(() => _opening = false);
    }
  }
}
