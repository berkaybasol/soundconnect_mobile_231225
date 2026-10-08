import '../../../core/auth/auth_session.dart';
import '../../../core/auth/auth_session_manager.dart';
import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/push/push_provider.dart';
import '../domain/entities/app_notification.dart';
import '../domain/entities/studio_reservation_notification_target.dart';
import 'models/app_notification_model.dart';
import 'notification_endpoints.dart';
import '../domain/entities/table_notification_target.dart';
import '../../tablegroup/data/table_group_endpoints.dart';
import '../../tablegroup/data/models/table_group_message_model.dart';
import '../../tablegroup/domain/entities/table_group_message.dart';
import '../../../core/pagination/page.dart';

/// Exact, read-only lookup for a native venue tap. The server supplies business
/// targets; notification text and FCM extras never authorize navigation.
class NotificationTargetRepository {
  NotificationTargetRepository(this._client, this._sessions);
  final ApiClient _client;
  final AuthSessionManager _sessions;

  static const unavailable = AppError(
    code: 'notification_target_unavailable',
    message:
        'Bildirim şu anda açılamıyor. Bağlantını kontrol edip tekrar dene.',
  );
  static const stale = AppError(
    code: 'notification_target_session_changed',
    message: 'Oturum değişti. Bildirimi yeniden aç.',
  );

  bool _current(AuthSession session) =>
      identical(_sessions.session, session) &&
      session.isAuthenticated &&
      (session.isActive || session.isVenueApplicationSession) &&
      !session.requiresListenerProfileChoice &&
      !session.hasAnyRole(const ['LISTENER', 'ROLE_LISTENER']);

  ApiRequestContext _context(AuthSession session) => ApiRequestContext(
    expectedSessionKey: session.userId,
    expectedToken: session.token,
  );

  Future<Result<AppNotification>> resolve(
    PushTarget target,
    AuthSession session,
  ) async {
    if (!_current(session)) return const Result.failure(stale);
    if ((!target.isVenue && !target.isVenueApplication) ||
        (session.isVenueApplicationSession && !target.isVenueApplication) ||
        target.conversationId != null ||
        !PushTarget.isUuid(target.notificationId) ||
        target.recipientId.toLowerCase() != session.userId?.toLowerCase()) {
      return const Result.failure(unavailable);
    }
    try {
      final item = await _client.request<AppNotification>(
        ApiHttpMethod.get,
        session.isVenueApplicationSession
            ? '${session.venueApplicationSessionBase}/notifications/${target.notificationId}'
            : '${NotificationEndpoints.list}/${target.notificationId}',
        requestContext: _context(session),
        decoder: (json) {
          if (json is! Map<String, dynamic>) {
            throw const FormatException('Invalid notification');
          }
          final item = AppNotificationModel.fromJson(json);
          final module = item.payload['module'];
          if (item.id.toLowerCase() != target.notificationId.toLowerCase() ||
              item.recipientId.toLowerCase() !=
                  target.recipientId.toLowerCase() ||
              item.type != target.type ||
              (target.isVenueApplication
                  ? !_applicationScope(item, session)
                  : item.type.startsWith('ARTIST_VENUE_')
                  ? module != 'ARTIST_VENUE'
                  : module != 'EVENT_PERFORMER' && module != 'EVENT_PLAN')) {
            throw const FormatException('Notification scope mismatch');
          }
          return item;
        },
      );
      return _current(session)
          ? Result.success(item)
          : const Result.failure(stale);
    } on ApiException catch (error) {
      return Result.failure(_current(session) ? error.error : stale);
    } catch (_) {
      return Result.failure(_current(session) ? unavailable : stale);
    }
  }

  bool _followCurrent(AuthSession session) =>
      identical(_sessions.session, session) &&
      session.isAuthenticated &&
      session.expiresAt?.isAfter(DateTime.now()) == true &&
      session.isActive &&
      !session.isVenueApplicationSession &&
      !session.requiresListenerProfileChoice;

  Future<Result<AppNotification>> resolveFollow(
    PushTarget target,
    AuthSession session,
  ) async {
    if (!_followCurrent(session)) return const Result.failure(stale);
    if (!target.isFollow ||
        target.conversationId != null ||
        !PushTarget.isUuid(target.notificationId) ||
        !PushTarget.isUuid(target.recipientId) ||
        target.recipientId != session.userId) {
      return const Result.failure(unavailable);
    }
    try {
      final item = await _client.request<AppNotification>(
        ApiHttpMethod.get,
        '${NotificationEndpoints.list}/${target.notificationId}',
        requestContext: _context(session),
        decoder: (json) {
          if (json is! Map<String, dynamic>) {
            throw const FormatException('Invalid follow notification');
          }
          final item = AppNotificationModel.fromJson(json);
          final band = target.type == 'SOCIAL_NEW_BAND_FOLLOWER';
          if (item.id != target.notificationId ||
              item.recipientId != target.recipientId ||
              item.type != target.type ||
              item.payload['action'] !=
                  (band ? 'NEW_BAND_FOLLOWER' : 'NEW_FOLLOWER') ||
              !PushTarget.isUuid(item.payload['followerId']) ||
              item.payload['followerId'] == item.recipientId ||
              (band && !PushTarget.isUuid(item.payload['bandId']))) {
            throw const FormatException('Follow target mismatch');
          }
          return item;
        },
      );
      return _followCurrent(session)
          ? Result.success(item)
          : const Result.failure(stale);
    } on ApiException catch (error) {
      return Result.failure(_followCurrent(session) ? error.error : stale);
    } catch (_) {
      return Result.failure(_followCurrent(session) ? unavailable : stale);
    }
  }

  Future<Result<AppNotification>> resolveMedia(
    PushTarget target,
    AuthSession session,
  ) async {
    if (!_followCurrent(session)) return const Result.failure(stale);
    if (!target.isMedia ||
        target.conversationId != null ||
        !PushTarget.isUuid(target.notificationId) ||
        !PushTarget.isUuid(target.recipientId) ||
        target.recipientId != session.userId) {
      return const Result.failure(unavailable);
    }
    try {
      final item = await _client.request<AppNotification>(
        ApiHttpMethod.get,
        '${NotificationEndpoints.list}/${target.notificationId}',
        requestContext: _context(session),
        decoder: (json) {
          if (json is! Map<String, dynamic>) {
            throw const FormatException('Invalid media notification');
          }
          final item = AppNotificationModel.fromJson(json);
          if (item.id != target.notificationId ||
              item.recipientId != target.recipientId ||
              item.type != target.type ||
              item.payload['module'] != 'SOCIAL' ||
              item.payload['targetType'] != 'MEDIA' ||
              !PushTarget.isUuid(item.payload['targetId']) ||
              !const [0, 1].contains(item.payload['mediaIdentityVersion']) ||
              (item.payload['mediaIdentityVersion'] == 1 &&
                  !PushTarget.isUuid(item.payload['actorId'])) ||
              (item.type == 'SOCIAL_COMMENT' &&
                  !PushTarget.isUuid(item.payload['commentId']))) {
            throw const FormatException('Media target mismatch');
          }
          return item;
        },
      );
      return _followCurrent(session)
          ? Result.success(item)
          : const Result.failure(stale);
    } on ApiException catch (error) {
      return Result.failure(_followCurrent(session) ? error.error : stale);
    } catch (_) {
      return Result.failure(_followCurrent(session) ? unavailable : stale);
    }
  }

  Future<Result<AppNotification>> resolveBand(
    PushTarget target,
    AuthSession session,
  ) async {
    if (!_followCurrent(session)) return const Result.failure(stale);
    if (!session.hasAnyRole(const ['MUSICIAN', 'ROLE_MUSICIAN']) ||
        session.hasAnyRole(const ['LISTENER', 'ROLE_LISTENER'])) {
      return const Result.failure(unavailable);
    }
    if (!target.isBand ||
        target.conversationId != null ||
        !PushTarget.isUuid(target.notificationId) ||
        !PushTarget.isUuid(target.recipientId) ||
        target.recipientId != session.userId) {
      return const Result.failure(unavailable);
    }
    try {
      final item = await _client.request<AppNotification>(
        ApiHttpMethod.get,
        '${NotificationEndpoints.list}/${target.notificationId}',
        requestContext: _context(session),
        decoder: (json) {
          if (json is! Map<String, dynamic>) {
            throw const FormatException('Invalid band notification');
          }
          final item = AppNotificationModel.fromJson(json);
          final payload = item.payload;
          final invitation = target.type.startsWith('BAND_INVITE_');
          final actorKey = switch (target.type) {
            'BAND_INVITE_RECEIVED' => 'inviterId',
            'BAND_MEMBER_REMOVED' => 'requesterId',
            _ => 'memberId',
          };
          final keys = <String>{
            'module',
            'bandId',
            'bandIdentityVersion',
            'action',
            actorKey,
            if (invitation) 'invitationId',
          };
          if (item.id != target.notificationId ||
              item.recipientId != target.recipientId ||
              item.type != target.type ||
              payload.keys.toSet().difference(keys).isNotEmpty ||
              keys.difference(payload.keys.toSet()).isNotEmpty ||
              payload['module'] != 'BAND' ||
              payload['action'] != target.type.substring(5) ||
              payload['bandIdentityVersion'] is! int ||
              payload['bandIdentityVersion'] != 1 ||
              !PushTarget.isUuid(payload['bandId']) ||
              !PushTarget.isUuid(payload[actorKey]) ||
              payload[actorKey] == item.recipientId ||
              (invitation && !PushTarget.isUuid(payload['invitationId']))) {
            throw const FormatException('Band target mismatch');
          }
          return item;
        },
      );
      return _followCurrent(session)
          ? Result.success(item)
          : const Result.failure(stale);
    } on ApiException catch (error) {
      return Result.failure(_followCurrent(session) ? error.error : stale);
    } catch (_) {
      return Result.failure(_followCurrent(session) ? unavailable : stale);
    }
  }

  static const inboxProductTypes = <String>{
    'COLLAB_APPLICATION_RECEIVED',
    'COLLAB_APPLICATION_ACCEPTED',
    'COLLAB_APPLICATION_REJECTED',
    'COLLAB_APPLICATION_WITHDRAWN',
    'COLLAB_APPLICATION_INVALIDATED',
    'COLLAB_LISTING_EXPIRED',
    'COLLAB_JOB_COMPLETION_REQUESTED',
    'COLLAB_JOB_COMPLETED',
    'COLLAB_REVIEW_RECEIVED',
    'COLLAB_LISTING_REMOVED',
    'COLLAB_REPORT_RESOLVED',
    'OVERTHINKING_REVEAL_REQUEST_RECEIVED',
    'OVERTHINKING_REVEAL_REQUEST_APPROVED',
    'OVERTHINKING_REVEAL_REQUEST_REJECTED',
  };

  /// Both families use the same fresh server-authorized occurrence for native/inbox.
  Future<Result<AppNotification>> resolveInboxProduct(
    AppNotification selected,
    AuthSession session,
  ) async {
    if (!_followCurrent(session)) return const Result.failure(stale);
    final collab = selected.type.startsWith('COLLAB_');
    if (!inboxProductTypes.contains(selected.type) ||
        !PushTarget.isUuid(selected.id) ||
        selected.recipientId != session.userId ||
        (collab && session.hasAnyRole(const ['LISTENER', 'ROLE_LISTENER']))) {
      return const Result.failure(unavailable);
    }
    try {
      final item = await _client.request<AppNotification>(
        ApiHttpMethod.get,
        '${NotificationEndpoints.list}/${selected.id}${collab ? '/collab-target' : '/overthinking-target'}',
        requestContext: _context(session),
        decoder: (json) {
          if (json is! Map<String, dynamic>) {
            throw const FormatException('Invalid row');
          }
          final item = AppNotificationModel.fromJson(json);
          if (item.id != selected.id ||
              item.recipientId != session.userId ||
              item.type != selected.type ||
              item.payload['module'] != (collab ? 'COLLAB' : 'OVERTHINKING') ||
              item.payload['action'] != item.type.substring(collab ? 7 : 13)) {
            throw const FormatException('Wrong owned occurrence');
          }
          if (!collab) {
            const keys = {
              'module',
              'action',
              'postId',
              'revealRequestId',
              'requestStatus',
              'sourceEventId',
              'identityVersion',
            };
            final payload = item.payload;
            final status = payload['requestStatus'];
            if (payload.keys.length != keys.length ||
                !payload.keys.toSet().containsAll(keys) ||
                payload['identityVersion'] != 1 ||
                !PushTarget.isUuid(payload['postId']) ||
                !PushTarget.isUuid(payload['revealRequestId']) ||
                !PushTarget.isUuid(payload['sourceEventId']) ||
                !const {'PENDING', 'APPROVED', 'REJECTED'}.contains(status) ||
                (item.type == 'OVERTHINKING_REVEAL_REQUEST_APPROVED' &&
                    status != 'APPROVED') ||
                (item.type == 'OVERTHINKING_REVEAL_REQUEST_REJECTED' &&
                    status != 'REJECTED')) {
              throw const FormatException('Invalid exact reveal target');
            }
          }
          return item;
        },
      );
      return _followCurrent(session)
          ? Result.success(item)
          : const Result.failure(stale);
    } on ApiException catch (error) {
      return Result.failure(_followCurrent(session) ? error.error : stale);
    } catch (_) {
      return Result.failure(_followCurrent(session) ? unavailable : stale);
    }
  }

  Future<Result<StudioReservationNotificationTarget>> resolveStudio(
    PushTarget target,
    AuthSession session,
  ) async {
    if (!_current(session) ||
        !session.isActive ||
        session.isVenueApplicationSession) {
      return const Result.failure(stale);
    }
    if (!target.isStudio ||
        target.conversationId != null ||
        !PushTarget.isUuid(target.notificationId) ||
        !PushTarget.isUuid(target.recipientId) ||
        target.recipientId.toLowerCase() != session.userId?.toLowerCase()) {
      return const Result.failure(unavailable);
    }
    try {
      final detail = await _client.request<StudioReservationNotificationTarget>(
        ApiHttpMethod.get,
        '${NotificationEndpoints.list}/${target.notificationId}/studio-reservation',
        requestContext: _context(session),
        decoder: (json) {
          if (json is! Map<String, dynamic>) {
            throw const FormatException('Invalid studio notification target');
          }
          return StudioReservationNotificationTarget.fromJson(json, target);
        },
      );
      return _current(session) && !session.isVenueApplicationSession
          ? Result.success(detail)
          : const Result.failure(stale);
    } on ApiException catch (error) {
      return Result.failure(_current(session) ? error.error : stale);
    } catch (_) {
      return Result.failure(_current(session) ? unavailable : stale);
    }
  }

  Future<Result<TableNotificationTarget>> resolveTable(
    AppNotification selected,
    AuthSession session,
  ) async {
    if (!_followCurrent(session)) return const Result.failure(stale);
    if (!TableNotificationTarget.actions.containsKey(selected.type) ||
        !PushTarget.isUuid(selected.id) ||
        selected.recipientId != session.userId ||
        session.hasAnyRole(const [
          'VENUE',
          'ROLE_VENUE',
          'STUDIO',
          'ROLE_STUDIO',
        ])) {
      return const Result.failure(unavailable);
    }
    try {
      final detail = await _client.request<TableNotificationTarget>(
        ApiHttpMethod.get,
        '${NotificationEndpoints.list}/${selected.id}/table-target',
        requestContext: _context(session),
        decoder: (json) {
          if (json is! Map<String, dynamic>) {
            throw const FormatException('Invalid table target');
          }
          return TableNotificationTarget.fromJson(json, selected);
        },
      );
      return _followCurrent(session)
          ? Result.success(detail)
          : const Result.failure(stale);
    } on ApiException catch (e) {
      return Result.failure(_followCurrent(session) ? e.error : stale);
    } catch (_) {
      return Result.failure(_followCurrent(session) ? unavailable : stale);
    }
  }

  Future<Result<void>> decideTableApplication(
    TableNotificationTarget target,
    AuthSession session, {
    required bool approve,
  }) async {
    if (!_followCurrent(session)) return const Result.failure(stale);
    if (!target.pending ||
        !target.sameApplication ||
        target.applicationId == null ||
        target.notification.recipientId != session.userId) {
      return const Result.failure(unavailable);
    }
    try {
      await _client.request<void>(
        ApiHttpMethod.post,
        approve
            ? TableGroupEndpoints.approve(target.tableGroupId, target.subjectId)
            : TableGroupEndpoints.reject(target.tableGroupId, target.subjectId),
        query: {'applicationId': target.applicationId},
        requestContext: _context(session),
      );
      return _followCurrent(session)
          ? const Result.success(null)
          : const Result.failure(stale);
    } on ApiException catch (e) {
      return Result.failure(_followCurrent(session) ? e.error : stale);
    } catch (_) {
      return Result.failure(_followCurrent(session) ? unavailable : stale);
    }
  }

  // Notification preparation does not clear the chat badge. A separate visible
  // frame can request the ordinary authorized read behavior after content loads.
  Future<Result<Page<TableGroupMessage>>> tableChat(
    TableNotificationTarget target,
    AuthSession session, {
    int page = 0,
    int size = 30,
    bool markRead = false,
  }) async {
    if (!_followCurrent(session)) return const Result.failure(stale);
    if (target.result || target.notification.recipientId != session.userId) {
      return const Result.failure(unavailable);
    }
    try {
      final response = await _client.request<Page<TableGroupMessage>>(
        ApiHttpMethod.get,
        TableGroupEndpoints.chatMessages(target.tableGroupId),
        requestContext: _context(session),
        query: {
          'page': page,
          'size': size,
          'markRead': markRead,
          if (target.chat) 'applicationId': target.applicationId,
        },
        decoder: (json) {
          if (json is! Map<String, dynamic> ||
              json['content'] is! List ||
              json['last'] is! bool) {
            throw const FormatException('Invalid chat page');
          }
          final messages = (json['content'] as List).map((item) {
            if (item is! Map<String, dynamic>) {
              throw const FormatException('Invalid chat message');
            }
            final message = TableGroupMessageModel.fromWireJson(item);
            if (message.tableGroupId != target.tableGroupId) {
              throw const FormatException('Wrong table chat');
            }
            return message;
          }).toList();
          return Page(items: messages, hasNext: !(json['last'] as bool));
        },
      );
      return _followCurrent(session)
          ? Result.success(response)
          : const Result.failure(stale);
    } on ApiException catch (e) {
      return Result.failure(_followCurrent(session) ? e.error : stale);
    } catch (_) {
      return Result.failure(_followCurrent(session) ? unavailable : stale);
    }
  }

  bool _applicationScope(AppNotification item, AuthSession session) {
    final expectedStatus = item.type == 'VENUE_APPLICATION_APPROVED'
        ? 'APPROVED'
        : 'REJECTED';
    return PushTarget.venueApplicationTypes.contains(item.type) &&
        item.payload['module'] == 'VENUE_APPLICATION' &&
        PushTarget.isUuid(item.payload['applicationId']) &&
        item.payload['applicantUserId'] == session.userId &&
        item.payload['status'] == expectedStatus &&
        item.payload['action'] == 'APPLICATION_$expectedStatus' &&
        (!session.isVenueApplicationSession ||
            item.payload['applicationId'] == session.applicationId);
  }

  Future<Result<void>> acknowledge(
    AppNotification notification,
    AuthSession session,
  ) async {
    final follow =
        notification.type == 'ADMIN_BROADCAST' ||
        PushTarget.followTypes.contains(notification.type) ||
        PushTarget.mediaTypes.contains(notification.type) ||
        PushTarget.bandTypes.contains(notification.type) ||
        TableNotificationTarget.actions.containsKey(notification.type) ||
        inboxProductTypes.contains(notification.type);
    bool current() => follow ? _followCurrent(session) : _current(session);
    if (!current()) return const Result.failure(stale);
    if (notification.recipientId.toLowerCase() !=
            session.userId?.toLowerCase() ||
        !PushTarget.isUuid(notification.id) ||
        (!PushTarget.venueTypes.contains(notification.type) &&
            !PushTarget.venueApplicationTypes.contains(notification.type) &&
            !PushTarget.studioTypes.contains(notification.type) &&
            !follow) ||
        (session.isVenueApplicationSession &&
            !_applicationScope(notification, session))) {
      return const Result.failure(unavailable);
    }
    try {
      await _client.request<void>(
        ApiHttpMethod.post,
        session.isVenueApplicationSession
            ? '${session.venueApplicationSessionBase}/notifications/${notification.id}/read'
            : NotificationEndpoints.markRead(notification.id),
        requestContext: _context(session),
      );
      return current()
          ? const Result.success(null)
          : const Result.failure(stale);
    } on ApiException catch (error) {
      return Result.failure(current() ? error.error : stale);
    } catch (_) {
      return Result.failure(current() ? unavailable : stale);
    }
  }
}
