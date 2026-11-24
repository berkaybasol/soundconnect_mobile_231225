import 'package:uuid/uuid.dart';

import '../../../core/auth/auth_session_manager.dart';
import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../collab/domain/collab_page.dart';
import '../../content_report/domain/content_report.dart';
import '../../studio/data/models/studio_json.dart';
import '../domain/admin_decision_reason.dart';
import '../domain/admin_panel_access.dart';
import 'admin_report_api.dart';

enum ContentReportStatus {
  open('OPEN', 'Açık'),
  resolved('RESOLVED', 'Sonuçlanmış');

  const ContentReportStatus(this.wire, this.label);
  final String wire, label;
}

enum ContentReportDecision {
  dismiss('DISMISS', 'İşlem yapmadan kapat'),
  confirm('CONFIRM_VIOLATION', 'İhlali kaydet'),
  remove('REMOVE_CONTENT', 'Bildirilen içeriği kaldır');

  const ContentReportDecision(this.wire, this.label);
  final String wire, label;
}

class AdminContentReport {
  AdminContentReport.fromJson(Object? value)
    : this._(studioJsonObject(value, 'content report'));

  AdminContentReport._(Map<String, dynamic> json)
    : id = studioJsonString(json, 'id'),
      version = studioJsonInt(json, 'version'),
      kind = ContentReportKind.fromWire(studioJsonString(json, 'kind')),
      reason = ContentReportReason.fromWire(studioJsonString(json, 'reason')),
      status = ContentReportStatus.values.firstWhere(
        (s) => s.wire == json['status'],
      ),
      reportedAt = studioJsonInstant(json, 'reportedAt'),
      targetLabel = studioJsonString(json, 'targetLabel'),
      description = studioJsonNullableString(json, 'description'),
      reporter = studioJsonNullableString(json, 'reporterUsername'),
      evidenceText = studioJsonNullableString(json, 'evidenceText'),
      parentText = studioJsonNullableString(json, 'parentText'),
      _profileUserId = studioJsonNullableString(json, 'profileUserId'),
      _removable = studioJsonBool(json, 'removable', fallback: false),
      decision = json['decision'] == null
          ? null
          : ContentReportDecision.values.firstWhere(
              (d) => d.wire == json['decision'],
            ),
      resolutionNote = studioJsonNullableString(json, 'resolutionNote'),
      reviewer = studioJsonNullableString(json, 'reviewerUsername'),
      reviewedAt = studioJsonNullableInstant(json, 'reviewedAt') {
    if (!Uuid.isValidUUID(fromString: id) || version < 0) {
      throw const FormatException('Invalid report identity');
    }
  }

  final String id, targetLabel;
  final int version;
  final ContentReportKind kind;
  final ContentReportReason reason;
  final ContentReportStatus status;
  final DateTime reportedAt;
  final String? reporter, evidenceText, parentText, description, _profileUserId;
  final bool _removable;
  final ContentReportDecision? decision;
  final String? resolutionNote, reviewer;
  final DateTime? reviewedAt;

  bool get isProfile => switch (kind) {
    ContentReportKind.listenerProfile ||
    ContentReportKind.musicianProfile ||
    ContentReportKind.venueProfile ||
    ContentReportKind.studioProfile => true,
    _ => false,
  };

  // A post or comment never links its author to the account directory.
  String? get profileUserId => isProfile ? _profileUserId : null;

  bool allows(ContentReportDecision decision) =>
      status == ContentReportStatus.open &&
      (decision != ContentReportDecision.remove || (!isProfile && _removable));
}

class ContentReportAdminRepository {
  ContentReportAdminRepository(ApiClient api, AuthSessionManager sessions)
    : _api = AdminReportApi(
        api,
        sessions,
        canRead: canManageContentReports,
        accessError: accessError,
        requestError: const AppError(
          code: 'content_reports_unavailable',
          message: 'Şikâyet kaydı doğrulanamadı. Tekrar dene.',
        ),
      );

  static const accessError = AppError(
    code: 'content_reports_access_changed',
    message: 'Bu şikâyetleri inceleme yetkin veya oturumun değişti.',
  );
  static bool isAccessError(AppError? error) =>
      isAdminPanelAccessError(error) || error?.code == accessError.code;

  static const _path = '/api/v1/admin/content-reports';
  static const _size = 20;
  final AdminReportApi _api;

  Future<Result<CollabPage<AdminContentReport>>> list(
    ContentReportStatus status,
    ContentReportKind? kind,
    int page,
  ) => _api.request(
    ApiHttpMethod.get,
    _path,
    query: {
      'status': status.wire,
      if (kind != null) 'kind': kind.wire,
      'page': page,
      'size': _size,
    },
    decode: (value) {
      final data = studioPageFromJson(value, AdminContentReport.fromJson);
      if (data.pageIndex != page ||
          data.pageSize != _size ||
          data.items.any(
            (r) => r.status != status || (kind != null && r.kind != kind),
          )) {
        throw const FormatException('Unexpected content report page');
      }
      return CollabPage(
        items: data.items,
        page: data.pageIndex,
        size: data.pageSize,
        totalElements: data.totalItems,
        totalPages: data.totalPages,
        first: data.isFirst,
        last: data.isLast,
      );
    },
  );

  AdminContentReport _matching(Object? value, String id) {
    final report = AdminContentReport.fromJson(value);
    if (report.id != id) throw const FormatException('Unexpected report ID');
    return report;
  }

  Future<Result<AdminContentReport>> detail(String id) => _api.request(
    ApiHttpMethod.get,
    '$_path/${Uri.encodeComponent(id)}',
    decode: (value) => _matching(value, id),
  );

  Future<Result<AdminContentReport>> review(
    AdminContentReport report,
    ContentReportDecision decision,
    String note,
  ) {
    if (!report.allows(decision) || !isValidAdminDecisionReason(note)) {
      return Future.value(
        const Result.failure(
          AppError(
            code: 'content_report_invalid_review',
            message: 'Kararı ve gerekçeyi kontrol et.',
          ),
        ),
      );
    }
    return _api.request(
      ApiHttpMethod.post,
      '$_path/${report.id}/review',
      body: {
        'decision': decision.wire,
        'expectedVersion': report.version,
        'resolutionNote': note.trim(),
      },
      decode: (value) {
        final saved = _matching(value, report.id);
        if (saved.status != ContentReportStatus.resolved ||
            saved.decision != decision ||
            saved.version <= report.version) {
          throw const FormatException('Unexpected decision response');
        }
        return saved;
      },
    );
  }
}
