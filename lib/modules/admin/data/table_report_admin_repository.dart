import 'package:uuid/uuid.dart';

import '../../../core/auth/auth_session_manager.dart';
import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../collab/domain/collab_page.dart';
import '../../studio/data/models/studio_json.dart';
import '../../tablegroup/domain/table_group_report.dart';
import '../domain/admin_panel_access.dart';
import '../domain/admin_decision_reason.dart';
import 'admin_report_api.dart';

enum TableReportStatus {
  open('OPEN', 'Açık'),
  resolved('RESOLVED', 'Sonuçlanmış');

  const TableReportStatus(this.wire, this.label);
  final String wire, label;
}

enum TableReportDecision {
  dismiss('DISMISS', 'İşlem gerekmiyor'),
  violation('CONFIRM_VIOLATION', 'İhlal tespit edildi'),
  removeMessage('REMOVE_MESSAGE', 'Bildirilen mesajı kaldır'),
  removeTable('REMOVE_TABLE', 'Masayı yayından kaldır');

  const TableReportDecision(this.wire, this.label);
  final String wire, label;
  bool get removesContent => this == removeMessage || this == removeTable;
}

class TableAdminReport {
  TableAdminReport.fromJson(Object? value)
    : this._(studioJsonObject(value, 'table report'));
  TableAdminReport._(Map<String, dynamic> data)
    : id = studioJsonString(data, 'id'),
      version = studioJsonInt(data, 'version'),
      kind = TableGroupReportKind.fromWire(data['kind']),
      reason = TableGroupReportReason.fromWire(data['reason']),
      status = TableReportStatus.values.byName(
        studioJsonString(data, 'status').toLowerCase(),
      ),
      reportedAt = studioJsonInstant(data, 'reportedAt'),
      tableDescription = studioJsonNullableString(data, 'tableDescription'),
      owner = studioJsonNullableString(data, 'ownerUsername'),
      venue = studioJsonNullableString(data, 'venueName'),
      city = studioJsonNullableString(data, 'cityName'),
      district = studioJsonNullableString(data, 'districtName'),
      meetingAt = studioJsonNullableInstant(data, 'meetingAt'),
      reporter = studioJsonNullableString(data, 'reporterUsername'),
      statement = studioJsonNullableString(data, 'description'),
      message = studioJsonNullableString(data, 'messageText'),
      sender = studioJsonNullableString(data, 'senderUsername'),
      messageSentAt = studioJsonNullableInstant(data, 'messageSentAt'),
      membershipEnd = studioJsonNullableString(data, 'membershipEndReason'),
      membershipEndedAt = studioJsonNullableInstant(data, 'membershipEndedAt'),
      active = studioJsonBool(data, 'tableActive', fallback: false),
      removed = studioJsonBool(data, 'tableRemoved', fallback: false),
      messageRemovable = studioJsonBool(
        data,
        'messageRemovable',
        fallback: false,
      ),
      decision = data['decision'] == null
          ? null
          : TableReportDecision.values.firstWhere(
              (d) => d.wire == data['decision'],
            ),
      reviewNote = studioJsonNullableString(data, 'resolutionNote'),
      reviewer = studioJsonNullableString(data, 'reviewerUsername'),
      reviewedAt = studioJsonNullableInstant(data, 'reviewedAt');
  final String id;
  final int version;
  final TableReportStatus status;
  final TableGroupReportKind kind;
  final TableGroupReportReason reason;
  final DateTime reportedAt;
  final String? tableDescription,
      owner,
      venue,
      city,
      district,
      reporter,
      statement,
      message,
      sender,
      membershipEnd,
      reviewNote,
      reviewer;
  final DateTime? meetingAt, messageSentAt, membershipEndedAt, reviewedAt;
  final bool active, removed, messageRemovable;
  final TableReportDecision? decision;
  String get title => tableDescription ?? venue ?? 'Masa';
  bool allows(TableReportDecision choice) =>
      status == TableReportStatus.open &&
      switch (choice) {
        TableReportDecision.removeMessage =>
          kind == TableGroupReportKind.message && messageRemovable,
        TableReportDecision.removeTable => active && !removed,
        _ => true,
      };
}

class TableReportAdminRepository {
  TableReportAdminRepository(ApiClient api, AuthSessionManager sessions)
    : _api = AdminReportApi(
        api,
        sessions,
        canRead: canManageTableReports,
        accessError: accessError,
        requestError: const AppError(
          code: 'table_admin_unavailable',
          message: 'Masa şikâyeti bilgileri alınamadı. Tekrar dene.',
        ),
      );
  static const accessError = AppError(
    code: 'table_admin_access_changed',
    message: 'Masa şikâyetlerini inceleme yetkin değişti.',
  );
  static const _path = '/api/v1/admin/table-group-reports';
  static const _size = 20;
  final AdminReportApi _api;

  Future<Result<CollabPage<TableAdminReport>>> list(
    TableReportStatus status,
    TableGroupReportKind? kind,
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
      final data = studioPageFromJson(value, TableAdminReport.fromJson);
      if (data.pageIndex != page ||
          data.pageSize != _size ||
          data.items.any(
            (r) => r.status != status || (kind != null && r.kind != kind),
          )) {
        throw const FormatException('Unexpected table report page');
      }
      return CollabPage(
        items: data.items,
        page: page,
        size: data.pageSize,
        totalElements: data.totalItems,
        totalPages: data.totalPages,
        first: data.isFirst,
        last: data.isLast,
      );
    },
  );

  TableAdminReport _matching(String id, Object? value) {
    final report = TableAdminReport.fromJson(value);
    if (report.id != id) throw const FormatException('Unexpected report ID');
    return report;
  }

  Future<Result<TableAdminReport>> detail(String id) => _api.request(
    ApiHttpMethod.get,
    '$_path/${Uri.encodeComponent(id)}',
    decode: (value) => _matching(id, value),
  );

  Future<Result<TableAdminReport>> review(
    TableAdminReport report,
    TableReportDecision decision,
    String note,
  ) {
    if (!Uuid.isValidUUID(fromString: report.id) ||
        !report.allows(decision) ||
        !isValidAdminDecisionReason(note)) {
      return Future.value(
        const Result.failure(
          AppError(
            code: 'table_report_invalid',
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
        final saved = _matching(report.id, value);
        if (saved.status != TableReportStatus.resolved ||
            saved.decision != decision) {
          throw const FormatException('Unexpected decision response');
        }
        return saved;
      },
    );
  }
}
