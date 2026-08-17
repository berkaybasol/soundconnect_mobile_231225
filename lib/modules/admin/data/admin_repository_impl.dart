import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/pagination/page.dart';
import '../domain/admin_repository.dart';
import '../domain/entities/admin_backline_category_request.dart';
import '../domain/entities/admin_collab_report.dart';
import '../domain/entities/admin_dashboard_summary.dart';
import '../domain/entities/admin_venue_application.dart';
import '../domain/entities/admin_studio_application.dart';
import 'admin_endpoints.dart';
import 'models/admin_dashboard_summary_model.dart';
import 'models/admin_backline_category_request_model.dart';
import 'models/admin_collab_report_model.dart';
import 'models/admin_venue_application_model.dart';
import 'models/admin_studio_application_model.dart';

class AdminRepositoryImpl implements AdminRepository {
  final ApiClient _apiClient;

  AdminRepositoryImpl(this._apiClient);

  @override
  Future<Result<AdminDashboardSummary>> getDashboardSummary() async {
    try {
      final response = await _apiClient.get<AdminDashboardSummary>(
        AdminEndpoints.dashboardSummary,
        decoder: (json) =>
            AdminDashboardSummaryModel.fromJson(json as Map<String, dynamic>),
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'admin_summary_unknown',
          message: 'Admin özeti getirilemedi.',
        ),
      );
    }
  }

  @override
  Future<Result<List<AdminVenueApplication>>> getVenueApplicationsByStatus(
    AdminVenueApplicationStatus status,
  ) async {
    try {
      final response = await _apiClient.get<List<AdminVenueApplication>>(
        AdminEndpoints.venueApplicationsByStatus,
        query: {'status': status.apiValue},
        decoder: (json) {
          final list = json as List? ?? const [];
          return list
              .whereType<Map<String, dynamic>>()
              .map(AdminVenueApplicationModel.fromJson)
              .toList(growable: false);
        },
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'admin_venue_applications_unknown',
          message: 'Mekân başvuruları getirilemedi.',
        ),
      );
    }
  }

  @override
  Future<Result<AdminVenueApplication>> approveVenueApplication(
    String id,
  ) async {
    return _applicationAction(
      path: AdminEndpoints.approveVenueApplication(id),
      fallbackCode: 'admin_venue_approve_unknown',
      fallbackMessage: 'Başvuru onaylanamadı.',
    );
  }

  @override
  Future<Result<AdminVenueApplication>> rejectVenueApplication({
    required String id,
    required String reason,
  }) async {
    final encodedReason = Uri.encodeQueryComponent(reason.trim());
    return _applicationAction(
      path:
          '${AdminEndpoints.rejectVenueApplication(id)}?reason=$encodedReason',
      fallbackCode: 'admin_venue_reject_unknown',
      fallbackMessage: 'Başvuru reddedilemedi.',
    );
  }

  Future<Result<AdminVenueApplication>> _applicationAction({
    required String path,
    required String fallbackCode,
    required String fallbackMessage,
  }) async {
    try {
      final response = await _apiClient.post<AdminVenueApplication>(
        path,
        body: null,
        decoder: (json) =>
            AdminVenueApplicationModel.fromJson(json as Map<String, dynamic>),
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        AppError(code: fallbackCode, message: fallbackMessage),
      );
    }
  }

  @override
  Future<Result<Page<AdminStudioApplication>>> getStudioApplicationsByStatus(
    AdminVenueApplicationStatus status, {
    int page = 0,
    int size = 50,
  }) async {
    try {
      final response = await _apiClient.get<Page<AdminStudioApplication>>(
        AdminEndpoints.studioApplicationsByStatus,
        query: {'status': status.apiValue, 'page': page, 'size': size},
        decoder: (json) {
          if (json is! Map<String, dynamic>) {
            throw const FormatException(
              'Studio application page must be an object',
            );
          }
          final rawContent = json['content'];
          final serverPage = json.containsKey('page')
              ? json['page']
              : json['number'];
          final serverSize = json['size'];
          final totalElements = json['totalElements'];
          final totalPages = json['totalPages'];
          final first = json['first'];
          final last = json['last'];
          if (rawContent is! List ||
              serverPage is! int ||
              serverSize is! int ||
              totalElements is! int ||
              totalPages is! int ||
              first is! bool ||
              last is! bool ||
              serverPage < 0 ||
              serverSize < 1 ||
              serverPage != page ||
              serverSize != size ||
              totalElements < 0 ||
              totalPages < 0) {
            throw const FormatException('Malformed Studio application page');
          }
          final items = rawContent
              .map((item) {
                if (item is! Map<String, dynamic>) {
                  throw const FormatException(
                    'Malformed Studio application item',
                  );
                }
                return AdminStudioApplicationModel.fromJson(item);
              })
              .toList(growable: false);
          final expectedTotalPages = totalElements == 0
              ? 0
              : (totalElements + serverSize - 1) ~/ serverSize;
          if ((totalPages == 0 && totalElements != 0) ||
              totalPages != expectedTotalPages ||
              (totalPages > 0 &&
                  serverPage >= totalPages &&
                  items.isNotEmpty) ||
              items.length > serverSize ||
              items.length > totalElements ||
              first != (serverPage == 0) ||
              last != (totalPages == 0 || serverPage >= totalPages - 1)) {
            throw const FormatException('Inconsistent Studio application page');
          }
          final hasNext = !last;
          return Page<AdminStudioApplication>(
            items: items,
            hasNext: hasNext,
            nextCursor: hasNext ? '${serverPage + 1}' : null,
          );
        },
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'admin_studio_applications_unknown',
          message: 'Stüdyo başvuruları getirilemedi',
        ),
      );
    }
  }

  @override
  Future<Result<AdminStudioApplication>> approveStudioApplication(String id) =>
      _studioApplicationAction(
        path: AdminEndpoints.approveStudioApplication(id),
        fallbackCode: 'admin_studio_approve_unknown',
        fallbackMessage: 'Stüdyo başvurusu onaylanamadı',
      );

  @override
  Future<Result<AdminStudioApplication>> rejectStudioApplication({
    required String id,
    required String reason,
  }) => _studioApplicationAction(
    path: AdminEndpoints.rejectStudioApplication(id),
    body: <String, dynamic>{'reason': reason.trim()},
    fallbackCode: 'admin_studio_reject_unknown',
    fallbackMessage: 'Stüdyo başvurusu reddedilemedi',
  );

  Future<Result<AdminStudioApplication>> _studioApplicationAction({
    required String path,
    Object? body,
    required String fallbackCode,
    required String fallbackMessage,
  }) async {
    try {
      final response = await _apiClient.post<AdminStudioApplication>(
        path,
        body: body,
        decoder: (json) =>
            AdminStudioApplicationModel.fromJson(json as Map<String, dynamic>),
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        AppError(code: fallbackCode, message: fallbackMessage),
      );
    }
  }

  @override
  Future<Result<Page<AdminBacklineCategoryRequest>>>
  getBacklineCategoryRequests({
    AdminBacklineCategoryRequestStatus? status,
    int page = 0,
    int size = 20,
  }) async {
    if (page < 0 || page > 1000 || size < 1 || size > 50) {
      return const Result.failure(
        AppError(
          code: 'admin_backline_category_request_validation',
          message: 'Geçersiz sayfalama isteği.',
        ),
      );
    }
    try {
      final response = await _apiClient.get<Page<AdminBacklineCategoryRequest>>(
        AdminEndpoints.backlineCategoryRequests,
        query: <String, dynamic>{
          if (status != null) 'status': status.apiValue,
          'page': page,
          'size': size,
        },
        decoder: (json) => _decodeBacklineCategoryRequestPage(
          json,
          requestedPage: page,
          requestedSize: size,
        ),
      );
      return Result.success(response);
    } on ApiException catch (error) {
      return Result.failure(error.error);
    } on FormatException {
      return const Result.failure(
        AppError(
          code: 'admin_backline_category_requests_invalid_response',
          message: 'Kategori talepleri beklenen biçimde alınamadı.',
        ),
      );
    } catch (_) {
      return const Result.failure(
        AppError(
          code: 'admin_backline_category_requests_unknown',
          message: 'Kategori talepleri yüklenemedi. Lütfen tekrar dene.',
        ),
      );
    }
  }

  @override
  Future<Result<AdminBacklineCategoryRequest>> reviewBacklineCategoryRequest({
    required String id,
    required AdminBacklineCategoryReviewDecision decision,
    String? note,
  }) async {
    final normalizedId = id.trim();
    final normalizedNote = note?.trim() ?? '';
    if (normalizedId.isEmpty ||
        normalizedNote.length > 500 ||
        (decision == AdminBacklineCategoryReviewDecision.reject &&
            normalizedNote.isEmpty)) {
      return Result.failure(
        AppError(
          code: 'admin_backline_category_request_validation',
          message:
              decision == AdminBacklineCategoryReviewDecision.reject &&
                  normalizedNote.isEmpty
              ? 'Red gerekçesi zorunludur.'
              : normalizedId.isEmpty
              ? 'Kategori talebi kimliği eksik.'
              : 'İnceleme notu 500 karakteri aşamaz.',
        ),
      );
    }
    try {
      final response = await _apiClient.post<AdminBacklineCategoryRequest>(
        AdminEndpoints.reviewBacklineCategoryRequest(normalizedId),
        body: <String, dynamic>{
          'decision': decision.apiValue,
          if (normalizedNote.isNotEmpty) 'note': normalizedNote,
        },
        decoder: AdminBacklineCategoryRequestModel.fromJson,
      );
      return Result.success(response);
    } on ApiException catch (error) {
      return Result.failure(error.error);
    } on FormatException {
      return const Result.failure(
        AppError(
          code: 'admin_backline_category_request_invalid_response',
          message: 'Güncellenen kategori talebi doğrulanamadı.',
        ),
      );
    } catch (_) {
      return Result.failure(
        AppError(
          code: 'admin_backline_category_request_review_unknown',
          message: decision == AdminBacklineCategoryReviewDecision.approve
              ? 'Kategori talebi onaylanamadı.'
              : 'Kategori talebi reddedilemedi.',
        ),
      );
    }
  }

  Page<AdminBacklineCategoryRequest> _decodeBacklineCategoryRequestPage(
    Object? value, {
    required int requestedPage,
    required int requestedSize,
  }) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Kategori talebi sayfası nesne olmalıdır');
    }
    final content = value['content'];
    final page = value.containsKey('page') ? value['page'] : value['number'];
    final size = value['size'];
    final totalElements = value['totalElements'];
    final totalPages = value['totalPages'];
    final first = value['first'];
    final last = value['last'];
    if (content is! List ||
        page is! int ||
        size is! int ||
        totalElements is! int ||
        totalPages is! int ||
        first is! bool ||
        last is! bool ||
        page != requestedPage ||
        size != requestedSize ||
        totalElements < 0 ||
        totalPages < 0) {
      throw const FormatException('Kategori talebi sayfası geçersiz');
    }
    final items = content
        .map(AdminBacklineCategoryRequestModel.fromJson)
        .toList(growable: false);
    final expectedPages = totalElements == 0
        ? 0
        : (totalElements + size - 1) ~/ size;
    final expectedFirst = page == 0;
    final expectedLast = totalPages == 0 || page >= totalPages - 1;
    if (totalPages != expectedPages ||
        (totalPages > 0 && page >= totalPages && items.isNotEmpty) ||
        items.length > size ||
        items.length > totalElements ||
        first != expectedFirst ||
        last != expectedLast) {
      throw const FormatException('Kategori talebi sayfa sınırları tutarsız');
    }
    return Page<AdminBacklineCategoryRequest>(
      items: items,
      hasNext: !last,
      nextCursor: last ? null : '${page + 1}',
    );
  }

  @override
  Future<Result<Page<AdminCollabReport>>> getCollabReports({
    AdminCollabReportStatus? status,
    AdminCollabReportReason? reason,
    int page = 0,
    int size = 20,
  }) async {
    if (page < 0 || page > 1000 || size < 1 || size > 50) {
      return const Result.failure(
        AppError(
          code: 'admin_collab_report_validation',
          message: 'Geçersiz sayfalama isteği.',
        ),
      );
    }
    try {
      final response = await _apiClient.get<Page<AdminCollabReport>>(
        AdminEndpoints.collabReports,
        query: <String, dynamic>{
          if (status != null) 'status': status.apiValue,
          if (reason != null) 'reason': reason.apiValue,
          'page': page,
          'size': size,
        },
        decoder: (json) => _decodeCollabReportPage(
          json,
          requestedPage: page,
          requestedSize: size,
        ),
      );
      return Result.success(response);
    } on ApiException catch (error) {
      return Result.failure(error.error);
    } on FormatException {
      return const Result.failure(
        AppError(
          code: 'admin_collab_reports_invalid_response',
          message: 'Collab raporları beklenen biçimde alınamadı.',
        ),
      );
    } catch (_) {
      return const Result.failure(
        AppError(
          code: 'admin_collab_reports_unknown',
          message: 'Collab raporları yüklenemedi. Lütfen tekrar dene.',
        ),
      );
    }
  }

  @override
  Future<Result<AdminCollabReport>> reviewCollabReport({
    required String id,
    required int expectedVersion,
    required AdminCollabReportDecision decision,
    required String resolutionNote,
  }) async {
    final normalizedId = id.trim();
    final normalizedNote = resolutionNote.trim();
    if (normalizedId.isEmpty ||
        expectedVersion < 0 ||
        normalizedNote.length < 5 ||
        normalizedNote.length > 500) {
      return const Result.failure(
        AppError(
          code: 'admin_collab_report_validation',
          message: 'Karar açıklaması 5-500 karakter arasında olmalıdır.',
        ),
      );
    }
    try {
      final response = await _apiClient.post<AdminCollabReport>(
        AdminEndpoints.reviewCollabReport(normalizedId),
        body: <String, dynamic>{
          'decision': decision.apiValue,
          'expectedVersion': expectedVersion,
          'resolutionNote': normalizedNote,
        },
        decoder: AdminCollabReportModel.fromJson,
      );
      return Result.success(response);
    } on ApiException catch (error) {
      return Result.failure(error.error);
    } on FormatException {
      return const Result.failure(
        AppError(
          code: 'admin_collab_report_invalid_response',
          message: 'Güncellenen Collab raporu doğrulanamadı.',
        ),
      );
    } catch (_) {
      return const Result.failure(
        AppError(
          code: 'admin_collab_report_review_unknown',
          message: 'Collab raporu sonuçlandırılamadı.',
        ),
      );
    }
  }

  Page<AdminCollabReport> _decodeCollabReportPage(
    Object? value, {
    required int requestedPage,
    required int requestedSize,
  }) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Collab rapor sayfası nesne olmalıdır');
    }
    final content = value['content'];
    final page = value.containsKey('page') ? value['page'] : value['number'];
    final size = value['size'];
    final totalElements = value['totalElements'];
    final totalPages = value['totalPages'];
    final first = value['first'];
    final last = value['last'];
    if (content is! List ||
        page is! int ||
        size is! int ||
        totalElements is! int ||
        totalPages is! int ||
        first is! bool ||
        last is! bool ||
        page != requestedPage ||
        size != requestedSize ||
        totalElements < 0 ||
        totalPages < 0) {
      throw const FormatException('Collab rapor sayfası geçersiz');
    }
    final items = content
        .map(AdminCollabReportModel.fromJson)
        .toList(growable: false);
    final expectedPages = totalElements == 0
        ? 0
        : (totalElements + size - 1) ~/ size;
    final expectedFirst = page == 0;
    final expectedLast = totalPages == 0 || page >= totalPages - 1;
    if (totalPages != expectedPages ||
        (totalPages > 0 && page >= totalPages && items.isNotEmpty) ||
        items.length > size ||
        items.length > totalElements ||
        first != expectedFirst ||
        last != expectedLast) {
      throw const FormatException('Collab rapor sayfa sınırları tutarsız');
    }
    return Page<AdminCollabReport>(
      items: items,
      hasNext: !last,
      nextCursor: last ? null : '${page + 1}',
    );
  }
}
