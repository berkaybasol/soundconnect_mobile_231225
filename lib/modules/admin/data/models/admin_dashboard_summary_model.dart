import '../../domain/entities/admin_dashboard_summary.dart';

class AdminDashboardSummaryModel extends AdminDashboardSummary {
  const AdminDashboardSummaryModel({
    required super.totalUsers,
    required super.pendingVenueApplications,
    required super.approvedVenueApplications,
    required super.rejectedVenueApplications,
    required super.activePromotions,
  });

  factory AdminDashboardSummaryModel.fromJson(Map<String, dynamic> json) {
    return AdminDashboardSummaryModel(
      totalUsers: _intValue(json['totalUsers']),
      pendingVenueApplications: _intValue(json['pendingVenueApplications']),
      approvedVenueApplications: _intValue(json['approvedVenueApplications']),
      rejectedVenueApplications: _intValue(json['rejectedVenueApplications']),
      activePromotions: _intValue(json['activePromotions']),
    );
  }

  static int _intValue(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
