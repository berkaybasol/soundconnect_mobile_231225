class AdminDashboardSummary {
  final int totalUsers;
  final int pendingVenueApplications;
  final int approvedVenueApplications;
  final int rejectedVenueApplications;
  final int pendingStudioApplications;
  final int approvedStudioApplications;
  final int rejectedStudioApplications;
  final int activePromotions;

  const AdminDashboardSummary({
    required this.totalUsers,
    required this.pendingVenueApplications,
    required this.approvedVenueApplications,
    required this.rejectedVenueApplications,
    required this.activePromotions,
    this.pendingStudioApplications = 0,
    this.approvedStudioApplications = 0,
    this.rejectedStudioApplications = 0,
  });

  const AdminDashboardSummary.empty()
    : totalUsers = 0,
      pendingVenueApplications = 0,
      approvedVenueApplications = 0,
      rejectedVenueApplications = 0,
      pendingStudioApplications = 0,
      approvedStudioApplications = 0,
      rejectedStudioApplications = 0,
      activePromotions = 0;
}
