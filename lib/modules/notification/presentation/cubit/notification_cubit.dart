import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/auth/token_store.dart';
import '../../../../core/error/result.dart';
import '../../data/notification_auth_support.dart';
import '../../data/notification_realtime_client.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/notification_audience_policy.dart';
import '../../domain/notification_repository.dart';
import 'notification_state.dart';

class NotificationCubit extends Cubit<NotificationState> {
  final NotificationRepository _repository;
  final TokenStore _tokenStore;
  final NotificationRealtimeClient _realtimeClient;
  final AuthSessionManager? _sessions;
  final Future<void> Function()? _onDeliveryStateChanged;
  final Duration _countReconciliationTimeout;
  AuthSession? _observedSession;
  bool _closing = false;

  NotificationCubit(
    this._repository,
    this._tokenStore, {
    NotificationRealtimeClient? realtimeClient,
    AuthSessionManager? sessions,
    Future<void> Function()? onDeliveryStateChanged,
    Duration countReconciliationTimeout = const Duration(seconds: 15),
  }) : _realtimeClient = realtimeClient ?? NotificationRealtimeClient(),
       _sessions = sessions,
       _onDeliveryStateChanged = onDeliveryStateChanged,
       _countReconciliationTimeout = countReconciliationTimeout,
       super(const NotificationState.initial()) {
    _realtimeClient.retain();
    _observedSession = _sessions?.session;
    _sessions?.addListener(_onSessionChanged);
  }

  bool get _listener =>
      _sessions?.session.hasAnyRole(const ['LISTENER', 'ROLE_LISTENER']) ==
      true;

  bool _canShowNotification(AppNotification notification) {
    final session = _sessions?.session;
    if (session != null &&
        (!session.isAuthenticated ||
            !session.isActive ||
            session.requiresListenerProfileChoice ||
            session.userId != notification.recipientId.trim())) {
      return false;
    }
    return !_listener ||
        NotificationAudiencePolicy.visibleToListener(notification.type);
  }

  void _onSessionChanged() {
    final session = _sessions!.session;
    final previous = _observedSession;
    _observedSession = session;
    if (previous?.userId == session.userId &&
        previous?.token == session.token &&
        previous?.isActive == session.isActive &&
        previous?.requiresListenerProfileChoice ==
            session.requiresListenerProfileChoice &&
        previous?.roles.join('|') == session.roles.join('|')) {
      return;
    }
    // Clear the old audience synchronously, before socket cancellation or any
    // pending REST/mutation can complete. stop also fences those callbacks.
    emit(const NotificationState.initial());
    unawaited(_restartForSession());
  }

  Future<void> _restartForSession() async {
    await stop();
    if (_closing || isClosed) return;
    final session = _sessions!.session;
    if (session.isAuthenticated &&
        session.isActive &&
        !session.requiresListenerProfileChoice) {
      await ensureStarted();
    }
  }

  Future<String?> _currentUserId() async {
    final session = _sessions?.session;
    if (session == null) return resolveNotificationUserId(_tokenStore);
    return session.isAuthenticated &&
            session.isActive &&
            !session.requiresListenerProfileChoice
        ? session.userId
        : null;
  }

  StreamSubscription<AppNotification>? _notificationSubscription;
  StreamSubscription<int>? _badgeSubscription;
  StreamSubscription<void>? _connectionSubscription;
  String? _startedUserId;
  Future<void>? _startInFlight;
  Future<void>? _stopInFlight;
  Future<void>? _resumeReconciliationInFlight;
  Future<void>? _gapReconciliationInFlight;
  int? _gapReconciliationGeneration;
  bool _gapReconciliationQueued = false;
  Timer? _badgeReconciliationTimer;
  int _lifecycleGeneration = 0;
  int _sessionRevision = 0;
  int _refreshSequence = 0;
  int _realtimeRevision = 0;
  int _badgeRevision = 0;
  // Local deltas fence stale REST responses, but do not replace each other's
  // contribution. Only a displayed server count supersedes an in-flight delta.
  int _serverCountRevision = 0;
  // Count-only events can already include a pending ACK. Page refreshes also
  // carry per-row read proof: an unread snapshot must still accept a later ACK.
  int _countOnlyRevision = 0;
  Future<void>? _countReconciliationInFlight;
  Completer<void>? _countReconciliationCancellation;
  bool _countReconciliationNeeded = false;
  int _confirmedCountMutationRevision = 0;
  static const _pageSize = 20;
  // Offset pages move left after a successful deletion. The last accepted
  // page remembers the deletion revision at request start; later successes
  // rewind its next boundary without dropping rows the user already loaded.
  int _paginationDeletionRevision = 0;
  int _paginationDeletionBaseline = 0;
  int? _paginationRepairPage;
  int? _paginationRepairThroughPage;
  // A successful refresh replaces the loaded pagination window while DELETE
  // may still be pending. Keep its boundary and whether that window has more
  // rows together, rather than retaining only DELETE's original terminal flag.
  final Map<String, ({int offset, bool hasNext})> _pendingDeletionBoundaries =
      {};
  final Map<String, int> _realtimeRevisionById = <String, int>{};
  // Confirmed reads are monotonic for an ID in this session. Neither an offset
  // page nor an unversioned socket frame proves an absent ID can be forgotten.
  // Keep only distinct IDs (no payloads), until deletion or session teardown;
  // TTL/LRU eviction would allow a delayed unread frame to undo a valid ACK.
  final Set<String> _confirmedReadIds = <String>{};
  // A successful DM ACK can precede this notification's first loaded page.
  // Retain its message identity for delayed pages/frames in this session too.
  final Set<String> _confirmedDmMessageIds = <String>{};
  final Set<String> _pendingDeletionIds = <String>{};
  // Shared by overlapping deletions so removing two top rows cannot capture
  // the same rollback index. Keep server/display order, including timestamp ties.
  List<String>? _pendingDeletionOrder;
  // Includes failed rows restored beyond page zero until a later page supplies
  // their position. DELETE completion alone does not retire that ordering gap.
  final Set<String> _offPageDeletionIds = <String>{};
  final Set<String> _deletedNotificationIds = <String>{};
  // A clear-all response has no server deletion watermark. Afterwards, REST
  // must verify unknown realtime IDs: a delayed pre-clear frame may be deleted.
  bool _verifyRealtimeAfterClear = false;
  // Bulk read has no ID watermark. A later unread creation frame may refer to
  // a now-read ID outside the refreshed first page. Verify such frames through
  // the same bounded REST reconciliation used after a realtime gap.
  bool _verifyUnreadRealtimeAfterBulkRead = false;
  Object? _clearOperation;

  Future<void> ensureStarted() async {
    final stopInFlight = _stopInFlight;
    if (stopInFlight != null) await stopInFlight;
    final requestGeneration = _lifecycleGeneration;
    final inFlight = _startInFlight;
    if (inFlight != null) {
      await inFlight;
      if (!_isCurrent(requestGeneration)) return;
    }
    if (!_isCurrent(requestGeneration)) return;
    final startFuture = _ensureStartedInternal(requestGeneration);
    _startInFlight = startFuture;
    try {
      await startFuture;
    } finally {
      if (identical(_startInFlight, startFuture)) {
        _startInFlight = null;
      }
    }
  }

  Future<void> _ensureStartedInternal(int generation) async {
    final currentUserId = await _currentUserId();
    if (!_isCurrent(generation)) return;
    if (currentUserId == null || currentUserId.trim().isEmpty) {
      if (_startedUserId != null) _sessionRevision += 1;
      _startedUserId = null;
      _realtimeRevisionById.clear();
      _confirmedReadIds.clear();
      _confirmedDmMessageIds.clear();
      _cancelCountReconciliation();
      _pendingDeletionIds.clear();
      _pendingDeletionOrder = null;
      _offPageDeletionIds.clear();
      _deletedNotificationIds.clear();
      _verifyRealtimeAfterClear = false;
      _verifyUnreadRealtimeAfterBulkRead = false;
      _clearOperation = null;
      _paginationDeletionRevision = 0;
      _paginationDeletionBaseline = 0;
      _paginationRepairPage = null;
      _paginationRepairThroughPage = null;
      _pendingDeletionBoundaries.clear();
      emit(const NotificationState.initial().copyWith(initialized: true));
      return;
    }
    if (_startedUserId == currentUserId && state.initialized) return;
    final switchingUser = _startedUserId != null;
    _sessionRevision += 1;
    _startedUserId = currentUserId;
    _realtimeRevisionById.clear();
    _confirmedReadIds.clear();
    _confirmedDmMessageIds.clear();
    _cancelCountReconciliation();
    _pendingDeletionIds.clear();
    _pendingDeletionOrder = null;
    _offPageDeletionIds.clear();
    _deletedNotificationIds.clear();
    _verifyRealtimeAfterClear = false;
    _verifyUnreadRealtimeAfterBulkRead = false;
    _clearOperation = null;
    _paginationDeletionRevision = 0;
    _paginationDeletionBaseline = 0;
    _paginationRepairPage = null;
    _paginationRepairThroughPage = null;
    _pendingDeletionBoundaries.clear();
    if (switchingUser) emit(const NotificationState.initial());

    await _notificationSubscription?.cancel();
    await _badgeSubscription?.cancel();
    await _connectionSubscription?.cancel();
    if (!_isCurrent(generation)) return;
    _notificationSubscription = null;
    _badgeSubscription = null;
    _connectionSubscription = null;
    if (switchingUser) {
      await _realtimeClient.disconnect();
      if (!_isCurrent(generation)) return;
    }

    final subscriptionSessionRevision = _sessionRevision;
    _notificationSubscription = _realtimeClient.notificationStream.listen((
      notification,
    ) {
      if (_isCurrentSession(generation, subscriptionSessionRevision)) {
        _onRealtimeNotification(notification);
      }
    });
    _badgeSubscription = _realtimeClient.badgeStream.listen((count) {
      if (_isCurrentSession(generation, subscriptionSessionRevision)) {
        if (_verifyRealtimeAfterClear || _listener) {
          // A count-only frame cannot identify its audience. Reconcile through
          // the server's current recipient/type projection before displaying it.
          _scheduleBadgeReconciliation(generation, subscriptionSessionRevision);
          return;
        }
        final shouldReconcile = state.initialized;
        _badgeRevision += 1;
        _serverCountRevision += 1;
        _countOnlyRevision += 1;
        emit(state.copyWith(unreadCount: count.clamp(0, 999999)));
        if (shouldReconcile) {
          _scheduleBadgeReconciliation(generation, subscriptionSessionRevision);
        }
      }
    });
    var observedConnection = _realtimeClient.isConnected;
    _connectionSubscription = _realtimeClient.connectionStream.listen((_) {
      if (!_isCurrentSession(generation, subscriptionSessionRevision)) return;
      if (!observedConnection) {
        observedConnection = true;
        return;
      }
      // An explicit foreground reconciliation already performs its own
      // authoritative REST refresh after reconnecting. The connection frame
      // is the same event, not a second gap that needs another request.
      if (_resumeReconciliationInFlight != null) return;
      unawaited(_reconcileAfterRealtimeGap(generation));
    });

    await _connectRealtimeIfNeeded(currentUserId, generation);
    // stop() already retires the previous generation's transport. An old
    // token read or handshake may finish after the next account connected;
    // it must not disconnect that account's shared realtime client.
    if (!_isCurrent(generation)) return;
    await _reconcileAfterRealtimeGap(generation);
  }

  Future<void> _reconcileAfterRealtimeGap(int generation) {
    final inFlight = _gapReconciliationInFlight;
    if (inFlight != null && _gapReconciliationGeneration == generation) {
      _gapReconciliationQueued = true;
      return inFlight;
    }
    if (!_isCurrent(generation)) return Future<void>.value();

    final operation = _runGapReconciliationLoop(generation);
    _gapReconciliationInFlight = operation;
    _gapReconciliationGeneration = generation;
    return operation.whenComplete(() {
      if (identical(_gapReconciliationInFlight, operation)) {
        _gapReconciliationInFlight = null;
        _gapReconciliationGeneration = null;
      }
    });
  }

  Future<void> _runGapReconciliationLoop(int generation) async {
    do {
      _gapReconciliationQueued = false;
      final sessionRevision = _sessionRevision;
      await _refresh(generation, sessionRevision: sessionRevision);
      if (_isCurrent(generation) && sessionRevision != _sessionRevision) {
        _gapReconciliationQueued = true;
      }
    } while (_gapReconciliationQueued && _isCurrent(generation));
  }

  void _scheduleBadgeReconciliation(int generation, int sessionRevision) {
    _badgeReconciliationTimer?.cancel();
    _badgeReconciliationTimer = Timer(const Duration(milliseconds: 250), () {
      _badgeReconciliationTimer = null;
      if (_isCurrentSession(generation, sessionRevision)) {
        unawaited(_reconcileAfterRealtimeGap(generation));
      }
    });
  }

  Future<void> refresh() =>
      _refresh(_lifecycleGeneration, sessionRevision: _sessionRevision);

  /// Reconciles notifications after the app returns to the foreground.
  ///
  /// Mobile platforms may suspend the realtime socket while the app is in the
  /// background. Reconnecting and refreshing are deliberately independent so
  /// a websocket outage never prevents the REST-backed list and badge from
  /// catching up.
  Future<void> reconcileAfterResume() {
    final inFlight = _resumeReconciliationInFlight;
    if (inFlight != null) return inFlight;

    final operation = _reconcileAfterResumeInternal();
    _resumeReconciliationInFlight = operation;
    return operation.whenComplete(() {
      if (identical(_resumeReconciliationInFlight, operation)) {
        _resumeReconciliationInFlight = null;
      }
    });
  }

  Future<void> _reconcileAfterResumeInternal() async {
    final generation = _lifecycleGeneration;
    final startInFlight = _startInFlight;
    if (startInFlight != null) await startInFlight;
    if (!_isCurrent(generation)) return;

    final currentUserId = await _currentUserId();
    if (!_isCurrent(generation)) return;
    if (currentUserId == null || currentUserId.trim().isEmpty) {
      await stop();
      return;
    }
    if (_startedUserId != currentUserId || !state.initialized) {
      await ensureStarted();
      return;
    }

    await _connectRealtimeIfNeeded(currentUserId, generation);
    if (!_isCurrent(generation)) return;
    await _refresh(generation, sessionRevision: _sessionRevision);
  }

  Future<void> _connectRealtimeIfNeeded(String userId, int generation) async {
    if (!_isCurrent(generation) || _realtimeClient.isConnected) return;
    final token = await readNotificationAuthToken(_tokenStore);
    if (!_isCurrent(generation) || token == null) return;
    try {
      await _realtimeClient.connect(userId: userId, token: token);
    } catch (_) {
      // REST notifications remain available when realtime is unavailable.
    }
  }

  Future<void> _refresh(int generation, {required int sessionRevision}) async {
    if (!_isCurrentSession(generation, sessionRevision)) return;
    final requestSequence = ++_refreshSequence;
    final realtimeRevisionAtStart = _realtimeRevision;
    final badgeRevisionAtStart = _badgeRevision;
    final deletionRevisionAtStart = _paginationDeletionRevision;
    emit(
      state.copyWith(
        status: NotificationStatus.loading,
        clearError: true,
        initialized: true,
      ),
    );
    final pageResult = await _repository.listNotifications(size: _pageSize);
    if (!_isCurrentSessionRefresh(
      generation,
      sessionRevision,
      requestSequence,
    )) {
      return;
    }
    final unreadResult = await _repository.getUnreadCount();
    if (!_isCurrentSessionRefresh(
      generation,
      sessionRevision,
      requestSequence,
    )) {
      return;
    }

    if (!pageResult.isSuccess || pageResult.data == null) {
      emit(
        state.copyWith(
          status: NotificationStatus.failure,
          errorMessage: pageResult.error?.message ?? 'Bildirimler getirilemedi',
          initialized: true,
        ),
      );
      return;
    }

    // A successful bulk read returns a count, not an ID watermark. Learn only
    // the server's explicit read projections; never infer read for new arrivals.
    // Remember them before merging: a delayed creation frame may have arrived
    // during this request and therefore take precedence over the REST row.
    _rememberReadProjections(pageResult.data!.items);
    final realtimeItems = state.items
        .where(
          (item) =>
              (_realtimeRevisionById[item.id] ?? 0) > realtimeRevisionAtStart,
        )
        .map(_withConfirmedRead);
    final pageItems = pageResult.data!.items.map(_withConfirmedRead);
    final orderedItems = _mergeById(<AppNotification>[
      ...realtimeItems,
      ...pageItems,
    ]).where(_canShowNotification).toList();
    final mergedItems = orderedItems
        .where((item) => !_isDeleted(item.id))
        .toList();
    final deletionOrder = _pendingDeletionOrder;
    _offPageDeletionIds.clear();
    if (deletionOrder != null) {
      final latestIds = orderedItems.map((item) => item.id).toList();
      // An older pending row may have moved beyond the refreshed first page.
      final offPagePendingIds = deletionOrder
          .where(
            (id) => _pendingDeletionIds.contains(id) && !latestIds.contains(id),
          )
          .toList();
      _offPageDeletionIds.addAll(offPagePendingIds);
      deletionOrder
        ..clear()
        ..addAll(latestIds)
        ..addAll(offPagePendingIds);
    }
    final mergedIds = mergedItems.map((item) => item.id).toSet();
    _realtimeRevisionById.removeWhere((id, _) => !mergedIds.contains(id));

    final badgeChangedDuringRefresh = _badgeRevision > badgeRevisionAtStart;
    var unreadCount = badgeChangedDuringRefresh
        ? state.unreadCount
        : unreadResult.data ?? state.unreadCount;
    if (!badgeChangedDuringRefresh) {
      final visibleUnreadCount = mergedItems.where((item) => !item.read).length;
      if (unreadCount < visibleUnreadCount) unreadCount = visibleUnreadCount;
      if (unreadResult.isSuccess && unreadResult.data != null) {
        _serverCountRevision += 1;
      }
    }

    _paginationDeletionBaseline = deletionRevisionAtStart;
    _paginationRepairPage = null;
    _paginationRepairThroughPage = null;
    _pendingDeletionBoundaries.updateAll(
      (_, boundary) => (
        offset: boundary.offset < _pageSize ? boundary.offset : _pageSize,
        hasNext: pageResult.data!.hasNext,
      ),
    );
    emit(
      state.copyWith(
        status: NotificationStatus.success,
        items: mergedItems,
        unreadCount: unreadCount.clamp(0, 999999),
        page: 0,
        hasNext: pageResult.data!.hasNext,
        clearError: true,
        initialized: true,
      ),
    );
  }

  Future<void> loadMore() async {
    if (!state.hasNext ||
        state.status == NotificationStatus.loading ||
        state.status == NotificationStatus.loadingMore) {
      return;
    }
    final generation = _lifecycleGeneration;
    final sessionRevision = _sessionRevision;
    final refreshSequence = _refreshSequence;
    final deletionRevisionAtStart = _paginationDeletionRevision;
    final deletedSincePage =
        deletionRevisionAtStart - _paginationDeletionBaseline;
    final previousBoundary = (state.page + 1) * _pageSize;
    var nextPage =
        (previousBoundary - deletedSincePage).clamp(0, previousBoundary) ~/
        _pageSize;
    final repairPage = _paginationRepairPage;
    if (repairPage != null && repairPage < nextPage) nextPage = repairPage;
    final repairThroughPage = _paginationRepairThroughPage;
    final repairingLoadedPages =
        repairThroughPage != null && nextPage <= repairThroughPage;
    emit(state.copyWith(status: NotificationStatus.loadingMore));
    final result = await _repository.listNotifications(
      page: nextPage,
      size: _pageSize,
    );
    if (!_isCurrentSession(generation, sessionRevision) ||
        !_isCurrentRefresh(generation, refreshSequence)) {
      return;
    }
    if (result.isSuccess &&
        _paginationDeletionRevision != deletionRevisionAtStart) {
      // This response may have selected its offset after DELETE committed.
      // Advancing to that page would lose the row which moved behind its
      // offset. Retry from the previous accepted boundary instead.
      emit(state.copyWith(status: NotificationStatus.success));
      await loadMore();
      return;
    }
    if (!result.isSuccess || result.data == null) {
      emit(
        state.copyWith(
          status: NotificationStatus.success,
          errorMessage: result.error?.message,
        ),
      );
      return;
    }
    // Offset pages can shift when a realtime notification is inserted between
    // page requests. Preserve the server order while suppressing an ID that
    // was already loaded (or repeated inside the response).
    // A duplicate row can still carry fresh read proof for an existing item.
    _rememberReadProjections(result.data!.items);
    final pageIds = result.data!.items
        .where(_canShowNotification)
        .where((item) => !_deletedNotificationIds.contains(item.id))
        .map((item) => item.id)
        .toSet();
    final retainedItems = state.items
        .where((item) => !_offPageDeletionIds.contains(item.id))
        .map(_withConfirmedRead)
        .toList();
    final unseenRestoredItems = state.items
        .where(
          (item) =>
              _offPageDeletionIds.contains(item.id) &&
              !pageIds.contains(item.id),
        )
        .map(_withConfirmedRead)
        .toList();
    final seenIds = retainedItems.map((item) => item.id).toSet();
    final uniqueNextItems = result.data!.items
        .where((item) => !_isDeleted(item.id))
        .where(_canShowNotification)
        .where((item) => seenIds.add(item.id))
        .map(_withConfirmedRead)
        .toList(growable: false);
    final pageItems = result.data!.items
        .where((item) => !_isDeleted(item.id))
        .where(_canShowNotification)
        .map(_withConfirmedRead)
        .toList();
    final itemsById = {
      for (final item in pageItems) item.id: item,
      for (final item in retainedItems) item.id: item,
    };
    final mergedPageItems = _mergePageOrder(
      retainedItems.map((item) => item.id),
      pageItems.map((item) => item.id),
    ).map((id) => itemsById[id]!).toList();
    final deletionOrder = _pendingDeletionOrder;
    if (deletionOrder != null) {
      // A pending row omitted by page zero still needs its position learned
      // from later pages, even though it remains hidden until DELETE resolves.
      final unseenPendingIds = deletionOrder
          .where(
            (id) => _offPageDeletionIds.contains(id) && !pageIds.contains(id),
          )
          .toList();
      final mergedDeletionOrder = _mergePageOrder(
        deletionOrder.where((id) => !_offPageDeletionIds.contains(id)),
        pageIds,
      );
      deletionOrder
        ..clear()
        ..addAll(mergedDeletionOrder)
        ..addAll(unseenPendingIds);
    }
    _offPageDeletionIds.removeAll(pageIds);
    _paginationDeletionBaseline = deletionRevisionAtStart;
    _paginationRepairPage = null;
    if (repairThroughPage != null && nextPage >= repairThroughPage) {
      _paginationRepairThroughPage = null;
    }
    emit(
      state.copyWith(
        status: NotificationStatus.success,
        items: [...mergedPageItems, ...unseenRestoredItems],
        page: nextPage,
        hasNext: result.data!.hasNext,
        clearError: true,
      ),
    );
    if (uniqueNextItems.isEmpty &&
        result.data!.hasNext &&
        (deletedSincePage > 0 || repairPage != null || repairingLoadedPages)) {
      // An overlapping repair page can contain only already-loaded IDs.
      // Continue to new rows without requiring a second scroll gesture.
      await loadMore();
    }
  }

  Future<void> markAsRead(AppNotification notification) async {
    if (notification.read || !_canShowNotification(notification)) return;
    final generation = _lifecycleGeneration;
    final sessionRevision = _sessionRevision;
    final countOnlyRevision = _countOnlyRevision;
    final result = await _repository.markAsRead(
      notificationId: notification.id,
    );
    if (!_isCurrentSession(generation, sessionRevision)) return;
    if (!result.isSuccess) {
      emit(state.copyWith(errorMessage: result.error?.message));
      return;
    }
    unawaited(_notifyDeliveryStateChanged(generation, sessionRevision));
    // The row may have left the loaded page while ACK was in flight. Success
    // still protects its next projection, without guessing a badge decrement.
    if (!_deletedNotificationIds.contains(notification.id)) {
      _confirmedReadIds.add(notification.id);
    }
    var changed = false;
    final updatedItems = state.items.map((item) {
      if (item.id != notification.id || item.read) return item;
      changed = true;
      return item.copyWith(read: true);
    }).toList();
    if (!changed) return;
    final unreadCount = _countOnlyRevision == countOnlyRevision
        ? (state.unreadCount - 1).clamp(0, 999999)
        : state.unreadCount;
    _badgeRevision++;
    emit(
      state.copyWith(
        items: updatedItems,
        unreadCount: unreadCount,
        clearError: true,
      ),
    );
  }

  /// The exact external target was ACKed with a captured bearer. Reconcile
  /// the OS immediately, then fetch the authoritative badge even if this item
  /// was never in the currently loaded inbox page.
  Future<void> applyConfirmedExternalRead(
    AppNotification notification,
    AuthSession session,
  ) async {
    if (!identical(_sessions?.session, session) ||
        !_canShowNotification(notification) ||
        _closing ||
        isClosed) {
      return;
    }
    final generation = _lifecycleGeneration;
    final revision = _sessionRevision;
    final newlyConfirmed =
        !_deletedNotificationIds.contains(notification.id) &&
        _confirmedReadIds.add(notification.id);
    if (newlyConfirmed) _badgeRevision += 1;
    emit(
      state.copyWith(
        items: state.items
            .map(
              (item) =>
                  item.id == notification.id ? item.copyWith(read: true) : item,
            )
            .toList(),
      ),
    );
    unawaited(_notifyDeliveryStateChanged(generation, revision));
    await _reconcileConfirmedCount(
      generation,
      revision,
      newMutation: newlyConfirmed,
    );
  }

  void markDmConversationAsReadLocally(String conversationId) {
    final normalizedConversationId = conversationId.trim();
    if (normalizedConversationId.isEmpty) return;

    var changedCount = 0;
    final updatedItems = state.items.map((item) {
      final module = item.payload['module']?.toString().trim() ?? '';
      final itemConversationId =
          item.payload['conversationId']?.toString().trim() ?? '';
      final isDmNotification = module == 'DM' || item.type.startsWith('DM');
      if (!item.read &&
          isDmNotification &&
          itemConversationId == normalizedConversationId) {
        changedCount += 1;
        _confirmedReadIds.add(item.id);
        return item.copyWith(read: true);
      }
      return item;
    }).toList();

    if (changedCount == 0) return;
    _badgeRevision++;
    emit(
      state.copyWith(
        items: updatedItems,
        unreadCount: (state.unreadCount - changedCount).clamp(0, 999999),
        clearError: true,
      ),
    );
  }

  /// Called only after this particular message's explicit read ACK succeeds.
  /// A page load is not acknowledgement for older or concurrently arriving DMs.
  Future<void> markDmMessageAsReadLocally(String messageId) async {
    final id = messageId.trim();
    if (_closing || isClosed || id.isEmpty) return;
    final newlyConfirmed = _confirmedDmMessageIds.add(id);
    final items = state.items.map((item) {
      if (!item.read &&
          item.type == 'DM_NEW_MESSAGE' &&
          item.payload['messageId']?.toString().trim() == id) {
        _confirmedReadIds.add(item.id);
        return item.copyWith(read: true);
      }
      return item;
    }).toList();
    if (newlyConfirmed) _badgeRevision += 1;
    emit(state.copyWith(items: items));
    // A count received before this callback may already include the committed
    // read. Loaded row changes cannot tell us whether to subtract from it.
    if (newlyConfirmed || _countReconciliationNeeded) {
      await _reconcileConfirmedCount(
        _lifecycleGeneration,
        _sessionRevision,
        newMutation: newlyConfirmed,
      );
    }
  }

  Future<void> markAllAsRead() async {
    final generation = _lifecycleGeneration;
    final sessionRevision = _sessionRevision;
    final result = await _repository.markAllAsRead();
    if (!_isCurrentSession(generation, sessionRevision)) return;
    if (!result.isSuccess) {
      // Opening the inbox must still load its contents if marking read fails.
      await _refresh(generation, sessionRevision: sessionRevision);
      if (!_isCurrentSession(generation, sessionRevision)) return;
      emit(state.copyWith(errorMessage: result.error?.message));
      return;
    }
    unawaited(_notifyDeliveryStateChanged(generation, sessionRevision));
    _verifyUnreadRealtimeAfterBulkRead = true;
    _badgeRevision += 1;
    _confirmedCountMutationRevision += 1;
    // Retire pre-mutation refresh/page responses before joining their queued
    // reconciliation. A failed follow-up must not expose an older unread page.
    _refreshSequence += 1;
    await _reconcileAfterRealtimeGap(generation);
  }

  Future<void> deleteNotification(AppNotification notification) async {
    final generation = _lifecycleGeneration;
    final sessionRevision = _sessionRevision;
    final currentIndex = state.items.indexWhere(
      (item) => item.id == notification.id,
    );
    if (currentIndex < 0 || !_pendingDeletionIds.add(notification.id)) return;
    final deletionOrder = _pendingDeletionOrder ??= state.items
        .map((item) => item.id)
        .toList();
    final serverCountRevision = _serverCountRevision;
    _badgeRevision += 1;
    final currentNotification = state.items[currentIndex];
    final boundary = (state.page + 1) * _pageSize;
    _pendingDeletionBoundaries[notification.id] = (
      offset:
          (boundary -
                  (_paginationDeletionRevision - _paginationDeletionBaseline))
              .clamp(0, boundary),
      hasNext: state.hasNext,
    );
    final realtimeRevision = _realtimeRevisionById.remove(notification.id);
    emit(
      state.copyWith(
        items: state.items.where((item) => item.id != notification.id).toList(),
        unreadCount: currentNotification.read
            ? state.unreadCount
            : (state.unreadCount - 1).clamp(0, 999999),
        clearError: true,
      ),
    );
    final result = await _repository.deleteNotification(
      notificationId: notification.id,
    );
    if (!_isCurrentSession(generation, sessionRevision)) return;
    if (!result.isSuccess) {
      _finishPendingDeletion(
        notification.id,
        restore: !_deletedNotificationIds.contains(notification.id),
      );
      if (_deletedNotificationIds.contains(notification.id)) return;
      if (realtimeRevision != null) {
        _realtimeRevisionById[notification.id] = realtimeRevision;
      }
      // An ACK may have succeeded while the optimistic deletion hid this row.
      // Restore its current read projection, including for badge rollback.
      final restoredNotification = _withConfirmedRead(currentNotification);
      final restoredItems = <AppNotification>[...state.items];
      if (!restoredItems.any((item) => item.id == notification.id)) {
        final followingIds = deletionOrder
            .skip(deletionOrder.indexOf(notification.id) + 1)
            .toSet();
        final nextIndex = restoredItems.indexWhere(
          (item) => followingIds.contains(item.id),
        );
        restoredItems.insert(
          nextIndex < 0 ? restoredItems.length : nextIndex,
          restoredNotification,
        );
      }
      emit(
        state.copyWith(
          items: restoredItems,
          unreadCount:
              !restoredNotification.read &&
                  _serverCountRevision == serverCountRevision
              ? (state.unreadCount + 1).clamp(0, 999999)
              : state.unreadCount,
          errorMessage: result.error?.message,
        ),
      );
      return;
    }
    unawaited(_notifyDeliveryStateChanged(generation, sessionRevision));
    final pendingBoundary = _pendingDeletionBoundaries[notification.id];
    final deletionBoundary = pendingBoundary?.offset ?? 0;
    _finishPendingDeletion(notification.id);
    if (_deletedNotificationIds.contains(notification.id)) return;
    // Keep a session-scoped tombstone: a page that was already in flight may
    // still contain the successfully deleted notification.
    _deletedNotificationIds.add(notification.id);
    _realtimeRevisionById.remove(notification.id);
    _confirmedReadIds.remove(notification.id);
    _paginationDeletionRevision += 1;
    // HTTP success can arrive after a next-page GET already observed the
    // committed deletion. Repair from the boundary saved before that DELETE,
    // not merely from the newest accepted page which may have skipped a row.
    final repairPage =
        (deletionBoundary - 1).clamp(0, deletionBoundary) ~/ _pageSize;
    if (_paginationRepairPage == null || repairPage < _paginationRepairPage!) {
      _paginationRepairPage = repairPage;
    }
    if (_paginationRepairThroughPage == null ||
        state.page > _paginationRepairThroughPage!) {
      _paginationRepairThroughPage = state.page;
    }
    if (pendingBoundary?.hasNext == true && !state.hasNext) {
      // A terminal page received while DELETE was pending may already have
      // skipped the boundary row, including after a refresh of a previously
      // complete inbox. Allow repair for that pagination window. A complete
      // refresh (or no refresh of a complete inbox) needs no extra page.
      emit(state.copyWith(hasNext: true));
    }
    // A refresh started before DELETE committed must not replace its local
    // count contribution when it finishes later. If a server count already
    // superseded that contribution, its snapshot may still include this row.
    _badgeRevision += 1;
    if (_serverCountRevision != serverCountRevision ||
        _countReconciliationNeeded) {
      final existingFlight = _countReconciliationInFlight;
      final reconciliation = _reconcileConfirmedCount(
        generation,
        sessionRevision,
      );
      // An existing read count will take a post-DELETE snapshot. Do not hold
      // this otherwise-complete DELETE behind that unrelated pending response.
      if (existingFlight == null ||
          _serverCountRevision != serverCountRevision) {
        await reconciliation;
      } else {
        unawaited(reconciliation);
      }
    }
  }

  Future<void> _reconcileConfirmedCount(
    int generation,
    int sessionRevision, {
    bool newMutation = true,
  }) {
    if (!_isCurrentSession(generation, sessionRevision)) {
      return Future<void>.value();
    }
    _countReconciliationNeeded = true;
    if (newMutation) _confirmedCountMutationRevision += 1;
    final inFlight = _countReconciliationInFlight;
    if (inFlight != null) return inFlight;
    final cancellation = Completer<void>();
    _countReconciliationCancellation = cancellation;
    final operation = _runCountReconciliation(
      generation,
      sessionRevision,
      cancellation,
    );
    _countReconciliationInFlight = operation;
    return operation.whenComplete(() {
      if (identical(_countReconciliationInFlight, operation)) {
        _countReconciliationInFlight = null;
        _countReconciliationCancellation = null;
      }
    });
  }

  Future<void> _runCountReconciliation(
    int generation,
    int sessionRevision,
    Completer<void> cancellation,
  ) async {
    // One shared flight. A newly confirmed mutation requires a snapshot taken
    // after its ACK; coalesce all such ACKs before the next request. In addition,
    // permit one contention retry for unversioned arrivals/other projections.
    // N additional confirmed mutations cost at most N+2 requests; an arrival
    // storm alone costs two. No timer polling or domain retry. Error/timeout
    // leaves the debt for a later mutation or existing badge/resume/refresh.
    var contentionRetryAvailable = true;
    while (_isCurrentSession(generation, sessionRevision)) {
      final mutationRevision = _confirmedCountMutationRevision;
      final serverRevision = _serverCountRevision;
      final badgeRevision = _badgeRevision;
      final realtimeRevision = _realtimeRevision;
      final timeout = Completer<Result<int>?>();
      final timer = Timer(
        _countReconciliationTimeout,
        () => timeout.complete(null),
      );
      Result<int>? result;
      try {
        result = await Future.any<Result<int>?>([
          _repository.getUnreadCount(),
          timeout.future,
          cancellation.future.then((_) => null),
        ]);
      } catch (_) {
        // A failed read-only projection does not undo the successful ACK or
        // leak an unobserved error through the synchronous DM callback.
        return;
      } finally {
        timer.cancel();
      }
      if (!_isCurrentSession(generation, sessionRevision) ||
          result == null ||
          !result.isSuccess ||
          result.data == null) {
        return;
      }
      if (_confirmedCountMutationRevision != mutationRevision) continue;
      // A newer local mutation/arrival may fall after this count's snapshot.
      // Read it again; never repeat DELETE or discard the loaded inbox rows.
      if (_badgeRevision != badgeRevision ||
          _realtimeRevision != realtimeRevision ||
          _serverCountRevision != serverRevision) {
        if (contentionRetryAvailable) {
          contentionRetryAvailable = false;
          continue;
        }
        return;
      }
      _serverCountRevision += 1;
      _countOnlyRevision += 1;
      _badgeRevision += 1;
      _countReconciliationNeeded = false;
      emit(state.copyWith(unreadCount: result.data!.clamp(0, 999999)));
      return;
    }
  }

  void _cancelCountReconciliation() {
    final cancellation = _countReconciliationCancellation;
    if (cancellation != null && !cancellation.isCompleted) {
      cancellation.complete();
    }
    _countReconciliationInFlight = null;
    _countReconciliationCancellation = null;
    _countReconciliationNeeded = false;
  }

  Future<void> clearAllNotifications() async {
    if (state.items.isEmpty || _clearOperation != null) return;
    final generation = _lifecycleGeneration;
    final sessionRevision = _sessionRevision;
    final operation = Object();
    _clearOperation = operation;
    final knownIds = {
      ...state.items.map((item) => item.id),
      ..._pendingDeletionIds,
    };
    try {
      final result = await _repository.clearAllNotifications();
      if (!_isCurrentSession(generation, sessionRevision)) return;
      if (!result.isSuccess) {
        emit(state.copyWith(errorMessage: result.error?.message));
        return;
      }
      unawaited(_notifyDeliveryStateChanged(generation, sessionRevision));
      _deletedNotificationIds.addAll(knownIds);
      _verifyRealtimeAfterClear = true;
      _realtimeRevisionById.clear();
      // An ACK of an unknown/new arrival may have completed during clear-all.
      // Without a server watermark, only the known deleted IDs can be retired.
      _confirmedReadIds.removeAll(_deletedNotificationIds);
      _badgeRevision++;
      emit(
        state.copyWith(
          items: state.items.where((item) => !_isDeleted(item.id)).toList(),
          unreadCount: 0,
          clearError: true,
        ),
      );
      await _refresh(generation, sessionRevision: sessionRevision);
    } finally {
      if (identical(_clearOperation, operation)) _clearOperation = null;
    }
  }

  Future<void> _notifyDeliveryStateChanged(
    int generation,
    int sessionRevision,
  ) async {
    if (!_isCurrentSession(generation, sessionRevision)) return;
    try {
      // Only confirmed server mutations reconcile the OS projection. Do not
      // block inbox updates or turn a failed OS comparison into a mutation error.
      await _onDeliveryStateChanged?.call();
    } catch (_) {
      // Reconciliation retries on resume; provider errors may contain secrets.
    }
  }

  Future<void> stop() {
    final inFlight = _stopInFlight;
    if (inFlight != null) return inFlight;

    final operation = _stopInternal();
    _stopInFlight = operation;
    return operation.whenComplete(() {
      if (identical(_stopInFlight, operation)) _stopInFlight = null;
    });
  }

  Future<void> _stopInternal() async {
    final generation = ++_lifecycleGeneration;
    _sessionRevision += 1;
    _refreshSequence += 1;
    _cancelCountReconciliation();
    _startedUserId = null;
    // A previous audience's network request may remain pending after logout.
    // Its generation is fenced; a new session must not wait for it to finish.
    _startInFlight = null;
    _resumeReconciliationInFlight = null;
    _badgeReconciliationTimer?.cancel();
    _badgeReconciliationTimer = null;
    _gapReconciliationQueued = false;
    await _notificationSubscription?.cancel();
    await _badgeSubscription?.cancel();
    await _connectionSubscription?.cancel();
    _notificationSubscription = null;
    _badgeSubscription = null;
    _connectionSubscription = null;
    await _realtimeClient.disconnect();
    _realtimeRevisionById.clear();
    _confirmedReadIds.clear();
    _confirmedDmMessageIds.clear();
    _pendingDeletionIds.clear();
    _pendingDeletionOrder = null;
    _offPageDeletionIds.clear();
    _deletedNotificationIds.clear();
    _verifyRealtimeAfterClear = false;
    _verifyUnreadRealtimeAfterBulkRead = false;
    _clearOperation = null;
    _paginationDeletionRevision = 0;
    _paginationDeletionBaseline = 0;
    _paginationRepairPage = null;
    _paginationRepairThroughPage = null;
    _pendingDeletionBoundaries.clear();
    if (_isCurrent(generation)) emit(const NotificationState.initial());
  }

  bool _isCurrent(int generation) {
    return !_closing && !isClosed && generation == _lifecycleGeneration;
  }

  bool _isDeleted(String id) =>
      _pendingDeletionIds.contains(id) || _deletedNotificationIds.contains(id);

  void _finishPendingDeletion(String id, {bool restore = false}) {
    _pendingDeletionIds.remove(id);
    _pendingDeletionBoundaries.remove(id);
    if (!restore) _offPageDeletionIds.remove(id);
    if (_pendingDeletionIds.isEmpty) _pendingDeletionOrder = null;
  }

  void _rememberReadProjections(Iterable<AppNotification> notifications) {
    for (final notification in notifications) {
      if (notification.read &&
          !_deletedNotificationIds.contains(notification.id) &&
          _canShowNotification(notification)) {
        // Optimistic deletion can still roll back; retain read proof until its
        // server success installs the tombstone and retires this ID's proof.
        _confirmedReadIds.add(notification.id);
      }
    }
  }

  AppNotification _withConfirmedRead(AppNotification notification) =>
      !notification.read &&
          (_confirmedReadIds.contains(notification.id) ||
              (notification.type == 'DM_NEW_MESSAGE' &&
                  _confirmedDmMessageIds.contains(
                    notification.payload['messageId']?.toString().trim(),
                  )))
      ? notification.copyWith(read: true)
      : notification;

  bool _isCurrentSession(int generation, int sessionRevision) {
    return _isCurrent(generation) && sessionRevision == _sessionRevision;
  }

  bool _isCurrentRefresh(int generation, int requestSequence) {
    return _isCurrent(generation) && requestSequence == _refreshSequence;
  }

  bool _isCurrentSessionRefresh(
    int generation,
    int sessionRevision,
    int requestSequence,
  ) {
    return _isCurrentSession(generation, sessionRevision) &&
        requestSequence == _refreshSequence;
  }

  void _onRealtimeNotification(AppNotification notification) {
    final recipientId = notification.recipientId.trim();
    if (_startedUserId == null || recipientId != _startedUserId) return;
    if (!_canShowNotification(notification)) return;
    if (_isDeleted(notification.id)) return;
    if (_verifyRealtimeAfterClear ||
        (_verifyUnreadRealtimeAfterBulkRead &&
            !notification.read &&
            !_confirmedReadIds.contains(notification.id))) {
      unawaited(_reconcileAfterRealtimeGap(_lifecycleGeneration));
      return;
    }
    if (notification.read) _confirmedReadIds.add(notification.id);
    notification = _withConfirmedRead(notification);
    _realtimeRevision += 1;
    _realtimeRevisionById[notification.id] = _realtimeRevision;
    final existingIndex = state.items.indexWhere(
      (item) => item.id == notification.id,
    );
    if (existingIndex >= 0) {
      final updated = [...state.items];
      updated[existingIndex] = notification;
      emit(state.copyWith(items: updated, clearError: true));
      return;
    }
    _pendingDeletionOrder
      ?..remove(notification.id)
      ..insert(0, notification.id);
    emit(
      state.copyWith(
        status: state.status == NotificationStatus.initial
            ? NotificationStatus.success
            : state.status,
        items: [notification, ...state.items],
        unreadCount: notification.read
            ? state.unreadCount
            : (state.unreadCount + 1).clamp(0, 999999),
        initialized: true,
        clearError: true,
      ),
    );
  }

  List<AppNotification> _mergeById(Iterable<AppNotification> items) {
    final seenIds = <String>{};
    return items.where((item) => seenIds.add(item.id)).toList(growable: false);
  }

  List<String> _mergePageOrder(
    Iterable<String> retained,
    Iterable<String> page,
  ) {
    final result = retained.toList();
    final ids = page.toList();
    final firstAnchor = ids
        .map(result.indexOf)
        .where((index) => index >= 0)
        .firstOrNull;
    var insertAt = firstAnchor ?? result.length;
    for (final id in ids) {
      final existing = result.indexOf(id);
      if (existing >= 0) {
        insertAt = existing + 1;
      } else {
        // Repair rows may belong before later pages already on screen.
        // Share these anchors with pending DELETE rollback order as well.
        result.insert(insertAt++, id);
      }
    }
    return result;
  }

  @override
  Future<void> close() async {
    _closing = true;
    _sessions?.removeListener(_onSessionChanged);
    await stop();
    await _realtimeClient.release();
    return super.close();
  }
}
