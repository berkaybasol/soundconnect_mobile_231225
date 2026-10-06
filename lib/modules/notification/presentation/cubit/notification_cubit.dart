import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/auth/token_store.dart';
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
  AuthSession? _observedSession;
  bool _closing = false;

  NotificationCubit(
    this._repository,
    this._tokenStore, {
    NotificationRealtimeClient? realtimeClient,
    AuthSessionManager? sessions,
    Future<void> Function()? onDeliveryStateChanged,
  }) : _realtimeClient = realtimeClient ?? NotificationRealtimeClient(),
       _sessions = sessions,
       _onDeliveryStateChanged = onDeliveryStateChanged,
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
  final Map<String, int> _realtimeRevisionById = <String, int>{};
  // Confirmed reads are monotonic for an ID in this session. Neither an offset
  // page nor an unversioned socket frame proves an absent ID can be forgotten.
  // Keep only distinct IDs (no payloads), until deletion or session teardown;
  // TTL/LRU eviction would allow a delayed unread frame to undo a valid ACK.
  final Set<String> _confirmedReadIds = <String>{};
  final Set<String> _pendingDeletionIds = <String>{};
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
      _pendingDeletionIds.clear();
      _deletedNotificationIds.clear();
      _verifyRealtimeAfterClear = false;
      _verifyUnreadRealtimeAfterBulkRead = false;
      _clearOperation = null;
      emit(const NotificationState.initial().copyWith(initialized: true));
      return;
    }
    if (_startedUserId == currentUserId && state.initialized) return;
    final switchingUser = _startedUserId != null;
    _sessionRevision += 1;
    _startedUserId = currentUserId;
    _realtimeRevisionById.clear();
    _confirmedReadIds.clear();
    _pendingDeletionIds.clear();
    _deletedNotificationIds.clear();
    _verifyRealtimeAfterClear = false;
    _verifyUnreadRealtimeAfterBulkRead = false;
    _clearOperation = null;
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
    emit(
      state.copyWith(
        status: NotificationStatus.loading,
        clearError: true,
        initialized: true,
      ),
    );
    final pageResult = await _repository.listNotifications();
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
    final mergedItems =
        _mergeById(<AppNotification>[...realtimeItems, ...pageItems])
            .where((item) => !_isDeleted(item.id) && _canShowNotification(item))
            .toList();
    final mergedIds = mergedItems.map((item) => item.id).toSet();
    _realtimeRevisionById.removeWhere((id, _) => !mergedIds.contains(id));

    final badgeChangedDuringRefresh = _badgeRevision > badgeRevisionAtStart;
    var unreadCount = badgeChangedDuringRefresh
        ? state.unreadCount
        : unreadResult.data ?? state.unreadCount;
    if (!badgeChangedDuringRefresh) {
      final visibleUnreadCount = mergedItems.where((item) => !item.read).length;
      if (unreadCount < visibleUnreadCount) unreadCount = visibleUnreadCount;
    }

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
    final nextPage = state.page + 1;
    emit(state.copyWith(status: NotificationStatus.loadingMore));
    final result = await _repository.listNotifications(page: nextPage);
    if (!_isCurrentSession(generation, sessionRevision) ||
        !_isCurrentRefresh(generation, refreshSequence)) {
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
    final seenIds = state.items.map((item) => item.id).toSet();
    final uniqueNextItems = result.data!.items
        .where((item) => !_isDeleted(item.id))
        .where(_canShowNotification)
        .where((item) => seenIds.add(item.id))
        .map(_withConfirmedRead)
        .toList(growable: false);
    emit(
      state.copyWith(
        status: NotificationStatus.success,
        items: [...state.items.map(_withConfirmedRead), ...uniqueNextItems],
        page: nextPage,
        hasNext: result.data!.hasNext,
        clearError: true,
      ),
    );
  }

  Future<void> markAsRead(AppNotification notification) async {
    if (notification.read || !_canShowNotification(notification)) return;
    final generation = _lifecycleGeneration;
    final sessionRevision = _sessionRevision;
    final badgeRevision = _badgeRevision;
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
    final unreadCount = _badgeRevision == badgeRevision
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
        isClosed) {
      return;
    }
    final generation = _lifecycleGeneration;
    final revision = _sessionRevision;
    if (!_deletedNotificationIds.contains(notification.id)) {
      _confirmedReadIds.add(notification.id);
    }
    final badgeRevision = ++_badgeRevision;
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
    final count = await _repository.getUnreadCount();
    if (!_isCurrentSession(generation, revision) ||
        !identical(_sessions?.session, session) ||
        _badgeRevision != badgeRevision) {
      return;
    }
    if (count.isSuccess && count.data != null) {
      emit(state.copyWith(unreadCount: count.data!.clamp(0, 999999)));
    }
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
  void markDmMessageAsReadLocally(String messageId) {
    if (isClosed || messageId.trim().isEmpty) return;
    var changed = 0;
    final items = state.items.map((item) {
      if (!item.read &&
          item.type == 'DM_NEW_MESSAGE' &&
          item.payload['messageId']?.toString() == messageId) {
        changed++;
        _confirmedReadIds.add(item.id);
        return item.copyWith(read: true);
      }
      return item;
    }).toList();
    if (changed == 0) return;
    _badgeRevision++;
    emit(
      state.copyWith(
        items: items,
        unreadCount: (state.unreadCount - changed).clamp(0, 999999),
      ),
    );
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
    final badgeRevision = ++_badgeRevision;
    final currentNotification = state.items[currentIndex];
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
      _pendingDeletionIds.remove(notification.id);
      if (_deletedNotificationIds.contains(notification.id)) return;
      if (realtimeRevision != null) {
        _realtimeRevisionById[notification.id] = realtimeRevision;
      }
      // An ACK may have succeeded while the optimistic deletion hid this row.
      // Restore its current read projection, including for badge rollback.
      final restoredNotification = _withConfirmedRead(currentNotification);
      final restoredItems = <AppNotification>[...state.items];
      if (!restoredItems.any((item) => item.id == notification.id)) {
        restoredItems.insert(
          currentIndex.clamp(0, restoredItems.length),
          restoredNotification,
        );
      }
      emit(
        state.copyWith(
          items: restoredItems,
          unreadCount:
              !restoredNotification.read && _badgeRevision == badgeRevision
              ? (state.unreadCount + 1).clamp(0, 999999)
              : state.unreadCount,
          errorMessage: result.error?.message,
        ),
      );
      return;
    }
    unawaited(_notifyDeliveryStateChanged(generation, sessionRevision));
    _pendingDeletionIds.remove(notification.id);
    // Keep a session-scoped tombstone: a page that was already in flight may
    // still contain the successfully deleted notification.
    _deletedNotificationIds.add(notification.id);
    _realtimeRevisionById.remove(notification.id);
    _confirmedReadIds.remove(notification.id);
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
    _pendingDeletionIds.clear();
    _deletedNotificationIds.clear();
    _verifyRealtimeAfterClear = false;
    _verifyUnreadRealtimeAfterBulkRead = false;
    _clearOperation = null;
    if (_isCurrent(generation)) emit(const NotificationState.initial());
  }

  bool _isCurrent(int generation) {
    return !_closing && !isClosed && generation == _lifecycleGeneration;
  }

  bool _isDeleted(String id) =>
      _pendingDeletionIds.contains(id) || _deletedNotificationIds.contains(id);

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
      !notification.read && _confirmedReadIds.contains(notification.id)
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

  @override
  Future<void> close() async {
    _closing = true;
    _sessions?.removeListener(_onSessionChanged);
    await stop();
    await _realtimeClient.release();
    return super.close();
  }
}
