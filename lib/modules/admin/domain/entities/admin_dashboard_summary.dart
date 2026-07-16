class AdminDashboardSummary {
  final int totalUsers;
  final int pendingVenueApplications;
  final int approvedVenueApplications;
  final int rejectedVenueApplications;
  final int activePromotions;

  const AdminDashboardSummary({
    required this.totalUsers,
    required this.pendingVenueApplications,
    required this.approvedVenueApplications,
    required this.rejectedVenueApplications,
    required this.activePromotions,
  });

  const AdminDashboardSummary.empty()
    : totalUsers = 0,
      pendingVenueApplications = 0,
      approvedVenueApplications = 0,
      rejectedVenueApplications = 0,
      activePromotions = 0;
}
