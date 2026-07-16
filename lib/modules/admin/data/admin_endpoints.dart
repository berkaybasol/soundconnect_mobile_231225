class AdminEndpoints {
  static const String dashboardSummary = '/api/v1/admin/dashboard/summary';

  static const String venueApplicationsBase =
      '/api/v1/admin/venue-applications';

  static const String venueApplicationsByStatus =
      '$venueApplicationsBase/by-status';

  static String venueApplicationById(String id) => '$venueApplicationsBase/$id';

  static String approveVenueApplication(String id) =>
      '$venueApplicationsBase/approve/$id';

  static String rejectVenueApplication(String id) =>
      '$venueApplicationsBase/reject/$id';
}
