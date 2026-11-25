import '../../../core/auth/auth_session.dart';
import '../../../core/auth/auth_session_manager.dart';
import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';

/// Ties moderator reads and decisions to the session that issued them.
class AdminReportApi {
  const AdminReportApi(
    this._api,
    this._sessions, {
    required this.canRead,
    required this.accessError,
    required this.requestError,
  });

  final ApiClient _api;
  final AuthSessionManager _sessions;
  final bool Function(AuthSession) canRead;
  final AppError accessError;
  final AppError requestError;

  Future<Result<T>> request<T>(
    ApiHttpMethod method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
    required T Function(Object?) decode,
  }) async {
    final session = _sessions.session;
    final revision = _sessions.credentialRevision;
    if (!canRead(session)) return Result.failure(accessError);
    var changed = false;
    void observe() {
      if (!identical(session, _sessions.session)) changed = true;
    }

    _sessions.addListener(observe);
    bool current() =>
        !changed &&
        revision == _sessions.credentialRevision &&
        identical(session, _sessions.session) &&
        canRead(_sessions.session);
    try {
      final value = await _api.request<T>(
        method,
        path,
        query: query,
        body: body,
        decoder: decode,
        requestContext: ApiRequestContext(
          expectedSessionKey: session.userId,
          expectedToken: session.token,
          expectedCredentialRevision: revision,
        ),
      );
      return current() ? Result.success(value) : Result.failure(accessError);
    } on ApiException catch (error) {
      return Result.failure(current() ? error.error : accessError);
    } catch (_) {
      return Result.failure(current() ? requestError : accessError);
    } finally {
      _sessions.removeListener(observe);
    }
  }
}
