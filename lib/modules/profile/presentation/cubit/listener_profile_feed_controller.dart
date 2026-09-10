import 'dart:async';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/error/app_error.dart';
import '../../../event_audience/domain/event_audience_repository.dart';
import '../../../overthinking/domain/overthinking_profile_share_repository.dart';
import 'listener_event_feed_controller.dart';

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
      share = null;

  ListenerProfileFeedEntry.overthinking(OverthinkingProfileShare publication)
    : key = 'overthinking:${publication.shareId}',
      publishedAt = publication.publishedAt,
      eventRow = null,
      share = publication;

  final String key;
  final DateTime publishedAt;
  final ListenerEventFeedRow? eventRow;
  final OverthinkingProfileShare? share;

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
    return second.share!.shareId.compareTo(first.share!.shareId);
  }
}

/// Merges the next heads of two independently paginated, descending streams.
/// A source must have a known head (or be exhausted) before another row can be
/// shown. Otherwise an older row could appear before an unfetched newer share.
class ListenerProfileFeedController extends ListenerEventFeedController {
  ListenerProfileFeedController({
    required EventAudienceRepository eventsRepository,
    required this.overthinkingRepository,
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
  }

  final OverthinkingProfileShareRepository overthinkingRepository;
  List<ListenerProfileFeedEntry> entries = const [];
  bool loadingMore = false;
  AuthSession _session = const AuthSession.guest();
  _SourceBuffer _events = _SourceBuffer();
  _SourceBuffer _overthinking = _SourceBuffer();
  final Set<String> _removed = {};
  int _epoch = 0;
  bool _closed = false;
  bool _retryAppend = false;

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
    if (!identical(_session, sessions.session)) _removed.clear();
    _session = sessions.session;
    ++_epoch;
    _events = _SourceBuffer();
    _overthinking = _SourceBuffer();
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

  void forgetShare(String shareId) {
    if (_closed) return;
    final key = 'overthinking:$shareId';
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
            eventsSource: true,
            session: session,
            generation: generation,
          ),
          _fill(
            overthinking,
            eventsSource: false,
            session: session,
            generation: generation,
          ),
        ]);
        if (!_current(generation, session)) return;
        if (events.items.isEmpty && overthinking.items.isEmpty) break;
        final takeEvent =
            overthinking.items.isEmpty ||
            (events.items.isNotEmpty &&
                ListenerProfileFeedEntry.compare(
                      events.items.first,
                      overthinking.items.first,
                    ) <=
                    0);
        final entry = (takeEvent ? events : overthinking).items.removeAt(0);
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
      entries = List.unmodifiable([
        if (append) ...entries,
        ...additions.where((entry) => !_removed.contains(entry.key)),
      ]);
      _projectEvents();
      hasNext = events.hasItemsOrNext || overthinking.hasItemsOrNext;
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
    required bool eventsSource,
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
      if (eventsSource) {
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
      } else {
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
    super.dispose();
  }
}

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
