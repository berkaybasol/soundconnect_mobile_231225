import '../../../core/error/result.dart';
import '../../../core/pagination/page.dart';
import 'entities/admin_dashboard_summary.dart';
import 'entities/admin_backline_category_request.dart';
import 'entities/admin_collab_report.dart';
import 'entities/admin_venue_application.dart';
import 'entities/admin_studio_application.dart';

abstract class AdminRepository {
  Future<Result<AdminDashboardSummary>> getDashboardSummary();

  Future<Result<List<AdminVenueApplication>>> getVenueApplicationsByStatus(
    AdminVenueApplicationStatus status,
  );

  Future<Result<AdminVenueApplication>> approveVenueApplication(String id);

  Future<Result<AdminVenueApplication>> rejectVenueApplication({
    required String id,
    required String reason,
  });

  Future<Result<Page<AdminStudioApplication>>> getStudioApplicationsByStatus(
    AdminVenueApplicationStatus status, {
    int page = 0,
    int size = 50,
  });

  Future<Result<AdminStudioApplication>> approveStudioApplication(String id);

  Future<Result<AdminStudioApplication>> rejectStudioApplication({
    required String id,
    required String reason,
  });

  Future<Result<Page<AdminBacklineCategoryRequest>>>
  getBacklineCategoryRequests({
    AdminBacklineCategoryRequestStatus? status,
    int page = 0,
    int size = 20,
  });

  Future<Result<AdminBacklineCategoryRequest>> reviewBacklineCategoryRequest({
    required String id,
    required AdminBacklineCategoryReviewDecision decision,
    String? note,
  });

  Future<Result<Page<AdminCollabReport>>> getCollabReports({
    AdminCollabReportStatus? status,
    AdminCollabReportReason? reason,
    int page = 0,
    int size = 20,
  });

  Future<Result<AdminCollabReport>> reviewCollabReport({
    required String id,
    required int expectedVersion,
    required AdminCollabReportDecision decision,
    required String resolutionNote,
  });
}
