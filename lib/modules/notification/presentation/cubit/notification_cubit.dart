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
  String? _startedUserId;
  Future<void>? _startInFlight;

  Future<void> ensureStarted() async {
    final inFlight = _startInFlight;
    if (inFlight != null) {
      await inFlight;
      return;
    }
    final startFuture = _ensureStartedInternal();
    _startInFlight = startFuture;
    try {
      await startFuture;
    } finally {
      if (identical(_startInFlight, startFuture)) {
        _startInFlight = null;
      }
    }
  }

  Future<void> _ensureStartedInternal() async {
    final currentUserId = await resolveNotificationUserId(_tokenStore);
    if (currentUserId == null || currentUserId.trim().isEmpty) {
      _startedUserId = null;
      emit(state.copyWith(initialized: true));
      return;
    }
    if (_startedUserId == currentUserId && state.initialized) return;
    _startedUserId = currentUserId;

    await _notificationSubscription?.cancel();
    await _badgeSubscription?.cancel();
    _notificationSubscription = null;
    _badgeSubscription = null;

    _notificationSubscription = _realtimeClient.notificationStream.listen(
      _onRealtimeNotification,
    );
    _badgeSubscription = _realtimeClient.badgeStream.listen((count) {
      emit(state.copyWith(unreadCount: count.clamp(0, 999999)));
    });

    final token = await readNotificationAuthToken(_tokenStore);
    if (token != null) {
      await _realtimeClient.connect(userId: currentUserId, token: token);
    }
    await refresh();
  }

  Future<void> refresh() async {
    emit(
      state.copyWith(
        status: NotificationStatus.loading,
        clearError: true,
        initialized: true,
      ),
    );
    final unreadResult = await _repository.getUnreadCount();
    final pageResult = await _repository.listNotifications();

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

    emit(
      state.copyWith(
        status: NotificationStatus.success,
        items: pageResult.data!.items,
        unreadCount: unreadResult.isSuccess
            ? unreadResult.data ?? 0
            : state.unreadCount,
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
    final nextPage = state.page + 1;
    emit(state.copyWith(status: NotificationStatus.loadingMore));
    final result = await _repository.listNotifications(page: nextPage);
    if (!result.isSuccess || result.data == null) {
      emit(
        state.copyWith(
          status: NotificationStatus.success,
          errorMessage: result.error?.message,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        status: NotificationStatus.success,
        items: [...state.items, ...result.data!.items],
        page: nextPage,
        hasNext: result.data!.hasNext,
        clearError: true,
      ),
    );
  }

  Future<void> markAsRead(AppNotification notification) async {
    if (notification.read) return;
    final result = await _repository.markAsRead(
      notificationId: notification.id,
    );
    if (!result.isSuccess) {
      emit(state.copyWith(errorMessage: result.error?.message));
      return;
    }
    emit(
      state.copyWith(
        items: state.items
            .map(
              (item) =>
                  item.id == notification.id ? item.copyWith(read: true) : item,
            )
            .toList(),
        unreadCount: (state.unreadCount - 1).clamp(0, 999999),
        clearError: true,
      ),
    );
  }

  Future<void> markAllAsRead() async {
    final result = await _repository.markAllAsRead();
    if (!result.isSuccess) {
      emit(state.copyWith(errorMessage: result.error?.message));
      return;
    }
    emit(
      state.copyWith(
        items: state.items.map((item) => item.copyWith(read: true)).toList(),
        unreadCount: 0,
        clearError: true,
      ),
    );
  }

  Future<void> deleteNotification(AppNotification notification) async {
    final result = await _repository.deleteNotification(
      notificationId: notification.id,
    );
    if (!result.isSuccess) {
      emit(state.copyWith(errorMessage: result.error?.message));
      return;
    }
    emit(
      state.copyWith(
        items: state.items.where((item) => item.id != notification.id).toList(),
        unreadCount: notification.read
            ? state.unreadCount
            : (state.unreadCount - 1).clamp(0, 999999),
        clearError: true,
      ),
    );
  }

  Future<void> clearAllNotifications() async {
    if (state.items.isEmpty) return;
    final result = await _repository.clearAllNotifications();
    if (!result.isSuccess) {
      emit(state.copyWith(errorMessage: result.error?.message));
      return;
    }
    emit(
      state.copyWith(
        items: const [],
        unreadCount: 0,
        page: 0,
        hasNext: false,
        clearError: true,
      ),
    );
  }

  void _onRealtimeNotification(AppNotification notification) {
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

  @override
  Future<void> close() async {
    await _notificationSubscription?.cancel();
    await _badgeSubscription?.cancel();
    await _realtimeClient.release();
    return super.close();
  }
}
