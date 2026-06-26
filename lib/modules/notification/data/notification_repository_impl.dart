import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/pagination/page.dart';
import '../domain/entities/app_notification.dart';
import '../domain/notification_repository.dart';
import 'models/app_notification_model.dart';
import 'notification_endpoints.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  final ApiClient _apiClient;

  NotificationRepositoryImpl(this._apiClient);

  @override
  Future<Result<Page<AppNotification>>> listNotifications({
    int page = 0,
    int size = 20,
  }) async {
    try {
      final response = await _apiClient.get<Page<AppNotification>>(
        NotificationEndpoints.list,
        query: {'page': page, 'size': size, 'sort': 'createdAt,desc'},
        decoder: (json) => _decodePage(json, page),
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'notification_list_unknown',
          message: 'Bildirimler getirilemedi',
        ),
      );
    }
  }

  @override
  Future<Result<List<AppNotification>>> getRecentNotifications() async {
    try {
      final response = await _apiClient.get<List<AppNotification>>(
        NotificationEndpoints.recent,
        decoder: (json) => _decodeList(json),
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'notification_recent_unknown',
          message: 'Son bildirimler getirilemedi',
        ),
      );
    }
  }

  @override
  Future<Result<int>> getUnreadCount() async {
    try {
      final response = await _apiClient.get<int>(
        NotificationEndpoints.unreadCount,
        decoder: (json) {
          final map = json as Map<String, dynamic>? ?? const {};
          return (map['unread'] as num?)?.toInt() ?? 0;
        },
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'notification_unread_unknown',
          message: 'Bildirim sayisi alinamadi',
        ),
      );
    }
  }

  @override
  Future<Result<void>> markAsRead({required String notificationId}) async {
    try {
      await _apiClient.post<Object?>(
        NotificationEndpoints.markRead(notificationId),
        body: null,
        decoder: (_) => null,
      );
      return const Result.success(null);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'notification_mark_read_unknown',
          message: 'Bildirim okundu olarak isaretlenemedi',
        ),
      );
    }
  }

  @override
  Future<Result<int>> markAllAsRead() async {
    try {
      final response = await _apiClient.post<int>(
        NotificationEndpoints.markAllRead,
        body: null,
        decoder: (json) {
          final map = json as Map<String, dynamic>? ?? const {};
          return (map['updated'] as num?)?.toInt() ?? 0;
        },
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'notification_mark_all_unknown',
          message: 'Bildirimler okundu olarak isaretlenemedi',
        ),
      );
    }
  }

  @override
  Future<Result<void>> deleteNotification({
    required String notificationId,
  }) async {
    try {
      await _apiClient.delete<Object?>(
        NotificationEndpoints.delete(notificationId),
        decoder: (_) => null,
      );
      return const Result.success(null);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'notification_delete_unknown',
          message: 'Bildirim silinemedi',
        ),
      );
    }
  }

  @override
  Future<Result<int>> clearAllNotifications() async {
    try {
      final response = await _apiClient.delete<int>(
        NotificationEndpoints.clearAll,
        decoder: (json) {
          final map = json as Map<String, dynamic>? ?? const {};
          return (map['deleted'] as num?)?.toInt() ?? 0;
        },
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'notification_clear_all_unknown',
          message: 'Bildirimler temizlenemedi',
        ),
      );
    }
  }

  Page<AppNotification> _decodePage(Object? json, int fallbackPage) {
    final map = json as Map<String, dynamic>? ?? const {};
    final content = (map['content'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => AppNotificationModel.fromJson(item.cast()))
        .toList();
    final currentPage = (map['number'] as num?)?.toInt() ?? fallbackPage;
    final bool hasNext = map['last'] is bool
        ? !(map['last'] as bool)
        : (map['hasNext'] as bool?) ?? false;
    return Page<AppNotification>(
      items: content,
      hasNext: hasNext,
      nextCursor: hasNext ? (currentPage + 1).toString() : null,
    );
  }

  List<AppNotification> _decodeList(Object? json) {
    if (json is! List) return const [];
    return json
        .whereType<Map>()
        .map((item) => AppNotificationModel.fromJson(item.cast()))
        .toList();
  }
}
