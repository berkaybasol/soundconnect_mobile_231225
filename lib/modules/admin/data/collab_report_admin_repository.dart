import 'package:uuid/uuid.dart';

import '../../../core/auth/auth_session_manager.dart';
import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../collab/data/models/collab_api_models.dart';
import '../../collab/domain/collab_page.dart';
import '../../collab/domain/collab_types.dart';
import '../domain/collab_report_admin.dart';
import '../domain/collab_report_admin_access.dart';
import 'admin_report_api.dart';

class CollabReportAdminRepository {
  CollabReportAdminRepository(ApiClient api, AuthSessionManager sessions)
    : _api = AdminReportApi(
        api,
        sessions,
        canRead: canManageCollabReports,
        accessError: const AppError(
          code: 'collab_report_access_changed',
          message: 'Oturumun veya inceleme yetkin değişti. Sayfayı yeniden aç.',
        ),
        requestError: const AppError(
          code: 'collab_report_unavailable',
          message: 'Şikâyet bilgileri doğrulanamadı. Lütfen tekrar dene.',
        ),
      );

  final AdminReportApi _api;
  static const _path = '/api/v1/admin/collab/reports';
  static const _pageSize = 20;
  static const _invalid = AppError(
    code: 'collab_report_invalid',
    message: 'Şikâyet bilgileri geçersiz.',
  );

  Future<Result<CollabPage<CollabAdminReport>>> load({
    CollabReportStatus status = CollabReportStatus.open,
    CollabReportReason? reason,
    int page = 0,
  }) {
    if (page < 0 || page > 1000) {
      return Future.value(const Result.failure(_invalid));
    }
    return _api.request(
      ApiHttpMethod.get,
      _path,
      query: {
        'status': status.apiValue,
        if (reason != null) 'reason': reason.apiValue,
        'page': page,
        'size': _pageSize,
      },
      decode: (data) {
        final result = decodeCollabPage(
          data,
          CollabAdminReport.fromJson,
          fallbackPage: page,
          fallbackSize: _pageSize,
        );
        if (result.page != page ||
            result.items.length > _pageSize ||
            result.items.any(
              (r) =>
                  r.status != status || (reason != null && r.reason != reason),
            )) {
          throw const FormatException('Unexpected report page');
        }
        return result;
      },
    );
  }

  Future<Result<CollabAdminReport>> detail(String reportId) {
    if (!Uuid.isValidUUID(fromString: reportId)) {
      return Future.value(const Result.failure(_invalid));
    }
    return _api.request(
      ApiHttpMethod.get,
      '$_path/$reportId',
      decode: (value) => _reportFor(reportId, value),
    );
  }

  Future<Result<CollabAdminReport>> review(
    CollabAdminReport report, {
    required CollabReportDecision decision,
    required String note,
  }) {
    if (!Uuid.isValidUUID(fromString: report.id) ||
        report.status != CollabReportStatus.open ||
        report.version < 0 ||
        !isValidCollabResolutionNote(note)) {
      return Future.value(const Result.failure(_invalid));
    }
    return _api.request(
      ApiHttpMethod.post,
      '$_path/${report.id}/review',
      body: {
        'decision': decision.apiValue,
        'expectedVersion': report.version,
        'resolutionNote': note.trim(),
      },
      decode: (data) {
        final updated = _reportFor(report.id, data);
        if (updated.reviewDecision != decision ||
            updated.status != decision.resultingStatus) {
          throw const FormatException('Unexpected report decision');
        }
        return updated;
      },
    );
  }

  CollabAdminReport _reportFor(String reportId, Object? value) {
    final report = CollabAdminReport.fromJson(value);
    if (report.id != reportId) {
      throw const FormatException('Unexpected report ID');
    }
    return report;
  }
}
