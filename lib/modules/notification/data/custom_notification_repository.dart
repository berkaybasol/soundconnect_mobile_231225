import '../../../core/auth/auth_session.dart';
import '../../../core/auth/auth_session_manager.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/push/push_provider.dart';
import '../../profile/data/models/media_asset_model.dart';
import '../../profile/domain/entities/media_asset.dart';
import '../domain/entities/app_notification.dart';
import 'models/app_notification_model.dart';
import 'notification_endpoints.dart';
import 'notification_target_repository.dart';

/// A campaign payload is never a navigation capability. Resolve the exact
/// owned inbox row and its current product target with the captured session.
class CustomNotificationRepository {
  CustomNotificationRepository(this._api, this._sessions);
  final ApiClient _api;
  final AuthSessionManager _sessions;

  bool current(AuthSession session) =>
      identical(session, _sessions.session) &&
      session.isAuthenticated &&
      session.isActive &&
      !session.isVenueApplicationSession &&
      !session.requiresListenerProfileChoice &&
      session.expiresAt?.isAfter(DateTime.now()) == true;

  Future<Result<CustomNotificationDestination>> resolve(
    PushTarget target,
    AuthSession session,
  ) async {
    if (!current(session)) {
      return const Result.failure(NotificationTargetRepository.stale);
    }
    if (target.type != 'ADMIN_BROADCAST' ||
        target.conversationId != null ||
        !PushTarget.isUuid(target.notificationId) ||
        !PushTarget.isUuid(target.recipientId) ||
        target.recipientId != session.userId) {
      return const Result.failure(NotificationTargetRepository.unavailable);
    }
    final requestContext = ApiRequestContext(
      expectedSessionKey: session.userId,
      expectedToken: session.token,
    );
    try {
      final notification = await _api.request<AppNotification>(
        ApiHttpMethod.get,
        '${NotificationEndpoints.list}/${target.notificationId}',
        requestContext: requestContext,
        decoder: (json) {
          if (json is! Map<String, dynamic> ||
              json['read'] is! bool ||
              json['payload'] is! Map<String, dynamic>) {
            throw const FormatException('Invalid exact notification');
          }
          final item = AppNotificationModel.fromJson(json);
          if (item.id != target.notificationId ||
              item.recipientId != target.recipientId ||
              item.type != target.type) {
            throw const FormatException('Notification identity mismatch');
          }
          return item;
        },
      );
      if (!current(session)) {
        return const Result.failure(NotificationTargetRepository.stale);
      }
      final destination = await _api.request<CustomNotificationDestination>(
        ApiHttpMethod.get,
        '${NotificationEndpoints.list}/${target.notificationId}/custom-target',
        requestContext: requestContext,
        decoder: (json) =>
            CustomNotificationDestination.decode(json, notification),
      );
      return current(session)
          ? Result.success(destination)
          : const Result.failure(NotificationTargetRepository.stale);
    } on ApiException catch (error) {
      return Result.failure(
        current(session) ? error.error : NotificationTargetRepository.stale,
      );
    } catch (_) {
      return Result.failure(
        current(session)
            ? NotificationTargetRepository.unavailable
            : NotificationTargetRepository.stale,
      );
    }
  }
}

class CustomNotificationDestination {
  const CustomNotificationDestination({
    required this.notification,
    required this.kind,
    required this.available,
    this.targetId,
    this.media,
    this.event,
  });
  final AppNotification notification;
  final String kind;
  final bool available;
  final String? targetId;
  final MediaAsset? media;
  final Map<String, dynamic>? event;
  static const modules = {'HOME', 'EVENTS', 'TABLES', 'COLLAB', 'MARKETPLACE'};
  static const entities = {'PROFILE', 'EVENT', 'CONTENT'};

  factory CustomNotificationDestination.decode(
    Object? json,
    AppNotification notification,
  ) {
    if (json is! Map<String, dynamic> ||
        json['notificationId'] != notification.id ||
        json['recipientId'] != notification.recipientId ||
        json['type'] != 'ADMIN_BROADCAST' ||
        json['read'] is! bool ||
        !const {'AVAILABLE', 'UNAVAILABLE'}.contains(json['state']) ||
        json['target'] is! Map<String, dynamic>) {
      throw const FormatException('Invalid custom notification target');
    }
    final target = json['target'] as Map<String, dynamic>;
    final kind = target['kind'];
    final id = target['targetId'];
    final available = json['state'] == 'AVAILABLE';
    if ((!modules.contains(kind) && !entities.contains(kind)) ||
        (available && entities.contains(kind) && !PushTarget.isUuid(id)) ||
        (modules.contains(kind) && id != null)) {
      throw const FormatException('Invalid target identity');
    }
    // The server removes stale/private targets from a terminal projection. A
    // generic error or a partial/mixed target is never proof that can be read.
    if (!available &&
        (kind != 'HOME' ||
            id != null ||
            json['event'] != null ||
            json['media'] != null ||
            json['profile'] != null)) {
      throw const FormatException('Invalid terminal target');
    }
    MediaAsset? media;
    Map<String, dynamic>? event;
    if (available && kind == 'CONTENT') {
      if (json['media'] is! Map<String, dynamic>) throw const FormatException();
      media = MediaAssetModel.fromJson(json['media'] as Map<String, dynamic>);
      if (media.id != id ||
          !const {'AUDIO', 'VIDEO', 'IMAGE'}.contains(media.kind)) {
        throw const FormatException('Media identity mismatch');
      }
    }
    if (available && kind == 'EVENT') {
      if (json['event'] is! Map<String, dynamic>) throw const FormatException();
      event = Map<String, dynamic>.unmodifiable(
        json['event'] as Map<String, dynamic>,
      );
      if (event['id'] != id ||
          (event.containsKey('eventOrigin') &&
              event['eventOrigin'] != 'VENUE')) {
        throw const FormatException('Event identity mismatch');
      }
    }
    return CustomNotificationDestination(
      notification: notification.copyWith(read: json['read'] as bool),
      kind: kind as String,
      available: available,
      targetId: id as String?,
      media: media,
      event: event,
    );
  }
}
