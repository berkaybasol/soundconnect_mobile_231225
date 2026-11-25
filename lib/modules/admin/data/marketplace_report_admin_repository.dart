import '../../../core/auth/auth_session_manager.dart';
import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../domain/marketplace_report_admin.dart';
import 'admin_report_api.dart';

class MarketplaceReportAdminRepository {
  MarketplaceReportAdminRepository(ApiClient api, AuthSessionManager sessions)
    : _api = AdminReportApi(
        api,
        sessions,
        canRead: canManageMarketplaceReports,
        accessError: _access,
        requestError: const AppError(
          code: 'marketplace_admin_unavailable',
          message: 'İşlem tamamlanamadı. Lütfen tekrar dene.',
        ),
      );
  final AdminReportApi _api;
  static const _path = '/api/v1/admin/marketplace/reports';
  static const _access = AppError(
    code: 'marketplace_admin_access_changed',
    message: 'Oturumun veya inceleme yetkin değişti. Sayfayı yeniden aç.',
  );

  Future<Result<MarketplaceAdminReportPage>> load({
    String status = 'OPEN',
    int page = 0,
  }) => _api.request(
    ApiHttpMethod.get,
    _path,
    query: {'status': status, 'page': page, 'size': 20},
    decode: MarketplaceAdminReportPage.fromJson,
  );

  Future<Result<MarketplaceAdminReport>> review(
    MarketplaceAdminReport report, {
    required bool removeListing,
    required String note,
  }) => _api.request(
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
}
