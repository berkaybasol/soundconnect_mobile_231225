import '../../../core/auth/auth_session.dart';
import '../../../core/auth/auth_session_manager.dart';
import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/pagination/page.dart';
import '../domain/pending_application.dart';

class PendingApplicationRepository {
  PendingApplicationRepository(this._api, this._sessions);
  final ApiClient _api;
  final AuthSessionManager _sessions;

  Future<Result<Page<PendingApplication>>> list(
    AuthSession session,
    ApplicationKind kind,
    int page,
  ) => _request(
    session,
    kind,
    'pending',
    query: {'page': page, 'size': 20},
    decode: (data) {
      final json = data as Map;
      if (json['page'] != page) throw const FormatException('Unexpected page');
      final items = (json['content'] as List)
          .map(PendingApplication.fromJson)
          .toList();
      if (items.any((item) => item.status != ApplicationReviewStatus.pending)) {
        throw const FormatException('Expected pending applications');
      }
      return Page(
        items: List.unmodifiable(items),
        hasNext: !(json['last'] as bool),
      );
    },
  );

  Future<Result<PendingApplication>> detail(
    AuthSession session,
    ApplicationKind kind,
    String id,
  ) => _request(
    session,
    kind,
    'review/${Uri.encodeComponent(id)}',
    decode: (data) {
      final item = PendingApplication.fromJson(data);
      if (item.id != id) throw const FormatException('Unexpected application');
      return item;
    },
  );

  Future<Result<bool>> decide(
    AuthSession session,
    ApplicationKind kind,
    String id, {
    required bool approve,
    String reason = '',
  }) {
    final error = approve ? null : applicationRejectionError(reason);
    if (error != null) {
      return Future.value(
        Result.failure(AppError(code: 'invalid_reason', message: error)),
      );
    }
    return _request(
      session,
      kind,
      '${approve ? 'approve' : 'reject'}/${Uri.encodeComponent(id)}',
      method: ApiHttpMethod.post,
      body: approve ? null : {'reason': reason.trim()},
      decode: (_) => true,
    );
  }

  Future<Result<T>> _request<T>(
    AuthSession session,
    ApplicationKind kind,
    String path, {
    ApiHttpMethod method = ApiHttpMethod.get,
    Object? body,
    Map<String, dynamic>? query,
    required T Function(Object?) decode,
  }) async {
    const denied = AppError(
      code: 'access_changed',
      message: 'Başvuruları görme yetkin değişti.',
    );
    bool current() =>
        identical(session, _sessions.session) && kind.canRead(session);
    if (!current()) return const Result.failure(denied);
    try {
      final data = await _api.request<T>(
        method,
        '/api/v1/admin/${kind.pathName}-applications/$path',
        body: body,
        query: query,
        decoder: decode,
        requestContext: ApiRequestContext(
          expectedSessionKey: session.userId,
          expectedToken: session.token,
          expectedCredentialRevision: _sessions.credentialRevision,
        ),
      );
      return current() ? Result.success(data) : const Result.failure(denied);
    } on ApiException catch (e) {
      if (!current() ||
          const {'401', '403', '1101', '1102'}.contains(e.error.code)) {
        return const Result.failure(denied);
      }
      if (const {'404', '1601', '1609'}.contains(e.error.code)) {
        return const Result.failure(
          AppError(
            code: 'not_pending',
            message: 'Bu başvuruya artık erişilemiyor.',
          ),
        );
      }
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        AppError(
          code: 'application_request_failed',
          message: method == ApiHttpMethod.get
              ? 'Başvuru bilgileri alınamadı.'
              : 'Karar gönderilirken bağlantı kesildi.',
        ),
      );
    }
  }
}
