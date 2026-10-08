import '../../../core/auth/auth_session_manager.dart';
import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/system_health.dart';

class SystemHealthRepository {
  SystemHealthRepository(this._api, this._sessions);
  final ApiClient _api;
  final AuthSessionManager _sessions;
  static const path = '/api/v1/admin/system-health';
  static const _access = AppError(
    code: 'health_access_changed',
    message: 'Oturumun veya yönetim yetkin değişti.',
  );
  static const _unavailable = AppError(
    code: 'health_unavailable',
    message: 'Güncel sağlık bilgisi alınamadı. Son ölçümler eski olabilir.',
  );

  Future<Result<SystemHealthSnapshot>> load() =>
      _load(path, SystemHealthSnapshot.fromJson);

  Future<Result<List<MobileDiagnosticSummary>>> loadRecentEvents() => _load(
    '$path/mobile-events',
    MobileDiagnosticSummary.listFromJson,
    query: const {'limit': 10},
  );

  Future<Result<T>> _load<T>(
    String requestPath,
    T Function(Object?) decoder, {
    Map<String, dynamic>? query,
  }) async {
    final session = _sessions.session;
    final revision = _sessions.credentialRevision;
    if (!canViewSystemHealth(session)) return const Result.failure(_access);
    var changed = false;
    void observe() {
      if (!identical(session, _sessions.session)) changed = true;
    }

    _sessions.addListener(observe);
    bool current() =>
        !changed &&
        revision == _sessions.credentialRevision &&
        identical(session, _sessions.session) &&
        canViewSystemHealth(_sessions.session);
    try {
      final result = await _api.request<T>(
        ApiHttpMethod.get,
        requestPath,
        query: query,
        decoder: decoder,
        requestContext: ApiRequestContext(
          expectedSessionKey: session.userId,
          expectedToken: session.token,
          expectedCredentialRevision: revision,
        ),
      );
      return current() ? Result.success(result) : const Result.failure(_access);
    } on ApiException {
      return Result.failure(current() ? _unavailable : _access);
    } catch (_) {
      return Result.failure(current() ? _unavailable : _access);
    } finally {
      _sessions.removeListener(observe);
    }
  }
}
