import 'dart:async';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/error/app_error.dart';
import '../../../event_audience/domain/event_audience_repository.dart';
import '../../../engagement/presentation/cubit/interaction_stats_state.dart';
import '../../../overthinking/domain/overthinking_profile_share_repository.dart';
import 'listener_event_feed_controller.dart';
import '../../../tablegroup/domain/table_group_profile_share_repository.dart';

/// A profile publication, with the publication's time and identity rather than
/// the creation date of its original event or Overthinking post.
class ListenerProfileFeedEntry {
  ListenerProfileFeedEntry.event(EventAudiencePost post)
    : key = 'event:${post.postId}',
      publishedAt = post.publishedAt,
      eventRow = ListenerEventFeedRow(
        event: post.event,
        postId: post.postId,
        intent: post.intent,
        note: post.note,
        ended: post.eventEnded,
        publishedAt: post.publishedAt,
        engagement: post.engagement,
        viewerIntentState: post.viewerIntentState,
      ),
      share = null,
      tableShare = null;

  ListenerProfileFeedEntry.overthinking(OverthinkingProfileShare publication)
    : key = 'overthinking:${publication.shareId}',
      publishedAt = publication.publishedAt,
      eventRow = null,
      share = publication,
      tableShare = null;

  ListenerProfileFeedEntry.tableGroup(TableGroupProfileShare publication)
    : key = 'table-group:${publication.shareId}',
      publishedAt = publication.publishedAt,
      eventRow = null,
      share = null,
      tableShare = publication;

  final String key;
  final DateTime publishedAt;
  final ListenerEventFeedRow? eventRow;
  final OverthinkingProfileShare? share;
  final TableGroupProfileShare? tableShare;

  static int compare(
    ListenerProfileFeedEntry first,
    ListenerProfileFeedEntry second,
  ) {
    final time = second.publishedAt.compareTo(first.publishedAt);
    if (time != 0) return time;
    final firstEvent = first.eventRow;
    final secondEvent = second.eventRow;
    if (firstEvent != null && secondEvent != null) {
      // Preserve the event endpoint's ordering across page boundaries.
      return firstEvent.event.id.compareTo(secondEvent.event.id);
    }
    if (firstEvent != null) return -1;
    if (secondEvent != null) return 1;
    if (first.share != null && second.share == null) return -1;
    if (second.share != null && first.share == null) return 1;
    return (second.share?.shareId ?? second.tableShare!.shareId).compareTo(
      first.share?.shareId ?? first.tableShare!.shareId,
    );
  }
}

/// Merges the next heads of independently paginated, descending streams.
/// A source must have a known head (or be exhausted) before another row can be
/// shown. Otherwise an older row could appear before an unfetched newer share.
class ListenerProfileFeedController extends ListenerEventFeedController {
  ListenerProfileFeedController({
    required EventAudienceRepository eventsRepository,
    required this.overthinkingRepository,
    this.tableGroupRepository,
    required AuthSessionManager sessions,
    required super.listenerProfileId,
    super.ownerUserId,
    super.pageSize = 6,
  }) : assert(pageSize >= 1 && pageSize <= 50),
       super(
         repository: eventsRepository,
         sessions: sessions,
         observeChanges: false,
         period: EventAudiencePeriod.all,
       ) {
    _session = sessions.session;
    sessions.addListener(_onSessionChanged);
    repository.changes.addListener(_onDataChanged);
    overthinkingRepository.changes.addListener(_onDataChanged);
    tableGroupRepository?.changes.addListener(_onDataChanged);
  }

  final OverthinkingProfileShareRepository overthinkingRepository;
  final TableGroupProfileShareRepository? tableGroupRepository;
  List<ListenerProfileFeedEntry> entries = const [];
  bool loadingMore = false;
  AuthSession _session = const AuthSession.guest();
  _SourceBuffer _events = _SourceBuffer();
  _SourceBuffer _overthinking = _SourceBuffer();
  _SourceBuffer _tables = _SourceBuffer();
  final Set<String> _removed = {};
  int _epoch = 0;
  bool _closed = false;
  bool _retryAppend = false;
  Future<bool>? _tableRefreshInFlight;

  @override
  bool get allowed =>
      !_closed &&
      super.allowed &&
      !sessions.session.requiresListenerProfileChoice &&
      identical(sessions.session, _session) &&
      listenerProfileId.trim().isNotEmpty;

  @override
  Future<void> reload() => _reload();

  /// Refresh every visible page atomically. Retaining the previous geometry
  /// while the view hides stale projections keeps detail navigation in place.
  Future<void> revalidate() async {
    if (_closed) return;
    if (!allowed || entries.isEmpty) return reload();
    await _load(
      append: false,
      targetCount: entries.length < pageSize ? pageSize : entries.length,
      replacePrefix: true,
    );
  }

  Future<void> _reload({bool retryOrderChange = true}) async {
    if (_closed) return;
    _tableRefreshInFlight = null;
    if (!identical(_session, sessions.session)) _removed.clear();
    _session = sessions.session;
    ++_epoch;
    _events = _SourceBuffer();
    _overthinking = _SourceBuffer();
    _tables = _SourceBuffer();
    entries = const [];
    rows = const [];
    page = 0;
    period = EventAudiencePeriod.all;
    hasNext = false;
    loading = false;
    loadingMore = false;
    error = null;
    _retryAppend = false;
    await _load(append: false, retryOrderChange: retryOrderChange);
  }

  @override
  Future<void> next() async {
    if (_closed || loading || loadingMore || !hasNext) return;
    await _load(append: true);
  }

  @override
  Future<void> retry() async {
    if (_closed || loading || loadingMore) return;
    if (_retryAppend) {
      await _load(append: true);
    } else {
      await reload();
    }
  }

  @override
  Future<void> previous() async {}

  @override
  Future<void> selectPeriod(EventAudiencePeriod value) async {
    // Public shares form one timeline; attendance filters belong to Planlarım.
    period = EventAudiencePeriod.all;
  }

  bool containsShare(AuthSession session, OverthinkingProfileShare share) =>
      allowed &&
      !loading &&
      identical(session, _session) &&
      entries.any((entry) => identical(entry.share, share));

  bool containsTableShare(AuthSession session, TableGroupProfileShare share) =>
      allowed &&
      !loading &&
      identical(session, _session) &&
      entries.any((entry) => identical(entry.tableShare, share));

  void forgetTableShare(String shareId) => _forget('table-group:$shareId');

  /// Refresh only on-screen tables, preserving timeline geometry and local
  /// interactions. All cards share one bounded request; a newer feed load,
  /// session, or hidden route wins over a late background response.
  Future<bool> refreshTableShares({
    required Set<String> shareIds,
    required bool Function() isCurrent,
    bool afterPending = false,
  }) {
    final pending = _tableRefreshInFlight;
    if (pending != null) {
      // Expiry may occur under a comments modal after a visible poll started.
      // Let that route-fenced poll finish, then make one fresh canonical read.
      return afterPending
          ? pending.then(
              (_) =>
                  refreshTableShares(shareIds: shareIds, isCurrent: isCurrent),
            )
          : pending;
    }
    final work = _refreshTableShares(shareIds, isCurrent);
    _tableRefreshInFlight = work;
    unawaited(
      work.then((_) {
        if (identical(_tableRefreshInFlight, work)) {
          _tableRefreshInFlight = null;
        }
      }),
    );
    return work;
  }

  Future<bool> _refreshTableShares(
    Set<String> shareIds,
    bool Function() isCurrent,
  ) async {
    final tables = tableGroupRepository;
    if (tables == null || !allowed || loading || loadingMore || !isCurrent()) {
      return true;
    }
    final requested = <String, TableGroupProfileShare>{
      for (final entry in entries)
        if (entry.tableShare case final share?)
          if (shareIds.contains(share.shareId) &&
              share.tableGroup.status == 'ACTIVE')
            share.shareId: share,
    };
    if (requested.isEmpty) return true;
    final ids = requested.keys.take(50).toSet();
    final generation = _epoch;
    final session = _session;
    bool current() => _current(generation, session) && isCurrent();
    try {
      final result = await tables.lookupProfile(
        profileId: listenerProfileId,
        expectedSession: session,
        shareIds: ids,
      );
      if (!current()) return true;
      final data = result.data;
      if (!result.isSuccess || data == null) {
        if (_isDenied(result.error?.code)) {
          ++_epoch;
          entries = const [];
          rows = const [];
          _events = _SourceBuffer();
          _overthinking = _SourceBuffer();
          _tables = _SourceBuffer();
          hasNext = false;
          error = result.error?.message;
          notifyListeners();
        }
        return false;
      }
      final updates = {for (final share in data) share.shareId: share};
      var changed = false;
      final refreshed = <ListenerProfileFeedEntry>[];
      for (final entry in entries) {
        final share = entry.tableShare;
        final expected = requested[share?.shareId];
        if (share == null ||
            expected == null ||
            !ids.contains(share.shareId) ||
            !identical(share.tableGroup, expected.tableGroup)) {
          refreshed.add(entry);
          continue;
        }
        final update = updates[share.shareId];
        if (update == null) {
          // Absence is authoritative only after a successful complete lookup.
          changed = true;
          continue;
        }
        if (update.tableGroup.id != share.tableGroup.id ||
            update.publishedAt != share.publishedAt ||
            update.note != share.note) {
          return false;
        }
        if (_sameTableSource(share.tableGroup, update.tableGroup)) {
          refreshed.add(entry);
          continue;
        }
        changed = true;
        refreshed.add(
          ListenerProfileFeedEntry.tableGroup(
            TableGroupProfileShare(
              shareId: share.shareId,
              publishedAt: share.publishedAt,
              note: share.note,
              tableGroup: update.tableGroup,
              // The engagement controller owns optimistic and confirmed writes;
              // a periodic source read must not revert an in-flight like.
              likeCount: share.likeCount,
              commentCount: share.commentCount,
              likedByMe: share.likedByMe,
            ),
          ),
        );
      }
      if (changed) {
        entries = List.unmodifiable(refreshed);
        _projectEvents();
        notifyListeners();
      }
      return true;
    } catch (_) {
      // Automatic freshness is best effort; keep the last confirmed page and
      // allow the shared scheduler to retry with backoff.
      return false;
    }
  }

  static bool _sameTableSource(
    TableGroupProfileShareSource a,
    TableGroupProfileShareSource b,
  ) =>
      a.id == b.id &&
      a.status == b.status &&
      a.description == b.description &&
      a.venueName == b.venueName &&
      a.cityName == b.cityName &&
      a.districtName == b.districtName &&
      a.meetingAt == b.meetingAt &&
      a.expiresAt == b.expiresAt &&
      a.maxPersonCount == b.maxPersonCount &&
      a.acceptedCount == b.acceptedCount;

  /// Store a confirmed interaction in the owning page before its lazy tile
  /// recycles. Old publications and old sessions cannot update replacements.
  void updateTableGroupEngagement({
    required AuthSession expectedSession,
    required TableGroupProfileShare expectedShare,
    required InteractionStatsItemState stats,
  }) {
    if (!containsTableShare(expectedSession, expectedShare) ||
        stats.loading ||
        stats.error != null ||
        !stats.hasLikeCount ||
        !stats.hasCommentCount) {
      return;
    }
    final updated = TableGroupProfileShare(
      shareId: expectedShare.shareId,
      note: expectedShare.note,
      publishedAt: expectedShare.publishedAt,
      tableGroup: expectedShare.tableGroup,
      likeCount: stats.likeCount,
      commentCount: stats.commentCount,
      likedByMe: stats.isLiked,
    );
    entries = List.unmodifiable([
      for (final entry in entries)
        if (identical(entry.tableShare, expectedShare))
          ListenerProfileFeedEntry.tableGroup(updated)
        else
          entry,
    ]);
    notifyListeners();
  }

  /// Keep confirmed wrapper engagement in the feed that owns a lazy row.
  /// Exact publication identity also makes a newer page/session win over a
  /// late response, including a response from an offscreen tile.
  void updateOverthinkingEngagement({
    required AuthSession expectedSession,
    required OverthinkingProfileShare expectedShare,
    required InteractionStatsItemState stats,
  }) {
    if (!containsShare(expectedSession, expectedShare) ||
        stats.loading ||
        stats.error != null ||
        !stats.hasLikeCount ||
        !stats.hasCommentCount) {
      return;
    }
    final publication = expectedShare.copyWithEngagement(
      likeCount: stats.likeCount,
      commentCount: stats.commentCount,
      likedByMe: stats.isLiked,
    );
    entries = List.unmodifiable([
      for (final entry in entries)
        if (identical(entry.share, expectedShare))
          ListenerProfileFeedEntry.overthinking(publication)
        else
          entry,
    ]);
    notifyListeners();
  }

  void forgetShare(String shareId) => _forget('overthinking:$shareId');

  void _forget(String key) {
    if (_closed) return;
    _removed.add(key);
    entries = List.unmodifiable(entries.where((entry) => entry.key != key));
    _projectEvents();
    notifyListeners();
  }

  Future<void> _load({
    required bool append,
    bool retryOrderChange = true,
    int? targetCount,
    bool replacePrefix = false,
  }) async {
    if (_closed) return;
    final generation = ++_epoch;
    final session = _session;
    _retryAppend = append;
    loading = !append && allowed;
    loadingMore = append && allowed;
    error = null;
    notifyListeners();
    if (!allowed) return;

    // Work on copies: a partial request failure cannot consume buffered rows
    // or move either source's cursor beyond the last committed visible page.
    final events = replacePrefix ? _SourceBuffer() : _events.copy();
    final overthinking = replacePrefix ? _SourceBuffer() : _overthinking.copy();
    final tables = replacePrefix ? _SourceBuffer() : _tables.copy();
    final additions = <ListenerProfileFeedEntry>[];
    final seen = {
      if (append)
        for (final entry in entries) entry.key,
    };
    try {
      while (additions.length < (targetCount ?? pageSize)) {
        await Future.wait([
          _fill(
            events,
            kind: _FeedSource.events,
            session: session,
            generation: generation,
          ),
          _fill(
            overthinking,
            kind: _FeedSource.overthinking,
            session: session,
            generation: generation,
          ),
          _fill(
            tables,
            kind: _FeedSource.tableGroup,
            session: session,
            generation: generation,
          ),
        ]);
        if (!_current(generation, session)) return;
        final ready =
            [
              events,
              overthinking,
              tables,
            ].where((source) => source.items.isNotEmpty).toList()..sort(
              (a, b) => ListenerProfileFeedEntry.compare(
                a.items.first,
                b.items.first,
              ),
            );
        if (ready.isEmpty) break;
        final entry = ready.first.items.removeAt(0);
        if (_removed.contains(entry.key) || !seen.add(entry.key)) continue;
        final tail = additions.isNotEmpty
            ? additions.last
            : append && entries.isNotEmpty
            ? entries.last
            : null;
        if (tail != null && ListenerProfileFeedEntry.compare(tail, entry) > 0) {
          // Offset pages can shift when another device publishes during a
          // read. Start from both current heads instead of appending a newer
          // item underneath the old tail. Retry once to bound busy accounts.
          throw const _FeedOrderChanged();
        }
        additions.add(entry);
      }
      if (!_current(generation, session)) return;
      _events = events;
      _overthinking = overthinking;
      _tables = tables;
      entries = List.unmodifiable([
        if (append) ...entries,
        ...additions.where((entry) => !_removed.contains(entry.key)),
      ]);
      _projectEvents();
      hasNext =
          events.hasItemsOrNext ||
          overthinking.hasItemsOrNext ||
          tables.hasItemsOrNext;
      page = append ? page + 1 : (entries.length - 1) ~/ pageSize;
      loading = false;
      loadingMore = false;
      _retryAppend = false;
      notifyListeners();
    } catch (failure) {
      if (!_current(generation, session)) return;
      if (failure is _FeedOrderChanged && retryOrderChange) {
        if (replacePrefix) {
          await _load(
            append: false,
            targetCount: targetCount,
            replacePrefix: true,
            retryOrderChange: false,
          );
        } else {
          await _reload(retryOrderChange: false);
        }
        return;
      }
      final appError = failure is _FeedReadFailure ? failure.error : null;
      final denied = _isDenied(appError?.code);
      if (!append || denied) {
        entries = const [];
        rows = const [];
        hasNext = false;
        _events = _SourceBuffer();
        _overthinking = _SourceBuffer();
        _tables = _SourceBuffer();
        _retryAppend = false;
      }
      error = failure is _FeedOrderChanged
          ? 'Paylaşımlar güncellendi. Listeyi yenileyip yeniden dene.'
          : appError?.message ?? 'Paylaşımlar yüklenemedi. Yeniden dene.';
      loading = false;
      loadingMore = false;
      notifyListeners();
    }
  }

  Future<void> _fill(
    _SourceBuffer source, {
    required _FeedSource kind,
    required AuthSession session,
    required int generation,
  }) async {
    while (source.items.isEmpty && source.hasNext) {
      if (!_current(generation, session)) return;
      final requested = source.nextPage;
      if (requested > 1000) {
        source.hasNext = false;
        return;
      }
      if (kind == _FeedSource.events) {
        final result = await repository.listPublic(
          listenerProfileId,
          expectedSessionKey: session.userId!,
          period: EventAudiencePeriod.all,
          page: requested,
          size: pageSize,
        );
        final data = result.data;
        if (!_current(generation, session)) return;
        if (!result.isSuccess || data == null) {
          throw _FeedReadFailure(result.error);
        }
        source.items.addAll(
          data.items
              .where((post) => post.intent != EventAudienceStatus.none)
              .map(ListenerProfileFeedEntry.event),
        );
        source.hasNext = data.hasNext && requested < 1000;
      } else if (kind == _FeedSource.overthinking) {
        final result = await overthinkingRepository.listProfile(
          profileId: listenerProfileId,
          expectedSession: session,
          page: requested,
          size: pageSize,
        );
        final data = result.data;
        if (!_current(generation, session)) return;
        if (!result.isSuccess || data == null) {
          throw _FeedReadFailure(result.error);
        }
        source.items.addAll(
          data.items.map(ListenerProfileFeedEntry.overthinking),
        );
        source.hasNext = data.hasNext && requested < 1000;
      } else {
        final tables = tableGroupRepository;
        if (tables == null) {
          source.hasNext = false;
          return;
        }
        final result = await tables.listProfile(
          profileId: listenerProfileId,
          expectedSession: session,
          page: requested,
          size: pageSize,
        );
        final data = result.data;
        if (!_current(generation, session)) return;
        if (!result.isSuccess || data == null) {
          throw _FeedReadFailure(result.error);
        }
        source.items.addAll(
          data.items.map(ListenerProfileFeedEntry.tableGroup),
        );
        source.hasNext = data.hasNext && requested < 1000;
      }
      source.nextPage = requested + 1;
      source.items.sort(ListenerProfileFeedEntry.compare);
    }
  }

  void _projectEvents() {
    rows = List.unmodifiable(
      entries.map((entry) => entry.eventRow).whereType<ListenerEventFeedRow>(),
    );
  }

  bool _current(int generation, AuthSession session) =>
      !_closed &&
      generation == _epoch &&
      identical(_session, session) &&
      identical(sessions.session, session) &&
      allowed;

  static bool _isDenied(String? code) => const {
    '401',
    '403',
    '404',
    '1101',
    '1102',
    '1103',
    '1301',
    '1308',
    '9401',
    '9415',
    'api_session_fence',
    'event_audience_session_changed',
    'overthinking_profile_share_session_changed',
    'table_group_profile_share_session_changed',
  }.contains(code);

  void _onSessionChanged() {
    if (!identical(_session, sessions.session)) unawaited(reload());
  }

  void _onDataChanged() => unawaited(revalidate());

  @override
  void dispose() {
    if (_closed) return;
    _closed = true;
    ++_epoch;
    sessions.removeListener(_onSessionChanged);
    repository.changes.removeListener(_onDataChanged);
    overthinkingRepository.changes.removeListener(_onDataChanged);
    tableGroupRepository?.changes.removeListener(_onDataChanged);
    super.dispose();
  }
}

enum _FeedSource { events, overthinking, tableGroup }

class _SourceBuffer {
  List<ListenerProfileFeedEntry> items = [];
  int nextPage = 0;
  bool hasNext = true;

  bool get hasItemsOrNext => items.isNotEmpty || hasNext;

  _SourceBuffer copy() => _SourceBuffer()
    ..items = List.of(items)
    ..nextPage = nextPage
    ..hasNext = hasNext;
}

class _FeedReadFailure implements Exception {
  const _FeedReadFailure(this.error);
  final AppError? error;
}

class _FeedOrderChanged implements Exception {
  const _FeedOrderChanged();
}
