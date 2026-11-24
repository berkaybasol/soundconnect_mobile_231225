import '../../../core/auth/auth_session.dart';
import '../../../core/auth/auth_session_manager.dart';
import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/content_report.dart';

class ContentReportRepository {
  const ContentReportRepository(this._api, this.sessions);
  final ApiClient _api;
  final AuthSessionManager sessions;

  static bool canReport(AuthSession session) =>
      session.isAuthenticated &&
      session.isActive &&
      !session.requiresListenerProfileChoice &&
      session.userId?.isNotEmpty == true;

  bool current(AuthSession expected, int revision) =>
      identical(sessions.session, expected) &&
      sessions.credentialRevision == revision &&
      canReport(expected);

  Future<Result<String>> submit({
    required AuthSession expected,
    required int revision,
    required String requestId,
    required ContentReportKind kind,
    required String targetId,
    required ContentReportReason reason,
    required String description,
    String? profileId,
  }) async {
    const changed = AppError(
      code: 'content_report_session',
      message: 'Oturum değişti.',
    );
    if (!current(expected, revision)) return const Result.failure(changed);
    try {
      final id = await _api.request<String>(
        ApiHttpMethod.post,
        '/api/v1/content-reports',
        requestContext: ApiRequestContext(
          expectedSessionKey: expected.userId,
          expectedToken: expected.token,
          expectedCredentialRevision: revision,
        ),
        body: {
          'requestId': requestId,
          'kind': kind.wire,
          'targetId': targetId,
          if (profileId != null) 'profileId': profileId,
          'reason': reason.wire,
          if (description.trim().isNotEmpty) 'description': description.trim(),
        },
        decoder: (json) {
          if (json case {'id': String id} when id.trim().isNotEmpty) return id;
          throw const FormatException('Geçersiz şikâyet kaydı.');
        },
      );
      return current(expected, revision)
          ? Result.success(id)
          : const Result.failure(changed);
    } on ApiException catch (error) {
      return Result.failure(
        current(expected, revision) ? error.error : changed,
      );
    } catch (_) {
      return const Result.failure(
        AppError(
          code: 'content_report_unavailable',
          message: 'Gönderim doğrulanamadı. Tekrar deneyebilirsin.',
        ),
      );
    }
  }
}
