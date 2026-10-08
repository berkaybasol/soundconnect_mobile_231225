import '../../../core/auth/auth_session.dart';
import '../../../core/auth/auth_session_manager.dart';
import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/push/push_provider.dart';
import 'models/login_response.dart';
import '../domain/entities/user_status.dart';

class VenueApplicationDetail {
  const VenueApplicationDetail({
    required this.id,
    required this.applicantUserId,
    required this.status,
    required this.venueName,
    this.venueId,
  });
  final String id, applicantUserId, status, venueName;
  final String? venueId;

  factory VenueApplicationDetail.fromJson(Object? json) {
    if (json is! Map<String, dynamic> ||
        !PushTarget.isUuid(json['id']) ||
        !PushTarget.isUuid(json['applicantUserId']) ||
        !const {'PENDING', 'APPROVED', 'REJECTED'}.contains(json['status']) ||
        json['venueName'] is! String ||
        (json['venueName'] as String).trim().isEmpty ||
        (json['status'] == 'APPROVED'
            ? !PushTarget.isUuid(json['venueId'])
            : json['venueId'] != null)) {
      throw const FormatException('Invalid application detail');
    }
    return VenueApplicationDetail(
      id: json['id'],
      applicantUserId: json['applicantUserId'],
      status: json['status'],
      venueName: json['venueName'],
      venueId: json['venueId'],
    );
  }
}

class VenueApplicationRepository {
  VenueApplicationRepository(this._client, this._sessions);
  final ApiClient _client;
  final AuthSessionManager _sessions;
  static const unavailable = AppError(
    code: 'venue_application_unavailable',
    message:
        'Başvuru durumu şu anda alınamıyor. Bağlantını kontrol edip tekrar dene.',
  );
  bool _current(AuthSession session, String id) =>
      identical(_sessions.session, session) &&
      session.isAuthenticated &&
      !session.requiresListenerProfileChoice &&
      PushTarget.isUuid(id) &&
      (session.isVenueApplicationSession
          ? session.applicationId == id
          : session.isActive &&
                session.hasAnyRole(const ['ROLE_VENUE', 'VENUE']));
  ApiRequestContext _context(AuthSession session) => ApiRequestContext(
    expectedSessionKey: session.userId,
    expectedToken: session.token,
  );
  String _base(String id) =>
      '/api/v1/venue-application-session/applications/$id';

  Future<Result<VenueApplicationDetail>> get(
    String id,
    AuthSession session,
  ) async {
    if (!_current(session, id)) return const Result.failure(unavailable);
    try {
      final detail = await _client.request<VenueApplicationDetail>(
        ApiHttpMethod.get,
        _base(id),
        requestContext: _context(session),
        decoder: VenueApplicationDetail.fromJson,
      );
      if (!_current(session, id) ||
          detail.id != id ||
          detail.applicantUserId != session.userId) {
        return const Result.failure(unavailable);
      }
      return Result.success(detail);
    } catch (_) {
      return const Result.failure(unavailable);
    }
  }

  Future<Result<bool>> promote(String id, AuthSession session) async {
    if (!_current(session, id) || !session.isVenueApplicationSession) {
      return const Result.failure(unavailable);
    }
    try {
      final login = await _client.request<LoginResponse>(
        ApiHttpMethod.post,
        '${_base(id)}/promote',
        requestContext: _context(session),
        decoder: (json) => LoginResponse.fromJson(json as Map<String, dynamic>),
      );
      if (!_current(session, id) ||
          login.userId != session.userId ||
          login.status.apiValue != 'ACTIVE' ||
          login.sessionScope != null ||
          login.applicationId != null ||
          login.requiresListenerProfileChoice) {
        return const Result.failure(unavailable);
      }
      final committed = await _sessions.promoteVenueApplication(
        expected: session,
        token: login.token,
        username: login.username,
      );
      return committed
          ? const Result.success(true)
          : const Result.failure(unavailable);
    } catch (_) {
      return const Result.failure(unavailable);
    }
  }
}
