import '../../../core/auth/auth_session.dart';
import '../../../core/auth/auth_session_manager.dart';
import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../studio/data/models/studio_json.dart';
import '../../studio/domain/entities/studio_page.dart';
import 'admin_report_api.dart';

/// Paged, session-bound reads for the lists in the admin Applications tab.
class AdminListRepository<T> {
  AdminListRepository(
    ApiClient api,
    AuthSessionManager sessions, {
    required this.path,
    required this.canRead,
    required this.accessError,
    required this.listError,
    required this.decodeRow,
  }) : _api = AdminReportApi(
         api,
         sessions,
         canRead: canRead,
         accessError: accessError,
         requestError: listError,
       );

  static const maxPage = 1000;
  static const pageSize = 20;
  final String path;
  final bool Function(AuthSession) canRead;
  final AppError accessError;
  final AppError listError;
  final T Function(Object?) decodeRow;
  final AdminReportApi _api;

  Future<Result<StudioPage<T>>> list(int page) => _api.request(
    ApiHttpMethod.get,
    path,
    query: {'page': page, 'size': pageSize},
    decode: (value) {
      final parsed = studioPageFromJson(value, decodeRow);
      if (parsed.pageIndex != page || parsed.pageSize != pageSize) {
        throw const FormatException('Unexpected admin list page');
      }
      return parsed;
    },
  );
}
