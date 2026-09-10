import '../../../../core/auth/auth_session_manager.dart';
import '../../domain/overthinking_session.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../engagement/domain/engagement_repository.dart';
import '../../domain/entities/overthinking_post.dart';
import '../../domain/overthinking_repository.dart';
import '../../domain/overthinking_feed_sort.dart';
import 'overthinking_feed_state.dart';

class OverthinkingFeedCubit extends Cubit<OverthinkingFeedState> {
  static const String targetType = 'OVERTHINKING';

  final OverthinkingRepository _overthinkingRepository;
  final EngagementRepository _engagementRepository;
  final OverthinkingSession _session;
  bool get isSessionCurrent => _session.isCurrent;
  bool get canWrite => !isClosed && _session.canWrite;
  bool isPostUnavailable(String postId) => _deletedIds.contains(postId);

  int _loadGeneration = 0;
  int _sortGeneration = 0;
  int _readGeneration = 0;
  int _revision = 0;
  // Reads can finish after an edit, comment, like or deletion. Keep only the
  // affected local posts when merging those older server snapshots.
  final Map<String, int> _postRevisions = {};
  final Map<String, int> _ownerWriteRevisions = {};
  final Map<String, int> _authorReadGenerations = {};
  final Map<String, int> _detailGenerations = {};
  final Map<String, int> _revealWriteRevisions = {};
  final Map<String, int> _revealReadGenerations = {};
  final Map<String, bool> _revealPendingValues = {};
  final Set<String> _revealReconcilingIds = {};
  final Set<String> _likingIds = {};
  final Set<String> _deletedIds = {};
  final Set<String> _createdIds = {};

  OverthinkingFeedCubit({
    required OverthinkingRepository overthinkingRepository,
    required EngagementRepository engagementRepository,
    AuthSessionManager? sessions,
  }) : _overthinkingRepository = overthinkingRepository,
       _engagementRepository = engagementRepository,
       _session = OverthinkingSession(sessions),
       super(const OverthinkingFeedState.initial()) {
    _session.addListener(_sessionChanged);
  }

  void _sessionChanged() {
    if (isClosed) return;
    ++_loadGeneration;
    ++_readGeneration;
    _postRevisions.clear();
    _ownerWriteRevisions.clear();
    _authorReadGenerations.clear();
    _detailGenerations.clear();
    _revealWriteRevisions.clear();
    _revealReadGenerations.clear();
    _revealPendingValues.clear();
    _revealReconcilingIds.clear();
    _likingIds.clear();
    _deletedIds.clear();
    _createdIds.clear();
    emit(
      const OverthinkingFeedState.initial().copyWith(
        status: OverthinkingFeedStatus.failure,
        error: OverthinkingSession.error,
      ),
    );
  }

  @override
  Future<void> close() {
    _session.removeListener(_sessionChanged);
    _session.dispose();
    return super.close();
  }

  Future<void> load() async {
    if (!isSessionCurrent || isClosed) return;
    final generation = ++_loadGeneration;
    final readGeneration = ++_readGeneration;
    final revision = _revision;
    emit(state.copyWith(status: OverthinkingFeedStatus.loading, error: null));
    final result = await _overthinkingRepository.getFeed(
      page: 0,
      size: 20,
      sort: state.sort,
    );
    if (!isSessionCurrent || isClosed || generation != _loadGeneration) return;
    if (!result.isSuccess || result.data == null) {
      emit(
        state.copyWith(
          status: OverthinkingFeedStatus.failure,
          error: result.error,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        status: OverthinkingFeedStatus.idle,
        posts: _mergePage(
          result.data!.items,
          revision,
          readGeneration,
          append: false,
        ),
        hasNext: result.data!.hasNext,
        page: 0,
        error: null,
      ),
    );
  }

  Future<void> setSort(OverthinkingFeedSort sort) async {
    if (!isSessionCurrent || isClosed || state.sort == sort) return;
    ++_sortGeneration;
    ++_loadGeneration;
    emit(state.copyWith(sort: sort, posts: [], page: 0, hasNext: false));
    await load();
  }

  Future<void> loadMore() async {
    if (!isSessionCurrent ||
        isClosed ||
        state.status == OverthinkingFeedStatus.loading ||
        state.status == OverthinkingFeedStatus.loadingMore ||
        !state.hasNext) {
      return;
    }

    final nextPage = state.page + 1;
    final generation = ++_loadGeneration;
    final readGeneration = ++_readGeneration;
    final revision = _revision;
    emit(
      state.copyWith(status: OverthinkingFeedStatus.loadingMore, error: null),
    );
    final result = await _overthinkingRepository.getFeed(
      page: nextPage,
      size: 20,
      sort: state.sort,
    );
    if (!isSessionCurrent || isClosed || generation != _loadGeneration) return;
    if (!result.isSuccess || result.data == null) {
      emit(
        state.copyWith(
          status: OverthinkingFeedStatus.failure,
          error: result.error,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        status: OverthinkingFeedStatus.idle,
        posts: _mergePage(
          result.data!.items,
          revision,
          readGeneration,
          append: true,
        ),
        hasNext: result.data!.hasNext,
        page: nextPage,
        error: null,
      ),
    );
  }

  Future<bool> createPost({
    String? clientRequestId,
    required String title,
    required String content,
    required bool anonymous,
    String? spotifyTrackUrl,
    String? spotifyArtistId,
    String? spotifyTrackName,
    String? spotifyArtistName,
    String? spotifyAlbumImageUrl,
  }) async {
    if (!canWrite || isClosed || state.submitting || state.deleting) {
      return false;
    }
    emit(state.copyWith(submitting: true, error: null));
    final result = await _overthinkingRepository.createPost(
      clientRequestId: clientRequestId,
      title: title,
      content: content,
      visibilityType: anonymous ? 'ANONYMOUS' : 'VISIBLE',
      spotifyTrackUrl: spotifyTrackUrl,
      spotifyArtistId: spotifyArtistId,
      spotifyTrackName: spotifyTrackName,
      spotifyArtistName: spotifyArtistName,
      spotifyAlbumImageUrl: spotifyAlbumImageUrl,
    );
    if (!isSessionCurrent || isClosed) return false;
    if (!result.isSuccess || result.data == null) {
      emit(state.copyWith(submitting: false, error: result.error));
      return false;
    }
    final created = result.data!;
    _createdIds.add(created.id);
    _markChanged(created.id);
    _ownerWriteRevisions[created.id] = _revision;
    if (state.sort != OverthinkingFeedSort.newest) {
      // The server owns global ordering; a new post may belong to a later page.
      emit(state.copyWith(submitting: false, error: null));
      await load();
      return true;
    }
    emit(
      state.copyWith(
        submitting: false,
        posts: [created, ...state.posts.where((post) => post.id != created.id)],
        error: null,
      ),
    );
    return true;
  }

  Future<void> refreshPost(String postId) => _refreshPost(postId);

  Future<void> _refreshPost(
    String postId, {
    bool reconcileReveal = false,
  }) async {
    if (!isSessionCurrent || isClosed || _deletedIds.contains(postId)) return;
    final generation = (_detailGenerations[postId] ?? 0) + 1;
    _detailGenerations[postId] = generation;
    final readGeneration = ++_readGeneration;
    final revision = _revision;
    final sortGeneration = _sortGeneration;
    final result = await _overthinkingRepository.getDetail(postId: postId);
    if (!isSessionCurrent ||
        isClosed ||
        (!reconcileReveal && sortGeneration != _sortGeneration) ||
        _deletedIds.contains(postId) ||
        _detailGenerations[postId] != generation) {
      return;
    }
    if (!result.isSuccess || result.data == null) {
      if (result.error?.code == '404' || result.error?.code == '9401') {
        _deletedIds.add(postId);
        _createdIds.remove(postId);
        _markChanged(postId);
        emit(
          state.copyWith(
            posts: state.posts.where((post) => post.id != postId).toList(),
            error: result.error,
          ),
        );
      } else {
        emit(state.copyWith(error: result.error));
      }
      return;
    }
    final current = _findPost(postId);
    final merged = current != null && (_postRevisions[postId] ?? 0) > revision
        ? current
        : _preservePendingLike(result.data!, current);
    final projection = _mergeReadProjection(
      merged,
      result.data!,
      current,
      revision,
      readGeneration,
      reconcileReveal: reconcileReveal,
    );
    // A conflict still settles its pending value across a sort change, but a
    // detail from the previous page must not insert that post into the new one.
    if (current != null || sortGeneration == _sortGeneration) {
      _replacePost(projection);
    }
  }

  Future<bool> updatePost({
    required OverthinkingPost post,
    required String title,
    required String content,
    required bool anonymous,
    String? spotifyTrackUrl,
    String? spotifyArtistId,
    String? spotifyTrackName,
    String? spotifyArtistName,
    String? spotifyAlbumImageUrl,
  }) async {
    if (!canWrite ||
        isClosed ||
        state.submitting ||
        state.deleting ||
        _deletedIds.contains(post.id)) {
      return false;
    }
    final revision = _revision;
    emit(state.copyWith(submitting: true, error: null));
    final result = await _overthinkingRepository.updatePost(
      postId: post.id,
      title: title,
      content: content,
      visibilityType: anonymous ? 'ANONYMOUS' : 'VISIBLE',
      spotifyTrackUrl: spotifyTrackUrl,
      spotifyArtistId: spotifyArtistId,
      spotifyTrackName: spotifyTrackName,
      spotifyArtistName: spotifyArtistName,
      spotifyAlbumImageUrl: spotifyAlbumImageUrl,
      musicianTrackId: post.musicianTrackId,
      bandTrackId: post.bandTrackId,
    );
    if (!isSessionCurrent || isClosed) return false;
    if (!result.isSuccess || result.data == null) {
      emit(state.copyWith(submitting: false, error: result.error));
      return false;
    }
    emit(state.copyWith(submitting: false, error: null));
    final current = _findPost(post.id);
    final updated =
        current != null &&
            ((_postRevisions[post.id] ?? 0) > revision ||
                _likingIds.contains(post.id))
        ? result.data!.copyWith(
            likedByMe: current.likedByMe,
            likeCount: current.likeCount,
            commentCount: current.commentCount,
          )
        : result.data!;
    _replacePost(updated);
    _ownerWriteRevisions[post.id] = _revision;
    return true;
  }

  Future<bool> deletePost(String postId) async {
    if (!canWrite ||
        isClosed ||
        state.deleting ||
        state.submitting ||
        _deletedIds.contains(postId)) {
      return false;
    }
    emit(state.copyWith(deleting: true, error: null));
    final result = await _overthinkingRepository.deletePost(postId: postId);
    if (!isSessionCurrent || isClosed) return false;
    if (!result.isSuccess) {
      emit(state.copyWith(deleting: false, error: result.error));
      return false;
    }
    _deletedIds.add(postId);
    _createdIds.remove(postId);
    _markChanged(postId);
    final posts = state.posts.where((item) => item.id != postId).toList();
    emit(state.copyWith(deleting: false, posts: posts, error: null));
    return true;
  }

  Future<void> toggleLike(OverthinkingPost post) async {
    if (!canWrite ||
        isClosed ||
        _deletedIds.contains(post.id) ||
        !_likingIds.add(post.id)) {
      return;
    }
    final before = _findPost(post.id) ?? post;
    final optimistic = before.copyWith(
      likedByMe: !before.likedByMe,
      likeCount: (before.likeCount + (before.likedByMe ? -1 : 1))
          .clamp(0, 1 << 30)
          .toInt(),
    );
    _replacePost(optimistic);

    final result = before.likedByMe
        ? await _engagementRepository.unlike(
            targetType: targetType,
            targetId: before.id,
          )
        : await _engagementRepository.like(
            targetType: targetType,
            targetId: before.id,
          );

    _likingIds.remove(post.id);
    if (!isSessionCurrent || isClosed || _deletedIds.contains(post.id)) return;
    // Reads started while the optimistic write was pending must not replace
    // its confirmed result with a snapshot taken before the server committed it.
    _markChanged(post.id);
    if (!result.isSuccess) {
      final current = _findPost(post.id);
      if (current == null) return;
      _replacePost(
        current.copyWith(
          likedByMe: before.likedByMe,
          likeCount:
              (current.likeCount + before.likeCount - optimistic.likeCount)
                  .clamp(0, 1 << 30)
                  .toInt(),
        ),
      );
      emit(state.copyWith(error: result.error));
    }
  }

  Future<bool> toggleReveal(OverthinkingPost post) => _setRevealPending(
    post,
    !(_revealPendingValues[post.id] ??
        _findPost(post.id)?.revealRequestPending ??
        post.revealRequestPending),
  );

  Future<bool> requestReveal(OverthinkingPost post) =>
      _setRevealPending(post, true);

  Future<bool> _setRevealPending(OverthinkingPost post, bool pending) async {
    if (!canWrite ||
        isClosed ||
        _deletedIds.contains(post.id) ||
        state.revealRequestingIds.contains(post.id)) {
      return false;
    }
    final before =
        _revealPendingValues[post.id] ??
        _findPost(post.id)?.revealRequestPending ??
        post.revealRequestPending;
    if (before == pending) return true;
    final sortGeneration = _sortGeneration;
    _revealPendingValues[post.id] = before;
    final requesting = Set<String>.from(state.revealRequestingIds)
      ..add(post.id);
    emit(state.copyWith(revealRequestingIds: requesting, error: null));

    final result = pending
        ? await _overthinkingRepository.requestReveal(postId: post.id)
        : await _overthinkingRepository.cancelReveal(postId: post.id);
    if (!isSessionCurrent || isClosed) return false;

    if (!result.isSuccess &&
        const {'409', '9406', '9409', '9410'}.contains(result.error?.code)) {
      // A decision on another device can race with a cancellation. Keep the
      // action locked until its authoritative author/pending projection arrives.
      _revealReconcilingIds.add(post.id);
      await _refreshPost(post.id, reconcileReveal: true);
      _revealReconcilingIds.remove(post.id);
      if (!isSessionCurrent || isClosed) return false;
    }

    final next = Set<String>.from(state.revealRequestingIds)..remove(post.id);
    emit(state.copyWith(revealRequestingIds: next));

    if (!result.isSuccess) {
      emit(state.copyWith(error: result.error));
      return false;
    }
    if (_deletedIds.contains(post.id)) return false;
    _revealPendingValues[post.id] = pending;
    _markChanged(post.id);
    _revealWriteRevisions[post.id] = _revision;
    final current = _findPost(post.id);
    if (current != null) {
      _replacePost(current.copyWith(revealRequestPending: pending));
    } else if (sortGeneration == _sortGeneration) {
      // Notification detail routes can display their initial post while the
      // first detail read is still pending. Publish the confirmed action there.
      _replacePost(post.copyWith(revealRequestPending: pending));
    }
    return true;
  }

  void incrementCommentCount(String postId) {
    if (!canWrite || isClosed || _deletedIds.contains(postId)) return;
    OverthinkingPost? post;
    for (final item in state.posts) {
      if (item.id == postId) {
        post = item;
        break;
      }
    }
    if (post == null) return;
    _replacePost(post.copyWith(commentCount: post.commentCount + 1));
  }

  void _replacePost(OverthinkingPost post) {
    if (!isSessionCurrent || isClosed || _deletedIds.contains(post.id)) return;
    _markChanged(post.id);
    final exists = state.posts.any((item) => item.id == post.id);
    final posts = exists
        ? state.posts.map((item) => item.id == post.id ? post : item).toList()
        : [post, ...state.posts];
    emit(state.copyWith(posts: posts, error: null));
  }

  OverthinkingPost? _findPost(String id) {
    for (final post in state.posts) {
      if (post.id == id) return post;
    }
    return null;
  }

  void _markChanged(String id) => _postRevisions[id] = ++_revision;

  OverthinkingPost _preservePendingLike(
    OverthinkingPost remote,
    OverthinkingPost? current,
  ) => current != null && _likingIds.contains(remote.id)
      ? remote.copyWith(
          likedByMe: current.likedByMe,
          likeCount: current.likeCount,
        )
      : remote;

  List<OverthinkingPost> _mergePage(
    List<OverthinkingPost> incoming,
    int requestedRevision,
    int readGeneration, {
    required bool append,
  }) {
    final current = {for (final post in state.posts) post.id: post};
    final merged = <String, OverthinkingPost>{
      for (final post in state.posts)
        if (append ||
            (state.sort == OverthinkingFeedSort.newest &&
                _createdIds.contains(post.id) &&
                (_postRevisions[post.id] ?? 0) > requestedRevision))
          post.id: post,
    };
    for (final post in incoming) {
      if (_deletedIds.contains(post.id)) continue;
      final local = current[post.id];
      final next =
          local != null && (_postRevisions[post.id] ?? 0) > requestedRevision
          ? local
          : _preservePendingLike(post, local);
      merged[post.id] = _mergeReadProjection(
        next,
        post,
        local,
        requestedRevision,
        readGeneration,
      );
    }
    return merged.values.toList();
  }

  OverthinkingPost _mergeReadProjection(
    OverthinkingPost merged,
    OverthinkingPost remote,
    OverthinkingPost? current,
    int requestedRevision,
    int readGeneration, {
    bool reconcileReveal = false,
  }) {
    // Engagement changes cannot retain an identity that a fresh server read
    // masks. A newer owner edit or a later-requested read remains authoritative.
    final keepCurrent =
        current != null &&
        ((_ownerWriteRevisions[remote.id] ?? 0) > requestedRevision ||
            (_authorReadGenerations[remote.id] ?? 0) > readGeneration);
    if (!keepCurrent) _authorReadGenerations[remote.id] = readGeneration;
    final author = keepCurrent ? current : remote;
    // Reveal writes and reads have their own revision. A simultaneous like
    // must neither restore an old pending request nor hide a new server result.
    final keepPending =
        _revealPendingValues.containsKey(remote.id) &&
        ((state.revealRequestingIds.contains(remote.id) &&
                !_revealReconcilingIds.contains(remote.id) &&
                !reconcileReveal) ||
            (_revealWriteRevisions[remote.id] ?? 0) > requestedRevision ||
            (_revealReadGenerations[remote.id] ?? 0) > readGeneration);
    final pending = keepPending
        ? _revealPendingValues[remote.id]!
        : remote.revealRequestPending;
    if (!keepPending) {
      _revealReadGenerations[remote.id] = readGeneration;
      _revealPendingValues[remote.id] = pending;
    }
    return merged.copyWith(
      authorId: author.authorId,
      authorUsername: author.authorUsername,
      authorAvatarUrl: author.authorAvatarUrl,
      authorVisibilityMode: author.authorVisibilityMode,
      anonymous: author.anonymous,
      canViewAuthor: author.canViewAuthor,
      visibilityType: author.visibilityType,
      revealRequestPending: pending,
    );
  }
}
