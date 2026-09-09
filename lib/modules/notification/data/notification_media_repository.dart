import '../../../core/auth/auth_session_manager.dart';
import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../profile/data/models/media_asset_model.dart';
import '../../profile/domain/entities/media_asset.dart';

class NotificationMediaRepository {
  final ApiClient api;
  final AuthSessionManager sessions;

  NotificationMediaRepository(this.api, this.sessions);

  Future<Result<MediaAsset>> resolve(
    String notificationId,
    String targetId,
  ) async {
    final session = sessions.session;
    const stale = AppError(
      code: 'notification_session_changed',
      message: 'Oturum değişti. Bildirimleri yeniden aç.',
    );
    if (!session.isAuthenticated ||
        !session.isActive ||
        session.userId?.trim().isNotEmpty != true) {
      return const Result.failure(stale);
    }
    try {
      final media = await api.request<MediaAsset>(
        ApiHttpMethod.get,
        '/api/v1/user/notifications/${Uri.encodeComponent(notificationId)}/media',
        requestContext: ApiRequestContext(expectedSessionKey: session.userId),
        decoder: (json) {
          if (json is! Map<String, dynamic>) {
            throw const FormatException('Invalid notification media');
          }
          final asset = MediaAssetModel.fromJson(json);
          if (asset.id != targetId ||
              !const ['AUDIO', 'VIDEO', 'IMAGE'].contains(asset.kind)) {
            throw const FormatException('Invalid notification media');
          }
          return asset;
        },
      );
      if (!identical(session, sessions.session)) {
        return const Result.failure(stale);
      }
      return Result.success(media);
    } on ApiException catch (error) {
      return Result.failure(error.error);
    } catch (_) {
      return const Result.failure(
        AppError(
          code: 'notification_media_invalid',
          message: 'İçerik açılamadı. Lütfen tekrar dene.',
        ),
      );
    }
  }
}
