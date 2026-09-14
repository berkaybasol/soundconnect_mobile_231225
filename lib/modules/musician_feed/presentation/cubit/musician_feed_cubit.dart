import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/error/app_error.dart';
import '../../../../core/error/result.dart';
import '../../../collab/domain/collab_repository.dart';
import '../../../engagement/domain/engagement_repository.dart';
import '../../../follow/domain/band_follow_repository.dart';
import '../../../follow/domain/follow_repository.dart';
import '../../domain/backstage_feed_session.dart';
import '../../domain/feed_item_access.dart';
import '../../domain/musician_feed_models.dart';
import '../../domain/musician_feed_mute_changes.dart';
import '../../domain/musician_feed_repository.dart';
import 'musician_feed_state.dart';

typedef _EngagementTarget = ({String targetType, String targetId});

class _LikeOperation {
  _LikeOperation({
    required this.session,
    required this.contentRevision,
    required this.optimistic,
    required this.snapshots,
  });

  final BackstageFeedIdentity session;
  int contentRevision;
  MusicianFeedEngagement optimistic;
  final Map<String, MusicianFeedEngagement> snapshots;
  final Completer<void> finished = Completer<void>();
  bool? succeeded;
}

class _CollabSaveOperation {
  _CollabSaveOperation({
    required this.session,
    required this.saved,
    required this.snapshots,
  });

  final BackstageFeedIdentity session;
  final bool saved;
  final Map<String, bool> snapshots;
  bool? succeeded;
}

class _EngagementRead {
  const _EngagementRead(this.generation);
  final int generation;
}

class _MuteOperation {
  const _MuteOperation(this.itemIds, this.session);

  final Set<String> itemIds;
  final BackstageFeedIdentity session;
}

class MusicianFeedCubit extends Cubit<MusicianFeedState> {
  MusicianFeedCubit(
    this._feedRepository,
    this._engagementRepository, {
    required CollabRepository collabRepository,
    required FollowRepository followRepository,
    required BandFollowRepository bandFollowRepository,
    required AuthSessionManager sessions,
    MusicianFeedMuteChanges? muteChanges,
    EngagementRepository? announcementEngagementRepository,
    String Function()? eventIdFactory,
    this.pageSize = 20,
  }) : _announcementEngagementRepository =
           announcementEngagementRepository ?? _engagementRepository,
       _collabRepository = collabRepository,
       _followRepository = followRepository,
       _bandFollowRepository = bandFollowRepository,
       _sessions = sessions,
       _eventIdFactory = eventIdFactory ?? const Uuid().v4,
       assert(pageSize > 0 && pageSize <= 30),
       super(const MusicianFeedState()) {
    _unmuteSubscription = muteChanges?.unmuted.listen(_authorUnmutedElsewhere);
  }

  static const AppError _invalidPage = AppError(
    code: 'musician_feed_page_identity_mismatch',
    message: 'Akış oturumu değişti. Lütfen akışı yenile.',
  );
  static const AppError _unknownLoadError = AppError(
    code: 'musician_feed_load_unknown',
    message: 'Akış yüklenemedi. Lütfen tekrar dene.',
  );
  static const AppError _unknownActionError = AppError(
    code: 'musician_feed_action_unknown',
    message: 'İşlem tamamlanamadı.',
  );
  static const AppError _sessionChangedActionError = AppError(
    code: 'musician_feed_action_session_changed',
    message: 'Hesabın değişti. Lütfen yeniden dene.',
  );

  final MusicianFeedRepository _feedRepository;
  final EngagementRepository _engagementRepository;
  final EngagementRepository _announcementEngagementRepository;
  final CollabRepository _collabRepository;
  final FollowRepository _followRepository;
  final BandFollowRepository _bandFollowRepository;
  final AuthSessionManager _sessions;
  final String Function() _eventIdFactory;
  final int pageSize;
  StreamSubscription<MusicianFeedAuthorUnmuted>? _unmuteSubscription;
  final Map<MusicianFeedAuthorProfileIdentity, _MuteOperation> _muteOperations =
      <MusicianFeedAuthorProfileIdentity, _MuteOperation>{};
  final Map<String, String> _acceptedDismissedItemOwners = <String, String>{};
  final Set<String> _pendingDismissedItemIds = <String>{};
  final Map<MusicianFeedAuthorProfileIdentity, String>
  _acceptedMutedAuthorOwners = <MusicianFeedAuthorProfileIdentity, String>{};
  final Map<String, ({String userId, int revision})> _acceptedFollows = {};
  int _followRevision = 0;
  final Map<String, String> _pendingFollowProfileOwners = <String, String>{};
  final Map<String, String> _pendingFollowItemOwners = <String, String>{};
  final Map<String, Object> _profileFollowOperations = <String, Object>{};
  final Map<_EngagementTarget, _LikeOperation> _engagementOperations =
      <_EngagementTarget, _LikeOperation>{};
  Map<_EngagementTarget, List<_LikeOperation>>? _pagingEngagementOperations;
  Map<_EngagementTarget, List<_LikeOperation>>? _refreshEngagementOperations;
  final Map<_EngagementTarget, _EngagementRead> _engagementReads = {};
  Map<_EngagementTarget, MusicianFeedEngagement>? _pagingEngagementReads;
  Map<_EngagementTarget, MusicianFeedEngagement>? _refreshEngagementReads;
  Map<_EngagementTarget, int>? _pagingCommentCounts;
  Map<_EngagementTarget, int>? _refreshCommentCounts;
  final Map<String, _CollabSaveOperation> _collabSaveOperations = {};
  Map<String, List<_CollabSaveOperation>>? _refreshCollabSaveOperations;
  List<MusicianFeedItem> _backingItems = const <MusicianFeedItem>[];
  int _generation = 0;
  int _contentRevision = 0;

  /// Opaque identity used to fence route callbacks that can outlive the
  /// account/profile session which opened them.
  Object? captureSessionFence() => _sessionIdentity;

  bool acceptsSessionFence(Object? fence) =>
      !isClosed && fence != null && fence == _sessionIdentity;

  Future<void> initialize() async {
    if (state.status != MusicianFeedStatus.initial) return;
    await _loadFirst(keepItems: false);
  }

  Future<void> refresh() => _loadFirst(keepItems: state.items.isNotEmpty);

  Future<void> retry() => _loadFirst(keepItems: false);

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
    emit(
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
      final error = result.error ?? _unknownLoadError;
      if (!keepItems && error.code == musicianFeedFeatureUnavailableCode) {
        emit(
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
      emit(
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
    emit(
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

  Future<void> loadMore() async {
    if (isClosed ||
        state.status == MusicianFeedStatus.loadingMore ||
        state.status == MusicianFeedStatus.loading ||
        state.refreshing ||
        !state.hasMore) {
      return;
    }
    final cursor = state.nextCursor;
    final sessionId = state.feedSessionId;
    final algorithm = state.algorithmVersion;
    if (cursor == null || sessionId == null || algorithm == null) {
      _notice(_invalidPage, loadMore: true);
      return;
    }
    final generation = _generation;
    final session = _sessionIdentity;
    if (session == null) return;
    emit(
      state.copyWith(
        status: MusicianFeedStatus.loadingMore,
        loadMoreError: null,
        actionError: null,
      ),
    );
    // Retain writes overlapping this request until its response is merged,
    // including writes that finish before the page arrives.
    final pageOperations = <_EngagementTarget, List<_LikeOperation>>{
      for (final entry in _engagementOperations.entries)
        entry.key: [entry.value],
    };
    _pagingEngagementOperations = pageOperations;
    final pageReads = <_EngagementTarget, MusicianFeedEngagement>{};
    _pagingEngagementReads = pageReads;
    final pageComments = <_EngagementTarget, int>{};
    _pagingCommentCounts = pageComments;
    final result = await _feedRepository.load(limit: pageSize, cursor: cursor);
    if (identical(_pagingEngagementOperations, pageOperations)) {
      _pagingEngagementOperations = null;
    }
    if (identical(_pagingEngagementReads, pageReads)) {
      _pagingEngagementReads = null;
      _pagingCommentCounts = null;
    }
    if (isClosed || generation != _generation || !_sameSession(session)) return;
    final page = result.data;
    if (!result.isSuccess || page == null) {
      final error = result.error ?? _unknownLoadError;
      if (error.code == musicianFeedCursorInvalidCode) {
        // A cursor rejected after a deploy or algorithm transition can never
        // succeed when retried verbatim. Preserve the visible page while
        // starting a clean first-page session.
        await _loadFirst(keepItems: true);
        return;
      }
      _notice(error, loadMore: true);
      return;
    }
    if (page.feedSessionId != sessionId ||
        page.algorithmVersion != algorithm ||
        (page.hasMore && page.nextCursor == cursor)) {
      _notice(_invalidPage, loadMore: true);
      return;
    }
    final seen = _backingItems.map((item) => item.id).toSet();
    final merged = <MusicianFeedItem>[..._backingItems];
    final pending = Set<String>.from(state.pendingItemIds);
    for (final item in _withoutAcceptedSuppressions(page.items)) {
      if (!_isAcceptedSuppressed(item) && seen.add(item.id)) {
        final latest = pageReads[_engagementTarget(item)];
        var reconciled = latest == null
            ? item
            : item.copyWith(
                engagement: item.engagement!.copyWith(
                  likedByMe: latest.likedByMe,
                  likeCount: latest.likeCount,
                  commentCount: latest.commentCount,
                ),
              );
        final commentCount = pageComments[_engagementTarget(item)];
        if (commentCount != null) {
          reconciled = reconciled.copyWith(
            engagement: reconciled.engagement!.copyWith(
              commentCount: commentCount,
            ),
          );
        }
        merged.add(_applyPagedLikes(reconciled, pageOperations, pending));
      }
    }
    _backingItems = List.unmodifiable(merged);
    emit(
      state.copyWith(
        status: MusicianFeedStatus.ready,
        items: _visibleBackingItems(),
        generatedAt: page.generatedAt,
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
        pendingItemIds: Set.unmodifiable(pending),
        loadMoreError: null,
        actionError: null,
      ),
    );
  }

  Future<bool> dismiss(
    String itemId,
    MusicianFeedFeedbackAction action, {
    String? reason,
  }) async {
    final session = _sessionIdentity;
    if (isClosed || session == null || state.pendingItemIds.contains(itemId)) {
      return false;
    }
    final index = state.items.indexWhere((item) => item.id == itemId);
    if (index < 0) return false;
    final item = state.items[index];
    if (!item.feedbackCapabilities.contains(action)) return false;
    _pendingDismissedItemIds.add(itemId);
    final pending = Set<String>.from(state.pendingItemIds)..add(itemId);
    emit(
      state.copyWith(
        items: _visibleBackingItems(),
        pendingItemIds: Set.unmodifiable(pending),
        actionError: null,
      ),
    );
    final result = await _feedRepository.sendFeedback(
      itemId: itemId,
      impressionToken: item.impressionToken,
      action: action,
      reason: reason,
    );
    if (isClosed) return false;
    _pendingDismissedItemIds.remove(itemId);
    final nextPending = Set<String>.from(state.pendingItemIds)..remove(itemId);
    if (!_sameSession(session)) {
      emit(
        state.copyWith(
          items: _visibleBackingItems(),
          pendingItemIds: Set.unmodifiable(nextPending),
          actionError: _sessionChangedActionError,
          noticeSerial: state.noticeSerial + 1,
        ),
      );
      return false;
    }
    if (result.isSuccess) {
      _acceptedDismissedItemOwners[itemId] = session.userId;
      _backingItems = List.unmodifiable(
        _backingItems.where((candidate) => candidate.id != itemId),
      );
      emit(
        state.copyWith(
          items: _visibleBackingItems(),
          pendingItemIds: Set.unmodifiable(nextPending),
        ),
      );
      final telemetryType = switch (action) {
        MusicianFeedFeedbackAction.hide => MusicianFeedTelemetryEventType.hide,
        MusicianFeedFeedbackAction.report =>
          MusicianFeedTelemetryEventType.report,
        MusicianFeedFeedbackAction.showLess => null,
      };
      if (telemetryType != null) {
        unawaited(recordEvent(item, telemetryType));
      }
      if (action == MusicianFeedFeedbackAction.showLess) {
        // SHOW_LESS changes the server-side ranking context encoded into the
        // cursor. Never allow an old cursor to page after that write.
        emit(state.copyWith(nextCursor: null, hasMore: false));
        await _loadFirst(keepItems: true);
      }
      return true;
    }
    emit(
      state.copyWith(
        items: _visibleBackingItems(),
        pendingItemIds: Set.unmodifiable(nextPending),
        actionError: result.error ?? _unknownActionError,
        noticeSerial: state.noticeSerial + 1,
      ),
    );
    return false;
  }

  Future<bool> muteAuthor({
    required String sourceItemId,
    required String profileType,
    required String profileId,
  }) async {
    final author = parseMusicianFeedAuthorProfileIdentity(
      profileType: profileType,
      profileId: profileId,
    );
    final session = _sessionIdentity;
    if (isClosed || author == null || session == null) return false;
    final sourceIndex = state.items.indexWhere(
      (item) =>
          item.id == sourceItemId &&
          musicianFeedAuthorProfileIdentity(item.author) == author,
    );
    if (sourceIndex < 0) return false;
    final sourceItem = state.items[sourceIndex];
    final removed = state.items
        .where(
          (item) => musicianFeedAuthorProfileIdentity(item.author) == author,
        )
        .toList(growable: false);
    if (removed.isEmpty ||
        removed.any((item) => state.pendingItemIds.contains(item.id))) {
      return false;
    }
    final removedIds = removed.map((item) => item.id).toSet();
    final operation = _MuteOperation(removedIds, session);
    _muteOperations[author] = operation;
    final pending = Set<String>.from(state.pendingItemIds)..addAll(removedIds);
    emit(
      state.copyWith(
        items: _visibleBackingItems(),
        pendingItemIds: Set.unmodifiable(pending),
        actionError: null,
      ),
    );
    final result = await _feedRepository.muteAuthor(
      profileType: author.profileType,
      profileId: author.profileId,
    );
    if (isClosed || !identical(_muteOperations[author], operation)) {
      return false;
    }
    _muteOperations.remove(author);
    final nextPending = Set<String>.from(state.pendingItemIds)
      ..removeAll(removedIds);
    if (!_sameSession(session)) {
      emit(
        state.copyWith(
          items: _visibleBackingItems(),
          pendingItemIds: Set.unmodifiable(nextPending),
          actionError: _sessionChangedActionError,
          noticeSerial: state.noticeSerial + 1,
        ),
      );
      return false;
    }
    if (result.isSuccess) {
      _acceptedMutedAuthorOwners[author] = session.userId;
      _backingItems = List.unmodifiable(
        _backingItems.where(
          (item) => musicianFeedAuthorProfileIdentity(item.author) != author,
        ),
      );
      emit(
        state.copyWith(
          items: _visibleBackingItems(),
          pendingItemIds: Set.unmodifiable(nextPending),
        ),
      );
      unawaited(recordEvent(sourceItem, MusicianFeedTelemetryEventType.mute));
      return true;
    }
    emit(
      state.copyWith(
        items: _visibleBackingItems(),
        pendingItemIds: Set.unmodifiable(nextPending),
        actionError: result.error ?? _unknownActionError,
        noticeSerial: state.noticeSerial + 1,
      ),
    );
    return false;
  }

  Future<bool> unmuteAuthor({
    required String profileType,
    required String profileId,
  }) async {
    final author = parseMusicianFeedAuthorProfileIdentity(
      profileType: profileType,
      profileId: profileId,
    );
    final session = _sessionIdentity;
    if (isClosed || author == null || session == null) return false;
    if (_acceptedMutedAuthorOwners[author] != session.userId) {
      return false;
    }
    final result = await _feedRepository.unmuteAuthor(
      profileType: author.profileType,
      profileId: author.profileId,
    );
    if (isClosed) return false;
    if (!_sameSession(session)) {
      emit(
        state.copyWith(
          actionError: _sessionChangedActionError,
          noticeSerial: state.noticeSerial + 1,
        ),
      );
      return false;
    }
    if (!result.isSuccess) {
      emit(
        state.copyWith(
          actionError: result.error ?? _unknownActionError,
          noticeSerial: state.noticeSerial + 1,
        ),
      );
      return false;
    }
    _acceptedMutedAuthorOwners.remove(author);
    await refresh();
    return true;
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
      emit(
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

  Future<bool> toggleLike(String itemId) async {
    if (isClosed || state.pendingItemIds.contains(itemId)) return false;
    final index = state.items.indexWhere((item) => item.id == itemId);
    if (index < 0) return false;
    final item = state.items[index];
    final engagement = item.engagement;
    final target = _engagementTarget(item);
    final session = _sessionIdentity;
    if (engagement == null ||
        !engagement.likable ||
        target == null ||
        session == null ||
        _engagementOperations.containsKey(target)) {
      return false;
    }
    final affectedIds = state.items
        .where((candidate) => _engagementTarget(candidate) == target)
        .map((candidate) => candidate.id)
        .toSet();
    if (affectedIds.isEmpty || affectedIds.any(state.pendingItemIds.contains)) {
      return false;
    }
    final contentRevision = _contentRevision;
    final nextLiked = !engagement.likedByMe;
    final optimistic = engagement.copyWith(
      likedByMe: nextLiked,
      likeCount: (engagement.likeCount + (nextLiked ? 1 : -1))
          .clamp(0, 0x7fffffff)
          .toInt(),
    );
    final snapshots = <String, MusicianFeedEngagement>{
      for (final candidate in _backingItems)
        if (_engagementTarget(candidate) == target)
          candidate.id: candidate.engagement!,
    };
    final operation = _LikeOperation(
      session: session,
      contentRevision: contentRevision,
      optimistic: optimistic,
      snapshots: snapshots,
    );
    _engagementOperations[target] = operation;
    _engagementReads.remove(target);
    _pagingEngagementOperations
        ?.putIfAbsent(target, () => <_LikeOperation>[])
        .add(operation);
    _refreshEngagementOperations
        ?.putIfAbsent(target, () => <_LikeOperation>[])
        .add(operation);
    final pending = Set<String>.from(state.pendingItemIds)..addAll(affectedIds);
    _setEngagementForTarget(
      target,
      likedByMe: optimistic.likedByMe,
      likeCount: optimistic.likeCount,
      pending: pending,
    );
    Result<void> result;
    try {
      final repository = engagement.targetType == 'ANNOUNCEMENT'
          ? _announcementEngagementRepository
          : _engagementRepository;
      result = nextLiked
          ? await repository.like(
              targetType: engagement.targetType,
              targetId: engagement.targetId,
            )
          : await repository.unlike(
              targetType: engagement.targetType,
              targetId: engagement.targetId,
            );
    } catch (_) {
      result = const Result.failure(_unknownActionError);
    }
    if (!operation.finished.isCompleted) operation.finished.complete();
    if (isClosed || !identical(_engagementOperations[target], operation)) {
      return false;
    }
    _engagementOperations.remove(target);
    operation.succeeded = result.isSuccess && _sameSession(session);
    if (!_sameSession(session) && contentRevision != _contentRevision) {
      return false;
    }
    final currentAffectedIds = state.items
        .where((candidate) => _engagementTarget(candidate) == target)
        .map((candidate) => candidate.id)
        .toSet();
    final nextPending = Set<String>.from(state.pendingItemIds)
      ..removeAll(snapshots.keys)
      ..removeAll(currentAffectedIds);
    if (!_sameSession(session)) {
      _restoreEngagementSnapshots(snapshots, pending: nextPending);
      emit(
        state.copyWith(
          actionError: _sessionChangedActionError,
          noticeSerial: state.noticeSerial + 1,
        ),
      );
      return false;
    }
    if (result.isSuccess) {
      emit(state.copyWith(pendingItemIds: Set.unmodifiable(nextPending)));
      return true;
    }
    _restoreEngagementSnapshots(snapshots, pending: nextPending);
    if (contentRevision != _contentRevision) return false;
    emit(
      state.copyWith(
        actionError: result.error ?? _unknownActionError,
        noticeSerial: state.noticeSerial + 1,
      ),
    );
    return false;
  }

  Future<bool> followProfile(String itemId) async {
    if (isClosed || state.pendingItemIds.contains(itemId)) return false;
    final index = state.items.indexWhere((item) => item.id == itemId);
    if (index < 0) return false;
    final item = state.items[index];
    final payload = item.payload;
    if (payload is! ProfileFeedPayload || payload.followedByViewer) {
      return false;
    }

    final profileKey = _profileFollowKey(payload);
    final identity = _sessionIdentity;
    if (profileKey == null ||
        identity == null ||
        _pendingFollowProfileOwners.containsKey(profileKey) ||
        (payload.profileType != 'BAND' && payload.userId == identity.userId)) {
      return false;
    }

    final operation = Object();
    _profileFollowOperations[itemId] = operation;
    _pendingFollowProfileOwners[profileKey] = identity.userId;
    _pendingFollowItemOwners[itemId] = identity.userId;
    final pending = Set<String>.from(state.pendingItemIds)..add(itemId);
    emit(
      state.copyWith(
        items: _visibleBackingItems(),
        pendingItemIds: Set.unmodifiable(pending),
        actionError: null,
      ),
    );

    final result = payload.profileType == 'BAND'
        ? await _bandFollowRepository.followBand(payload.profileId)
        : await _followRepository.follow(
            followerId: identity.userId,
            followingId: payload.userId!,
          );
    if (isClosed || !identical(_profileFollowOperations[itemId], operation)) {
      return false;
    }

    _profileFollowOperations.remove(itemId);
    _pendingFollowProfileOwners.remove(profileKey);
    _pendingFollowItemOwners.remove(itemId);
    final nextPending = Set<String>.from(state.pendingItemIds)..remove(itemId);
    if (!_sameSession(identity)) {
      emit(
        state.copyWith(
          items: _visibleBackingItems(),
          pendingItemIds: Set.unmodifiable(nextPending),
          actionError: _sessionChangedActionError,
          noticeSerial: state.noticeSerial + 1,
        ),
      );
      return false;
    }
    if (!result.isSuccess) {
      emit(
        state.copyWith(
          items: _visibleBackingItems(),
          pendingItemIds: Set.unmodifiable(nextPending),
          actionError: result.error ?? _unknownActionError,
          noticeSerial: state.noticeSerial + 1,
        ),
      );
      return false;
    }

    _acceptedFollows[profileKey] = (
      userId: identity.userId,
      revision: ++_followRevision,
    );
    emit(
      state.copyWith(
        items: _visibleBackingItems(),
        pendingItemIds: Set.unmodifiable(nextPending),
        actionError: null,
      ),
    );
    unawaited(recordEvent(item, MusicianFeedTelemetryEventType.follow));
    await refresh();
    return true;
  }

  Future<bool> toggleCollabSaved(String itemId, bool saved) async {
    if (isClosed || state.pendingItemIds.contains(itemId)) return false;
    final session = _sessionIdentity;
    if (session == null) return false;
    final index = state.items.indexWhere((item) => item.id == itemId);
    if (index < 0) return false;
    final item = state.items[index];
    final payload = item.payload;
    if (payload is! CollabFeedPayload) return false;
    final listingId = payload.listing['id']?.toString().trim() ?? '';
    if (listingId.isEmpty || _collabSaveOperations.containsKey(listingId)) {
      return false;
    }
    final contentRevision = _contentRevision;
    final operation = _CollabSaveOperation(
      session: session,
      saved: saved,
      snapshots: {
        for (final candidate in _backingItems)
          if (_collabListingId(candidate) == listingId)
            candidate.id:
                (candidate.payload as CollabFeedPayload).listing['savedByMe'] ==
                true,
      },
    );
    _collabSaveOperations[listingId] = operation;
    _refreshCollabSaveOperations
        ?.putIfAbsent(listingId, () => <_CollabSaveOperation>[])
        .add(operation);
    _setCollabSaved(listingId, saved);
    emit(
      state.copyWith(
        items: _visibleBackingItems(),
        pendingItemIds: Set.unmodifiable(
          Set<String>.from(state.pendingItemIds)
            ..addAll(operation.snapshots.keys),
        ),
        actionError: null,
      ),
    );
    Result<void> result;
    try {
      result = saved
          ? await _collabRepository.saveListing(listingId)
          : await _collabRepository.unsaveListing(listingId);
    } catch (_) {
      result = const Result.failure(_unknownActionError);
    }
    if (isClosed || !identical(_collabSaveOperations[listingId], operation)) {
      return false;
    }
    _collabSaveOperations.remove(listingId);
    operation.succeeded = result.isSuccess && _sameSession(session);
    if (!_sameSession(session) && contentRevision != _contentRevision) {
      return false;
    }
    final nextPending = Set<String>.from(state.pendingItemIds)
      ..removeAll(operation.snapshots.keys)
      ..removeAll(
        state.items
            .where((candidate) => _collabListingId(candidate) == listingId)
            .map((candidate) => candidate.id),
      );
    if (!_sameSession(session)) {
      _restoreCollabSaved(operation.snapshots, nextPending);
      emit(
        state.copyWith(
          actionError: _sessionChangedActionError,
          noticeSerial: state.noticeSerial + 1,
        ),
      );
      return false;
    }
    if (result.isSuccess) {
      emit(state.copyWith(pendingItemIds: Set.unmodifiable(nextPending)));
      if (saved) {
        unawaited(recordEvent(item, MusicianFeedTelemetryEventType.save));
      }
      return true;
    }
    _restoreCollabSaved(operation.snapshots, nextPending);
    if (contentRevision != _contentRevision) return false;
    emit(
      state.copyWith(
        actionError: result.error ?? _unknownActionError,
        noticeSerial: state.noticeSerial + 1,
      ),
    );
    return false;
  }

  void adjustCommentCount(String itemId, int delta) {
    if (isClosed || delta == 0) return;
    final index = state.items.indexWhere((item) => item.id == itemId);
    if (index < 0) return;
    final item = state.items[index];
    final engagement = item.engagement;
    final target = _engagementTarget(item);
    if (engagement == null || target == null) return;
    _engagementReads.remove(target);
    final next = (engagement.commentCount + delta).clamp(0, 0x7fffffff).toInt();
    _setEngagementForTarget(
      target,
      commentCount: next,
      pending: Set<String>.from(state.pendingItemIds),
    );
  }

  /// Reconciles a detail target without replacing the feed session or pages.
  /// Route callers fence the opening session; this read also fences account,
  /// replaced content, newer reads, and local like/comment changes in flight.
  Future<void> refreshEngagement(MusicianFeedItem item) async {
    final target = _engagementTarget(item);
    final session = _sessionIdentity;
    if (isClosed || target == null || session == null) return;
    if (!_backingItems.any(
      (candidate) => _engagementTarget(candidate) == target,
    )) {
      return;
    }
    final contentRevision = _contentRevision;
    final operation = _EngagementRead(_generation);
    _engagementReads[target] = operation;
    bool current() =>
        !isClosed &&
        _sameSession(session) &&
        (contentRevision == _contentRevision ||
            operation.generation == _generation) &&
        identical(_engagementReads[target], operation);
    try {
      // A read started behind an optimistic write must observe its completed
      // result, otherwise an older server count could undo a successful tap.
      final write = _engagementOperations[target];
      if (write != null) await write.finished.future;
      if (!current()) return;
      final repository = target.targetType == 'ANNOUNCEMENT'
          ? _announcementEngagementRepository
          : _engagementRepository;
      final results = await Future.wait<Object>([
        repository.getLikeCount(
          targetType: target.targetType,
          targetId: target.targetId,
        ),
        repository.isLiked(
          targetType: target.targetType,
          targetId: target.targetId,
        ),
        repository.getCommentCount(
          targetType: target.targetType,
          targetId: target.targetId,
        ),
      ]);
      if (!current()) return;
      final likes = results[0] as Result<int>;
      final liked = results[1] as Result<bool>;
      final comments = results[2] as Result<int>;
      // Like state and count are one projection. Preserve both on a partial
      // failure; independent authoritative comments can still be reconciled.
      final hasLikes =
          likes.isSuccess &&
          likes.data != null &&
          liked.isSuccess &&
          liked.data != null;
      final hasComments = comments.isSuccess && comments.data != null;
      if (!hasLikes && !hasComments) return;
      // An older read may still update the retained page while refresh is
      // pending (or fails), but cannot override the newer refresh snapshot.
      final carryIntoRefresh = operation.generation == _generation;
      _setEngagementForTarget(
        target,
        likedByMe: hasLikes ? liked.data : null,
        likeCount: hasLikes ? likes.data : null,
        commentCount: hasComments ? comments.data : null,
        pending: Set<String>.from(state.pendingItemIds),
        carryIntoRefresh: carryIntoRefresh,
      );
      // This read follows all earlier writes. A late page must not reapply an
      // earlier optimistic count over this newer server projection.
      _pagingEngagementOperations?.remove(target);
      if (carryIntoRefresh && hasLikes) {
        _refreshEngagementOperations?.remove(target);
      }
      for (final candidate in _backingItems) {
        if (_engagementTarget(candidate) == target) {
          _pagingEngagementReads?[target] = candidate.engagement!;
          if (carryIntoRefresh && hasLikes) {
            _refreshEngagementReads?[target] = candidate.engagement!;
          }
          break;
        }
      }
    } catch (_) {
      // Returning from a detail should remain usable if its stats read fails.
      // Retain known counts and allow the next detail return/pull to reconcile.
    } finally {
      if (identical(_engagementReads[target], operation)) {
        _engagementReads.remove(target);
      }
    }
  }

  /// Best-effort delivery-scoped telemetry. It never mutates feed UI state.
  Future<bool> recordEvent(
    MusicianFeedItem item,
    MusicianFeedTelemetryEventType eventType,
  ) async {
    final session = _sessionIdentity;
    if (isClosed || session == null) return false;
    try {
      final result = await _feedRepository.recordEvent(
        clientEventId: _eventIdFactory(),
        impressionToken: item.impressionToken,
        eventType: eventType,
      );
      return !isClosed && _sameSession(session) && result.isSuccess;
    } catch (_) {
      return false;
    }
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
    emit(
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
    emit(
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
    emit(
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

  bool get supportsProfileCompletion =>
      _sessionIdentity?.audience.supportsProfileCompletion == true;

  BackstageFeedAudience? get audience => _sessionIdentity?.audience;

  bool canDisplayItem(MusicianFeedItem item) =>
      audience != null && feedCanShowItem(audience!, item);

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
    emit(
      state.copyWith(
        status: MusicianFeedStatus.ready,
        loadMoreError: loadMore ? error : null,
        actionError: loadMore ? null : error,
        noticeSerial: state.noticeSerial + 1,
      ),
    );
  }

  @override
  Future<void> close() {
    _generation += 1;
    unawaited(_unmuteSubscription?.cancel());
    _muteOperations.clear();
    for (final operation in _engagementOperations.values) {
      if (!operation.finished.isCompleted) operation.finished.complete();
    }
    _engagementOperations.clear();
    _pagingEngagementOperations = null;
    _pagingEngagementReads = null;
    _pagingCommentCounts = null;
    _refreshCommentCounts = null;
    _refreshEngagementOperations = null;
    _refreshEngagementReads = null;
    _refreshCollabSaveOperations = null;
    _engagementReads.clear();
    _collabSaveOperations.clear();
    _profileFollowOperations.clear();
    _pendingFollowProfileOwners.clear();
    _pendingFollowItemOwners.clear();
    return super.close();
  }
}
