import '../../../core/auth/auth_session_manager.dart';
import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/marketplace_report_admin.dart';

class MarketplaceReportAdminRepository {
  MarketplaceReportAdminRepository(this._api, this._sessions);
  final ApiClient _api;
  final AuthSessionManager _sessions;
  static const _path = '/api/v1/admin/marketplace/reports';
  static const _access = AppError(
    code: 'marketplace_admin_access_changed',
    message: 'Oturumun veya inceleme yetkin değişti. Sayfayı yeniden aç.',
  );

  Future<Result<MarketplaceAdminReportPage>> load({
    String status = 'OPEN',
    int page = 0,
  }) => _request(
    ApiHttpMethod.get,
    _path,
    query: {'status': status, 'page': page, 'size': 20},
    decode: MarketplaceAdminReportPage.fromJson,
  );

  Future<Result<MarketplaceAdminReport>> review(
    MarketplaceAdminReport report, {
    required bool removeListing,
    required String note,
  }) => _request(
    ApiHttpMethod.post,
    '$_path/${Uri.encodeComponent(report.id)}/review',
    body: {
      'expectedVersion': report.version,
      'decision': removeListing ? 'REMOVE_LISTING' : 'DISMISS',
      'resolutionNote': note.trim(),
    },
    decode: (value) {
      final updated = MarketplaceAdminReport.fromJson(value);
      if (updated.id != report.id) {
        throw const FormatException('Report identity mismatch');
      }
      return updated;
    },
  );

  Future<Result<T>> _request<T>(
    ApiHttpMethod method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
    required T Function(Object?) decode,
  }) async {
    final session = _sessions.session;
    if (!canManageMarketplaceReports(session)) {
      return const Result.failure(_access);
    }
    var changed = false;
    void observe() {
      if (!identical(session, _sessions.session)) changed = true;
    }

    _sessions.addListener(observe);
    bool current() =>
        !changed &&
        identical(session, _sessions.session) &&
        canManageMarketplaceReports(_sessions.session);
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
        ),
      );
      return current() ? Result.success(value) : const Result.failure(_access);
    } on ApiException catch (e) {
      return Result.failure(current() ? e.error : _access);
    } catch (_) {
      return Result.failure(
        current()
            ? const AppError(
                code: 'marketplace_admin_unavailable',
                message: 'İşlem tamamlanamadı. Lütfen tekrar dene.',
              )
            : _access,
      );
    } finally {
      _sessions.removeListener(observe);
    }
  }
}
