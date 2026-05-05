import '../../domain/entities/app_notification.dart';

enum NotificationStatus { initial, loading, success, failure, loadingMore }

class NotificationState {
  final NotificationStatus status;
  final List<AppNotification> items;
  final int unreadCount;
  final int page;
  final bool hasNext;
  final String? errorMessage;
  final bool initialized;

  const NotificationState({
    required this.status,
    required this.items,
    required this.unreadCount,
    required this.page,
    required this.hasNext,
    required this.errorMessage,
    required this.initialized,
  });

  const NotificationState.initial()
    : status = NotificationStatus.initial,
      items = const [],
      unreadCount = 0,
      page = 0,
      hasNext = false,
      errorMessage = null,
      initialized = false;

  NotificationState copyWith({
    NotificationStatus? status,
    List<AppNotification>? items,
    int? unreadCount,
    int? page,
    bool? hasNext,
    String? errorMessage,
    bool clearError = false,
    bool? initialized,
  }) {
    return NotificationState(
      status: status ?? this.status,
      items: items ?? this.items,
      unreadCount: unreadCount ?? this.unreadCount,
      page: page ?? this.page,
      hasNext: hasNext ?? this.hasNext,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      initialized: initialized ?? this.initialized,
    );
  }
}
