import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/token_store.dart';
import '../../data/notification_auth_support.dart';
import '../../data/notification_realtime_client.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/notification_repository.dart';
import 'notification_state.dart';

class NotificationCubit extends Cubit<NotificationState> {
  final NotificationRepository _repository;
  final TokenStore _tokenStore;
  final NotificationRealtimeClient _realtimeClient;

  NotificationCubit(
    this._repository,
    this._tokenStore, {
    NotificationRealtimeClient? realtimeClient,
  }) : _realtimeClient = realtimeClient ?? NotificationRealtimeClient(),
       super(const NotificationState.initial()) {
    _realtimeClient.retain();
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
  final Set<String> _pendingDeletionIds = <String>{};

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
    final currentUserId = await resolveNotificationUserId(_tokenStore);
    if (!_isCurrent(generation)) return;
    if (currentUserId == null || currentUserId.trim().isEmpty) {
      if (_startedUserId != null) _sessionRevision += 1;
      _startedUserId = null;
      _realtimeRevisionById.clear();
      _pendingDeletionIds.clear();
      emit(const NotificationState.initial().copyWith(initialized: true));
      return;
    }
    if (_startedUserId == currentUserId && state.initialized) return;
    final switchingUser = _startedUserId != null;
    _sessionRevision += 1;
    _startedUserId = currentUserId;
    _realtimeRevisionById.clear();
    _pendingDeletionIds.clear();
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
    if (!_isCurrent(generation)) {
      await _realtimeClient.disconnect();
      return;
    }
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

    final currentUserId = await resolveNotificationUserId(_tokenStore);
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

    final realtimeItems = state.items.where(
      (item) => (_realtimeRevisionById[item.id] ?? 0) > realtimeRevisionAtStart,
    );
    final mergedItems = _mergeById(<AppNotification>[
      ...realtimeItems,
      ...pageResult.data!.items,
    ]).where((item) => !_pendingDeletionIds.contains(item.id)).toList();
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
    if (!state.hasNext || state.status == NotificationStatus.loadingMore) {
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
    final seenIds = state.items.map((item) => item.id).toSet();
    final uniqueNextItems = result.data!.items
        .where((item) => seenIds.add(item.id))
        .toList(growable: false);
    emit(
      state.copyWith(
        status: NotificationStatus.success,
        items: [...state.items, ...uniqueNextItems],
        page: nextPage,
        hasNext: result.data!.hasNext,
        clearError: true,
      ),
    );
  }

  Future<void> markAsRead(AppNotification notification) async {
    if (notification.read) return;
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
    var changed = false;
    final updatedItems = state.items.map((item) {
      if (item.id != notification.id || item.read) return item;
      changed = true;
      return item.copyWith(read: true);
    }).toList();
    if (!changed) return;
    emit(
      state.copyWith(
        items: updatedItems,
        unreadCount: _badgeRevision == badgeRevision
            ? (state.unreadCount - 1).clamp(0, 999999)
            : state.unreadCount,
        clearError: true,
      ),
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
        return item.copyWith(read: true);
      }
      return item;
    }).toList();

    if (changedCount == 0) return;
    emit(
      state.copyWith(
        items: updatedItems,
        unreadCount: (state.unreadCount - changedCount).clamp(0, 999999),
        clearError: true,
      ),
    );
  }

  Future<void> markAllAsRead() async {
    final generation = _lifecycleGeneration;
    final sessionRevision = _sessionRevision;
    final result = await _repository.markAllAsRead();
    if (!_isCurrentSession(generation, sessionRevision)) return;
    if (!result.isSuccess) {
      emit(state.copyWith(errorMessage: result.error?.message));
      return;
    }
    await _refresh(generation, sessionRevision: sessionRevision);
  }

  Future<void> deleteNotification(AppNotification notification) async {
    final generation = _lifecycleGeneration;
    final sessionRevision = _sessionRevision;
    final badgeRevision = _badgeRevision;
    final currentIndex = state.items.indexWhere(
      (item) => item.id == notification.id,
    );
    if (currentIndex < 0 || !_pendingDeletionIds.add(notification.id)) return;
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
      if (realtimeRevision != null) {
        _realtimeRevisionById[notification.id] = realtimeRevision;
      }
      final restoredItems = <AppNotification>[...state.items];
      if (!restoredItems.any((item) => item.id == notification.id)) {
        restoredItems.insert(
          currentIndex.clamp(0, restoredItems.length),
          currentNotification,
        );
      }
      emit(
        state.copyWith(
          items: restoredItems,
          unreadCount:
              !currentNotification.read && _badgeRevision == badgeRevision
              ? (state.unreadCount + 1).clamp(0, 999999)
              : state.unreadCount,
          errorMessage: result.error?.message,
        ),
      );
      return;
    }
    _pendingDeletionIds.remove(notification.id);
    _realtimeRevisionById.remove(notification.id);
  }

  Future<void> clearAllNotifications() async {
    if (state.items.isEmpty) return;
    final generation = _lifecycleGeneration;
    final sessionRevision = _sessionRevision;
    final result = await _repository.clearAllNotifications();
    if (!_isCurrentSession(generation, sessionRevision)) return;
    if (!result.isSuccess) {
      emit(state.copyWith(errorMessage: result.error?.message));
      return;
    }
    await _refresh(generation, sessionRevision: sessionRevision);
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
    _pendingDeletionIds.clear();
    if (_isCurrent(generation)) emit(const NotificationState.initial());
  }

  bool _isCurrent(int generation) {
    return !isClosed && generation == _lifecycleGeneration;
  }

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
    if (_pendingDeletionIds.contains(notification.id)) return;
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
    await stop();
    await _realtimeClient.release();
    return super.close();
  }
}
