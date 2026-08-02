import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/admin_repository.dart';
import '../domain/entities/admin_dashboard_summary.dart';
import '../domain/entities/admin_venue_application.dart';
import '../domain/entities/admin_studio_application.dart';
import 'admin_endpoints.dart';
import 'models/admin_dashboard_summary_model.dart';
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
          message: 'Admin ozeti getirilemedi',
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
          message: 'Mekan basvurulari getirilemedi',
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
      fallbackMessage: 'Basvuru onaylanamadi',
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
      fallbackMessage: 'Basvuru reddedilemedi',
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
  Future<Result<List<AdminStudioApplication>>> getStudioApplicationsByStatus(
    AdminVenueApplicationStatus status,
  ) async {
    try {
      final response = await _apiClient.get<List<AdminStudioApplication>>(
        AdminEndpoints.studioApplicationsByStatus,
        query: {'status': status.apiValue},
        decoder: (json) => (json as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(AdminStudioApplicationModel.fromJson)
            .toList(growable: false),
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
    path:
        '${AdminEndpoints.rejectStudioApplication(id)}?reason=${Uri.encodeQueryComponent(reason.trim())}',
    fallbackCode: 'admin_studio_reject_unknown',
    fallbackMessage: 'Stüdyo başvurusu reddedilemedi',
  );

  Future<Result<AdminStudioApplication>> _studioApplicationAction({
    required String path,
    required String fallbackCode,
    required String fallbackMessage,
  }) async {
    try {
      final response = await _apiClient.post<AdminStudioApplication>(
        path,
        body: null,
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
}
