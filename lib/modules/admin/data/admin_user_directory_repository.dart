import 'package:uuid/uuid.dart';

import '../../../core/auth/auth_session_manager.dart';
import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/pagination/page.dart';
import '../domain/admin_user_directory.dart';
import '../domain/admin_analytics_report.dart';
import '../domain/admin_decision_reason.dart';
import 'admin_report_api.dart';

class AdminUserDirectoryRepository {
  AdminUserDirectoryRepository(ApiClient api, AuthSessionManager sessions)
    : _sessions = sessions,
      _api = AdminReportApi(
        api,
        sessions,
        canRead: canReadAdminUsers,
        accessError: adminUsersAccessError,
        requestError: const AppError(
          code: 'admin_users_unavailable',
          message: 'Hesap bilgileri doğrulanamadı. Lütfen tekrar dene.',
        ),
      );

  static const pageSize = 20;
  static const maxPage = 1000;
  static const maxQueryLength = 80;
  static const _path = '/api/v1/admin/users';
  final AdminReportApi _api;
  final AuthSessionManager _sessions;

  Future<Result<AdminAnalyticsReport>> analyticsReport(
    DateTime month,
    AdminUserProfileType? profile,
  ) {
    final period = reportMonth(month);
    return _api.request(
      ApiHttpMethod.get,
      '$_path/analytics-report',
      query: {
        'month': period,
        if (profile != null) 'profileType': profile.wire,
      },
      decode: (data) => AdminAnalyticsReport.read(data, period, profile),
    );
  }

  Future<Result<MemberPreferenceCounts>> preferenceCounts(
    AdminUserProfileType? profileType,
  ) => _api.request(
    ApiHttpMethod.get,
    '$_path/analytics-preferences',
    query: {if (profileType != null) 'profileType': profileType.wire},
    decode: MemberPreferenceCounts.fromJson,
  );

  Future<Result<Page<AdminUserAccount>>> search({
    String query = '',
    AdminUserProfileType? profileType,
    AdminUserStatus? status,
    bool suspendedOnly = false,
    int page = 0,
  }) {
    final text = query.trim();
    if (page < 0 || page > maxPage || text.length > maxQueryLength) {
      return Future.value(
        const Result.failure(
          AppError(
            code: 'admin_users_invalid_query',
            message: 'Arama ölçütlerini kontrol et.',
          ),
        ),
      );
    }
    return _api.request(
      ApiHttpMethod.get,
      _path,
      query: {
        if (text.isNotEmpty) 'query': text,
        if (profileType != null) 'profileType': profileType.wire,
        if (status != null) 'status': status.wire,
        if (suspendedOnly) 'suspended': true,
        'page': page,
        'size': pageSize,
      },
      decode: (value) {
        final json = value as Map;
        final rows = (json['content'] as List)
            .map(AdminUserAccount.fromJson)
            .toList();
        final total = json['totalElements'] as int;
        final pages = (total + pageSize - 1) ~/ pageSize;
        if (total < 0 ||
            json['page'] != page ||
            json['size'] != pageSize ||
            json['totalPages'] != pages ||
            rows.length > pageSize ||
            rows.map((row) => row.userId).toSet().length != rows.length ||
            rows.any(
              (row) =>
                  (profileType != null && row.profileType != profileType) ||
                  (status != null && row.status != status) ||
                  (suspendedOnly && !row.suspended),
            )) {
          throw const FormatException('Unexpected account directory page');
        }
        return Page(
          items: List.unmodifiable(rows),
          hasNext: page + 1 < pages,
          totalElements: total,
        );
      },
    );
  }

  Future<Result<AdminUserDetail>> detail(String userId) {
    if (!Uuid.isValidUUID(fromString: userId)) {
      return Future.value(
        const Result.failure(
          AppError(
            code: 'admin_users_invalid_id',
            message: 'Hesap kimliği geçersiz.',
          ),
        ),
      );
    }
    return _api.request(
      ApiHttpMethod.get,
      '$_path/$userId',
      decode: (value) {
        final detail = AdminUserDetail.fromJson(
          value,
          allowChanges: _sessions.session.permissions.contains('MANAGE_USERS'),
        );
        if (detail.account.userId != userId) {
          throw const FormatException('Unexpected account identity');
        }
        return detail;
      },
    );
  }

  Future<Result<bool>> changeAccess(AdminUserDetail detail, String reason) {
    final session = _sessions.session;
    final revision = detail.accessRevision;
    if (!canReadAdminUsers(session) ||
        !session.permissions.contains('MANAGE_USERS') ||
        !detail.canManageAccess ||
        revision == null ||
        revision < 0 ||
        session.userId == detail.account.userId) {
      return Future.value(const Result.failure(adminUsersAccessError));
    }
    final text = reason.trim();
    if (!isValidAdminDecisionReason(text)) {
      return Future.value(
        const Result.failure(
          AppError(
            code: 'invalid_access_reason',
            message: '5–500 karakterlik bir gerekçe yaz.',
          ),
        ),
      );
    }
    final suspended = !detail.account.suspended;
    return _api.request(
      ApiHttpMethod.post,
      '$_path/${detail.account.userId}/access',
      body: {
        'suspended': suspended,
        'expectedRevision': revision,
        'requestId': const Uuid().v4(),
        'reason': text,
      },
      decode: (value) {
        final response = value as Map;
        if (response['suspended'] != suspended ||
            response['revision'] != revision + 1) {
          throw const FormatException('Unexpected access decision');
        }
        return suspended;
      },
    );
  }
}
