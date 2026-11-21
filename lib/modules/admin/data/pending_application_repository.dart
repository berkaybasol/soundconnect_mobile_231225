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
  ) => _get(
    session,
    kind,
    query: {'page': page, 'size': 20},
    decode: (data) {
      final json = data as Map;
      if (json['page'] != page) throw const FormatException('Unexpected page');
      return Page(
        items: List.unmodifiable(
          (json['content'] as List).map(PendingApplication.fromJson),
        ),
        hasNext: !(json['last'] as bool),
      );
    },
  );

  Future<Result<PendingApplication>> detail(
    AuthSession session,
    ApplicationKind kind,
    String id,
  ) => _get(
    session,
    kind,
    suffix: '/${Uri.encodeComponent(id)}',
    decode: (data) {
      final item = PendingApplication.fromJson(data);
      if (item.id != id) throw const FormatException('Unexpected application');
      return item;
    },
  );

  Future<Result<T>> _get<T>(
    AuthSession session,
    ApplicationKind kind, {
    String suffix = '',
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
        ApiHttpMethod.get,
        '/api/v1/admin/${kind.pathName}-applications/pending$suffix',
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
      if (!current() || const {'403', '1102'}.contains(e.error.code)) {
        return const Result.failure(denied);
      }
      if (const {'404', '1601', '1609'}.contains(e.error.code)) {
        return const Result.failure(
          AppError(
            code: 'not_pending',
            message:
                'Bu başvuru artık bekleyen başvurular arasında görünmüyor.',
          ),
        );
      }
      return Result.failure(e.error);
    } catch (_) {
      return const Result.failure(
        AppError(
          code: 'application_read_failed',
          message: 'Başvuru bilgileri alınamadı.',
        ),
      );
    }
  }
}
