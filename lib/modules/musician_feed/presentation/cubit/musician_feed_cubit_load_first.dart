part of 'musician_feed_cubit.dart';

extension _MusicianFeedCubitLoadFirstMethods on MusicianFeedCubit {
  Future<void> _loadFirst({required bool keepItems}) async {
    if (isClosed) return;
    final generation = ++_generation;
    final session = _sessionIdentity;
    final followRevision = _followRevision;
    _pagingEngagementOperations = null;
    _pagingEngagementReads = null;
    _pagingCommentCounts = null;
    // Keep every write overlapping this read, even if it completes before the
    // response. A later read begun after a write completed is authoritative.
    final likes = <_EngagementTarget, List<_LikeOperation>>{
      for (final entry in _engagementOperations.entries)
        entry.key: [entry.value],
    };
    final saves = <String, List<_CollabSaveOperation>>{
      for (final entry in _collabSaveOperations.entries)
        entry.key: [entry.value],
    };
    final comments = <_EngagementTarget, int>{};
    final reads = <_EngagementTarget, MusicianFeedEngagement>{};
    _refreshEngagementOperations = likes;
    _refreshCollabSaveOperations = saves;
    _refreshCommentCounts = comments;
    _refreshEngagementReads = reads;
    if (!keepItems) _backingItems = const <MusicianFeedItem>[];
    _emitState(
      state.copyWith(
        status: keepItems
            ? MusicianFeedStatus.ready
            : MusicianFeedStatus.loading,
        items: keepItems ? state.items : const <MusicianFeedItem>[],
        feedSessionId: keepItems ? state.feedSessionId : null,
        algorithmVersion: keepItems ? state.algorithmVersion : null,
        generatedAt: keepItems ? state.generatedAt : null,
        nextCursor: keepItems ? state.nextCursor : null,
        hasMore: keepItems ? state.hasMore : false,
        refreshing: keepItems,
        pendingItemIds: _visiblePendingItemIds(),
        error: null,
        loadMoreError: null,
        actionError: null,
      ),
    );
    final result = await _feedRepository.load(limit: pageSize);
    if (identical(_refreshEngagementOperations, likes)) {
      _refreshEngagementOperations = null;
      _refreshCollabSaveOperations = null;
      _refreshCommentCounts = null;
      _refreshEngagementReads = null;
    }
    if (isClosed || generation != _generation || session != _sessionIdentity) {
      return;
    }
    final page = result.data;
    if (!result.isSuccess || page == null) {
      final error = result.error ?? MusicianFeedCubit._unknownLoadError;
      if (!keepItems && error.code == musicianFeedFeatureUnavailableCode) {
        _emitState(
          state.copyWith(
            status: MusicianFeedStatus.featureUnavailable,
            items: const <MusicianFeedItem>[],
            feedSessionId: null,
            algorithmVersion: null,
            generatedAt: null,
            nextCursor: null,
            hasMore: false,
            refreshing: false,
            pendingItemIds: const <String>{},
            error: null,
            loadMoreError: null,
            actionError: null,
          ),
        );
        return;
      }
      _emitState(
        state.copyWith(
          status: keepItems
              ? MusicianFeedStatus.ready
              : MusicianFeedStatus.failure,
          refreshing: false,
          error: keepItems ? null : error,
          actionError: keepItems ? error : null,
          noticeSerial: keepItems ? state.noticeSerial + 1 : state.noticeSerial,
        ),
      );
      return;
    }
    // A successful read begun after a follow write is authoritative, including
    // a later unfollow from another screen. Writes overlapping this read still
    // need their overlay until their own subsequent read succeeds.
    _acceptedFollows.removeWhere(
      (_, follow) =>
          follow.userId == session?.userId && follow.revision <= followRevision,
    );
    // A detail read begun during this refresh is newer than its GET snapshot.
    // Keep that read valid if it finishes after the first page arrives.
    _engagementReads.removeWhere((_, read) => read.generation != generation);
    _backingItems = _withoutAcceptedSuppressions(page.items);
    _contentRevision += 1;
    _reconcileFirstPageWrites(likes, saves, comments, reads);
    _emitState(
      state.copyWith(
        status: MusicianFeedStatus.ready,
        items: _visibleBackingItems(),
        feedSessionId: page.feedSessionId,
        algorithmVersion: page.algorithmVersion,
        generatedAt: page.generatedAt,
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
        refreshing: false,
        pendingItemIds: _visiblePendingItemIds(),
        error: null,
        loadMoreError: null,
        actionError: null,
      ),
    );
  }

  void _authorUnmutedElsewhere(MusicianFeedAuthorUnmuted change) {
    if (isClosed ||
        (_sessionIdentity?.userId != change.userId ||
            _sessionIdentity?.token != change.token)) {
      return;
    }
    if (_acceptedMutedAuthorOwners[change.author] == change.userId) {
      _acceptedMutedAuthorOwners.remove(change.author);
    }
    // A PUT may have committed before the settings DELETE while its response
    // is still in flight. That older response must not restore the local mute.
    final superseded = _muteOperations.remove(change.author);
    if (superseded != null) {
      _emitState(
        state.copyWith(
          items: _visibleBackingItems(),
          pendingItemIds: Set.unmodifiable(
            Set<String>.from(state.pendingItemIds)
              ..removeAll(superseded.itemIds),
          ),
        ),
      );
    }
    if (state.status != MusicianFeedStatus.initial) unawaited(refresh());
  }

  void _reconcileFirstPageWrites(
    Map<_EngagementTarget, List<_LikeOperation>> likes,
    Map<String, List<_CollabSaveOperation>> saves,
    Map<_EngagementTarget, int> comments,
    Map<_EngagementTarget, MusicianFeedEngagement> reads,
  ) {
    // Only a successful paired like read supplies this projection. Confirmed
    // comments travel independently in `comments`, so a partial stats failure
    // cannot replace either field with a value retained from the old page.
    _backingItems = List.unmodifiable(
      _backingItems.map((item) {
        final latest = reads[_engagementTarget(item)];
        return latest == null
            ? item
            : item.copyWith(
                engagement: item.engagement!.copyWith(
                  likedByMe: latest.likedByMe,
                  likeCount: latest.likeCount,
                ),
              );
      }),
    );
    for (final entry in likes.entries) {
      for (final operation in entry.value) {
        if (!_sameSession(operation.session) || operation.succeeded == false) {
          continue;
        }
        if (operation.succeeded == null) operation.snapshots.clear();
        MusicianFeedEngagement? rebased;
        _backingItems = List.unmodifiable(
          _backingItems.map((item) {
            if (_engagementTarget(item) != entry.key) return item;
            final fresh = item.engagement!;
            if (operation.succeeded == null) {
              // A failed write must restore this new server projection, never
              // the old page or its counts. Every alias shares the same write.
              operation.snapshots[item.id] = fresh;
            }
            final liked = operation.optimistic.likedByMe;
            rebased ??= fresh.copyWith(
              likedByMe: liked,
              likeCount:
                  (fresh.likeCount +
                          (fresh.likedByMe == liked ? 0 : (liked ? 1 : -1)))
                      .clamp(0, 0x7fffffff)
                      .toInt(),
            );
            return item.copyWith(
              engagement: fresh.copyWith(
                likedByMe: rebased!.likedByMe,
                likeCount: rebased!.likeCount,
              ),
            );
          }),
        );
        operation.contentRevision = _contentRevision;
        if (rebased != null) operation.optimistic = rebased!;
      }
    }
    for (final entry in saves.entries) {
      for (final operation in entry.value) {
        if (!_sameSession(operation.session) || operation.succeeded == false) {
          continue;
        }
        if (operation.succeeded == null) {
          operation.snapshots
            ..clear()
            ..addEntries(
              _backingItems
                  .where((item) => _collabListingId(item) == entry.key)
                  .map(
                    (item) => MapEntry(
                      item.id,
                      (item.payload as CollabFeedPayload)
                              .listing['savedByMe'] ==
                          true,
                    ),
                  ),
            );
        }
        _setCollabSaved(entry.key, operation.saved);
      }
    }
    _backingItems = List.unmodifiable(
      _backingItems.map((item) {
        final count = comments[_engagementTarget(item)];
        return count == null
            ? item
            : item.copyWith(
                engagement: item.engagement!.copyWith(commentCount: count),
              );
      }),
    );
  }

  String? _collabListingId(MusicianFeedItem item) {
    final payload = item.payload;
    if (payload is! CollabFeedPayload) return null;
    final id = payload.listing['id']?.toString().trim() ?? '';
    return id.isEmpty ? null : id;
  }

  MusicianFeedItem _withCollabSaved(MusicianFeedItem item, bool saved) =>
      item.copyWith(
        payload: CollabFeedPayload(
          listing: {
            ...(item.payload as CollabFeedPayload).listing,
            'savedByMe': saved,
          },
        ),
      );

  void _setCollabSaved(String listingId, bool saved) {
    _backingItems = List.unmodifiable(
      _backingItems.map(
        (item) => _collabListingId(item) == listingId
            ? _withCollabSaved(item, saved)
            : item,
      ),
    );
  }

  void _restoreCollabSaved(Map<String, bool> snapshots, Set<String> pending) {
    _backingItems = List.unmodifiable(
      _backingItems.map((item) {
        final saved = snapshots[item.id];
        return saved == null || item.payload is! CollabFeedPayload
            ? item
            : _withCollabSaved(item, saved);
      }),
    );
    _emitState(
      state.copyWith(
        items: _visibleBackingItems(),
        pendingItemIds: Set.unmodifiable(pending),
        actionError: null,
      ),
    );
  }

  _EngagementTarget? _engagementTarget(MusicianFeedItem item) {
    final engagement = item.engagement;
    if (engagement == null) return null;
    final targetType = engagement.targetType.trim().toUpperCase();
    final targetId = engagement.targetId.trim();
    if (targetType.isEmpty || targetId.isEmpty) return null;
    return (targetType: targetType, targetId: targetId);
  }

  MusicianFeedItem _applyPagedLikes(
    MusicianFeedItem item,
    Map<_EngagementTarget, List<_LikeOperation>> pageOperations,
    Set<String> pending,
  ) {
    final operations = pageOperations[_engagementTarget(item)];
    if (operations == null) return item;
    var updated = item;
    for (final operation in operations) {
      if (operation.contentRevision != _contentRevision ||
          !_sameSession(operation.session) ||
          operation.succeeded == false) {
        continue;
      }
      final engagement = updated.engagement!;
      if (operation.succeeded == null) {
        operation.snapshots.putIfAbsent(item.id, () => engagement);
        pending.add(item.id);
      }
      updated = updated.copyWith(
        engagement: engagement.copyWith(
          likedByMe: operation.optimistic.likedByMe,
          likeCount: operation.optimistic.likeCount,
        ),
      );
    }
    return updated;
  }

  void _setEngagementForTarget(
    _EngagementTarget target, {
    bool? likedByMe,
    int? likeCount,
    int? commentCount,
    required Set<String> pending,
    bool carryIntoRefresh = true,
  }) {
    // Comment callbacks carry a confirmed total delta even when no detail
    // stats read occurred. Keep it independently of optimistic like snapshots.
    if (commentCount != null) {
      _pagingCommentCounts?[target] = commentCount;
      if (carryIntoRefresh) _refreshCommentCounts?[target] = commentCount;
    }
    _backingItems = List<MusicianFeedItem>.unmodifiable(
      _backingItems.map((candidate) {
        final engagement = candidate.engagement;
        if (engagement == null || _engagementTarget(candidate) != target) {
          return candidate;
        }
        final updated = candidate.copyWith(
          engagement: engagement.copyWith(
            likedByMe: likedByMe,
            likeCount: likeCount,
            commentCount: commentCount,
          ),
        );
        for (final reads in [
          _pagingEngagementReads,
          if (carryIntoRefresh) _refreshEngagementReads,
        ]) {
          final pageSnapshot = reads?[target];
          if (pageSnapshot == null) continue;
          // Keep the authoritative like baseline for aliases arriving during
          // a write: _applyPagedLikes captures it before applying optimism so
          // a failed write can roll every alias back to the same known count.
          reads![target] = _engagementOperations.containsKey(target)
              ? pageSnapshot.copyWith(
                  commentCount: updated.engagement!.commentCount,
                )
              : updated.engagement!;
        }
        return updated;
      }),
    );
    _emitState(
      state.copyWith(
        items: _visibleBackingItems(),
        pendingItemIds: Set.unmodifiable(pending),
        actionError: null,
      ),
    );
  }

  void _restoreEngagementSnapshots(
    Map<String, MusicianFeedEngagement> snapshots, {
    required Set<String> pending,
  }) {
    _backingItems = List<MusicianFeedItem>.unmodifiable(
      _backingItems.map((candidate) {
        final snapshot = snapshots[candidate.id];
        if (snapshot == null || candidate.engagement == null) return candidate;
        final updated = candidate.copyWith(
          engagement: candidate.engagement!.copyWith(
            likedByMe: snapshot.likedByMe,
            likeCount: snapshot.likeCount,
          ),
        );
        final target = _engagementTarget(candidate);
        for (final reads in [_pagingEngagementReads, _refreshEngagementReads]) {
          if (reads?.containsKey(target) == true) {
            reads![target!] = updated.engagement!;
          }
        }
        return updated;
      }),
    );
    _emitState(
      state.copyWith(
        items: _visibleBackingItems(),
        pendingItemIds: Set.unmodifiable(pending),
        actionError: null,
      ),
    );
  }

  List<MusicianFeedItem> _withoutAcceptedSuppressions(
    Iterable<MusicianFeedItem> items,
  ) => List.unmodifiable(
    items.where((item) => canDisplayItem(item) && !_isAcceptedSuppressed(item)),
  );

  List<MusicianFeedItem> _visibleBackingItems() => List.unmodifiable(
    _backingItems
        .where(
          (item) =>
              !_pendingDismissedItemIds.contains(item.id) &&
              !_hasPendingMute(musicianFeedAuthorProfileIdentity(item.author)),
        )
        .map(_applyFollowOverlay),
  );

  bool _hasPendingMute(MusicianFeedAuthorProfileIdentity? author) {
    final operation = _muteOperations[author];
    return operation != null && _sameSession(operation.session);
  }

  MusicianFeedItem _applyFollowOverlay(MusicianFeedItem item) {
    final payload = item.payload;
    if (payload is! ProfileFeedPayload || payload.followedByViewer) return item;
    final key = _profileFollowKey(payload);
    final ownerUserId = _sessionIdentity?.userId;
    if (key == null ||
        ownerUserId == null ||
        (_pendingFollowProfileOwners[key] != ownerUserId &&
            _acceptedFollows[key]?.userId != ownerUserId)) {
      return item;
    }
    return item.copyWith(payload: payload.copyWith(followedByViewer: true));
  }

  Set<String> _visiblePendingItemIds() => Set.unmodifiable({
    ..._pendingFollowItemOwners.entries
        .where(
          (entry) =>
              entry.value == _sessionIdentity?.userId &&
              _backingItems.any((item) => item.id == entry.key),
        )
        .map((entry) => entry.key),
    for (final item in _backingItems)
      if (_sameSession(_engagementOperations[_engagementTarget(item)]?.session))
        item.id,
    for (final item in _backingItems)
      if (_sameSession(_collabSaveOperations[_collabListingId(item)]?.session))
        item.id,
  });

  BackstageFeedIdentity? get _sessionIdentity =>
      backstageFeedSessionIdentity(_sessions.session);

  bool _sameSession(BackstageFeedIdentity? expected) =>
      expected != null && _sessionIdentity == expected;

  String? _profileFollowKey(ProfileFeedPayload payload) {
    final type = payload.profileType.toUpperCase();
    if (type == 'BAND') return 'BAND:${payload.profileId}';
    if (const {'MUSICIAN', 'LISTENER', 'STUDIO', 'VENUE'}.contains(type)) {
      final userId = payload.userId?.trim() ?? '';
      return userId.isEmpty ? null : 'USER:$userId';
    }
    return null;
  }

  bool _isAcceptedSuppressed(MusicianFeedItem item) {
    final ownerUserId = _sessionIdentity?.userId;
    if (ownerUserId == null) return false;
    return _acceptedDismissedItemOwners[item.id] == ownerUserId ||
        _acceptedMutedAuthorOwners[musicianFeedAuthorProfileIdentity(
              item.author,
            )] ==
            ownerUserId;
  }

  void _notice(AppError error, {required bool loadMore}) {
    _emitState(
      state.copyWith(
        status: MusicianFeedStatus.ready,
        loadMoreError: loadMore ? error : null,
        actionError: loadMore ? null : error,
        noticeSerial: state.noticeSerial + 1,
      ),
    );
  }
}
