import '../../../core/error/result.dart';
import 'entities/admin_dashboard_summary.dart';
import 'entities/admin_venue_application.dart';

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
}
