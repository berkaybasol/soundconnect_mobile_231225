import '../../../core/error/result.dart';
import '../../../core/pagination/page.dart';
import 'entities/app_notification.dart';

abstract class NotificationRepository {
  Future<Result<Page<AppNotification>>> listNotifications({
    int page = 0,
    int size = 20,
  });

  Future<Result<List<AppNotification>>> getRecentNotifications();

  Future<Result<int>> getUnreadCount();

  Future<Result<void>> markAsRead({required String notificationId});

  Future<Result<int>> markAllAsRead();

  Future<Result<void>> deleteNotification({required String notificationId});

  Future<Result<int>> clearAllNotifications();
}
